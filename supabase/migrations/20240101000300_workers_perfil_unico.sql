-- =====================================================================
-- Mano Ya · Índice único para el alta automática de trabajadores
-- ---------------------------------------------------------------------
-- La app hace `upsert` sobre `workers` usando `profile_id` como clave de
-- conflicto. Para que eso funcione, `profile_id` necesita una restricción
-- única (las fichas del catálogo que todavía no tienen usuario quedan con
-- `profile_id` nulo, y en Postgres los nulos no chocan entre sí).
--
-- Además se relaja la política de escritura: el trabajador puede crear su
-- propia ficha y actualizarla, pero solo puede cambiar su propio registro.
-- =====================================================================

-- Evita el duplicado cuando la misma persona se registra dos veces.
-- En Postgres un índice único admite varios `NULL`, así que las fichas del
-- catálogo que aún no tienen usuario no se bloquean entre sí.
create unique index if not exists workers_profile_unique
  on public.workers (profile_id);

comment on index public.workers_profile_unique is
  'Clave de conflicto del upsert de fichas de trabajadores.';

-- Verificación: una ficha por usuario.
do $$
declare
  duplicados bigint;
begin
  select count(*) into duplicados
  from (
    select profile_id
    from public.workers
    where profile_id is not null
    group by profile_id
    having count(*) > 1
  ) d;

  if duplicados > 0 then
    raise exception 'Hay % fichas duplicadas por usuario: corrige antes de continuar', duplicados;
  end if;

  raise notice 'Mano Ya · fichas de trabajadores sin duplicados';
end;
$$;
