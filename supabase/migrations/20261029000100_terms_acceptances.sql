-- Keeps an append-only audit record for each acceptance of the current
-- Terms and Conditions version. Writes are performed by the accept-terms
-- Edge Function using the service role; users can only read their own rows.
create table if not exists public.terms_acceptances (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  terms_version text not null,
  accepted_at timestamptz not null default now(),
  ip_address inet,
  user_agent text not null default ''
);

create unique index if not exists terms_acceptances_user_version_uidx
  on public.terms_acceptances (user_id, terms_version);

alter table public.terms_acceptances enable row level security;

revoke all on table public.terms_acceptances from anon, authenticated;
grant select on table public.terms_acceptances to authenticated;
grant select, insert on table public.terms_acceptances to service_role;
grant usage, select on sequence public.terms_acceptances_id_seq to service_role;

drop policy if exists terms_acceptances_read_own
  on public.terms_acceptances;
create policy terms_acceptances_read_own
  on public.terms_acceptances
  for select
  to authenticated
  using (auth.uid() = user_id);

comment on table public.terms_acceptances is
  'Append-only audit records for accepted terms versions; written by the accept-terms Edge Function.';

create or replace function public.prevent_terms_acceptance_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  raise exception 'Terms acceptance audit records cannot be modified or deleted';
end;
$$;

drop trigger if exists terms_acceptances_are_immutable
  on public.terms_acceptances;
create trigger terms_acceptances_are_immutable
  before update or delete on public.terms_acceptances
  for each row execute function public.prevent_terms_acceptance_mutation();
