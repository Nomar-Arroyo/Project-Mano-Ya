<#
.SYNOPSIS
    Corrige el workflow de n8n que recibe los reportes de Mano Ya.

.DESCRIPTION
    El webhook de n8n devuelve "No authentication data defined on node!"
    cuando el nodo Webhook tiene activada la autenticacion por cabecera pero
    la credencial no tiene valor. Este script:

      1. Crea (o reutiliza) la credencial "Header Auth" con el nombre
         `x-webhook-secret` y el valor del secreto del `.env`.
      2. Localiza el workflow que tiene el nodo Webhook con la ruta
         configurada en `N8N_WEBHOOK_URL`.
      3. Le asigna esa credencial al nodo y activa el workflow.
      4. Verifica por API la configuracion sin ejecutar el workflow ni enviar
         un reporte o correo de prueba.

    Necesita una API Key de n8n (Settings > n8n API > Create an API key).

.PARAMETER BaseUrl
    URL de la instancia de n8n.

.PARAMETER ApiKey
    API Key de n8n. Si no se indica, se pide de forma segura.

.EXAMPLE
    .\tool\configurar-n8n-webhook.ps1 -BaseUrl https://mi-equipo.app.n8n.cloud -ApiKey n8n_api_xxx
#>
[CmdletBinding()]
param(
  [string]$BaseUrl = '',
  [string]$ApiKey = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$envFile = Join-Path $repoRoot '.env'
$values = @{}
foreach ($line in Get-Content $envFile) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
  $separator = $trimmed.IndexOf('=')
  if ($separator -lt 1) { continue }
  $values[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim().Trim('"').Trim("'")
}

$webhookUrl = $values['N8N_WEBHOOK_URL']
$secret = $values['N8N_WEBHOOK_SECRET']
if (-not $webhookUrl) { throw 'Falta N8N_WEBHOOK_URL en el .env.' }
if (-not $secret) { throw 'Falta N8N_WEBHOOK_SECRET en el .env.' }

if (-not $BaseUrl) { $BaseUrl = $values['N8N_BASE_URL'] }
if (-not $BaseUrl) {
  # La URL del webhook ya trae el dominio de la instancia:
  # https://<equipo>.app.n8n.cloud/webhook/<ruta>
  $uriWebhook = [Uri]$webhookUrl
  $BaseUrl = "$($uriWebhook.Scheme)://$($uriWebhook.Authority)"
}
if (-not $BaseUrl) { throw 'Falta la URL de la instancia de n8n (parametro -BaseUrl o variable N8N_BASE_URL).' }
$BaseUrl = $BaseUrl.TrimEnd('/')

if (-not $ApiKey) {
  $ApiKey = Read-Host 'API Key de n8n' -MaskInput
}
if (-not $ApiKey) { throw 'Falta la API Key de n8n.' }

$headers = @{ 'X-N8N-API-KEY' = $ApiKey; 'Content-Type' = 'application/json' }

# 1. Credencial de autenticacion por cabecera.
Write-Host '1/4 Credencial Header Auth...' -ForegroundColor Cyan
$credentialId = $null
try {
  $credentials = Invoke-RestMethod -Uri "$BaseUrl/api/v1/credentials?type=headerAuth" -Headers $headers -Method Get -TimeoutSec 60
  foreach ($credential in @($credentials.data)) {
    if ($credential.name -eq 'Mano Ya - x-webhook-secret') { $credentialId = $credential.id; break }
  }

  $credentialBody = @{
    name = 'Mano Ya - x-webhook-secret'
    type = 'headerAuth'
    data = @{ name = 'x-webhook-secret'; value = $secret }
  } | ConvertTo-Json -Depth 4

  if (-not $credentialId) {
    $created = Invoke-RestMethod -Uri "$BaseUrl/api/v1/credentials" -Headers $headers -Method Post -Body $credentialBody -TimeoutSec 60
    $credentialId = $created.data.id
    Write-Host "  creada (id $credentialId)" -ForegroundColor Green
  } else {
    Invoke-RestMethod -Uri "$BaseUrl/api/v1/credentials/$credentialId" -Headers $headers -Method Patch -Body $credentialBody -TimeoutSec 60 | Out-Null
    Write-Host "  actualizada (id $credentialId)" -ForegroundColor Green
  }
} catch {
  Write-Warning "  la API no dejo escribir la credencial: $($_.Exception.Message)"
  Write-Host '  Crea la credencial a mano en n8n:' -ForegroundColor Yellow
  Write-Host '    Credentials -> New -> Header Auth' -ForegroundColor Yellow
  Write-Host "      Name:  x-webhook-secret" -ForegroundColor Yellow
  Write-Host "      Value: $secret" -ForegroundColor Yellow
  Write-Host '  y asignasela al nodo Webhook (Authentication: Header Auth).' -ForegroundColor Yellow
  throw 'Falta la credencial de cabecera en n8n.'
}

# 2. Workflow que contiene el webhook.
Write-Host '2/4 Buscando el workflow del webhook...' -ForegroundColor Cyan
$rutaWebhook = ([Uri]$webhookUrl).AbsolutePath.Trim('/')
# El nodo Webhook de n8n guarda la ruta sin el prefijo "webhook/":
# https://host/webhook/request-endpoint -> parameters.path = "request-endpoint".
$path = $rutaWebhook -replace '^webhook/', ''
$workflows = Invoke-RestMethod -Uri "$BaseUrl/api/v1/workflows?limit=200" -Headers $headers -Method Get -TimeoutSec 60
$target = $null
$rutasVistas = @()
foreach ($workflow in @($workflows.data)) {
  foreach ($node in @($workflow.nodes)) {
    if ($node.type -ne 'n8n-nodes-base.webhook') { continue }
    $nodePath = $node.parameters.path
    $rutasVistas += "$($workflow.name): '$nodePath'"
    if ($nodePath -eq $path -or $nodePath -eq $rutaWebhook) {
      $target = $workflow
      break
    }
  }
  if ($target) { break }
}

if (-not $target) {
  throw "No se encontro ningun workflow con un nodo Webhook en la ruta '$path'. Rutas revisadas: $($rutasVistas -join ', ')"
}
Write-Host "  workflow: $($target.name) (id $($target.id))" -ForegroundColor Green

# 3. Asignar la credencial y activar.
Write-Host '3/4 Asignando la credencial y activando...' -ForegroundColor Cyan
$updatedNodes = @()
foreach ($node in @($target.nodes)) {
  $nodeCopy = $node | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  if ($nodeCopy.type -eq 'n8n-nodes-base.webhook') {
    $nodeCopy.parameters.authentication = 'headerAuth'
    if (-not $nodeCopy.PSObject.Properties['credentials']) {
      $nodeCopy | Add-Member -NotePropertyName 'credentials' -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $nodeCopy.credentials = [pscustomobject]@{
      httpHeaderAuth = [pscustomobject]@{ id = $credentialId; name = 'Mano Ya - x-webhook-secret' }
    }
  }
  $updatedNodes += $nodeCopy
}

$putBody = @{
  nodes = $updatedNodes
  settings = $target.settings
} | ConvertTo-Json -Depth 20

# PATCH con lo unico que cambia. Con PUT habria que reenviar el workflow
# entero y se perderian campos que la API no devuelve.
Invoke-RestMethod -Uri "$BaseUrl/api/v1/workflows/$($target.id)" -Headers $headers -Method Patch -Body $putBody -TimeoutSec 60 | Out-Null
Write-Host '  workflow actualizado' -ForegroundColor Green

try {
  Invoke-RestMethod -Uri "$BaseUrl/api/v1/workflows/$($target.id)/activate" -Headers $headers -Method Post -TimeoutSec 60 | Out-Null
  Write-Host '  workflow activado' -ForegroundColor Green
} catch {
  Write-Warning "  no se pudo activar (puede que ya estuviera activo): $($_.Exception.Message)"
}

# 4. Verificacion de configuracion sin ejecutar el workflow ni enviar correos.
Write-Host '4/4 Verificando la configuracion por API...' -ForegroundColor Cyan
$verifiedWorkflow = Invoke-RestMethod -Uri "$BaseUrl/api/v1/workflows/$($target.id)" -Headers $headers -Method Get -TimeoutSec 60
$verifiedWebhook = @($verifiedWorkflow.nodes) | Where-Object {
  $_.type -eq 'n8n-nodes-base.webhook' -and
  $_.parameters.path -eq $path
} | Select-Object -First 1

if (-not $verifiedWebhook -or
    $verifiedWebhook.parameters.authentication -ne 'headerAuth' -or
    $verifiedWebhook.credentials.httpHeaderAuth.id -ne $credentialId) {
  throw 'La API no confirma la autenticacion Header Auth en el nodo Webhook.'
}

Write-Host '  Header Auth y credencial confirmados. No se envio ningun reporte de prueba.' -ForegroundColor Green
