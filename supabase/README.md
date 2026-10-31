# Base de datos de Mano Ya (Supabase)

Esta carpeta contiene el esquema de la base de datos y los datos iniciales del
proyecto `waxypsqomsljcljdqwra`.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `migrations/20240101000000_init_schema.sql` | Tablas, índices, políticas RLS, triggers y buckets de Storage. |
| `migrations/20240101000100_seed_catalogo.sql` | Catálogo y perfiles sintéticos, sin teléfonos ni reseñas inventadas. |
| `migrations/20240101000200_reportes_y_automatizacion.sql` | Reportes, notificación y mantenimiento. |
| `migrations/20240101000300_workers_perfil_unico.sql` | Una ficha de catálogo por perfil. |
| `migrations/20240101000400_historial_trabajos.sql` | Escritura del historial de servicios. |
| `migrations/20240101000500_webhook_secret.sql` | Secreto del webhook de reportes. |
| `migrations/20261025000000_backend_security_and_booking.sql` | Protección de datos, catálogo, citas, cobros, reportes, Storage y cuota de IA. |
| `migrations/20261029000000_add_422_mobile_prefix.sql` | Acepta el prefijo móvil venezolano `422` al normalizar teléfonos. |
| `migrations/20261029000100_terms_acceptances.sql` | Guarda las aceptaciones del acuerdo en un registro de auditoría de solo lectura para el usuario. |
| `migrations/20261031000000_worker_profile_details.sql` | Añade especialidad y coordenadas aproximadas al perfil privado del trabajador. |
| `migrations/20261031000100_persist_job_charges.sql` | Persiste cobros asociados a trabajos y valida notificación/confirmación atómica de cuotas. |
| `functions/accept-terms/index.ts` | Valida la sesión y guarda versión, hora, IP disponible e identificador del usuario al aceptar. |
| `functions/recommend-workers/index.ts` | Clasifica solicitudes con Ollama y ordena trabajadores por disponibilidad y distancia calculada desde coordenadas. |
| `functions/send-worker-contact-card/index.ts` | Envía por Resend la ficha privada del trabajador al cliente autenticado que lo contacta. |

## Cómo aplicarlo

**Supabase CLI (recomendado)**

```bash
supabase link --project-ref waxypsqomsljcljdqwra
supabase db push
```

No ejecutes de nuevo manualmente migraciones ya aplicadas. La migración de
seguridad revisa si hay citas activas duplicadas en el mismo instante; si las
encuentra se detiene y requiere una resolución revisada, no borra registros.
La restricción solo evita dos trabajos aceptados/en curso con la misma fecha y
hora exacta; no modela duración ni rangos de solapamiento porque el esquema
actual no define la duración de los servicios.

La migración `20261029000000_add_422_mobile_prefix.sql` actualiza la función de
normalización para admitir los móviles con prefijo `422`. Para que el registro
los acepte en el proyecto remoto, aplica las migraciones pendientes con
`supabase db push` desde una CLI autenticada y enlazada al proyecto.

La aplicación exige aceptar los términos al crear una cuenta. El inicio de
sesión no vuelve a solicitar esa aceptación. Para activar el registro auditable
en el backend, aplica la migración y despliega la función:

```bash
supabase db push
supabase functions deploy accept-terms
```

La función obtiene el `user_id` y la hora del servidor; guarda la IP solo si el
proxy entrega ese dato. Conserva un registro por usuario y versión; los usuarios autenticados solo
pueden leer sus propios registros y las filas no se pueden modificar ni borrar
mediante las operaciones normales de la base de datos.

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

- `profiles` contiene datos privados de pago y solo se puede leer por su dueño;
  la ficha pública se obtiene desde `workers`.
- `workers` publica únicamente perfiles vinculados a una cuenta trabajadora y
  con oficio, subcategoría y ciudad. El usuario no puede asignarse insignias,
  valoraciones o contadores de reseñas.
- Los teléfonos aceptados al crear o actualizar perfiles se normalizan a
  E.164 (`+584...`) y se validan como móviles venezolanos.
