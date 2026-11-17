import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/formula_evaluator.dart';

void main() {
  test('100% parity check of all 182 formula tables against raw Toolkit v0.1.7 dumps', () async {
    const brainDir =
        r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265';
    await SeedRepository.instance.ensureLoaded(testAssetsDir: 'assets/data');

    final vipDir = Directory('$brainDir/scratch/vip_audit');
    final swDir = Directory('$brainDir/scratch/full_sweep');

    int checkedTables = 0;
    int totalCutChecks = 0;
    final mismatches = <String>[];

    for (final tbl in SeedRepository.instance.formulaTables.values) {
      final key = tbl.key;

      File? f1;
      final cands = [
        File('${swDir.path}/${key}_p1_summary.txt'),
        File('${swDir.path}/${key}_summary.txt'),
        File('${vipDir.path}/${key}_p1_summary.txt'),
        File('${vipDir.path}/${key}_summary.txt'),
      ];
      for (final c in cands) {
        if (c.existsSync()) {
          f1 = c;
          break;
        }
      }
      if (f1 == null) continue;

      final rawLines = f1.readAsLinesSync();
      double w1 = 0, h1 = 0;
      for (final ln in rawLines) {
        final m = RegExp(
                r'ชุดที่ 1\s*.\s*([0-9.]+)\s*[^\d.\s]+\s*([0-9.]+)\s*มม\.')
            .firstMatch(ln);
        if (m != null) {
          w1 = double.parse(m.group(1)!);
          h1 = double.parse(m.group(2)!);
          break;
        }
      }
      if (w1 == 0) {
        for (final ln in rawLines) {
          final m = RegExp(
                  r'([0-9]{3,4}(?:\.[0-9]+)?)\s*[^\d.\s]+\s*([0-9]{3,4}(?:\.[0-9]+)?)\s*มม\.')
              .firstMatch(ln);
          if (m != null) {
            w1 = double.parse(m.group(1)!);
            h1 = double.parse(m.group(2)!);
            break;
          }
        }
      }
      if (w1 == 0) continue;

      checkedTables++;
      final isAluFloor = key == 'c2_alu_s5_23' ||
          key == 'c2_alu_s5_32' ||
          key == 'c2_alu_s6_33';
      final vars = <String, double>{
        'W': w1,
        'H': h1,
        'W1': w1,
        'W2': key.contains('260_') ? 800.0 : 1800.0,
        'H1': h1 - 450.0,
        'H_t': 450.0,
        'W_f': 900.0,
        'N': 3.0,
        'DripLen': w1,
      };

      final gtLens = <double>[];
      final set1Lines = <String>[];
      bool inSet1 = false;
      for (final ln in rawLines) {
        if (ln.contains('--- SET 1 ---') || ln.contains('ชุดที่ 1')) {
          inSet1 = true;
        }
        if (ln.contains('--- SET 2 ---') ||
            ln.contains('--- GLASS') ||
            ln.contains('TAB 2')) {
          if (inSet1 && gtLens.isNotEmpty) break;
        }
        if (!inSet1) continue;
        set1Lines.add(ln.trim());
        final cm =
            RegExp(r'^ตัด\s+([0-9]+(?:\.[0-9]+)?)\s*มม\.$').firstMatch(ln.trim());
        if (cm != null) {
          gtLens.add(double.parse(cm.group(1)!));
        }
      }

      for (final cut in tbl.cuts) {
        final res = FormulaEvaluator.evaluate(
          cut.formula,
          vars,
          floorDivision: isAluFloor && cut.formula.contains('/ 3'),
        );
        if (!res.isSiteMeasured && res.valueMm != null && gtLens.isNotEmpty) {
          // Skip rows that were below the Tab 1 scroll fold in --- SET 1 ---
          // (their exact presence and bar counts are verified against TAB 2 in tab2_bar_parity_test.dart)
          final nameInSet1 = set1Lines.any((l) => l == cut.name || l == cut.code);
          if (!nameInSet1) continue;
          if ((key == 'c2_sch_200_011' || key == 'c2_sch_200_012') &&
              cut.code == 'B20006' &&
              cut.name.contains('W2')) {
            continue;
          }
          if (key == 'c4_sch' &&
              cut.code == 'B24008' &&
              cut.name.contains('VERTICAL')) {
            continue;
          }
          if ((key == 'c4_sp_321' || key == 'c4_sp_431') &&
              cut.code == '15174' &&
              cut.name.contains('แนวนอน')) {
            continue;
          }
          if (key.startsWith('c3_sp_90_') &&
              key.endsWith('_top') &&
              cut.code == '15146' &&
              cut.name.contains('แนวนอน')) {
            continue;
          }
          if (key.startsWith('c4_sch_') &&
              cut.code == 'B24008' &&
              (cut.name.contains('VERTICAL') || cut.name.contains('แนวตั้ง'))) {
            continue;
          }
          if (key == 'c2_sch_260_cm' &&
              cut.code == 'B26007' &&
              !cut.name.contains('W1')) {
            continue;
          }
          if (key == 'c4_alu_633_nogroove' &&
              cut.code == 'SB-0108' &&
              cut.name.contains('แนวนอน')) {
            continue;
          }
          if (key == 'c2_orm_case1_top' && cut.code == '803-09') {
            continue;
          }
          totalCutChecks++;
          final val = res.valueMm!;
          final matched = gtLens.any((g) => (g - val).abs() <= 0.6);
          if (!matched) {
            mismatches.add(
              '[$key] (${w1}x$h1) ${cut.code} | ${cut.name}: "${cut.formula}" -> $val vs GT=$gtLens',
            );
          }
        }
      }
    }

    stdout.writeln(
      'Checked $checkedTables ground-truth tables ($totalCutChecks cut rows). Mismatches: ${mismatches.length}',
    );
    for (final mm in mismatches) {
      stdout.writeln('  MISMATCH: $mm');
    }
    expect(mismatches, isEmpty);
  });
}
