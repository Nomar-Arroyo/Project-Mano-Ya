# Informe técnico de Mano Ya

## 1. Alcance y estado de este informe

Este documento describe la implementación visible en el código fuente del proyecto, no solo las funciones que aparecen en la interfaz. Distingue entre persistencia conectada a Supabase, comportamiento local/de demostración e integraciones que requieren configuración externa.

El inventario inicial se hizo sobre el commit `813de7b`; la rama `main` avanzó desde entonces y la recuperación de contraseña ya forma parte de su historial. Esta publicación incorpora además la casilla obligatoria y el visor del acuerdo para registro, acceso por correo y Google.

Supabase CLI confirmó que las migraciones versionadas, incluida `20261029000100_terms_acceptances.sql`, están aplicadas en el proyecto enlazado, y que la Edge Function `accept-terms` está activa con validación JWT. El despliegue web se verifica por separado; las referencias a Vercel describen su configuración, no el estado de cada publicación.

## 2. Resumen ejecutivo

Mano Ya es una aplicación Flutter en español para conectar clientes con trabajadores de servicios en Venezuela. Contempla dos roles principales —cliente y trabajador—, catálogo y búsqueda de profesionales, perfiles, solicitudes de servicio, seguimiento del trabajo, reseñas, reportes y un flujo demostrativo de pagos móviles.

La aplicación combina:

- **Flutter y Dart** para la interfaz móvil y web.
- **Riverpod** para estado y proveedores.
- **go_router** para navegación.
- **Supabase Auth, Postgres, Row Level Security (RLS), Storage y Edge Functions** para las funciones conectadas al backend.
- Servicios opcionales para Google OAuth, geocodificación de OpenStreetMap/Nominatim, envío de reportes por correo y recomendaciones mediante Ollama.

Una distinción importante: **el flujo de pago móvil de la aplicación es demostrativo**. No ordena transferencias, no cobra dinero con Stripe ni con un banco y no envía por correo los reportes de pago. Asimismo, la capa de cobros convencional visible en la aplicación mantiene sus datos en memoria; que existan tablas de cobros en el esquema de Supabase no significa que ese flujo esté persistido allí.

## 3. Producto, roles y navegación

### Cliente

El cliente puede explorar trabajadores, filtrar el catálogo, consultar perfiles y portafolios, guardar favoritos y direcciones, crear solicitudes de servicio, revisar su historial y enviar reseñas o reportes cuando corresponda.

### Trabajador

El trabajador puede mantener su perfil profesional, oficio, zona, descripción, disponibilidad, portafolio y datos preferidos para recibir pagos. Puede consultar las solicitudes asociadas a sus servicios y gestionar su progreso según los estados implementados.

### Navegación

La navegación principal adapta las opciones al rol. Incluye Inicio, Perfil y las secciones contextuales del rol —por ejemplo, Catálogo para clientes y Cobros—. La aplicación tiene tema claro/oscuro y localización en español.

La autenticación y el rol activo condicionan el acceso a funciones. Cuando Supabase no está configurado, hay rutas de funcionamiento local y datos de demostración; estas rutas sirven para desarrollo y no equivalen a persistencia multiusuario en producción.

## 4. Arquitectura y componentes

El código sigue una organización por funcionalidades y capas:

- `lib/core`: configuración, rutas, servicios compartidos, tema y utilidades.
- `lib/features/<funcionalidad>/domain`: modelos y reglas de dominio.
- `lib/features/<funcionalidad>/data`: repositorios y acceso a datos.
- `lib/features/<funcionalidad>/presentation`: páginas, widgets y estado de interfaz.
- `supabase/migrations`: esquema, funciones SQL, políticas, triggers y cambios incrementales.
- `supabase/functions`: funciones de backend desplegables.
- `n8n`: documentación de automatizaciones para reportes.

`main.dart` inicializa Supabase y los servicios compartidos, restaura tema, sesión y disponibilidad, y después arranca la aplicación con Riverpod. La navegación está centralizada en el router de la aplicación.

Los repositorios actúan como frontera entre la interfaz y el origen de datos. Algunas funciones consultan Supabase cuando hay una sesión real; otras conservan almacenamiento en memoria o datos de muestra. En consecuencia, que una pantalla funcione en modo local no garantiza que sus cambios estén guardados en la base de datos.

