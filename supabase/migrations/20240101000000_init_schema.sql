-- =====================================================================
-- Mano Ya · Esquema inicial de la base de datos (Supabase/Postgres)
-- ---------------------------------------------------------------------
-- Este script crea las tablas del producto, activa las políticas de
-- seguridad por fila (RLS) y el trigger que crea el perfil de cada usuario
-- al registrarse.
--
-- Cómo aplicarlo:
--   Opción 1 (recomendada): Supabase CLI ->  supabase db push
--   Opción 2: panel de Supabase -> SQL Editor -> copiar y ejecutar
-- =====================================================================

-- Extensión para generar identificadores y comparar contraseñas de forma
-- segura dentro de la base de datos.
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. Tabla de perfiles (clientes y trabajadores)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role text not null default 'client' check (role in ('client', 'worker')),
  phone text,
  city text,
  avatar_url text,
  bio text,
  category text,
  -- Datos de cobro del trabajador (método de pago preferido).
  payout_method text,
  payout_account_holder text,
  payout_account_number text,
  payout_bank_name text,
  available_today boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil base de cada usuario: datos de contacto, rol y datos de cobro.';

-- ---------------------------------------------------------------------
-- 2. Portafolio express del trabajador (3 a 5 fotos)
-- ---------------------------------------------------------------------
create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.profiles (id) on delete cascade,
  image_url text not null,
  caption text not null default '',
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists portfolio_items_worker_idx
  on public.portfolio_items (worker_id, position);

-- ---------------------------------------------------------------------
-- 3. Direcciones/zonas guardadas del cliente
-- ---------------------------------------------------------------------
create table if not exists public.saved_addresses (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles (id) on delete cascade,
  label text not null default 'Dirección',
  address text not null,
  latitude double precision not null default 0,
  longitude double precision not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists saved_addresses_client_idx
  on public.saved_addresses (client_id);

-- ---------------------------------------------------------------------
-- 4. Contratistas favoritos del cliente
-- ---------------------------------------------------------------------
create table if not exists public.favorites (
  client_id uuid not null references public.profiles (id) on delete cascade,
  worker_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (client_id, worker_id)
);

-- ---------------------------------------------------------------------
-- 5. Catálogo de oficios y de trabajadores (ficha pública)
-- ---------------------------------------------------------------------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  color text not null default '#2563EB',
  position integer not null default 0
);

create table if not exists public.workers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles (id) on delete set null,
  name text not null,
  category text not null,
  subcategory text not null default '',
  city text not null default '',
  bio text,
  phone text,
  avatar_url text,
  rating numeric(3, 2) not null default 0,
  reviews_count integer not null default 0,
  identity_verified boolean not null default false,
  work_guaranteed boolean not null default true,
  status text not null default 'available'
    check (status in ('available', 'busy')),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create index if not exists workers_category_idx
  on public.workers (category);
create index if not exists workers_city_idx on public.workers (city);

-- ---------------------------------------------------------------------
-- 6. Trabajos (servicios) y su historial de estados
-- ---------------------------------------------------------------------
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  description text not null default '',
  client_id uuid not null references public.profiles (id) on delete cascade,
  client_name text not null default '',
  worker_id uuid references public.profiles (id) on delete set null,
  worker_name text not null default '',
  worker_phone text,
  address text not null default '',
  price numeric(12, 2) not null default 0,
  scheduled_at timestamptz not null,
  status text not null default 'requested'
    check (status in ('requested', 'accepted', 'in_progress', 'completed', 'cancelled')),
  rating numeric(3, 2),
  review text,
  created_at timestamptz not null default now()
);

create index if not exists jobs_client_idx on public.jobs (client_id);
create index if not exists jobs_worker_idx on public.jobs (worker_id);

-- Historial de los cuatro pasos del flujo:
-- solicitud -> aceptación -> ejecución -> pago.
create table if not exists public.job_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  status text not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists job_events_job_idx on public.job_events (job_id);

