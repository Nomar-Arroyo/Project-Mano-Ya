# Base de datos de Mano Ya (Supabase)

Esta carpeta contiene el esquema de la base de datos y los datos iniciales del
proyecto `waxypsqomsljcljdqwra`.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `migrations/20240101000000_init_schema.sql` | Tablas, índices, políticas RLS, triggers y buckets de Storage. |
| `migrations/20240101000100_seed_catalogo.sql` | Los 6 oficios del catálogo y los trabajadores de ejemplo. |

## Cómo aplicarlo

**Opción 1 · Supabase CLI (recomendado)**

```bash
supabase link --project-ref waxypsqomsljcljdqwra
supabase db push
```

**Opción 2 · Panel de Supabase**

1. Entrar al proyecto `waxypsqomsljcljdqwra` en <https://supabase.com/dashboard>.
2. Abrir **SQL Editor → New query**.
3. Pegar y ejecutar primero `20240101000000_init_schema.sql`.
4. Pegar y ejecutar después `20240101000100_seed_catalogo.sql`.

## Qué incluye el esquema

- `profiles`: perfil base del usuario (nombre, rol, contacto, bio y datos de cobro).
- `categories` y `workers`: catálogo público de oficios y fichas de trabajadores.
- `portfolio_items`: portafolio express (3 a 5 fotos) del trabajador.
- `saved_addresses`: direcciones/zonas guardadas del cliente.
- `favorites`: contratistas favoritos del cliente.
- `jobs`, `job_events`: servicios y su historial (solicitud → aceptación → ejecución → pago).
- `charges`, `installments`: cobros, cuotas e hitos de pago.
- `reviews`: calificaciones de los servicios completados.

## Seguridad

- Todas las tablas tienen **RLS** activado: cada usuario solo escribe en sus
  propias filas y solo ve los trabajos, cobros y cuotas en los que participa.
- El `role` (cliente/trabajador) no se puede cambiar desde la aplicación: solo
  un administrador del proyecto puede modificarlo.
- Los buckets `avatars` y `portfolios` son públicos para lectura, pero cada
  usuario solo puede escribir en la carpeta con su propio `user_id`.
