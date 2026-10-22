# Workflows de GitHub Actions

Esta carpeta guarda los archivos de workflow listos para copiar.

## Por que no estan en `.github/workflows/`

El token de acceso personal (PAT) que se usa para subir los cambios a GitHub
**no tiene el permiso `workflow`**, y GitHub rechaza cualquier `push` que
cree o modifique un archivo dentro de `.github/workflows/`:

```
! [remote rejected] main -> main (refusing to allow a Personal Access Token
to create or update workflow `.github/workflows/deploy-web.yml` without
`workflow` scope)
```

Por eso el archivo vive en `tool/github-actions/` y hay dos formas de
activarlo.

### Opcion 1 · Crear un PAT con permiso `workflow` (recomendada)

1. En <https://github.com/settings/tokens/new> crea un token personal.
2. Marca la casilla **`workflow`** en la seccion de permisos.
3. Copia el archivo:

   ```powershell
   Copy-Item .\tool\github-actions\deploy-web.yml .\.github\workflows\deploy-web.yml
   ```

4. Sube el cambio con ese token:

   ```powershell
   git add .github/workflows/deploy-web.yml
   git commit -m "chore: activa el workflow de despliegue en GitHub Pages"
   git push origin main
   ```

5. En el repositorio: **Settings -> Pages -> Build and deployment ->
   Source: "Deploy from a branch" -> rama `gh-pages` -> carpeta `/ (root)`.

### Opcion 2 · Dejarlo manual

Si no quieres crear otro token, compila y publica la web a mano:

```powershell
# Compilar
.\tool\run_flutter_with_env.ps1 build web --release --base-href "/"

# Copiar el resultado a la rama gh-pages
cd build\web
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name="Mano Ya" -c user.email="manoya@example.com" commit -q -m "Deploy manual"
git push -f https://github.com/Nomar-Arroyo/Project-Mano-Ya.git HEAD:gh-pages
```

## Secretos que necesita el workflow

En **Settings -> Secrets and variables -> Actions** crea estos secretos:

| Secreto | Valor |
| --- | --- |
| `SUPABASE_URL` | `https://waxypsqomsljcljdqwra.supabase.co` |
| `SUPABASE_ANON_KEY` | Clave publica (`sb_publishable_...`) |
| `GOOGLE_CLIENT_ID` | Client ID web de Google OAuth |
| `GOOGLE_SERVER_CLIENT_ID` | Client ID web de Google OAuth |
| `WEB_APP_URL` | URL publica de la web |
| `N8N_WEBHOOK_URL` | `https://<tu-n8n>/webhook/reportes` |
| `SUPPORT_EMAIL` | `soporte@manoya.app` |

La clave de servicio de Supabase **no** se pone aqui: el workflow solo
compila la web, que es una aplicacion publica.
