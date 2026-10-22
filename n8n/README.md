# n8n en Mano Ya

Automatizaciones del proyecto **Mano Ya**: los reportes que envian los
usuarios de la app llegan a n8n, n8n llama a la Edge Function de Supabase y
esa funcion manda el correo al equipo de soporte. Ademas hay un workflow
diario que ejecuta la retencion de datos de la base de datos.

| Archivo | Que es |
| --- | --- |
| `mano-ya-reportes.json` | Workflow principal: recibe el reporte, lo valida y pide el correo. |
| `mano-ya-mantenimiento.json` | Workflow de cron diario: llama a `public.run_maintenance()`. |
| `mano-ya-keepalive.json` | Workflow de keep alive: GET programados a Supabase para que el proyecto no se pause. |
| `supabase-webhook-setup.sql` | Script para pegar en el SQL Editor de Supabase y dejar listo el webhook. |
| `verify-data.ps1` | Script de PowerShell que comprueba que los datos de la app llegan a Supabase. |

---

## 1. Como funciona el flujo completo

```
App Flutter ──POST──> n8n /webhook/reportes ──POST──> Edge Function notify-report
                                                          │
                                                          └──> Resend ──> correo a soporte

Trigger reports_notify_n8n (pg_net) ──POST──> n8n /webhook/reportes
```

- **La app** siempre guarda el reporte en la tabla `public.reports` y, si
  tiene `N8N_WEBHOOK_URL`, tambien lo manda al webhook de n8n.
- **El trigger de la base de datos** (`reports_notify_n8n`, definido en
  `supabase/migrations/20240101000200_reportes_y_automatizacion.sql`) hace lo
  mismo con `net.http_post` en cuanto se inserta la fila.
- Por eso hay **doble via**: la app avisa y la base de datos tambien avisa.
- Es **idempotente**: el trigger marca `notified_at = now()` en la fila del
  reporte, asi que el panel y las consultas permiten saber que el reporte ya
  fue notificado y no hay que procesarlo dos veces a mano.
- La **Edge Function** es la unica que manda correos y exige el secreto
  `x-webhook-secret`, de modo que solo n8n (que lo tiene en su
  configuracion) puede pedir un envio.

---

## 2. Instalar n8n

### 2.1 Opcion A · Docker en tu equipo (la mas rapida para probar)

```bash
docker run -d --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_HOST=localhost \
  -e N8N_PORT=5678 \
  -e WEBHOOK_URL=https://n8n.tudominio.com/ \
  -e GENERIC_TIMEZONE=America/Caracas \
  -e N8N_ENCRYPTION_KEY=cadena-larga-y-aleatoria-de-32-caracteres \
  -e N8N_USER_MANAGEMENT_DISABLED=true \
  --restart always \
  n8nio/n8n
```

Abre <http://localhost:5678>.

Notas importantes:

- **`WEBHOOK_URL` es obligatoria en produccion.** n8n construye la URL del
  webhook a partir de ese valor; si no lo pones, generara URLs con
  `localhost` y el trigger de Supabase nunca podra llamarte.
- **`N8N_ENCRYPTION_KEY`**: sin ella, las credenciales guardadas se cifran con
  una clave aleatoria que cambia en cada reinicio y n8n deja de poder
  descifrarlas. Pon una cadena larga y guardala.
- **Autenticacion**: desde n8n 1.0 las variables `N8N_BASIC_AUTH_ACTIVE`,
  `N8N_BASIC_AUTH_USER` y `N8N_BASIC_AUTH_PASSWORD` ya no existen. En su lugar
  n8n pide crear la cuenta de administrador la primera vez que entras. Para una
  demo local puedes saltarte esa pantalla con `N8N_USER_MANAGEMENT_DISABLED=true`
  (no recomendado en un servidor publico: cualquiera que conozca la URL
  entra). Con la cuenta de administrador ademas puedes crear usuarios de solo
  lectura para el equipo.
- **`--restart always`**: el contenedor vuelve solo si la maquina se reinicia.
- Volume `n8n_data`: guarda los workflows, las credenciales y los historiales.
  Sin el, cada reinicio del contenedor pierde todo.

Variante antigua (n8n 0.x), por si tienes una version previa instalada:

