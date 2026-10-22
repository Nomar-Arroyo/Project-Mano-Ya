param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('run', 'build')]
  [string]$Command,

  # Permite arrancar la app en modo simulado (sin Supabase) para revisar la
  # interfaz: splash, catálogo, perfil y redirección a WhatsApp.
  [switch]$ModoDemo,

  # No corta aunque la clave publica siga siendo el valor de ejemplo.
  [switch]$PermitirClaveDeEjemplo,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$envFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
if (-not (Test-Path $envFile)) {
  throw "No se encontró $envFile. Cópialo desde .env.example y agrega las credenciales."
}

$values = @{}
foreach ($line in Get-Content $envFile) {
  $trimmedLine = $line.Trim()
  if ($trimmedLine.Length -eq 0 -or $trimmedLine.StartsWith('#')) {
    continue
  }

  $separator = $trimmedLine.IndexOf('=')
  if ($separator -lt 1) {
    throw "Línea inválida en .env: $trimmedLine"
  }

  $name = $trimmedLine.Substring(0, $separator).Trim()
  $value = $trimmedLine.Substring($separator + 1).Trim()
  $values[$name] = $value.Trim('"').Trim("'")
}

$supabaseUrl = $values['SUPABASE_URL']
$supabaseKey = $values['SUPABASE_ANON_KEY']

if ($ModoDemo) {
  # Sin credenciales la app arranca en modo simulado: sirve para revisar la
  # interfaz sin depender de la red.
  $supabaseUrl = ''
  $supabaseKey = ''
  Write-Host 'Modo demo: la app arranca sin conexion a Supabase.' -ForegroundColor Yellow
}
else {
  if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
      [string]::IsNullOrWhiteSpace($supabaseKey)) {
    throw 'SUPABASE_URL y SUPABASE_ANON_KEY deben estar configurados en .env.'
  }
  if ($supabaseKey -match 'your_key_here|TU_ANON_KEY|TU_CLAVE') {
    if (-not $PermitirClaveDeEjemplo) {
      throw 'Reemplaza el valor de ejemplo de .env por la clave publica real del proyecto Supabase. Usa -PermitirClaveDeEjemplo para arrancar de todos modos.'
    }
    Write-Host 'Atencion: se usa la clave de ejemplo, la conexion con Supabase fallara.' -ForegroundColor Yellow
  }
  if ($supabaseKey.StartsWith('sb_secret_') -or $supabaseKey -match 'service_role') {
    throw 'No uses sb_secret ni service_role en una aplicacion Flutter. Usa la clave publica publishable/anon.'
  }
  if (-not $supabaseKey.StartsWith('sb_publishable_') -and
      -not $supabaseKey.StartsWith('eyJ')) {
    throw 'SUPABASE_ANON_KEY debe ser una clave publica sb_publishable_ o anon.'
  }
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'No se encontró Flutter en PATH. Agrega flutter\bin a PATH y vuelve a intentarlo.'
}

# Las credenciales de Google son opcionales: sin ellas el acceso con Google
# queda en modo simulado, pero el resto de la app funciona igual.
$googleClientId = $values['GOOGLE_CLIENT_ID']
$googleServerClientId = $values['GOOGLE_SERVER_CLIENT_ID']

# Variables opcionales de la app. Si no vienen en el .env, la app usa sus
# valores por defecto (o funciona sin webhook de n8n).
$webAppUrl = $values['WEB_APP_URL']
$n8nWebhookUrl = $values['N8N_WEBHOOK_URL']
$supportEmail = $values['SUPPORT_EMAIL']
$n8nWebhookSecret = $values['N8N_WEBHOOK_SECRET']

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl"
  "--dart-define=SUPABASE_ANON_KEY=$supabaseKey"
)

if (-not [string]::IsNullOrWhiteSpace($googleClientId)) {
  $defines += "--dart-define=GOOGLE_CLIENT_ID=$googleClientId"
}
if (-not [string]::IsNullOrWhiteSpace($googleServerClientId)) {
  $defines += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$googleServerClientId"
}
if (-not [string]::IsNullOrWhiteSpace($webAppUrl)) {
  $defines += "--dart-define=WEB_APP_URL=$webAppUrl"
}
if (-not [string]::IsNullOrWhiteSpace($n8nWebhookUrl)) {
  $defines += "--dart-define=N8N_WEBHOOK_URL=$n8nWebhookUrl"
}
if (-not [string]::IsNullOrWhiteSpace($supportEmail)) {
  $defines += "--dart-define=SUPPORT_EMAIL=$supportEmail"
}
if (-not [string]::IsNullOrWhiteSpace($n8nWebhookSecret)) {
  # El secreto solo se inyecta en las versiones moviles. En la web el bundle
  # es publico y cualquiera podria leer el valor del JavaScript; ahi la app
  # se autentica con la sesion del usuario y la Edge Function valida la
  # peticion en el servidor.
  $esWeb = $false
  foreach ($arg in $FlutterArgs) {
    if ($arg -eq 'web' -or $arg -eq 'web-server' -or $arg -like 'web-*') {
      $esWeb = $true
    }
  }
  if ($esWeb) {
    Write-Host 'Version web: no se inyecta N8N_WEBHOOK_SECRET (el bundle es publico).' -ForegroundColor Yellow
  }
  else {
    $defines += "--dart-define=N8N_WEBHOOK_SECRET=$n8nWebhookSecret"
  }
}

& flutter $Command @FlutterArgs @defines
exit $LASTEXITCODE
