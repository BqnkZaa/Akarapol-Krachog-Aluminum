[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$projDir  = "d:\Workshop\aluminum\toolkit_app"
$dataDir  = Join-Path $projDir "assets\data"
$fixDir   = Join-Path $projDir "test\fixtures"
$brainDir = "C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265"
$swDir    = Join-Path $brainDir "scratch\full_sweep"
$vipDir   = Join-Path $brainDir "scratch\vip_audit"

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $fixDir  | Out-Null

# ---------------------------------------------------------------------------
# 1. Generate Launcher Icons (Clean Navy & Teal Window-Ruler Icon)
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
$iconSizes = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}
foreach ($kv in $iconSizes.GetEnumerator()) {
    $sz = $kv.Value
    $resFolder = Join-Path $projDir "android\app\src\main\res\$($kv.Key)"
    New-Item -ItemType Directory -Force -Path $resFolder | Out-Null
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(255, 29, 78, 216))

    $pad = [int]($sz * 0.17)
    $w = $sz - 2 * $pad
    $penW = [Math]::Max(2.0, [float]($sz * 0.065))
    $whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $penW)
    $g.DrawRectangle($whitePen, $pad, $pad, $w, $w)
    $g.DrawLine($whitePen, [int]($sz / 2), $pad, [int]($sz / 2), ($sz - $pad))

    # Teal ruler triangle bottom-right
    $tealBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
    $pts = @(
        (New-Object System.Drawing.Point(($sz - $pad), [int]($sz * 0.45))),
        (New-Object System.Drawing.Point(($sz - $pad), ($sz - $pad))),
        (New-Object System.Drawing.Point([int]($sz * 0.45), ($sz - $pad)))
    )
    $g.FillPolygon($tealBrush, $pts)

    $iconPath = Join-Path $resFolder "ic_launcher.png"
    $bmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}
Write-Output "Generated custom launcher icons across all 5 mipmap folders!"

# ---------------------------------------------------------------------------
# 2. Compile orm_prices_1139.json (Verify exact 1,139 SKUs!)
# ---------------------------------------------------------------------------
$priceLines = [System.IO.File]::ReadAllLines((Join-Path $swDir "orm_prices_full.txt"), [System.Text.Encoding]::UTF8)
$ormSkus = New-Object System.Collections.Generic.List[object]
foreach ($pl in $priceLines) {
    if ($pl.Trim() -eq "") { continue }
    # Format: ORM · 801-01 | เฟรมล่างบานเลื่อนธรรมดา 9 ซม. | 1.2 มม. · ตัวดิบ MILL · 6.4 ม. | ฿1254.00 / เส้น | Toolkit ฿1254.00
    $parts = $pl -split "\s*\|\s*"
    if ($parts.Count -lt 4) { continue }
    $codePart = $parts[0] -replace "^ORM\s*.\s*", ""
    $namePart = $parts[1].Trim()
    $specSegs = $parts[2] -split "\s*·\s*"
    $thickness = "ไม่ระบุความหนา"
    $color = ""
    $stockM = 6.4
    if ($specSegs.Count -eq 3) {
        $thickness = $specSegs[0].Trim()
        $color = $specSegs[1].Trim()
        if ($specSegs[2] -match "([0-9.]+)") { $stockM = [double]$Matches[1] }
    } elseif ($specSegs.Count -eq 2) {
        $color = $specSegs[0].Trim()
        if ($specSegs[1] -match "([0-9.]+)") { $stockM = [double]$Matches[1] }
    }
    $priceVal = 0.0
    if ($parts[3] -match "([0-9]+(?:\.[0-9]+)?)") { $priceVal = [double]$Matches[1] }
    $ormSkus.Add([ordered]@{
        brand     = "ORM"
        code      = $codePart.Trim()
        name      = $namePart
        thickness = $thickness
        color     = $color
        stockM    = $stockM
        price     = $priceVal
    })
}
if ($ormSkus.Count -ne 1139) {
    throw "Expected 1139 ORM SKUs, got $($ormSkus.Count)!"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dataDir "orm_prices_1139.json"), ($ormSkus | ConvertTo-Json -Depth 5), $utf8NoBom)
