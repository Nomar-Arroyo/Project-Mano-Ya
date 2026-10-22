-- =====================================================================
-- Mano Ya · Reportes, automatizaciones y retención
-- ---------------------------------------------------------------------
-- Esta migración añade:
--   1. La tabla `reports` para los reportes y denuncias de la app.
--   2. El trigger que notifica a n8n cada reporte nuevo (pg_net).
--   3. El job programado (pg_cron) que purga datos antiguos y mantiene
--      viva la base de datos.
--
-- Cómo aplicarlo:
--   Opción 1 (recomendada): Supabase CLI ->  supabase db push
--   Opción 2: panel de Supabase -> SQL Editor -> copiar y ejecutar
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_cron";
create extension if not exists "pg_net";

-- ---------------------------------------------------------------------
-- 1. Tabla de reportes (quejas, cobros indebidos, solicitudes de soporte)
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles (id) on delete set null,
  reporter_name text not null default '',
  reporter_email text not null default '',
  target_user_id uuid references public.profiles (id) on delete set null,
  target_name text not null default '',
  job_id uuid references public.jobs (id) on delete set null,
  category text not null default 'otro'
    check (category in (
      'calidad',
      'pago',
      'conducta',
      'no_show',
      'datos',
      'otro'
    )),
  reason text not null default '',
  details text not null default '',
  severity text not null default 'normal'
    check (severity in ('baja', 'normal', 'alta')),
  status text not null default 'abierto'
    check (status in ('abierto', 'en_revision', 'resuelto', 'cerrado')),
  notified_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.reports is
  'Reportes enviados desde la app: el usuario los crea y n8n los notifica.';

create index if not exists reports_reporter_idx
  on public.reports (reporter_id, created_at desc);
create index if not exists reports_status_idx
  on public.reports (status, created_at desc);
create index if not exists reports_target_idx
  on public.reports (target_user_id);

-- ---------------------------------------------------------------------
-- 2. Seguridad por fila (RLS)
-- ---------------------------------------------------------------------
alter table public.reports enable row level security;

-- Cada usuario ve sus propios reportes; el equipo de soporte usa el
-- panel de Supabase (service_role), que ignora las politicas de RLS.
drop policy if exists "reports_own" on public.reports;
create policy "reports_own"
  on public.reports for all
  using (auth.uid() = reporter_id)
  with check (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------
-- 3. Notificación a n8n cuando se crea un reporte
-- ---------------------------------------------------------------------
-- La URL del webhook se toma de la tabla `app_settings`. Se puede cambiar
-- desde el panel sin volver a ejecutar esta migración:
--   update public.app_settings set value = 'https://n8n.../webhook/reportes'
--   where key = 'n8n_report_webhook';
create table if not exists public.app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value)
values (
  'n8n_report_webhook',
  coalesce(
    (select value from public.app_settings where key = 'n8n_report_webhook'),
    ''
  )
)
on conflict (key) do nothing;

create or replace function public.notify_new_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  webhook text;
begin
  select value into webhook
  from public.app_settings
  where key = 'n8n_report_webhook';

  if webhook is null or webhook = '' then
    return new;
  end if;

  -- La llamada es asincrona: no bloquea la insercion del reporte.
  perform net.http_post(
    url     := webhook,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object(
      'evento',      'nuevo_reporte',
      'id',          new.id,
      'categoria',   new.category,
      'severidad',   new.severity,
      'motivo',      new.reason,
      'detalle',     new.details,
      'reporta',     new.reporter_name,
      'reporta_id',  new.reporter_id,
      'correo',      new.reporter_email,
      'reportado',   new.target_name,
      'reportado_id', new.target_user_id,
      'servicio_id', new.job_id,
      'creado',      new.created_at
    )
  );

  update public.reports set notified_at = now() where id = new.id;
  return new;
end;
$$;

drop trigger if exists reports_notify_n8n on public.reports;
create trigger reports_notify_n8n
  after insert on public.reports
  for each row execute function public.notify_new_report();

-- ---------------------------------------------------------------------
-- 4. Retención automática y mantenimiento (pg_cron)
-- ---------------------------------------------------------------------
-- Purga los datos de soporte con mas de 180 dias y refresca las
-- estadisticas del catalogo de trabajadores.
create or replace function public.run_maintenance()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  -- Reportes cerrados muy antiguos.
  delete from public.reports
  where status in ('resuelto', 'cerrado')
    and created_at < now() - interval '180 days';

  -- Historial de estados de trabajos terminados.
  delete from public.job_events
  where created_at < now() - interval '365 days';

  -- Mantiene el catalogo de trabajadores alineado con los perfiles.
  update public.workers w
  set name = coalesce(nullif(p.full_name, ''), w.name),
      avatar_url = coalesce(p.avatar_url, w.avatar_url),
      phone = coalesce(p.phone, w.phone),
      city = coalesce(nullif(p.city, ''), w.city)
  from public.profiles p
  where w.profile_id = p.id;
end;
$$;

-- El planificador de Postgres ejecuta el mantenimiento cada noche.
-- Si pg_cron no esta disponible en el plan, se puede ejecutar a mano:
--   select public.run_maintenance();
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'mano-ya-mantenimiento';
    perform cron.schedule(
      'mano-ya-mantenimiento',
      '17 3 * * *',
      'select public.run_maintenance();'
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Vista de resumen para el panel de control
-- ---------------------------------------------------------------------
create or replace view public.dashboard_summary
with (security_invoker = true) as
select
  (select count(*) from public.profiles) as perfiles,
  (select count(*) from public.profiles where role = 'worker') as trabajadores,
  (select count(*) from public.profiles where role = 'client') as clientes,
  (select count(*) from public.workers) as fichas,
  (select count(*) from public.jobs) as servicios,
  (select count(*) from public.jobs where status = 'requested') as por_aceptar,
  (select count(*) from public.jobs where status = 'in_progress') as en_curso,
  (select count(*) from public.reports where status = 'abierto') as reportes_abiertos,
  now() as generado;
