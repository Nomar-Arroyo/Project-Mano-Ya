# Mano Ya · Cuentas y conexiones que hay que crear

Guía paso a paso de todo lo que necesita una cuenta externa, con el orden
recomendado. Marca cada casilla cuando la completes.

Resumen rápido:

| # | Servicio | Para qué | Obligatorio | Coste |
|---|----------|----------|-------------|-------|
| 1 | Supabase | Base de datos, login, 2FA, archivos | Sí | Gratis (pausa a los 7 días sin uso) |
| 2 | Google Cloud | Iniciar sesión con Google (OAuth) | Sí para OAuth | Gratis |
| 3 | n8n | Automatizar reportes y correos | Sí para automatizar | Gratis autoalojado / n8n Cloud de pago |
| 4 | Resend | Enviar los correos de los reportes | Sí para correos | Gratis hasta 3.000/mes |
| 5 | GitHub Pages o Cloudflare Pages | Publicar la web (PWA) | Sí para publicar | Gratis |
| 6 | Dominio propio | URL con tu marca (opcional) | No | ~10 USD/año |

---

## 0. Lo que ya quedó listo (no hay que hacer nada)

- Base de datos `waxypsqomsljcljdqwra` creada y con el esquema completo:
  13 tablas, 24 políticas RLS, buckets `avatars` y `portfolios`, extensión
  `pg_cron` con el mantenimiento diario y `pg_net` para avisar a n8n.
- El trigger que crea el perfil de cada usuario al registrarse funciona.
- La app Flutter ya compila con el esquema nuevo (nombres de columnas
  alineados: `profiles.full_name/role/city`, `jobs.client_id/worker_id`,
  `portfolio_items.worker_id`, `saved_addresses.client_id/is_primary`,
  `reviews.worker_id/client_id`, `favorites.client_id/worker_id`).

Lo que falta de tu lado son las **claves** y las **cuentas** de los
servicios de abajo.

---

## 1. Supabase (projecto `waxypsqomsljcljdqwra`)

### 1.1 Crear un token de acceso personal

1. Entra en <https://supabase.com/dashboard/account/tokens>.
2. **Generate new token** → nombre `mano-ya-setup` → **Generate token**.
3. Copia el token (`sbp_...`). Aparece una sola vez.

Con este token puedo hacer automáticamente todo lo del punto 1.2 y dejar el
proyecto listo:

```powershell
cd C:\Projects\ManoYa\src
$env:SUPABASE_ACCESS_TOKEN = "sbp_xxxxxxxx"
node tool/setup-supabase.mjs --project-ref waxypsqomsljcljdqwra `
  --google-client-id "TU_CLIENT_ID.apps.googleusercontent.com" `
  --google-client-secret "TU_CLIENT_SECRET"
```

El script escribe las claves en `.env`, habilita Google en Auth y ajusta la
URL de la app. **El token se puede revocar después** desde la misma página.

### 1.2 Alternativa manual (sin token)

Si prefieres no darme el token, copia estos dos valores del panel:

- **Project Settings → Data API → Project URL**
  `https://waxypsqomsljcljdqwra.supabase.co`
- **Project Settings → Data API → Publishable key** (`sb_publishable_...`)

y ponlos en `C:\Projects\ManoYa\src\.env`:

```
SUPABASE_URL=https://waxypsqomsljcljdqwra.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...
```

La **secret key** (`sb_secret_...`) solo hace falta para n8n y la Edge
Function: nunca va en la app.

### 1.3 Habilitar el 2FA (TOTP)

Panel → **Authentication → Sign In / Providers → Multi-Factor
Authentication** → activa **TOTP** y ponle *Enforce* = *Optional*.

> Esto no se puede cambiar por SQL: la Management API no expone el flag
> MFA/TOTP en el plan gratuito. Son dos clics en el panel.

### 1.4 Evitar que el proyecto se pause

El plan gratuito pausa el proyecto tras 7 días sin tráfico. Como el
`pg_cron` corre `public.run_maintenance()` cada madrugada, **ese job ya
cuenta como actividad**, así que en la práctica no se pausa. Si aun así
queda inactivo, la alternativa es pasar al plan Pro (20 USD/mes) o activate
alguno de los pasos de este documento cada pocos días.

### 1.5 Crear los buckets (ya están hechos)

`avatars` y `portfolios` ya existen y son públicos para lectura, con
políticas que obligan a que la primera carpeta del archivo sea el id del
usuario. No hay que hacer nada.

---

## 2. Google Cloud (inicio de sesión con Google)

Objetivo: que el usuario pueda entrar con Google y que Supabase valide el
`id_token`.

