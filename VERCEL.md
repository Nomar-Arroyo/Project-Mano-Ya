# Desplegar la web de Mano Ya en Vercel

Guia paso a paso para publicar la version web de **Mano Ya** en
<https://vercel.com> conectada al repositorio de GitHub.

---

## 1. Que se va a desplegar

| Dato | Valor |
| --- | --- |
| Repositorio | `https://github.com/Nomar-Arroyo/Project-Mano-Ya.git` |
| Rama | `main` |
| Directorio del proyecto (Root Directory) | `.` (la raiz del repositorio) |
| Build Command | `node tool/vercel-build.js` |
| Output Directory | `build/web` |
| Version de Flutter | `3.47.7` (stable) |
| URL asignada por Vercel | `https://project-mano-ya-web.vercel.app` |

> **Importante:** el *Output Directory* tiene que ser `build/web`. Si se deja
> en `web`, Vercel sirve el esqueleto HTML del repositorio (`index.html` con
> los placeholders sin sustituir) y la app no carga: fallan
> `flutter_bootstrap.js`, `main.dart.js` y los assets.

La web es una aplicacion Flutter compilada a JavaScript. Vercel no trae
Flutter instalado, asi que hace falta un *build server* de la comunidad.

---

## 2. Opcion A · Build server de la comunidad (recomendada)

Es la forma mas directa: Vercel compila el codigo cada vez que haces push.

1. En <https://vercel.com/new> pulsa **Add New... -> Project**.
2. Importa el repositorio `Nomar-Arroyo/Project-Mano-Ya`.
3. En **Configure Project**:
   - **Framework Preset**: `Other`
   - **Root Directory**: `.` (dejalo como esta)
   - **Build Command**: `node tool/vercel-build.js`
   - **Output Directory**: `build/web`
   - **Install Command**:
     `git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /tmp/flutter`
4. En **Environment Variables** anade las variables de la seccion 3.
5. Pulsa **Deploy**.

> Vercel lee las variables de entorno del proyecto y las expone al build con
> el formato `$NOMBRE`. El script Node compila Flutter con esas variables y activa
> el pago DEMO. Mantiene corto el `buildCommand` para respetar el límite de
> 256 caracteres del esquema de `vercel.json`.
> El lanzador usa el SDK instalado en `/tmp/flutter/bin/flutter`; el comando
> de instalación debe dejarlo en esa ruta.

### Si el build falla con "flutter: command not found"

Vercel no tiene Flutter por defecto. Opciones:

- **Opcion A1 · Build server de la comunidad**: en el paso 3, en vez de
  `Framework Preset: Other`, elige **Flutter** en la lista de build servers.
  Vercel usa la imagen `AidenGarcia/flutter-web`, que ya trae Flutter y
  Chrome. Si aparece, el `Build Command` y el `Output Directory` se rellenan
  solos: deja el build command tal cual y confirma que el output es
  `build/web`.
- **Opcion A2 · Imagen propia**: añade un `Dockerfile` con Flutter 3.47.7
  y configura en `vercel.json`:
  ```json
  {
    "builds": [
      { "src": "Dockerfile", "use": "@vercel/static-build" }
    ],
    "routes": [{ "src": "/(.*)", "dest": "/build/web" }]
  }
  ```

---

## 3. Variables de entorno en Vercel

En **Project Settings -> Environment Variables** anade estas (marca
**Production**, **Preview** y **Development** si quieres que tambien funcionen
las pruebas previas):

| Variable | Valor | Publica |
| --- | --- | --- |
| `SUPABASE_URL` | `https://waxypsqomsljcljdqwra.supabase.co` | Si |
| `SUPABASE_ANON_KEY` | Tu clave publica (`sb_publishable_...`) | Si |
| `GOOGLE_CLIENT_ID` | Id de cliente web de Google OAuth | Si |
| `GOOGLE_SERVER_CLIENT_ID` | Id de cliente de servidor (opcional) | Si |
| `WEB_APP_URL` | `https://project-mano-ya-web.vercel.app` | Si |

> **Nunca** pongas aqui la `SUPABASE_SERVICE_ROLE_KEY` ni el
> `N8N_WEBHOOK_SECRET`: son secretos de servidor y no deben ir al navegador.
> El build command de arriba solo pasa las variables publicas, precisamente
> para que las claves privadas nunca entren en el bundle de la web.
>
> En la web los reportes se authenticate con la sesion del usuario
> (`Authorization: Bearer <access_token>`) y la Edge Function `notify-report`
> valida la sesión antes de notificar. No se inyecta ningún secreto de n8n
> en la web ni en el APK.

Todas estas variables llegan al navegador dentro del bundle, asi que son
publicas por naturaleza: usa siempre la **clave anon** de Supabase, nunca la
de servicio.

---

## 4. Rutas y SPA

Flutter web usa el sistema de rutas del navegador, asi que al recargar una
ruta como `/reports` o `/two-factor` el servidor debe devolver siempre
`index.html`. Vercel lo hace con `vercel.json`:

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

