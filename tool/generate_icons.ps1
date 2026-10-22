param(
  [string]$ProjectRoot = "C:\Projects\ManoYa\src"
)

Add-Type -AssemblyName System.Drawing

$iconsDir = Join-Path $ProjectRoot "assets\icons"
$webDir = Join-Path $ProjectRoot "web"
$webIconsDir = Join-Path $webDir "icons"
$androidRes = Join-Path $ProjectRoot "android\app\src\main\res"

function Get-ContentBounds {
  param([System.Drawing.Bitmap]$Bitmap)
  $minX = $Bitmap.Width; $minY = $Bitmap.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $Bitmap.Height; $y += 1) {
    for ($x = 0; $x -lt $Bitmap.Width; $x += 1) {
      $c = $Bitmap.GetPixel($x, $y)
      $visible = ($c.A -gt 24) -and -not ($c.R -gt 242 -and $c.G -gt 242 -and $c.B -gt 242)
      if ($visible) {
        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt 0) { return $null }
  return [System.Drawing.Rectangle]::new($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

function ConvertTo-Argb {
  <#
    Convierte "#RRGGBB" o "#AARRGGBB" a un color .NET.
    El canal alfa se indica por separado para evitar confusiones de orden.
  #>
  param([string]$Hex, [int]$Alpha = 255)
  $clean = $Hex.TrimStart('#')
  if ($clean.Length -eq 6) {
    $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    return [System.Drawing.Color]::FromArgb($Alpha, $r, $g, $b)
  }
  $a = [Convert]::ToInt32($clean.Substring(0, 2), 16)
  $r = [Convert]::ToInt32($clean.Substring(2, 2), 16)
  $g = [Convert]::ToInt32($clean.Substring(4, 2), 16)
  $b = [Convert]::ToInt32($clean.Substring(6, 2), 16)
  return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function Save-Png {
  param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $Bitmap.Dispose()
}

function New-Canvas {
  param([int]$Size, [System.Drawing.Color]$Background)
  $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.Clear($Background)
  return @{ Bitmap = $bmp; Graphics = $g }
}

function Write-Logo {
  <#
    Recorta el logo al contenido visible y lo escala dentro de un lienzo
    cuadrado. $Fill es la proporcion del lienzo que ocupa el logo.
  #>
  param(
    [string]$Destination,
    [int]$Size,
    [double]$Fill = 0.86,
    [string]$Background = "#00FFFFFF",
    [string]$SourceLogo = "logotipo_oficial.png"
  )
  $srcPath = Join-Path $iconsDir $SourceLogo
  $src = New-Object System.Drawing.Bitmap($srcPath)
  $bounds = Get-ContentBounds -Bitmap $src
  if ($null -eq $bounds) { $src.Dispose(); throw "No se encontro contenido visible en $srcPath" }

  $crop = $src.Clone($bounds, $src.PixelFormat)
  $src.Dispose()

  $bg = ConvertTo-Argb -Hex $Background
  $canvas = New-Canvas -Size $Size -Background $bg
  $g = $canvas.Graphics
  $bmp = $canvas.Bitmap

  $target = [int]($Size * $Fill)
  $scale = [math]::Min($target / $crop.Width, $target / $crop.Height)
  $w = [int]($crop.Width * $scale)
  $h = [int]($crop.Height * $scale)
  $dx = [int](($Size - $w) / 2)
  $dy = [int](($Size - $h) / 2)

  $g.DrawImage($crop, (New-Object System.Drawing.Rectangle($dx, $dy, $w, $h)))
  $crop.Dispose()
  $g.Dispose()
  Save-Png -Bitmap $bmp -Path $Destination
  Write-Output ("  {0} <- {1} ({2}x{2})" -f (Split-Path -Leaf $Destination), $SourceLogo, $Size)
}

Write-Output "Generando iconos desde los logos oficiales..."

# Logo principal de la app (splash y pantallas de acceso): wordmark completo.
Write-Logo -Destination (Join-Path $iconsDir "app_logo.png") -Size 768 -Fill 0.94 -Background "#00FFFFFF" -SourceLogo "logotipo_oficial.png"

# Icono del lanzador: emblema cuadrado con fondo solido.
Write-Logo -Destination (Join-Path $iconsDir "app_icon.png") -Size 1024 -Fill 0.88 -Background "#FFFFFFFF" -SourceLogo "favicon_oficial.png"

# Capa frontal del icono adaptativo de Android: emblema dentro de la zona segura.
Write-Logo -Destination (Join-Path $iconsDir "app_icon_foreground.png") -Size 1024 -Fill 0.60 -Background "#00FFFFFF" -SourceLogo "favicon_oficial.png"

# Favicon: emblema completo y sin fondo.
Write-Logo -Destination (Join-Path $webDir "favicon.png") -Size 256 -Fill 0.96 -Background "#00FFFFFF" -SourceLogo "favicon_oficial.png"

# Iconos PWA: emblema sobre el fondo de la marca.
Write-Logo -Destination (Join-Path $webIconsDir "Icon-192.png") -Size 192 -Fill 0.84 -Background "#F8FAFC" -SourceLogo "favicon_oficial.png"
Write-Logo -Destination (Join-Path $webIconsDir "Icon-512.png") -Size 512 -Fill 0.84 -Background "#F8FAFC" -SourceLogo "favicon_oficial.png"

# Iconos enmascarables: emblema dentro de la zona segura (80% central).
Write-Logo -Destination (Join-Path $webIconsDir "Icon-maskable-192.png") -Size 192 -Fill 0.58 -Background "#F8FAFC" -SourceLogo "favicon_oficial.png"
Write-Logo -Destination (Join-Path $webIconsDir "Icon-maskable-512.png") -Size 512 -Fill 0.58 -Background "#F8FAFC" -SourceLogo "favicon_oficial.png"

Write-Output "Listo."
