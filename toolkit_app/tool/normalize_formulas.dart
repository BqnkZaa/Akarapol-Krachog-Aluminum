import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'd:/Workshop/aluminum/toolkit_app/assets/data/formulas_168_verified.json';
  final list = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

  const twoSetBomKeys = {
    'c1_s2_1s1f',
    'c1_s2_boxframe',
    'c1_s4_center',
    'c1_union_awn1_v2',
    'c1_union_case1_v2',
    'c2_alu_d1',
    'c2_alu_s2',
    'c2_orm_case1',
    'c2_sch_200_s2',
    'c2_uai_s4',
    'c3_fuji_s2_final',
    'c4_alu_321',
    'c4_fuji_std_321',
    'c4_fuji_std_431',
    'c4_orm101_321',
    'c4_orm90_321',
    'c4_orm90_431',
    'c4_sch',
    'c4_sp_431',
  };

  for (final rawTbl in list) {
    final tbl = rawTbl as Map<String, dynamic>;
    final key = tbl['key'] as String;
    final cuts = (tbl['cuts'] as List<dynamic>).cast<Map<String, dynamic>>();
    final glasses = (tbl['glasses'] as List<dynamic>).cast<Map<String, dynamic>>();
    final hardware = (tbl['hardware'] as List<dynamic>).cast<Map<String, dynamic>>();

    // 1. Fix HOMELIFE 200 corner W2 formulas (011 outer & 012 inner)
    if (key == 'c2_sch_200_011' || key == 'c2_sch_200_012') {
      final isOuter = key == 'c2_sch_200_011';
      final sashDed = isOuter ? '198' : '230';
      final glassDed = isOuter ? '166' : '198';
      // Deduplicate B20009 R scroll artifact & fix W2 formulas
      cuts.removeWhere((c) =>
          c['code'] == 'B20009' &&
          (c['name'] as String).contains('001R') &&
          c['qty'] == 1);
      bool hasB20006W2 = false;
      for (final c in cuts) {
        final name = c['name'] as String;
        if (name.contains('เฟรมบน W2') || name.contains('เฟรมล่าง W2')) {
          c['formula'] = 'W2 - 22';
        } else if (name == 'ขวางบน W2') {
          c['formula'] = '(W2 - $sashDed) / 2';
        } else if (name == 'ขวางล่าง W2') {
          c['formula'] = '(W2 - $sashDed) / 2';
          hasB20006W2 = true;
        }
      }
      if (!hasB20006W2) {
        cuts.add({
          'section': 'กรอบบาน',
          'code': 'B20006',
          'name': 'ขวางล่าง W2',
          'stockMm': 6400,
          'qty': 2,
          'qtyText': '2 ชิ้น',
          'angle': '90° / 90°',
          'formula': '(W2 - $sashDed) / 2',
        });
      }
      for (final g in glasses) {
        if ((g['name'] as String).contains('W2')) {
          g['wFormula'] = '(W2 - $glassDed) / 2';
          g['hFormula'] = 'H - 118';
        }
      }
    }

    // 2. Fix HOMELIFE 240 2L (c4_sch) scroll artifact on DOOR STOP JAMB & add vertical bead
    if (key == 'c4_sch') {
      for (final c in cuts) {
        if (c['code'] == 'B24006') {
          c['formula'] = 'H - 96';
        }
      }
      if (!cuts.any((c) => c['code'] == 'B24008' && (c['name'] as String).contains('VERTICAL'))) {
        cuts.add({
          'section': 'คิ้วกระจก',
          'code': 'B24008',
          'name': 'VERTICAL GLAZING BEAD',
          'stockMm': 6400,
          'qty': 4,
          'qtyText': '4 ชิ้น',
          'angle': '90° / 90°',
          'formula': 'H - 242',
        });
      }
    }

    // 3. Ensure horizontal inner bead 15174 is present on c4_sp_321 & c4_sp_431
    if (key == 'c4_sp_321' &&
        !cuts.any((c) => c['code'] == '15174' && (c['name'] as String).contains('แนวนอน'))) {
      cuts.add({
        'section': 'คิ้วกระจกใน',
        'code': '15174',
        'name': 'คิ้วในบานเฟี้ยมร่องกระจก 12.7 มิล แนวนอน · อ้างอิงกรอบบานสุดท้าย',
        'stockMm': 6400,
        'qty': 6,
        'qtyText': '6 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 617.1) / 3',
      });
    }
    if (key == 'c4_sp_431' &&
        !cuts.any((c) => c['code'] == '15174' && (c['name'] as String).contains('แนวนอน'))) {
      cuts.add({
        'section': 'คิ้วกระจกใน',
        'code': '15174',
        'name': 'คิ้วในบานเฟี้ยมร่องกระจก 12.7 มิล แนวนอน · อ้างอิงกรอบบานสุดท้าย',
        'stockMm': 6400,
        'qty': 8,
        'qtyText': '8 ชิ้น',
        'angle': '90° / 90°',
        'formula': '(W - 758) / 4',
      });
    }

    // 4. Normalize exact closed-form glass formulas where single-pass or 2-set sweep left numeric literals
    switch (key) {
      case 'c2_orm_case1':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานกระทุ้ง',
            'qty': 1,
            'qtyText': '1 แผ่น',
            'siteCut': false,
            'wFormula': 'W - 216',
            'hFormula': 'H - 246',
          });
        break;
      case 'c2_sch_200_s2':
        glasses
          ..clear()
          ..add({
            'name': 'กระจก 5-6 มม.',
            'qty': 2,
            'qtyText': '2 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 156) / 2',
            'hFormula': 'H - 118',
          });
        break;
      case 'c3_alu_s3':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเลื่อน',
            'qty': 3,
            'qtyText': '3 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 315) / 3',
            'hFormula': 'H - 220',
          });
        break;
      case 'c3_alu_s4_1w':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเลื่อน',
            'qty': 4,
            'qtyText': '4 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 372) / 4',
            'hFormula': 'H - 220',
          });
        break;
      case 'c3_alu_s4_1w_top':
        glasses
          ..clear()
          ..addAll([
            {
              'name': 'กระจกบานเลื่อน',
              'qty': 4,
              'qtyText': '4 แผ่น',
              'siteCut': false,
              'wFormula': '(W - 372) / 4',
              'hFormula': 'H1 - 220',
            },
            {
              'name': 'กระจกช่องแสงบน',
              'qty': 1,
              'qtyText': '1 แผ่น',
              'siteCut': false,
              'wFormula': 'W - 80',
              'hFormula': '(H - H1) - 33',
            },
          ]);
        break;
      case 'c3_alu_s4_ctr':
        if (glasses.isEmpty) {
          glasses.add({
            'name': 'กระจกบานเลื่อน',
            'qty': 4,
            'qtyText': '4 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 456) / 4',
            'hFormula': 'H - 220',
          });
        }
        break;
      case 'c3_alu_s4_ctr_top':
        glasses
          ..clear()
          ..addAll([
            {
              'name': 'กระจกบานเลื่อน',
              'qty': 4,
              'qtyText': '4 แผ่น',
              'siteCut': false,
              'wFormula': '(W - 456) / 4',
              'hFormula': 'H1 - 220',
            },
            {
              'name': 'กระจกช่องแสงบน',
              'qty': 1,
              'qtyText': '1 แผ่น',
              'siteCut': false,
              'wFormula': 'W - 80',
              'hFormula': '(H - H1) - 33',
            },
          ]);
        break;
      case 'c3_fuji_s2_final':
        glasses
          ..clear()
          ..add({
            'name': 'กระจก',
            'qty': 2,
            'qtyText': '2 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 244) / 2',
            'hFormula': 'H - 210',
          });
        break;
      case 'c3_fuji_w1':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกกรอบบาน',
            'qty': 1,
            'qtyText': '1 แผ่น',
            'siteCut': false,
            'wFormula': 'W - 271',
            'hFormula': 'H - 271',
          });
        break;
      case 'c4_alu_321':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม',
            'qty': 3,
            'qtyText': '3 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 525.6) / 3',
            'hFormula': 'H - 216',
          });
        break;
      case 'c4_fuji_std_321':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม',
            'qty': 3,
            'qtyText': '3 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 510.9) / 3',
            'hFormula': 'H - 222',
          });
        break;
      case 'c4_fuji_std_431':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม',
            'qty': 4,
            'qtyText': '4 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 614) / 4',
            'hFormula': 'H - 222',
          });
        break;
      case 'c4_orm101_321':
      case 'c4_orm90_321':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม 3-2-1',
            'qty': 3,
            'qtyText': '3 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 465.9) / 3',
            'hFormula': 'H - 215',
          });
        break;
      case 'c4_orm90_431':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม 4-3-1',
            'qty': 4,
            'qtyText': '4 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 604) / 4',
            'hFormula': 'H - 215',
          });
        break;
      case 'c4_sch':
        glasses
          ..clear()
          ..add({
            'name': 'กระจก 6 มม.',
            'qty': 2,
            'qtyText': '2 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 321) / 2',
            'hFormula': 'H - 215',
          });
        break;
      case 'c4_sp_321':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม 3-2-1',
            'qty': 3,
            'qtyText': '3 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 557.1) / 3',
            'hFormula': 'H - 224',
          });
        break;
      case 'c4_sp_431':
        glasses
          ..clear()
          ..add({
            'name': 'กระจกบานเฟี้ยม 4-3-1',
            'qty': 4,
            'qtyText': '4 แผ่น',
            'siteCut': false,
            'wFormula': '(W - 678) / 4',
            'hFormula': 'H - 224',
          });
        break;
    }

    // 5. Normalize per-set BOM quantities for the 19 tables captured with 2 sets
    if (twoSetBomKeys.contains(key)) {
      if (key == 'c2_uai_s4') {
        hardware
          ..clear()
          ..addAll([
            {'code': '', 'name': 'มือจับฝัง / มือจับเมโทร', 'qtyText': '1 ชุดรวม'},
            {'code': '', 'name': 'แกนเกียร์ตัวที', 'qtyText': '1 ตัว'},
            {'code': '', 'name': 'ปุ่มล็อคบานเลื่อน', 'qtyText': '2 ตัว'},
            {'code': '', 'name': 'แป้นรับล็อค', 'qtyText': '2 ตัว'},
            {'code': '', 'name': 'ฝาปิดตบเกี่ยว', 'qtyText': '8 ตัว'},
            {'code': '', 'name': 'ล้อตลับ 15×20', 'qtyText': '8 ตัว'},
            {'code': 'HD-1025A', 'name': 'ตะแกรงน้ำไหลเล็ก', 'qtyText': 'ผู้ใช้กำหนด'},
            {'code': 'HD-1021', 'name': 'ตะแกรงระบายน้ำ', 'qtyText': 'ผู้ใช้กำหนด'},
            {'code': '', 'name': 'ยางกันชนบานเลื่อน', 'qtyText': 'ผู้ใช้กำหนด'},
            {'code': '', 'name': 'สักหลาด 5×4', 'qtyText': 'รอยืนยัน'},
          ]);
      } else {
        for (final hw in hardware) {
          final qt = hw['qtyText'] as String;
          final m = RegExp(r'^(\d+)\s+(.+)$').firstMatch(qt);
          if (m != null) {
            final n = int.parse(m.group(1)!);
            final unit = m.group(2)!;
            final perSet = (n == 21 && (hw['code'] == 'HD-641')) ? 9 : (n ~/ 2);
            hw['qtyText'] = '$perSet $unit';
          }
        }
        // Note: on c1_union_awn1_v2 / case1_v2 default hinge is 6 นิ้ว (or swapped dynamically)
      }
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  File(path).writeAsStringSync(encoder.convert(list));
  stdout.writeln('Normalized formulas_168_verified.json (${list.length} tables) successfully!');
}
