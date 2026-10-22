<#
.SYNOPSIS
  Comprueba que los datos de la app Mano Ya estan llegando a Supabase.

.DESCRIPTION
  Consulta por REST (PostgREST) las tablas principales del proyecto usando la
  clave publica de Supabase y muestra:
    - el numero de filas de cada tabla,
    - las ultimas filas de cada tabla,
    - el detalle de los ultimos perfiles y de los ultimos trabajos.

  El script NO necesita la service role key: la clave publica (sb_publishable_)
  respeta las politicas RLS, por eso algunas tablas privadas (jobs, job_events,
  reports) pueden devolver 0 filas si no hay sesion iniciada.

  Si una columna no existe en el proyecto (por ejemplo, porque la migracion
  todavia no se aplico), el script reintenta con `select=*` y avisa de la
  diferencia para que puedas ver las columnas reales.

.PARAMETER SupabaseUrl
  URL del proyecto de Supabase. Por defecto se lee de SUPABASE_URL en el
  archivo .env de la raiz del proyecto.

.PARAMETER SupabaseKey
  Clave publica (sb_publishable_ o anon). Por defecto se lee de
  SUPABASE_ANON_KEY en el archivo .env de la raiz del proyecto.

.PARAMETER Limite
  Cuantas filas se muestran por tabla (por defecto 5).

.PARAMETER EnvFile
  Ruta alterna al archivo .env.

.EXAMPLE
  .\n8n\verify-data.ps1

.EXAMPLE
  .\n8n\verify-data.ps1 -SupabaseUrl "https://xxxx.supabase.co" -SupabaseKey "sb_publishable_..."

.NOTES
  Codigo de salida:
    0 = hay al menos un perfil (la app esta registrando usuarios)
    1 = no hay ningun perfil (la app no esta llegando a Supabase)
    2 = error de configuracion (faltan la URL o la clave)
