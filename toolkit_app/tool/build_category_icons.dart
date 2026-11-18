// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _brandsDir = 'assets/brands';

// High-DPI 5x canvas for a 122x76 dp showcase plate on CategorySelectScreen
const int _plateW = 610;
const int _plateH = 380;

img.Image _trimTransparent(img.Image src) {
  int minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a.toInt() > 14) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < minX || maxY < minY) return src;
  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

void _drawRoundedBox(
  img.Image canvas, {
  required int x,
  required int y,
  required int w,
  required int h,
  required double radius,
  required List<int> fillRgba,
  List<int>? borderRgba,
  double borderWidth = 2.0,
}) {
  final xEnd = math.min(canvas.width, x + w);
  final yEnd = math.min(canvas.height, y + h);

  for (int py = math.max(0, y); py < yEnd; py++) {
    for (int px = math.max(0, x); px < xEnd; px++) {
      final lx = px - x + 0.5;
      final ly = py - y + 0.5;

      double dx = 0, dy = 0;
      if (lx < radius && ly < radius) {
        dx = radius - lx;
        dy = radius - ly;
      } else if (lx > w - radius && ly < radius) {
        dx = lx - (w - radius);
        dy = radius - ly;
      } else if (lx < radius && ly > h - radius) {
        dx = radius - lx;
        dy = ly - (h - radius);
      } else if (lx > w - radius && ly > h - radius) {
        dx = lx - (w - radius);
        dy = ly - (h - radius);
      }

      double distFromEdge;
      if (dx > 0 && dy > 0) {
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > radius + 0.7) continue;
        distFromEdge = radius - d;
      } else {
        distFromEdge = math.min(
          math.min(lx, w - lx),
          math.min(ly, h - ly),
        );
      }

      final outerCov = (distFromEdge + 0.7).clamp(0.0, 1.0);
      List<int> src = fillRgba;
      if (borderRgba != null && distFromEdge < borderWidth) {
        final borderBlend = (borderWidth - distFromEdge).clamp(0.0, 1.0);
        src = [
          (fillRgba[0] * (1 - borderBlend) + borderRgba[0] * borderBlend).round(),
          (fillRgba[1] * (1 - borderBlend) + borderRgba[1] * borderBlend).round(),
          (fillRgba[2] * (1 - borderBlend) + borderRgba[2] * borderBlend).round(),
          255,
        ];
      }

      final alpha = ((src[3] / 255.0) * outerCov).clamp(0.0, 1.0);
      final dst = canvas.getPixel(px, py);
      final dstA = dst.a.toInt() / 255.0;
      final outA = alpha + dstA * (1 - alpha);
      if (outA <= 0) continue;
      final outR = ((src[0] * alpha + dst.r * dstA * (1 - alpha)) / outA).round();
      final outG = ((src[1] * alpha + dst.g * dstA * (1 - alpha)) / outA).round();
      final outB = ((src[2] * alpha + dst.b * dstA * (1 - alpha)) / outA).round();
      canvas.setPixelRgba(px, py, outR, outG, outB, (outA * 255).round());
    }
  }
}

void _placeLogoInRect(
  img.Image canvas,
  img.Image trimmedLogo, {
  required int x,
  required int y,
  required int w,
  required int h,
  int padX = 12,
  int padY = 10,
}) {
  final availW = math.max(1, w - padX * 2);
  final availH = math.max(1, h - padY * 2);
  final scale = math.min(availW / trimmedLogo.width, availH / trimmedLogo.height);
  final tw = math.max(1, (trimmedLogo.width * scale).round());
  final th = math.max(1, (trimmedLogo.height * scale).round());

  final resized = img.copyResize(
    trimmedLogo,
    width: tw,
    height: th,
    interpolation: img.Interpolation.average,
  );

  final dstX = x + (w - tw) ~/ 2;
  final dstY = y + (h - th) ~/ 2;
  img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);
}

img.Image _createBasePlate() {
  final canvas = img.Image(width: _plateW, height: _plateH, numChannels: 4);
  _drawRoundedBox(
    canvas,
    x: 0,
    y: 0,
    w: _plateW,
    h: _plateH,
    radius: 52,
    fillRgba: const [248, 250, 252, 255], // #F8FAFC
    borderRgba: const [220, 228, 238, 255], // crisp subtle slate border
    borderWidth: 4.0,
  );
  return canvas;
}

img.Image _buildSingleBrandPlate(img.Image logo) {
  final canvas = _createBasePlate();
  _drawRoundedBox(
    canvas,
    x: 16,
    y: 16,
    w: _plateW - 32,
    h: _plateH - 32,
    radius: 38,
    fillRgba: const [255, 255, 255, 255],
    borderRgba: const [235, 240, 246, 255],
    borderWidth: 2.5,
  );
  _placeLogoInRect(
    canvas,
    logo,
    x: 16,
    y: 16,
    w: _plateW - 32,
    h: _plateH - 32,
    padX: 46,
    padY: 42,
  );
  return canvas;
}

