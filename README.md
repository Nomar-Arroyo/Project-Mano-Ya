# Mano Ya — Tus Oficios a la Mano

Aplicación híbrida (móvil/web) desarrollada en **Flutter** que conecta a
**clientes** con **trabajadores de oficios** (construcción, belleza, costura,
mantenimiento, automotriz y eventos) en su zona.

Incluye autenticación con roles, perfil avanzado con 2FA, catálogo de oficios
con geolocalización y contacto directo por WhatsApp, y un módulo completo de
cobro con cuotas/hitos, confirmación de pago y generación de recibo en PDF.

> Backend previsto: **Supabase** (Auth, PostgreSQL, Storage y Realtime). Mientras
> se integran las credenciales reales, la app funciona en **modo mock** para que
> sea 100% navegable y compilable.

---

## Proyecto de 3er Trimestre (ITSU)

Proyecto de fin de trimestre (ITSU) que se desarrolla y **se expone como una
tesis**: abarca desde el planteamiento del problema y la arquitectura hasta la
implementación, las pruebas y la defensa final ante el jurado.

**Integrantes:**

- **Nomar Arroyo** · nomar.arroyo.itsu@gmail.com
- **Ana Anselmi** · anaanselmi.itsu@gmail.com
- **Alan Mendoza** · alanmendoza.itsu@gmail.com

---

## Tabla de contenido

