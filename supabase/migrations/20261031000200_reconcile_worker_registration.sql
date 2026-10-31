-- Reconcile an explicitly registered worker with the protected profile role.
-- Existing Google accounts can have worker metadata while their original
-- profile row is still marked as a client.
create or replace function public.ensure_current_user_worker_role()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_metadata jsonb;
  v_terms_version text;
  v_profile_role text;
  v_previous_assignment text;
begin
  if v_user_id is null then
    raise exception 'Inicia sesión para completar tu perfil de trabajador';
  end if;

  select raw_user_meta_data
  into v_metadata
  from auth.users
  where id = v_user_id;

  v_terms_version := v_metadata ->> 'terms_version';
  if v_metadata ->> 'role' is distinct from 'worker'
     or v_metadata ->> 'terms_accepted' is distinct from 'true'
     or v_terms_version is null
     or not exists (
       select 1
       from public.terms_acceptances
       where user_id = v_user_id
         and terms_version = v_terms_version
     ) then
    raise exception
      'Completa el registro como trabajador y acepta los términos vigentes';
  end if;

  select role
  into v_profile_role
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'No se encontró el perfil de esta cuenta';
  end if;

  if v_profile_role <> 'worker' then
    select current_setting('mano_ya.role_assignment', true)
    into v_previous_assignment;
    perform set_config('mano_ya.role_assignment', 'on', true);
    update public.profiles
    set role = 'worker',
        role_confirmed = true,
        updated_at = now()
    where id = v_user_id;
    perform set_config(
      'mano_ya.role_assignment',
      coalesce(v_previous_assignment, ''),
      true
    );
  end if;
end;
$$;

revoke all on function public.ensure_current_user_worker_role()
  from public, anon;
grant execute on function public.ensure_current_user_worker_role()
  to authenticated;