#>
[CmdletBinding()]
param(
  [string]$SupabaseUrl,
  [string]$SupabaseKey,
  [int]$Limite = 5,
  [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

# La salida se escribe en UTF-8 para que los acentos se vean bien en la
# consola de Windows (cp850 / cp437) y en las terminales modernas.
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
  Write-Host 'Aviso: no se pudo cambiar la codificacion de la consola.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 0. Configuracion: .env por defecto y validaciones
# ---------------------------------------------------------------------
# PowerShell 5.1 negocia por defecto TLS 1.0 y Supabase solo admite TLS 1.2+.
try {
  [Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
  Write-Host 'Aviso: no se pudo forzar TLS 1.2 en este equipo.' -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
  $EnvFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
}

function Read-DotEnvValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
    $separator = $trimmed.IndexOf('=')
    if ($separator -lt 1) { continue }
    $key = $trimmed.Substring(0, $separator).Trim()
    if ($key -ne $Name) { continue }
    return $trimmed.Substring($separator + 1).Trim().Trim('"').Trim("'")
  }

  return $null
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  $SupabaseUrl = Read-DotEnvValue -Path $EnvFile -Name 'SUPABASE_URL'
}
if ([string]::IsNullOrWhiteSpace($SupabaseKey)) {
  $SupabaseKey = Read-DotEnvValue -Path $EnvFile -Name 'SUPABASE_ANON_KEY'
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  Write-Host 'ERROR: no se encontro SUPABASE_URL.' -ForegroundColor Red
  Write-Host "       Revisa el archivo '$EnvFile' o usa -SupabaseUrl." -ForegroundColor Yellow
  exit 2
}
if ([string]::IsNullOrWhiteSpace($SupabaseKey)) {
  Write-Host 'ERROR: no se encontro SUPABASE_ANON_KEY.' -ForegroundColor Red
  Write-Host "       Revisa el archivo '$EnvFile' o usa -SupabaseKey." -ForegroundColor Yellow
  exit 2
}

$SupabaseUrl = $SupabaseUrl.TrimEnd('/')
$requestBase = @{
  'apikey'        = $SupabaseKey
  'Authorization' = "Bearer $SupabaseKey"
}

Write-Host ''
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host ' Mano Ya · Verificacion de datos en Supabase' -ForegroundColor Cyan
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host " URL      : $SupabaseUrl"
Write-Host " Archivo  : $EnvFile"
Write-Host " Clave    : $($SupabaseKey.Substring(0, [Math]::Min(14, $SupabaseKey.Length)))... (publica)"
Write-Host ''

# ---------------------------------------------------------------------
# 1. Consulta REST con conteo exacto y manejo de errores
# ---------------------------------------------------------------------
function Invoke-SupabaseQuery {
  param(
    [Parameter(Mandatory = $true)][string]$Tabla,
    [Parameter(Mandatory = $true)][string]$Select,
    [string]$Order = 'created_at',
    [int]$Limit = 5,
    [switch]$SelectCompleto
  )

  $columnas = if ($SelectCompleto) { '*' } else { $Select }
  $query = "select=$([uri]::EscapeDataString($columnas))"
  if (-not [string]::IsNullOrWhiteSpace($Order) -and -not $SelectCompleto) {
    $query += "&order=$([uri]::EscapeDataString("$Order.desc"))"
  }
  $query += "&limit=$Limit"

  $uri = "$SupabaseUrl/rest/v1/$Tabla`?$query"
  $headers = $requestBase.Clone()
  $headers['Prefer'] = 'count=exact'

  $status = 0
  $cuerpo = ''

  try {
    $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 30
    $filas = @()
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
      $parsed = ConvertFrom-Json $response.Content
      foreach ($item in $parsed) { $filas += $item }
    }

    $total = $filas.Count
    $rango = ''
    if ($response.Headers -and $response.Headers.ContainsKey('Content-Range')) {
      $rango = [string]$response.Headers['Content-Range']
    }
    if ($rango -match '/(\d+)$') {
      $total = [int]$Matches[1]
    }

    return [pscustomobject]@{
      Tabla       = $Tabla
      Total       = $total
      Filas       = $filas
      Error       = ''
      Codigo      = [int]$response.StatusCode
      Uri         = $uri
      Select      = $columnas
      Columnas    = @($filas | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique)
      Advertencia = ''
    }
  } catch {
    if ($_.Exception.Response) {
      try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
      try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
          $reader = New-Object System.IO.StreamReader($stream)
          $cuerpo = $reader.ReadToEnd()
        }
      } catch { $cuerpo = '' }
    }
    if ([string]::IsNullOrWhiteSpace($cuerpo) -and $_.ErrorDetails) {
      $cuerpo = [string]$_.ErrorDetails.Message
    }
  }

  # Si el fallo es por una columna inexistente, se reintenta con select=*.
  if ($status -eq 400 -and $cuerpo -match 'does not exist' -and -not $SelectCompleto) {
    $fallback = Invoke-SupabaseQuery -Tabla $Tabla -Select $Select -Order $Order -Limit $Limit -SelectCompleto
    if (-not $fallback.Error) {
      $faltante = ($cuerpo | ConvertFrom-Json -ErrorAction SilentlyContinue).message
      $fallback.Advertencia = "La columna pedida no existe en el proyecto ($faltante). Se muestran todas las columnas disponibles."
      return $fallback
    }
    return $fallback
  }

  $mensaje = switch ($status) {
    400 { "La consulta no es valida para esta tabla: $cuerpo" }
    401 { 'La clave es invalida, fue revocada o el proyecto esta pausado. Revisa SUPABASE_ANON_KEY en el .env y el estado del proyecto en el panel de Supabase.' }
    403 { 'Permiso denegado. La clave publica no tiene permiso sobre esta tabla: revisa las politicas RLS de la migracion 20240101000000_init_schema.sql.' }
    404 { "La tabla '$Tabla' no existe en el proyecto. Aplica las migraciones de supabase/migrations/ (supabase db push) o el SQL Editor de Supabase." }
    0 { "No hay conexion con Supabase: $($_.Exception.Message)" }
    default { "La API de Supabase respondio con codigo $status. Detalle: $cuerpo" }
  }

  return [pscustomobject]@{
    Tabla       = $Tabla
    Total       = -1
    Filas       = @()
    Error       = $mensaje
    Codigo      = $status
    Uri         = $uri
    Select      = $columnas
    Columnas    = @()
    Advertencia = ''
  }
}

