-- =====================================================================
-- Mano Ya · Política de escritura en el historial de trabajos
-- ---------------------------------------------------------------------
-- La app registra cada cambio de estado del trabajo en `job_events`
-- (solicitud -> aceptación -> ejecución -> pago). La tabla solo tenía
-- permiso de lectura, así que la escritura era rechazada por RLS y el
-- historial nunca se guardaba.
--
-- Ahora los dos participantes del trabajo pueden añadir eventos, y solo
-- sobre trabajos en los que están dentro.
-- =====================================================================

drop policy if exists "job_events_insert_participants" on public.job_events;
create policy "job_events_insert_participants"
  on public.job_events for insert
  with check (
    exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (j.client_id = auth.uid() or j.worker_id = auth.uid())
    )
  );

-- El cliente y el trabajador pueden corregir la nota de un evento propio.
drop policy if exists "job_events_update_own" on public.job_events;
create policy "job_events_update_own"
  on public.job_events for update
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (j.client_id = auth.uid() or j.worker_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (j.client_id = auth.uid() or j.worker_id = auth.uid())
    )
  );
