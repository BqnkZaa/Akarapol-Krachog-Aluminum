import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfFontBundle {
  final pw.Font regular;
  final pw.Font bold;

  const PdfFontBundle({
    required this.regular,
    required this.bold,
  });

  pw.ThemeData get theme => pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      );
}

class PdfFonts {
  PdfFonts._();

  static PdfFontBundle? _cached;

  static Future<PdfFontBundle> load({String? testFontsDir}) async {
    if (_cached != null) return _cached!;

    final regBytes = await _loadFontBytes(
      'assets/fonts/Sarabun-Regular.ttf',
      testFontsDir,
    );
    final boldBytes = await _loadFontBytes(
      'assets/fonts/Sarabun-Bold.ttf',
      testFontsDir,
    );

    _cached = PdfFontBundle(
      regular: pw.Font.ttf(regBytes),
      bold: pw.Font.ttf(boldBytes),
    );
    return _cached!;
  }

  static Future<ByteData> _loadFontBytes(
    String assetPath,
    String? testFontsDir,
  ) async {
    if (testFontsDir != null) {
      final fileName = assetPath.split('/').last;
      final bytes = await File('$testFontsDir/$fileName').readAsBytes();
      return ByteData.sublistView(bytes);
    }
    try {
      return await rootBundle.load(assetPath);
    } catch (_) {
      final localFile = File(assetPath);
      if (localFile.existsSync()) {
        final bytes = await localFile.readAsBytes();
        return ByteData.sublistView(bytes);
      }
      rethrow;
    }
  }
}
