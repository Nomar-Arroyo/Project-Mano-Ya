-- Persist charges against a real job and keep payment transitions atomic.

drop policy if exists "charges_insert_worker" on public.charges;
drop policy if exists "charges_update_participants" on public.charges;

create or replace function public.create_charge_with_installments(
  p_job_id uuid,
  p_concept text,
  p_total numeric,
  p_bank_info text,
  p_installment_count integer,
  p_spacing_days integer
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_job public.jobs%rowtype;
  v_worker_name text;
  v_client_name text;
  v_client_email text;
  v_charge_id uuid;
  v_total numeric(12, 2);
  v_installment_amount numeric(12, 2);
  v_accumulated numeric(12, 2) := 0;
  v_index integer;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión para crear un cobro';
  end if;
  if p_concept is null or length(btrim(p_concept)) not between 1 and 200 then
    raise exception 'El concepto debe tener entre 1 y 200 caracteres';
  end if;
  if p_bank_info is null or length(btrim(p_bank_info)) not between 1 and 1000 then
    raise exception 'Los datos de pago deben tener entre 1 y 1000 caracteres';
  end if;
  if p_total is null or p_total <= 0 or p_total > 9999999999.99 then
    raise exception 'El monto del cobro no es válido';
  end if;
  if p_installment_count is null
     or p_installment_count not in (1, 2, 4)
     or p_spacing_days is null
     or p_spacing_days not in (15, 30) then
    raise exception 'El plan de cuotas no es válido';
  end if;

  v_total := round(p_total, 2);
  if v_total <= 0 or (p_installment_count > 1 and v_total <= 800) then
    raise exception 'Las cuotas requieren un monto mayor a 800';
  end if;

  select *
  into v_job
  from public.jobs
  where id = p_job_id
    and worker_id = auth.uid()
  for share;
  if not found or v_job.status not in ('accepted', 'in_progress', 'completed') then
    raise exception 'El trabajo no está disponible para crear un cobro';
  end if;

  select nullif(btrim(full_name), '')
  into v_worker_name
  from public.profiles
  where id = auth.uid()
    and role = 'worker';
  if v_worker_name is null then
    raise exception 'La cuenta no tiene un perfil de trabajador válido';
  end if;

  select nullif(btrim(full_name), '')
  into v_client_name
  from public.profiles
  where id = v_job.client_id
    and role = 'client';
  if v_client_name is null then
    raise exception 'El trabajo no tiene un perfil de cliente válido';
  end if;

  select email
  into v_client_email
  from auth.users
  where id = v_job.client_id;

  insert into public.charges (
    concept,
    job_id,
    client_id,
    worker_id,
    worker_name,
    client_name,
    client_email,
    total,
    bank_info
  )
  values (
    btrim(p_concept),
    v_job.id,
    v_job.client_id,
    auth.uid(),
    v_worker_name,
    coalesce(nullif(btrim(v_job.client_name), ''), v_client_name),
    v_client_email,
    v_total,
    btrim(p_bank_info)
  )
  returning id into v_charge_id;

  for v_index in 1..p_installment_count loop
    v_installment_amount := case
      when v_index = p_installment_count then v_total - v_accumulated
      else round(v_total / p_installment_count, 2)
    end;
    v_accumulated := v_accumulated + v_installment_amount;

    insert into public.installments (
      charge_id,
      label,
      amount,
      due_date
    )
    values (
      v_charge_id,
      case
        when p_installment_count = 1 then 'Pago único'
        else 'Cuota ' || v_index
      end,
      v_installment_amount,
      current_date + (p_spacing_days * (v_index - 1))
    );
  end loop;

  return v_charge_id;
end;
$$;

create or replace function public.notify_charge_payment(p_charge_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_charge public.charges%rowtype;
begin
  select *
  into v_charge
  from public.charges
  where id = p_charge_id
  for update;
  if not found or v_charge.client_id is distinct from auth.uid() then
    raise exception 'El cobro no está disponible para esta cuenta';
  end if;
  if v_charge.status <> 'pending'
     or not exists (
       select 1
       from public.installments
       where charge_id = v_charge.id
         and not paid
     ) then
    raise exception 'Este cobro no está pendiente de notificación';
  end if;

  update public.charges
  set status = 'client_notified'
  where id = v_charge.id;
end;
$$;

create or replace function public.confirm_charge_payment(p_charge_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_charge public.charges%rowtype;
  v_installment_id uuid;
begin
  select *
  into v_charge
  from public.charges
  where id = p_charge_id
  for update;
  if not found or v_charge.worker_id is distinct from auth.uid() then
    raise exception 'El cobro no está disponible para esta cuenta';
  end if;
  if v_charge.status <> 'client_notified' then
    raise exception 'El cliente aún no ha reportado el pago';
  end if;

  select id
  into v_installment_id
  from public.installments
  where charge_id = v_charge.id
    and not paid
  order by due_date, id
  limit 1
  for update;
  if not found then
    raise exception 'No quedan cuotas pendientes por confirmar';
  end if;

  update public.installments
  set paid = true
  where id = v_installment_id;

  if exists (
    select 1
    from public.installments
    where charge_id = v_charge.id
      and not paid
  ) then
    update public.charges
    set status = 'pending',
        paid_at = null
    where id = v_charge.id;
  else
    update public.charges
    set status = 'paid',
        paid_at = now()
    where id = v_charge.id;
  end if;
end;
$$;

revoke all on function public.create_charge_with_installments(
  uuid, text, numeric, text, integer, integer
) from public, anon;
revoke all on function public.notify_charge_payment(uuid) from public, anon;
revoke all on function public.confirm_charge_payment(uuid) from public, anon;

grant execute on function public.create_charge_with_installments(
  uuid, text, numeric, text, integer, integer
) to authenticated;
grant execute on function public.notify_charge_payment(uuid) to authenticated;
grant execute on function public.confirm_charge_payment(uuid) to authenticated;