-- ---------------------------------------------------------------------
-- 7. Cobros, cuotas e hitos de pago
-- ---------------------------------------------------------------------
create table if not exists public.charges (
  id uuid primary key default gen_random_uuid(),
  concept text not null,
  job_id uuid references public.jobs (id) on delete set null,
  client_id uuid references public.profiles (id) on delete set null,
  worker_id uuid references public.profiles (id) on delete set null,
  worker_name text not null default '',
  client_name text not null default '',
  client_email text,
  total numeric(12, 2) not null default 0,
  bank_info text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'client_notified', 'paid')),
  receipt_path text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.installments (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.charges (id) on delete cascade,
  label text not null default 'Cuota',
  amount numeric(12, 2) not null default 0,
  due_date date not null default current_date,
  paid boolean not null default false
);

create index if not exists installments_charge_idx
  on public.installments (charge_id);

-- ---------------------------------------------------------------------
-- 8. Reseñas de los servicios completados
-- ---------------------------------------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs (id) on delete cascade,
  worker_id uuid references public.profiles (id) on delete cascade,
  client_id uuid references public.profiles (id) on delete cascade,
  rating numeric(3, 2) not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

-- =====================================================================
-- 9. Seguridad por fila (RLS)
-- =====================================================================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.saved_addresses enable row level security;
alter table public.favorites enable row level security;
alter table public.workers enable row level security;
alter table public.jobs enable row level security;
alter table public.job_events enable row level security;
alter table public.charges enable row level security;
alter table public.installments enable row level security;
alter table public.reviews enable row level security;

-- Perfiles: lectura pública (el catálogo muestra la ficha del trabajador),
-- escritura únicamente de la propia fila.
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public"
  on public.profiles for select
  using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Portafolio: lectura pública, escritura del propio trabajador.
drop policy if exists "portfolio_select_public" on public.portfolio_items;
create policy "portfolio_select_public"
  on public.portfolio_items for select
  using (true);

drop policy if exists "portfolio_insert_own" on public.portfolio_items;
create policy "portfolio_insert_own"
  on public.portfolio_items for insert
  with check (auth.uid() = worker_id);

drop policy if exists "portfolio_update_own" on public.portfolio_items;
create policy "portfolio_update_own"
  on public.portfolio_items for update
  using (auth.uid() = worker_id)
  with check (auth.uid() = worker_id);

drop policy if exists "portfolio_delete_own" on public.portfolio_items;
create policy "portfolio_delete_own"
  on public.portfolio_items for delete
  using (auth.uid() = worker_id);

-- Direcciones guardadas: solo las del propio cliente.
drop policy if exists "addresses_own" on public.saved_addresses;
create policy "addresses_own"
  on public.saved_addresses for all
  using (auth.uid() = client_id)
  with check (auth.uid() = client_id);

-- Favoritos: solo los del propio cliente.
drop policy if exists "favorites_own" on public.favorites;
create policy "favorites_own"
  on public.favorites for all
  using (auth.uid() = client_id)
  with check (auth.uid() = client_id);

-- Categorías: catálogo público de oficios.
drop policy if exists "categories_select_public" on public.categories;
create policy "categories_select_public"
  on public.categories for select
  using (true);

-- Catálogo: lectura pública y escritura del propio perfil.
drop policy if exists "workers_select_public" on public.workers;
create policy "workers_select_public"
  on public.workers for select
  using (true);

drop policy if exists "workers_insert_own" on public.workers;
create policy "workers_insert_own"
  on public.workers for insert
  with check (auth.uid() = profile_id);

drop policy if exists "workers_update_own" on public.workers;
create policy "workers_update_own"
  on public.workers for update
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

-- Trabajos: solo participan cliente y trabajador.
drop policy if exists "jobs_participants" on public.jobs;
create policy "jobs_participants"
  on public.jobs for select
  using (auth.uid() = client_id or auth.uid() = worker_id);