## 5. Funciones y reglas de negocio

### 5.1 Registro, inicio de sesión y cuenta

El código contempla:

- Registro e inicio de sesión con correo y contraseña.
- Confirmación/verificación de correo mediante códigos y plantillas de Supabase.
- Inicio de sesión con Google OAuth, sujeto a que los identificadores de cliente de Google y la configuración correspondiente de Supabase coincidan.
- Restauración y cierre de sesión.
- MFA TOTP cuando está habilitado y configurado en Supabase.
- Validación de teléfonos móviles venezolanos, incluido el prefijo `422`.

El repositorio local también incluye una recuperación de contraseña en pasos de correo, código y contraseña nueva. Ese desarrollo estaba pendiente de publicar en el checkout inspeccionado y requiere que el proveedor de correo/plantillas y el flujo de recuperación de Supabase estén correctamente configurados. No debe asumirse que ya está disponible para usuarios en producción.

Existe la migración `20261030000000_fix_handle_new_user.sql`, destinada a reparar la creación de perfiles durante el alta. Que el archivo esté versionado no demuestra que la migración se haya aplicado en el proyecto remoto; su estado remoto debe comprobarse por separado.

### 5.2 Perfiles y catálogo

El perfil de trabajador agrupa datos de identidad pública, oficio, localidad, biografía, disponibilidad, valoración, portafolio y preferencias de cobro. El código contempla un portafolio de entre tres y cinco imágenes; las imágenes pueden residir en Supabase Storage o ser locales en modo demostración.

El catálogo admite filtros por oficio, localidad y disponibilidad. La aplicación también dispone de búsqueda/localización hiperlocal para Venezuela, geocodificación con Nominatim y cálculo de distancia mediante la fórmula de Haversine cuando hay coordenadas. El resultado depende de la disponibilidad del proveedor externo y de los datos de ubicación guardados.

Puede haber perfiles sintéticos de demostración. Deben distinguirse de trabajadores reales y no deben presentarse como verificados por el mero hecho de aparecer en el catálogo.

### 5.3 Solicitudes y ciclo del servicio

Las solicitudes incluyen trabajador, fecha o cita, ubicación y presupuesto/datos del trabajo. El ciclo de estados contemplado es:

1. `requested`: solicitud creada y pendiente.
2. `accepted`: solicitud aceptada.
3. `in_progress`: servicio en curso.
4. `completed`: trabajo terminado.
5. `cancelled`: solicitud cancelada.

Los cambios pueden generar eventos de historial. La reseña se condiciona a que el trabajo haya alcanzado el estado de completado. La posibilidad de crear una solicitud, y su persistencia, depende de la sesión y de la conexión del repositorio con Supabase; algunos flujos cuentan con respaldo local o de demostración.

### 5.4 Cobros convencionales

Hay modelos para cobros y cuotas/hitos, incluyendo modalidades de pago único o fraccionado, y se puede generar un recibo PDF. Sin embargo, el `BillingRepository` actual conserva los cobros **en memoria**. No debe interpretarse como una liquidación real ni como un registro persistente en Supabase, aunque el esquema contenga tablas relacionadas.

### 5.5 Pago móvil DEMO

El flujo de pagos móviles es una simulación explícita:

- Presenta datos ficticios del banco, documento y teléfono del trabajador.
- Requiere completar el paso simulado de pago antes de habilitar la marca de pago realizado.
- Genera referencias identificadas como `DEMO`.
- Muestra un reparto ilustrativo de 15 % para la plataforma y 85 % para el trabajador.
- Puede registrar mensajes en una bandeja de correo simulada para ambas partes.

No se conecta a bancos, no ejecuta transferencias, no valida una operación bancaria, no usa Stripe y no envía correos reales. Los datos y estados del flujo son de demostración/en memoria y no acreditan un pago real.

### 5.6 Reseñas, reportes y notificaciones

Las reseñas se vinculan al servicio y se limitan según el estado del trabajo. Los reportes de soporte tienen categorías, motivo, detalles y severidad; el repositorio contempla guardar reportes en `public.reports`.

Hay componentes de backend para notificar reportes: una función `notify-report` puede enviar correo mediante Resend, y un trigger/automatización puede conectarse a n8n. Para que el trayecto sea real hace falta desplegar y configurar la función, secretos y automatización. La bandeja que usa el pago DEMO es distinta y no equivale a ese servicio.

