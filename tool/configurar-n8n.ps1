<#
.SYNOPSIS
    Importa y activa los workflows de Mano Ya en una instancia de n8n.

.DESCRIPTION
    Configura la instancia de n8n por su API REST:
      1. Crea (o actualiza) las Variables de n8n que usan los workflows.
      2. Importa los workflows de la carpeta `n8n` (reportes, mantenimiento
         y keep alive).
      3. Activa el workflow de keep alive, que es el que mantiene despierto
         el proyecto de Supabase.

    Necesita la API Key de n8n (Settings -> n8n API -> Create an API key) y
    las credenciales de Supabase en el `.env` de la raiz del proyecto.

.PARAMETER BaseUrl
    URL de la instancia de n8n. Por defecto `http://localhost:5678`.

.PARAMETER ApiKey
    API Key de n8n. Si no se indica, se pide de forma segura.

.PARAMETER ActivarReportes
    Tambien activa el workflow de reportes. Por defecto solo se activa el
    de keep alive, porque el de reportes necesita la Edge Function desplegada
    y el webhook configurado.

.EXAMPLE
    .\tool\configurar-n8n.ps1 -BaseUrl https://n8n.manoya.app -ApiKey n8n_api_xxx
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5678',
    [string]$ApiKey = '',
    [switch]$ActivarReportes
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

if (-not $ApiKey) {
    $ApiKey = Read-Host 'API Key de n8n' -MaskInput
}
if (-not $ApiKey) {
    Write-Error 'Falta la API Key de n8n'
    exit 1
}

# Se leen las credenciales del .env de la raiz del proyecto.
$rutaEnv = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path -LiteralPath $rutaEnv)) {
    Write-Error "No se encontro el archivo .env en $rutaEnv"
    exit 1
}
$env2 = @{}
Get-Content -LiteralPath $rutaEnv | ForEach-Object {
    $linea = $_.Trim()
    if ($linea -and -not $linea.StartsWith('#') -and $linea.Contains('=')) {
        $clave, $valor = $linea.Split('=', 2)
        $env2[$clave.Trim()] = $valor.Trim().Trim('"').Trim("'")
    }
}

$supabaseUrl = $env2['SUPABASE_URL']
$anonKey = $env2['SUPABASE_ANON_KEY']
$serviceKey = $env2['SUPABASE_SERVICE_ROLE_KEY']
$webhookSecret = $env2['N8N_WEBHOOK_SECRET']

$cabeceras = @{
    'X-N8N-API-KEY' = $ApiKey
    'Content-Type'  = 'application/json'
}

function Invoke-N8N {
    param([string]$Metodo, [string]$Ruta, $Cuerpo)
    $parametros = @{
        Uri             = "$BaseUrl/api/v1$Ruta"
        Method          = $Metodo
        Headers         = $cabeceras
        UseBasicParsing = $true
    }
    if ($null -ne $Cuerpo) {
        $parametros['Body'] = ($Cuerpo | ConvertTo-Json -Depth 30 -Compress)
    }
    try {
        return Invoke-RestMethod @parametros
    }
    catch {
        $detalle = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detalle = $_.ErrorDetails.Message }
        throw "$Metodo $Ruta fallo: $detalle"
    }
}

Write-Host "Instancia de n8n: $BaseUrl" -ForegroundColor Cyan

# ---------------------------------------------------------------- Variables
Write-Host "`n1. Variables de n8n" -ForegroundColor Green
$variables = @(
    @{ name = 'SUPABASE_URL';              value = $supabaseUrl },
    @{ name = 'SUPABASE_ANON_KEY';         value = $anonKey },
    @{ name = 'SUPABASE_SERVICE_ROLE_KEY'; value = $serviceKey },
    @{ name = 'N8N_WEBHOOK_SECRET';        value = $webhookSecret }
)
foreach ($variable in $variables) {
    if (-not $variable.value) {
        Write-Warning "Se omite $($variable.name): el valor esta vacio en el .env"
        continue
    }
    try {
        Invoke-N8N -Metodo 'PATCH' -Ruta "/variables/$($variable.name)" -Cuerpo @{
            name  = $variable.name
            value = $variable.value
        } | Out-Null
        Write-Host "   variable guardada: $($variable.name)"
    }
    catch {
        Write-Host "   no se pudo guardar $($variable.name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --------------------------------------------------------------- Workflows
Write-Host "`n2. Importacion de workflows" -ForegroundColor Green
$rutaWorkflows = Join-Path $PSScriptRoot '..\n8n'
$archivos = @(
    'mano-ya-keepalive.json',
    'mano-ya-mantenimiento.json',
    'mano-ya-reportes.json'
)

$importados = @{}
foreach ($archivo in $archivos) {
    $ruta = Join-Path $rutaWorkflows $archivo
    if (-not (Test-Path -LiteralPath $ruta)) {
        Write-Warning "No existe $archivo, se omite"
        continue
    }
    $contenido = Get-Content -LiteralPath $ruta -Raw | ConvertFrom-Json
    $body = @{ name = $contenido.name; nodes = $contenido.nodes; connections = $contenido.connections; settings = $contenido.settings }
    try {
        $creado = Invoke-N8N -Metodo 'POST' -Ruta '/workflows' -Cuerpo $body
        $importados[$archivo] = $creado.id
        Write-Host "   importado: $($contenido.name) (id $($creado.id))"
    }
    catch {
        Write-Host "   fallo al importar $archivo : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------- Activacion
Write-Host "`n3. Activacion" -ForegroundColor Green
$aActivar = @('mano-ya-keepalive.json')
if ($ActivarReportes) { $aActivar += 'mano-ya-reportes.json' }

foreach ($archivo in $aActivar) {
    if (-not $importados.ContainsKey($archivo)) { continue }
    $id = $importados[$archivo]
    try {
        Invoke-N8N -Metodo 'PATCH' -Ruta "/workflows/$id" -Cuerpo @{ active = $true } | Out-Null
        Write-Host "   activo: $archivo" -ForegroundColor Green
    }
    catch {
        Write-Host "   no se pudo activar $archivo : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nListo. En n8n revisa que los marcadores {{SUPABASE_URL}} y {{SUPABASE_ANON_KEY}} esten resueltos por las Variables o sustituyelos a mano." -ForegroundColor Cyan