### 2.1 Crear el proyecto

1. <https://console.cloud.google.com/> → **New Project** → nombre
   `Mano Ya` → **Create**.
2. Anota el **Project ID**.

### 2.2 Activar la API de Google Identity

1. Menú **APIs & Services → Library**.
2. Busca **Google Identity Platform** → **Enable**. (En proyectos nuevos
   Google Identity Platform ya incluye OAuth.)

### 2.3 Configurar la pantalla de consentimiento

1. **APIs & Services → OAuth consent screen**.
2. **External**, nombre `Mano Ya`, correo de soporte, logo (opcional).
3. En **Test users** agrega tu correo de pruebas (esto permite usar la app
   sin publicar la pantalla).
4. En **Data Access** marca los scopes: `email`, `profile`,
   `openid` (obligatorios para Supabase).

### 2.4 Crear el Client ID de tipo Web

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
2. **Application type: Web application**.
3. **Name**: `Mano Ya Web`.
4. **Authorized redirect URIs**:
   - `https://waxypsqomsljcljdqwra.supabase.co/auth/v1/callback`
   - `https://<tu-dominio-o-*.pages.dev>/auth/callback`
5. **Create** → anota el **Client ID** y el **Client secret**.

### 2.5 Crear el Client ID de tipo Android

1. **Create Credentials → OAuth client ID → Android**.
2. **Package name**: debe coincidir con el de la app. En
   `android/app/build.gradle.kts` busca `applicationId` y cópialo
   (normalmente `com.example.mano_ya`; cámbialo a `com.manoya.app` si
   quieres).
3. **SHA-1**: obtén el SHA-1 de tu keystore de debug:

```powershell
cd C:\Projects\ManoYa\src\android
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey -storepass android -keypass android
```

4. **Create** → anota el **Client ID** de Android.

### 2.6 Qué client ID usa cada plataforma

| Plataforma | Variable | Client ID |
|------------|----------|-----------|
| Web (PWA) | `GOOGLE_CLIENT_ID` | **Web** (2.4) |
| Android | `GOOGLE_CLIENT_ID` | **Android** (2.5) |
| Android (id_token) | `GOOGLE_SERVER_CLIENT_ID` | **Web** (2.4) |

> Android exige el client id de tipo **Web** (`serverClientId`) para
> generar el `id_token` que valida Supabase. Por eso la app pide las dos
> variables y no arranca el login con Google si falta alguna.

Añade al `.env`:

```
GOOGLE_CLIENT_ID=000000000000-xxxx.apps.googleusercontent.com
GOOGLE_SERVER_CLIENT_ID=000000000000-xxxx.apps.googleusercontent.com
```

> El **Client secret** solo se usa en el panel de Supabase (o en el script
> `setup-supabase.mjs`). **Nunca** va en la app.

### 2.7 El botón de Google en la web

En el navegador, Google Identity Services **no permite** iniciar sesión con
un botón hecho por la aplicación: hay que usar el botón oficial del SDK. Por
eso la app lo tiene en cuenta:

- En la web se dibuja el botón de Google Identity Services
  (`lib/features/auth/presentation/widgets/google_sign_in_platform_web.dart`).
- En Android e iOS se usa el diálogo nativo del SDK.

Además, `web/index.html` lleva esta etiqueta, que el SDK usa como respaldo
cuando no se le pasa el client id por código:

```html
<meta name="google-signin-client_id" content="TU_CLIENT_ID_WEB_GOOGLE">
```

Sustituye `TU_CLIENT_ID_WEB_GOOGLE` por el Client ID Web (2.4). Si lo dejas
como está, no pasa nada: la app le pasa el client id desde
`GOOGLE_CLIENT_ID` y ese valor tiene prioridad.

Recuerda añadir el dominio de producción a los **orígenes de JavaScript
autorizados** del Client ID Web:

```
https://mano-ya.vercel.app
https://<tu-dominio-personalizado>
http://localhost
http://localhost:7357
```

> En local, Google solo autoriza `http://localhost` y
> `http://localhost:7357`. Arranca la web con
> `flutter run -d chrome --web-hostname localhost --web-port 7357`.

---

## 3. n8n (automatización de reportes)

### 3.1 Opción A: n8n Cloud (lo más rápido)

1. <https://app.n8n.cloud/> → **Sign up** (o Google).
2. Crea un **workflow** en blanco.
3. n8n Cloud exige plan de pago para webhooks de producción; mientras
   tanto puedes usar la URL de prueba (`/webhook-test/`) solo desde el
   editor.

### 3.2 Opción B: n8n autoalojado (gratis e ilimitado)

