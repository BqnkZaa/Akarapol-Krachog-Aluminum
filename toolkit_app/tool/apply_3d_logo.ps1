$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\architectural_aluminum_glass_app_icon_1794853748518.jpg"
$projDir = "d:\Workshop\aluminum\toolkit_app"
$webPub  = "d:\Workshop\aluminum\public\downloads"

$srcImg = [System.Drawing.Image]::FromFile($srcPath)
# Slight 8% inset crop so the 3D aluminum-glass emblem has strong presence on mobile home screens
$inset = [int]($srcImg.Width * 0.08)
$cropW = $srcImg.Width - (2 * $inset)
$cropRect = New-Object System.Drawing.Rectangle($inset, $inset, $cropW, $cropW)

function Save-ResizedPng([string]$OutPath, [int]$Size) {
    $dir = Split-Path -Parent $OutPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
    $g.DrawImage($srcImg, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

$mipmaps = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($kv in $mipmaps.GetEnumerator()) {
    $out = Join-Path $projDir "android\app\src\main\res\$($kv.Key)\ic_launcher.png"
    Save-ResizedPng -OutPath $out -Size $kv.Value
}

Save-ResizedPng -OutPath (Join-Path $projDir "assets\images\app_logo_3d.png") -Size 512
Save-ResizedPng -OutPath (Join-Path $webPub "app-logo-3d.png") -Size 512

$srcImg.Dispose()
Write-Output "Generated high-DPI 3D launcher icons and web 3D logo successfully!"
