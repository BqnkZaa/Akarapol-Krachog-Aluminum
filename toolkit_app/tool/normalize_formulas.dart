import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'd:/Workshop/aluminum/toolkit_app/assets/data/formulas_168_verified.json';
  final list = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

  for (final rawTbl in list) {
    final tbl = rawTbl as Map<String, dynamic>;
    final key = tbl['key'] as String;
    final cuts = (tbl['cuts'] as List<dynamic>).cast<Map<String, dynamic>>();
    final glasses = (tbl['glasses'] as List<dynamic>).cast<Map<String, dynamic>>();

    void ensureCut(Map<String, dynamic> spec) {
      final exists = cuts.any((c) =>
          c['code'] == spec['code'] &&
          c['name'] == spec['name'] &&
          c['formula'] == spec['formula']);
      if (!exists) cuts.add(spec);
    }

    // -------------------------------------------------------------------------
    // A. Remove sweep scroll-artifact & section-header rows
    // -------------------------------------------------------------------------
    cuts.removeWhere((c) =>
        (c['code'] == 'SB-0108' && c['name'] == 'SB-0108') ||
        (c['code'] == 'F7973' && c['name'] == 'F7973') ||
        (c['code'] == 'ตัวหยุดบาน' && c['name'] == 'ตัวหยุดบาน') ||
        (c['code'] == 'ตบกระจก' && c['name'] == 'ตบกระจก'));

    // Non-stock-bar accessory brackets (appear in Tab 1 cut list, NOT in Tab 2/Tab 3 6400mm bars)
    for (final c in cuts) {
      if ((key == 'c1_s2_boxframe' || key == 'c1_s2_smoothbox') &&
          c['code'] == 'ฉากข้อต่อ') {
        c['stockMm'] = 0;
      }
      if ((c['code'] as String).contains('ฉากประกอบบานหลัก')) {
        c['stockMm'] = 0;
      }
      if ((c['code'] as String) == 'คิ้วยูเนี่ยน') {
        c['stockMm'] = 0;
      }
    }

    // Fix ALUMET Smart X corner duplicate SS-X216 scroll artifact
    if (key == 'c2_alu_s4_corner' ||
        key == 'c2_alu_s5_23' ||
        key == 'c2_alu_s5_32' ||
        key == 'c2_alu_s6_33') {
      cuts.removeWhere(
          (c) => c['code'] == 'SS-X216' && (c['qty'] as int) > 2);
      // Deduplicate identical (code, name) on SS-X216
      final seen = <String>{};
      cuts.retainWhere((c) {
        if (c['code'] != 'SS-X216') return true;
        final sig = '${c['code']}|${c['name']}';
        if (seen.contains(sig)) return false;
        seen.add(sig);
        return true;
      });
    }

    // -------------------------------------------------------------------------
    // B. Complete bottom rows truncated by Tab 1 scroll during initial sweep
    // -------------------------------------------------------------------------
    if (key == 'c1_s2_1s1f') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'เสากุญแจ',
        'name': 'เสากุญแจ',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90°',
        'formula': 'H - 20',
      });
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'เสาเกี่ยว',
        'name': 'เสาเกี่ยว',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90°',
        'formula': 'H - 20',
      });
    }

    if (key == 'c1_s2_boxframe') {
      cuts.removeWhere((c) => c['code'] == 'เสากุญแจ' || c['code'] == 'เสาเกี่ยว');
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'เสากุญแจ',
        'name': 'เสากุญแจ',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90°',
        'formula': 'H - 90',
      });
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'เสาเกี่ยว',
        'name': 'เสาเกี่ยว',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90°',
        'formula': 'H - 90',
      });
    }

    if (key == 'c1_s2_smoothbox') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'กรอบบานขวางล่าง',
        'name': 'กรอบบานขวางล่าง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90°',
        'formula': '(W - 243) / 2',
      });
    }

    if (key == 'c1_union_awn1_v2' || key == 'c1_union_case1_v2') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'กรอบในยูเนี่ยน',
        'name': 'แนวตั้ง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'H - 119',
      });
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'กรอบในยูเนี่ยน',
        'name': 'แนวนอน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'W - 119',
      });
      if (glasses.isEmpty) {
        glasses.add({
          'name': 'กระจก Market Union',
          'qty': 1,
          'qtyText': '1 แผ่น',
          'siteCut': true,
          'wFormula': '',
          'hFormula': '',
        });
      }
    }

    // Cat 2 ALUMET Smart X Sliding missing SS-X106 & transom bottom rows
    if (key == 'c2_alu_s2' ||
        key == 'c2_alu_s2_15mm_45_mkt' ||
        key == 'c2_alu_s2_top' ||
        key == 'c2_alu_s4' ||
        key == 'c2_alu_s4_top') {
      ensureCut({
        'section': 'เฟรม 90°',
        'code': 'SS-X106',
        'name': 'ตบธรณีแบบมีรางมุ้ง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 50',
      });
    }
    if (key == 'c2_alu_s2_top') {
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-X217',
        'name': 'กรอบบานแนวขวางล่าง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 246) / 2',
      });
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-X216',
        'name': 'ตบเกี่ยว',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H1 - 70',
      });
    }
    if (key == 'c2_alu_s4_top') {
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-X217',
        'name': 'กรอบบานแนวขวางล่าง',
        'stockMm': 6400,
        'qty': 4,
        'qtyText': '4 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 436) / 4',
      });
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-X216',
        'name': 'ตบเกี่ยว',
        'stockMm': 6400,
        'qty': 4,
        'qtyText': '4 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H1 - 70',
      });
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-0141',
        'name': 'เสาชนกลาง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H1 - 70',
      });
      ensureCut({
        'section': 'กรอบบาน 90° ช่องแสงบน',
        'code': 'SS-0117',
        'name': 'ฝาปิดชนกลาง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H1 - 70',
      });
    }

    // Cat 2 ORM Asian Trop Casement + Top Transom
    if (key == 'c2_orm_case1_top') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': '803-09',
        'name': 'กรอบบานกระทุ้ง · กรอบบานแนวตั้ง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'H1 - 33',
      });
      ensureCut({
        'section': 'กรอบบาน',
        'code': '803-09',
        'name': 'กรอบบานกระทุ้ง · กรอบบานแนวนอน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'W - 33',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': '803-04',
        'name': 'คิ้วกระจก 12.6 mm · แนวตั้ง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H1 - 136',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': '803-04',
        'name': 'คิ้วกระจก 12.6 mm · แนวนอน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 136',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': '803-04',
        'name': 'คิ้วกระจก 12.6 mm · ช่องแสงแนวตั้ง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(H - H1) - 25',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': '803-04',
        'name': 'คิ้วกระจก 12.6 mm · ช่องแสงแนวนอน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 94',
      });
      ensureCut({
        'section': 'ระบบมัลติพอยท์ล็อค',
        'code': 'เส้น C-กรุ๊ฟ',
        'name': 'เส้น C-กรุ๊ฟ',
        'stockMm': 6000,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 233',
      });
    }

    if (key == 'c2_orm_case1') {
      glasses
        ..clear()
        ..add({
          'name': 'กระจกบานกระทุ้ง',
          'qty': 1,
          'qtyText': '1 แผ่น',
          'siteCut': false,
          'wFormula': 'W - 116',
          'hFormula': 'H - 146',
        });
    }

    // ORM Wood Frame Door glazing bead 807-02 stock estimate (2 bars)
    if (key == 'c2_orm_wood_active') {
      cuts.removeWhere((c) => c['code'] == '807-02');
      cuts.addAll([
        {
          'section': 'อลูมิเนียมวัดตัดตามจริง',
          'code': '807-02',
          'name': 'คิ้วกรอบบานแนวตั้ง · วัดตัดตามจริง · ใส่แนวตั้งก่อน',
          'stockMm': 6400,
          'qty': 4,
          'qtyText': '4 ชิ้น',
          'angle': '90° / 90°',
          'formula': 'วัดตามจริง (ประมาณการรวม 4*(H - 234))',
        },
        {
          'section': 'อลูมิเนียมวัดตัดตามจริง',
          'code': '807-02',
          'name': 'คิ้วกรอบบานแนวนอน · วัดตัดตามจริง · ใส่หลังแนวตั้ง',
          'stockMm': 6400,
          'qty': 4,
          'qtyText': '4 ชิ้น',
          'angle': '90° / 90°',
          'formula': 'วัดตามจริง (ประมาณการรวม 4*(W - 234))',
        },
      ]);
    }

    // Schimmer HOMELIFE 200 6-panel & corner mosquito
    if (key == 'c2_sch_200_010') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'B20009',
        'name': 'เสาเกี่ยวฟิกซ์ · B20009-003',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 79',
      });
    }
    if (key == 'c2_sch_200_011' || key == 'c2_sch_200_012') {
      ensureCut({
        'section': 'มุ้งลวด',
        'code': 'B30006',
        'name': 'กรอบมุ้งลวดแนวตั้ง · B30006-002',
        'stockMm': 6400,
        'qty': 4,
        'qtyText': '4 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 69',
      });
      ensureCut({
        'section': 'มุ้งลวด',
        'code': 'B30006',
        'name': 'กรอบมุ้งลวดแนวนอน W1 · B30006-001',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W1 - 6) / 2',
      });
      ensureCut({
        'section': 'มุ้งลวด',
        'code': 'B30006',
        'name': 'กรอบมุ้งลวดแนวนอน W2 · B30006-001',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W2 - 6) / 2',
      });
    }

    // Schimmer HOMELIFE 260 Couple Mullion B26007 beads
    if (key == 'c2_sch_260_cm') {
      ensureCut({
        'section': 'คิ้วกระจก W2',
        'code': 'B26007',
        'name': 'คิ้วตบแนวนอน W2',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W2 - 128',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B26007',
        'name': 'คิ้วตบแนวตั้ง',
        'stockMm': 6400,
        'qty': 4,
        'qtyText': '4 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 128',
      });
    }

    // SMART PLUS Cat 2 15107 stock estimate
    if (key == 'c2_sp_s4_2t') {
      for (final c in cuts) {
        if (c['code'] == '15107') {
          c['formula'] = 'วัดตามจริง (ประมาณการรวม W - 50)';
        }
      }
    }

    // ALUFRAME Cat 3 A1-028-15 & A1-026-15 stock estimates
    if (key == 'c3_af_s2') {
      for (final c in cuts) {
        if (c['code'] == 'A1-028-15') {
          c['formula'] = 'วัดตามจริง (ประมาณการรวม 2*(H - 78))';
        }
      }
      ensureCut({
        'section': 'อลูมิเนียมวัดตัดตามจริง',
        'code': 'A1-026-15',
        'name': 'วัสดุโปรไฟล์ A1-026-15 · วัดตามจริง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'วัดตามจริง (ประมาณการรวม W - 46)',
      });
    }

    // ALUMET Iconiq Sliding vertical glazing beads iS-0202 & top transom profiles
    if (key.startsWith('c3_alu_s')) {
      final isTop = key.endsWith('_top');
      final panels = key.contains('s4') ? 4 : (key.contains('s3') ? 3 : 2);
      final vertExpr = isTop ? 'H1 - 211' : 'H - 211';
      final vertName = isTop
          ? 'ส่วนบานเลื่อน · ตามระยะตัดกรอบบานสุดท้าย'
          : 'ตามระยะตัดกรอบบานสุดท้าย';
      ensureCut({
        'section': isTop ? 'ส่วนบานเลื่อน · คิ้วกระจก' : 'คิ้วกระจก',
        'code': 'iS-0202',
        'name': vertName,
        'stockMm': 6400,
        'qty': 2 * panels,
        'qtyText': '${2 * panels} ชิ้น',
        'angle': '90° / 90°',
        'formula': vertExpr,
      });
    }
    if (key == 'c3_alu_s2' || key == 'c3_alu_s4_ctr' || key == 'c3_alu_s4_ctr_top') {
      ensureCut({
        'section': 'อลูมิเนียมวัดตัดตามจริง',
        'code': 'iS-0114',
        'name': 'ตบธรณี · วัดตามจริง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'วัดตามจริง (ประมาณการรวม W - 50)',
      });
    }
    if (key == 'c3_alu_s2_door_in_mosq') {
      ensureCut({
        'section': 'อลูมิเนียมวัดตัดตามจริง',
        'code': 'iS-0114',
        'name': 'ตบธรณี · วัดตามจริง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'วัดตามจริง (ประมาณการรวม W - 50)',
      });
      ensureCut({
        'section': 'อลูมิเนียมวัดตัดตามจริง',
        'code': 'iS-0205',
        'name': 'วัสดุโปรไฟล์ iS-0205 · วัดตามจริง',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'วัดตามจริง (ประมาณการรวม H - 81)',
      });
      ensureCut({
        'section': 'อลูมิเนียม',
        'code': 'เส้นซีกรุฟ (C-Groove)',
        'name': 'เส้นซีกรุฟ (C-Groove) · เสากุญแจ',
        'stockMm': 6000,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 481',
      });
    }
    if (key == 'c3_alu_s2_top' || key == 'c3_alu_s4_1w_top' || key == 'c3_alu_s4_ctr_top') {
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iS-0113',
        'name': 'ช่องแสงบน · วงกบบน',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 50',
      });
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iF-0102',
        'name': 'ช่องแสงบน · วงกบล่างช่องแสงบน',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 50',
      });
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iF-0101',
        'name': 'ช่องแสงบน · วงกบบนช่องแสงบน',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 50',
      });
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iS-0116',
        'name': 'ช่องแสงบน · เสริมเฟรมข้าง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - H1',
      });
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iO-0203',
        'name': 'ช่องแสงบน · คิ้วกระจกแนวนอน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 90',
      });
      ensureCut({
        'section': 'ส่วนช่องแสงบน',
        'code': 'iO-0203',
        'name': 'ช่องแสงบน · คิ้วกระจกแนวตั้ง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(H - H1) - 43',
      });
    }

    // ORM Euro Casement / Awning glazing bead stock estimate
    if (key == 'c3_orm_awn1_chk' || key == 'c3_orm_case1_chk') {
      for (final c in cuts) {
        if ((c['code'] as String).contains('812-10')) {
          if ((c['name'] as String).contains('แนวนอน')) {
            c['formula'] = 'วัดตามจริง (ประมาณการรวม 2*(W - 150))';
          } else {
            c['formula'] = 'วัดตามจริง (ประมาณการรวม 2*(H - 150))';
          }
        }
      }
    }

    // SMART PLUS Euro 90° Top Transom horizontal sash 15146
    if (key == 'c3_sp_90_s2_top') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': '15146',
        'name': 'กรอบบาน แนวนอน',
        'stockMm': 6400,
        'qty': 4,
        'qtyText': '4 ชิ้น',
        'angle': '45° / 45°',
        'formula': '(W + 26) / 2',
      });
    }
    if (key == 'c3_sp_90_s3_top') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': '15146',
        'name': 'กรอบบาน แนวนอน',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '45° / 45°',
        'formula': '(W + 99) / 3',
      });
    }
    if (key == 'c3_sp_90_s4_top') {
      ensureCut({
        'section': 'กรอบบาน',
        'code': '15146',
        'name': 'กรอบบาน แนวตั้ง',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'H1 - 68',
      });
      ensureCut({
        'section': 'กรอบบาน',
        'code': '15146',
        'name': 'กรอบบาน แนวนอน',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '45° / 45°',
        'formula': '(W + 100) / 4',
      });
    }

    // SMART PLUS Euro 45° Sliding 15157, 15158, 15163, 15151, 15179, 15212
    if (key == 'c3_sp_s2') {
      for (final c in cuts) {
        if (c['code'] == '15158') c['formula'] = 'H - 68';
        if (c['code'] == '15157') {
          c['formula'] = 'วัดตามจริง (ประมาณการรวม 2*(H - 68))';
        }
      }
    }
    if (key == 'c3_sp_s2_3t_sec') {
      ensureCut({
        'section': 'อลูมิเนียมวัดตัดตามจริง',
        'code': '15157',
        'name': 'Transmission Rod · วัดตัดตามจริง · อ้างอิงกรอบบานสำหรับถอดของ ไม่ใช่ระยะตัดจริง',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'วัดตามจริง (ประมาณการรวม 2*(H - 68))',
      });
    }
    if (key == 'c3_sp_s3_3t_euro' || key == 'c3_sp_s4_2t' || key == 'c3_sp_s4_4t') {
      for (final c in cuts) {
        if (c['code'] == '15157') {
          c['formula'] = 'วัดตามจริง (ประมาณการรวม 2*(H - 68))';
        }
        if (c['code'] == '15163' && (c['formula'] as String).contains('วัดตามจริง')) {
          c['formula'] = 'วัดตามจริง (ประมาณการรวม H - 68)';
        }
      }
    }
    if (key == 'c3_sp_s4_3t_sec') {
      ensureCut({
        'section': 'ตบ/ฝาปิด/เสริม',
        'code': '15151',
        'name': 'ใบบังฝนบานเลื่อน',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 88',
      });
      ensureCut({
        'section': 'ตบ/ฝาปิด/เสริม',
        'code': '15179',
        'name': 'เส้นเสริม C groove',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 70',
      });
    }
    if (key == 'c3_sp_win1_top' || key == 'c3_sp_win2_top') {
      ensureCut({
        'section': 'ช่องแสงบน',
        'code': '15212',
        'name': 'ฐานช่องแสงบน',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'W - 50',
      });
    }

    // Category 4 ALUMET / Fuji / Schimmer Folding completions
    if (key == 'c4_alu_440_nothresh' && glasses.isEmpty) {
      glasses.add({
        'name': 'กระจกบานเฟี้ยม',
        'qty': 4,
        'qtyText': '4 แผ่น',
        'siteCut': false,
        'wFormula': '(W - 662) / 4',
        'hFormula': 'H - 201',
      });
    }
    if (key == 'c4_alu_633_nogroove') {
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'SB-0108',
        'name': 'คิ้วภายนอกแนวนอน',
        'stockMm': 6400,
        'qty': 12,
        'qtyText': '12 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 1099.8) / 6',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'SB-0109',
        'name': 'คิ้วภายในแนวตั้ง',
        'stockMm': 6400,
        'qty': 12,
        'qtyText': '12 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 206',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'SB-0109',
        'name': 'คิ้วภายในแนวนอน',
        'stockMm': 6400,
        'qty': 12,
        'qtyText': '12 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 1099.8) / 6',
      });
      ensureCut({
        'section': 'เส้นเฉพาะ Layout',
        'code': 'SB-0117',
        'name': 'บังใบบานคี่',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 82',
      });
      ensureCut({
        'section': 'เส้น C-กรุ๊ฟ',
        'code': 'เส้น C-กรุ๊ฟ',
        'name': 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
        'stockMm': 6400,
        'qty': 2,
        'qtyText': '2 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 85',
      });
      ensureCut({
        'section': 'กรอบบานเฟี้ยม',
        'code': 'SB-0114',
        'name': 'กรอบบานแนวตั้ง',
        'stockMm': 6400,
        'qty': 12,
        'qtyText': '12 ชิ้น',
        'angle': '45° / 45°',
        'formula': 'H - 82',
      });
      ensureCut({
        'section': 'กรอบบานเฟี้ยม',
        'code': 'SB-0114',
        'name': 'กรอบบานแนวนอน',
        'stockMm': 6400,
        'qty': 12,
        'qtyText': '12 ชิ้น',
        'angle': '45° / 45°',
        'formula': '(W - 115.8) / 6',
      });
    }
    if (key == 'c4_alu_871' && glasses.isEmpty) {
      glasses.add({
        'name': 'กระจกบานเฟี้ยม',
        'qty': 8,
        'qtyText': '8 แผ่น',
        'siteCut': false,
        'wFormula': '(W - 1203.2) / 8',
        'hFormula': 'H - 216',
      });
    }
    if (key == 'c4_fuji_std_642') {
      for (final c in cuts) {
        c['formula'] = (c['formula'] as String)
            .replaceAll('157.8', '158')
            .replaceAll('877.8', '878');
      }
      for (final g in glasses) {
        g['wFormula'] = (g['wFormula'] as String).replaceAll('937.8', '938');
      }
    }
    if (key == 'c4_fuji_std_981' && glasses.isEmpty) {
      glasses.add({
        'name': 'กระจกบานเฟี้ยม',
        'qty': 9,
        'qtyText': '9 แผ่น',
        'siteCut': false,
        'wFormula': '(W - 1338.9) / 9',
        'hFormula': 'H - 222',
      });
    }

    // Schimmer HOMELIFE 240 3-panel & 4-panel glazing beads B24008 & lock stile
    if (key == 'c4_sch_3_1l2r') {
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'HORIZONTAL GLAZING BEAD',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 413.1) / 3',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'VERTICAL GLAZING BEAD',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 242',
      });
    }
    if (key == 'c4_sch_3_3l') {
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'HORIZONTAL GLAZING BEAD · B24008-001',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 408) / 3',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'VERTICAL GLAZING BEAD · B24008-002',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 242',
      });
    }
    if (key == 'c4_sch_4_1l3r') {
      cuts.removeWhere((c) =>
          c['code'] == 'B24007' && (c['name'] as String).contains('003L'));
      ensureCut({
        'section': 'กรอบบาน',
        'code': 'B24007',
        'name': 'กรอบบานแนวตั้งมือจับล็อก · B24007-003L',
        'stockMm': 6400,
        'qty': 1,
        'qtyText': '1 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 92',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'คิ้วกระจกแนวนอน · B24008-001',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 526.8) / 4',
      });
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'คิ้วกระจกแนวตั้ง · B24008-002',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 242',
      });
    }
    if (key == 'c4_sch_4_2l2r') {
      ensureCut({
        'section': 'คิ้วกระจก',
        'code': 'B24008',
        'name': 'คิ้วกระจกแนวตั้ง · B24008-002',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '90° / 90°',
        'formula': 'H - 242',
      });
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  File(path).writeAsStringSync(encoder.convert(list));
  stdout.writeln('Updated formulas_168_verified.json (${list.length} tables) successfully!');
}
