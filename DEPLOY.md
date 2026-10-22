# Publicar Mano Ya en internet

Guia paso a paso para que cualquier persona abra la app web desde una URL
pública y se registre desde el movil. No hace falta ningun servidor propio:
todo se apoya en Supabase (base de datos y correo) y en un hosting gratuito
para el frontend.

- **Frontend**: Flutter web compilado a `build/web/`.
- **Backend**: Supabase (Auth, PostgreSQL, Storage y las Edge Functions que
  avisan a soporte).
- **Automatizaciones**: n8n (ver [`n8n/README.md`](n8n/README.md)).

---

## 0. Antes de compilar: variables de entorno

Todas las variables se inyectan en tiempo de compilacion con `--dart-define`.
La app las lee en `lib/core/config/app_config.dart`.

| Variable | Publica | Uso |
| --- | --- | --- |
| `SUPABASE_URL` | Si | URL del proyecto: `https://waxypsqomsljcljdqwra.supabase.co` || `SUPABASE_ANON_KEY` | Si | Clave publica `sb_publishable_...` o la clave `anon` heredada |
| `GOOGLE_CLIENT_ID` | Si | Client id de la app web/iOS (Google Cloud Console) |
| `GOOGLE_SERVER_CLIENT_ID` | Si | Client id de tipo *web* que Android usa para el `id_token` |
| `WEB_APP_URL` | Si | URL publica de la app web (se usa en los enlaces de los correos) |
| `N8N_WEBHOOK_URL` | Si | Webhook que recibe los reportes: `https://<tu-n8n>/webhook/reportes` |
| `SUPPORT_EMAIL` | Si | Correo que recibe los reportes: `soporte@manoya.app` |

### Que es publico y que no

- **La clave publica de Supabase si es publica.** `SUPABASE_ANON_KEY`
  (`sb_publishable_...`) viaja dentro del bundle de la web y cualquiera puede
  leerla. No es un problema: la seguridad la ponen las politicas **RLS** de
  Postgres, que definen que filas puede ver cada usuario. Por eso la clave
  publica puede ir en el repositorio y en los secretos de GitHub sin riesgo.
- **El client id de Google tambien es publico.** `GOOGLE_CLIENT_ID` y
  `GOOGLE_SERVER_CLIENT_ID` son identificadores, no secretos: estan pensados
  para acabar en el navegador o en el APK. Google exige que el *client id* se
  registre como cliente OAuth de tipo "web" o "Android" para que el
  `id_token` pueda validarse contra Supabase.
- **Lo que nunca debe salir del servidor** (ni al bundle, ni al APK, ni al
  repositorio):
  - el **client secret** de Google (`client_secret`),
  - la **service role key** de Supabase (`sb_secret_...` o `service_role`),
  - el **N8N_WEBHOOK_SECRET**,
  - la **RESEND_API_KEY** de la Edge Function.

  Si alguna de estas aparece en el bundle web, cualquiera puede leerla desde
  el codigo fuente de la pagina y abusar de ella. Revisa siempre con la
  consola del navegador (pestaña Sources) o con
  `grep -r "sb_secret" build/web` antes de publicar.

### Compilacion local con el `.env`

```powershell
# En la raiz del proyecto, con el .env ya configurado (no se sube a Git)
.\tool\run_flutter_with_env.ps1 build web --release --base-href="/"
```

El resultado queda en `build/web/`. Es una carpeta estatica: la puedes subir
a cualquier hosting.

---

## Opcion A · GitHub Pages (la mas simple)

El repositorio ya esta en <https://github.com/Nomar-Arroyo/Project-Mano-Ya>
y el workflow de despliegue esta listo en `tool/github-actions/deploy-web.yml`.

> **Antes de activarlo**: el token de acceso personal que se usa para subir
> los cambios no tiene el permiso `workflow`, y GitHub rechaza cualquier
> `push` que toque `.github/workflows/`. Por eso el archivo esta en
> `tool/github-actions/`. Las dos formas de activarlo (crear un PAT con
> permiso `workflow` o publicar a mano) estan explicadas en
> `.github/workflows/README.md`.

### 1. Crear los secretos del repositorio

En GitHub: **Settings -> Secrets and variables -> Actions -> New repository
secret**. Crea uno por cada variable:

| Nombre del secreto | Valor |
| --- | --- |
| `SUPABASE_URL` | `https://waxypsqomsljcljdqwra.supabase.co` |
| `SUPABASE_ANON_KEY` | `sb_publishable_...` |
| `GOOGLE_CLIENT_ID` | client id de la app web/iOS (opcional) |
| `GOOGLE_SERVER_CLIENT_ID` | client id de tipo web (opcional) |
| `WEB_APP_URL` | `https://Nomar-Arroyo.github.io/Project-Mano-Ya/` |
| `N8N_WEBHOOK_URL` | `https://<tu-n8n>/webhook/reportes` (opcional) |
| `SUPPORT_EMAIL` | `soporte@manoya.app` |