- [Proyecto de 3er Trimestre (ITSU)](#proyecto-de-3er-trimestre-itsu)
- [Características](#-características)
- [Stack tecnológico](#-tech-stack)
- [Arquitectura del proyecto](#-arquitectura-del-proyecto)
- [Requisitos](#-requisitos)
- [Puesta en marcha](#-puesta-en-marcha)
- **Configuración de Supabase** (#-configuración-de-supabase)
- [Roles de usuario](#-roles-de-usuario)
- [Estado del proyecto](#-estado-del-proyecto)
- `test` y verificación

## Características

- **Autenticación y perfiles**: registro/login con Email y Google, selección
  obligatoria de rol (`Cliente` / `Trabajador`), foto de perfil, edición de
  datos y **Verificación en 2 Pasos (2FA)**.
- **Perfil avanzado por rol**:
  - *Trabajador*: presentación (bio), **portafolio express de 3 a 5 fotos**,
    configuración de **método de pago/cuenta de cobro** y disponibilidad.
  - *Cliente*: **direcciones/zonas guardadas**, **contratistas favoritos** e
    **historial de servicios con comprobantes de pago**.
- **Tema claro/oscuro** con detección del tema del sistema y toggle manual,
  junto con una **splash screen** de bienvenida.
- **Catálogo de oficios** con las 6 categorías principales, búsqueda por
  ciudad/zona (autocompletado geolocalizado) y filtro por disponibilidad.
- **Asistente de recomendaciones**: interpreta la necesidad del cliente y
  muestra trabajadores existentes; requiere configurar la Edge Function y
  Ollama en el backend.
- **Ficha y confianza**: insignias de *Identidad Verificada*, *Trabajo
  Garantizado* y *Disponible Hoy*, además de valoraciones.
- **Comunicación por WhatsApp**: enlace directo `wa.me` con mensaje
  predeterminado estructurado para contactar al trabajador.
- **Módulo de cobro**: solicitud de cobro con datos bancarios/pago móvil,
  **plan de cuotas/hitos** (pago único, 2, 4 o quincenal) con tabla de estado
  (`Pagada` / `Pendiente`), confirmación de pago y **recibo en PDF** con el
  sello *"TRABAJO PAGADO / GARANTIZADO"*. Incluye un flujo de pago móvil
  **DEMO** seleccionable con datos ficticios, comisión visible (15% Mano Ya /
  85% trabajador) y reportes registrados en una bandeja simulada.
- **Imágenes en la nube**: las fotos de perfil y del portafolio se suben a los
  buckets públicos `avatars` y `portfolios` de Supabase Storage.

## Stack tecnológico

| Área | Tecnología |
| --- | --- |
| Framework | Flutter (Dart) — móvil y web |
| Estado | Riverpod |
| Navegación | go_router |
| Backend | Supabase (Auth, PostgreSQL, Storage, Realtime) |
| Geolocalización | OpenStreetMap Nominatim (+ distancia Haversine) |
| PDF | paquete `pdf` |
| Otros | `url_launcher` (WhatsApp), `image_picker`, `shared_preferences`, `intl` |

## Estructura del proyecto

```
lib/
├── core/                     # Infraestructura compartida
│   ├── config/               # Configuración (Supabase y Google vía dart-define)
│   ├── constants/            # Paleta de colores
│   ├── routes/               # Rutas de la app (go_router)
│   ├── services/             # Servicios: Supabase, Storage, PDF, WhatsApp,
│   │                         #   Maps (Nominatim), notificaciones
│   ├── theme/                # Temas claro/oscuro y su persistencia
│   └── utils/                # Utilidades (formato, imágenes locales web-safe)
├── features/
│   ├── auth/                 # Autenticación (dominio, datos y UI)
│   ├── billing/              # Cobros, cuotas, confirmación de pago y recibo
│   ├── home/                 # Contenedor con la navegación inferior
│   ├── profile/              # Perfil por rol: portafolio, cobro, direcciones,
│   │                         #   favoritos, historial y edición de datos
│   ├── requests/             # Solicitud de presupuesto
│   ├── shared/               # Modelos y widgets compartidos
│   ├── splash/               # Pantalla de bienvenida
│   └── workers/              # Catálogo, detalle y trabajadores
├── main.dart                 # Punto de entrada
supabase/
├── migrations/               # Esquema SQL (tablas, RLS, triggers) y semilla
└── README.md                 # Instrucciones para aplicar el esquema
```

Cada módulo de la carpeta `features/` sigue una separación por capas:
`domain/` (modelos), `data/` (repositorios) y `presentation/`
(providers, páginas y widgets).

## Requisitos

- Flutter SDK (canal estable) y Dart.
- Android Studio / SDK de Android para compilar el APK.
- (Opcional) Un proyecto en Supabase con credenciales.

## Puesta en marcha

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Ejecutar en modo desarrollo sin Supabase (modo mock)
flutter run

# Ejecutar localmente el flujo ficticio de pagos móviles
.\tool\run_flutter_with_env.ps1 run -PagosDemo

# Ejecutar con la configuración local de Supabase (.env, no se sube a Git)
.\tool\run_flutter_with_env.ps1 run

# 3. Compilar APK de depuración
flutter build apk --debug

# 4. Compilar para web
flutter build web
```

El flujo de pagos DEMO requiere `PAYMENTS_DEMO=true` durante la compilación.
Vercel lo activa en su build de producción; para verlo localmente usa
`-PagosDemo` con el script anterior, y para un APK agrega
`--dart-define=PAYMENTS_DEMO=true` al comando de compilación. Muestra avisos
DEMO y datos ficticios: no conecta con Stripe ni con bancos, no transfiere
dinero y no envía correos reales.

## Configuración de Supabase

La app funciona en **modo mock** cuando no se proporcionan credenciales. Para
usar Supabase, copia `.env.example` a `.env` y completa `SUPABASE_URL` y
`SUPABASE_ANON_KEY` con la URL del proyecto y la clave pública `sb_publishable_`
(o la clave pública heredada `anon`). Después ejecuta:

```powershell
.\tool\run_flutter_with_env.ps1 run
```

El script pasa esos valores a Flutter como `--dart-define`; Flutter no carga
archivos `.env` directamente. Para compilar, se puede usar `build` en lugar de
`run` y agregar los argumentos de plataforma, por ejemplo:

```powershell
.\tool\run_flutter_with_env.ps1 build apk --release
```

No pongas una clave `sb_secret_` ni `service_role` en Flutter; son credenciales
privilegiadas.

### Verificación del correo al registrarse

Después del registro, la app muestra una pantalla para introducir el código de
verificación enviado por Supabase Auth. Solo después de validar el código
permite entrar. En el proyecto remoto, activa **Authentication > Providers >
Email > Confirm email** y configura la plantilla de confirmación para mostrar
el token `{{ .Token }}` (la plantilla local está en
`supabase/templates/confirmation.html`). Para Supabase local,
`supabase/config.toml` habilita `auth.email.enable_confirmations`; consulta los
mensajes de desarrollo en Inbucket.

El proyecto remoto genera códigos de 8 dígitos (Supabase permite entre 6 y 10),
así que la app acepta ese rango en la pantalla de verificación y en la de
recuperación. No hace falta cambiar la longitud en el panel para que funcione.

Si la confirmación está desactivada, el cliente bloquea el acceso e informa que
la configuración debe corregirse. En modo mock no se crean cuentas ni se envían
correos. El inicio de sesión con Google usa la verificación gestionada por
Google.

### Recuperación de contraseña

El botón **¿Olvidaste tu contraseña?** del inicio de sesión abre un flujo de
tres pasos: correo, código numérico y contraseña nueva. Usa el mismo SMTP
configurado en Supabase Auth y no depende de que la persona recuerde la
contraseña anterior.

Para que el correo incluya el código, en el proyecto remoto entra a
**Authentication > Emails > Reset Password** y reemplaza la plantilla por el
contenido de `supabase/templates/recovery.html`, que muestra `{{ .Token }}`.
La plantilla por defecto solo trae un enlace; como la app pide el código, sin
este cambio la pantalla del código no tendría qué aceptar. El asunto sugerido es
*Recupera tu contraseña en Mano Ya*.

El flujo completo también está en `supabase/config.toml` para Supabase local.

#### SMTP propio (obligatorio para producción)

El SMTP integrado de Supabase solo entrega unos pocos correos por hora y, en
varios planes, únicamente a direcciones del equipo del proyecto. Al superar el
cupo, GoTrue responde `429 over_email_send_rate_limit` y **no envía nada**, así
que el registro termina sin código (la app ya muestra ese caso en español).

Para que los códigos lleguen a cualquier usuario:

1. Verifica un dominio de envío en Resend, Brevo o el proveedor que uses.
2. En el panel: **Authentication > Emails > SMTP Settings** y completa host,
   puerto, usuario, contraseña y remitente (por ejemplo
   `Mano Ya <no-reply@manoya.app>`).
3. En **Authentication > Rate Limits** sube el límite de correos por hora.
4. Envía un registro de prueba y revisa spam la primera vez: el remitente por
   defecto de Supabase tiene mala reputación.

Configuración actual del proyecto remoto: Gmail con contraseña de aplicación
(`smtp.gmail.com`, puerto `465`), remitente **Mano Ya**, límite de 30 correos por
hora y `site_url` en la web de Vercel. Gmail sirve para validar el flujo, pero
para producción conviene un dominio propio verificado, porque el cupo diario de
Gmail es bajo y el remitente `@gmail.com` se marca como spam con facilidad.

### Inicio de sesión con Google (OAuth)

En el mismo `.env` se agregaron dos variables opcionales:

| Variable | Uso |
| --- | --- |
| `GOOGLE_CLIENT_ID` | Client id de la app web/iOS (Google Cloud Console). |
| `GOOGLE_SERVER_CLIENT_ID` | Client id de tipo *web* (Android lo exige para generar el `id_token`). |

La app obtiene el `id_token` de Google y lo valida en Supabase con
`signInWithIdToken`; el **rol es obligatorio** y se guarda en los metadatos del
usuario. Sin estas credenciales el botón de Google funciona en modo simulado.

### Esquema de base de datos

El esquema completo (tablas, RLS, triggers y buckets de Storage) está en
`supabase/migrations/`. Las instrucciones para aplicarlo están en
`supabase/README.md`:

```bash
supabase link --project-ref waxypsqomsljcljdqwra
supabase db push
```

Mientras el esquema no esté aplicado, los módulos de trabajos, cobros y
catálogo siguen usando datos mock, pero el perfil extendido (portafolio, datos
de cobro, direcciones y favoritos) funciona con ambos modos.

## Roles

- **Cliente**: busca trabajadores, filtra por oficio/zona, contacta por WhatsApp
  o solicita presupuesto, guarda direcciones y favoritos, notifica pagos y
  consulta su historial de servicios con comprobantes.
- **Trabajador**: gestiona su disponibilidad, publica su bio y portafolio
  express, configura su método de cobro, recibe solicitudes, envía solicitudes
  de cobro (con plan de cuotas) y confirma pagos recibidos.

## Estado de integración

- **Conectado a Supabase Auth** cuando se inicia mediante
  `.\tool\run_flutter_with_env.ps1 run`: registro, inicio/cierre de sesión,
  restauración de sesión y metadata básica del perfil.
- **Google OAuth implementado**: el flujo real (`google_sign_in` +
  `signInWithIdToken`) ya está en el código; solo faltan los client ids de
  Google Cloud en el `.env` para activarlo.
- **Perfil extendido conectado a Supabase**: `profiles`, `portfolio_items`,
  `saved_addresses` y `favorites` se leen y escriben contra el backend cuando
  las tablas existen, con respaldo en memoria (modo mock) si no están.
- **Imágenes en Supabase Storage**: avatar y portafolio se suben a los buckets
  `avatars` y `portfolios`.
- **Esquema de base de datos listo** en `supabase/migrations/`: falta aplicarlo
  en el proyecto `waxypsqomsljcljdqwra` para que el catálogo, los trabajos y
  los cobros dejen de usar datos mock.
- MFA/2FA requiere configuración adicional en Supabase.

## Verificación

```bash
dart analyze       # Análisis estático (debe terminar sin hallazgos)
dart format lib    # Formato de código
```

---

Hecho con dedicación para **Mano Ya** · *Tus Oficios a la Mano*.