drop policy if exists "jobs_insert_client" on public.jobs;
create policy "jobs_insert_client"
  on public.jobs for insert
  with check (auth.uid() = client_id);

drop policy if exists "jobs_update_participants" on public.jobs;
create policy "jobs_update_participants"
  on public.jobs for update
  using (auth.uid() = client_id or auth.uid() = worker_id)
  with check (auth.uid() = client_id or auth.uid() = worker_id);

-- Historial del trabajo: visible para los participantes.
drop policy if exists "job_events_participants" on public.job_events;
create policy "job_events_participants"
  on public.job_events for select
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (j.client_id = auth.uid() or j.worker_id = auth.uid())
    )
  );

-- Cobros: solo el cliente y el trabajador del cobro.
drop policy if exists "charges_participants" on public.charges;
create policy "charges_participants"
  on public.charges for select
  using (auth.uid() = client_id or auth.uid() = worker_id);

drop policy if exists "charges_insert_worker" on public.charges;
create policy "charges_insert_worker"
  on public.charges for insert
  with check (auth.uid() = worker_id or auth.uid() = client_id);

drop policy if exists "charges_update_participants" on public.charges;
create policy "charges_update_participants"
  on public.charges for update
  using (auth.uid() = client_id or auth.uid() = worker_id)
  with check (auth.uid() = client_id or auth.uid() = worker_id);

-- Cuotas: visibles si el cobro es visible.
drop policy if exists "installments_participants" on public.installments;
create policy "installments_participants"
  on public.installments for select
  using (
    exists (
      select 1 from public.charges c
      where c.id = charge_id
        and (c.client_id = auth.uid() or c.worker_id = auth.uid())
    )
  );

-- Reseñas: lectura pública y escritura del cliente que Hire.
drop policy if exists "reviews_select_public" on public.reviews;
create policy "reviews_select_public"
  on public.reviews for select
  using (true);

drop policy if exists "reviews_insert_client" on public.reviews;
create policy "reviews_insert_client"
  on public.reviews for insert
  with check (auth.uid() = client_id);

-- =====================================================================
-- 10. Triggers: creación del perfil y fecha de actualización
-- =====================================================================

-- Crea la fila de perfil automáticamente al registrarse el usuario.
-- El rol inicial llega en los metadatos del registro (cliente o trabajador).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, phone, city, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    ),
    coalesce(new.raw_user_meta_data ->> 'role', 'client'),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'city',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Actualiza la fecha de modificación del perfil.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- El rol solo puede cambiar desde el panel de administración de Supabase.
-- Así el usuario no puede convertirse en trabajador por su cuenta.
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role
     and auth.role() is distinct from 'service_role' then
    raise exception 'El rol solo puede ser modificado por un administrador';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- =====================================================================
-- 11. Buckets de Storage para fotos de perfil y portafolio
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true), ('portfolios', 'portfolios', true)
on conflict (id) do nothing;

drop policy if exists "storage_read_avatars" on storage.objects;
create policy "storage_read_avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "storage_upload_avatars" on storage.objects;
create policy "storage_upload_avatars"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_update_avatars" on storage.objects;
create policy "storage_update_avatars"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_delete_avatars" on storage.objects;
create policy "storage_delete_avatars"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_read_portfolios" on storage.objects;
create policy "storage_read_portfolios"
  on storage.objects for select
  using (bucket_id = 'portfolios');

drop policy if exists "storage_upload_portfolios" on storage.objects;
create policy "storage_upload_portfolios"
  on storage.objects for insert
  with check (
    bucket_id = 'portfolios'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_update_portfolios" on storage.objects;
create policy "storage_update_portfolios"
  on storage.objects for update
  using (
    bucket_id = 'portfolios'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "storage_delete_portfolios" on storage.objects;
create policy "storage_delete_portfolios"
  on storage.objects for delete
  using (
    bucket_id = 'portfolios'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
