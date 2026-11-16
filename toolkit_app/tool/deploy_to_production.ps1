$ErrorActionPreference = "Stop"

$env:JAVA_HOME    = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
$env:ANDROID_HOME = "C:\Users\ayumg\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_TOOL_OPTIONS = "-Duser.language=en -Duser.country=US"
$env:Path = "$($env:JAVA_HOME)\bin;C:\dev\flutter\bin;$($env:Path)"

Write-Output "=== 1. Building optimized Android ARM64 + ARMv7 Release APK ==="
Set-Location "d:\Workshop\aluminum\toolkit_app"
& C:\dev\flutter\bin\flutter.bat build apk --release --target-platform android-arm64,android-arm
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

Write-Output "=== 2. Updating public/downloads/akkaraphon-toolkit.apk & apk-meta.json ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "d:\Workshop\aluminum\toolkit_app\tool\publish_apk_to_web.ps1"
if ($LASTEXITCODE -ne 0) { throw "publish_apk_to_web.ps1 failed" }

Write-Output "=== 3. Staging, committing, and pushing to GitHub (triggers Vercel Production) ==="
Set-Location "d:\Workshop\aluminum"
git add next.config.ts src/components/Sidebar.tsx src/app/download src/app/api/download-apk public/downloads toolkit_app
git status --short
git commit -m "feat: add Akkaraphon Toolkit 1:1 VIP Offline Android APK and /download page"
git push origin master
if ($LASTEXITCODE -ne 0) { throw "git push failed" }

Write-Output "=== 4. Publishing GitHub Release v0.1.7 CDN mirror ==="
$apkFile = "d:\Workshop\aluminum\public\downloads\akkaraphon-toolkit.apk"
$relCheck = gh release view v0.1.7 2>$null
if ($LASTEXITCODE -eq 0) {
    gh release upload v0.1.7 $apkFile --clobber
} else {
    gh release create v0.1.7 $apkFile --title "อัครพลกระจกอลูมิเนียม v0.1.7 (VIP Offline APK)" --notes "ไฟล์ติดตั้งแอปพลิเคชัน อัครพลกระจกอลูมิเนียม (Android .apk v0.1.7 VIP Offline 100%)"
}

Write-Output "=== PUSH & GITHUB RELEASE COMPLETE ==="
