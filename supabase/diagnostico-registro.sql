-- =====================================================================
-- Mano Ya · Diagnóstico del error 500 al registrar usuarios
-- ---------------------------------------------------------------------
-- El registro responde:
--   {"code":500,"error_code":"unexpected_failure",
--    "msg":"Database error saving new user"}
--
-- Ese mensaje lo devuelve Supabase Auth cuando falla el INSERT en
-- auth.users o cualquiera de sus triggers (por ejemplo handle_new_user).
-- Este archivo NO cambia nada: solo lee definiciones y reproduce el alta
-- dentro de una transacción que se deshace.
--
-- Cómo usarlo:
--   1. Abre el SQL Editor del proyecto en el panel de Supabase.
--   2. Ejecuta cada bloque por separado y copia el resultado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Definición real de las funciones que intervienen en el alta
-- ---------------------------------------------------------------------
select p.proname as funcion,
       pg_get_functiondef(p.oid) as definicion
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'handle_new_user',
    'sync_auth_user_profile',
    'normalize_profile_phone',
    'normalize_venezuelan_mobile'
  )
order by p.proname;


-- ---------------------------------------------------------------------
-- 2. Triggers reales sobre auth.users y public.profiles
-- ---------------------------------------------------------------------
select c.relnamespace::regnamespace as esquema,
       c.relname as tabla,
       t.tgname as trigger,
       pg_get_triggerdef(t.oid) as definicion
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
where not t.tgisinternal
  and c.oid in ('auth.users'::regclass, 'public.profiles'::regclass)
order by 1, 2, 3;


-- ---------------------------------------------------------------------
-- 3. Reproducción del alta (se deshace siempre)
-- ---------------------------------------------------------------------
-- Muestra en el error el SQLSTATE y el mensaje exactos. Si responde
-- "DIAGNOSTICO: OK", el insert funcionó y el problema está después.
do $$
declare
  nuevo_id uuid := gen_random_uuid();
  detalle text := 'OK';
begin
  begin
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    values (
      coalesce(
        (select u.instance_id from auth.users u limit 1),
        '00000000-0000-0000-0000-000000000000'::uuid
      ),
      nuevo_id,
      'authenticated',
      'authenticated',
      'diagnostico.' || substr(nuevo_id::text, 1, 8) || '@manoya.app',
      null,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Diagnostico","role":"client"}'::jsonb,
      now(),
      now()
    );
  exception
    when others then
      detalle := sqlstate || ' | ' || sqlerrm;
  end;

  -- Fuerza el rollback: nunca deja el usuario de prueba creado.
  raise exception 'DIAGNOSTICO: %', detalle;
end;
$$;