El servicio de notificaciones push presente en la aplicación es un stub; no hay una integración FCM activa que permita afirmar que se entregan notificaciones push a dispositivos.

### 5.7 Recomendaciones de trabajadores

La función `recommend-workers` requiere sesión Supabase válida. Valida la descripción, consulta categorías y trabajadores existentes, aplica un límite de uso de 20 solicitudes por usuario por hora y solicita a Ollama clasificar la necesidad. La selección final se basa en trabajadores reales del catálogo y los ordena con criterios como categoría, disponibilidad, localidad, valoración y reseñas.

Ollama es un servicio opcional externo. Si la función, la cuota, Supabase u Ollama no están configurados o disponibles, la recomendación puede fallar explícitamente; la aplicación no debe presentarla como una función garantizada en producción.

## 6. Datos y persistencia

El esquema de Supabase contempla, entre otras, estas entidades:

| Entidad | Propósito |
|---|---|
| `profiles` | Datos de cuenta y rol. |
| `workers` | Perfil profesional, oficio, ubicación, disponibilidad y valoración. |
| `categories` | Catálogo de oficios. |
| `portfolio_items` | Imágenes y descripciones del portafolio. |
| `saved_addresses` | Direcciones guardadas por clientes. |
| `favorites` | Trabajadores favoritos. |
| `jobs` | Solicitudes y servicios. |
| `job_events` | Historial de cambios del servicio. |
| `charges`, `installments` | Estructuras de cobros y cuotas disponibles en el esquema. |
| `reviews` | Reseñas asociadas a servicios. |
| `reports` | Reportes enviados por los usuarios. |
| `app_settings` | Configuración de la aplicación. |
| Tabla de cuota de IA | Control de solicitudes de recomendación. |

El esquema también incluye políticas RLS, triggers, funciones SQL y buckets de Storage para avatares y portafolios. La existencia de una tabla o una migración no confirma por sí sola que todos los repositorios de Flutter la usen, ni que cada migración esté aplicada en el backend remoto.

## 7. Seguridad y privacidad

- La autorización del backend se apoya en Supabase Auth y políticas RLS; la interfaz no debe ser la única barrera de acceso.
- Los repositorios de perfiles y trabajos evitan consultas UUID usando identificadores mock como `mock_user`.
- La función de recomendaciones valida JWT, limita entrada y consumo, y no utiliza el modelo para inventar trabajadores, precios o reseñas.
- Los buckets y las políticas determinan qué imágenes son accesibles; deben revisarse junto con las reglas RLS al desplegar cambios.
- Las claves privadas —por ejemplo, `service_role`, secretos de n8n, Resend y Ollama— no deben incluirse en Flutter, en `--dart-define` público ni en el bundle web. Los secretos del backend deben configurarse en Supabase/Vercel según corresponda.
- Los datos de pago de la demostración son ficticios; no deben sustituirse por datos reales hasta integrar un procesador y un diseño de seguridad y cumplimiento adecuados.

## 8. Servicios e integraciones externas

| Servicio | Uso | Estado/condición |
|---|---|---|
| Supabase Auth/Postgres/Storage | Cuenta, datos y archivos | Requiere URL, clave pública, configuración Auth, políticas y migraciones aplicadas. |
| Google OAuth | Inicio de sesión con Google | Requiere clientes compatibles y configuración en Google/Supabase. |
| OpenStreetMap Nominatim | Búsqueda/geocodificación | Dependencia externa; su disponibilidad y límites aplican. |
| Resend | Correo para reportes | Opcional; necesita función desplegada y secretos. No se usa para los correos ficticios de pagos. |
| n8n | Automatización de reportes | Opcional; requiere instancia, webhook y secreto. |
| Ollama | Clasificación para recomendaciones | Opcional; requiere servicio/modelo alcanzable por la Edge Function. |
| Stripe/bancos | Procesamiento de pagos | No integrado en el pago móvil DEMO descrito en este informe. |
| FCM | Notificaciones push | No hay integración activa confirmada en el código inspeccionado. |

## 9. Compilación, configuración y despliegue

La aplicación se construye con Flutter para web y móvil. La configuración de Supabase y otros valores de cliente se inyecta en tiempo de compilación; deben utilizarse los nombres/valores documentados por el proyecto y nunca incorporar secretos privados al cliente.

