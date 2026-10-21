-- =====================================================================
-- Mano Ya · Datos iniciales (catálogo de oficios y trabajadores demo)
-- ---------------------------------------------------------------------
-- Se ejecuta después de 20240101000000_init_schema.sql.
-- Es idempotente: se puede volver a ejecutar sin duplicar registros.
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
      'Carlos Ramírez', 'Construcción', 'Albañil', 'Cali, Valle del Cauca',
      'Maestro de obra con 15 años de experiencia en mampostería, pañetes y acabados. Trabajos garantizados y puntuales.',
      '+57 300 111 2233', 4.80, 42, 'available', 3.4516, -76.5320
    ),
    (
      'Ana Torres', 'Belleza', 'Manicure', 'Palmira, Valle del Cauca',
      'Especialista en uñas acrílicas, semipermanentes y diseños personalizados. Atención a domicilio.',
      '+57 300 222 3344', 4.90, 28, 'available', 3.5394, -76.3036
    ),
    (
      'Luis Pérez', 'Mantenimiento', 'Electricista', 'Cali, Valle del Cauca',
      'Instalaciones eléctricas residenciales, tableros y certificados RETIE.',
      '+57 300 333 4455', 4.70, 15, 'busy', 3.4370, -76.5225
    ),
    (
      'María López', 'Costura', 'Modista', 'Cali, Valle del Cauca',
      'Confección y arreglo de prendas, diseños a medida y servicios de modistería rápida.',
      '+57 300 444 5566', 4.90, 36, 'available', 3.4370, -76.5225
    ),
    (
      'Jorge Silva', 'Automotriz', 'Mecánico', 'Palmira, Valle del Cauca',
      'Mecánica general, revisión de frenos, suspensión y mantenimiento preventivo a domicilio.',
      '+57 300 555 6677', 4.60, 21, 'available', 3.5394, -76.3036
    ),
    (
      'Diana Ruiz', 'Eventos', 'Decoración', 'Cali, Valle del Cauca',
      'Decoración de eventos, montajes temáticos, globos y ambientación de fiestas.',
      '+57 300 666 7788', 4.80, 19, 'busy', 3.4516, -76.5320
    )
) as seed(
  name, category, subcategory, city, bio, phone,
  rating, reviews_count, status, latitude, longitude
)
where not exists (
  select 1 from public.workers w
  where w.name = seed.name and w.city = seed.city
);
