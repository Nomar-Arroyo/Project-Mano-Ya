-- Protect private profile data, server-managed catalog fields, and booking state.

create or replace function public.normalize_venezuelan_mobile(phone text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  digits text;
begin
  if phone is null or btrim(phone) = '' then
    return null;
  end if;

  digits := regexp_replace(phone, '[^0-9]', '', 'g');
  if length(digits) = 11 and left(digits, 1) = '0' then
    digits := substr(digits, 2);
  elsif length(digits) = 12 and left(digits, 2) = '58' then
    digits := substr(digits, 3);
  end if;

  if length(digits) <> 10
     or left(digits, 1) <> '4'
     or substr(digits, 1, 3) not in ('412', '414', '416', '424', '426') then
    raise exception 'El teléfono debe ser un móvil venezolano válido';
  end if;

  return '+58' || digits;
end;
$$;

create or replace function public.normalize_profile_phone()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.phone := public.normalize_venezuelan_mobile(new.phone);
  return new;
end;
$$;

drop trigger if exists profiles_normalize_phone on public.profiles;
create trigger profiles_normalize_phone
  before insert or update of phone on public.profiles
  for each row execute function public.normalize_profile_phone();

drop trigger if exists workers_normalize_phone on public.workers;
create trigger workers_normalize_phone
  before insert or update of phone on public.workers
  for each row execute function public.normalize_profile_phone();

-- Public catalog coordinates are approximate. Keep existing and future values
-- to two decimal places (~1 km), rather than exposing precise home locations.
update public.workers
set latitude = round(latitude::numeric, 2)::double precision,
    longitude = round(longitude::numeric, 2)::double precision
where latitude is not null or longitude is not null;

create or replace function public.is_worker_account(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = target_profile_id
      and p.role = 'worker'
  );
$$;

revoke all on function public.is_worker_account(uuid) from public;
grant execute on function public.is_worker_account(uuid) to anon, authenticated;

-- profiles also contains private payout details; catalog clients use workers.
drop policy if exists "profiles_select_public" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

-- The role may be selected during initial registration, but later edits to
-- user_metadata cannot promote an existing account.
alter table public.profiles
  add column if not exists role_confirmed boolean not null default false;

update public.profiles
set role_confirmed = true
where role_confirmed = false;

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  trusted_assignment boolean :=
    current_setting('mano_ya.role_assignment', true) = 'on';
begin
  if auth.role() is distinct from 'service_role'
     and not trusted_assignment
     and (
       new.role is distinct from old.role
       or new.role_confirmed is distinct from old.role_confirmed
     ) then
    raise exception 'El rol solo puede definirse durante el registro';
  end if;
  return new;
end;
$$;

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

  insert into public.profiles (
    id, full_name, role, role_confirmed, phone, city, avatar_url
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    ),
    requested_role,
    confirmed_role,
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'city',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  previous_assignment text;
  requested_role text;
begin
  requested_role := new.raw_user_meta_data ->> 'role';
  if requested_role in ('client', 'worker') then
    select current_setting('mano_ya.role_assignment', true)
    into previous_assignment;
    perform set_config('mano_ya.role_assignment', 'on', true);
    update public.profiles
    set role = requested_role, role_confirmed = true
    where id = new.id and role_confirmed = false;
    perform set_config(
      'mano_ya.role_assignment',
      coalesce(previous_assignment, ''),
      true
    );
  end if;

  update public.profiles
  set full_name = case
        when new.raw_user_meta_data ? 'full_name'
          then coalesce(new.raw_user_meta_data ->> 'full_name', '')
        when new.raw_user_meta_data ? 'name'
          then coalesce(new.raw_user_meta_data ->> 'name', '')
        else full_name
      end,
      phone = case
        when new.raw_user_meta_data ? 'phone'
          then public.normalize_venezuelan_mobile(
            new.raw_user_meta_data ->> 'phone'
          )
        else phone
      end,
      city = case
        when new.raw_user_meta_data ? 'city'
          then new.raw_user_meta_data ->> 'city'
        else city
      end,
      avatar_url = case
        when new.raw_user_meta_data ? 'avatar_url'
          then new.raw_user_meta_data ->> 'avatar_url'
        else avatar_url
      end,
      updated_at = now()
  where id = new.id;

  update public.workers w
  set name = coalesce(nullif(p.full_name, ''), w.name),
      phone = p.phone,
      city = coalesce(nullif(p.city, ''), w.city),
      avatar_url = p.avatar_url
  from public.profiles p
  where w.profile_id = p.id and p.id = new.id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of raw_user_meta_data on auth.users
  for each row
  when (old.raw_user_meta_data is distinct from new.raw_user_meta_data)
  execute function public.sync_auth_user_profile();

-- An account may edit its own worker listing, but cannot self-assign trust
-- badges, ratings, or review totals.
create or replace function public.guard_worker_listing()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if auth.role() = 'service_role'
     or current_setting('mano_ya.server_managed_write', true) = 'on' then
    return new;
  end if;

  if auth.uid() is null or new.profile_id is distinct from auth.uid() then
    raise exception 'Solo puedes administrar tu propia ficha de trabajador';
  end if;

  if not public.is_worker_account(new.profile_id) then
    raise exception 'La ficha requiere una cuenta registrada como trabajador';
  end if;

  if tg_op = 'INSERT' then
    new.identity_verified := false;
    new.work_guaranteed := false;
    new.rating := 0;
    new.reviews_count := 0;
  else
    if new.id is distinct from old.id
       or new.profile_id is distinct from old.profile_id
       or new.created_at is distinct from old.created_at
       or new.identity_verified is distinct from old.identity_verified
       or new.work_guaranteed is distinct from old.work_guaranteed
       or new.rating is distinct from old.rating
       or new.reviews_count is distinct from old.reviews_count then
      raise exception 'Los datos de confianza solo los puede actualizar el servidor';
    end if;
  end if;

  if new.latitude is not null then
    new.latitude := round(new.latitude::numeric, 2)::double precision;
  end if;
  if new.longitude is not null then
    new.longitude := round(new.longitude::numeric, 2)::double precision;
  end if;

  return new;
end;
$$;

drop trigger if exists workers_guard_listing on public.workers;
create trigger workers_guard_listing
  before insert or update on public.workers
  for each row execute function public.guard_worker_listing();

drop policy if exists "workers_select_public" on public.workers;
create policy "workers_select_public"
  on public.workers for select
  using (
    profile_id is null
    or (
      category <> ''
      and subcategory <> ''
      and city <> ''
      and public.is_worker_account(profile_id)
    )
  );

drop policy if exists "workers_select_own" on public.workers;
create policy "workers_select_own"
  on public.workers for select
  using (auth.uid() = profile_id);

drop policy if exists "workers_insert_own" on public.workers;
create policy "workers_insert_own"
  on public.workers for insert
  with check (
    auth.uid() = profile_id
    and public.is_worker_account(profile_id)
  );

drop policy if exists "workers_update_own" on public.workers;
create policy "workers_update_own"
  on public.workers for update
  using (auth.uid() = profile_id)
  with check (
    auth.uid() = profile_id
    and public.is_worker_account(profile_id)
  );

-- Create requests from canonical profile/catalog data and allow only valid
-- state changes by the relevant participant.
create or replace function public.guard_job_write()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  requester_role text;
  requester_name text;
  worker_listing public.workers%rowtype;
  status_changed boolean;
  rating_changed boolean;
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.client_id is distinct from auth.uid() then
      raise exception 'La solicitud debe pertenecer al usuario autenticado';
    end if;

    select role, full_name into requester_role, requester_name
    from public.profiles
    where id = auth.uid();

    if requester_role is distinct from 'client' then
      raise exception 'Solo una cuenta cliente puede crear una solicitud';
    end if;
    new.client_name := coalesce(requester_name, '');

    if new.scheduled_at < now() or new.price < 0 then
      raise exception 'La fecha y el presupuesto de la solicitud no son válidos';
    end if;

    new.status := 'requested';
    new.rating := null;
    new.review := null;
    new.created_at := now();

    if new.worker_id is not null then
      select w.* into worker_listing
      from public.workers w
      where w.profile_id = new.worker_id
        and w.category <> ''
        and w.subcategory <> ''
        and w.city <> ''
        and public.is_worker_account(w.profile_id)
      for share;

      if not found then
        raise exception 'El trabajador no tiene una ficha pública elegible';
      end if;

      new.worker_name := worker_listing.name;
      new.worker_phone := worker_listing.phone;
      new.category := worker_listing.category;
    else
      new.worker_name := '';
      new.worker_phone := null;
    end if;

    return new;
  end if;

  if (to_jsonb(new) - array['status', 'rating', 'review'])
      is distinct from
     (to_jsonb(old) - array['status', 'rating', 'review']) then
    raise exception 'Los datos principales de una solicitud no se pueden cambiar';
  end if;

  status_changed := new.status is distinct from old.status;
  rating_changed := new.rating is distinct from old.rating
    or new.review is distinct from old.review;

  if status_changed and rating_changed then
    raise exception 'Actualiza el estado y la reseña en operaciones separadas';
  end if;

  if status_changed then
    if (old.status = 'requested' and new.status = 'accepted'
        and auth.uid() = old.worker_id)
       or (old.status = 'accepted' and new.status = 'in_progress'
        and auth.uid() = old.worker_id)
       or (old.status = 'in_progress' and new.status = 'completed'
        and auth.uid() = old.worker_id)
       or (new.status = 'cancelled'
        and old.status in ('requested', 'accepted', 'in_progress')
        and auth.uid() in (old.client_id, old.worker_id)) then
      return new;
    end if;

    raise exception 'Transición de estado no permitida para este participante';
  end if;

  if rating_changed then
    if auth.uid() is distinct from old.client_id
       or old.status <> 'completed'
       or old.rating is not null
       or new.rating is null
       or new.rating < 1
       or new.rating > 5
       or length(coalesce(new.review, '')) > 1000 then
      raise exception 'Solo el cliente puede calificar una vez un trabajo completado';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists jobs_guard_write on public.jobs;
create trigger jobs_guard_write
  before insert or update on public.jobs
  for each row execute function public.guard_job_write();

-- A worker cannot accept two active jobs for the exact same appointment time.
do $$
begin
  if exists (
    select 1
    from public.jobs
    where worker_id is not null
      and status in ('accepted', 'in_progress')
    group by worker_id, scheduled_at
    having count(*) > 1
  ) then
    raise exception 'Hay citas activas duplicadas; resuélvelas antes de aplicar la migración';
  end if;
end;
$$;

create unique index if not exists jobs_active_worker_slot_unique
  on public.jobs (worker_id, scheduled_at)
  where worker_id is not null and status in ('accepted', 'in_progress');

-- Event records are append-only and must match the current job state.
drop policy if exists "job_events_update_own" on public.job_events;

create or replace function public.validate_job_event()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  current_status text;
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  select j.status into current_status
  from public.jobs j
  where j.id = new.job_id
    and auth.uid() in (j.client_id, j.worker_id);

  if not found or new.status is distinct from current_status then
    raise exception 'El evento debe coincidir con el estado actual de tu trabajo';
  end if;

  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists job_events_validate on public.job_events;
create trigger job_events_validate
  before insert or update on public.job_events
  for each row execute function public.validate_job_event();

-- Reviews can only describe a completed job and must agree with its rating.
do $$
begin
  if exists (
    select 1
    from public.reviews
    where job_id is not null
    group by job_id
    having count(*) > 1
  ) then
    raise exception 'Hay reseñas duplicadas por trabajo; resuélvelas antes de aplicar la migración';
  end if;
end;
$$;

create unique index if not exists reviews_one_per_job
  on public.reviews (job_id)
  where job_id is not null;

create or replace function public.validate_review()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if auth.uid() is null
     or new.client_id is distinct from auth.uid()
     or length(coalesce(new.comment, '')) > 1000
     or not exists (
       select 1
       from public.jobs j
       where j.id = new.job_id
         and j.client_id = auth.uid()
         and j.worker_id = new.worker_id
         and j.status = 'completed'
         and j.rating = new.rating
         and j.review is not distinct from new.comment
     ) then
    raise exception 'La reseña debe corresponder a un trabajo completado por ti';
  end if;

  new.created_at := now();
  return new;
end;
$$;

create or replace function public.refresh_worker_rating()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_worker_id uuid := case when tg_op = 'DELETE' then old.worker_id else new.worker_id end;
  previous_managed_write text;
begin
  select current_setting('mano_ya.server_managed_write', true)
  into previous_managed_write;
  perform set_config('mano_ya.server_managed_write', 'on', true);

  update public.workers w
  set rating = coalesce((
        select round(avg(r.rating), 2)
        from public.reviews r
        where r.worker_id = target_worker_id
      ), 0),
      reviews_count = (
        select count(*)::integer
        from public.reviews r
        where r.worker_id = target_worker_id
      )
  where w.profile_id = target_worker_id;

  perform set_config(
    'mano_ya.server_managed_write',
    coalesce(previous_managed_write, ''),
    true
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists reviews_refresh_worker_rating on public.reviews;
create trigger reviews_refresh_worker_rating
  after insert or delete on public.reviews
  for each row execute function public.refresh_worker_rating();

drop trigger if exists reviews_validate on public.reviews;
create trigger reviews_validate
  before insert or update on public.reviews
  for each row execute function public.validate_review();

drop policy if exists "reviews_select_public" on public.reviews;
drop policy if exists "reviews_select_participants" on public.reviews;
create policy "reviews_select_participants"
  on public.reviews for select
  using (auth.uid() = client_id or auth.uid() = worker_id);

drop policy if exists "reviews_update_own" on public.reviews;
drop policy if exists "reviews_delete_own" on public.reviews;

-- Reporters may submit and read their reports, but cannot change their status
-- or notification metadata from the client.
drop policy if exists "reports_own" on public.reports;
drop policy if exists "reports_select_own" on public.reports;
create policy "reports_select_own"
  on public.reports for select
  using (auth.uid() = reporter_id);

drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

create or replace function public.validate_report_submission()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  reporter_name text;
  reporter_email text;
  target_name text;
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if auth.uid() is null or new.reporter_id is distinct from auth.uid()
     or length(btrim(new.reason)) not between 1 and 200
     or length(coalesce(new.details, '')) > 5000 then
    raise exception 'El reporte no cumple los requisitos de envío';
  end if;

  select p.full_name, u.email
  into reporter_name, reporter_email
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = auth.uid();

  if not found then
    raise exception 'No se encontró el perfil del usuario reportante';
  end if;

  new.reporter_name := coalesce(reporter_name, '');
  new.reporter_email := coalesce(reporter_email, '');
  new.status := 'abierto';
  new.severity := 'normal';
  new.notified_at := null;
  new.created_at := now();

  if new.target_user_id is not null then
    select p.full_name into target_name
    from public.profiles p
    where p.id = new.target_user_id;
    if not found then
      raise exception 'El usuario reportado no existe';
    end if;
    new.target_name := coalesce(target_name, '');
  end if;

  if new.job_id is not null and not exists (
    select 1
    from public.jobs j
    where j.id = new.job_id
      and auth.uid() in (j.client_id, j.worker_id)
      and (
        new.target_user_id is null
        or new.target_user_id in (j.client_id, j.worker_id)
      )
  ) then
    raise exception 'El servicio indicado no está relacionado con tu cuenta';
  end if;

  return new;
end;
$$;

drop trigger if exists reports_validate_submission on public.reports;
create trigger reports_validate_submission
  before insert on public.reports
  for each row execute function public.validate_report_submission();
revoke all on function public.validate_report_submission() from public, anon, authenticated;

-- Charge creation and status changes must follow the linked job participants.
create or replace function public.guard_charge_write()
returns trigger
language plpgsql
set search_path = pg_catalog, public, auth
as $$
declare
  linked_job public.jobs%rowtype;
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.worker_id is distinct from auth.uid()
       or new.job_id is null then
      raise exception 'Solo el trabajador del servicio puede solicitar el cobro';
    end if;

    select j.* into linked_job
    from public.jobs j
    where j.id = new.job_id
      and j.worker_id = auth.uid()
      and j.client_id = new.client_id
      and j.status in ('in_progress', 'completed');

    if not found then
      raise exception 'El cobro debe estar asociado a un servicio válido';
    end if;

    new.status := 'pending';
    new.paid_at := null;
    new.receipt_path := null;
    new.worker_name := linked_job.worker_name;
    new.client_name := linked_job.client_name;
    new.created_at := now();
    return new;
  end if;

  if (to_jsonb(new) - array['status', 'paid_at', 'receipt_path'])
      is distinct from
     (to_jsonb(old) - array['status', 'paid_at', 'receipt_path']) then
    raise exception 'Los datos principales del cobro no se pueden cambiar';
  end if;

  if old.status = 'pending'
     and new.status = 'client_notified'
     and auth.uid() = old.client_id then
    new.paid_at := null;
    new.receipt_path := old.receipt_path;
    return new;
  end if;

  if old.status = 'client_notified'
     and new.status = 'paid'
     and auth.uid() = old.worker_id then
    new.paid_at := now();
    return new;
  end if;

  raise exception 'Transición de cobro no permitida para este participante';
end;
$$;

drop trigger if exists charges_guard_write on public.charges;
create trigger charges_guard_write
  before insert or update on public.charges
  for each row execute function public.guard_charge_write();

drop policy if exists "charges_insert_worker" on public.charges;
create policy "charges_insert_worker"
  on public.charges for insert
  with check (auth.uid() = worker_id);

-- Internal settings hold webhook destinations and shared secrets.
alter table public.app_settings enable row level security;
revoke all on table public.app_settings from public, anon, authenticated;
drop policy if exists "app_settings_deny_client_access" on public.app_settings;

revoke all on function public.run_maintenance() from public, anon, authenticated;
grant execute on function public.run_maintenance() to postgres, service_role;
revoke all on function public.notify_new_report() from public, anon, authenticated;

-- Updates must not move an owned object into another user's folder.
drop policy if exists "storage_update_avatars" on storage.objects;
create policy "storage_update_avatars"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_update_portfolios" on storage.objects;
create policy "storage_update_portfolios"
  on storage.objects for update
  using (
    bucket_id = 'portfolios'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'portfolios'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('avatars', 'portfolios');

-- Server-side quota for the optional AI recommendation edge function.
create table if not exists public.ai_request_limits (
  user_id uuid primary key references auth.users (id) on delete cascade,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0 check (request_count >= 0)
);

alter table public.ai_request_limits enable row level security;
revoke all on table public.ai_request_limits from public, anon, authenticated;

create or replace function public.consume_ai_recommendation_quota()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  current_user_id uuid := auth.uid();
  current_count integer;
begin
  if current_user_id is null then
    raise exception 'Se requiere una sesión autenticada';
  end if;

  insert into public.ai_request_limits (user_id, window_started_at, request_count)
  values (current_user_id, now(), 1)
  on conflict (user_id) do update
    set window_started_at = case
          when public.ai_request_limits.window_started_at < now() - interval '1 hour'
            then now()
          else public.ai_request_limits.window_started_at
        end,
        request_count = case
          when public.ai_request_limits.window_started_at < now() - interval '1 hour'
            then 1
          else public.ai_request_limits.request_count + 1
        end
  returning request_count into current_count;

  return current_count <= 20;
end;
$$;

revoke all on function public.consume_ai_recommendation_quota() from public, anon;
grant execute on function public.consume_ai_recommendation_quota() to authenticated;
