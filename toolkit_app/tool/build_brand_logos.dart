// ignore_for_file: avoid_print
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _vipAuditDir =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\scratch\vip_audit';
const String _rawLogosDir =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\scratch\raw_brand_logos';
const String _outDir = 'assets/brands';

const int _canvasW = 360;
const int _canvasH = 180;

img.Image _ensureRgba(img.Image src) {
  if (src.numChannels == 4) {
    return src.clone();
  }
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
    }
  }
  return out;
}

bool _isNearWhiteOrLightGrey(int r, int g, int b, {int minLum = 236, int maxSpread = 12}) {
  final hi = math.max(r, math.max(g, b));
  final lo = math.min(r, math.min(g, b));
  final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
  return lum >= minLum && (hi - lo) <= maxSpread;
}

/// Converts all near-white neutral pixels globally to smooth alpha (great for wordmarks).
img.Image _whiteToAlphaGlobal(img.Image input, {int hardWhite = 247, int softStart = 230}) {
  final out = _ensureRgba(input);
  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final a = p.a.toInt();
      if (a == 0) continue;
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final hi = math.max(r, math.max(g, b));
      final lo = math.min(r, math.min(g, b));
      final spread = hi - lo;
      final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;

      if (spread <= 14 && lum >= hardWhite) {
        out.setPixelRgba(x, y, r, g, b, 0);
      } else if (spread <= 18 && lum >= softStart) {
        final ratio = (hardWhite - lum) / (hardWhite - softStart);
        final nextA = (a * ratio.clamp(0.0, 1.0)).round();
        out.setPixelRgba(x, y, r, g, b, nextA);
      }
    }
  }
  return out;
}

/// Flood-fills from image perimeter so enclosed white interiors (e.g. UAI diamond, SMART PLUS frame) remain opaque white.
img.Image _floodTransparentFromBorder(img.Image input) {
  final out = _ensureRgba(input);
  final w = out.width;
  final h = out.height;
  final visited = List<bool>.filled(w * h, false);
  final q = Queue<int>();

  void tryEnqueue(int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final idx = y * w + x;
    if (visited[idx]) return;
    final p = out.getPixel(x, y);
    if (p.a.toInt() == 0 ||
        _isNearWhiteOrLightGrey(p.r.toInt(), p.g.toInt(), p.b.toInt(), minLum: 234, maxSpread: 14)) {
      visited[idx] = true;
      q.add(idx);
    }
  }

  for (int x = 0; x < w; x++) {
    tryEnqueue(x, 0);
    tryEnqueue(x, h - 1);
  }
  for (int y = 0; y < h; y++) {
    tryEnqueue(0, y);
    tryEnqueue(w - 1, y);
  }

  while (q.isNotEmpty) {
    final idx = q.removeFirst();
    final x = idx % w;
    final y = idx ~/ w;
    final p = out.getPixel(x, y);
    out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);

    tryEnqueue(x + 1, y);
    tryEnqueue(x - 1, y);
    tryEnqueue(x, y + 1);
    tryEnqueue(x, y - 1);
  }

  // Soften 1px boundary pixels next to transparent background
  final copy = out.clone();
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final p = copy.getPixel(x, y);
      if (p.a.toInt() == 0) continue;
      int transNeighbors = 0;
      if (copy.getPixel(x + 1, y).a.toInt() == 0) transNeighbors++;
      if (copy.getPixel(x - 1, y).a.toInt() == 0) transNeighbors++;
      if (copy.getPixel(x, y + 1).a.toInt() == 0) transNeighbors++;
      if (copy.getPixel(x, y - 1).a.toInt() == 0) transNeighbors++;
      if (transNeighbors > 0 &&
          _isNearWhiteOrLightGrey(p.r.toInt(), p.g.toInt(), p.b.toInt(), minLum: 215, maxSpread: 22)) {
        out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 90);
      }
    }
  }
  return out;
}

img.Image _trimTransparent(img.Image src) {
  int minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a.toInt() > 12) {
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

img.Image _applyRoundedCorners(img.Image src, double radius) {
  final out = _ensureRgba(src);
  final w = out.width;
  final h = out.height;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double dx = 0, dy = 0;
      if (x < radius && y < radius) {
        dx = radius - x - 0.5;
        dy = radius - y - 0.5;
      } else if (x >= w - radius && y < radius) {
        dx = x - (w - radius) + 0.5;
        dy = radius - y - 0.5;
      } else if (x < radius && y >= h - radius) {
        dx = radius - x - 0.5;
        dy = y - (h - radius) + 0.5;
      } else if (x >= w - radius && y >= h - radius) {
        dx = x - (w - radius) + 0.5;
        dy = y - (h - radius) + 0.5;
      }
      if (dx > 0 && dy > 0) {
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > radius + 0.5) {
          final p = out.getPixel(x, y);
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
        } else if (dist > radius - 0.8) {
          final p = out.getPixel(x, y);
          final factor = ((radius + 0.5 - dist) / 1.3).clamp(0.0, 1.0);
          out.setPixelRgba(
            x,
            y,
            p.r.toInt(),
            p.g.toInt(),
            p.b.toInt(),
            (p.a.toInt() * factor).round(),
          );
        }
      }
    }
  }
  return out;
}