El despliegue web de Vercel utiliza `node tool/vercel-build.js` y publica el contenido de `build/web`. La configuración del proyecto activa `PAYMENTS_DEMO=true`; esa variable activa una demostración y no conecta una institución financiera. Los APK de Android se generan bajo `build/app/outputs/`.

Antes de una publicación se debe:

1. Verificar variables públicas y URL/clave de Supabase en el entorno destino.
2. Comprobar la configuración de Google OAuth y las plantillas/SMTP de Auth.
3. Aplicar y verificar migraciones en el proyecto Supabase remoto.
4. Desplegar Edge Functions y configurar sus secretos solo en el backend.
5. Decidir explícitamente si se habilitan Resend, n8n y Ollama.
6. Ejecutar pruebas/análisis y verificar el artefacto desplegado.

Los documentos de despliegue y configuración del repositorio pueden no reflejar todos los cambios recientes; el código y las migraciones versionadas deben prevalecer al validar el comportamiento.

## 10. Pruebas y calidad

El proyecto incluye pruebas de validadores y pruebas de lógica de autenticación, trabajos, pagos demo, reportes y recomendaciones, además de pruebas para el cliente de la Edge Function. En una revisión previa se ejecutaron `flutter test` (42 pruebas) y `flutter analyze` sin hallazgos después del cambio de validación del teléfono `422`. Esa ejecución corresponde a ese cambio y no es una certificación del estado completo actual.

La recuperación de contraseña local y el commit local posterior sobre correo ya registrado requieren validación propia antes de publicarse. Este informe no ejecuta nuevamente la suite ni verifica una instancia real de Supabase, Vercel, Google OAuth, Resend, n8n u Ollama.

## 11. Limitaciones y asuntos pendientes

1. **Pagos:** el pago móvil y los correos que muestra son demostrativos; no hay transferencia de dinero.
2. **Persistencia de cobros:** el repositorio de cobros convencional es en memoria; falta persistencia real para operar una liquidación.
3. **Correo:** el correo de pago DEMO no se envía. El correo de reportes depende de la función y secretos configurados.
4. **Recuperación de contraseña:** está en el checkout local y pendiente de publicar/configurar; no asumir disponibilidad en producción.
5. **Migraciones remotas:** el usuario confirmó aplicada la migración del prefijo `422`; el estado remoto de `fix_handle_new_user` y otras migraciones no se verificó aquí.
6. **Despliegue actual:** no fue posible confirmar desde este informe el estado en vivo de Vercel ni qué commit está desplegado. El commit local `813de7b` no estaba en `origin/main` al revisar el repositorio.
7. **Datos de demostración:** los perfiles sintéticos y fallbacks deben identificarse como tales para evitar confundirlos con usuarios o disponibilidad reales.
8. **Servicios opcionales:** Google, Nominatim, Resend, n8n, Ollama y cualquier notificación requieren configuración, conectividad y pruebas en su entorno objetivo.

## 12. Referencias de implementación

- Arranque y configuración de la app: [`lib/main.dart`](./lib/main.dart)
- Rutas: [`lib/core/routes/app_router.dart`](./lib/core/routes/app_router.dart)
- Autenticación: [`lib/features/auth/data/auth_repository.dart`](./lib/features/auth/data/auth_repository.dart)
- Repositorio de trabajos: [`lib/features/jobs/data/jobs_repository.dart`](./lib/features/jobs/data/jobs_repository.dart)
- Cobros convencionales: [`lib/features/billing/data/billing_repository.dart`](./lib/features/billing/data/billing_repository.dart)
- Pago móvil DEMO: [`lib/features/billing/data/payments_demo_repository.dart`](./lib/features/billing/data/payments_demo_repository.dart)
- Reportes: [`lib/features/reports/data/report_repository.dart`](./lib/features/reports/data/report_repository.dart)
- Recomendaciones: [`supabase/functions/recommend-workers/index.ts`](./supabase/functions/recommend-workers/index.ts)
- Notificaciones de reportes: [`supabase/functions/notify-report/index.ts`](./supabase/functions/notify-report/index.ts)
- Migraciones y despliegue de Supabase: [`supabase/README.md`](./supabase/README.md)
- Automatización n8n: [`n8n/README.md`](./n8n/README.md)