Necesitas un servidor/VPS. Alternativas gratuitas con Electron (una sola
instancia) o con créditos:

- **Oracle Cloud Always Free**: 2 VM Always Free (1 GB RAM). Es la opción
  gratuita más estable para n8n.
- **Railway / Render / Fly.io**: créditos de prueba, good para validar.
- **Railway**: plan Hobby 5 USD/mes (con tarjeta). Se pausa sin uso.

Si ya tienes un VPS o contenedor:

```bash
docker run -d --name n8n --restart always \
  -p 5678:5678 \
  -e N8N_HOST=tu-dominio \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=https://tu-dominio/ \
  -e GENERIC_TIMEZONE=America/Caracas \
  -v n8n_data:/home/node/.n8n \
  n8nio/n8n
```

Luego entra en `https://tu-domino:5678`, crea el usuario administrador y ve
a **Settings → n8n → API key → Create API key**.

### 3.3 Importar los workflows

En n8n: **Workflows → Import from File** y elige:

- `n8n/mano-ya-reportes.json` → recibe los reportes y envía el correo.
- `n8n/mano-ya-mantenimiento.json` → llama a `public.run_maintenance()`
  cada madrugada (por si el `pg_cron` no estuviera disponible).

### 3.4 Configurar las variables

En n8n, **Settings → Variables**, o directamente en los nodos:

| Marcador | Valor |
|----------|-------|
| `{{SUPABASE_URL}}` | `https://waxypsqomsljcljdqwra.supabase.co` |
| `{{SUPABASE_SERVICE_ROLE_KEY}}` | secret key de Supabase (`sb_secret_...`) |
| `{{N8N_WEBHOOK_SECRET}}` | un texto largo inventado por ti |

### 3.5 Conectar el webhook con Supabase

1. Activa el workflow de reportes.
2. Copia la **URL de producción** del nodo Webhook:
   `https://tu-n8n/webhook/reportes`.
3. En el **SQL Editor de Supabase** ejecuta `n8n/supabase-webhook-setup.sql`
   y, si hace falta, corrige la URL con:

```sql
select public.set_n8n_webhook('https://tu-n8n/webhook/reportes');
```

4. Pon la misma URL en el `.env` de la app:

```
N8N_WEBHOOK_URL=https://tu-n8n/webhook/reportes
```

5. Genera un secreto y ponlo en ambos lados:

```
N8N_WEBHOOK_SECRET=un-texto-largo-y-aleatorio
```

- En n8n: variable del workflow.
- En Supabase: **Edge Functions → notify-report → Secrets**.

> El trigger de la base de datos (`notify_new_report`) ya avisa a n8n
> automáticamente. La app también lo hace. Las dos vías son idempotentes
> porque el trigger marca `notified_at`, así que un reporte no genera dos
> correos.

---

## 4. Resend (los correos de los reportes)

1. <https://resend.com/signup> → cuenta con tu correo.
2. **API Keys → Create API Key** → nombre `mano-ya`.
3. Copia `re_...`.
4. En Supabase: **Edge Functions → notify-report → Secrets**:
   - `RESEND_API_KEY` = `re_...`
   - `N8N_WEBHOOK_SECRET` = el mismo secreto que pusiste en n8n.
   - `SUPPORT_EMAIL` = a quién llega el reporte (ej. `soporte@manoya.app`).
5. **Domains → Add Domain** → `manoya.app` (o el que uses) y configura los
   DNS que te indique Resend. Verifica con el botón de check.

El plan gratuito de Resend envía 3.000 correos al mes. Si no quieres
configurar el dominio, Resend permite enviar desde
`onboarding@resend.dev` solo a tu propio correo (útil para probar).

---

## 5. Publicar la web (PWA) con URL gratis

La app ya compila para web. Solo falta publicarla.

### 5.1 GitHub Pages (recomendado: el repositorio ya está en GitHub)

El workflow `.github/workflows/deploy-web.yml` ya está creado. Solo falta:

1. En GitHub: **Settings → Secrets and variables → Actions → New
   repository secret**:
   - `SUPABASE_URL` = `https://waxypsqomsljcljdqwra.supabase.co`
   - `SUPABASE_ANON_KEY` = `sb_publishable_...`
   - `GOOGLE_CLIENT_ID` = (el de Android, para la PWA conviene el Web)
   - `GOOGLE_SERVER_CLIENT_ID` = el Web
   - `WEB_APP_URL` = `https://<usuario>.github.io/Project-Mano-Ya`
   - `N8N_WEBHOOK_URL` = la URL de n8n
   - `SUPPORT_EMAIL` = tu correo de soporte
