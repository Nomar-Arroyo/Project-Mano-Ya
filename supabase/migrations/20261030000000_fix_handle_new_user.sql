-- =====================================================================
-- Mano Ya · Corrige el alta de usuarios (error 500 al registrarse)
-- ---------------------------------------------------------------------
-- Producción tenía un public.handle_new_user() que no coincide con
-- ninguna migración del repositorio: escribía en public.profiles la
-- columna `email`, que no existe.
--
--   insert into public.profiles (id, email, created_at)
--   values (new.id, new.email, now());
--   -> ERROR 42703: column "email" of relation "profiles" does not exist
--
-- Como el INSERT en auth.users dispara ese trigger, fallaba cualquier
-- alta (email, teléfono o /auth/v1/admin/users) con
-- "Database error saving new user".
--
-- Esta migración restaura la versión del repositorio y añade una red de
-- seguridad: si el perfil no se puede crear, el alta del usuario sigue
-- adelante y el fallo queda en el log como WARNING. Un problema de
-- perfil no debe impedir que alguien cree su cuenta.
-- =====================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  requested_role text := new.raw_user_meta_data ->> 'role';
  confirmed_role boolean;
begin
  if requested_role is null or requested_role not in ('client', 'worker') then
    requested_role := 'client';
  end if;

  confirmed_role :=
    coalesce(
      new.raw_user_meta_data ->> 'role' in ('client', 'worker'),
      false
    )
    or coalesce(new.raw_app_meta_data ->> 'provider', '') <> 'google';

  begin
    insert into public.profiles (
      id, full_name, role, role_confirmed, phone, city, avatar_url
    )
    values (
      new.id,
      coalesce(
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'name',
        split_part(new.email, '@', 1),
        'Usuario'
      ),
      requested_role,
      confirmed_role,
      new.raw_user_meta_data ->> 'phone',
      new.raw_user_meta_data ->> 'city',
      new.raw_user_meta_data ->> 'avatar_url'
    )
    on conflict (id) do nothing;
  exception
    when others then
      -- El alta continua: el perfil se puede reparar despues.
      raise warning 'handle_new_user: perfil no creado para %: % (%)',
        new.id, sqlerrm, sqlstate;
  end;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Crea el perfil al registrarse. Nunca bloquea el alta del usuario.';

-- El trigger ya existía; se recrea para garantizar que apunta a la
-- función corregida y que hay exactamente uno.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- Verificación (opcional): después de aplicar, esta consulta no debe
-- devolver ninguna fila.
-- ---------------------------------------------------------------------
-- select p.oid::regprocedure as funcion, pg_get_functiondef(p.oid)
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname = 'handle_new_user'
--   and pg_get_functiondef(p.oid) like '%profiles (id, email%';
