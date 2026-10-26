<#
.SYNOPSIS
    Despliega en Supabase todo lo que necesita Mano Ya: migraciones, Edge
    Function y secretos.

.DESCRIPTION
    Ejecuta, en este orden:
      1. `supabase link` con el proyecto (usa el PAT de Supabase).
      2. `supabase db push` para aplicar las migraciones pendientes
         (por ejemplo la que anade la cabecera `x-webhook-secret` al
         trigger de reportes).
      3. Despliega `notify-report` y `recommend-workers`.
      4. `supabase secrets set` con las variables de entorno de la funcion.

    Necesita un Personal Access Token de Supabase
    (Settings > API > Personal Access Tokens) y, opcionalmente, la
    contrasena de la base de datos.

.PARAMETER ProjectRef
    Referencia del proyecto de Supabase.

.PARAMETER AccessToken
    Personal Access Token de Supabase. Si no se indica, se pide de forma
    segura por pantalla.

.PARAMETER DatabasePassword
    Contrasena de la base de datos. Se usa para aplicar las migraciones
    sobre el pooler de la transaction.

.PARAMETER SinMigraciones
    Solo despliega la Edge Function y los secretos.

.EXAMPLE
    .\tool\desplegar-supabase.ps1 -AccessToken sbp_xxx -DatabasePassword 'mi-clave'
#>
[CmdletBinding()]
param(
  [string]$ProjectRef = 'waxypsqomsljcljdqwra',
  [string]$AccessToken = '',
  [string]$DatabasePassword = '',
  [switch]$SinMigraciones
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$envFile = Join-Path $repoRoot '.env'
if (-not (Test-Path $envFile)) {
  throw "No se encontro $envFile"
}

$values = @{}
foreach ($line in Get-Content $envFile) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
  $separator = $trimmed.IndexOf('=')
  if ($separator -lt 1) { continue }
  $values[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim().Trim('"').Trim("'")
}

if (-not $AccessToken) {
  $AccessToken = Read-Host 'Personal Access Token de Supabase' -MaskInput
}
if (-not $AccessToken) {
  throw 'Falta el Personal Access Token de Supabase.'
}
if (-not $DatabasePassword) {
  $DatabasePassword = Read-Host 'Contrasena de la base de datos' -MaskInput
}

# La CLI de Supabase lee el token de esta variable en todos los comandos
# (link, db push, functions deploy y secrets set). Asi el PAT no queda
# guardado en disco ni en el historial de la consola.
$env:SUPABASE_ACCESS_TOKEN = $AccessToken

Write-Host '1/4 Enlazando el proyecto...' -ForegroundColor Cyan
npx --yes supabase@latest link --project-ref $ProjectRef --password $DatabasePassword
if ($LASTEXITCODE -ne 0) { throw 'Fallo el enlace con el proyecto.' }

if (-not $SinMigraciones) {
  Write-Host '2/4 Aplicando las migraciones pendientes...' -ForegroundColor Cyan
  # Sin --include-all: solo se aplican las migraciones que faltan, las que ya
  # estan en la base de datos no se tocan.
  npx --yes supabase@latest db push
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la aplicacion de las migraciones.' }
} else {
  Write-Host '2/4 Migraciones omitidas.' -ForegroundColor Yellow
}

Write-Host '3/4 Desplegando la Edge Function notify-report...' -ForegroundColor Cyan
npx --yes supabase@latest functions deploy notify-report --no-verify-jwt --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Fallo el despliegue de la Edge Function.' }
npx --yes supabase@latest functions deploy recommend-workers --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Fallo el despliegue de recommend-workers.' }

Write-Host '4/4 Configurando los secretos de la funcion...' -ForegroundColor Cyan
$secrets = @{}
if ($values['N8N_WEBHOOK_SECRET']) { $secrets['N8N_WEBHOOK_SECRET'] = $values['N8N_WEBHOOK_SECRET'] }
if ($values['SUPPORT_EMAIL']) { $secrets['SUPPORT_EMAIL'] = $values['SUPPORT_EMAIL'] }
if ($values['RESEND_FROM_EMAIL']) { $secrets['RESEND_FROM_EMAIL'] = $values['RESEND_FROM_EMAIL'] }
if ($values['SUPABASE_URL']) { $secrets['SUPABASE_URL'] = $values['SUPABASE_URL'] }
if ($values['SUPABASE_ANON_KEY']) { $secrets['SUPABASE_ANON_KEY'] = $values['SUPABASE_ANON_KEY'] }
if ($values['RESEND_API_KEY']) { $secrets['RESEND_API_KEY'] = $values['RESEND_API_KEY'] }
if ($values['OLLAMA_BASE_URL']) { $secrets['OLLAMA_BASE_URL'] = $values['OLLAMA_BASE_URL'] }
if ($values['OLLAMA_MODEL']) { $secrets['OLLAMA_MODEL'] = $values['OLLAMA_MODEL'] }
if ($values['APP_ORIGIN']) { $secrets['APP_ORIGIN'] = $values['APP_ORIGIN'] }

if ($secrets.Count -eq 0) {
  Write-Host '  No hay secretos que configurar.' -ForegroundColor Yellow
} else {
  $pairs = @()
  foreach ($key in $secrets.Keys) { $pairs += "$key=$($secrets[$key])" }
  npx --yes supabase@latest secrets set --project-ref $ProjectRef @pairs
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la configuracion de los secretos.' }
}

if (-not $values['RESEND_API_KEY']) {
  Write-Host '  AVISO: falta RESEND_API_KEY en el .env. Sin ella la Edge Function' -ForegroundColor Yellow
  Write-Host '  no puede enviar el correo de aviso, aunque el reporte se guarde.' -ForegroundColor Yellow
}

Write-Host 'Listo.' -ForegroundColor Green