- Los trabajos y cobros validan en PostgreSQL quién puede crearlos o avanzar
  sus estados. Los cobros se crean desde trabajos asignados al trabajador y
  solo los RPC autorizados pueden crear, notificar o confirmar cuotas. Las
  reseñas se limitan a un trabajo completado y una reseña por trabajo.
- `app_settings` está bloqueada para `anon` y `authenticated`; el secreto del
  webhook solo lo usa el trigger de servidor.
- Los buckets `avatars` y `portfolios` son públicos para lectura. Las escrituras
  quedan limitadas al directorio del usuario, a imágenes JPEG/PNG/WebP y 10 MB.
- Las ubicaciones de catálogo se redondean a dos decimales (~1 km) para no
  publicar coordenadas precisas.
- Los perfiles sintéticos de la migración de catálogo están rotulados como demo,
  no tienen teléfono ni reseñas y no se recomiendan como proveedores reales.
- Los perfiles nuevos de trabajadores deben incluir oficio, especialidad y una
  zona seleccionada con coordenadas. El catálogo no usa datos sintéticos si una
  consulta real a Supabase falla.
- No se ejecutó ninguna migración contra una base remota desde este cambio.

### Asistente con Ollama (opcional)

La función `recommend-workers` requiere que Ollama sea accesible desde la red
de Supabase Edge Functions. No uses la dirección `localhost` de una computadora
ni expongas el servidor de Ollama a Internet. Configura una instancia privada o
un endpoint HTTPS protegido y guarda únicamente su URL y el nombre del modelo
como secretos de Edge Functions:

```bash
supabase secrets set OLLAMA_BASE_URL=https://ollama.example.internal OLLAMA_MODEL=llama3.1
supabase secrets set APP_ORIGIN=https://project-mano-ya-web.vercel.app
supabase functions deploy recommend-workers
```

La función requiere una sesión autenticada, limita las solicitudes a 20 por
usuario por hora y usa Ollama solo para interpretar la categoría. El cliente
debe seleccionar una zona; el servidor calcula distancias con coordenadas de
trabajadores y prioriza disponibilidad. Las coordenadas no se envían a Ollama.

La migración crea el RPC de cuota `consume_ai_recommendation_quota`. Aplica la
migración antes de desplegar la función. Si Ollama no está configurado, la
función responde `503`; no simula recomendaciones.

### Ficha del trabajador por correo

La función `send-worker-contact-card` solo permite solicitudes autenticadas de
cuentas cliente. Valida la sesión antes de leer los datos privados de cobro y
envía la ficha al correo de esa misma cuenta. Para activarla, configura en
Supabase Edge Function Secrets `RESEND_API_KEY`, `RESEND_FROM_EMAIL`,
`APP_ORIGIN` y `WEB_APP_URL`, y despliega:

```bash
supabase functions deploy send-worker-contact-card
```

`RESEND_FROM_EMAIL` debe pertenecer a un dominio verificado en Resend.
`ANDROID_APK_URL` es opcional: si hay una descarga Android pública por HTTPS,
la función la incluirá junto al enlace web.
`SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_ANON_KEY` se proporcionan al runtime de
Supabase; no los incluyas en Flutter ni en el repositorio. Si el envío no está
configurado o falla, la app informa el error y aun así permite abrir WhatsApp.

### Cobros persistentes

El trabajador crea el cobro desde un trabajo propio aceptado, en curso o
completado. La base de datos deriva el cliente y su correo del trabajo/cuenta;
no confía en un nombre o destinatario escrito en el formulario. La creación y
cada transición de pago se ejecutan mediante RPC transaccionales que validan el
rol del usuario y procesan una cuota a la vez. Aplica la migración nueva antes
de usar estos flujos en producción.

### MFA y OAuth

La aplicación usa factores TOTP nativos de Supabase Auth. La política de nivel
de aseguramiento (AAL) y los proveedores OAuth deben configurarse y verificarse
en el Dashboard de Supabase y Google Cloud Console, incluidos los redirect URLs
de producción. Este repositorio no tiene acceso a esas consolas y no contiene
una implementación de MFA por correo; no se debe presentar un código enviado
por correo como MFA sin validación y control de un solo uso en servidor.