### 2. Activar GitHub Pages

**Settings -> Pages -> Build and deployment -> Source: "Deploy from a
branch"**, rama `gh-pages`, carpeta `/ (root)`, **Save**.

### 3. Lanzar el workflow

- **Actions -> Deploy web (GitHub Pages) -> Run workflow**, o
- `git push` a `main` (tambien se ejecuta solo en cada `push`).

El workflow:

1. instala Flutter (con cache del SDK y de las dependencias de Dart),
2. compila con `flutter build web --release --base-href "/Project-Mano-Ya/"`
   (el `--base-href` es obligatorio en Pages porque la app cuelga de un
   subdirectorio),
3. copia `build/web` a la rama `gh-pages`.

Resultado: <https://Nomar-Arroyo.github.io/Project-Mano-Ya/>

> Si cambias de hosting y la app no carga los recursos, casi siempre es un
> problema de `--base-href`: en GitHub Pages es `/<nombre-del-repo>/` y en el
> resto de hostings es `/`.

---

## Opcion B · Cloudflare Pages

1. Entra en <https://dash.cloudflare.com> -> **Workers & Pages -> Create ->
   Pages -> Connect to Git**.
2. Elige el repositorio `Nomar-Arroyo/Project-Mano-Ya`.
3. En **Settings -> Builds & deployments**:
   - **Build command**: `flutter build web --release --base-href="/"`
   - **Build output directory**: `build/web`
   - **Root directory**: *(vacio, la app esta en la raiz del repo)*
4. En **Settings -> Environment variables** (production y preview) crea:

   | Nombre | Valor |
   | --- | --- |
   | `SUPABASE_URL` | `https://waxypsqomsljcljdqwra.supabase.co` |
   | `SUPABASE_ANON_KEY` | `sb_publishable_...` |
   | `GOOGLE_CLIENT_ID` | client id de la app web (opcional) |
   | `GOOGLE_SERVER_CLIENT_ID` | client id de tipo web (opcional) |
   | `WEB_APP_URL` | `https://<tu-sitio>.pages.dev/` |
   | `N8N_WEBHOOK_URL` | `https://<tu-n8n>/webhook/reportes` (opcional) |
   | `SUPPORT_EMAIL` | `soporte@manoya.app` |

5. **Save and Deploy**. Cloudflare te da el dominio `*.pages.dev` y puedes
   añadir uno propio gratis.

Cloudflare Pages es el que mejor rendimiento da en el plan gratuito (CDN
mundial) y su constructor de Express siempre disponible.

---

## Opcion C · Netlify

El repositorio ya incluye `netlify.toml` con el directorio de publicacion y
la redireccion de la PWA.

1. Entra en <https://app.netlify.com> -> **Add new site -> Import an existing
   project** y elige el repositorio.
2. Netlify detecta `netlify.toml` y toma:
   - **Publish directory**: `build/web`
   - **Build command**: el del `netlify.toml` (compila con los
     `--dart-define` tomados de las variables de entorno).
3. En **Site configuration -> Environment variables** crea las mismas
   variables de la tabla de la Opcion B (la clave publica de Supabase y los
   client id de Google pueden ir ahi sin riesgo; la service role key y el
   secreto de n8n **no**).
4. **Deploy site**. Dominio: `https://<tu-sitio>.netlify.app`.

La redireccion `/* -> /index.html 200` es la que permite que el
enrutamiento de Flutter funcione al recargar la pagina o al abrir un
enlace profundo.

---

## Opcion D · Firebase Hosting

El repositorio ya incluye `firebase.json` con `public: build/web` y la
reescritura de todas las rutas a `index.html`.

1. Instala la CLI: `npm install -g firebase-tools` y
   `firebase login`.
2. Crea el proyecto en <https://console.firebase.google.com> (plan Spark
   gratuito) y conecta tu cuenta:
   `firebase use --add`
3. Compila la web:
   ```powershell
   flutter build web --release --base-href="/"
   ```
4. Publica:
   ```bash
   firebase deploy --only hosting
   ```
5. Dominio: `https://<tu-proyecto>.web.app` (y `https://<tu-proyecto>.firebaseapp.com`).

Para pasar las variables al bundle, compilelas con `--dart-define` en el
paso 3 (o defines las de Firebase Hosting en `firebase.json` con la opcion
`--dart-define` de `flutter build`).

---

## Instalar la PWA en el movil

La app web es una **PWA**: se abre en el navegador y se puede instalar como
una aplicacion normal (con icono, sin barra de navegador).

**Android (Chrome)**

