import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../engine/formula_evaluator.dart';
import '../models/app_models.dart';
import 'pdf_fonts.dart';

class SingleCutPdfGenerator {
  SingleCutPdfGenerator._();

  static String suggestedFileName([DateTime? now]) {
    final dt = now ?? DateTime.now();
    return 'Toolkit_CuttingOrder_${DateFormat('yyyyMMdd_HHmm').format(dt)}.pdf';
  }

  static Future<Uint8List> generate(
    CalculationOutput out, {
    DateTime? printedAt,
    String? testFontsDir,
  }) async {
    final fonts = await PdfFonts.load(testFontsDir: testFontsDir);
    final now = printedAt ?? DateTime.now();
    final doc = pw.Document(theme: fonts.theme);

    const navy = PdfColor.fromInt(0xFF1E3A8A);
    const blue = PdfColor.fromInt(0xFF2563EB);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderGray = PdfColor.fromInt(0xFFCBD5E1);
    const mutedText = PdfColor.fromInt(0xFF475569);
    const remnantBg = PdfColor.fromInt(0xFFE2E8F0);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Toolkit - ใบสั่งตัด · ${out.brandTitle} (${out.patternTitle})',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
              ),
              pw.Text(
                'หน้า ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
              ),
            ],
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // Header
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Toolkit - ใบสั่งตัด',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: navy,
                  ),
                ),
                pw.Text(
                  'วันที่พิมพ์: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
                  style: const pw.TextStyle(fontSize: 9.5, color: mutedText),
                ),
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 8));

          // Summary Box (สรุปงาน)
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderGray, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'สรุปงาน',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'แบรนด์ / ระบบ: ${out.brandTitle} · ${out.systemTitle}',
                          style: const pw.TextStyle(fontSize: 9.5),
                        ),
                      ),
                      pw.Text(
                        'จำนวนรวม: ${out.totalSetsCount} ชุด',
                        style: pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'รูปแบบบาน: ${out.patternTitle}',
                          style: const pw.TextStyle(fontSize: 9.5),
                        ),
                      ),
                      pw.Text(
                        'รวมเส้นสั่งซื้อ: ${out.totalStockBars} เส้น',
                        style: pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          // 1. รายการตัดอลูมิเนียม
          widgets.add(_sectionHeader('รายการตัดอลูมิเนียม', navy));
          for (final s in out.sets) {
            final wStr = FormulaEvaluator.formatMm(s.sizeRow.widthMm);
            final hStr = FormulaEvaluator.formatMm(s.sizeRow.heightMm);
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
                child: pw.Text(
                  'ชุดที่ ${s.setIndex} — $wStr × $hStr มม. | จำนวน ${s.sizeRow.qty} ชุด',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                headerStyle: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(2.4),
                  3: const pw.FlexColumnWidth(1.1),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(0.9),
                },
                headers: const [
                  'หมวด',
                  'รหัส',
                  'ชื่อชิ้นส่วน',
                  'ระยะตัด (มม.)',
                  'จำนวน',
                  'มุมตัด',
                ],
                data: s.cuts.map((c) {
                  final lenTxt = c.isSiteMeasured
                      ? 'วัดตามจริง'
                      : FormulaEvaluator.formatMm(c.lengthMm ?? 0);
                  return [
                    c.section,
                    c.code,
                    c.name,
                    lenTxt,
                    '${c.totalQty} ชิ้น',
                    c.angle,
                  ];
                }).toList(),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 14));

          // 2. การบริหารเส้น: สรุปจำนวนเส้นที่ต้องสั่งซื้อ
          if (out.barGroups.isNotEmpty) {
            widgets.add(_sectionHeader(
                'การบริหารเส้น: สรุปจำนวนเส้นที่ต้องสั่งซื้อ', navy));
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                headerStyle: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: const [
                  'รหัสหน้าตัด',
                  'ชื่อชิ้นส่วนรวม',
                  'เส้นโรงงาน',
                  'ยืนยัน',
                  'ประมาณการ',
                  'รวม',
                ],
                data: out.barGroups
                    .map((g) => [
                          g.code,
                          g.combinedNames,
                          '${g.stockLengthMm} mm',
                          '${g.confirmedBars.length} เส้น',
                          '${g.estimatedBars} เส้น',
                          '${g.totalBars} เส้น',
                        ])
                    .toList(),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Text(
                'กันระยะปลายเส้น 100 mm ตามระบบจัดท่อน · เศษคงเหลือแสดงจากช่วงใช้งาน',
                style: const pw.TextStyle(fontSize: 8, color: mutedText),
              ),
            );
            widgets.add(pw.SizedBox(height: 8));

            // Visual bar diagrams per profile group
            for (final grp in out.barGroups) {
              if (grp.confirmedBars.isEmpty) continue;
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                  child: pw.Text(
                    '${grp.code} — ${grp.combinedNames} (เส้น ${grp.stockLengthMm} mm)',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              );
              for (final bar in grp.confirmedBars) {
                widgets.add(
                  buildProportionalBarRow(
                    bar: bar,
                    totalWidthPt: 495,
                    cutColor: blue,
                    remnantColor: remnantBg,
                    borderColor: borderGray,
                  ),
                );
              }
            }

            // เศษคงเหลือหลังตัด
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  border: pw.Border.all(color: borderGray, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'เศษคงเหลือหลังตัด (รวมจากช่วงใช้งานหลังหักหัวท้าย 100 mm)',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${FormulaEvaluator.formatMm(out.totalRemnantMm)} mm',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));
          }

          // 3. กระจก
          final allGlasses = out.sets.expand((s) => s.glasses).toList();
          widgets.add(_sectionHeader('กระจก', navy));
          widgets.add(pw.SizedBox(height: 4));
          if (allGlasses.isEmpty) {
            widgets.add(pw.Text('ไม่มีรายการกระจก',
                style: const pw.TextStyle(fontSize: 9, color: mutedText)));
          } else {
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                headerStyle: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: const ['ชุดที่', 'รายการกระจก', 'ขนาดสั่งตัด', 'จำนวน'],
                data: allGlasses.map((g) {
                  final dim = g.siteCut
                      ? 'วัดตัดหน้างาน'
                      : '${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม.';
                  return [
                    'ชุดที่ ${g.setIndex}',
                    g.name,
                    dim,
                    '${g.totalPanels} แผ่น',
                  ];
                }).toList(),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 12));

          // 4. อุปกรณ์
          widgets.add(_sectionHeader('อุปกรณ์', navy));
          widgets.add(pw.SizedBox(height: 4));
          if (out.hardware.isEmpty) {
            widgets.add(pw.Text('ไม่มีรายการอุปกรณ์ประกอบ',
                style: const pw.TextStyle(fontSize: 9, color: mutedText)));
          } else {
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                headerStyle: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: const ['รหัส', 'รายการอุปกรณ์ประกอบ', 'จำนวนรวม'],
                data: out.hardware
                    .map((h) => [
                          h.code.isEmpty ? '-' : h.code,
                          h.name,
                          h.displayQty,
                        ])
                    .toList(),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _sectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget buildProportionalBarRow({
    required BarAssignment bar,
    required double totalWidthPt,
    required PdfColor cutColor,
    required PdfColor remnantColor,
    required PdfColor borderColor,
  }) {
    final usable = bar.usableLengthMm.toDouble();
    final segs = <pw.Widget>[];

    for (int i = 0; i < bar.cuts.length; i++) {
      final c = bar.cuts[i];
      final ratio = (c.lengthMm / usable).clamp(0.02, 1.0);
      final wPt = (ratio * totalWidthPt).clamp(18.0, totalWidthPt);
      final tagPrefix = c.itemTag != null ? '${c.itemTag} ' : '';
      final label = '$tagPrefix${FormulaEvaluator.formatMm(c.lengthMm)}';

      segs.add(
        pw.Container(
          width: wPt,
          height: 16,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: cutColor,
            border: pw.Border.all(color: PdfColors.white, width: 0.6),
          ),
          child: pw.Text(
            wPt >= 28 ? label : '',
            style: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      );
    }

    final rem = bar.remnantMm;
    if (rem > 1) {
      segs.add(
        pw.Expanded(
          child: pw.Container(
            height: 16,
            alignment: pw.Alignment.center,
            color: remnantColor,
            child: pw.Text(
              rem >= 350 ? 'เหลือ ${FormulaEvaluator.formatMm(rem)}' : '',
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColor.fromInt(0xFF334155),
              ),
            ),
          ),
        ),
      );
    }

    final usedStr = FormulaEvaluator.formatMm(bar.usedLengthMm);
    final remStr = FormulaEvaluator.formatMm(rem < 0 ? 0 : rem);
    final cutListStr = bar.cuts
        .map((c) =>
            '${c.itemTag != null ? "${c.itemTag} " : ""}${FormulaEvaluator.formatMm(c.lengthMm)}')
        .join(' + ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: totalWidthPt,
            height: 16,
            decoration: pw.BoxDecoration(
              color: remnantColor,
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Row(children: segs),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            'เส้นที่ #${bar.barIndex}: [$cutListStr] · ใช้ $usedStr mm · เหลือ $remStr mm · ใบเลื่อย 4 mm',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColor.fromInt(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
