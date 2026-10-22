param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('run', 'build')]
  [string]$Command,

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
if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    [string]::IsNullOrWhiteSpace($supabaseKey)) {
  throw 'SUPABASE_URL y SUPABASE_ANON_KEY deben estar configurados en .env.'
}
if ($supabaseKey -match 'your_key_here|TU_ANON_KEY|TU_CLAVE') {
  throw 'Reemplaza el valor de ejemplo de .env por la clave pública real del proyecto Supabase.'
}
if ($supabaseKey.StartsWith('sb_secret_') -or $supabaseKey -match 'service_role') {
  throw 'No uses sb_secret ni service_role en una aplicación Flutter. Usa la clave pública publishable/anon.'
}
if (-not $supabaseKey.StartsWith('sb_publishable_') -and
    -not $supabaseKey.StartsWith('eyJ')) {
  throw 'SUPABASE_ANON_KEY debe ser una clave pública sb_publishable_ o anon.'
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

& flutter $Command @FlutterArgs @defines
exit $LASTEXITCODE
