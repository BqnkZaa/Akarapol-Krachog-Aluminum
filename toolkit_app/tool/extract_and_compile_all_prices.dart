// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Builds `assets/data/catalog_prices_seed.json` combining:
/// 1. Exact ORM 1,139 verified SKUs (`assets/data/orm_prices_1139.json`) + 3 ORM descriptive aliases
/// 2. Exact ALUMET Hub official retail price sheets (Smart X 11/05/2569, ICONIQ Euro 11/05/2569,
///    Pro Smart 01/08/2567, Battens/Box 01/08/2567, Hardware 03/03/2568)
/// 3. Exact `aluprosmart.com` (`meterial.php`) extracted prices for Market (`g01`), Glass, and Hardware
/// 4. Reference benchmark prices (`isEstimated: true`) for brands/codes whose upstream catalog
///    stores `0.00` or `"รออัพเดท"` (`SCHIMMER`, `SMART_PLUS`, `FUJI`, `UAI`, `ALUFRAME`, and 5 Smart X 45° codes),
///    ensuring 100% of active patterns calculate out-of-the-box without locking dropdowns.
void main() {
  final ormRaw = File('assets/data/orm_prices_1139.json').readAsStringSync();
  final ormList = (jsonDecode(ormRaw) as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final profiles = <Map<String, dynamic>>[];
  final seenKeys = <String>{};

  void addSku({
    required String brand,
    required String code,
    required String name,
    required String thickness,
    required String color,
    double stockM = 6.4,
    required double price,
    bool isEstimated = false,
  }) {
    final key = '$brand|$code|$thickness|$color';
    if (seenKeys.contains(key)) return;
    seenKeys.add(key);
    profiles.add({
      'brand': brand,
      'code': code,
      'name': name,
      'thickness': thickness,
      'color': color,
      'stockM': stockM,
      'price': (price * 100).round() / 100.0,
      if (isEstimated) 'isEstimated': true,
    });
  }

  // ---------------------------------------------------------------------------
  // 1. Preserve all 1,139 verified ORM SKUs verbatim + 3 descriptive aliases
  // ---------------------------------------------------------------------------
  for (final item in ormList) {
    addSku(
      brand: item['brand'] as String? ?? 'ORM',
      code: item['code'] as String,
      name: item['name'] as String,
      thickness: item['thickness'] as String,
      color: item['color'] as String,
      stockM: (item['stockM'] as num).toDouble(),
      price: (item['price'] as num).toDouble(),
      isEstimated: false,
    );
  }

  // 812-10 in orm_prices_1139.json -> also map compound label used in ORM Euro casement
  for (final item in ormList.where((e) => e['code'] == '812-10')) {
    addSku(
      brand: 'ORM',
      code: 'คิ้วบานยูโร · เลือกตามชุด (812-10 / 812-11)',
      name: 'คิ้วกระจกบานยูโร (812-10 / 812-11)',
      thickness: item['thickness'] as String,
      color: item['color'] as String,
      stockM: (item['stockM'] as num).toDouble(),
      price: (item['price'] as num).toDouble(),
      isEstimated: false,
    );
  }

  // 805-04 (กรอบบานเฟี้ยม 90/101.6 in ORM catalog) -> map 'กรอบบานเฟี้ยมมาตรฐาน'
  final ormFoldSashRows = ormList.where((e) => e['code'] == '805-04').toList();
  if (ormFoldSashRows.isNotEmpty) {
    for (final item in ormFoldSashRows) {
      addSku(
        brand: 'ORM',
        code: 'กรอบบานเฟี้ยมมาตรฐาน',
        name: 'กรอบบานเฟี้ยมมาตรฐาน ORM Pano Suit',
        thickness: item['thickness'] as String,
        color: item['color'] as String,
        stockM: (item['stockM'] as num).toDouble(),
        price: (item['price'] as num).toDouble(),
        isEstimated: false,
      );
    }
  } else {
    for (final cEntry in _ormColorMultipliers.entries) {
      addSku(
        brand: 'ORM',
        code: 'กรอบบานเฟี้ยมมาตรฐาน',
        name: 'กรอบบานเฟี้ยมมาตรฐาน ORM Pano Suit',
        thickness: '1.8 มม.',
        color: cEntry.key,
        price: (2150.0 * cEntry.value).roundToDouble(),
        isEstimated: true,
      );
    }
  }

  // ORM 'เส้น C-กรุ๊ฟ' (Transmission rod)
  for (final cEntry in _ormColorMultipliers.entries) {
    addSku(
      brand: 'ORM',
      code: 'เส้น C-กรุ๊ฟ',
      name: 'เส้น C-กรุ๊ฟ ก้านส่งกำลังชุดล็อก',
      thickness: 'ไม่ระบุความหนา',
      color: cEntry.key,
      price: (240.0 * cEntry.value).roundToDouble(),
      isEstimated: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Official ALUMET Hub Retail Prices (Update 11/05/2569 + 01/08/2567)
  // ---------------------------------------------------------------------------
  void addAlumetOfficial({
    required String code,
    required String name,
    required String thickness,
    required double whiteBlack8911, // 8911 อบขาว & 8816 อบดำ
    required double greySahara8820, // 8820 เทาซาฮาร่า
    required double sandSahara8515, // 8515 ทรายซาฮาร่า
    required double wood15656, // 15656 ไม้สัก / 15659 วอลนัท
    double? mill,
    double? anodizeNa,
    bool isEstimated = false,
    bool woodEstimated = false,
  }) {
    final effMill = mill ?? (whiteBlack8911 * 0.68).roundToDouble();
    final effNa = anodizeNa ?? (whiteBlack8911 * 0.77).roundToDouble();

    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'ตัวดิบ MILL',
      price: effMill,
      isEstimated: isEstimated || mill == null,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'ชุบขาว',
      price: effNa,
      isEstimated: isEstimated || anodizeNa == null,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'อบขาว (8911)',
      price: whiteBlack8911,
      isEstimated: isEstimated,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'อบดำ (8816)',
      price: whiteBlack8911,
      isEstimated: isEstimated,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'เทาซาฮาร่า (8820)',
      price: greySahara8820,
      isEstimated: isEstimated,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'ทรายซาฮาร่า (8515)',
      price: sandSahara8515,
      isEstimated: isEstimated,
    );
    addSku(
      brand: 'ALUMET',
      code: code,
      name: name,
      thickness: thickness,
      color: 'ลายไม้ (15656 / 15659)',
      price: wood15656,
      isEstimated: isEstimated || woodEstimated,
    );
  }

  // --- ALUMET Smart X Sliding (ราคาปลีกสีสต็อก_สมาร์X110569 ล่าสุด หน้า 1-3) ---
  addAlumetOfficial(code: 'SS-X109', name: 'เฟรมล่างบานเลื่อน 3 ราง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 3010, greySahara8820: 3085, sandSahara8515: 3245, wood15656: 3995);
  addAlumetOfficial(code: 'SS-X110', name: 'เฟรมบนบานเลื่อน 3 ราง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2410, greySahara8820: 2470, sandSahara8515: 2600, wood15656: 3200, woodEstimated: true);
  addAlumetOfficial(code: 'SS-X111', name: 'เฟรมข้างกล่องเรียบ สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1645, greySahara8820: 1685, sandSahara8515: 1770, wood15656: 2215);
  addAlumetOfficial(code: 'SS-0121', name: 'เฟรมล่าง 3 ราง (ภายใน) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1530, greySahara8820: 1570, sandSahara8515: 1650, wood15656: 2060, mill: 1010, anodizeNa: 1140);
  addAlumetOfficial(code: 'SS-X101', name: 'เฟรมบนบานเลื่อน 3 ราง สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2615, greySahara8820: 2685, sandSahara8515: 2825, wood15656: 3445, mill: 1760, anodizeNa: 1980);
  addAlumetOfficial(code: 'SS-X102', name: 'เฟรมล่างบานเลื่อน 3 ราง สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 3435, greySahara8820: 3525, sandSahara8515: 3705, wood15656: 4520, mill: 2320, anodizeNa: 2620);
  addAlumetOfficial(code: 'SS-X103', name: 'เฟรมข้างกล่องเรียบ สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1835, greySahara8820: 1880, sandSahara8515: 1975, wood15656: 2445, mill: 1255, anodizeNa: 1405);
  addAlumetOfficial(code: 'SS-X104', name: 'ตบเฟรม 3 รางบานเลื่อน ต่อช่องแสง สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1950, greySahara8820: 2005, sandSahara8515: 2105, wood15656: 2565, mill: 1315, anodizeNa: 1475);
  addAlumetOfficial(code: 'SS-X105', name: 'ตบธรณีเสริมมุ้งชุดมาตรฐาน (ล่าง) สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 655, greySahara8820: 670, sandSahara8515: 705, wood15656: 895);
  addAlumetOfficial(code: 'SS-X106', name: 'ตบธรณีเสริมมุ้งชุดมาตรฐาน (บน) สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 755, greySahara8820: 775, sandSahara8515: 815, wood15656: 1035);
  addAlumetOfficial(code: 'SS-X108', name: 'ตบธรณี สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 665, greySahara8820: 680, sandSahara8515: 715, wood15656: 905);
  addAlumetOfficial(code: 'SS-X107', name: 'เสริมปีกเฟรมข้างกล่องเรียบ (มีบังใบ) สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 595, greySahara8820: 610, sandSahara8515: 640, wood15656: 895);
  addAlumetOfficial(code: 'SS-0120', name: 'เสริมปีกเฟรมข้างกล่องเรียบ สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 385, greySahara8820: 395, sandSahara8515: 415, wood15656: 540, mill: 240, anodizeNa: 265);
  // Also register compound choice code SS-X107 / SS-0120 directly at SS-X107 official price
  addAlumetOfficial(code: 'SS-X107 / SS-0120', name: 'เดือยเสากุญแจ (SS-X107 / SS-0120)', thickness: '1.0 มม.', whiteBlack8911: 595, greySahara8820: 610, sandSahara8515: 640, wood15656: 895);
  addAlumetOfficial(code: 'SS-0117', name: 'ฝาปิดเสริมเสากุญแจตัวผู้ สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 330, greySahara8820: 335, sandSahara8515: 355, wood15656: 435, mill: 205, anodizeNa: 230);
  addAlumetOfficial(code: 'SS-X113', name: 'รางแขวนยึดผนังด้านบน สมาร์ท เอ็กซ์', thickness: '2.5 มม.', whiteBlack8911: 2105, greySahara8820: 2160, sandSahara8515: 2270, wood15656: 2800);
  addAlumetOfficial(code: 'SS-X114', name: 'ฝาครอบปิดรางแขวน สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 615, greySahara8820: 630, sandSahara8515: 665, wood15656: 845);
  addAlumetOfficial(code: 'SS-X115', name: 'เสริมยึดล้อรางแขวน สมาร์ท เอ็กซ์', thickness: '2.0 มม.', whiteBlack8911: 810, greySahara8820: 835, sandSahara8515: 875, wood15656: 1100);
  addAlumetOfficial(code: 'SS-X116', name: 'รางแขวนยึดผนังด้านข้าง สมาร์ท เอ็กซ์', thickness: '2.5 มม.', whiteBlack8911: 2700, greySahara8820: 2770, sandSahara8515: 2915, wood15656: 3595);
  addAlumetOfficial(code: 'SS-0147', name: 'เสากุญแจซิงเกิลล็อก ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1315, greySahara8820: 1350, sandSahara8515: 1420, wood15656: 1750, mill: 865, anodizeNa: 980, woodEstimated: true);
  addAlumetOfficial(code: 'SS-0123', name: 'ตบเกี่ยวทางเดียว (เสาซิงเกิลล็อก) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 640, greySahara8820: 660, sandSahara8515: 690, wood15656: 880, mill: 400, anodizeNa: 450);
  addAlumetOfficial(code: 'SS-0114', name: 'ตบเกี่ยวสองทาง (เสาซิงเกิลล็อก) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 900, greySahara8820: 920, sandSahara8515: 965, wood15656: 1210, mill: 615, anodizeNa: 695);
  addAlumetOfficial(code: 'SS-0116', name: 'เสริมเสากุญแจตัวผู้ (เสาซิงเกิลล็อก) สมาร์ท เอ็กซ์', thickness: '1.3 มม.', whiteBlack8911: 500, greySahara8820: 510, sandSahara8515: 535, wood15656: 690, mill: 335, anodizeNa: 385);
  addAlumetOfficial(code: 'SS-0138', name: 'เสากุญแจมัลติพอยท์ ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1640, greySahara8820: 1680, sandSahara8515: 1765, wood15656: 2150, mill: 1090, anodizeNa: 1225);
  addAlumetOfficial(code: 'SS-0139', name: 'ตบเกี่ยวทางเดียว (เสามัลติพอยท์) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 645, greySahara8820: 660, sandSahara8515: 695, wood15656: 845, mill: 435, anodizeNa: 490);
  addAlumetOfficial(code: 'SS-0140', name: 'ตบเกี่ยวสองทาง (เสามัลติพอยท์) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1030, greySahara8820: 1055, sandSahara8515: 1110, wood15656: 1370, mill: 695, anodizeNa: 780);
  addAlumetOfficial(code: 'SS-0141', name: 'เสริมเสากุญแจตัวผู้ มัลติพอยท์ล็อก สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 805, greySahara8820: 825, sandSahara8515: 870, wood15656: 1090, mill: 525, anodizeNa: 595);
  addAlumetOfficial(code: 'SS-X217', name: 'ขวางบน-ล่าง (ล้อตลับ) ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1680, greySahara8820: 1725, sandSahara8515: 1810, wood15656: 2245);
  addAlumetOfficial(code: 'SS-0105', name: 'ขวางบน-ล่าง (ล้อตลาด) ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1355, greySahara8820: 1390, sandSahara8515: 1460, wood15656: 1815, mill: 920, anodizeNa: 1035);
  addAlumetOfficial(code: 'SS-0124', name: 'ขวางล่าง (ภายใน) ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1230, greySahara8820: 1265, sandSahara8515: 1330, wood15656: 1650, mill: 770, anodizeNa: 1125);
  addAlumetOfficial(code: 'SS-X209', name: 'เสากุญแจมัลติพอยท์ ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1860, greySahara8820: 1910, sandSahara8515: 2005, wood15656: 2445);
  addAlumetOfficial(code: 'SS-X210', name: 'ขวางบน-ล่าง (ล้อตลับ) ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1905, greySahara8820: 1955, sandSahara8515: 2055, wood15656: 2540);
  addAlumetOfficial(code: 'SS-X201', name: 'เสากุญแจมัลติพอยท์ ร่อง 16 สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1775, greySahara8820: 1820, sandSahara8515: 1915, wood15656: 2435, mill: 1225, anodizeNa: 1380);
  addAlumetOfficial(code: 'SS-X202', name: 'เสากุญแจมือจับมัลติพอยท์ ร่อง 16 สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2290, greySahara8820: 2350, sandSahara8515: 2470, wood15656: 3150, mill: 1565, anodizeNa: 1770);
  addAlumetOfficial(code: 'SS-X203', name: 'ขวางบน-ล่าง (ล้อตลับ) ร่อง 16 สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1805, greySahara8820: 1855, sandSahara8515: 1950, wood15656: 2400, mill: 1250, anodizeNa: 1405);
  addAlumetOfficial(code: 'SS-X204', name: 'เสริมร่องกระจก 9.5 มม. สมาร์ท เอ็กซ์', thickness: '1.1 มม.', whiteBlack8911: 360, greySahara8820: 365, sandSahara8515: 385, wood15656: 465, mill: 235, anodizeNa: 265);
  addAlumetOfficial(code: 'SS-X206', name: 'ฝาปิดเสริมมุ้งนิรภัยบานเลื่อน สมาร์ท เอ็กซ์', thickness: '1.1 มม.', whiteBlack8911: 160, greySahara8820: 165, sandSahara8515: 175, wood15656: 250, mill: 110, anodizeNa: 115);
  addAlumetOfficial(code: 'SS-X207', name: 'เสริมเสามือจับใหญ่ บานเลื่อน สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2245, greySahara8820: 2305, sandSahara8515: 2420, wood15656: 2950, mill: 1565, anodizeNa: 1755);
  addAlumetOfficial(code: 'SS-X208', name: 'เสริมเสามือจับเล็ก บานเลื่อน สมาร์ท เอ็กซ์', thickness: '2.0 มม.', whiteBlack8911: 1705, greySahara8820: 1750, sandSahara8515: 1840, wood15656: 2340);

  // 5 Smart X 45° / Corner profiles marked "รออัพเดท" in 11/05/2569 sheet -> benchmarked from sister Smart X sections
  addAlumetOfficial(code: 'SS-X212', name: 'เสากุญแจเข้ามุม 45° ร่อง 9.5 สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1680, greySahara8820: 1725, sandSahara8515: 1810, wood15656: 2245, isEstimated: true);
  addAlumetOfficial(code: 'SS-X219', name: 'เสากุญแจเข้ามุม 45° ร่อง 9.5 หนา 1.5 มม. สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1905, greySahara8820: 1955, sandSahara8515: 2055, wood15656: 2540, isEstimated: true);
  addAlumetOfficial(code: 'SS-X216', name: 'ตบเกี่ยวทางเดียว (เสา 45 องศา) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 665, greySahara8820: 685, sandSahara8515: 720, wood15656: 880, isEstimated: true);
  addAlumetOfficial(code: 'SS-X213', name: 'เสริมเสากุญแจเข้ามุม (ตัวเมีย) สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1450, greySahara8820: 1490, sandSahara8515: 1565, wood15656: 1950, isEstimated: true);
  addAlumetOfficial(code: 'SS-X214', name: 'เสริมเสากุญแจเข้ามุม (ตัวผู้) สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 980, greySahara8820: 1005, sandSahara8515: 1055, wood15656: 1320, isEstimated: true);

  // --- ALUMET Smart X Casement, Awning, Door, Fixed (หน้า 4-5) ---
  addAlumetOfficial(code: 'SC-X101', name: 'เฟรมบน-ข้างบานกระทุ้ง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1950, greySahara8820: 2000, sandSahara8515: 2100, wood15656: 2600, mill: 1325, anodizeNa: 1505);
  addAlumetOfficial(code: 'SC-X102', name: 'เฟรมล่างบานกระทุ้ง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2225, greySahara8820: 2280, sandSahara8515: 2400, wood15656: 2960, mill: 1505, anodizeNa: 1705);
  addAlumetOfficial(code: 'SC-X104', name: 'ตบเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1735, greySahara8820: 1780, sandSahara8515: 1870, wood15656: 2275, mill: 1185, anodizeNa: 1335);
  addAlumetOfficial(code: 'SC-X105', name: 'ฝาปิดร่อง C-18 สมาร์ท เอ็กซ์', thickness: '0.8 มม.', whiteBlack8911: 125, greySahara8820: 130, sandSahara8515: 135, wood15656: 200, mill: 55, anodizeNa: 70);
  addAlumetOfficial(code: 'SC-X106', name: 'เสริมช่องแสงเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์', thickness: '0.8 มม.', whiteBlack8911: 935, greySahara8820: 960, sandSahara8515: 1010, wood15656: 1265, mill: 635, anodizeNa: 715);
  addAlumetOfficial(code: 'SC-X107', name: 'เฟรมบน-ข้างบานกระทุ้ง ซีกรู๊ฟนอก สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2000, greySahara8820: 2055, sandSahara8515: 2160, wood15656: 2750);
  addAlumetOfficial(code: 'SC-X108', name: 'เฟรมล่างบานกระทุ้ง ซีกรู๊ฟนอก สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2245, greySahara8820: 2305, sandSahara8515: 2420, wood15656: 3085);
  addAlumetOfficial(code: 'SC-X204', name: 'กรอบบานกระทุ้ง 85 มม. สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2425, greySahara8820: 2485, sandSahara8515: 2615, wood15656: 3225);
  addAlumetOfficial(code: 'SC-0212', name: 'เสริมเสาบานเปิดคู่ สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1225, greySahara8820: 1255, sandSahara8515: 1320, wood15656: 1600, mill: 795, anodizeNa: 890);
  addAlumetOfficial(code: 'SO-X201', name: 'กรอบบานประตูบานเปิด 165 มม. สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 4080, greySahara8820: 4190, sandSahara8515: 4405, wood15656: 5410);
  addAlumetOfficial(code: 'SF-X105', name: 'เสริมช่องแสงเฟรมกระทุ้ง สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 865, greySahara8820: 885, sandSahara8515: 930, wood15656: 1140, woodEstimated: true);
  addAlumetOfficial(code: 'SF-X108', name: 'คิ้วช่องแสง/บานเปิด ร่อง 12.7 มม. สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 530, greySahara8820: 545, sandSahara8515: 570, wood15656: 695);
  addAlumetOfficial(code: 'SF-X109', name: 'เฟรมล่างช่องแสง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 2015, greySahara8820: 2070, sandSahara8515: 2175, wood15656: 2685);
  addAlumetOfficial(code: 'SF-X110', name: 'เฟรมบน-ข้างช่องแสง สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 1655, greySahara8820: 1700, sandSahara8515: 1785, wood15656: 2210);
  addAlumetOfficial(code: 'SF-X111', name: 'คิ้วช่องแสง/บานเปิด ร่อง 20 มม. สมาร์ท เอ็กซ์', thickness: '1.2 มม.', whiteBlack8911: 495, greySahara8820: 505, sandSahara8515: 530, wood15656: 685);

  // --- ALUMET Smart X Folding (หน้า 6) ---
  addAlumetOfficial(code: 'SB-0101', name: 'เฟรมบนบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '3.0 มม.', whiteBlack8911: 6070, greySahara8820: 6230, sandSahara8515: 6550, wood15656: 8025, mill: 4185, anodizeNa: 4740);
  addAlumetOfficial(code: 'SB-0103', name: 'เฟรมล่างบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2455, greySahara8820: 2520, sandSahara8515: 2650, wood15656: 3270, mill: 1700, anodizeNa: 1925);
  addAlumetOfficial(code: 'SB-0105', name: 'เฟรมข้างบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2630, greySahara8820: 2700, sandSahara8515: 2840, wood15656: 3500, mill: 1765, anodizeNa: 1995);
  addAlumetOfficial(code: 'SB-0108', name: 'คิ้วบางบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 435, greySahara8820: 445, sandSahara8515: 465, wood15656: 565, mill: 295, anodizeNa: 335);
  addAlumetOfficial(code: 'SB-0109', name: 'คิ้วหนาบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.0 มม.', whiteBlack8911: 660, greySahara8820: 675, sandSahara8515: 710, wood15656: 900, mill: 445, anodizeNa: 495);
  addAlumetOfficial(code: 'SB-0113', name: 'เสาบานเปิดคู่บานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2225, greySahara8820: 2280, sandSahara8515: 2400, wood15656: 2960, mill: 1530, anodizeNa: 1730);
  addAlumetOfficial(code: 'SB-0114', name: 'เสาประตูบานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 2570, greySahara8820: 2635, sandSahara8515: 2775, wood15656: 3380, mill: 1745, anodizeNa: 1975);
  addAlumetOfficial(code: 'SB-0115', name: 'รางฝังพื้นบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 670, greySahara8820: 685, sandSahara8515: 720, wood15656: 915, mill: 450, anodizeNa: 515);
  addAlumetOfficial(code: 'SB-0116', name: 'เฟรมล่างบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1645, greySahara8820: 1685, sandSahara8515: 1770, wood15656: 2195, mill: 1120, anodizeNa: 1265);
  addAlumetOfficial(code: 'SB-0117', name: 'เสริมเสาบานเปิดกลาง บานเฟี้ยม สมาร์ท เอ็กซ์', thickness: '1.5 มม.', whiteBlack8911: 1150, greySahara8820: 1180, sandSahara8515: 1240, wood15656: 1505, mill: 775, anodizeNa: 875);

  // --- ALUMET ICONIQ Euro Series (ราคาปลีกสีสต็อก_ไอคอนิค 110569 ล่าสุด หน้า 1-4) ---
  addAlumetOfficial(code: 'iS-0101', name: 'เฟรมบน-ล่างบานเลื่อน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 4185, greySahara8820: 4295, sandSahara8515: 4510, wood15656: 5485);
  addAlumetOfficial(code: 'iS-0102', name: 'เฟรมข้างบานเลื่อน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 1915, greySahara8820: 1965, sandSahara8515: 2065, wood15656: 2545);
  addAlumetOfficial(code: 'iS-0103', name: 'ยูเสริมปีกเฟรมข้างบานเลื่อน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 520, greySahara8820: 535, sandSahara8515: 560, wood15656: 720);
  addAlumetOfficial(code: 'iS-0104', name: 'ตบรางล้อบานเลื่อน ไอคอนิค (ชุบ E&A / ชุบดำ)', thickness: '4.5 มม.', whiteBlack8911: 360, greySahara8820: 360, sandSahara8515: 360, wood15656: 360, mill: 340, anodizeNa: 340);
  addAlumetOfficial(code: 'iS-0105', name: 'ฝาปิดระบายน้ำหน้าเฟรม ไอคอนิค', thickness: '1.2 มม.', whiteBlack8911: 135, greySahara8820: 135, sandSahara8515: 145, wood15656: 215);
  addAlumetOfficial(code: 'iS-0106', name: 'กันน้ำหัวบาน ไอคอนิค', thickness: '1.2 มม.', whiteBlack8911: 570, greySahara8820: 585, sandSahara8515: 615, wood15656: 780);
  addAlumetOfficial(code: 'iS-0107', name: 'ฝาปิดขอบปูน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 410, greySahara8820: 420, sandSahara8515: 445, wood15656: 535);
  addAlumetOfficial(code: 'iS-0113', name: 'ตบเฟรมบนบานเลื่อน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2505, greySahara8820: 2570, sandSahara8515: 2700, wood15656: 3320);
  addAlumetOfficial(code: 'iS-0114', name: 'ตบธรณีบานเลื่อน ไอคอนิค', thickness: '1.2 มม.', whiteBlack8911: 755, greySahara8820: 775, sandSahara8515: 810, wood15656: 985);
  addAlumetOfficial(code: 'iS-0116', name: 'เสริมช่องแสงเฟรมข้างบานเลื่อน ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 1160, greySahara8820: 1190, sandSahara8515: 1250, wood15656: 1555);
  addAlumetOfficial(code: 'iS-0201', name: 'กรอบบานเลื่อน 2.0 เปิดคิ้ว ไอคอนิค', thickness: '2.0 มม.', whiteBlack8911: 2850, greySahara8820: 2920, sandSahara8515: 3070, wood15656: 3770);
  addAlumetOfficial(code: 'iS-0202', name: 'คิ้วกรอบบาน 2.0 ร่องกระจก 12.7 มม. ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 475, greySahara8820: 490, sandSahara8515: 510, wood15656: 660);
  addAlumetOfficial(code: 'iS-0205', name: 'เสริมมุ้งบานเลื่อน ไอคอนิค', thickness: '1.0 มม.', whiteBlack8911: 420, greySahara8820: 430, sandSahara8515: 455, wood15656: 585);
  addAlumetOfficial(code: 'iO-0101', name: 'เฟรมประตูบานเปิด ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 3060, greySahara8820: 3140, sandSahara8515: 3300, wood15656: 4205);
  addAlumetOfficial(code: 'iO-0201', name: 'กรอบบานประตูบานเปิด ไอคอนิค', thickness: '2.0 มม.', whiteBlack8911: 3220, greySahara8820: 3305, sandSahara8515: 3470, wood15656: 4260);
  addAlumetOfficial(code: 'iO-0203', name: 'คิ้วกรอบบาน 12.7 ไอคอนิค', thickness: '1.1 มม.', whiteBlack8911: 515, greySahara8820: 525, sandSahara8515: 550, wood15656: 680);
  addAlumetOfficial(code: 'iC-0101', name: 'เฟรมบน-ข้างกระทุ้ง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2305, greySahara8820: 2365, sandSahara8515: 2485, wood15656: 3155);
  addAlumetOfficial(code: 'iC-0102', name: 'เฟรมล่างกระทุ้ง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2570, greySahara8820: 2640, sandSahara8515: 2770, wood15656: 3525);
  addAlumetOfficial(code: 'iC-0107', name: 'เฟรมบน-ข้างกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2250, greySahara8820: 2310, sandSahara8515: 2425, wood15656: 2985);
  addAlumetOfficial(code: 'iC-0108', name: 'เฟรมล่างกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2520, greySahara8820: 2585, sandSahara8515: 2715, wood15656: 3300);
  addAlumetOfficial(code: 'iC-0201', name: 'กรอบบานกระทุ้ง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2310, greySahara8820: 2370, sandSahara8515: 2490, wood15656: 3165);
  addAlumetOfficial(code: 'iF-0101', name: 'เฟรมบน-ข้างช่องแสง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2075, greySahara8820: 2130, sandSahara8515: 2235, wood15656: 2755);
  addAlumetOfficial(code: 'iF-0102', name: 'เฟรมล่างช่องแสง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 2360, greySahara8820: 2420, sandSahara8515: 2540, wood15656: 3130);
  addAlumetOfficial(code: 'iF-0104', name: 'ตบช่องแสง ไอคอนิค', thickness: '1.5 มม.', whiteBlack8911: 1465, greySahara8820: 1500, sandSahara8515: 1575, wood15656: 1950);

  // ALUMET 030038 C-Groove rod + Mosquito small sash
  addAlumetOfficial(code: '030038', name: 'ก้านสไลด์ มัลติพอยท์ล็อก', thickness: '2.0 มม.', whiteBlack8911: 290, greySahara8820: 300, sandSahara8515: 315, wood15656: 360, mill: 195, anodizeNa: 215);
  addAlumetOfficial(code: 'เส้น C-กรุ๊ฟ', name: 'เส้น C-กรุ๊ฟ ก้านสไลด์มัลติพอยท์ล็อก (030038)', thickness: 'ไม่ระบุความหนา', whiteBlack8911: 290, greySahara8820: 300, sandSahara8515: 315, wood15656: 360, mill: 195, anodizeNa: 215);
  addAlumetOfficial(code: 'เส้นซีกรุฟ (C-Groove)', name: 'เส้นซีกรุฟ C-Groove ก้านสไลด์มัลติพอยท์ล็อก (030038)', thickness: 'ไม่ระบุความหนา', whiteBlack8911: 290, greySahara8820: 300, sandSahara8515: 315, wood15656: 360, mill: 195, anodizeNa: 215);
  addAlumetOfficial(code: 'กรอบมุ้งตลาดเล็ก', name: 'กรอบมุ้งบานเลื่อนชุดมาตรฐาน', thickness: '1.0 มม.', whiteBlack8911: 310, greySahara8820: 320, sandSahara8515: 335, wood15656: 420, mill: 220, anodizeNa: 255, isEstimated: true);

  // --- ALUMET NEX (อลูเม็ท เน็กซ์ — ราคาขายปลีกทางการ Update: 21/11/2569) ---
  void addAlumetNexOfficial({
    required String code,
    required String name,
    required String thickness,
    required double white8911,
    required double black8816,
    required double greySahara8820,
    required double mill,
    double? anodizeNa,
    double? sandSahara8515,
    double? wood15656,
    bool isEstimated = false,
  }) {
    final effNa = anodizeNa ?? ((mill + white8911) / 2.0).roundToDouble();
    final effSand = sandSahara8515 ?? (greySahara8820 * 1.05).roundToDouble();
    final effWood = wood15656 ?? (white8911 * 1.33).roundToDouble();

    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'ตัวดิบ MILL', price: mill, isEstimated: isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'ชุบขาว', price: effNa, isEstimated: anodizeNa == null || isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'อบขาว (8911)', price: white8911, isEstimated: isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'อบดำ (8816)', price: black8816, isEstimated: isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'เทาซาฮาร่า (8820)', price: greySahara8820, isEstimated: isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'ทรายซาฮาร่า (8515)', price: effSand, isEstimated: sandSahara8515 == null || isEstimated);
    addSku(brand: 'ALUMET', code: code, name: name, thickness: thickness, color: 'ลายไม้ (15656 / 15659)', price: effWood, isEstimated: wood15656 == null || isEstimated);
  }

  // 15 Official NEX Retail SKUs (Update: 21/11/2569, 6.4 m/bar)
  addAlumetNexOfficial(code: 'PS-0206', name: 'เสากุญแจประตูบานเลื่อน เน็กซ์', thickness: '1.2 มม.', white8911: 1185, black8816: 1185, greySahara8820: 1250, mill: 1100);
  addAlumetNexOfficial(code: 'PS-0208', name: 'เสาเกี่ยว เน็กซ์', thickness: '1.2 มม.', white8911: 1030, black8816: 1030, greySahara8820: 1085, mill: 955);
  addAlumetNexOfficial(code: 'PS-0207', name: 'ขวางบน-ล่าง ล้อตลับ เน็กซ์', thickness: '1.2 มม.', white8911: 1150, black8816: 1150, greySahara8820: 1210, mill: 1070);
  addAlumetNexOfficial(code: 'PS-0210', name: 'ขวางบน-ล่าง ล้อตลาด เน็กซ์', thickness: '1.2 มม.', white8911: 1110, black8816: 1110, greySahara8820: 1165, mill: 1030);
  addAlumetNexOfficial(code: 'PS-0107', name: 'เฟรมบน 2 ราง เน็กซ์', thickness: '1.2 มม.', white8911: 1840, black8816: 1840, greySahara8820: 1935, mill: 1710);
  addAlumetNexOfficial(code: 'PS-0108', name: 'เฟรมล่าง 2 ราง เน็กซ์', thickness: '1.2 มม.', white8911: 2090, black8816: 2090, greySahara8820: 2200, mill: 1940);
  addAlumetNexOfficial(code: 'PS-0106', name: 'เฟรมข้างกล่องเรียบ เน็กซ์', thickness: '1.2 มม.', white8911: 1290, black8816: 1290, greySahara8820: 1355, mill: 1200);
  addAlumetNexOfficial(code: 'PS-0111', name: 'เสริมรับล็อกเฟรมข้าง เน็กซ์', thickness: '1.2 มม.', white8911: 670, black8816: 670, greySahara8820: 705, mill: 625);
  addAlumetNexOfficial(code: 'PC-0203', name: 'กรอบบานกระทุ้งซิงเกิลล็อก เน็กซ์', thickness: '1.0 มม.', white8911: 940, black8816: 940, greySahara8820: 990, mill: 870);
  addAlumetNexOfficial(code: 'PC-0104', name: 'เฟรมบน-ข้าง บานกระทุ้ง มัลติพอยท์ เน็กซ์', thickness: '1.0 มม.', white8911: 1460, black8816: 1460, greySahara8820: 1535, mill: 1380);
  addAlumetNexOfficial(code: 'PC-0105', name: 'เฟรมล่าง บานกระทุ้ง มัลติพอยท์ เน็กซ์', thickness: '1.0 มม.', white8911: 1580, black8816: 1580, greySahara8820: 1660, mill: 1465);
  addAlumetNexOfficial(code: 'PC-0204', name: 'กรอบบานกระทุ้ง มัลติพอยท์ เน็กซ์', thickness: '1.0 มม.', white8911: 1505, black8816: 1505, greySahara8820: 1585, mill: 1395);
  addAlumetNexOfficial(code: 'PF-0101', name: 'กล่องเปิด เน็กซ์', thickness: '1.2 มม.', white8911: 1670, black8816: 1670, greySahara8820: 1755, mill: 1550);
  addAlumetNexOfficial(code: 'PF-0102', name: 'ฝาปิด เน็กซ์', thickness: '1.2 มม.', white8911: 510, black8816: 520, greySahara8820: 535, mill: 485);
  addAlumetNexOfficial(code: 'PF-0103', name: 'กล่องร่อง เน็กซ์', thickness: '1.2 มม.', white8911: 1560, black8816: 1560, greySahara8820: 1640, mill: 1450);

  // Official ALUMET Hub shared codes used in NEX Catalog SP001/01-2026
  addAlumetOfficial(code: 'A30274', name: 'คิ้วช่องแสงเฟรมกระทุ้ง (A30274)', thickness: '1.5 มม.', whiteBlack8911: 460, greySahara8820: 470, sandSahara8515: 485, wood15656: 600, mill: 390, anodizeNa: 435);
  addAlumetOfficial(code: '2005', name: 'เส้นคาดกลางมุ้ง (2005)', thickness: '0.9 มม.', whiteBlack8911: 170, greySahara8820: 175, sandSahara8515: 180, wood15656: 225, mill: 140, anodizeNa: 160, woodEstimated: true);

  // Complementary NEX Catalog SP001/01-2026 codes calibrated by exact weight table (~300 B/kg powder coat, isEstimated: true)
  addAlumetNexOfficial(code: 'PS-0209', name: 'เสากุญแจหน้าต่างบานเลื่อน เน็กซ์', thickness: '1.2 มม.', white8911: 1005, black8816: 1005, greySahara8820: 1055, mill: 935, isEstimated: true);
  addAlumetNexOfficial(code: 'PS-0112', name: 'ตบเฟรมบนบานเลื่อน เน็กซ์', thickness: '1.2 มม.', white8911: 1625, black8816: 1625, greySahara8820: 1705, mill: 1510, isEstimated: true);
  addAlumetNexOfficial(code: 'PS-0109', name: 'ฝาตบเฟรมบน เน็กซ์', thickness: '1.2 มม.', white8911: 265, black8816: 265, greySahara8820: 280, mill: 245, isEstimated: true);
  addAlumetNexOfficial(code: 'PS-0110', name: 'ตบธรณีเฟรมล่าง เน็กซ์', thickness: '1.2 มม.', white8911: 365, black8816: 365, greySahara8820: 385, mill: 340, isEstimated: true);
  addAlumetNexOfficial(code: 'PS-0113', name: 'เฟรมบน 3 ราง เน็กซ์', thickness: '1.2 มม.', white8911: 1835, black8816: 1835, greySahara8820: 1925, mill: 1705, isEstimated: true);
  addAlumetNexOfficial(code: 'PS-0114', name: 'เฟรมล่าง 3 ราง เน็กซ์', thickness: '1.3 มม.', white8911: 2370, black8816: 2370, greySahara8820: 2490, mill: 2205, isEstimated: true);
  addAlumetNexOfficial(code: 'PC-0106', name: 'ซอยเฟรม บานกระทุ้ง เน็กซ์', thickness: '1.1 มม.', white8911: 2525, black8816: 2525, greySahara8820: 2655, mill: 2350, isEstimated: true);
  addAlumetNexOfficial(code: 'PC-0107', name: 'ตบเฟรม บานกระทุ้ง เน็กซ์', thickness: '1.1 มม.', white8911: 1400, black8816: 1400, greySahara8820: 1470, mill: 1300, isEstimated: true);
  addAlumetNexOfficial(code: 'PC-0205', name: 'เสาเสริมบานเปิดคู่ เน็กซ์', thickness: '1.0 มม.', white8911: 860, black8816: 860, greySahara8820: 900, mill: 800, isEstimated: true);
  addAlumetNexOfficial(code: 'A10261', name: 'ตบร่อง หนา 1.2 มม. เน็กซ์', thickness: '1.2 มม.', white8911: 965, black8816: 965, greySahara8820: 1010, mill: 895, isEstimated: true);
  addAlumetNexOfficial(code: '4011', name: 'เสากุญแจ ชุดมาตรฐาน (เน็กซ์ 100)', thickness: '1.0 มม.', white8911: 990, black8816: 990, greySahara8820: 1040, mill: 920, isEstimated: true);
  addAlumetNexOfficial(code: '4012', name: 'เสาเกี่ยว ชุดมาตรฐาน (เน็กซ์ 100)', thickness: '1.0 มม.', white8911: 1005, black8816: 1005, greySahara8820: 1055, mill: 935, isEstimated: true);
  addAlumetNexOfficial(code: '4016', name: 'ประกบกลาง ชุดมาตรฐาน (เน็กซ์ 100)', thickness: '1.0 มม.', white8911: 460, black8816: 460, greySahara8820: 480, mill: 425, isEstimated: true);
  addAlumetNexOfficial(code: '2006', name: 'กรอบมุ้ง (2006)', thickness: '1.2 มม.', white8911: 750, black8816: 750, greySahara8820: 790, mill: 700, isEstimated: true);
  addAlumetNexOfficial(code: '4017', name: 'ชนกลางมุ้ง (4017)', thickness: '1.2 มม.', white8911: 330, black8816: 330, greySahara8820: 345, mill: 305, isEstimated: true);
  addAlumetNexOfficial(code: '030065', name: 'กล่องก้าน 1 นิ้ว กระทุ้งยูเนี่ยน (เน็กซ์ 100)', thickness: '1.3 มม.', white8911: 1760, black8816: 1760, greySahara8820: 1845, mill: 1635, isEstimated: true);
  addAlumetNexOfficial(code: '010129', name: 'คิ้วตบประตูเหลี่ยม (010129)', thickness: '1.1 มม.', white8911: 335, black8816: 335, greySahara8820: 355, mill: 310, isEstimated: true);
  addAlumetNexOfficial(code: '010009', name: 'คิ้วลอยเทเหลี่ยม (010009)', thickness: '1.0 มม.', white8911: 545, black8816: 545, greySahara8820: 575, mill: 510, isEstimated: true);
  addAlumetNexOfficial(code: '010010', name: 'คิ้วตบเหลี่ยม (010010)', thickness: '1.0 มม.', white8911: 330, black8816: 330, greySahara8820: 345, mill: 305, isEstimated: true);

  // ---------------------------------------------------------------------------
  // 3. MARKET (ชุดตลาด) — Extracted from `aluprosmart.com` (`meterial.php` 1.2 Powder Coat)
  //    + ALUMET Box/Batten sheet (`ราคาขายปลีก_กล่อง 010867.pdf`)
  // ---------------------------------------------------------------------------
  void addMarketProfile({
    required String code,
    required String name,
    required double powderBase12, // 1.2 mm Powder Coat (อบขาว / อบดำ)
    bool isEstimated = false,
  }) {
    // Provide both 1.2 มม. and 1.5 มม. across standard colors so Market thickness/color selectors work seamlessly
    for (final thickEntry in const {'1.2 มม.': 1.0, '1.5 มม.': 1.22}.entries) {
      final tMult = thickEntry.value;
      final p12 = powderBase12 * tMult;
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'ตัวดิบ MILL', price: (p12 * 0.78).roundToDouble(), isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'ชุบขาว', price: (p12 * 0.88).roundToDouble(), isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'อบขาว (8911)', price: p12, isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'อบดำ (8816)', price: p12, isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'สีชา', price: (p12 * 0.96).roundToDouble(), isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'เทาซาฮาร่า (8820)', price: (p12 * 1.04).roundToDouble(), isEstimated: isEstimated);
      addSku(brand: 'MARKET', code: code, name: name, thickness: thickEntry.key, color: 'ลายไม้ (15656 / 15659)', price: (p12 * 1.38).roundToDouble(), isEstimated: isEstimated);
    }
  }

  // Exact from aluprosmart.com meterial.php rows 1, 19, 20, 51..59 + ALUMET Box sheet
  addMarketProfile(code: 'เฟรมบนติดกล่อง', name: 'เฟรมบนเสริมกล่อง (M40052C)', powderBase12: 1283.00);
  addMarketProfile(code: 'เฟรมล่างติดกล่อง', name: 'เฟรมล่างเสริมกล่อง (M40053C)', powderBase12: 1233.00);
  addMarketProfile(code: 'เฟรมข้างติดกล่อง', name: 'เฟรมข้างเสริมกล่อง 3.8 ซม. (M40051C)', powderBase12: 1075.00);
  addMarketProfile(code: 'เสาเกี่ยว', name: 'เสาเกี่ยวบานเลื่อน (M04012C)', powderBase12: 718.00);
  addMarketProfile(code: 'เสากุญแจ', name: 'เสากุญแจบานเลื่อน (M04011B)', powderBase12: 701.00);
  addMarketProfile(code: 'เสากุญแจบานเลื่อน (เสาตั้ง)', name: 'เสากุญแจบานเลื่อน (เสาตั้ง)', powderBase12: 701.00);
  addMarketProfile(code: 'เสาตาย', name: 'เสาตายบานเลื่อนชุดตลาด', powderBase12: 690.00, isEstimated: true);
  addMarketProfile(code: 'กรอบบานขวางบน', name: 'ขวางบนบานเลื่อน (M04014B)', powderBase12: 562.00);
  addMarketProfile(code: 'กรอบบานขวางล่าง', name: 'ขวางล่างบานเลื่อน (M04015C)', powderBase12: 742.00);
  addMarketProfile(code: 'ขวางบน / ขวางล่าง', name: 'ขวางบน / ขวางล่างบานเลื่อน', powderBase12: 652.00);
  addMarketProfile(code: 'กรอบนอกยูเนี่ยน', name: 'กรอบนอกยูเนี่ยน (M05398C)', powderBase12: 415.86);
  addMarketProfile(code: 'กรอบในยูเนี่ยน', name: 'กรอบในยูเนี่ยน (M05025F)', powderBase12: 547.23);
  addMarketProfile(code: 'ฉากข้อต่อ', name: 'ฉากข้อต่อ 1x1 นิ้ว หนา 2 มม.', powderBase12: 341.00);
  addMarketProfile(code: 'เฟรมบนไม่ติดกล่อง', name: 'เฟรมบนไม่ติดกล่อง', powderBase12: 690.00, isEstimated: true);
  addMarketProfile(code: 'เฟรมล่างไม่ติดกล่อง', name: 'เฟรมล่างไม่ติดกล่อง', powderBase12: 720.00, isEstimated: true);
  addMarketProfile(code: 'เฟรมข้างไม่ติดกล่อง', name: 'เฟรมข้างไม่ติดกล่อง', powderBase12: 540.00, isEstimated: true);
  addMarketProfile(code: 'กล่องเรียบ', name: 'กล่องเรียบ 1.8x4 นิ้ว', powderBase12: 1185.00); // ALUMET 831 1.2mm 8911 = 1,185
  addMarketProfile(code: 'กล่องเรียบแนวตั้ง', name: 'กล่องเรียบแนวตั้ง', powderBase12: 1185.00);
  addMarketProfile(code: 'กล่องเรียบแนวขวางบน', name: 'กล่องเรียบแนวขวางบน', powderBase12: 1185.00);
  addMarketProfile(code: 'กล่องเรียบแนวขวางล่าง', name: 'กล่องเรียบแนวขวางล่าง', powderBase12: 1185.00);
  addMarketProfile(code: 'เสาวงกบ (กล่องเรียบ)', name: 'เสาวงกบกล่องเรียบ', powderBase12: 1185.00);
  addMarketProfile(code: 'เสาวงกบ (กล่องกุญแจ/กล่องเรียบ)', name: 'เสาวงกบกล่องกุญแจ/กล่องเรียบ', powderBase12: 1210.00, isEstimated: true);
  addMarketProfile(code: 'ขวางวงกบบน', name: 'ขวางวงกบบน', powderBase12: 1185.00);
  addMarketProfile(code: 'กล่องแบ็คสั้น (วงกบบน)', name: 'กล่องแบ็คสั้น (วงกบบน)', powderBase12: 1080.00, isEstimated: true);
  addMarketProfile(code: 'ฝาแบ็คสั้น', name: 'ฝาตบแบ็คสั้น', powderBase12: 350.00, isEstimated: true);
  addMarketProfile(code: 'ธรณีสวิง (วงกบล่าง)', name: 'ธรณีบานสวิง (วงกบล่าง)', powderBase12: 780.00, isEstimated: true);
  addMarketProfile(code: 'เสากุญแจบานสวิง (เสาตั้ง)', name: 'เสากุญแจบานสวิง', powderBase12: 960.00, isEstimated: true);
  addMarketProfile(code: 'เสาบานสวิง (เสาตั้ง)', name: 'เสาบานสวิง', powderBase12: 960.00, isEstimated: true);
  addMarketProfile(code: 'ขวางบนบานสวิง', name: 'ขวางบนบานสวิง', powderBase12: 890.00, isEstimated: true);
  addMarketProfile(code: 'ขวางล่างบานสวิง', name: 'ขวางล่างบานสวิง', powderBase12: 1050.00, isEstimated: true);
  addMarketProfile(code: 'กล่อง 1.6 นิ้ว ตั้ง / เสาข้างวงกบ', name: 'กล่อง 1.6 นิ้ว ตั้ง / เสาข้างวงกบ (724)', powderBase12: 675.00); // ALUMET 724 8911 = 675
  addMarketProfile(code: 'กล่อง 1.6 นิ้ว นอน / วงกบบน', name: 'กล่อง 1.6 นิ้ว นอน / วงกบบน (724)', powderBase12: 675.00);
  addMarketProfile(code: 'รางแขวนบน (รางแขวนใหญ่)', name: 'รางแขวนบน (รางแขวนใหญ่)', powderBase12: 1380.00, isEstimated: true);
  addMarketProfile(code: 'รางแขวนบน (กล่องรางแขวน)', name: 'รางแขวนบน (กล่องรางแขวน)', powderBase12: 1590.00, isEstimated: true);

  // ---------------------------------------------------------------------------
  // 4. Euro & Pattana Brands (SCHIMMER, SMART_PLUS, FUJI, UAI, ALUFRAME)
  //    Benchmarked by profile structural role & section size (`isEstimated: true`)
  //    so 100% of active patterns calculate realistic costs & remain 1-tap editable!
  // ---------------------------------------------------------------------------
  void addBrandBenchmark({
    required String brand,
    required String code,
    required String name,
    required String primaryThick,
    required double whiteBlackBase,
    String? altThick,
    double stockM = 6.4,
  }) {
    final thicknesses = <String, double>{
      primaryThick: 1.0,
      if (altThick != null && altThick != primaryThick) altThick: 1.18,
    };
    for (final t in thicknesses.entries) {
      final base = whiteBlackBase * t.value;
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'ตัวดิบ MILL', stockM: stockM, price: (base * 0.76).roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'ชุบขาว', stockM: stockM, price: (base * 0.87).roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'อบขาว (8911)', stockM: stockM, price: base.roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'อบดำ (8816)', stockM: stockM, price: base.roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'เทาซาฮาร่า (8820)', stockM: stockM, price: (base * 1.04).roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'ทรายซาฮาร่า (8515)', stockM: stockM, price: (base * 1.08).roundToDouble(), isEstimated: true);
      addSku(brand: brand, code: code, name: name, thickness: t.key, color: 'ลายไม้ (15656 / 15659)', stockM: stockM, price: (base * 1.32).roundToDouble(), isEstimated: true);
    }
  }

  // --- SMS SCHIMMER (39 codes) ---
  final schimmerSpecs = <String, (String, String, double)>{
    'B10002': ('เฟรมบน/ล่างส่วนบานตาย HOMELIFE', '1.5 มม.', 1790),
    'B10003': ('ตัวปรับรับกระจก HOMELIFE', '1.2 มม.', 620),
    'B10004': ('เฟรมแคบ HOMELIFE', '1.5 มม.', 1480),
    'B10010': ('ตบกระจกแนวนอนส่วนบานตาย', '1.2 มม.', 540),
    'B10016': ('ถาดรองน้ำ B10016', '1.5 มม.', 920),
    'B10019': ('ถาดรองน้ำ B10019', '1.5 มม.', 980),
    'B10023': ('ถาดรองน้ำ B10023', '1.5 มม.', 1050),
    'B20001': ('เฟรมบน HOMELIFE 200', '1.5 มม.', 2280),
    'B20002': ('เฟรมล่าง HOMELIFE 200', '1.5 มม.', 2590),
    'B20003': ('เฟรมข้าง HOMELIFE 200', '1.5 มม.', 1750),
    'B20005': ('ขวางบน HOMELIFE 200', '1.5 มม.', 1580),
    'B20006': ('ขวางล่าง HOMELIFE 200', '1.5 มม.', 1720),
    'B20007': ('เสากุญแจ HOMELIFE 200', '1.5 มม.', 1690),
    'B20009': ('เสาเกี่ยว HOMELIFE 200', '1.5 มม.', 1740),
    'B20012': ('เสาเข้ามุมเสริม / เสากุญแจล็อก HOMELIFE 200', '1.5 มม.', 1890),
    'B20014': ('เสากุญแจตัวผู้ HOMELIFE 200', '1.5 มม.', 1820),
    'B20016': ('เสากุญแจตัวเมีย HOMELIFE 200', '1.5 มม.', 1860),
    'B20017': ('เสาเข้ามุม 90° HOMELIFE 200', '1.8 มม.', 2450),
    'B20018': ('ธรณีบานเลื่อน HOMELIFE 200', '1.2 มม.', 690),
    'B20020': ('รางล่างเสริม HOMELIFE 200', '1.5 มม.', 780),
    'B20024': ('แผงกั้นมุ้งลวด HOMELIFE 200', '1.2 มม.', 520),
    'B24001': ('เฟรมบนบานเฟี้ยม HOMELIFE 240 (HEAD)', '2.5 มม.', 5450),
    'B24002': ('ตบกันชนเฟรมบน HOMELIFE 240 (DOOR STOP HEAD)', '1.2 มม.', 680),
    'B24003': ('เฟรมล่างบานเฟี้ยม HOMELIFE 240 (SILL)', '1.8 มม.', 2390),
    'B24004': ('ตบกันชนเฟรมล่าง HOMELIFE 240 (DOOR STOP SILL)', '1.2 มม.', 640),
    'B24005': ('เฟรมข้างบานเฟี้ยม HOMELIFE 240 (JAMB)', '1.8 มม.', 2420),
    'B24006': ('ตบกันชนเฟรมข้าง HOMELIFE 240 (DOOR STOP JAMB)', '1.2 มม.', 640),
    'B24007': ('กรอบบานเฟี้ยม HOMELIFE 240 (SASH)', '1.8 มม.', 2650),
    'B24008': ('คิ้วกระจกบานเฟี้ยม HOMELIFE 240 (GLAZING BEAD)', '1.1 มม.', 490),
    'B24009': ('บังใบบานเฟี้ยม HOMELIFE 240 (SASH STOP)', '1.5 มม.', 1120),
    'B25001': ('เฟรมบน/ล่างประตูบานเปิด HOMELIFE 250', '1.8 มม.', 2680),
    'B25002': ('เฟรมข้างประตูบานเปิด HOMELIFE 250', '1.8 มม.', 2580),
    'B25003': ('ตบเบรคบาน HOMELIFE 250', '1.2 มม.', 590),
    'B25004': ('กรอบบานประตูบานเปิด HOMELIFE 250', '1.8 มม.', 3180),
    'B26001': ('เฟรมวงกบบานกระทุ้ง HOMELIFE 260', '1.5 มม.', 1980),
    'B26003': ('เฟรมประกบกลาง Couple Mullion HOMELIFE 260', '1.5 มม.', 2150),
    'B26004': ('กรอบบานหน้าต่าง HOMELIFE 260', '1.5 มม.', 2240),
    'B26007': ('คิ้วตบกระจก HOMELIFE 260', '1.1 มม.', 480),
    'B30006': ('กรอบมุ้งลวด HOMELIFE', '1.2 มม.', 960),
  };
  for (final e in schimmerSpecs.entries) {
    addBrandBenchmark(
      brand: 'SCHIMMER',
      code: e.key,
      name: e.value.$1,
      primaryThick: e.value.$2,
      whiteBlackBase: e.value.$3,
    );
  }

  // --- SMART_PLUS (61 codes) ---
  final smartPlusSpecs = <String, (String, String, double)>{
    '15100': ('เฟรมบน Semi Euro', '1.2 มม.', 1980),
    '15101': ('เฟรมล่างขาเตี้ย Semi Euro', '1.2 มม.', 2190),
    '15102': ('เฟรมล่างขาสูง Semi Euro', '1.2 มม.', 2420),
    '15104': ('เฟรมข้าง Semi Euro', '1.2 มม.', 1580),
    '15105': ('เสาเกี่ยว / เสากุญแจ Semi Euro', '1.2 มม.', 1520),
    '15106': ('ขวางบน / ล่าง Semi Euro', '1.2 มม.', 1540),
    '15107': ('ตบธรณีขาเตี้ย Semi Euro', '1.0 มม.', 590),
    '15109': ('ตบเกี่ยว Semi Euro', '1.2 มม.', 620),
    '15110': ('เดือยกุญแจ Semi Euro', '1.2 มม.', 480),
    '15111': ('ชนกลางบานเลื่อน Semi Euro', '1.5 มม.', 820),
    '15112': ('เดือยกุญแจ / ฝาปิดเดือยกุญแจ', '1.0 มม.', 360),
    '15115': ('คิ้วกระจก SMART PLUS', '1.1 มม.', 460),
    '15116': ('กรอบบาน Semi Euro', '1.2 มม.', 1890),
    '15117': ('กรอบบาน EURO 1.2 มม.', '1.2 มม.', 2050),
    '15120': ('คิ้วช่องแสงบน SMART PLUS', '1.1 มม.', 490),
    '15124': ('Adaptor SMART PLUS', '1.2 มม.', 680),
    '15125': ('เฟรมบน 3 ราง Semi Euro', '1.2 มม.', 2650),
    '15126': ('เฟรมล่าง 3 ราง Semi Euro', '1.2 มม.', 3120),
    '15128': ('ตบเกี่ยว 2 ทาง Semi Euro', '1.2 มม.', 960),
    '15131': ('กล่องก้าน HOLLOW 1.2 มม.', '1.2 มม.', 1150),
    '15132': ('กรอบมุ้งนิรภัย SMART PLUS', '1.5 มม.', 1880),
    '15133': ('คิ้วตบกรอบมุ้งนิรภัย SMART PLUS', '1.1 มม.', 420),
    '15135': ('เฟรมบน/ล่าง 3 ราง EURO', '1.5 มม.', 3480),
    '15140': ('เฟรมข้าง 3 ราง EURO', '1.5 มม.', 1920),
    '15141': ('กรอบบานกระทุ้ง 80 มิล EURO', '1.5 มม.', 2380),
    '15142': ('วงกบไม้ EURO', '1.5 มม.', 2190),
    '15143': ('เสาแบ่งช่องแสงบน EURO', '1.5 มม.', 2490),
    '15144': ('กรอบบานกระทุ้ง 80 มิล EURO', '1.5 มม.', 2380),
    '15145': ('คิ้วตบกระจก EURO', '1.1 มม.', 480),
    '15146': ('กรอบบานเลื่อน EURO', '1.5 มม.', 2560),
    '15147': ('กรอบบานเลื่อนใหญ่ EURO', '1.8 มม.', 2890),
    '15149': ('ฝาปิดรางเลื่อน EURO', '1.2 มม.', 410),
    '15150': ('ฝาปิดร่องเฟรม EURO', '1.0 มม.', 290),
    '15151': ('ฝาปิดกรอบบานบน EURO', '1.2 มม.', 520),
    '15155': ('วงกบบานเปิด EURO', '1.5 มม.', 2450),
    '15156': ('ตบปิดกล่องก้าน EURO', '1.2 มม.', 580),
    '15157': ('Transmission Rod ก้านส่งกำลัง', '2.0 มม.', 290),
    '15158': ('ตบเกี่ยวทางเดียว EURO', '1.5 มม.', 780),
    '15159': ('ตบเกี่ยว 2 ทาง EURO', '1.5 มม.', 1190),
    '15160': ('ฐานช่องแสงบน EURO', '1.5 มม.', 1720),
    '15162': ('เฟรมบน/ข้าง 3 ราง EURO', '1.5 มม.', 3150),
    '15163': ('เสาชนกลาง บานเปิดกลาง EURO', '1.5 มม.', 1120),
    '15167': ('เฟรมบนบานเฟี้ยม EURO', '3.0 มม.', 5850),
    '15168': ('เฟรมล่างบานเฟี้ยม EURO', '1.8 มม.', 2420),
    '15169': ('เฟรมข้างบานเฟี้ยม EURO', '1.8 มม.', 2540),
    '15171': ('เสาบานเฟี้ยม EURO', '1.8 มม.', 2590),
    '15173': ('คิ้วนอกบานเฟี้ยม ร่อง 12.7 มิล', '1.1 มม.', 450),
    '15174': ('คิ้วในบานเฟี้ยม ร่อง 12.7 มิล', '1.1 มม.', 620),
    '15177': ('บังใบบานเฟี้ยม EURO', '1.5 มม.', 1150),
    '15178': ('แกนกลางเฟี้ยม EURO', '1.8 มม.', 1680),
    '15179': ('เส้นเสริม C groove EURO', '1.5 มม.', 390),
    '15181': ('แกนกลางบังใบเฟี้ยม EURO', '1.8 มม.', 1850),
    '15182': ('เฟรมข้าง 3 ราง EURO', '1.5 มม.', 1950),
    '15183': ('เดือย/ฝาปิด EURO', '1.2 มม.', 440),
    '15190': ('เฟรม 2 ราง EURO', '1.5 มม.', 2680),
    '15191': ('Adapter ต่อเฟรม EURO', '1.5 มม.', 920),
    '15192': ('กรอบมุ้งนิรภัย EURO', '1.5 มม.', 1950),
    '15209': ('กรอบบานประตูบานเปิด EURO', '2.0 มม.', 3280),
    '15212': ('ฐานช่องแสงบน EURO', '1.5 มม.', 1780),
    '23 มม. ×4 ต่อมุ้ง · เส้น 6000 มม. · ใบตัด 4 มม./ครั้ง': ('เส้นต่อมุ้ง 23 มม.', '1.2 มม.', 420),
    'เส้น C-กรุ๊ฟ': ('เส้น C-กรุ๊ฟ ก้านส่งกำลังชุดล็อก', 'ไม่ระบุความหนา', 290),
  };
  for (final e in smartPlusSpecs.entries) {
    addBrandBenchmark(
      brand: 'SMART_PLUS',
      code: e.key,
      name: e.value.$1,
      primaryThick: e.value.$2,
      whiteBlackBase: e.value.$3,
      altThick: e.value.$2 == '1.2 มม.' ? '1.5 มม.' : null,
      stockM: e.key.contains('6000') ? 6.0 : 6.4,
    );
  }

  // --- UAI (11 codes) ---
  final uaiSpecs = <String, (String, String, double)>{
    'SLI-30628': ('ตบปิดราง UAI Super Frame', '1.0 มม.', 350),
    'SLI-30753': ('เฟรมล่าง 2 ราง UAI Super Frame', '1.2 มม.', 2240),
    'SLI-30754': ('กรอบบานแนวนอนบน-ล่าง UAI', '1.2 มม.', 1580),
    'SLI-30755': ('ตบเกี่ยวทางเดียว UAI', '1.2 มม.', 640),
    'SLI-30756': ('เฟรมบน 2 ราง UAI Super Frame', '1.2 มม.', 1980),
    'SLI-30900': ('เฟรมบน 3 ราง UAI Super Frame', '1.2 มม.', 2580),
    'SLI-30909': ('เฟรมล่าง 3 ราง UAI Super Frame', '1.2 มม.', 2980),
    'SLI-32019': ('เฟรมข้างซ้าย-ขวา UAI Super Frame', '1.2 มม.', 1620),
    'SLI-33001': ('อะแด๊ปเตอร์ชนกลางมีปีก UAI', '1.5 มม.', 820),
    'SLI-33002': ('กรอบบานแนวตั้ง UAI', '1.2 มม.', 1650),
    'SLI-33089': ('ยูรับล็อค UAI', '1.2 มม.', 540),
  };
  for (final e in uaiSpecs.entries) {
    addBrandBenchmark(
      brand: 'UAI',
      code: e.key,
      name: e.value.$1,
      primaryThick: e.value.$2,
      whiteBlackBase: e.value.$3,
      altThick: '1.5 มม.',
    );
  }

  // --- FUJI EUROTECH (35 codes) ---
  final fujiSpecs = <String, (String, String, double)>{
    'F7859': ('วงกบบานกระทุ้ง/บานเปิด Fuji Eurotech', '1.5 มม.', 2250),
    'F7860': ('คิ้วช่องแสงล่าง Fuji Eurotech', '1.1 มม.', 490),
    'F7919': ('คิ้วกระจก Fuji Eurotech', '1.1 มม.', 480),
    'F7932': ('ราง U ล่างบานเฟี้ยม Fuji Eurotech', '1.8 มม.', 1650),
    'F7935': ('คิ้วกระจก 5–12 mm Fuji Eurotech', '1.1 มม.', 510),
    'F7938': ('วงกบประตูบานเปิด Fuji Eurotech', '1.8 มม.', 2790),
    'F7939': ('วงกบแนวนอนด้านใน Fuji Eurotech', '1.5 มม.', 1890),
    'F7943': ('กรอบบาน Fuji Eurotech', '1.8 มม.', 2850),
    'F7944': ('กรอบมุ้ง Fuji Eurotech', '1.2 มม.', 1150),
    'F7945': ('เสากลางบาน Fuji Eurotech', '1.8 มม.', 2280),
    'F7948': ('รางมุ้ง Fuji Eurotech', '1.2 มม.', 780),
    'F7949': ('คิ้วมุ้ง Fuji Eurotech', '1.0 มม.', 360),
    'F7961': ('รับล็อกเฟรมข้างบานคู่ Fuji Eurotech', '1.5 มม.', 1120),
    'F7962': ('รับล็อกบานคู่ + บานคี่ Fuji Eurotech', '1.5 มม.', 1280),
    'F7968': ('วงกบบนบานเฟี้ยม Fuji Eurotech', '3.0 มม.', 5950),
    'F7969': ('วงกบล่างมาตรฐานบานเฟี้ยม Fuji Eurotech', '1.8 มม.', 2480),
    'F7970': ('วงกบข้างบานเฟี้ยม Fuji Eurotech', '1.8 มม.', 2560),
    'F7971': ('ตบวงกบข้างบานเฟี้ยม Fuji Eurotech', '1.2 มม.', 680),
    'F7972': ('กรอบบานเฟี้ยม Fuji Eurotech', '1.8 มม.', 2620),
    'F7973': ('ตัวปิดร่องบานเฟี้ยม Fuji Eurotech', '1.0 มม.', 320),
    'F7974': ('ชนกลางบานคู่ Fuji Eurotech', '1.8 มม.', 1980),
    'F7975': ('บังใบบานเฟี้ยม Fuji Eurotech', '1.2 มม.', 540),
    'F7976': ('เฟรมบน/ล่าง 2 ราง Fuji Eurotech', '1.5 มม.', 2780),
    'F7977': ('เฟรมบน/ล่าง 3 ราง Fuji Eurotech', '1.5 มม.', 3890),
    'F7978': ('เฟรมข้าง 2 ราง Fuji Eurotech', '1.5 มม.', 1890),
    'F7979': ('เฟรมข้าง 3 ราง Fuji Eurotech', '1.5 มม.', 2250),
    'F7980': ('กรอบบานเลื่อนหน้าต่าง Fuji Eurotech', '1.5 มม.', 2480),
    'F7981': ('กรอบบานเลื่อนประตู Fuji Eurotech', '1.8 มม.', 2920),
    'F7983': ('ตบเกี่ยว Fuji Eurotech', '1.5 มม.', 820),
    'F7986': ('ตบรับล็อค Fuji Eurotech', '1.5 มม.', 760),
    'F7988': ('ตบปิดร่อง Fuji Eurotech', '1.0 มม.', 310),
    'F7992': ('ตบฝังเฟรมบน Fuji Eurotech', '1.2 มม.', 580),
    'F7993': ('ตบปิดร่องราง Fuji Eurotech', '1.2 มม.', 420),
    'F7994': ('เส้นรางเลื่อน Fuji Eurotech', '2.0 มม.', 460),
    'F7997': ('คานแบ่งช่อง Fuji Eurotech', '1.5 มม.', 2350),
  };
  for (final e in fujiSpecs.entries) {
    addBrandBenchmark(
      brand: 'FUJI',
      code: e.key,
      name: e.value.$1,
      primaryThick: e.value.$2,
      whiteBlackBase: e.value.$3,
    );
  }

  // --- ALUFRAME (18 codes) ---
  final aluframeSpecs = <String, (String, String, double)>{
    'A1-001-15': ('เฟรมล่างบานเลื่อน ALUFRAME Euro', '1.5 มม.', 3250),
    'A1-002-15': ('เฟรมบนบานเลื่อน ALUFRAME Euro', '1.5 มม.', 2890),
    'A1-007-15': ('เฟรมข้างบานเลื่อน ALUFRAME Euro', '1.5 มม.', 1920),
    'A1-009-15': ('กรอบบานเลื่อน ALUFRAME Euro', '1.5 มม.', 2580),
    'A1-011-14R': ('ตบเกี่ยวเสา 87 มม. ALUFRAME Euro', '1.4 มม.', 840),
    'A1-018-11': ('ตบธรณีบานเลื่อน ALUFRAME Euro', '1.1 มม.', 690),
    'A1-021-12': ('คิ้วกระจกบานเลื่อน ALUFRAME Euro', '1.2 มม.', 490),
    'A1-024-17': ('เส้นตบรางเลื่อน ALUFRAME Euro', '1.7 มม.', 410),
    'A1-026-15': ('โปรไฟล์เสริม A1-026-15 ALUFRAME', '1.5 มม.', 980),
    'A1-027-15': ('บังใบหัวบาน ALUFRAME Euro', '1.5 มม.', 590),
    'A1-028-15': ('เดือยเสากุญแจเฟรมข้าง ALUFRAME Euro', '1.5 มม.', 680),
    'A2-002-15': ('เฟรมล่างบานกระทุ้ง ALUFRAME Euro', '1.5 มม.', 2420),
    'A2-003-15': ('เฟรมบนช่องแสง / เฟรมข้าง ALUFRAME Euro', '1.5 มม.', 2190),
    'A2-006-15': ('เฟรมบนบานกระทุ้ง ALUFRAME Euro', '1.5 มม.', 2280),
    'A2-010-15': ('กรอบบานกระทุ้ง ALUFRAME Euro', '1.5 มม.', 2340),
    'A2-012-12': ('คิ้วกรอบบาน/ช่องแสง ALUFRAME Euro', '1.2 มม.', 485),
    'A2-016-12': ('เสาประกบกลาง ALUFRAME Euro', '1.2 มม.', 1850),
    'A2-018-14': ('ตบปิดร่องตบเกี่ยว ALUFRAME Euro', '1.4 มม.', 360),
  };
  for (final e in aluframeSpecs.entries) {
    addBrandBenchmark(
      brand: 'ALUFRAME',
      code: e.key,
      name: e.value.$1,
      primaryThick: e.value.$2,
      whiteBlackBase: e.value.$3,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Glass Standard Rates (บาท / ตร.ม. — Grounded in aluprosmart.com 19/24/28 บ./ตร.ฟุต)
  //    (1 ตร.ม. = 10.7639 ตร.ฟุต -> 19 บ./ตร.ฟุต ≈ 205 บ./ตร.ม., 24 บ./ตร.ฟุต ≈ 260 บ./ตร.ม., 28 บ./ตร.ฟุต ≈ 300 บ./ตร.ม.)
  // ---------------------------------------------------------------------------
  final glassRates = <Map<String, dynamic>>[
    {'rateKey': 'GLASS|กระจกใส 5 มม.', 'category': 'GLASS', 'code': 'GLS-CLR-5', 'name': 'กระจกใส 5 มม. (~16 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 175.0, 'isEstimated': false},
    {'rateKey': 'GLASS|กระจกใส 6 มม.', 'category': 'GLASS', 'code': 'GLS-CLR-6', 'name': 'กระจกใส 6 มม. (19 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 205.0, 'isEstimated': false},
    {'rateKey': 'GLASS|กระจกใส 8 มม.', 'category': 'GLASS', 'code': 'GLS-CLR-8', 'name': 'กระจกใส 8 มม. (~32 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 345.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกใส 10 มม.', 'category': 'GLASS', 'code': 'GLS-CLR-10', 'name': 'กระจกใส 10 มม. (~42 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 450.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกเขียวตัดแสง 5 มม.', 'category': 'GLASS', 'code': 'GLS-GRN-5', 'name': 'กระจกเขียวตัดแสง 5 มม. (~20 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 215.0, 'isEstimated': false},
    {'rateKey': 'GLASS|กระจกเขียวตัดแสง 6 มม.', 'category': 'GLASS', 'code': 'GLS-GRN-6', 'name': 'กระจกเขียวตัดแสง 6 มม. (24 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 260.0, 'isEstimated': false},
    {'rateKey': 'GLASS|กระจกเขียวตัดแสง 8 มม.', 'category': 'GLASS', 'code': 'GLS-GRN-8', 'name': 'กระจกเขียวตัดแสง 8 มม. (~38 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 410.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกชาดำ 5 มม.', 'category': 'GLASS', 'code': 'GLS-TEA-5', 'name': 'กระจกชาดำ 5 มม. (~22 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 240.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกชาดำ 6 มม.', 'category': 'GLASS', 'code': 'GLS-TEA-6', 'name': 'กระจกชาดำ 6 มม. (~26 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 280.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกฝ้า 5 มม.', 'category': 'GLASS', 'code': 'GLS-FRS-5', 'name': 'กระจกฝ้า 5 มม. (28 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 300.0, 'isEstimated': false},
    {'rateKey': 'GLASS|กระจกฝ้า 6 มม.', 'category': 'GLASS', 'code': 'GLS-FRS-6', 'name': 'กระจกฝ้า 6 มม. (~33 บ./ตร.ฟุต)', 'unit': 'ตร.ม.', 'price': 355.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกเทมเปอร์ใส 8 มม.', 'category': 'GLASS', 'code': 'GLS-TMP-8', 'name': 'กระจกเทมเปอร์ใส 8 มม.', 'unit': 'ตร.ม.', 'price': 690.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกเทมเปอร์ใส 10 มม.', 'category': 'GLASS', 'code': 'GLS-TMP-10', 'name': 'กระจกเทมเปอร์ใส 10 มม.', 'unit': 'ตร.ม.', 'price': 850.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกเทมเปอร์ใส 12 มม.', 'category': 'GLASS', 'code': 'GLS-TMP-12', 'name': 'กระจกเทมเปอร์ใส 12 มม.', 'unit': 'ตร.ม.', 'price': 1050.0, 'isEstimated': true},
    {'rateKey': 'GLASS|กระจกลามิเนต 6+6 มม.', 'category': 'GLASS', 'code': 'GLS-LAM-12', 'name': 'กระจกลามิเนตนิรภัย', 'unit': 'ตร.ม.', 'price': 1150.0, 'isEstimated': true},
  ];

  // ---------------------------------------------------------------------------
  // 6. Hardware Rates (บาท / หน่วย — Grounded in ALUMET Hub Hardware 03/03/2568
  //    + aluprosmart.com meterial.php)
  // ---------------------------------------------------------------------------
  final formulasRaw = File('assets/data/formulas_168_verified.json').readAsStringSync();
  final fList = jsonDecode(formulasRaw) as List<dynamic>;

  final hardwareRates = <Map<String, dynamic>>[];
  final seenHwKeys = <String>{};

  void addHwRate({
    required String rateKey,
    required String code,
    required String name,
    required String unit,
    required double price,
    bool isEstimated = false,
  }) {
    if (seenHwKeys.contains(rateKey)) return;
    seenHwKeys.add(rateKey);
    hardwareRates.add({
      'rateKey': rateKey,
      'category': 'HARDWARE',
      'code': code,
      'name': name,
      'unit': unit,
      'price': price,
      if (isEstimated) 'isEstimated': true,
    });
  }

  // Exact ALUMET Hub Hardware (ราคาขายปลีกอุปกรณ์ 030368.pdf) + aluprosmart.com meterial.php rules
  (double, bool) inferHardwarePrice(String code, String name, String unit) {
    final c = code.trim().toUpperCase();
    final n = name.toLowerCase();

    // Direct code matches from ALUMET Hardware PDF & HYDA/Schimmer equivalents
    if (c == 'HD-640' || c == 'HD-640A' || c == 'HD-640B') return (450.0, false); // AKL-SMBF001 = 450
    if (c == 'HD-643' || c == 'HD-643A' || c == 'HD-643B') return (385.0, false); // AKL-SMBF002 = 385
    if (c == 'HD-641') return (105.0, false); // AKL-SMBF003 = 105
    if (c == 'HD-642') return (170.0, false); // AKL-SMBF004 = 170
    if (c == 'HD-320') return (105.0, false); // AKL-SMBF030 = 105
    if (c == 'HD-321') return (30.0, false); // AKL-EUCA028 = 30
    if (c == 'HD-474') return (120.0, false); // AKL-SMBF028 = 120
    if (c == 'HD-481A' || c == '00-024') return (450.0, false); // ACF-EUOP001 = 450
    if (c == 'HD-801') return (270.0, false); // AKL-SMBF013 = 270
    if (c == 'HD-851') return (345.0, false); // AKL-SMBF018 = 345
    if (c == 'HD-310') return (315.0, false); // AKL-SMBF025 = 315
    if (c == 'HD-929-2') return (135.0, false); // AKL-MTSL030 = 135
    if (c == 'HD-929-4') return (220.0, false); // AKL-MTSL031 = 220
    if (c == 'SS-0105' || c == '050-1520-2') return (45.0, false); // AAL-MTSL040 = 45
    if (c == 'HD-414' || c == 'HD-414-C2' || c == 'HD-453') return (165.0, false); // DH-PS102 / AKL-MTSL026 = 165
    if (c == 'HD-414D') return (210.0, false); // AKL-MTSL025 = 210
    if (c == 'HD-414-B') return (90.0, false); // ADC-MTSL039 = 90
    if (c == 'HD-1103') return (45.0, false); // AKL-MTSL029 = 45
    if (c == 'HD-1104') return (145.0, false); // AGU-MTSL046 = 145
    if (c == 'HD-1105' || c == 'ICONIQ_LOCKING_PINS') return (30.0, false);
    if (c == 'HD-1126' || c == 'HD-1129B' || c == 'ICONIQ_U_RECEIVERS') return (30.0, false); // AHD-ICSL050 = 30
    if (c == 'HD-214') return (45.0, false); // AHD-ICSL047 = 45
    if (c == 'HD-200' || c == 'HD-200A') return (15.0, false);
    if (c == 'HD-1015') return (10.0, false); // AAL-MTSL002 = 10
    if (c == 'HD-1021' || c == 'HD-1022' || c == 'HD-1025A') return (10.0, false); // AAL-MTSL006/007 = 10
    if (c == 'HD-1030' || c == 'HD-1033B') return (10.0, false); // AAL-MTSL001 / AAL-SMSL018 = 10
    if (c == 'HD-1035A') return (15.0, false); // AHD-MTSL049 = 15
    if (c == 'HD-1250') return (550.0, false); // aluprosmart.com สักหลาดม้วน = 550
    if (c == 'MS-2000' || c == 'KL-MS 7016') return (195.0, false); // aluprosmart.com MS 600ml = 195
    if (c == '3DI') return (65.0, true);
    if (c == 'HD-622') return (215.0, false); // AKL-EUCA024 = 215
    if (c == 'HD-626') return (260.0, false); // AKL-EUCA002+003 pair = 260

    // Keyword matching grounded in ALUMET Hub Hardware PDF + aluprosmart.com
    if (unit.contains('ม้วน')) {
      if (n.contains('สักหลาด')) return (550.0, false);
      if (n.contains('ยาง')) return (500.0, false);
      return (450.0, true);
    }
    if (unit.contains('หลอด') || n.contains('ซิลิโคน') || n.contains('sealant')) return (120.0, false);
    if (n.contains('มือจับฝังล็อก+กุญแจ')) return (210.0, false);
    if (n.contains('มือจับฝังล็อก') || n.contains('มือจับฝัง/เมโทร multi')) return (110.0, false);
    if (n.contains('มือจับฝังดัมมี่') || n.contains('เมโทร dummy') || n.contains('มือจับดัมมี่')) return (70.0, false);
    if (n.contains('มือจับฝัง')) return (165.0, false);
    if (n.contains('มือจับเขาควาย')) return (500.0, false);
    if (n.contains('มือจับกระทุ้ง') || n.contains('spindle')) return (206.0, false);
    if (n.contains('มือจับ')) return (215.0, false);
    if (n.contains('เสื้อกุญแจ') || n.contains('ตลับกุญแจ') || n.contains('mortise')) return (395.0, false);
    if (n.contains('ไส้กุญแจ')) return (270.0, false);
    if (n.contains('บานพับซ่อน')) return (430.0, false);
    if (n.contains('บานพับกระทุ้ง') || n.contains('4 bar') || n.contains('friction')) return (215.0, false);
    if (n.contains('บานพับ')) return (180.0, false);
    if (n.contains('ล้อบน') || n.contains('end carrier') || n.contains('intermediate carrier')) return (450.0, true);
    if (n.contains('pivot')) return (385.0, true);
    if (n.contains('ลูกล้อมุ้ง')) return (15.0, true);
    if (n.contains('ล้อตลับ') || n.contains('ลูกล้อตลับ')) return (45.0, false);
    if (n.contains('ล้อ')) return (135.0, false);
    if (n.contains('สปิก๊อต')) return (45.0, false);
    if (n.contains('ฉากเข้ามุม') || n.contains('ข้อต่อเข้ามุม')) return (35.0, false);
    if (n.contains('ฉากประคอง')) return (10.0, false);
    if (n.contains('แกนเกียร์') || n.contains('t-gear')) return (45.0, false);
    if (n.contains('ปุ่มล็อก') || n.contains('ปุ่มล็อค') || n.contains('ปุ่มเสริม') || n.contains('กระดุมล็อก')) return (30.0, false);
    if (n.contains('แป้นรับล็อก') || n.contains('แป้นรับล็อค') || n.contains('ยูรับล็อค') || n.contains('จุดรับล็อค') || n.contains('รับล็อก') || n.contains('striker') || n.contains('receiver')) return (30.0, false);
    if (n.contains('ฝาปิด') || n.contains('ตะแกรงระบายน้ำ') || n.contains('กันบานตก') || n.contains('ยางกันชน') || n.contains('ยางกันกระแทก') || n.contains('ตัวหยุดบาน') || n.contains('setting block') || n.contains('ล็อคมุมมุ้ง') || n.contains('มุมมุ้ง')) return (10.0, false);
    if (n.contains('สกรู') || n.contains('รีเวท') || n.contains('ยางอุดรู')) return (2.0, true);
    if (n.contains('สักหลาด') || n.contains('mohair')) return (25.0, true);
    if (n.contains('ยาง') || n.contains('seal') || n.contains('wedge')) return (35.0, true);
    return (85.0, true);
  }

  for (final rawTbl in fList) {
    final tbl = rawTbl as Map<String, dynamic>;
    final hws = tbl['hardware'] as List<dynamic>? ?? [];
    for (final rawHw in hws) {
      final h = rawHw as Map<String, dynamic>;
      final code = (h['code'] as String? ?? '').trim();
      final name = (h['name'] as String? ?? '').trim();
      final qtyText = (h['qtyText'] as String? ?? '1 ชิ้น').trim();
      final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(qtyText);
      final unit = m != null && m.group(2)!.trim().isNotEmpty ? m.group(2)!.trim() : 'ชิ้น';
      final rKey = code.isNotEmpty ? 'HW|$code|$name' : 'HW||$name';
      final (price, est) = inferHardwarePrice(code, name, unit);
      addHwRate(
        rateKey: rKey,
        code: code,
        name: name,
        unit: unit,
        price: price,
        isEstimated: est,
      );
    }
  }

  // Also add standalone ALUMET Hub Hardware items for direct search in Price Center
  const alumetCatalogHw = <(String, String, String, double)>[
    ('AKL-SMBF001', 'บานพับล้อบนบานเฟี้ยม ALUMET', 'ชิ้น', 450),
    ('AKL-SMBF002', 'บานพับไกด์ล่างบานเฟี้ยม ALUMET', 'ชิ้น', 385),
    ('AKL-SMBF003', 'บานพับบานเฟี้ยม ALUMET', 'ชิ้น', 105),
    ('AKL-SMBF004', 'บานพับมือจับบานเฟี้ยม ALUMET', 'ชิ้น', 170),
    ('AKL-SMBF021', 'ยางลูกโป่งบานเฟี้ยม (100 เมตร) ALUMET', 'ม้วน', 1150),
    ('ACF-EUCA001', 'บานพับ Hinge 80 กก. ALUMET', 'ชิ้น', 180),
    ('AKL-EUCA019', 'มือจับประตูบานเปิด #85 ALUMET', 'ชิ้น', 500),
    ('AKL-MTSL025', 'มือจับฝังล็อก+กุญแจ ALUMET', 'ชิ้น', 210),
    ('AKL-MTSL028', 'มือจับฝังล็อก ALUMET', 'ชิ้น', 110),
    ('AKL-MTSL030', 'ล้อบานเลื่อน 1624 (80 กก./คู่) ALUMET', 'คู่', 135),
    ('AKL-MTSL031', 'ล้อบานเลื่อน 1522 (180 กก./คู่) ALUMET', 'คู่', 220),
    ('AKL-MTSL036', 'สักหลาด 6x4 มม. (300 เมตร) ALUMET', 'ม้วน', 750),
    ('', 'ล้อตลาดบานเลื่อน NEX', 'ตัว', 35),
    ('', 'ลูกล้อมุ้งไฟเบอร์', 'ตัว', 15),
    ('', 'มุมมุ้งพลาสติก', 'ตัว', 10),
    ('', 'มือจับกระทุ้งซิงเกิลล็อก', 'ชุด', 165),
    ('', 'บานพับบานเปิด', 'คู่', 215),
  ];
  for (final item in alumetCatalogHw) {
    final rKey = item.$1.isNotEmpty ? 'HW|${item.$1}|${item.$2}' : 'HW||${item.$2}';
    addHwRate(
      rateKey: rKey,
      code: item.$1,
      name: item.$2,
      unit: item.$3,
      price: item.$4,
      isEstimated: item.$1.isEmpty,
    );
  }

  final outJson = {
    'version': '2.1.0',
    'generatedAt': '2026-11-23',
    'profiles': profiles,
    'glassRates': glassRates,
    'hardwareRates': hardwareRates,
  };

  final outFile = File('assets/data/catalog_prices_seed.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(outJson));

  print('Successfully generated assets/data/catalog_prices_seed.json:');
  print('  Profile SKUs: ${profiles.length}');
  print('  Glass Rates:  ${glassRates.length}');
  print('  Hardware Rates: ${hardwareRates.length}');
}

const Map<String, double> _ormColorMultipliers = {
  'ตัวดิบ MILL': 1.0,
  'ชุบขาว': 1.08,
  'พ่นขาว คอตตอน ไวท์': 1.06,
  'พ่นดำ ซุปเปอร์แบล็ค': 1.08,
  'พ่นเทา แชมเปญเกรย์ (สีใหม่)': 1.15,
  'พ่นเมทัลลิค (สีเดิม) / กาแล็คซี่ (สีใหม่)': 1.18,
  'ลายไม้ สักทอง / โอ๊ค / เดนมาร์ค': 1.95,
};
