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
-- Este archivo NO deja datos: el alta de prueba va dentro de una
-- transacción que termina en rollback.
--
-- Cómo usarlo:
--   1. Abre el SQL Editor del proyecto en el panel de Supabase.
--   2. Ejecuta el bloque 5 completo (incluye begin y rollback).
--   3. Copia el mensaje de error que muestre el editor.
--   4. Si el bloque 5 dice "INSERT OK", ejecuta los bloques 1 a 4.
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
-- 5. Reproducción del alta (rollback garantizado)
-- ---------------------------------------------------------------------
-- Ejecuta exactamente el INSERT que hace GoTrue. Si falla, el editor
-- muestra el SQLSTATE y el mensaje exactos. Si responde "INSERT OK" y
-- aun así el registro falla, el problema está en auth.identities.
-- El rollback deja la base como estaba.
begin;

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
    (select u.instance_id from auth.users u order by u.created_at limit 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ),
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'diagnostico.rollback@manoya.app',
  null,
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Diagnostico","role":"client"}'::jsonb,
  now(),
  now()
);

select 'INSERT OK' as resultado;

rollback;


-- ---------------------------------------------------------------------
-- 6. Reproducción del alta de identidad (rollback garantizado)
-- ---------------------------------------------------------------------
-- Solo hace falta si el bloque 5 responde "INSERT OK". Usa un usuario
-- real ya existente y deshace todo al final.
begin;

insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
values (
  gen_random_uuid(),
  (select u.id from auth.users u where u.email = 'cliente.validacion@manoya.app'),
  jsonb_build_object(
    'sub',
    gen_random_uuid()::text,
    'email',
    'diagnostico.rollback@manoya.app'
  ),
  'email',
  gen_random_uuid()::text,
  now(),
  now(),
  now()
);

select 'IDENTITY OK' as resultado;

rollback;