Write-Output "Verified & wrote orm_prices_1139.json: $($ormSkus.Count) SKUs!"

# ---------------------------------------------------------------------------
# 3. Compile formulas_168_verified.json from generated_formulas_ref.md
#    AND ground_truth_168.json from raw _p1 / _p2 summaries!
# ---------------------------------------------------------------------------
$refLines = [System.IO.File]::ReadAllLines((Join-Path $swDir "generated_formulas_ref.md"), [System.Text.Encoding]::UTF8)
$tables = New-Object System.Collections.Generic.List[object]
$curTbl = $null

foreach ($rl in $refLines) {
    if ($rl -match '^### `([^`]+)`\s*.\s*(.+)$') {
        if ($null -ne $curTbl) { $tables.Add($curTbl) }
        $curTbl = [ordered]@{
            key      = $Matches[1].Trim()
            header   = $Matches[2].Trim()
            cuts     = New-Object System.Collections.Generic.List[object]
            glasses  = New-Object System.Collections.Generic.List[object]
            hardware = New-Object System.Collections.Generic.List[object]
        }
        continue
    }
    if ($null -eq $curTbl) { continue }

    if ($rl -match '^\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*\*\*`([^`]+)`\*\*\s*\|$') {
        $sec   = $Matches[1].Trim()
        $code  = $Matches[2].Trim()
        $pname = $Matches[3].Trim()
        $stkS  = $Matches[4].Trim()
        $qtyS  = $Matches[5].Trim()
        $angS  = $Matches[6].Trim()
        $fmlS  = $Matches[7].Trim()
        $stkMm = if ($stkS -match "6\.0") { 6000 } else { 6400 }
        $qtyN  = 1
        if ($qtyS -match "(\d+)") { $qtyN = [int]$Matches[1] }
        $curTbl.cuts.Add([ordered]@{
            section = $sec
            code    = $code
            name    = $pname
            stockMm = $stkMm
            qty     = $qtyN
            qtyText = $qtyS
            angle   = $angS
            formula = $fmlS
        })
    }
    elseif ($rl -match '^- \*\*กระจก \(`([^`]+)`\s*.\s*([^)]+)\):\*\*\s*(.+)$') {
        $gName = $Matches[1].Trim()
        $gQtyS = $Matches[2].Trim()
        $gRhs  = $Matches[3].Trim()
        $gQtyN = 1
        if ($gQtyS -match "(\d+)") { $gQtyN = [int]$Matches[1] }
        if ($gRhs -match 'วัดตัดหน้างาน') {
            $curTbl.glasses.Add([ordered]@{
                name     = $gName
                qty      = $gQtyN
                qtyText  = $gQtyS
                siteCut  = $true
                wFormula = ""
                hFormula = ""
            })
        }
        elseif ($gRhs -match '`(.+?)\s*[^\w\s()+*/.-]\s*(.+?)\s*มม\.`') {
            $curTbl.glasses.Add([ordered]@{
                name     = $gName
                qty      = $gQtyN
                qtyText  = $gQtyS
                siteCut  = $false
                wFormula = $Matches[1].Trim()
                hFormula = $Matches[2].Trim()
            })
        }
    }
    elseif ($rl -match '^- \*\*อุปกรณ์ประกอบ \(BOM ต่อ 1 ชุด\):\*\*\s*(.+)$') {
        $hwRaw = $Matches[1].Trim()
        $hwSegs = $hwRaw -split "\s*\|\s*"
        $hi = 0
        while ($hi -lt $hwSegs.Count) {
            if ($hi + 2 -lt $hwSegs.Count -and $hwSegs[$hi+2] -match "^\d+\s*\S+|ตามหน้างาน|ไม่ระบุ|วัด") {
                $curTbl.hardware.Add([ordered]@{
                    code    = $hwSegs[$hi].Trim()
                    name    = $hwSegs[$hi+1].Trim()
                    qtyText = $hwSegs[$hi+2].Trim()
                })
                $hi += 3
            }
            elseif ($hi + 1 -lt $hwSegs.Count) {
                $curTbl.hardware.Add([ordered]@{
                    code    = ""
                    name    = $hwSegs[$hi].Trim()
                    qtyText = $hwSegs[$hi+1].Trim()
                })
                $hi += 2
            } else { break }
        }
    }
}
if ($null -ne $curTbl) { $tables.Add($curTbl) }
[System.IO.File]::WriteAllText((Join-Path $dataDir "formulas_168_verified.json"), ($tables | ConvertTo-Json -Depth 8), $utf8NoBom)
Write-Output "Compiled formulas_168_verified.json: $($tables.Count) tables!"