img.Image _buildSixBrandGridPlate(List<img.Image> logos) {
  assert(logos.length == 6);
  final canvas = _createBasePlate();
  const int outerPad = 14;
  const int gap = 10;
  const int cols = 3;
  const int rows = 2;

  final cellW = (_plateW - outerPad * 2 - gap * (cols - 1)) ~/ cols;
  final cellH = (_plateH - outerPad * 2 - gap * (rows - 1)) ~/ rows;

  for (int i = 0; i < 6; i++) {
    final r = i ~/ cols;
    final c = i % cols;
    final cx = outerPad + c * (cellW + gap);
    final cy = outerPad + r * (cellH + gap);

    _drawRoundedBox(
      canvas,
      x: cx,
      y: cy,
      w: cellW,
      h: cellH,
      radius: 24,
      fillRgba: const [255, 255, 255, 255],
      borderRgba: const [233, 238, 245, 255],
      borderWidth: 2.0,
    );
    _placeLogoInRect(
      canvas,
      logos[i],
      x: cx,
      y: cy,
      w: cellW,
      h: cellH,
      padX: 11,
      padY: 12,
    );
  }
  return canvas;
}

img.Image _buildThreeBrandBentoPlate({
  required img.Image wideTopLeft,
  required img.Image wideBottomLeft,
  required img.Image squareRight,
}) {
  final canvas = _createBasePlate();
  const int outerPad = 14;
  const int gap = 10;
  final totalInnerW = _plateW - outerPad * 2;
  final totalInnerH = _plateH - outerPad * 2;

  final leftW = ((totalInnerW - gap) * 0.59).round();
  final rightW = totalInnerW - gap - leftW;
  final leftCellH = (totalInnerH - gap) ~/ 2;

  // Top-left (PBM)
  _drawRoundedBox(
    canvas,
    x: outerPad,
    y: outerPad,
    w: leftW,
    h: leftCellH,
    radius: 26,
    fillRgba: const [255, 255, 255, 255],
    borderRgba: const [233, 238, 245, 255],
    borderWidth: 2.0,
  );
  _placeLogoInRect(
    canvas,
    wideTopLeft,
    x: outerPad,
    y: outerPad,
    w: leftW,
    h: leftCellH,
    padX: 20,
    padY: 16,
  );

  // Bottom-left (HYDA)
  final botY = outerPad + leftCellH + gap;
  _drawRoundedBox(
    canvas,
    x: outerPad,
    y: botY,
    w: leftW,
    h: totalInnerH - leftCellH - gap,
    radius: 26,
    fillRgba: const [255, 255, 255, 255],
    borderRgba: const [233, 238, 245, 255],
    borderWidth: 2.0,
  );
  _placeLogoInRect(
    canvas,
    wideBottomLeft,
    x: outerPad,
    y: botY,
    w: leftW,
    h: totalInnerH - leftCellH - gap,
    padX: 20,
    padY: 16,
  );

  // Right (RP Steelglass)
  final rightX = outerPad + leftW + gap;
  _drawRoundedBox(
    canvas,
    x: rightX,
    y: outerPad,
    w: rightW,
    h: totalInnerH,
    radius: 26,
    fillRgba: const [255, 255, 255, 255],
    borderRgba: const [233, 238, 245, 255],
    borderWidth: 2.0,
  );
  _placeLogoInRect(
    canvas,
    squareRight,
    x: rightX,
    y: outerPad,
    w: rightW,
    h: totalInnerH,
    padX: 22,
    padY: 22,
  );

  return canvas;
}

void main() async {
  img.Image loadTrimmed(String file) {
    final decoded = img.decodePng(File('$_brandsDir/$file').readAsBytesSync())!;
    return _trimTransparent(decoded);
  }

  final orm = loadTrimmed('brand_orm.png');
  final schimmer = loadTrimmed('brand_schimmer.png');
  final alumet = loadTrimmed('brand_alumet.png');
  final smartplus = loadTrimmed('brand_smartplus.png');
  final uai = loadTrimmed('brand_uai.png');
  final fuji = loadTrimmed('brand_fuji.png');
  final aluframe = loadTrimmed('brand_aluframe.png');
  final pbm = loadTrimmed('brand_pbm.png');
  final hyda = loadTrimmed('brand_hyda.png');
  final rp = loadTrimmed('brand_rp.png');

  final plates = <String, img.Image>{
    // 1. ชุดตลาด -> โลโก้ ALUMET ตามที่ลูกค้ากำหนด
    'cat1_market.png': _buildSingleBrandPlate(alumet),

    // 2. ชุดพัฒนา -> ORM, SMS SCHIMMER, ALUMET, SMART PLUS, UAI, ALUFRAME
    'cat2_pattana.png': _buildSixBrandGridPlate([
      orm,
      schimmer,
      alumet,
      smartplus,
      uai,
      aluframe,
    ]),

    // 3. ชุดยูโรโปรไฟล์ -> ORM, Fuji Eurotech, ALUMET, SMART PLUS, UAI, ALUFRAME
    'cat3_euro.png': _buildSixBrandGridPlate([
      orm,
      fuji,
      alumet,
      smartplus,
      uai,
      aluframe,
    ]),

    // 4. ระบบบานเฟี้ยม -> ORM, Fuji Eurotech, SMS SCHIMMER, SMART PLUS, ALUMET, UAI
    'cat4_folding.png': _buildSixBrandGridPlate([
      orm,
      fuji,
      schimmer,
      smartplus,
      alumet,
      uai,
    ]),

    // 5. บานเปลือย / Shower -> PBM, HYDA, RP Steelglass
    'cat5_shower.png': _buildThreeBrandBentoPlate(
      wideTopLeft: pbm,
      wideBottomLeft: hyda,
      squareRight: rp,
    ),
  };

  for (final e in plates.entries) {
    final outPath = '$_brandsDir/${e.key}';
    final bytes = img.encodePng(e.value, level: 6);
    await File(outPath).writeAsBytes(bytes);
    print('Saved $outPath (${bytes.length} bytes, ${e.value.width}x${e.value.height})');
  }
}
