import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../engine/thai_baht_text.dart';
import '../models/app_models.dart';
import 'pdf_fonts.dart';

class QuotationPdfGenerator {
  QuotationPdfGenerator._();

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'en_US');

  static String formatMoney(double v) => _moneyFmt.format(v);

  static Future<Uint8List> generate({
    required SavedQuotation quotation,
    required ShopInfo shopInfo,
    String? testFontsDir,
  }) async {
    final fonts = await PdfFonts.load(testFontsDir: testFontsDir);
    final doc = pw.Document(theme: fonts.theme);

    const navy = PdfColor.fromInt(0xFF1E293B);
    const slateBg = PdfColor.fromInt(0xFFF1F5F9);
    const borderGray = PdfColor.fromInt(0xFFCBD5E1);
    const muted = PdfColor.fromInt(0xFF475569);

    pw.MemoryImage? logoImage;
    if (shopInfo.logoPath != null && shopInfo.logoPath!.trim().isNotEmpty) {
      final f = File(shopInfo.logoPath!);
      if (f.existsSync()) {
        try {
          logoImage = pw.MemoryImage(f.readAsBytesSync());
        } catch (_) {
          logoImage = null;
        }
      }
    }

    final isItemized = quotation.mode == 'ITEMIZED';
    final bahtWords = ThaiBahtText.convert(quotation.netTotal);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 32),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${quotation.qtNumber} · ${quotation.revisionTag}',
                style: const pw.TextStyle(fontSize: 8.5, color: muted),
              ),
              pw.Text(
                'หน้า ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8.5, color: muted),
              ),
            ],
          ),
        ),
        build: (ctx) {
          final w = <pw.Widget>[];

          // 1. Top Header: Shop Info (Left) + Document Title Box (Right)
          w.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 10),
                          child: pw.Container(
                            width: 48,
                            height: 48,
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              shopInfo.shopName.isEmpty
                                  ? 'ชื่อร้าน / บริษัท'
                                  : shopInfo.shopName,
                              style: pw.TextStyle(
                                fontSize: 13.5,
                                fontWeight: pw.FontWeight.bold,
                                color: navy,
                              ),
                            ),
                            if (shopInfo.address.trim().isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  shopInfo.address.trim(),
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: muted),
                                ),
                              ),
                            if (shopInfo.phone.trim().isNotEmpty ||
                                shopInfo.email.trim().isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  [
                                    if (shopInfo.phone.trim().isNotEmpty)
                                      'โทร: ${shopInfo.phone.trim()}',
                                    if (shopInfo.email.trim().isNotEmpty)
                                      'อีเมล: ${shopInfo.email.trim()}',
                                  ].join('   '),
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: muted),
                                ),
                              ),
                            if (shopInfo.taxId.trim().isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  'เลขประจำตัวผู้เสียภาษี: ${shopInfo.taxId.trim()}',
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  flex: 4,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: slateBg,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderGray, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          quotation.docTitle.isEmpty
                              ? 'ใบเสนอราคา'
                              : quotation.docTitle,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        _kvRow('เลขที่เอกสาร:', quotation.qtNumber),
                        _kvRow('วันที่ออก:', quotation.issueDate),
                        _kvRow('ยืนราคาถึง:', quotation.validUntil),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          w.add(pw.SizedBox(height: 12));

          // 2. Customer & Project Cards (2 Columns)
          w.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGray, width: 0.7),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ข้อมูลลูกค้า',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'ชื่อลูกค้า: ${quotation.customerName.isEmpty ? "-" : quotation.customerName}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'ที่อยู่: ${quotation.customerAddress.isEmpty ? "-" : quotation.customerAddress}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'ข้อมูลติดต่อ: ${quotation.customerContact.isEmpty ? "-" : quotation.customerContact}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGray, width: 0.7),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ข้อมูลโครงการ',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'โครงการ: ${quotation.projectName.isEmpty ? "-" : quotation.projectName}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'สถานที่ติดตั้ง: ${quotation.projectLocation.isEmpty ? "-" : quotation.projectLocation}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'ผู้เสนอราคา: ${shopInfo.proposerName.isEmpty ? "-" : shopInfo.proposerName}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          w.add(pw.SizedBox(height: 12));

          // 3. Line Items Table (Mode A: 6 Columns vs Mode B: Heading + 4 Columns + Lump Sum Bar)
          pw.Widget cellBox(
            pw.Widget child, {
            pw.Alignment alignment = pw.Alignment.center,
          }) {
            return pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              alignment: alignment,
              child: child,
            );
          }

          pw.Widget headerText(String t, {pw.TextAlign align = pw.TextAlign.center}) {
            return pw.Text(
              t,
              textAlign: align,
              style: pw.TextStyle(
                fontSize: 8.8,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            );
          }

          pw.Widget descriptionCell(QuotationLineEntry ln) {
            final subLines = ln.subtitle
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            return pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ln.label,
                    style: pw.TextStyle(
                      fontSize: 9.2,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  ...subLines.map(
                    (s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1.8),
                      child: pw.Text(
                        s,
                        style: const pw.TextStyle(
                          fontSize: 8.4,
                          color: PdfColor.fromInt(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (isItemized) {
            w.add(
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.52),
                  1: pw.FlexColumnWidth(3.42),
                  2: pw.FlexColumnWidth(1.20),
                  3: pw.FlexColumnWidth(0.68),
                  4: pw.FlexColumnWidth(1.10),
                  5: pw.FlexColumnWidth(1.18),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: slateBg),
                    children: [
                      cellBox(headerText('ลำดับ')),
                      cellBox(headerText('รายการ', align: pw.TextAlign.left),
                          alignment: pw.Alignment.centerLeft),
                      cellBox(headerText('ขนาด')),
                      cellBox(headerText('จำนวน')),
                      cellBox(headerText('ราคา/หน่วย', align: pw.TextAlign.right),
                          alignment: pw.Alignment.centerRight),
                      cellBox(headerText('ราคารวม', align: pw.TextAlign.right),
                          alignment: pw.Alignment.centerRight),
                    ],
                  ),
                  ...List.generate(quotation.lines.length, (i) {
                    final ln = quotation.lines[i];
                    return pw.TableRow(
                      children: [
                        cellBox(
                          pw.Text('${i + 1}',
                              style: const pw.TextStyle(fontSize: 8.8)),
                        ),
                        descriptionCell(ln),
                        cellBox(
                          pw.Text(
                            ln.sizeText,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8.6),
                          ),
                        ),
                        cellBox(
                          pw.Text('${ln.qty} ชุด',
                              style: const pw.TextStyle(fontSize: 8.8)),
                        ),
                        cellBox(
                          pw.Text(formatMoney(ln.unitPrice),
                              style: const pw.TextStyle(fontSize: 8.8)),
                          alignment: pw.Alignment.centerRight,
                        ),
                        cellBox(
                          pw.Text(
                            formatMoney(ln.lineTotal),
                            style: pw.TextStyle(
                              fontSize: 8.8,
                              fontWeight: pw.FontWeight.bold,
                              color: navy,
                            ),
                          ),
                          alignment: pw.Alignment.centerRight,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          } else {
            w.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  'รายการประกอบใบเสนอราคาเหมาทั้งโครงการ',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: navy,
                  ),
                ),
              ),
            );
            w.add(
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.65),
                  1: pw.FlexColumnWidth(3.85),
                  2: pw.FlexColumnWidth(1.65),
                  3: pw.FlexColumnWidth(0.95),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: slateBg),
                    children: [
                      cellBox(headerText('ลำดับ')),
                      cellBox(headerText('รายการ', align: pw.TextAlign.left),
                          alignment: pw.Alignment.centerLeft),
                      cellBox(headerText('ขนาด')),
                      cellBox(headerText('จำนวน')),
                    ],
                  ),
                  ...List.generate(quotation.lines.length, (i) {
                    final ln = quotation.lines[i];
                    return pw.TableRow(
                      children: [
                        cellBox(
                          pw.Text('${i + 1}',
                              style: const pw.TextStyle(fontSize: 8.8)),
                        ),
                        descriptionCell(ln),
                        cellBox(
                          pw.Text(
                            ln.sizeText,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8.6),
                          ),
                        ),
                        cellBox(
                          pw.Text('${ln.qty} ชุด',
                              style: const pw.TextStyle(fontSize: 8.8)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
            w.add(
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  color: slateBg,
                  border: pw.Border(
                    left: pw.BorderSide(color: borderGray, width: 0.6),
                    right: pw.BorderSide(color: borderGray, width: 0.6),
                    bottom: pw.BorderSide(color: borderGray, width: 0.6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ราคาเหมารวมทั้งโครงการ',
                      style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: navy),
                    ),
                    pw.Text(
                      '${formatMoney(quotation.lumpSumPrice)} บาท',
                      style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: navy),
                    ),
                  ],
                ),
              ),
            );
          }
          w.add(pw.SizedBox(height: 10));

          // 4. Thai Baht Text Pill (Left) + Totals Summary (Right)
          w.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: slateBg,
                      borderRadius: pw.BorderRadius.circular(5),
                      border: pw.Border.all(color: borderGray, width: 0.6),
                    ),
                    child: pw.Text(
                      'จำนวนเงินรวมทั้งสิ้น ($bahtWords)',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGray, width: 0.6),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      children: [
                        _summaryRow(
                            'รวมเป็นเงิน', '${formatMoney(quotation.subtotal)} บาท'),
                        if (quotation.discount > 0)
                          _summaryRow('ส่วนลด',
                              '-${formatMoney(quotation.discount)} บาท'),
                        if (quotation.vatEnabled)
                          _summaryRow('ภาษีมูลค่าเพิ่ม 7%',
                              '${formatMoney(quotation.vatAmount)} บาท'),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          decoration: const pw.BoxDecoration(
                            color: navy,
                            borderRadius: pw.BorderRadius.only(
                              bottomLeft: pw.Radius.circular(4),
                              bottomRight: pw.Radius.circular(4),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'ยอดสุทธิ',
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.Text(
                                '${formatMoney(quotation.netTotal)} บาท',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          w.add(pw.SizedBox(height: 12));

          // 5. เงื่อนไขและหมายเหตุ
          final condLines = <String>[
            if (quotation.paymentTerms.trim().isNotEmpty)
              'เงื่อนไขการชำระเงิน: ${quotation.paymentTerms.trim()}',
            if (quotation.leadTime.trim().isNotEmpty)
              'ระยะเวลาดำเนินงาน: ${quotation.leadTime.trim()}',
            if (quotation.warranty.trim().isNotEmpty)
              'การรับประกัน: ${quotation.warranty.trim()}',
            if (quotation.remarks.trim().isNotEmpty)
              'หมายเหตุเพิ่มเติม: ${quotation.remarks.trim()}',
          ];
          w.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGray, width: 0.6),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'เงื่อนไขและหมายเหตุ',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  if (condLines.isEmpty)
                    pw.Text('-',
                        style: const pw.TextStyle(fontSize: 8.5, color: muted))
                  else
                    ...condLines.map(
                      (c) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(c,
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                    ),
                ],
              ),
            ),
          );
          w.add(pw.SizedBox(height: 28));

          // 6. Dual Signature Block
          final proposerLabel = shopInfo.proposerName.trim().isNotEmpty
              ? shopInfo.proposerName.trim()
              : shopInfo.shopName.trim();
          w.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _signatureBox(
                  roleTitle: 'ผู้เสนอราคา',
                  personName: proposerLabel.isEmpty ? '........................' : proposerLabel,
                ),
                _signatureBox(
                  roleTitle: 'ผู้อนุมัติ / ผู้ว่าจ้าง',
                  personName: quotation.customerName.trim().isEmpty
                      ? '........................'
                      : quotation.customerName.trim(),
                ),
              ],
            ),
          );

          return w;
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kvRow(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(
            v,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.8)),
          pw.Text(
            val,
            style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureBox({
    required String roleTitle,
    required String personName,
  }) {
    return pw.SizedBox(
      width: 190,
      child: pw.Column(
        children: [
          pw.SizedBox(height: 22),
          pw.Container(
            width: 155,
            height: 0.7,
            color: const PdfColor.fromInt(0xFF64748B),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            roleTitle,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '($personName)',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'วันที่ ____ / ____ / ________',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
