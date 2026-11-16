$ErrorActionPreference = "Stop"

$env:JAVA_HOME    = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
$env:ANDROID_HOME = "C:\Users\ayumg\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_TOOL_OPTIONS = "-Duser.language=en -Duser.country=US"
$env:Path = "$($env:JAVA_HOME)\bin;C:\dev\flutter\bin;$($env:Path)"

Set-Location "d:\Workshop\aluminum\toolkit_app\android"
& .\gradlew.bat --stop

Set-Location "d:\Workshop\aluminum\toolkit_app"
Write-Output "=== Building Release APK (with ISO Gregorian Locale for apkzlib) ==="
& C:\dev\flutter\bin\flutter.bat build apk --release
if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed with exit code $LASTEXITCODE" }

Write-Output "=== Publishing APK & Metadata to Next.js public/downloads ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "d:\Workshop\aluminum\toolkit_app\tool\publish_apk_to_web.ps1"
if ($LASTEXITCODE -ne 0) { throw "publish_apk_to_web.ps1 failed" }

Write-Output "=== Running Next.js 16 production build (npm run build) ==="
Set-Location "d:\Workshop\aluminum"
& npm.cmd run build
if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }

Write-Output "=== ALL BUILDS SUCCEEDED ==="
