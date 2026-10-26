-- =====================================================================
-- Mano Ya · Configuracion del webhook de n8n en Supabase
-- ---------------------------------------------------------------------
-- Este script se pega y ejecuta en el SQL Editor de Supabase
-- (Dashboard -> SQL Editor -> New query).
--
-- Hace tres cosas:
--   1. Crea la funcion `public.set_n8n_webhook()` para guardar la URL
--      del webhook de n8n de forma parametrica.
--   2. Verifica que el trigger `reports_notify_n8n` exista y lo recrea
--      si falta o quedo desactualizado.
--   3. Muestra como verificar la configuración sin insertar ni borrar
--      registros de usuarios.
--
-- IMPORTANTE: sustituye `https://TU-N8N/webhook/reportes` y el secreto de
-- ejemplo por los valores reales antes de ejecutar las secciones 2 y 3.
-- =====================================================================

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------------
-- 1. Funcion auxiliar para configurar la URL del webhook
-- ---------------------------------------------------------------------
-- Se puede volver a llamar las veces que quieras para cambiar la URL
-- (por ejemplo, al pasar de un webhook de prueba a uno de produccion).
create or replace function public.set_n8n_webhook(p_url text)
returns text
language plpgsql
security definer set search_path = pg_catalog, public
as $$
declare
  v_url text := coalesce(btrim(p_url), '');
begin
  if v_url <> '' and v_url !~ '^https://[^[:space:]]+$' then
    raise exception 'La URL del webhook debe usar HTTPS';
  end if;
  if position('tu-n8n' in lower(v_url)) > 0 then
    raise exception 'Reemplaza la URL de ejemplo por la URL real de n8n';
  end if;

  insert into public.app_settings (key, value, updated_at)
  values ('n8n_report_webhook', v_url, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();
  return v_url;
end;
$$;

revoke all on function public.set_n8n_webhook(text) from public, anon, authenticated;
grant execute on function public.set_n8n_webhook(text) to postgres;

comment on function public.set_n8n_webhook(text) is
  'Guarda la URL del webhook de n8n que usa el trigger reports_notify_n8n.';

-- ---------------------------------------------------------------------
-- 2. Guardar la URL del webhook
-- ---------------------------------------------------------------------
-- REEMPLAZA la URL de abajo por la de tu n8n. Ejemplo:
--   https://manoya-n8n.up.railway.app/webhook/reportes
--   https://n8n.midominio.com/webhook/reportes
select public.set_n8n_webhook('https://TU-N8N/webhook/reportes') as webhook_configurado;

-- Guarda el mismo secreto configurado como Header Auth en n8n.
-- Sustituye el marcador antes de ejecutar; no guardes aquí un secreto real
-- en Git. Ejecuta este bloque desde el SQL Editor de Supabase.
--
-- insert into public.app_settings (key, value, updated_at)
-- values ('n8n_webhook_secret', '<SECRETO_ALEATORIO>', now())
-- on conflict (key) do update
--   set value = excluded.value,
--       updated_at = now();

-- Equivalente con una instruccion UPDATE directa (alternativa):
--
--   update public.app_settings
--      set value = 'https://TU-N8N/webhook/reportes', updated_at = now()
--    where key = 'n8n_report_webhook';

-- Comprobacion: debe mostrar la URL que acabas de guardar.
select key, value, updated_at
from public.app_settings
where key = 'n8n_report_webhook';

-- ---------------------------------------------------------------------
-- 3. Verificar y recrear el trigger `reports_notify_n8n`
-- ---------------------------------------------------------------------
-- 3.1 Estado actual del trigger (debe devolver una fila).
select
  t.tgname                                        as trigger,
  t.tgenabled                                     as habilitado,
  p.proname                                      as funcion,
  pg_get_triggerdef(t.oid)                       as definicion
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'public.reports'::regclass
  and not t.tgisinternal;

-- 3.2 Se recrea la funcion del trigger (idempotente).
create or replace function public.notify_new_report()
returns trigger
language plpgsql
security definer set search_path = pg_catalog, public
as $$
declare
  webhook text;
  webhook_secret text;
  request_headers jsonb;
begin
  select value into webhook
  from public.app_settings
  where key = 'n8n_report_webhook';

  if webhook is null or webhook = '' then
    return new;
  end if;

  select value into webhook_secret
  from public.app_settings
  where key = 'n8n_webhook_secret';

  request_headers := jsonb_build_object('Content-Type', 'application/json');
  if webhook_secret is not null and webhook_secret <> '' then
    request_headers := request_headers
      || jsonb_build_object('x-webhook-secret', webhook_secret);
  end if;

  -- La llamada es asincrona: no bloquea la insercion del reporte.
  perform net.http_post(
    url     := webhook,
    headers := request_headers,
    body    := jsonb_build_object(
      'evento',       'nuevo_reporte',
      'id',           new.id,
      'categoria',    new.category,
      'severidad',    new.severity,
      'motivo',       new.reason,
      'detalle',      new.details,
      'reporta',      new.reporter_name,
      'reporta_id',   new.reporter_id,
      'correo',       new.reporter_email,
      'reportado',    new.target_name,
      'reportado_id', new.target_user_id,
      'servicio_id',  new.job_id,
      'creado',       new.created_at
    )
  );

  update public.reports set notified_at = now() where id = new.id;
  return new;
end;
$$;

-- 3.3 Se asegura el trigger (lo borra y lo vuelve a crear).
drop trigger if exists reports_notify_n8n on public.reports;
create trigger reports_notify_n8n
  after insert on public.reports
  for each row execute function public.notify_new_report();

-- 3.4 Comprobacion final: debe devolver una sola fila habilitada.
select
  t.tgname  as trigger,
  t.tgenabled as habilitado,
  p.proname as funcion
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'public.reports'::regclass
  and t.tgname = 'reports_notify_n8n'
  and not t.tgisinternal;

-- ---------------------------------------------------------------------
-- 4. Verificar el estado de los reportes existentes
-- ---------------------------------------------------------------------
-- `notified_at` significa que el POST fue encolado por pg_net; no certifica
-- que n8n ejecutó el workflow ni que el correo fue entregado.
select
  id,
  category,
  notified_at,
  (notified_at is not null) as webhook_encolado
from public.reports
order by created_at desc
limit 20;

-- ---------------------------------------------------------------------
-- 5. Estado final del cron de mantenimiento
-- ---------------------------------------------------------------------
select jobid, jobname, schedule, command, active
from cron.job
where jobname = 'mano-ya-mantenimiento';

-- Si no aparece ninguna fila, activa el job con:
--   select cron.schedule(
--     'mano-ya-mantenimiento',
--     '17 3 * * *',
--     'select public.run_maintenance();'
--   );
