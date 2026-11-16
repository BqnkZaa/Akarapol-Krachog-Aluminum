import '../models/app_models.dart';
import 'formula_evaluator.dart';

class ClipboardFormatter {
  ClipboardFormatter._();

  /// Produces the exact 1:1 plain-text clipboard format of Toolkit v0.1.7 (`คัดลอกรายการ`).
  static String formatCalculation(CalculationOutput out) {
    final sb = StringBuffer();
    sb.writeln('${out.brandTitle} | ${out.patternTitle}');
    sb.writeln('จำนวนรวม ${out.totalSetsCount} ชุด');
    sb.writeln('==============================');

    for (final setRes in out.sets) {
      final wStr = FormulaEvaluator.formatMm(setRes.sizeRow.widthMm);
      final hStr = FormulaEvaluator.formatMm(setRes.sizeRow.heightMm);
      sb.writeln(
          'ชุดที่ ${setRes.setIndex} — $wStr × $hStr มม. | จำนวน ${setRes.sizeRow.qty} ชุด');

      String currentSection = '';
      for (final cut in setRes.cuts) {
        if (cut.section != currentSection) {
          currentSection = cut.section;
          sb.writeln('[$currentSection]');
        }
        if (cut.isSiteMeasured) {
          sb.writeln(
              '- ${cut.code} | ${cut.name} : วัดตามจริง · ${cut.totalQty} ชิ้น (${cut.angle})');
        } else {
          final lenStr = FormulaEvaluator.formatMm(cut.lengthMm ?? 0);
          sb.writeln(
              '- ${cut.code} | ${cut.name} : ตัด $lenStr มม. · ${cut.totalQty} ชิ้น (${cut.angle})');
        }
      }
      sb.writeln('');
    }

    final allGlasses = out.sets.expand((s) => s.glasses).toList();
    if (allGlasses.isNotEmpty) {
      sb.writeln('--- กระจกที่ต้องสั่ง ---');
      for (final g in allGlasses) {
        if (g.siteCut) {
          sb.writeln('- ${g.name} : วัดตัดหน้างาน · ${g.totalPanels} แผ่น');
        } else {
          final gw = FormulaEvaluator.formatMm(g.widthMm ?? 0);
          final gh = FormulaEvaluator.formatMm(g.heightMm ?? 0);
          sb.writeln('- ${g.name} : $gw × $gh มม. · ${g.totalPanels} แผ่น');
        }
      }
      sb.writeln('');
    }

    if (out.barGroups.isNotEmpty) {
      sb.writeln('--- อลูมิเนียมที่ต้องสั่งซื้อ (จัดเส้น) ---');
      for (final grp in out.barGroups) {
        sb.writeln(
            '- ${grp.code} (${grp.combinedNames}) · เส้นโรงงาน ${grp.stockLengthMm} มม. : ${grp.totalBars} เส้น');
      }
      sb.writeln('');
    }

    if (out.hardware.isNotEmpty) {
      sb.writeln('--- อุปกรณ์ประกอบ ---');
      for (final hw in out.hardware) {
        final prefix = hw.code.isNotEmpty ? '${hw.code} | ' : '';
        sb.writeln('- $prefix${hw.name} : ${hw.displayQty}');
      }
    }

    return sb.toString().trimRight();
  }
}
