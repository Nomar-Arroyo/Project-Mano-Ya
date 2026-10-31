-- Store worker listing details on the private profile for reliable syncing.
alter table public.profiles
  add column if not exists subcategory text not null default '',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;