1. Abre la URL de la app (por ejemplo <https://Nomar-Arroyo.github.io/Project-Mano-Ya/>).
2. Menu de tres puntos -> **Instalar aplicacion** o
   **Agregar a pantalla de inicio**.
3. Confirma. Aparece el icono de Mano Ya en el launcher.

**iPhone (Safari)**

1. Abre la URL en **Safari** (no en Chrome: en iOS solo Safari instala PWA).
2. Boton **Compartir** -> **Agregar a pantalla de inicio** -> **Agregar**.
3. El icono se coloca en la pantalla de inicio y abre a pantalla completa.

**Escritorio**

- Chrome/Edge: icono de instalar en la barra de direcciones.
- Safari (macOS): **Archivo -> Agregar al Dock**.

> La PWA guarda la sesion en el navegador, asi que el registro con Supabase
> queda guardado en el movil.

---

## Ejecutar la app en un movil real

### Con cable USB

1. En el movil: **Ajustes -> Aproximadamente -> Numero de compilacion** ->
   toca 7 veces para activar las opciones de desarrollador.
2. **Ajustes -> Opciones de desarrollador -> Depuracion USB** activada.
3. Conecta el movil y acepta el dialogo de depuracion en la pantalla.
4. En el PC:
   ```powershell
   flutter devices
   flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
   ```
   O, mucho mas comodo, con el `.env` ya configurado:
   ```powershell
   .\tool\run_flutter_with_env.ps1 run
   ```

### Por WiFi (depuracion sin cable)

1. Con el movil y el PC en la misma red WiFi.
2. Averigua la IP del movil (Ajustes -> Acerca del telefono -> IP).
3. Con el movil conectado por cable al menos una vez:
   ```powershell
   flutter run --host 192.168.1.50
   ```
   Flutter se conecta al puerto de depuracion del movil por WiFi y ya puedes
   desconectar el cable.

### Compilar el APK de depuracion

```powershell
flutter build apk --debug
# El archivo queda en build/app/outputs/flutter-apk/app-debug.apk
```

---

## Generar el APK release firmado

### 1. Crear el keystore (una sola vez)

```bash
keytool -genkey -v \
  -keystore ~/mano-ya-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias mano-ya
```

Guarda el archivo `.jks` en un lugar seguro y **fuera del repositorio**: si
lo pierdes, no podras publicar actualizaciones de la misma app en Play
Store.

### 2. Crear `android/key.properties`

```properties
storePassword=<contrasena-del-keystore>
keyPassword=<contrasena-de-la-clave>
keyAlias=mano-ya
storeFile=C:/Users/TU_USUARIO/mano-ya-upload.jks
```

### 3. Referenciar el keystore desde Gradle

En `android/app/build.gradle.kts` (o `build.gradle` segun la version),
dentro del bloque `android { ... }`:

```kotlin
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 4. Compilar

```powershell
flutter build apk --release
# o el paquete para Play Store:
flutter build appbundle --release
```

Salida: `build/app/outputs/flutter-apk/app-release.apk` (o
`build/app/outputs/bundle/release/app-release.aab`).

Con las variables del `.env` incluidas:

```powershell
.\tool\run_flutter_with_env.ps1 build apk --release
```

### 5. Que NO se sube al repositorio

`android/key.properties` y el `.jks` deben quedar fuera de Git. Anade estas
lineas al `.gitignore` de la raiz:

```gitignore
# Firma de la app (nunca subir la clave privada)
android/key.properties
*.jks
*.keystore
```

Ademas, revisa que no se haya subido antes:

```bash
git rm --cached android/key.properties
```

---

## Verificar que los datos llegan

Con la app ya en uso (registro, catalogo, un servicio solicitado), ejecuta:

```powershell
.\n8n\verify-data.ps1
```

El script consulta la API de Supabase con la clave publica del `.env` y
muestra el conteo de filas de `profiles`, `workers`, `jobs`, `job_events`,
`reports` y `reviews`, ademas del detalle de los ultimos perfiles y
trabajos. Devuelve codigo de salida `0` si hay al menos un perfil y `1` si
no hay ninguno, para poder encadenarlo en un pipeline.

Tambien puedes comprobarlo a mano en el panel de Supabase:
**Table editor -> profiles / jobs / reports**.

Si la tabla `reports` todavia no existe en el proyecto, aplica la migracion:

```bash
supabase link --project-ref waxypsqomsljcljdqwra
supabase db push
```

---

## Resumen rapido

| Hosting | Coste | URL de ejemplo | Archivos del repo |
| --- | --- | --- | --- |
| GitHub Pages | Gratis | `Nomar-Arroyo.github.io/Project-Mano-Ya/` | `tool/github-actions/deploy-web.yml` |
| Cloudflare Pages | Gratis | `tu-sitio.pages.dev` | (configuracion en el panel) |
| Netlify | Gratis | `tu-sitio.netlify.app` | `netlify.toml` |
| Firebase Hosting | Gratis (Spark) | `tu-proyecto.web.app` | `firebase.json` |

Los cuatro sirven la misma carpeta `build/web`; lo unico que cambia es el
`--base-href` (`/<repo>/` en GitHub Pages, `/` en los demas) y donde se
declaran las variables de entorno.