Crea ese archivo en la raiz del repositorio si Vercel complains con un
`404` al recargar. El repositorio ya incluye `vercel.json` con esa regla y
con las cabeceras `no-cache` para `index.html` y `flutter_service_worker.js`,
de modo que la redireccion de Google OAuth (que vuelve a la app con `?code=`)
siempre resuelve a `index.html`.

> Si ademas usas GitHub Pages, el `--base-href` debe ser `/` para Vercel y
> `/<nombre-del-repo>/` para GitHub Pages. Como son dos salidas distintas, lo
> mas simple es compilar dos veces: una para Vercel (sin `--base-href`) y
> otra para GitHub Pages (con `--base-href`).

---

## 5. Conectar Google OAuth con el dominio de Vercel

Google solo acepta dominios que esten verificados en la consola de Google
Cloud:

1. En <https://console.cloud.google.com> abre **APIs y servicios -> Pantalla
   de consentimiento OAuth -> Tus aplicaciones**.
2. En **Client IDs -> Web client**, anade a **URIs de JavaScript autorizados**:
   ```
   https://project-mano-ya-web.vercel.app
   https://<tu-dominio-personalizado>
   ```
3. En **URIs de redireccionamiento autorizado** anade:
   ```
   https://waxypsqomsljcljdqwra.supabase.co/auth/v1/callback
   ```
4. En **Supabase -> Authentication -> URL Configuration**:
   - **Site URL**: `https://project-mano-ya-web.vercel.app`
   - **Redirect URLs**: `https://project-mano-ya-web.vercel.app/**` y
     `http://localhost:port/**` para las pruebas en local.

> Comprobacion rapida de que Supabase acepta el dominio, sin abrir el panel:
> ```bash
> curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' \
>   "https://waxypsqomsljcljdqwra.supabase.co/auth/v1/authorize?provider=google&redirect_to=https%3A%2F%2Fproject-mano-ya-web.vercel.app" \
>   -H "apikey: <SUPABASE_ANON_KEY>"
> ```
> Si devuelve `302` y en `redirect_url` aparece `accounts.google.com` con el
> `redirect_to` intacto, el dominio ya esta en la lista de Redirect URLs.

---

## 6. Comprobar el despliegue

```bash
# La web responde
curl -I https://project-mano-ya-web.vercel.app

# La app se registro bien (deberia responder 200 con la clave publica)
curl "https://waxypsqomsljcljdqwra.supabase.co/rest/v1/categories?select=id" \
  -H "apikey: <SUPABASE_ANON_KEY>"
```

En el navegador abre <https://project-mano-ya-web.vercel.app> y comprueba:

1. El registro con correo y contrasena.
2. El inicio de sesion con Google (si ya configuraste el proveedor).
3. La pantalla de reportes (`/reports`).
4. La pantalla de verificacion en dos pasos (`/two-factor`).

---

## 7. Alternativa · Publicar desde GitHub Actions

Si prefieres no usar el build server de Vercel, el workflow
`.github/workflows/deploy-web.yml` ya compila la web. Puedes añadir un
segundo job que suba el resultado a Vercel con el CLI:

```yaml
  deploy-vercel:
    name: Publicar en Vercel
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm i -g vercel@latest
      - run: vercel deploy --prebuilt --token=${{ secrets.VERCEL_TOKEN }} --prod
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

Necesitas en **GitHub -> Settings -> Secrets and variables -> Actions**:
`VERCEL_TOKEN`, `VERCEL_ORG_ID` y `VERCEL_PROJECT_ID`. El token se crea en
<https://vercel.com/account/tokens> y los identificadores estan en
**Project Settings -> General**.

---

## 8. Problemas frecuentes en Vercel

| Sintoma | Causa | Solucion |
| --- | --- | --- |
| `flutter: command not found` | Vercel no tiene Flutter | Usa el build server de la comunidad o el `Dockerfile` de la opcion A2 |
| `No Output Directory named "build/web"` | El build fallo antes de generar la carpeta | Mira el log del build; normalmente es `flutter pub get` o una variable de entorno mal puesta |
| `404` al recargar `/reports` | Falta la regla de reescritura a `index.html` | Anade el `vercel.json` de la seccion 4 |
| La pantalla sale sin datos | Faltan `SUPABASE_URL` o `SUPABASE_ANON_KEY` | Revisa las variables de entorno del proyecto y vuelve a desplegar |
| `redirect_uri_mismatch` al entrar con Google | El dominio de Vercel no esta autorizado | Anade el dominio en la consola de Google Cloud (seccion 5) |
| El build tarda mucho la primera vez | Se descargan el SDK de Dart y las dependencias | Es normal; las siguientes compilaciones usan la cache |
| El proyecto de Supabase se pausa | Plan Free sin actividad | Activa el workflow de keep alive (seccion 7.2 de `n8n/README.md`) |
