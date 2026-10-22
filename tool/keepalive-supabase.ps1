<#
.SYNOPSIS
    Mantiene despierto el proyecto de Supabase con una peticion GET.

.DESCRIPTION
    En el plan Free de Supabase el proyecto se pausa a los 7 dias sin
    actividad. Cualquier peticion HTTP a la API REST cuenta como actividad,
    por lo que este script es una alternativa al workflow de n8n
    `n8n/mano-ya-keepalive.json`.

    Se puede usar a mano para comprobar que el proyecto responde, o bien
    desde el Programador de tareas de Windows para ejecutarlo cada 12 horas.

.PARAMETER Horas
    Cada cuantas horas se ejecuta el script cuando se programa como tarea
    repetitiva. Por defecto 12.

.EXAMPLE
    .\tool\keepalive-supabase.ps1

.EXAMPLE
    Programar cada 12 horas con el Programador de tareas:
    powershell -ExecutionPolicy Bypass -File .\tool\keepalive-supabase.ps1
#>
[CmdletBinding()]
param(
    [int]$Horas = 12
)

$ErrorActionPreference = 'Stop'

# Se lee el .env de la raiz del proyecto para obtener la URL y la clave publica.
$rutaEnv = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path -LiteralPath $rutaEnv)) {
    Write-Error "No se encontro el archivo .env en $rutaEnv"
    exit 1
}

$variables = @{}
Get-Content -LiteralPath $rutaEnv | ForEach-Object {
    $linea = $_.Trim()
    if ($linea -and -not $linea.StartsWith('#') -and $linea.Contains('=')) {
        $clave, $valor = $linea.Split('=', 2)
        $variables[$clave.Trim()] = $valor.Trim().Trim('"').Trim("'")
    }
}

$url = $variables['SUPABASE_URL']
$clave = $variables['SUPABASE_ANON_KEY']

if (-not $url) {
    Write-Error 'Falta SUPABASE_URL en el archivo .env'
    exit 1
}
if (-not $clave -or $clave -match 'TU_CLAVE|your_key|aqui|pendiente') {
    Write-Error 'Falta SUPABASE_ANON_KEY real en el archivo .env'
    exit 1
}

$destino = "$url/rest/v1/profiles?select=id&limit=1"
$cabeceras = @{
    'apikey'       = $clave
    'Authorization' = "Bearer $clave"
}

try {
    $respuesta = Invoke-WebRequest -Uri $destino -Headers $cabeceras -Method Get -TimeoutSec 30
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Proyecto activo: HTTP $($respuesta.StatusCode) en $($url)"
    exit 0
}
catch {
    $codigo = $null
    try { $codigo = $_.Exception.Response.StatusCode.value__ } catch { }
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Fallo la peticion GET (codigo $codigo): $($_.Exception.Message)"
    exit 1
}