function Show-Rows {
  param(
    [object[]]$Filas,
    [string[]]$Columnas
  )

  if (-not $Filas -or $Filas.Count -eq 0) {
    Write-Host '   (sin filas)' -ForegroundColor DarkGray
    return
  }

  $proyectadas = foreach ($fila in $Filas) {
    $objeto = [ordered]@{}
    foreach ($columna in $Columnas) {
      $valor = $fila.$columna
      if ($null -eq $valor) {
        $valor = ''
      } elseif ($valor -is [datetime]) {
        $valor = $valor.ToString('yyyy-MM-dd HH:mm:ss')
      } elseif ($valor -isnot [string]) {
        $valor = [string]$valor
      }
      if ($valor.Length -gt 46) {
        $valor = $valor.Substring(0, 43) + '...'
      }
      $objeto[$columna] = $valor
    }
    [pscustomobject]$objeto
  }

  $proyectadas | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
}

function Get-Field {
  param([object]$Fila, [string[]]$Nombres)

  foreach ($nombre in $Nombres) {
    $valor = $Fila.$nombre
    if ($null -ne $valor -and [string]$valor -ne '') {
      return [string]$valor
    }
  }
  return ''
}

# ---------------------------------------------------------------------
# 2. Recorrido de las tablas principales
# ---------------------------------------------------------------------
$tablas = @(
  @{ Nombre = 'profiles';   Columnas = @('id', 'full_name', 'role', 'city', 'created_at') }
  @{ Nombre = 'workers';    Columnas = @('id', 'name', 'category', 'city', 'rating', 'created_at') }
  @{ Nombre = 'jobs';       Columnas = @('id', 'title', 'status', 'client_name', 'worker_name', 'created_at') }
  @{ Nombre = 'job_events'; Columnas = @('id', 'job_id', 'status', 'note', 'created_at') }
  @{ Nombre = 'reports';    Columnas = @('id', 'category', 'reason', 'status', 'notified_at', 'created_at') }
  @{ Nombre = 'reviews';    Columnas = @('id', 'job_id', 'rating', 'comment', 'created_at') }
)

$resultados = @{}

Write-Host '--- Resumen de filas por tabla ---' -ForegroundColor Cyan
Write-Host ''

foreach ($tabla in $tablas) {
  $nombre = $tabla.Nombre
  $select = ($tabla.Columnas -join ',')
  $resultado = Invoke-SupabaseQuery -Tabla $nombre -Select $select -Order 'created_at' -Limit $Limite
  $resultados[$nombre] = $resultado

  if ($resultado.Error) {
    Write-Host ("{0,-12} ERROR {1}" -f $nombre, $resultado.Error) -ForegroundColor Red
    continue
  }

  $color = 'Green'
  if ($resultado.Total -eq 0) { $color = 'Yellow' }
  Write-Host ("{0,-12} {1,6} filas" -f $nombre, $resultado.Total) -ForegroundColor $color

  $columnas = $tabla.Columnas
  if ($resultado.Advertencia) {
    Write-Host ("   aviso: {0}" -f $resultado.Advertencia) -ForegroundColor DarkYellow
    $columnas = @($resultado.Columnas | Select-Object -First 8)
  }

  Write-Host ("   ultimas filas: {0}" -f $resultado.Uri) -ForegroundColor DarkGray
  Show-Rows -Filas $resultado.Filas -Columnas $columnas
  Write-Host ''
}

# ---------------------------------------------------------------------
# 3. Detalle de los ultimos perfiles
# ---------------------------------------------------------------------
Write-Host '--- Detalle de los ultimos perfiles ---' -ForegroundColor Cyan
Write-Host ''

