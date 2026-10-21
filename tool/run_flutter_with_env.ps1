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

& flutter $Command @FlutterArgs `
  "--dart-define=SUPABASE_URL=$supabaseUrl" `
  "--dart-define=SUPABASE_ANON_KEY=$supabaseKey"
exit $LASTEXITCODE
