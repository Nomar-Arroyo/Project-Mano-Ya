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
-- 2. Perfiles sintéticos de demostración para el catálogo.
-- No son proveedores reales: no incluyen teléfonos, reseñas ni verificaciones.
-- ---------------------------------------------------------------------
insert into public.workers (
  name, category, subcategory, city, bio, phone,
  rating, reviews_count, identity_verified, work_guaranteed,
  status, latitude, longitude
)
select
  seed.name, seed.category, seed.subcategory, seed.city, seed.bio, seed.phone,
  seed.rating, seed.reviews_count, false, false,
  seed.status, seed.latitude, seed.longitude
from (
  values
    (
      'Demo - Albañilería', 'Construcción', 'Albañilería', 'Caracas, Distrito Capital',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.48, -66.90
    ),
    (
      'Demo - Manicure', 'Belleza', 'Manicure', 'Maracay, Aragua',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.25, -67.60
    ),
    (
      'Demo - Electricidad', 'Mantenimiento', 'Electricidad', 'Valencia, Carabobo',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.16, -68.01
    ),
    (
      'Demo - Costura', 'Costura', 'Costura', 'Caracas, Distrito Capital',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.48, -66.90
    ),
    (
      'Demo - Mecánica', 'Automotriz', 'Mecánica', 'Barquisimeto, Lara',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.07, -69.32
    ),
    (
      'Demo - Eventos', 'Eventos', 'Decoración', 'Maracaibo, Zulia',
      'Perfil sintético para demostración. No representa a un proveedor real.',
      null::text, 0::numeric, 0, 'available', 10.64, -71.61
    )
) as seed(
  name, category, subcategory, city, bio, phone,
  rating, reviews_count, status, latitude, longitude
)
where not exists (
  select 1 from public.workers w
  where w.name = seed.name and w.city = seed.city
);
