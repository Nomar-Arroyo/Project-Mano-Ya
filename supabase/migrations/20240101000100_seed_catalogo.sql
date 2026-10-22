-- =====================================================================
-- Mano Ya · Datos iniciales (catálogo de oficios y trabajadores demo)
-- ---------------------------------------------------------------------
-- Se ejecuta después de 20240101000000_init_schema.sql.
-- Es idempotente: se puede volver a ejecutar sin duplicar registros.
--
-- El catálogo está dirigido a Venezuela: ciudades, coordenadas y
-- teléfonos usan el prefijo +58.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Los 6 oficios del catálogo de Mano Ya
-- ---------------------------------------------------------------------
insert into public.categories (slug, name, description, color, position)
values
  ('construccion', 'Construcción', 'Albañilería, acabados y remodelaciones', '#F97316', 1),
  ('belleza', 'Belleza', 'Peluquería, uñas y cuidado personal', '#EC4899', 2),
  ('costura', 'Costura', 'Confección, arreglos y diseño de prendas', '#8B5CF6', 3),
  ('mantenimiento', 'Mantenimiento', 'Electricidad, plomería y mantenimiento en general', '#2563EB', 4),
  ('automotriz', 'Automotriz', 'Mecánica, revisar y mantenimiento vehicular', '#0EA5E9', 5),
  ('eventos', 'Eventos', 'Decoración, ambienceación y organización de eventos', '#10B981', 6)
on conflict (slug) do update
  set name = excluded.name,
      description = excluded.description,
      color = excluded.color,
      position = excluded.position;

-- ---------------------------------------------------------------------
-- 2. Trabajadores de ejemplo para el catálogo
-- ---------------------------------------------------------------------
insert into public.workers (
  name, category, subcategory, city, bio, phone,
  rating, reviews_count, identity_verified, work_guaranteed,
  status, latitude, longitude
)
select
  seed.name, seed.category, seed.subcategory, seed.city, seed.bio, seed.phone,
  seed.rating, seed.reviews_count, true, true,
  seed.status, seed.latitude, seed.longitude
from (
  values
    (
      'Carlos Ramírez', 'Construcción', 'Albañil', 'Caracas, Distrito Capital',
      'Maestro de obra con 15 años de experiencia en mampostería, pañetes y acabados. Trabajos garantizados y puntuales.',
      '+58 412 111 2233', 4.80, 42, 'available', 10.4806, -66.9036
    ),
    (
      'Ana Torres', 'Belleza', 'Manicure', 'Maracay, Aragua',
      'Especialista en uñas acrílicas, semipermanentes y diseños personalizados. Atención a domicilio.',
      '+58 412 222 3344', 4.90, 28, 'available', 10.2469, -67.5958
    ),
    (
      'Luis Pérez', 'Mantenimiento', 'Electricista', 'Valencia, Carabobo',
      'Instalaciones eléctricas residenciales, tableros y certificados.',
      '+58 414 333 4455', 4.70, 15, 'busy', 10.1620, -68.0077
    ),
    (
      'María López', 'Costura', 'Modista', 'Caracas, Distrito Capital',
      'Confección y arreglo de prendas, diseños a medida y servicios de modistería rápida.',
      '+58 416 444 5566', 4.90, 36, 'available', 10.4806, -66.9036
    ),
    (
      'Jorge Silva', 'Automotriz', 'Mecánico', 'Barquisimeto, Lara',
      'Mecánica general, revisión de frenos, suspensión y mantenimiento preventivo a domicilio.',
      '+58 424 555 6677', 4.60, 21, 'available', 10.0670, -69.3170
    ),
    (
      'Diana Ruiz', 'Eventos', 'Decoración', 'Maracaibo, Zulia',
      'Decoración de eventos, montajes temáticos, globos y ambientación de fiestas.',
      '+58 426 666 7788', 4.80, 19, 'busy', 10.6427, -71.6125
    )
) as seed(
  name, category, subcategory, city, bio, phone,
  rating, reviews_count, status, latitude, longitude
)
where not exists (
  select 1 from public.workers w
  where w.name = seed.name and w.city = seed.city
);

-- ---------------------------------------------------------------------
-- 3. Limpieza de fichas de ejemplo con datos de otros países
-- ---------------------------------------------------------------------
-- Si la base ya traía fichas de otra región, se quitan para que el
-- catálogo se vea coherente con Venezuela.
delete from public.workers
where city ilike '%Colombia%'
   or city ilike '%Valle del Cauca%'
   or phone like '+57%';
