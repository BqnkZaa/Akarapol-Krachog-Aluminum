$ErrorActionPreference = "Stop"

$env:JAVA_HOME    = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
$env:ANDROID_HOME = "C:\Users\ayumg\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_TOOL_OPTIONS = "-Duser.language=en -Duser.country=US"
$env:Path = "$($env:JAVA_HOME)\bin;C:\dev\flutter\bin;$($env:Path)"

Write-Output "=== 1. Generating 3D App Icons & Web Assets ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "d:\Workshop\aluminum\toolkit_app\tool\apply_3d_logo.ps1"

Write-Output "=== 2. Running flutter analyze & Building Release APK with 3D Logo ==="
Set-Location "d:\Workshop\aluminum\toolkit_app"
& C:\dev\flutter\bin\flutter.bat pub get
& C:\dev\flutter\bin\flutter.bat analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }

& C:\dev\flutter\bin\flutter.bat build apk --release --target-platform android-arm64,android-arm
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

Write-Output "=== 3. Updating public/downloads/akkaraphon-toolkit.apk & apk-meta.json ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "d:\Workshop\aluminum\toolkit_app\tool\publish_apk_to_web.ps1"

Write-Output "=== 4. Verifying Next.js 16 Landing Page Build ==="
Set-Location "d:\Workshop\aluminum"
& npm.cmd run build
if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }

Write-Output "=== 5. Pushing to GitHub & Updating Release v0.1.7 ==="
gh auth switch -u BqnkZaa
gh auth setup-git
git add package.json package-lock.json src/components/Sidebar.tsx src/app/download public/downloads toolkit_app
git commit -m "feat: redesign /download as formal corporate landing page and apply 3D architectural app logo"
git push origin master
if ($LASTEXITCODE -ne 0) { throw "git push failed" }

gh release upload v0.1.7 "d:\Workshop\aluminum\public\downloads\akkaraphon-toolkit.apk" --clobber
gh auth switch -u Jixgo-cloud

Write-Output "=== REBUILD & PRODUCTION DEPLOY COMPLETE ==="
