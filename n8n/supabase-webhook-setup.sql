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
--   3. Muestra una prueba que inserta un reporte de ejemplo y confirma
--      que el campo `notified_at` quedo relleno (o sea: que el trigger
--      disparo y que la URL del webhook esta configurada).
--
-- IMPORTANTE: sustituye `https://TU-N8N/webhook/reportes` por la URL
-- real de tu instancia de n8n antes de ejecutar la seccion 2.
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
security definer set search_path = public
as $$
declare
  v_url text := coalesce(btrim(p_url), '');
begin
  insert into public.app_settings (key, value, updated_at)
  values ('n8n_report_webhook', v_url, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();
  return v_url;
end;
$$;

comment on function public.set_n8n_webhook(text) is
  'Guarda la URL del webhook de n8n que usa el trigger reports_notify_n8n.';

-- ---------------------------------------------------------------------
-- 2. Guardar la URL del webhook
-- ---------------------------------------------------------------------
-- REEMPLAZA la URL de abajo por la de tu n8n. Ejemplo:
--   https://manoya-n8n.up.railway.app/webhook/reportes
--   https://n8n.midominio.com/webhook/reportes
select public.set_n8n_webhook('https://TU-N8N/webhook/reportes') as webhook_configurado;

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
-- 4. Prueba de extremo a extremo
-- ---------------------------------------------------------------------
-- Inserta un reporte de ejemplo. El trigger debe:
//   a) enviar el POST a la URL de n8n guardada en app_settings
--   b) rellenar `notified_at`
-- Ejecuta este bloque por separado del resto para poder ver el resultado.

insert into public.reports (
  reporter_name,
  reporter_email,
  target_name,
  category,
  reason,
  details,
  severity,
  status
)
values (
  'Prueba automatica',
  'prueba@manoya.app',
  'Trabajador de prueba',
  'calidad',
  'Reporte de prueba del setup de n8n',
  'Este reporte lo genero n8n/supabase-webhook-setup.sql para comprobar que el trigger notifica a n8n.',
  'baja',
  'abierto'
)
returning id, category, reason, notified_at;

-- Si la columna `notified_at` viene con una fecha, el trigger funciono y
-- la URL del webhook esta guardada. Si viene NULL, revisa que la URL
-- este escrita en app_settings y que el trigger este habilitado.
select
  id,
  category,
  reason,
  created_at,
  notified_at,
  (notified_at is not null) as notificado_ok
from public.reports
where reporter_email = 'prueba@manoya.app'
order by created_at desc
limit 1;

-- Limpieza opcional de la prueba:
--   delete from public.reports where reporter_email = 'prueba@manoya.app';

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
