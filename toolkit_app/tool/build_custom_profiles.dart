// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _srcPath =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\.user_uploaded\media_1794999548522_f89e7911.jpg';
const String _outDir = 'assets/profiles';

void main() async {
  final dir = Directory(_outDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final srcBytes = await File(_srcPath).readAsBytes();
  final decoded = img.decodeImage(srcBytes)!;
  print('Loaded customer SS-X219 image: ${decoded.width}x${decoded.height}');

  final work = decoded.clone();
  final w = work.width;
  final h = work.height;

  // Mask out the clipped right-edge text ("SS-", "เสาก", "ร่อง", "สมา")
  // which sits in x >= 85% and y in [15%..46%], preserving all CAD lines & "7.2" at bottom-right.
  final maskXStart = (w * 0.855).round();
  final maskYStart = (h * 0.14).round();
  final maskYEnd = (h * 0.46).round();
  for (int y = maskYStart; y <= maskYEnd && y < h; y++) {
    for (int x = maskXStart; x < w; x++) {
      work.setPixelRgb(x, y, 255, 255, 255);
    }
  }

  // Normalize near-white JPEG background pixels (>= 246) to pure crisp #FFFFFF
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = work.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (lum >= 246) {
        work.setPixelRgb(x, y, 255, 255, 255);
      } else if (lum < 235) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  final cropped = img.copyCrop(
    work,
    x: math.max(0, minX - 8),
    y: math.max(0, minY - 8),
    width: math.min(w - math.max(0, minX - 8), (maxX - minX) + 17),
    height: math.min(h - math.max(0, minY - 8), (maxY - minY) + 17),
  );

  // Resize to crisp high-DPI height (640 px) and center on clean white 520x680 canvas
  const targetMaxH = 632;
  final scale = math.min(1.0, targetMaxH / cropped.height);
  final rw = (cropped.width * scale).round();
  final rh = (cropped.height * scale).round();
  final resized = scale < 1.0
      ? img.copyResize(cropped, width: rw, height: rh, interpolation: img.Interpolation.cubic)
      : cropped;

  final canvasW = math.max(resized.width + 64, (resized.height * 0.78).round());
  final canvasH = resized.height + 48;
  final canvas = img.Image(width: canvasW, height: canvasH);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(
    canvas,
    resized,
    dstX: (canvasW - resized.width) ~/ 2,
    dstY: (canvasH - resized.height) ~/ 2,
  );

  final outPng = img.encodePng(canvas, level: 6);
  final outPath = '$_outDir/ss_x219.png';
  await File(outPath).writeAsBytes(outPng);
  print('Saved $outPath (${canvasW}x$canvasH, ${outPng.length} bytes)');
}