```bash
docker run -d --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=clave-segura \
  -e N8N_ENCRYPTION_KEY=cadena-larga-y-aleatoria \
  -e WEBHOOK_URL=https://n8n.tudominio.com/ \
  --restart always n8nio/n8n
```

### 2.2 Opcion B · n8n Cloud (prueba gratuita)

1. Entra en <https://app.n8n.cloud> y crea una cuenta.
2. n8n ofrece un periodo de prueba gratuito de 14 dias con el plan Pro
   (revisa las condiciones vigentes en <https://n8n.com/pricing>).
3. Tu instancia queda en `https://<tu-usuario>.app.n8n.cloud`.
4. La URL del webhook de produccion sera
   `https://<tu-usuario>.app.n8n.cloud/webhook/reportes`.

Ventaja: no hay que mantener nada. Desventaja: la prueba caduca y las
ejecuciones tienen limite segun el plan.

### 2.3 Opcion C · Railway, Render o Fly.io (con planes gratuitos o de prueba)

Los tres desplegan n8n como un contenedor a partir de la imagen oficial:

```bash
# Railway (plan de prueba con credito)
railway login
railway init
railway up

# Render (crea un "Web Service" con la imagen n8nio/n8n)
# Fly.io
fly launch --image n8nio/n8n --machine-type shared-cpu-1x --vm-size shared-cpu-1x
```

En todos los casos:

1. Crea el servicio con la imagen `n8nio/n8n` y el puerto **5678**.
2. Añade las variables de entorno:

   | Variable | Valor |
   | --- | --- |
   | `WEBHOOK_URL` | `https://<tu-dominio-n8n>/` |
   | `N8N_ENCRYPTION_KEY` | cadena aleatoria larga |
   | `GENERIC_TIMEZONE` | `America/Caracas` |
   | `N8N_USER_MANAGEMENT_DISABLED` | `true` solo en pruebas locales |

3. Monta un volumen persistente (Railway: `n8n_data:/home/node/.n8n`,
   Render: disco, Fly.io: volumen) para no perder los workflows.
4. Espera a que la instancia arranque y entra por el dominio generado.

Avisos honestos sobre los planes gratuitos:

- **Render** apaga el servicio tras unos minutos sin trafico y lo vuelve a
  encender cuando llega una peticion: el primer webhook puede tardar 30
  segundos o mas (arranque en frio). Para una demo sirve; para produccion,
  mejor una VPS.
- **Railway** da credito de prueba y despues pasa a ser de pago; el volumen
  persistente cuesta un poco mas.
- **Fly.io**: `shared-cpu-1x` es la maquina mas barata y entra en el
  credito inicial.
- Los tres suspenden el servicio cuando no queda saldo: el webhook dejaria
  de responder y la app mostraria "Reporte registrado" (el reporte queda
  guardado en Supabase de todos modos).

### 2.4 Opcion D · Una VPS (la mas barata a largo plazo)

Un servidor de 1 vCPU y 1 GB de RAM (Hetzner, DigitalOcean, Vultr...) cuesta
pocos dolares al mes y aguanta 24/7 sin cortes por inactividad.

```bash
# Instalar Docker en Ubuntu
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh

# Publicar n8n detras de Caddy (con HTTPS automatico)
docker run -d --name n8n -p 127.0.0.1:5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_HOST=n8n.tudominio.com \
  -e WEBHOOK_URL=https://n8n.tudominio.com/ \
  -e N8N_ENCRYPTION_KEY=cadena-larga-y-aleatoria \
  -e GENERIC_TIMEZONE=America/Caracas \
  --restart always n8nio/n8n
```

Con un proxy inverso (Caddy o Nginx) delante, HTTPS ya no es opcional: la
app y el trigger de Supabase necesitan una URL valida.

---

## 3. Importar los workflows

1. Entra a n8n.
2. Menu superior derecho -> **Import from File**.
3. Selecciona `n8n/mano-ya-reportes.json`, despues
   `n8n/mano-ya-mantenimiento.json` y por ultimo
   `n8n/mano-ya-keepalive.json`.
4. Los workflows aparecen desactivados: revisa los nodos y activalos cuando
   todo este listo.

### 3.1 Marcadores que hay que sustituir

Los workflows traen marcadores de texto porque n8n no puede resolver
variables de entorno en un archivo importado (la resolucion depende de como
se creo el workflow). Sustituyelos en el nodo correspondiente:

| Marcador | Donde aparece | Que poner |
| --- | --- | --- |
| `{{SUPABASE_URL}}` | Nodo HTTP Request (URL) | `https://waxypsqomsljcljdqwra.supabase.co` |
| `{{N8N_WEBHOOK_SECRET}}` | Cabecera `x-webhook-secret` | El mismo valor que pongas en los secretos de Supabase |
| `{{SUPABASE_SERVICE_ROLE_KEY}}` | Cabeceras `apikey` y `Authorization` | La clave `service_role` (o `sb_secret_`) del proyecto. **Nunca** la pongas en la app |
| `{{GOOGLE_SHEETS_ID}}` | Nodo de Google Sheets (opcional) | El id de la hoja de calculo |
| `{{SLACK_CHANNEL_ID}}` | Nodo de Slack (opcional) | El id del canal |

Dos formas de dejarlo bien:

- **Sustituir el texto**: abre el nodo, edita el valor del campo y pega el
  valor real. Es lo mas simple y lo que se recomienda.
- **Usar variables de n8n**: en n8n existe el menu **Variables** (en la
  izquierda, arriba). Crea `SUPABASE_URL`, `N8N_WEBHOOK_SECRET` y
  `SUPABASE_SERVICE_ROLE_KEY` y en el nodo escribe
  `={{ $vars.SUPABASE_URL }}`. Asi no quedan secretos en el archivo exportado.

> Las variables de entorno del sistema (`$env`) estan bloqueadas por defecto
> en n8n (`N8N_BLOCK_ENV_ACCESS_IN_NODE=true`). Usa las **Variables** de n8n
> o los marcadores de texto.

### 3.2 Nodos opcionales (desactivados)

| Nodo | Para que sirve | Como se activa |
| --- | --- | --- |
| `Consultar reporte en Supabase` | Comprobar que el reporte existe de verdad en `public.reports` antes de avisar a soporte (endurece el webhook, que es publico) | Sustituye `{{SUPABASE_URL}}` y `{{SUPABASE_SERVICE_ROLE_KEY}}`, activa el nodo y anade un nodo **IF** que compruebe que la respuesta trae una fila (`{{ $json.length }} > 0`) para decidir si se manda el correo |
| `Apend report (Google Sheets)` | Llevar el historial de reportes a una hoja de calculo | Crea la credencial **Google Sheets**, deja el id de la hoja en `{{GOOGLE_SHEETS_ID}}`, usa una pestana llamada `Reportes` con los encabezados `id, categoria, severidad, motivo, detalle, reporta, correo, reportado, servicio_id, creado` y activa el nodo |
| `Avisar a soporte (Slack)` | Aviso instantaneo en un canal de Slack | Crea una app en <https://api.slack.com/apps> con el permiso `chat:write`, crea la credencial **Slack API** con el bot token (`xoxb-...`), pon el id del canal en `{{SLACK_CHANNEL_ID}}` y activa el nodo |

Los tres nodos opcionales se pueden activar por separado. Si un nodo falla, el
flujo sigue adelante (`onError: continue`) para que la respuesta al webhook
nunca se quede colgada.

---

## 4. Conectar Supabase con n8n

### 4.1 Desplegar la Edge Function

```bash
# Con la Supabase CLI
supabase link --project-ref waxypsqomsljcljdqwra
supabase functions deploy notify-report --no-verify-jwt
```

Sin la CLI, desde el panel: **Edge Functions -> New Function -> paste code**,
pega el contenido de `supabase/functions/notify-report/index.ts` y pulsa
**Deploy**.

### 4.2 Guardar los secretos de la funcion

En **Supabase -> Project Settings -> Edge Functions -> Secrets**:

| Secreto | Valor |
| --- | --- |
| `RESEND_API_KEY` | La clave de <https://resend.com> (`re_...`). Requiere un dominio verificado en Resend para enviar desde tu propia direccion |
| `SUPPORT_EMAIL` | El correo que recibe los reportes (por ejemplo `soporte@manoya.app`) |
| `N8N_WEBHOOK_SECRET` | Un texto largo y aleatorio, por ejemplo el resultado de `openssl rand -hex 24` |
| `RESEND_FROM_EMAIL` | Remitente, por ejemplo `Mano Ya <reportes@manoya.app>` (opcional) |

El mismo `N8N_WEBHOOK_SECRET` es el que tiene que poner n8n en la cabecera
`x-webhook-secret` del nodo HTTP Request.

### 4.3 Guardar la URL del webhook en la base de datos

Pega en el **SQL Editor** de Supabase el archivo `n8n/supabase-webhook-setup.sql`
o ejecuta directamente:

```sql
update public.app_settings
   set value = 'https://<tu-n8n>/webhook/reportes'
 where key = 'n8n_report_webhook';
```

Tambien puedes usar la funcion auxiliar que crea el script:

```sql
select public.set_n8n_webhook('https://<tu-n8n>/webhook/reportes');
```

Comprueba que quedo guardado:

```sql
select * from public.app_settings where key = 'n8n_report_webhook';
```

Y prueba el circuito completo (esto inserta un reporte de ejemplo y debe
rellenar `notified_at`):

```sql
insert into public.reports (reporter_name, reporter_email, target_name, category, reason, details)
values ('Prueba', 'prueba@manoya.app', 'Prueba', 'otro', 'Prueba del webhook', 'Reporte de prueba')
returning id, notified_at;
```

Si `notified_at` vuelve con una fecha, el trigger encontro la URL y disparo
la llamada. Si vuelve `NULL`, la URL esta vacia o el trigger no esta
habilitado.

> Si el trigger de la base de datos y la app avisan a la vez, el correo puede
> llegar duplicado. Es inofensivo: ambos reportes apuntan al mismo `id` y el
> workflow puede filtrar por ese id si mas adelante quieres evitarlo.

### 4.4 Prueba manual del webhook

```bash
curl -X POST "https://<tu-n8n>/webhook/reportes" \
  -H "Content-Type: application/json" \
  -d '{"id":"11111111-1111-1111-1111-111111111111","categoria":"calidad","severidad":"normal","motivo":"Prueba manual","detalle":"Llamada desde la terminal","reporta":"Prueba","correo":"prueba@manoya.app","reportado":"","servicio_id":null,"creado":"2024-01-01T00:00:00Z"}'
```

Respuesta esperada:

```json
{ "ok": true, "id": "11111111-1111-1111-1111-111111111111", "mensaje": "Reporte recibido y enviado a soporte." }
```

---

## 5. Configurar el `.env` local

En la raiz del proyecto, `.env` (esta en `.gitignore`, no se sube nunca):

```dotenv
SUPABASE_URL=https://waxypsqomsljcljdqwra.supabase.co
SUPABASE_ANON_KEY=sb_publishable_TU_CLAVE_PUBLICA

WEB_APP_URL=https://tu-dominio-web/
N8N_WEBHOOK_URL=https://<tu-n8n>/webhook/reportes
SUPPORT_EMAIL=soporte@manoya.app

N8N_WEBHOOK_SECRET=el-mismo-secreto-que-esta-en-supabase
```

El script `tool/run_flutter_with_env.ps1` lee ese archivo y pasa a Flutter
las variables que esten Informadas como `--dart-define`:

| Variable del `.env` | `--dart-define` | Nota |
| --- | --- | --- |
| `SUPABASE_URL` | `SUPABASE_URL` | Obligatoria |
| `SUPABASE_ANON_KEY` | `SUPABASE_ANON_KEY` | Obligatoria, clave publica |
| `GOOGLE_CLIENT_ID` | `GOOGLE_CLIENT_ID` | Opcional |
| `GOOGLE_SERVER_CLIENT_ID` | `GOOGLE_SERVER_CLIENT_ID` | Opcional |
| `WEB_APP_URL` | `WEB_APP_URL` | Opcional, si no se pasa usa `https://mano-ya.app` |
| `N8N_WEBHOOK_URL` | `N8N_WEBHOOK_URL` | Opcional, si no se pasa los reportes no se notifican |
| `SUPPORT_EMAIL` | `SUPPORT_EMAIL` | Opcional, si no se pasa usa `soporte@manoya.app` |

```powershell
# Arrancar la app con todo el .env inyectado
.\tool\run_flutter_with_env.ps1 run

# Compilar la web con las mismas variables
.\tool\run_flutter_with_env.ps1 build web --release
```

**`N8N_WEBHOOK_SECRET` NO se pasa como `--dart-define`.** Es un secreto de
servidor: viaja de n8n a la Edge Function, nunca al navegador ni al
movil. Si lo metieras en el bundle de la web, cualquiera podria leerlo del
JavaScript y mandar correos a soporte.

> El webhook de n8n es publico (la app envia el reporte sin cabeceras de
> autenticacion). Para endurecerlo puedes activar la autenticacion por
> cabecera del nodo Webhook de n8n, pero entonces tendrias que modificar la
> app para que mande esa cabecera. Con la configuracion actual el unico
> riesgo real es que alguien que adivine la URL genere un correo de aviso
> sin relacion.

---

## 6. Mantenerlo funcionando 24/7

### 6.1 Supabase no necesita servidor propio

El proyecto `waxypsqomsljcljdqwra` es **gestionado**: la base de datos, la
autenticacion, el almacenamiento y las Edge Functions ya estan online y
funcionando aunque tu equipo este apagado. Lo unico que necesitas es que el
servidor de n8n este encendido.

### 6.2 El plan gratuito de Supabase

- En el plan **Free**, Supabase **pausa el proyecto despues de 7 dias de
  inactividad**: la base de datos se apaga, el sitio web y las Edge Functions
  dejan de responder y las claves dan error `401` o `JWT expired`.
- **Como evitarlo**: cualquier actividad programada cuenta como actividad.
  La migracion ya crea el job de `pg_cron` que corre todas las noches:

  ```sql
  select cron.schedule('mano-ya-mantenimiento', '17 3 * * *', 'select public.run_maintenance();');
  ```

  Una consulta diaria es suficiente para que el proyecto nunca se pause.
  Comprueba que existe con:

  ```sql
  select jobid, jobname, schedule, command, active from cron.job;
  ```

  Si el job no esta (algunos planes no dan `pg_cron`), crea una regla de
  **Database Webhook** en el panel de Supabase que llame cada dia a
  `public.run_maintenance()`, o deja que sea el workflow de n8n de la
  seccion 7 el que la ejecute.

- **Alternativas de pago**: el plan **Pro** ($25 al mes) da mas recursos,
  backups y no pausa el proyecto; el plan **Team** ($599 al mes) es para
  organizaciones. Para un proyecto de tesis el plan Free con el cron
  configurado es suficiente.

### 6.3 El servidor de n8n

- Docker en una VPS: se mantiene con `--restart always` y el sistema
  `supervisord` o `systemd` de la VPS.
- Railway / Render / Fly.io: revisa el panel, el servicio duerme por inactividad
  o se suspende si se acaban los creditos.
- n8n Cloud: es el que menos mantenimiento da, pero tiene limite de
  ejecuciones y es de pago.

---

## 7. Tareas programadas (cron) en n8n

### 7.1 El workflow de mantenimiento

`n8n/mano-ya-mantenimiento.json` ya viene hecho:

1. **Disparador diario** (`Schedule Trigger`): todos los dias a las 03:30.
2. **Ejecutar run_maintenance**: un nodo HTTP Request que hace

   ```
   POST {{SUPABASE_URL}}/rest/v1/rpc/run_maintenance
   apikey: {{SUPABASE_SERVICE_ROLE_KEY}}
   Authorization: Bearer {{SUPABASE_SERVICE_ROLE_KEY}}
   ```

   La funcion `public.run_maintenance()` borra los reportes cerrados de hace
   mas de 180 dias, el historial de estados de trabajos terminados de hace
   mas de un ano y sincroniza el catalogo de trabajadores con los perfiles.
   Como es `security definer` y la RPC exige rol de servicio, se llama con
   la **service role key**.
3. **Resumir ejecucion**: deja un objeto con el resultado, listo para
   conectarlo a un nodo de Slack o de correo si quieres enterarte cuando
   falle.

Importalo, sustituye `{{SUPABASE_URL}}` y `{{SUPABASE_SERVICE_ROLE_KEY}}` y
activa el workflow.

### 7.2 El workflow de keep alive (mantener el proyecto despierto)

En el plan **Free**, Supabase pausa el proyecto a los 7 dias sin actividad.
Una peticion HTTP cuenta como actividad, asi que basta con un GET periodico.

`n8n/mano-ya-keepalive.json` ya viene hecho:

1. **Cada 12 horas** (`Schedule Trigger`): dispara el workflow dos veces al
   dia. Si tu n8n esta en UTC, no importa: el intervalo es relativo.
2. **GET profiles**: un nodo HTTP Request que hace

   ```
   GET {{SUPABASE_URL}}/rest/v1/profiles?select=id&limit=1
   apikey: {{SUPABASE_ANON_KEY}}
   Authorization: Bearer {{SUPABASE_ANON_KEY}}
   ```

   Usa la clave **publica** (publishable/anon): basta para leer y cuenta como
   actividad, asi que no hace falta exponer la service role.
3. **GET jobs**: segunda peticion de respaldo por si la primera falla.
4. **Resumir keep alive**: deja el resultado de la ejecucion.

Para configurarlo:

1. Importa `n8n/mano-ya-keepalive.json` (menu derecho -> **Import from File**).
2. Sustituye `{{SUPABASE_URL}}` por `https://waxypsqomsljcljdqwra.supabase.co`.
3. Sustituye `{{SUPABASE_ANON_KEY}}` por tu clave publica
   (`sb_publishable_...`).
4. Activa el workflow y pulsa **Execute workflow** una vez para comprobar que
   responde `200`.

> Si usas **Variables** de n8n en vez de sustituir el texto, escribe
> `={{ $vars.SUPABASE_URL }}` y `={{ $vars.SUPABASE_ANON_KEY }}` en los nodos.
> Asi el archivo exportado no guarda ningun secreto.

### 7.3 La funcion `public.run_maintenance()` a mano

Si no quieres depender de n8n para el mantenimiento, desde el SQL Editor:

```sql
select public.run_maintenance();
```

### 7.4 Otros cron utiles

| Tarea | Expresion cron | Que hace |
| --- | --- | --- |
| Mantenimiento diario | `30 3 * * *` | Ejecuta `public.run_maintenance()` |
| Keep alive del proyecto | cada 12 horas | GET a la API REST de Supabase (workflow `mano-ya-keepalive.json`) |
| Resumen de la plataforma | `0 8 * * *` | Llama a la vista `public.dashboard_summary` y lo manda a soporte |

Para que la zona horaria sea la de Venezuela (UTC-4), pon `GENERIC_TIMEZONE=America/Caracas`
en el servidor de n8n.

---

## 8. Comprobar que todo funciona

```powershell
# Datos de la app en Supabase (perfiles, trabajos, reportes, resenas...)
.\n8n\verify-data.ps1
```

El script usa la clave publica del `.env`, muestra el conteo de filas de
cada tabla y el detalle de los ultimos perfiles y trabajos. Devuelve codigo
de salida `0` si hay al menos un perfil y `1` si no hay ninguno, para poder
usarlo en un pipeline.

Lista de comprobacion manual:

1. `n8n` responde en <https://tu-n8n> y el workflow **Mano Ya - Reportes**
   esta activo.
2. La Edge Function `notify-report` esta desplegada y sus secretos puestos.
3. `app_settings.n8n_report_webhook` tiene la URL correcta.
4. `curl` de la seccion 4.4 devuelve `{"ok": true, ...}`.
5. Llega el correo a `SUPPORT_EMAIL`.
6. La app envia reportes y en `n8n/verify-data.ps1` aparecen filas en
   `reports` con `notified_at` relleno.

---

## 9. Problemas frecuentes

| Sintoma | Causa probable | Solucion |
| --- | --- | --- |
| n8n responde `404` al webhook | La URL guardada en `app_settings` no coincide con el workflow activo | Copia la URL **Production** del nodo Webhook (n8n muestra las URLs de test y de produccion) |
| `401` desde la Edge Function | El secreto no coincide o no esta puesto | Revisa `N8N_WEBHOOK_SECRET` en los secretos de Supabase y en el nodo HTTP Request |
| El trigger no dispara | `pg_net` no instalado o URL vacia | Aplica la migracion y comprueba `select value from public.app_settings where key = 'n8n_report_webhook'` |
| El correo no llega | Dominio de Resend sin verificar o clave incorrecta | Verifica el dominio en Resend y el valor de `RESEND_API_KEY` |
| El webhook tarda 30 s | El hosting gratis apaga el servicio por inactividad | Es el arranque en frio de Render/Railway: usa una VPS o n8n Cloud |
| `JWT expired` al usar la app | El proyecto de Supabase esta pausado por inactividad | Configura el `pg_cron` diario (seccion 6.2) o pasa al plan Pro |
