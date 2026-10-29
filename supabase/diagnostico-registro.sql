-- =====================================================================
-- Mano Ya · Diagnóstico del error 500 al registrar usuarios
-- ---------------------------------------------------------------------
-- Síntoma: toda alta de usuario responde 500:
--   {"code":500,"error_code":"unexpected_failure",
--    "msg":"Database error saving new user"}
--
-- Lo devuelve Supabase Auth (GoTrue) cuando falla el INSERT en
-- auth.users, en auth.identities o en alguno de sus triggers (por
-- ejemplo public.handle_new_user). Falla igual con email, con teléfono
-- y con /auth/v1/admin/users, así que no depende de los metadatos que
-- envía la app.
--
-- Este archivo NO cambia datos: solo lee definiciones y reproduce el
-- alta dentro de una transacción que siempre se deshace.
--
-- Cómo usarlo:
--   1. Abre el SQL Editor del proyecto en el panel de Supabase.
--   2. Ejecuta el bloque 5 (el último) y copia el mensaje que empieza
--      por "DIAGNOSTICO:".
--   3. Si el mensaje no basta, ejecuta también los bloques 1 a 4.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Columnas reales de auth.users
-- ---------------------------------------------------------------------
-- Si el servicio de Auth se actualizó y el esquema no, aquí se ve una
-- columna nueva, con NOT NULL o sin valor por defecto.
select column_name as columna,
       data_type as tipo,
       is_nullable as admite_nulos,
       column_default as valor_por_defecto
from information_schema.columns
where table_schema = 'auth'
  and table_name = 'users'
order by ordinal_position;


-- ---------------------------------------------------------------------
-- 2. Índices y restricciones de auth.users / auth.identities
-- ---------------------------------------------------------------------
select c.relname as tabla,
       i.relname as indice,
       pg_get_indexdef(x.indexrelid) as definicion,
       x.indisunique as es_unico
from pg_index x
join pg_class i on i.oid = x.indexrelid
join pg_class c on c.oid = x.indrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'auth'
  and c.relname in ('users', 'identities')
order by 1, 2;


-- ---------------------------------------------------------------------
-- 3. Instancia de Auth y conteo de tablas implicadas
-- ---------------------------------------------------------------------
-- auth.users.instance_id apunta a auth.instances. Si esa fila no existe,
-- ningún alta puede completarse.
select (select count(*) from auth.instances) as filas_instances,
       (select count(*) from auth.users) as filas_users,
       (select count(*) from auth.identities) as filas_identities,
       (select count(*) from public.profiles) as filas_profiles;


-- ---------------------------------------------------------------------
-- 4. Triggers y funciones que intervienen en el alta
-- ---------------------------------------------------------------------
select c.relnamespace::regnamespace as esquema,
       c.relname as tabla,
       t.tgname as trigger,
       pg_get_triggerdef(t.oid) as definicion
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
where not t.tgisinternal
  and c.oid in (
    'auth.users'::regclass,
    'auth.identities'::regclass,
    'public.profiles'::regclass
  )
order by 1, 2, 3;

select p.proname as funcion,
       pg_get_userbyid(p.proowner) as propietario,
       p.prosecdef as es_security_definer,
       pg_get_functiondef(p.oid) as definicion
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'handle_new_user',
    'sync_auth_user_profile',
    'normalize_profile_phone',
    'normalize_venezuelan_mobile',
    'protect_profile_role'
  )
order by 1;


-- ---------------------------------------------------------------------
-- 5. Reproducción del alta (siempre se deshace)
-- ---------------------------------------------------------------------
-- Devuelve "DIAGNOSTICO: OK" si el INSERT funcionó, o el SQLSTATE y el
-- mensaje exactos del fallo. Es el dato que hace falta para corregirlo.
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

    -- Si el INSERT pasó, este bloque confirma que el perfil se creó.
    if not exists (select 1 from public.profiles where id = nuevo_id) then
      detalle := 'OK pero sin perfil: el trigger handle_new_user no lo creó';
    end if;
  exception
    when others then
      detalle := sqlstate || ' | ' || sqlerrm;
  end;

  -- Fuerza el rollback: nunca deja el usuario de prueba creado.
  raise exception 'DIAGNOSTICO: %', detalle;
end;
$$;
