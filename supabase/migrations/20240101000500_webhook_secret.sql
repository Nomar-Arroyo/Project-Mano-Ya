-- =====================================================================
-- Mano Ya · Notificacion a n8n con el secreto compartido
-- ---------------------------------------------------------------------
-- La funcion `notify_new_report` ahora envia la cabecera `x-webhook-secret`
-- en la peticion al webhook de n8n, igual que hace la app movil.
--
-- El secreto vive en `public.app_settings`, con la clave
-- `n8n_webhook_secret`:
--
--   insert into public.app_settings (key, value)
--   values ('n8n_webhook_secret', '<N8N_WEBHOOK_SECRET>')
--   on conflict (key) do update set value = excluded.value,
--     updated_at = now();
--
-- La tabla tiene RLS activo y no es legible ni por la clave anon ni por un
-- usuario autenticado: solo la service_role y el rol `postgres` pueden
-- leerla. El secreto nunca sale del servidor.
--
-- En n8n, el nodo Webhook debe usar la autenticacion "Header Auth" con el
-- nombre `x-webhook-secret` y ese mismo valor; si la credencial esta vacia
-- n8n responde "No authentication data defined on node!".
-- =====================================================================

begin;

create or replace function public.notify_new_report()
returns trigger
language plpgsql
security definer set search_path = public
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

  -- La cabecera del secreto solo se anade si hay valor configurado.
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

commit;