2. **Settings → Pages → Source: GitHub Actions**.
3. Cada `push` a `main` publica la web.

URL final: `https://<usuario>.github.io/Project-Mano-Ya/`

### 5.2 Cloudflare Pages (URL más limpia: `manoya.pages.dev`)

1. <https://dash.cloudflare.com/> → **Workers & Pages → Create → Pages**.
2. **Connect to Git** → elige el repositorio.
3. **Build command**: `flutter build web --release`
4. **Build output directory**: `build/web`
5. **Environment variables**: las mismas de arriba.
6. **Settings → Builds & deployments** → añade `NODE_VERSION 20` y
   `FLUTTER_VERSION 3.24.0` si falla la compilación.

### 5.3 Netlify o Firebase Hosting

Ya están los archivos `netlify.toml` y `firebase.json`. Solo con arrastrar
el repositorio y definir las variables de entorno funciona.

### 5.4 Instalar la PWA en el móvil

- **Android (Chrome)**: abrir la URL → menú → *Añadir a pantalla de
  inicio*.
- **iPhone (Safari)**: abrir la URL → botón de compartir → *Añadir a
  pantalla de inicio*.

### 5.5 Conectar la URL con Supabase y Google

- Supabase → **Authentication → URL Configuration**:
  - **Site URL**: la URL de tu web.
  - **Redirect URLs**: la URL de tu web + `/**` y la de Google
    (`https://waxypsqomsljcljdqwra.supabase.co/auth/v1/callback`).
- Google Cloud: añade la nueva URL a los **Authorized redirect URIs** del
  client id de tipo Web.

---

## 6. Dominio propio (opcional)

- **Cloudflare Registrar** cobra a precio de coste (sin markup) y da DNS
  gratis. Compra `manoya.app` o similar y apunta a GitHub Pages / Cloudflare
  Pages con un `CNAME`.
- **Freedns / eu.org** ofrecen subdominios gratuitos.
- Después actualiza `WEB_APP_URL`, las *Redirect URLs* de Supabase y los
  *Authorized redirect URIs* de Google.

---

## 7. Orden recomendado de ejecución

1. **Supabase**: genera el PAT y ejecuta `setup-supabase.mjs` → deja el
   `.env` con URL y claves.
2. **Supabase**: activa TOTP en *Authentication → MFA*.
3. **Google Cloud**: crea los client ids (Web + Android) y ponlos en el
   `.env`.
4. **n8n**: crea la cuenta/instancia, importa los dos workflows, configura
   las variables y activa el workflow de reportes.
5. **Resend**: crea la API key y ponla en los secretos de la Edge Function.
6. **Edge Function**: en Supabase → *Edge Functions → notify-report* →
   *Deploy*. (También se puede desplegar con
   `supabase functions deploy notify-report --no-verify-jwt`.)
7. **Supabase SQL Editor**: ejecuta `n8n/supabase-webhook-setup.sql` con
   la URL de n8n.
8. **Hosting**: publica la web en GitHub Pages o Cloudflare Pages.
9. **Prueba final**: registra un usuario en la web, activa el 2FA, envía un
   reporte y confirma que llega el correo.

---

## 8. Comprobación de que los datos llegan

```powershell
cd C:\Projects\ManoYa\src
powershell -ExecutionPolicy Bypass -File n8n\verify-data.ps1
```

Devuelve el número de filas de `profiles`, `workers`, `jobs`, `job_events`,
`reports` y `reviews`, y las filas más recientes de cada una. Sale con
código `0` si hay al menos un perfil y `1` si la base está vacía.

---

## 9. Datos que nunca debes compartir ni subir al repositorio

| Dato | Dónde vive | ¿Va en la app? |
|------|-----------|----------------|
| `SUPABASE_ANON_KEY` (`sb_publishable_...`) | `.env` y secretos del hosting | Sí, es pública |
| `GOOGLE_CLIENT_ID` | `.env` y secretos del hosting | Sí, es público |
| `GOOGLE_SERVER_CLIENT_ID` | `.env` y secretos del hosting | Sí, es público |
| `SUPABASE_SERVICE_ROLE_KEY` (`sb_secret_...`) | `.env` de n8n | **No** |
| `GOOGLE_CLIENT_SECRET` | Panel de Supabase | **No** |
| `N8N_WEBHOOK_SECRET` | n8n y secretos de Supabase | **No** |
| Contraseña de la base de datos | Solo en tus notas | **No** |

El archivo `.env` ya está en `.gitignore`. Antes de hacer commit, revisa con
`git status` que no se te cuele ningún archivo con secretos.