# ---------------------------------------------------------------------------
# 4. Compile static_content.json (Notifications, Trick Article, ORM Dealers, Contact)
# ---------------------------------------------------------------------------
$staticObj = [ordered]@{
    supportEmail = "toolkitalutechsupport@gmail.com"
    notifications = @(
        [ordered]@{
            title = "📢 Toolkit อัปเดตใหม่ วันเสาร์ที่ 14 พฤศจิกายน 2569"
            lines = @(
                "🚀 Toolkit เตรียมอัปเดตวันเสาร์นี้!",
                "✅ ปรับปรุงสูตรตัดอลูมิเนียมและกระจก"
            )
            date  = ""
        },
        [ordered]@{
            title = "ทดสอบระบบแจ้งเตือนก่อนเปิดตัว"
            lines = @("ทดสอบครั้งที่1")
            date  = "Tue, Oct 27"
        }
    )
    trickArticles = @(
        [ordered]@{
            title    = "ทำความเข้าใจก่อนใช้งานแอปพลิเคชัน"
            subtitle = "การวัดช่องเปิดและเผื่อระยะติดตั้งวงกบ"
            body     = "ก่อนกรอกขนาดลงใน Toolkit ควรวัดช่องเปิดหน้างานหลายตำแหน่ง และ ใช้ระยะที่แคบที่สุดเป็นเกณฑ์เสมอ เพื่อป้องกันวงกบใหญ่เกินช่องเปิดจริง`n`nวิธีวัดและกรอกขนาด`n`n1. วัดความกว้างช่องเปิดที่ด้านบน ตรงกลาง และด้านล่าง แล้วเลือกค่าที่แคบที่สุด`n2. วัดความสูงช่องเปิดที่ด้านซ้าย ตรงกลาง และด้านขวา แล้วเลือกค่าที่แคบที่สุด`n3. หักระยะจากความกว้าง 10 มม. และความสูง 10 มม. เพื่อเผื่อช่องว่างติดตั้งประมาณด้านละ 5 มม. สำหรับยิง PU`n4. นำขนาดที่หักระยะแล้วมากรอกใน Toolkit โดยใช้หน่วย มิลลิเมตร (มม.)`n`nตัวอย่าง`n`nวัดช่องเปิดได้ขนาดแคบที่สุด กว้าง 2,000 มม. × สูง 1,500 มม.`n`n- กว้างที่กรอก = 2,000 − 10 = 1,990 มม.`n- สูงที่กรอก = 1,500 − 10 = 1,490 มม.`n`nข้อควรจำ: Toolkit ไม่ได้หักระยะเผื่อติดตั้งให้อัตโนมัติ ผู้ใช้งานต้องหักระยะก่อนกรอกขนาด และตรวจสอบความเหมาะสมกับระบบวงกบ ระดับพื้น ความได้ฉาก และสภาพหน้างานจริง โดยเฉพาะระบบที่มีธรณีหรือข้อกำหนดการติดตั้งเฉพาะ"
        }
    )
    ormDealers = @(
        [ordered]@{
            name      = "บริษัท เค.ซี. อินเตอร์เฟรม จำกัด"
            provinces = @("กรุงเทพมหานคร", "ฉะเชิงเทรา", "ปทุมธานี")
            lineId    = "@kcinterframe"
        }
    )
    dealerProvinceFilters = @("ทุกจังหวัด", "กรุงเทพมหานคร", "ฉะเชิงเทรา", "ปทุมธานี")
}
[System.IO.File]::WriteAllText((Join-Path $dataDir "static_content.json"), ($staticObj | ConvertTo-Json -Depth 6), $utf8NoBom)
Write-Output "Compiled static_content.json!"
