$ErrorActionPreference = "Stop"

$apkSrc  = "d:\Workshop\aluminum\toolkit_app\build\app\outputs\flutter-apk\app-release.apk"
$destDir = "d:\Workshop\aluminum\public\downloads"
$apkDest = Join-Path $destDir "akkaraphon-toolkit.apk"
$metaOut = Join-Path $destDir "apk-meta.json"

if (-not (Test-Path $apkSrc)) {
    throw "APK not found at $apkSrc"
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item -Force -Path $apkSrc -Destination $apkDest

$fileInfo = Get-Item $apkDest
$hashInfo = Get-FileHash -Path $apkDest -Algorithm SHA256
$sizeMb   = [Math]::Round($fileInfo.Length / 1048576.0, 2).ToString("0.00")
$nowStr   = (Get-Date).ToString("dd/MM/yyyy HH:mm")

$meta = [ordered]@{
    appName   = "อัครพลกระจกอลูมิเนียม"
    packageId = "com.akkaraphon.toolkit"
    version   = "0.1.7 (VIP Offline)"
    fileName  = "akkaraphon-toolkit.apk"
    sizeBytes = $fileInfo.Length
    sizeMb    = $sizeMb
    sha256    = $hashInfo.Hash.ToLowerInvariant()
    updatedAt = $nowStr
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($metaOut, ($meta | ConvertTo-Json -Depth 4), $utf8NoBom)
Write-Output "Published APK ($sizeMb MB, SHA256=$($meta.sha256)) to $apkDest"