img.Image _placeOnCanvas(
  img.Image trimmed, {
  int maxW = 328,
  int maxH = 152,
}) {
  final scale = math.min(maxW / trimmed.width, maxH / trimmed.height);
  final targetW = math.max(1, (trimmed.width * scale).round());
  final targetH = math.max(1, (trimmed.height * scale).round());

  final resized = img.copyResize(
    trimmed,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: _canvasW, height: _canvasH, numChannels: 4);
  final ox = (_canvasW - targetW) ~/ 2;
  final oy = (_canvasH - targetH) ~/ 2;
  img.compositeImage(canvas, resized, dstX: ox, dstY: oy);
  return canvas;
}

void main() async {
  final outDirectory = Directory(_outDir);
  if (!outDirectory.existsSync()) {
    outDirectory.createSync(recursive: true);
  }

  final cat2Top = img.decodePng(
    await File('$_vipAuditDir/10_cat2_top.png').readAsBytes(),
  )!;

  Future<void> saveLogo(String name, img.Image processed, {int maxW = 324, int maxH = 150}) async {
    final trimmed = _trimTransparent(processed);
    final finalImg = _placeOnCanvas(trimmed, maxW: maxW, maxH: maxH);
    final bytes = img.encodePng(finalImg, level: 6);
    final path = '$_outDir/$name';
    await File(path).writeAsBytes(bytes);
    print('Saved $path (${bytes.length} bytes, trimmed=${trimmed.width}x${trimmed.height})');
  }

  // 1. ORM (from lossless 1216x2640 VIP screenshot)
  final ormCrop = img.copyCrop(cat2Top, x: 142, y: 737, width: 280, height: 168);
  await saveLogo('brand_orm.png', _whiteToAlphaGlobal(ormCrop), maxW: 300, maxH: 130);

  // 2. SMS SCHIMMER (from lossless 1216x2640 VIP screenshot — crisp vector render)
  final schimmerCrop = img.copyCrop(cat2Top, x: 142, y: 1094, width: 280, height: 168);
  await saveLogo('brand_schimmer.png', _whiteToAlphaGlobal(schimmerCrop), maxW: 300, maxH: 144);

  // 3. ALUMET (from official high-res WebP)
  final alumetRaw = img.decodeWebP(
    await File('$_rawLogosDir/alumet_web.webp').readAsBytes(),
  )!;
  await saveLogo('brand_alumet.png', _whiteToAlphaGlobal(alumetRaw), maxW: 326, maxH: 136);

  // 4. SMART PLUS (from lossless 1216x2640 VIP screenshot with border flood-fill)
  final spCrop = img.copyCrop(cat2Top, x: 142, y: 1813, width: 280, height: 168);
  await saveLogo('brand_smartplus.png', _floodTransparentFromBorder(spCrop), maxW: 290, maxH: 154);

  // 5. UAI (from lossless 1216x2640 VIP screenshot with border flood-fill keeping white diamond interior)
  final uaiCrop = img.copyCrop(cat2Top, x: 142, y: 2175, width: 280, height: 168);
  await saveLogo('brand_uai.png', _floodTransparentFromBorder(uaiCrop), maxW: 308, maxH: 154);

  // 6. FUJI METAL (from official high-res WebP)
  final fujiRaw = img.decodeWebP(
    await File('$_rawLogosDir/fuji_web.webp').readAsBytes(),
  )!;
  await saveLogo('brand_fuji.png', _whiteToAlphaGlobal(fujiRaw), maxW: 290, maxH: 158);

  // 7. ALUFRAME (from official Thai Aluwork PNG)
  final aluframeRaw = img.decodePng(
    await File('$_rawLogosDir/aluframe_raw.png').readAsBytes(),
  )!;
  await saveLogo('brand_aluframe.png', _whiteToAlphaGlobal(aluframeRaw), maxW: 316, maxH: 118);

  // 8. PBM (from official PBM PNG — preserve white letters inside blue circle!)
  final pbmRaw = img.decodePng(
    await File('$_rawLogosDir/pbm_raw.png').readAsBytes(),
  )!;
  await saveLogo('brand_pbm.png', _floodTransparentFromBorder(pbmRaw), maxW: 332, maxH: 136);

  // 9. HYDA (from official HYDA WebP)
  final hydaRaw = img.decodeWebP(
    await File('$_rawLogosDir/hyda_raw.webp').readAsBytes(),
  )!;
  await saveLogo('brand_hyda.png', _whiteToAlphaGlobal(hydaRaw), maxW: 324, maxH: 136);

  // 10. RP Steelglass (from official RP Steelglass square emblem PNG, rounded corners)
  final rpRaw = img.decodePng(
    await File('$_rawLogosDir/rp_raw1.png').readAsBytes(),
  )!;
  final rpRounded = _applyRoundedCorners(_trimTransparent(_ensureRgba(rpRaw)), 28.0);
  await saveLogo('brand_rp.png', rpRounded, maxW: 162, maxH: 162);

  print('Successfully generated all 10 manufacturer brand logos!');
}
