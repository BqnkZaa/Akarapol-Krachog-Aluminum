import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../engine/bin_packer.dart';
import '../engine/formula_evaluator.dart';
import '../models/app_models.dart';
import 'pdf_fonts.dart';
import 'single_cut_pdf.dart';

class ProjectPdfOptions {
  final bool includeSummary;
  final bool includeCutList;
  final bool includeBarOpt;
  final bool includeBom;

  const ProjectPdfOptions({
    this.includeSummary = true,
    this.includeCutList = true,
    this.includeBarOpt = true,
    this.includeBom = true,
  });

  bool get hasAnySelected =>
      includeSummary || includeCutList || includeBarOpt || includeBom;
}

class ProjectPdfGenerator {
  ProjectPdfGenerator._();

  static String suggestedFileName([DateTime? now]) {
    final dt = now ?? DateTime.now();
    return 'Toolkit_Project_${DateFormat('yyyyMMdd').format(dt)}.pdf';
  }

  static Future<Uint8List> generate(
    SavedProject project,
    ProjectPdfOptions options, {
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

    final totalUnits = project.items.fold(0, (s, i) => s + i.totalUnits);
    final packedGroups = BinPacker.packProjectItems(project.items);

    pw.Widget buildFooter(pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'เอกสารโครงการ Toolkit · ${project.name}',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
              ),
              pw.Text(
                'หน้า ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
              ),
            ],
          ),
        );

    // -------------------------------------------------------------------------
    // Cover TOC + Sections 1 & 2 (Portrait A4)
    // -------------------------------------------------------------------------
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        footer: buildFooter,
        build: (ctx) {
          final w = <pw.Widget>[];

          // Cover Header & TOC
          w.add(
            pw.Text(
              'เอกสารโครงการ Toolkit',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          );
          w.add(pw.SizedBox(height: 8));
          w.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderGray, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ชื่อโครงการ: ${project.name}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  if (project.note.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(
                        'โน้ตเพิ่มเติม: ${project.note}',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'จำนวนรายการในแฟ้มงาน: ${project.items.length} รายการ (รวม $totalUnits ชุด) · วันที่พิมพ์: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
                    style: const pw.TextStyle(fontSize: 9.5, color: mutedText),
                  ),
                ],
              ),
            ),
          );
          w.add(pw.SizedBox(height: 10));

          // TOC Box
          final tocLines = <String>[];
          if (options.includeSummary) tocLines.add('• 1. สรุปโครงการ');
          if (options.includeCutList) tocLines.add('• 2. ใบสั่งตัดแยกตามรายการ');
          if (options.includeBarOpt) tocLines.add('• 3. ใบคำนวณบริหารเส้น (A4 แนวนอน)');
          if (options.includeBom) tocLines.add('• 4. รายการวัสดุรวม');

          w.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGray, width: 0.6),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'สารบัญเอกสารที่เลือกส่งออก',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...tocLines.map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(line,
                          style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
          w.add(pw.SizedBox(height: 14));

          // Section 1: 1. สรุปโครงการ
          if (options.includeSummary) {
            w.add(_secTitle('1. สรุปโครงการ', navy));
            w.add(pw.SizedBox(height: 6));
            w.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                headerStyle: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: const [
                  'รหัสอ้างอิง',
                  'ตำแหน่งติดตั้ง',
                  'แบรนด์ / รูปแบบบาน',
                  'ขนาด (มม.)',
                  'จำนวน',
                ],
                data: List.generate(project.items.length, (idx) {
                  final it = project.items[idx];
                  return [
                    '[${it.displayOrderTag(idx + 1)}]',
                    it.installLocation.isEmpty ? '-' : it.installLocation,
                    '${it.brandTitle} · ${it.patternTitle}',
                    it.sizeSummaryText,
                    '${it.totalUnits} ชุด',
                  ];
                }),
              ),
            );
            w.add(pw.SizedBox(height: 14));
          }

          // Section 2: 2. ใบสั่งตัดแยกตามรายการ
          if (options.includeCutList) {
            w.add(_secTitle('2. ใบสั่งตัดแยกตามรายการ', navy));
            w.add(pw.SizedBox(height: 6));
            for (int idx = 0; idx < project.items.length; idx++) {
              final it = project.items[idx];
              final tag = '[${it.displayOrderTag(idx + 1)}]';
              final locTxt = it.installLocation.isNotEmpty
                  ? ' · ตำแหน่ง: ${it.installLocation}'
                  : '';
              w.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
                  child: pw.Text(
                    '$tag ${it.brandTitle} — ${it.patternTitle}$locTxt (รวม ${it.totalUnits} ชุด)',
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              );
              for (final s in it.evaluatedSets) {
                w.add(
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: borderGray, width: 0.5),
                    headerDecoration: const pw.BoxDecoration(color: lightBg),
                    headerStyle: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headers: const [
                      'หมวด',
                      'รหัส',
                      'ชื่อชิ้นส่วน',
                      'ระยะตัด (มม.)',
                      'จำนวน',
                      'มุมตัด',
                    ],
                    data: s.cuts
                        .map((c) => [
                              c.section,
                              c.code,
                              c.name,
                              c.isSiteMeasured
                                  ? 'วัดตามจริง'
                                  : FormulaEvaluator.formatMm(c.lengthMm ?? 0),
                              '${c.totalQty} ชิ้น',
                              c.angle,
                            ])
                        .toList(),
                  ),
                );
                w.add(pw.SizedBox(height: 4));
              }
            }
          }

          return w;
        },
      ),
    );

    // -------------------------------------------------------------------------
    // Section 3: 3. ใบคำนวณบริหารเส้น (LANDSCAPE A4!)
    // -------------------------------------------------------------------------
    if (options.includeBarOpt) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
          footer: buildFooter,
          build: (ctx) {
            final w = <pw.Widget>[];
            w.add(_secTitle(
                '3. ใบคำนวณบริหารเส้น (จัดท่อนรวมข้ามรายการทั้งโครงการ)', navy));
            w.add(pw.SizedBox(height: 4));
            w.add(
              pw.Text(
                'กันระยะปลายเส้น 100 mm ตามระบบจัดท่อน · เศษคงเหลือแสดงจากช่วงใช้งาน · ป้าย [01], [02] อ้างอิงลำดับรายการในโครงการ',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
              ),
            );
            w.add(pw.SizedBox(height: 6));

            if (packedGroups.isEmpty) {
              w.add(pw.Text('ไม่มีรายการจัดเส้น',
                  style: const pw.TextStyle(fontSize: 9.5, color: mutedText)));
            } else {
              w.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGray, width: 0.6),
                  headerDecoration: const pw.BoxDecoration(color: lightBg),
                  headerStyle: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headers: const [
                    'แบรนด์',
                    'รหัสหน้าตัด',
                    'ชื่อชิ้นส่วนรวม',
                    'ความยาวเส้น',
                    'ยืนยัน',
                    'ประมาณการ',
                    'รวมสั่งซื้อ',
                    'เศษคงเหลือรวม',
                  ],
                  data: packedGroups
                      .map((g) => [
                            g.brand,
                            g.code,
                            g.combinedNames,
                            '${g.stockLengthMm} mm',
                            '${g.confirmedBars.length} เส้น',
                            '${g.estimatedBars} เส้น',
                            '${g.totalBars} เส้น',
                            '${FormulaEvaluator.formatMm(g.totalRemnantMm)} mm',
                          ])
                      .toList(),
                ),
              );
              w.add(pw.SizedBox(height: 10));

              for (final grp in packedGroups) {
                if (grp.confirmedBars.isEmpty) continue;
                w.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                    child: pw.Text(
                      '${grp.brand} · ${grp.code} — ${grp.combinedNames} (เส้น ${grp.stockLengthMm} mm)',
                      style: pw.TextStyle(
                          fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                );
                for (final bar in grp.confirmedBars) {
                  w.add(
                    SingleCutPdfGenerator.buildProportionalBarRow(
                      bar: bar,
                      totalWidthPt: 760,
                      cutColor: blue,
                      remnantColor: remnantBg,
                      borderColor: borderGray,
                    ),
                  );
                }
              }
            }
            return w;
          },
        ),
      );
    }

    // -------------------------------------------------------------------------
    // Section 4: 4. รายการวัสดุรวม (Portrait A4)
    // -------------------------------------------------------------------------
    if (options.includeBom) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
          footer: buildFooter,
          build: (ctx) {
            final w = <pw.Widget>[];
            w.add(_secTitle('4. รายการวัสดุรวม (อลูมิเนียม กระจก และอุปกรณ์)', navy));
            w.add(pw.SizedBox(height: 8));

            // Consolidated Aluminum Bars
            w.add(
              pw.Text(
                'อลูมิเนียมสั่งซื้อรวมทั้งโครงการ',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            );
            w.add(pw.SizedBox(height: 4));
            if (packedGroups.isNotEmpty) {
              w.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGray, width: 0.6),
                  headerDecoration: const pw.BoxDecoration(color: lightBg),
                  headerStyle: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headers: const [
                    'แบรนด์',
                    'รหัสหน้าตัด',
                    'ชื่อชิ้นส่วน',
                    'เส้นโรงงาน',
                    'จำนวนเส้นรวม',
                  ],
                  data: packedGroups
                      .map((g) => [
                            g.brand,
                            g.code,
                            g.combinedNames,
                            '${g.stockLengthMm} มม.',
                            '${g.totalBars} เส้น',
                          ])
                      .toList(),
                ),
              );
            }
            w.add(pw.SizedBox(height: 12));

            // Consolidated Glass
            w.add(
              pw.Text(
                'กระจกสั่งตัดรวมทั้งโครงการ',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            );
            w.add(pw.SizedBox(height: 4));
            final glassRows = <List<String>>[];
            for (int idx = 0; idx < project.items.length; idx++) {
              final it = project.items[idx];
              final tag = '[${it.displayOrderTag(idx + 1)}]';
              for (final s in it.evaluatedSets) {
                for (final g in s.glasses) {
                  glassRows.add([
                    tag,
                    g.name,
                    g.siteCut
                        ? 'วัดตัดหน้างาน'
                        : '${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม.',
                    '${g.totalPanels} แผ่น',
                  ]);
                }
              }
            }
            if (glassRows.isNotEmpty) {
              w.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGray, width: 0.6),
                  headerDecoration: const pw.BoxDecoration(color: lightBg),
                  headerStyle: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headers: const ['รายการ', 'ชนิดกระจก', 'ขนาด', 'จำนวน'],
                  data: glassRows,
                ),
              );
            }
            w.add(pw.SizedBox(height: 12));

            // Consolidated Hardware
            w.add(
              pw.Text(
                'อุปกรณ์ประกอบรวมทั้งโครงการ',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            );
            w.add(pw.SizedBox(height: 4));
            final hwMap = <String, AggregatedHardwareItem>{};
            for (final it in project.items) {
              for (final h in it.hardware) {
                final k = '${h.code}|${h.name}|${h.unitOrNote}';
                final prev = hwMap[k];
                if (prev == null) {
                  hwMap[k] = h;
                } else if (prev.numericQty != null && h.numericQty != null) {
                  hwMap[k] = AggregatedHardwareItem(
                    code: h.code,
                    name: h.name,
                    numericQty: prev.numericQty! + h.numericQty!,
                    unitOrNote: h.unitOrNote,
                  );
                }
              }
            }
            if (hwMap.isNotEmpty) {
              w.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGray, width: 0.6),
                  headerDecoration: const pw.BoxDecoration(color: lightBg),
                  headerStyle: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headers: const ['รหัส', 'รายการอุปกรณ์', 'จำนวนรวม'],
                  data: hwMap.values
                      .map((h) => [
                            h.code.isEmpty ? '-' : h.code,
                            h.name,
                            h.displayQty,
                          ])
                      .toList(),
                ),
              );
            }

            return w;
          },
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _secTitle(String text, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }
}