$perfiles = $resultados['profiles']
if ($perfiles.Error) {
  Write-Host "   ERROR: $($perfiles.Error)" -ForegroundColor Red
} elseif ($perfiles.Filas.Count -eq 0) {
  Write-Host '   No hay perfiles todavia. Registra un usuario en la app y vuelve a ejecutar el script.' -ForegroundColor Yellow
} else {
  foreach ($perfil in $perfiles.Filas) {
    $nombre = Get-Field -Fila $perfil -Nombres @('full_name', 'display_name', 'name')
    $rol = Get-Field -Fila $perfil -Nombres @('role')
    $ciudad = Get-Field -Fila $perfil -Nombres @('city', 'zone_id')
    Write-Host ("   id          : {0}" -f $perfil.id) -ForegroundColor DarkGray
    Write-Host ("   nombre      : {0}" -f $nombre)
    Write-Host ("   rol         : {0}" -f $(if ($rol) { $rol } else { 'sin dato en esta version del esquema' }))
    Write-Host ("   ciudad      : {0}" -f $(if ($ciudad) { $ciudad } else { 'sin dato en esta version del esquema' }))
    Write-Host ("   creado      : {0}" -f $perfil.created_at)
    Write-Host ''
  }
}

# ---------------------------------------------------------------------
# 4. Detalle de los ultimos trabajos
# ---------------------------------------------------------------------
Write-Host '--- Detalle de los ultimos trabajos ---' -ForegroundColor Cyan
Write-Host ''

$trabajos = $resultados['jobs']
if ($trabajos.Error) {
  Write-Host "   ERROR: $($trabajos.Error)" -ForegroundColor Red
} elseif ($trabajos.Filas.Count -eq 0) {
  Write-Host '   No hay trabajos visibles con la clave publica.' -ForegroundColor Yellow
  Write-Host '   La tabla jobs solo deja leer filas donde participa el usuario (politica RLS "jobs_participants").' -ForegroundColor DarkYellow
  Write-Host '   Para verlos todos necesitas la service role key o consultar desde el panel de Supabase.' -ForegroundColor DarkYellow
} else {
  foreach ($trabajo in $trabajos.Filas) {
    Write-Host ("   titulo      : {0}" -f (Get-Field -Fila $trabajo -Nombres @('title')))
    Write-Host ("   estado      : {0}" -f (Get-Field -Fila $trabajo -Nombres @('status')))
    Write-Host ("   cliente     : {0}" -f (Get-Field -Fila $trabajo -Nombres @('client_name')))
    Write-Host ("   trabajador  : {0}" -f (Get-Field -Fila $trabajo -Nombres @('worker_name')))
    Write-Host ("   creado      : {0}" -f $trabajo.created_at)
    Write-Host ''
  }
}

# ---------------------------------------------------------------------
# 5. Notas de la base de datos
# ---------------------------------------------------------------------
Write-Host '--- Notas importantes sobre RLS y tablas ---' -ForegroundColor Cyan
Write-Host ''
Write-Host ' * La clave publica respeta las politicas RLS: profiles, workers, categories y reviews se leen sin sesion;' -ForegroundColor DarkGray
Write-Host '   jobs, job_events, charges, installments y reports solo muestran las filas del usuario conectado.' -ForegroundColor DarkGray
Write-Host ' * La tabla favorites NO tiene columna id: su clave primaria es (client_id, worker_id).' -ForegroundColor DarkGray
Write-Host '   Para consultarla usa  select=client_id,worker_id  y filtra por client_id=eq.<uuid>.' -ForegroundColor DarkGray
Write-Host ' * Si una tabla devuelve 404, la migracion correspondiente todavia no se aplico en el proyecto.' -ForegroundColor DarkGray
Write-Host ' * Si devuelve 401, la clave publica no es la del proyecto o el proyecto esta pausado por inactividad.' -ForegroundColor DarkGray
Write-Host ' * Si el aviso menciona una columna inexistente, el esquema del proyecto difiere de supabase/migrations/.' -ForegroundColor DarkGray
Write-Host ''

# ---------------------------------------------------------------------
# 6. Codigo de salida
# ---------------------------------------------------------------------
$totalPerfiles = 0
if (-not $resultados['profiles'].Error) {
  $totalPerfiles = $resultados['profiles'].Total
}

if ($totalPerfiles -gt 0) {
  Write-Host ("RESULTADO: {0} perfil(es) encontrados. La app si esta escribiendo en Supabase." -f $totalPerfiles) -ForegroundColor Green
  exit 0
}

Write-Host 'RESULTADO: no hay ningun perfil en la base de datos. Revisa que la app se este ejecutando con las variables de .env.' -ForegroundColor Yellow
exit 1
