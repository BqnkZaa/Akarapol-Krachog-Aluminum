// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/models/app_models.dart';

const String _outputsDir =
    r'C:\Users\ayumg\.gemini\antigravity\brain\e96a7de5-9a54-42b4-b7f2-ed54af4f20d0\browser_sandbox\outputs';
const String _backupAssetsDir =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\scratch\alupro_existing_backup';
const String _glassDownloadPath =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\browser_sandbox\downloads\glass.jpg';

const List<int> _processStepNums = [
  245, 250, 252, 256, 260, 262, 264, 266, 268, 270, 272, 274, 276, 278, 282, 379,
];
const List<int> _homeStepNums = [
  289, 291, 293, 295, 297, 299, 301, 303, 305, 307, 309, 311, 313, 315, 317, 319, 324, 326, 328, 330, 332,
];

class _FoldingDiagramEntry {
  final String cat;
  final String jid;
  final String name;
  final String hash;
  final int n;
  final int l;
  final int r;

  const _FoldingDiagramEntry({
    required this.cat,
    required this.jid,
    required this.name,
    required this.hash,
    required this.n,
    required this.l,
    required this.r,
  });
}

Uint8List _decodeDataUri(String dataUri) {
  final idx = dataUri.indexOf('base64,');
  final b64 = idx >= 0 ? dataUri.substring(idx + 7) : dataUri;
  return base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
}

/// Finds a clean pure-white horizontal row separating the window/door diagram
/// from the bottom brand/series watermark strip, wipes everything below that row
/// to `#FFFFFF`, and composites the official ALUMET or ICONIQ badge cleanly.
img.Image _rebrandAlumetPatternDiagram({
  required img.Image source,
  required img.Image badgeCrop,
  required int badgeDstX,
  required int badgeDstY,
}) {
  // Normalize canvas to 240x168 white if source width differs (e.g. 195x168)
  final canvas = img.Image(width: 240, height: 168);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  // Find white separator row in source between y=112..148
  int? splitY;
  for (int y = 112; y <= 148 && y < source.height; y++) {
    bool allWhite = true;
    for (int x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      if (p.r < 242 || p.g < 242 || p.b < 242) {
        allWhite = false;
        break;
      }
    }
    if (allWhite) {
      splitY = y;
      break;
    }
  }
  if (splitY == null) {
    throw StateError(
      'Could not find pure-white separator row between diagram and watermark (${source.width}x${source.height})',
    );
  }

  final offsetX = ((240 - source.width) / 2).round();
  for (int y = 0; y < splitY; y++) {
    for (int x = 0; x < source.width; x++) {
      final dx = x + offsetX;
      if (dx >= 0 && dx < 240) {
        final p = source.getPixel(x, y);
        canvas.setPixelRgb(dx, y, p.r, p.g, p.b);
      }
    }
  }

  // Copy badgeCrop into bottom-right
  for (int y = 0; y < badgeCrop.height; y++) {
    final dy = badgeDstY + y;
    if (dy < 0 || dy >= 168) continue;
    for (int x = 0; x < badgeCrop.width; x++) {
      final dx = badgeDstX + x;
      if (dx < 0 || dx >= 240) continue;
      final p = badgeCrop.getPixel(x, y);
      canvas.setPixelRgb(dx, dy, p.r, p.g, p.b);
    }
  }
  return canvas;
}

void main() async {
  final rawImagesByHash = <String, Uint8List>{};
  final processCodeToHash = <String, String>{};
  final homeItems = <Map<String, dynamic>>[];
  final jidToHash = <String, String>{};

  // 0. Seed rawImagesByHash from existing assets/alupro and backup folder so
  //    earlier step_241 / step_243 (ชุดตลาด) CAD & hardware JPEGs are preserved!
  for (final dirPath in [_backupAssetsDir, 'assets/alupro']) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.jpg') || name == 'glass.jpg') continue;
      final stem = name.substring(0, name.length - 4);
      if (stem.contains('_')) continue; // skip stamped variants
      final bytes = f.readAsBytesSync();
      if (bytes.length > 500) {
        rawImagesByHash.putIfAbsent(stem, () => bytes);
      }
    }
  }

  // 1. Load extracted process.php outputs (ONLY exact 1:1 profile CAD cross-sections)
  const nonProfileHardwareWords = {
    'Anti-Strike',
    'Anti-Theft',
    'Auxiliary',
    'Spigot',
    'CDQ20',
  };
  final gluedRodRegex = RegExp(r'^([0-9]{5})(?:Transmission|Connecting)\b');
  final codeRegex = RegExp(
    r'^([A-Za-z0-9]+(?:-[A-Za-z0-9.]+)*)\s*[ก-๙A-Za-z(]',
  );

  for (final step in _processStepNums) {
    final f = File('$_outputsDir/step_$step.json');
    if (!f.existsSync()) {
      throw StateError('Missing process output file: ${f.path}');
    }
    final root = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final val = root['value'] as Map<String, dynamic>;
    final images = (val['images'] as Map<String, dynamic>?) ?? {};
    for (final e in images.entries) {
      final bytes = _decodeDataUri(e.value as String);
      if (bytes.length > 500) {
        rawImagesByHash[e.key] = bytes;
      }
    }
    final rows = (val['rows'] as List<dynamic>?) ?? [];
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final h = (m['imgHash'] as String? ?? '').trim();
      final rawText = (m['rawText'] as String? ?? '').trim();
      if (h.isEmpty || !rawImagesByHash.containsKey(h)) continue;

      String? extractedCode;
      final rodMatch = gluedRodRegex.firstMatch(rawText);
      if (rodMatch != null) {
        extractedCode = rodMatch.group(1)!.trim();
      } else {
        final match = codeRegex.firstMatch(rawText);
        if (match != null) {
          extractedCode = match.group(1)!.trim();
        }
      }
      if (extractedCode != null &&
          extractedCode.length >= 4 &&
          !extractedCode.startsWith('ขนาด') &&
          !nonProfileHardwareWords.contains(extractedCode)) {
        processCodeToHash.putIfAbsent(extractedCode, () => h);
      }
    }
  }

  // 2. Load extracted home.php outputs (Window/Door/Folding pattern diagrams)
  for (final step in _homeStepNums) {
    final f = File('$_outputsDir/step_$step.json');
    if (!f.existsSync()) {
      throw StateError('Missing home output file: ${f.path}');
    }
    final root = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final val = root['value'] as Map<String, dynamic>;
    final images = (val['images'] as Map<String, dynamic>?) ?? {};
    for (final e in images.entries) {
      final bytes = _decodeDataUri(e.value as String);
      if (bytes.length > 500) {
        rawImagesByHash[e.key] = bytes;
      }
    }
    final items = (val['items'] as List<dynamic>?) ?? [];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final h = (m['hash'] as String? ?? '').trim();
      final jid = (m['jid'] as String? ?? '').trim();
      if (h.isNotEmpty && rawImagesByHash.containsKey(h)) {
        homeItems.add(m);
        if (jid.isNotEmpty) {
          jidToHash[jid] = h;
        }
      }
    }
  }

  print('Loaded ${rawImagesByHash.length} valid unique AluProSmart images.');
  print('Exact verified profile CAD codes: ${processCodeToHash.length}; pattern jids: ${jidToHash.length}.');

  final missingJids = <String>{};
  String jidHash(String jid) {
    final h = jidToHash[jid];
    if (h == null) {
      missingJids.add(jid);
      return '';
    }
    return h;
  }

  // Parse all folding diagrams from homeItems (strictly skipping AluProSmart's
  // mislabeled g04b0105 / g04b0106 which contain '240-3R' inside the image!)
  const mislabeledAluproFoldingJids = {'g04b0105', 'g04b0106'};
  final foldingEntries = <_FoldingDiagramEntry>[];
  for (final it in homeItems) {
    final cat = it['cat'] as String? ?? '';
    if (!cat.contains('b0')) continue;
    final jid = it['jid'] as String? ?? '';
    if (mislabeledAluproFoldingJids.contains(jid)) continue;
    final name = it['name'] as String? ?? '';
    final hash = it['hash'] as String;

    int? n, l, r;
    final hyphenMatch = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{1,2})').firstMatch(name);
    final fourDigitMatch = RegExp(r'บานเฟี้ยม(?:ล้อล่าง)?\s*(1\d)(\d)(\d)').firstMatch(name);
    final threeDigitMatch = RegExp(r'บานเฟี้ยม(?:ล้อล่าง)?\s*(\d)(\d)(\d)').firstMatch(name);

    if (hyphenMatch != null) {
      n = int.parse(hyphenMatch.group(1)!);
      l = int.parse(hyphenMatch.group(2)!);
      r = int.parse(hyphenMatch.group(3)!);
    } else if (fourDigitMatch != null) {
      final candN = int.parse(fourDigitMatch.group(1)!);
      final candL = int.parse(fourDigitMatch.group(2)!);
      final candR = int.parse(fourDigitMatch.group(3)!);
      if (candL + candR == candN) {
        n = candN;
        l = candL;
        r = candR;
      }
    } else if (threeDigitMatch != null) {
      final candN = int.parse(threeDigitMatch.group(1)!);
      final candL = int.parse(threeDigitMatch.group(2)!);
      final candR = int.parse(threeDigitMatch.group(3)!);
      if (candL + candR == candN) {
        n = candN;
        l = candL;
        r = candR;
      }
    }
    if (n != null && l != null && r != null) {
      foldingEntries.add(
        _FoldingDiagramEntry(
          cat: cat,
          jid: jid,
          name: name,
          hash: hash,
          n: n,
          l: l,
          r: r,
        ),
      );
    }
  }
  print('Parsed ${foldingEntries.length} verified folding diagrams across brands.');

  // STRICT SAME-BRAND & EXACT (n, l, r) ONLY! Zero cross-brand or mirror borrowing!
  String? resolveFoldingHash(String family, int n, int l, int r) {
    final preferredCat = switch (family) {
      'orm90' || 'orm101' => 'g08b01',
      'fuji_std' || 'fuji_u' => 'u09b01',
      'sch240' => 'g04b01',
      'sp_fold' => 'u04b01',
      'alu_fold' => 'g02b01',
      _ => '',
    };
    if (preferredCat.isEmpty) return null;

    for (final e in foldingEntries) {
      if (e.cat == preferredCat && e.n == n && e.l == l && e.r == r) {
        return e.hash;
      }
    }
    return null;
  }

  final brandAssets = <String, String>{
    'c2_orm': 'assets/brands/brand_orm.png',
    'c2_schimmer': 'assets/brands/brand_schimmer.png',
    'c2_alumet': 'assets/brands/brand_alumet.png',
    'c2_smartplus': 'assets/brands/brand_smartplus.png',
    'c2_uai': 'assets/brands/brand_uai.png',
    'c2_aluframe_dis': 'assets/brands/brand_aluframe.png',
    'c3_orm_pano': 'assets/brands/brand_orm.png',
    'c3_fuji': 'assets/brands/brand_fuji.png',
    'c3_alumet_iconiq': 'assets/brands/brand_alumet.png',
    'c3_smartplus_euro': 'assets/brands/brand_smartplus.png',
    'c3_uai_euro_dis': 'assets/brands/brand_uai.png',
    'c3_aluframe_euro': 'assets/brands/brand_aluframe.png',
    'c4_orm_fold': 'assets/brands/brand_orm.png',
    'c4_fuji_fold': 'assets/brands/brand_fuji.png',
    'c4_schimmer_fold': 'assets/brands/brand_schimmer.png',
    'c4_smartplus_fold': 'assets/brands/brand_smartplus.png',
    'c4_alumet_fold': 'assets/brands/brand_alumet.png',
    'c4_uai_fold_dis': 'assets/brands/brand_uai.png',
    'c5_pbm_dis': 'assets/brands/brand_pbm.png',
    'c5_hyda_dis': 'assets/brands/brand_hyda.png',
    'c5_rp_dis': 'assets/brands/brand_rp.png',
  };

  // STRICT 100% SAME-BRAND & EXACT-LAYOUT PATTERN JIDs ONLY!
  final explicitPatternJids = <String, String>{
    // Category 1: ชุดตลาด (g01* ONLY)
    'c1_pat_s2_alt': 'g01s0101',
    'c1_pat_s2_1s1f': 'g01s0116',
    'c1_pat_s4_ctr': 'g01s0201',
    'c1_dis_s3': 'g01s0301',
    'c1_dis_s2_top': 'g01s0105',
    'c1_dis_s2_bot': 'g01s0103',
    'c1_dis_s4_top': 'g01s0203',
    'c1_dis_s4_bot': 'g01s0204',
    'c1_pat_swing1': 'g01w0101',
    'c1_pat_swing2': 'g01w0103',
    'c1_pat_hang1': 'g01h0101',
    'c1_pat_hang2': 'g01h0106',
    'c1_pat_union_case1': 'g01c0126',
    'c1_pat_union_awn1': 'g01c0104',

    // Category 2: ORM Asian Trop (g08* ONLY)
    'c2_orm_s2_card': 'g08s0201',
    'c2_orm_s2_top_card': 'g08s0403',
    'c2_orm_s2_bot_card': 'g08s0407',
    'c2_orm_s4_card': 'g08s0204',
    'c2_orm_s4_top_card': 'g08s0411',
    'c2_orm_s4_bot_card': 'g08s0415',
    'c2_orm_case1_card': 'g08c0101',
    'c2_orm_case1_bot_card': 'g08c0106',
    'c2_orm_case_div2_card': 'g08c0102',
    'c2_orm_case_div3_card': 'g08c0109',
    'c2_orm_case_div4_card': 'g08c0118',
    'c2_orm_fix1_card': 'g08f0101',
    'c2_orm_wood1_card': 'g08o0101',
    'c2_orm_wood2_dis': 'g08o0102',

    // Category 2: SMS SCHIMMER (g04* ONLY)
    'c2_sch_200_001_card': 'g04s0201',
    'c2_sch_200_002_card': 'g04s0202',
    'c2_sch_200_004_card': 'g04s0205',
    'c2_sch_200_005_card': 'g04s0203',
    'c2_sch_200_006_card': 'g04s0206',
    'c2_sch_200_008_card': 'g04s0208',
    'c2_sch_200_010_card': 'g04s0210',
    'c2_sch_200_011_card': 'g04s0211',
    'c2_sch_200_012_card': 'g04s0212',
    'c2_sch_250_002_card': 'g04o0101',
    'c2_sch_250_004_card': 'g04o0104',
    'c2_sch_260_001_card': 'g04c0201',
    'c2_sch_260_cm_card': 'g04c0203',
    'c2_sch_260_fm_card': 'g04c0202',
    'c2_sch_260_nm_card': 'g04c0204',

    // Category 2: ALUMET Smart X (g02* ONLY — normalized with pure ALUMET logo!)
    'c2_alu_s2_card': 'g02s0104',
    'c2_alu_s2_top_card': 'g02s0308',
    'c2_alu_s3_card': 'g02s0201',
    'c2_alu_s4_card': 'g02s0101',
    'c2_alu_s4_top_card': 'g02s0102',
    'c2_alu_win1_card': 'g02c0201',
    'c2_alu_win3_card': 'g02c0207',
    'c2_alu_win4_card': 'g02c0101',
    'c2_alu_win5_card': 'g02c0106',
    'c2_alu_win6_card': 'g02c0102',
    'c2_alu_win7_card': 'g02c0107',
    'c2_alu_d1_card': 'g02o0101',
    'c2_alu_d2_card': 'g02o0105',
    'c2_alu_fix1_dis': 'g02f0101',
    'c2_alu_fix2_dis': 'g02f0102',
    'c2_alu_fix3_dis': 'g02f0103',

    // Category 2: SMART PLUS Semi Euro (u04* ONLY)
    'c2_sp_s2_card': 'u04s0103',
    'c2_sp_s4_card': 'u04s0104',
    'c2_sp_s3_card': 'u04s0101',
    'c2_sp_s2_sec_card': 'u04s0103',
    'c2_sp_case1_card': 'u04c0201',
    'c2_sp_awn1_card': 'u04c0101',

    // Category 2: UAI Super Frame (u06* ONLY)
    'c2_uai_s2_card': 'u06s0101',
    'c2_uai_s3_dis': 'u06s0205',
    'c2_uai_s4_card': 'u06s0201',
    'c2_uai_24_1': 'u06c0101',
    'c2_uai_24_2': 'u06c0201',
    'c2_uai_24_3': 'u06c0209',
    'c2_uai_25_4': 'u06s0102',
    'c2_uai_25_5': 'u06s0103',

    // Category 3: ORM Pano Suit (g08* ONLY)
    'c3_orm_s2_card': 'g08s0105',
    'c3_orm_s3_card': 'g08s0104',
    'c3_orm_s4_ctr_card': 'g08s0102',
    'c3_orm_s4_1w_card': 'g08s0103',
    'c3_orm_case1_card': 'g08c0110',
    'c3_orm_case2_dis': 'g08c0111',
    'c3_orm_awn1_card': 'g08c0202',
    'c3_orm_awn2_dis': 'g08c0102',

    // Category 3: Fuji Eurotech (u09* ONLY)
    'c3_fuji_s2_card': 'u09s0101',
    'c3_fuji_s3_card': 'u09s0105',
    'c3_fuji_s4_ctr_card': 'u09s0102',
    'c3_fuji_4t_int_card': 'u09s0106',
    'c3_fuji_5t_int_card': 'u09s0107',
    'c3_fuji_s4_2t_card': 'u09s0102',
    'c3_fuji_s4_3t_card': 'u09s0104',
    'c3_fuji_s5_card': 'u09s0107',
    'c3_fuji_w1_card': 'u09c0101',
    'c3_fuji_w2_card': 'u09c0102',
    'c3_fuji_w1_mosq_card': 'u09c0201',
    'c3_fuji_w1_bot_card': 'u09c0111',
    'c3_fuji_w2_bot_card': 'u09c0112',
    'c3_fuji_d_dis1': 'u09o0101',
    'c3_fuji_f_dis1': 'u09f0101',
    'c3_fuji_f_dis2': 'u09f0102',
    'c3_fuji_f_dis3': 'u09f0103',
    'c3_fuji_f_dis4': 'u09f0104',

    // Category 3: ALUMET Iconiq Euro (g02* ONLY — normalized with ALUMET ICONIQ EURO SERIES!)
    'c3_alu_s2_card': 'g02s0301',
    'c3_alu_s2_in_mosq_card': 'g02s0203',
    'c3_alu_s2_top_card': 'g02s0308',
    'c3_alu_s3_card': 'g02s0302',
    'c3_alu_s4_ctr_card': 'g02s0303',
    'c3_alu_s4_ctr_top_card': 'g02s0306',
    'c3_alu_awn1_card': 'g02c0101',
    'c3_alu_awn1_bot_card': 'g02c0111',
    'c3_alu_case1_card': 'g02c0201',
    'c3_alu_d1_card': 'g02o0101',
    'c3_alu_d2_card': 'g02o0105',
    'c3_alu_fix1_dis': 'g02f0101',
    'c3_alu_fix2_dis': 'g02f0102',

    // Category 3: SMART PLUS Euro (u04* ONLY)
    'c3_sp_s2_2t_card': 'u04s0201',
    'c3_sp_s4_2t_card': 'u04s0202',
    'c3_sp_s2_3t_45_card': 'u04s0201',
    'c3_sp_s3_3t_euro_card': 'u04s0203',
    'c3_sp_s4_3t_45_card': 'u04s0202',
    'c3_sp_s4_4t_card': 'u04s0202',
    'c3_sp_s2_3t_sec_card': 'u04s0201',
    'c3_sp_s4_3t_sec_card': 'u04s0202',
    'c3_sp_90_s2_card': 'u04s0204',
    'c3_sp_90_s3_card': 'u04s0203',
    'c3_sp_90_s4_card': 'u04s0205',
    'c3_sp_win2_card': 'u04c0202',
    'c3_sp_w_sec1_dis': 'u04c0201',
    'c3_sp_w_sec2_dis': 'u04c0202',
    'c3_sp_w_sec3_dis': 'u04c0101',
    'c3_sp_w_fix_dis': 'u04f0102',
    'c3_sp_door1_card': 'u04o0105',
    'c3_sp_door2_card': 'u04o0103',

    // Category 3: ALUFRAME Euro (u08* ONLY)
    'c3_af_s2_card': 'u08s0301',
    'c3_af_s3_card': 'u08s0303',
    'c3_af_s4_ctr_card': 'u08s0302',
    'c3_af_s4_std_card': 'u08s0302',
    'c3_af_s6_ctr_card': 'u08s0304',
    'c3_af_s4_flush_card': 'u08s0302',
    'c3_af_w1_card': 'u08c0301',
    'c3_af_w1_top_card': 'u08c0303',
    'c3_af_case2_card': 'u08c0409',
    'c3_af_case2_top_card': 'u08c0411',
    'c3_af_awn2_card': 'u08c0309',
    'c3_af_awn2_top_card': 'u08c0311',

    // Category 4: SMS SCHIMMER Folding (g04* ONLY — verified exact panel labels)
    'c4_sch_2l_card': 'g04b0101',
    'c4_sch_3_3l_card': 'g04b0103',
    'c4_sch_4_1l3r_card': 'g04b0109',
    'c4_sch_4_2l2r_card': 'g04b0111',
    'c4_sch_4_4l_card': 'g04b0107',
  };

  // Enforce compile-time brand-prefix guard on every explicit JID!
  String expectedJidPrefixForBrand(String brandId) {
    if (brandId == 'market') return 'g01';
    if (brandId.contains('orm')) return 'g08';
    if (brandId.contains('schimmer')) return 'g04';
    if (brandId.contains('alumet')) return 'g02';
    if (brandId.contains('smartplus')) return 'u04';
    if (brandId.contains('uai')) return 'u06';
    if (brandId.contains('fuji')) return 'u09';
    if (brandId.contains('aluframe')) return 'u08';
    throw StateError('Unknown brandId: $brandId');
  }

  // Extract official ALUMET & ALUMET ICONIQ EURO SERIES watermark crops
  final alumetRefImg = img.decodeImage(rawImagesByHash[jidHash('g02s0101')]!)!;
  final alumetBadgeCrop = img.copyCrop(
    alumetRefImg,
    x: 142,
    y: 135,
    width: 98,
    height: 33,
  );
  final iconiqRefImg = img.decodeImage(rawImagesByHash[jidHash('g02s0301')]!)!;
  final iconiqBadgeCrop = img.copyCrop(
    iconiqRefImg,
    x: 84,
    y: 135,
    width: 156,
    height: 33,
  );

  final patternFiles = <String, String>{};
  final referencedPlainHashes = <String>{};
  final generatedCustomJpegs = <String, Uint8List>{};

  String registerAlumetVariant(String rawHash, {required bool isIconiq}) {
    final variantKey = isIconiq ? '${rawHash}_iconiq' : '${rawHash}_alumet';
    final fileName = '$variantKey.jpg';
    if (!generatedCustomJpegs.containsKey(fileName)) {
      final src = img.decodeImage(rawImagesByHash[rawHash]!)!;
      final stamped = _rebrandAlumetPatternDiagram(
        source: src,
        badgeCrop: isIconiq ? iconiqBadgeCrop : alumetBadgeCrop,
        badgeDstX: isIconiq ? 84 : 142,
        badgeDstY: 135,
      );
      generatedCustomJpegs[fileName] = Uint8List.fromList(
        img.encodeJpg(stamped, quality: 88),
      );
    }
    return fileName;
  }

  void registerPattern(String brandId, PatternCardDef p) {
    final expPrefix = expectedJidPrefixForBrand(brandId);
    String? resolvedHash;
    if (explicitPatternJids.containsKey(p.id)) {
      final jid = explicitPatternJids[p.id]!;
      if (!jid.startsWith(expPrefix)) {
        throw StateError(
          'CROSS-BRAND VIOLATION: ${p.id} in $brandId mapped to $jid (expected $expPrefix*)',
        );
      }
      resolvedHash = jidHash(jid);
    } else if (p.foldingFamily != null &&
        p.foldingTotalPanels != null &&
        p.foldingLeftPanels != null &&
        p.foldingRightPanels != null) {
      resolvedHash = resolveFoldingHash(
        p.foldingFamily!,
        p.foldingTotalPanels!,
        p.foldingLeftPanels!,
        p.foldingRightPanels!,
      );
    }

    if (resolvedHash == null || resolvedHash.isEmpty) {
      return; // Cleanly omit thumbnail when brand lacks this exact diagram
    }

    if (brandId == 'c2_alumet' || brandId == 'c4_alumet_fold') {
      patternFiles[p.id] = registerAlumetVariant(resolvedHash, isIconiq: false);
    } else if (brandId == 'c3_alumet_iconiq') {
      patternFiles[p.id] = registerAlumetVariant(resolvedHash, isIconiq: true);
    } else {
      referencedPlainHashes.add(resolvedHash);
      patternFiles[p.id] = '$resolvedHash.jpg';
    }
  }

  void walkSystem(String brandId, SubSystemDef sys) {
    for (final p in sys.patterns) {
      registerPattern(brandId, p);
    }
    for (final tab in sys.subTabs) {
      walkSystem(brandId, tab);
    }
  }

  for (final cat in CatalogDefinitions.categories) {
    for (final sys in cat.directSystems) {
      walkSystem('market', sys);
    }
    for (final brand in cat.brands) {
      if (!brandAssets.containsKey(brand.id)) {
        throw StateError('Unmapped BrandDef: ${brand.id}');
      }
      for (final p in brand.directPatterns) {
        registerPattern(brand.id, p);
      }
      for (final sys in brand.systems) {
        walkSystem(brand.id, sys);
      }
    }
  }

  // 4. STRICT 1:1 Profile CAD Cross-Sections ONLY!
  //    (Exact AluProSmart codes + verified customer overrides + Cat 1 ชุดตลาด standard profiles)
  final profileCodeHashes = <String, String>{
    ...processCodeToHash,

    // Verified customer CAD overrides
    'SS-X219': 'assets/profiles/ss_x219.png',

    // Category 1 (ชุดตลาด) standard generic Thai profile names ONLY
    'เฟรมบนไม่ติดกล่อง': 'ce723f4b',
    'เฟรมล่างไม่ติดกล่อง': 'fdc611ed',
    'เฟรมข้างไม่ติดกล่อง': '322020dc',
    'เฟรมบนติดกล่อง': '200a1410',
    'เฟรมล่างติดกล่อง': '5b29947c',
    'เฟรมข้างติดกล่อง': 'e7e43ce3',
    'เสากุญแจ': '685151f2',
    'เสากุญแจบานเลื่อน (เสาตั้ง)': '685151f2',
    'เสาเกี่ยว': '1f65d563',
    'เสาตาย': '74fbffe6',
    'กรอบบานขวางบน': 'bd4877e5',
    'ขวางบน / ขวางล่าง': 'bd4877e5',
    'กรอบบานขวางล่าง': '20474a68',
    'ฉากข้อต่อ': '3c052cea',
    'กล่องเรียบ': '13596996',
    'กล่องเรียบแนวตั้ง': '13596996',
    'กล่องเรียบแนวขวางล่าง': '13596996',
    'กล่องเรียบแนวขวางบน': '13596996',
    'เสาวงกบ (กล่องเรียบ)': '13596996',
    'เสาวงกบ (กล่องกุญแจ/กล่องเรียบ)': '13596996',
    'ขวางวงกบบน': '13596996',
    'ธรณีสวิง (วงกบล่าง)': '13596996',
    'กล่องแบ็คสั้น (วงกบบน)': 'c7bbe247',
    'ฝาแบ็คสั้น': '13d7f8b6',
    'เสากุญแจบานสวิง (เสาตั้ง)': 'caf718b1',
    'เสาบานสวิง (เสาตั้ง)': 'caf718b1',
    'ขวางบนบานสวิง': 'dd60aea4',
    'ขวางล่างบานสวิง': '7c70853b',
    'คิ้วสวิง': 'bbbc793a',
    'กล่อง 1.6 นิ้ว ตั้ง / เสาข้างวงกบ': 'bb6f3c77',
    'กล่อง 1.6 นิ้ว นอน / วงกบบน': 'bb6f3c77',
    'รางแขวนบน (รางแขวนใหญ่)': '1d9819d2',
    'รางแขวนบน (กล่องรางแขวน)': '1d9819d2',
    'กรอบนอกยูเนี่ยน': '2cfa5183',
    'กรอบในยูเนี่ยน': '2fe28be0',
    'คิ้วยูเนี่ยน': '68b6b5fd',
  };

  // 5. Hardware Code & Keyword Rules (cleaned of brand-mismatched catch-alls)
  final hardwareCodeHashes = <String, String>{
    'HD-929-2': '1be83179',
    'HD-929-4': '1be83179',
    '050-1520-2': '1be83179',
    '01-002': 'cdc046ef',
    '01-003': 'cdc046ef',
    'HD-640': '9ddf6d4d',
    'HD-640A': '9ddf6d4d',
    'HD-640B': '9ddf6d4d',
    '05-006': '57eb29b1',
    '05-007': '57eb29b1',
    '05-008': '9ddf6d4d',
    '05-009': '9ddf6d4d',
    'HD-643': '48de300e',
    'HD-643A': '48de300e',
    'HD-643B': '48de300e',
    'HD-642': '05a6a3f6',
    '05-004': '05a6a3f6',
    'HD-641': 'adf52c7e',
    'HD-474': '2c4b8130',
    'HD-320': '120c52ff',
    'HD-312': '120c52ff',
    'HD-305': '120c52ff',
    '00-019': '120c52ff',
    'HD-622': '8571b905',
    'HD-626': '185ae7a2',
    'HD-453': 'b8e27ded',
    'HD-481A': '3fa25e09',
    '00-024': '3fa25e09',
    'HD-414': '120c52ff',
    'HD-414D': '120c52ff',
    'HD-414-C2': '120c52ff',
    'HD-414-B': '120c52ff',
    '00-001': '3fa25e09',
    '00-030': '120c52ff',
    '00-031': '120c52ff',
    'HD-851': '62d17139',
    'HD-310': 'acfb50ec',
    'HD-321': 'acfb50ec',
    'HD-342': '62d17139',
    'HD-801': '78bb471c',
    'HD-1103': 'a2dff7cd',
    'HD-1176A': 'a2dff7cd',
    'HD-1176B': 'a2dff7cd',
    'HD-1102': 'ccee5a6a',
    'HD-1104': '1c985c62',
    'HD-1105': '1c985c62',
    'ICONIQ_LOCKING_PINS': '1c985c62',
    'HD-1100': 'e079d11e',
    'HD-1101': 'e079d11e',
    'HD-1115': 'e079d11e',
    'HD-1126': 'a528b55a',
    'HD-1129B': '70cf2d93',
    'HD-348C': '70cf2d93',
    'ICONIQ_U_RECEIVERS': 'a528b55a',
    'B24010': 'bcb3e414',
    '04-016': 'bcb3e414',
    '04-025': '3869df86',
    'HD-214': '96d3fc97',
    '04-014': '96d3fc97',
    'HD-200': 'e6682e73',
    'HD-200A': 'e6682e73',
    'HD-1180': 'e6682e73',
    '02-001': 'e6682e73',
    '02-002': 'e6682e73',
    'HD-1025A': '28f6d3f5',
    'HD-1021': '54034218',
    'HD-1022': '54034218',
    'HD-1030': '1d3b2535',
    'HD-1033B': '1d3b2535',
    'HD-1015': 'b8784b6d',
    'HD-1035A': 'b8784b6d',
    '02-037': 'b8784b6d',
    '04-001': '3cdbf139',
    '04-011': '3cdbf139',
    '04-029': '3cdbf139',
    'HD-1250': 'a283261c',
    '02-028': 'a283261c',
    '02-036': 'db5db97a',
    '02-021': 'e2082b9c',
    '02-027': '4d026bd7',
    '02-030': '4d026bd7',
    '02-034': '4d026bd7',
    '02-015': '5f899ed0',
    '02-016': '5f899ed0',
    '02-025': '5f899ed0',
    '02-035': '5f899ed0',
    'MS-2000': '523d300c',
    'KL-MS 7016': '523d300c',
    '3Di': '1a364c38',
  };

  final hardwareKeywordRules = <Map<String, String>>[
    {'kw': 'ล้อรางแขวน', 'hash': 'c11263cf'},
    {'kw': 'ล้อตลับ', 'hash': '1be83179'},
    {'kw': 'ลูกล้อตลับ', 'hash': '1be83179'},
    {'kw': 'ล๊อตตัว', 'hash': '1be83179'},
    {'kw': 'ล้อคู่สแตนเลส', 'hash': '1be83179'},
    {'kw': 'ล้อบน', 'hash': '9ddf6d4d'},
    {'kw': 'carrier', 'hash': '9ddf6d4d'},
    {'kw': 'pivot', 'hash': '57eb29b1'},
    {'kw': 'ไกด์ล่าง', 'hash': '48de300e'},
    {'kw': 'ล้อบานเลื่อน', 'hash': 'cdc046ef'},
    {'kw': 'ลูกล้อ', 'hash': 'cdc046ef'},
    {'kw': 'บานพับมือจับ', 'hash': '05a6a3f6'},
    {'kw': 'บานพับพร้อมมือจับ', 'hash': '05a6a3f6'},
    {'kw': 'hinge handle', 'hash': '05a6a3f6'},
    {'kw': 'บานพับปกติ', 'hash': 'adf52c7e'},
    {'kw': 'บานพับกลาง', 'hash': 'adf52c7e'},
    {'kw': 'บานพับกรอบบน', 'hash': '9ddf6d4d'},
    {'kw': 'ปากเป็ด', 'hash': '2c4b8130'},
    {'kw': 'มือจับตอนเลื่อนบาน', 'hash': '2c4b8130'},
    {'kw': 'ปลายกลอน', 'hash': '120c52ff'},
    {'kw': 'สลักตอนล่าง', 'hash': '120c52ff'},
    {'kw': 'ตอนบานล่าง', 'hash': '120c52ff'},
    {'kw': 'flush bolt', 'hash': '120c52ff'},
    {'kw': '4 bar', 'hash': '8571b905'},
    {'kw': '4bar', 'hash': '8571b905'},
    {'kw': 'friction stay', 'hash': '8571b905'},
    {'kw': 'บานพับกระทุ้งยูเนี่ยน', 'hash': '6357ebab'},
    {'kw': 'บานพับกระทุ้ง', 'hash': '8571b905'},
    {'kw': 'บานพับบานกระทุ้ง', 'hash': '8571b905'},
    {'kw': 'บานพับซ่อน', 'hash': '8571b905'},
    {'kw': 'บานพับแขนค้ำ', 'hash': '8571b905'},
    {'kw': 'บานพับบานเปิด', 'hash': '185ae7a2'},
    {'kw': 'บานพับประตู', 'hash': '08dcf4df'},
    {'kw': 'บานพับ', 'hash': '185ae7a2'},
    {'kw': 'โช๊คสวิง', 'hash': 'ffc37936'},
    {'kw': 'มือจับกระทุ้งยูเนี่ยน', 'hash': '7ff3e10b'},
    {'kw': 'มือจับกระทุ้ง', 'hash': '3fa25e09'},
    {'kw': 'spindle', 'hash': '3fa25e09'},
    {'kw': 'เขาควาย', 'hash': '3fa25e09'},
    {'kw': 'mortise lock', 'hash': '3fa25e09'},
    {'kw': 'มือจับบานพร้อมกุญแจ', 'hash': '3fa25e09'},
    {'kw': 'auto lock', 'hash': '120c52ff'},
    {'kw': 'multi point', 'hash': '62d17139'},
    {'kw': 'multi-point', 'hash': '62d17139'},
    {'kw': 'multi-lock', 'hash': '62d17139'},
    {'kw': 'มัลติพอยท์', 'hash': '62d17139'},
    {'kw': 'มัลติพ้อย', 'hash': '62d17139'},
    {'kw': 'ยกล็อค', 'hash': '62d17139'},
    {'kw': 'ปากนกแก้ว', 'hash': '120c52ff'},
    {'kw': 'มือจับฝัง', 'hash': '120c52ff'},
    {'kw': 'มือจับดัมมี่', 'hash': '3fa25e09'},
    {'kw': 'dummy', 'hash': '3fa25e09'},
    {'kw': 'มือจับ', 'hash': '3fa25e09'},
    {'kw': 'ไส้กุญแจ', 'hash': '78bb471c'},
    {'kw': 'เสื้อกุญแจ', 'hash': '62d17139'},
    {'kw': 'cdq', 'hash': 'acfb50ec'},
    {'kw': 'ตลับกุญแจ', 'hash': 'acfb50ec'},
    {'kw': 'ตลับกลอน', 'hash': 'acfb50ec'},
    {'kw': 'ชุดล็อก', 'hash': '62d17139'},
    {'kw': 'แกนเกียร์', 'hash': 'a2dff7cd'},
    {'kw': 't-gear', 'hash': 'a2dff7cd'},
    {'kw': 'connection rod', 'hash': 'a2dff7cd'},
    {'kw': 'ขาล็อกตัว t', 'hash': 'a2dff7cd'},
    {'kw': 'กระดุม', 'hash': 'ccee5a6a'},
    {'kw': 'ปุ่มล็อค', 'hash': '1c985c62'},
    {'kw': 'ปุ่มล็อก', 'hash': '1c985c62'},
    {'kw': 'ปุ่มเสริม', 'hash': '1c985c62'},
    {'kw': 'หมุดล็อค', 'hash': 'ccee5a6a'},
    {'kw': 'ขอมัลติพอยท์', 'hash': '1c985c62'},
    {'kw': 'แป้นรับล็อก', 'hash': 'a528b55a'},
    {'kw': 'แป้นรับล็อค', 'hash': 'a528b55a'},
    {'kw': 'ยูรับล็อค', 'hash': '70cf2d93'},
    {'kw': 'ยูรับล็อก', 'hash': '70cf2d93'},
    {'kw': 'u lock', 'hash': '70cf2d93'},
    {'kw': 'จุดรับล็อค', 'hash': 'e079d11e'},
    {'kw': 'ตัวรับล็อก', 'hash': 'e079d11e'},
    {'kw': 'รับล็อก', 'hash': 'e079d11e'},
    {'kw': 'striker', 'hash': '3869df86'},
    {'kw': 'receiver', 'hash': 'bcb3e414'},
    {'kw': 'สปิก๊อต', 'hash': '96d3fc97'},
    {'kw': 'sprigot', 'hash': '96d3fc97'},
    {'kw': 'ฉากปรับมุม', 'hash': '96d3fc97'},
    {'kw': 'ฉากเข้ามุม', 'hash': '96d3fc97'},
    {'kw': 'ข้อต่อเข้ามุม', 'hash': '96d3fc97'},
    {'kw': 'ล็อคมุม', 'hash': '96d3fc97'},
    {'kw': 'มุมมุ้งลวด', 'hash': '96d3fc97'},
    {'kw': 'ฉากประคอง', 'hash': 'e6682e73'},
    {'kw': 'ฉากประกอบ', 'hash': 'e6682e73'},
    {'kw': 'ฉากข้อต่อ', 'hash': '3c052cea'},
    {'kw': 'แผ่นประกับ', 'hash': 'e6682e73'},
    {'kw': 'แผ่นอะลูมิเนียมปิด', 'hash': 'e6682e73'},
    {'kw': 'hd-1025', 'hash': '28f6d3f5'},
    {'kw': 'ตะแกรง', 'hash': '28f6d3f5'},
    {'kw': 'ฝาปิดน้ำเข้า', 'hash': 'd7eb0689'},
    {'kw': 'ฝาปิดน้ำออก', 'hash': '54034218'},
    {'kw': 'ฝาปิดรูน้ำ', 'hash': '54034218'},
    {'kw': 'ฝาปิดระบายน้ำ', 'hash': '54034218'},
    {'kw': 'ฝาปิดตบ', 'hash': '1d3b2535'},
    {'kw': 'ฝาปิดเสา', 'hash': '1d3b2535'},
    {'kw': 'ยางกันกระแทกแบบกลม', 'hash': 'deae6e29'},
    {'kw': 'ยางกันกระแทก', 'hash': 'b8784b6d'},
    {'kw': 'ยางกันชน', 'hash': 'b8784b6d'},
    {'kw': 'ยางกันลม', 'hash': 'b8784b6d'},
    {'kw': 'ยางกันน้ำ', 'hash': 'b8784b6d'},
    {'kw': 'setting block', 'hash': 'b8784b6d'},
    {'kw': 'กันบานตก', 'hash': '3cdbf139'},
    {'kw': 'ปรับบานกันตก', 'hash': '3cdbf139'},
    {'kw': 'ตัวหยุดบาน', 'hash': '3cdbf139'},
    {'kw': 'ตัวล็อคเสริม', 'hash': '3cdbf139'},
    {'kw': 'ยางอุดรู', 'hash': '3cb6cbc1'},
    {'kw': 'ยางปิดรู', 'hash': '3cb6cbc1'},
    {'kw': 'สักหลาด', 'hash': 'a283261c'},
    {'kw': 'mohair', 'hash': 'a283261c'},
    {'kw': 'ยางกระจก', 'hash': 'e2082b9c'},
    {'kw': 'ยางหุ้ม', 'hash': 'e2082b9c'},
    {'kw': 'ยางอุดมุ้ง', 'hash': '4d026bd7'},
    {'kw': 'ยางอัด', 'hash': '4d026bd7'},
    {'kw': 'wedge', 'hash': '4d026bd7'},
    {'kw': 'seal', 'hash': '5f899ed0'},
    {'kw': 'tpe', 'hash': '5f899ed0'},
    {'kw': 'สกรู', 'hash': '9ec2d256'},
    {'kw': 'screw', 'hash': '9ec2d256'},
    {'kw': 'รีเวท', 'hash': 'c630bba4'},
    {'kw': 'acrylic', 'hash': '1a364c38'},
    {'kw': 'ซิลิโคน', 'hash': '523d300c'},
    {'kw': 'sealant', 'hash': '523d300c'},
    {'kw': 'pu', 'hash': '523d300c'},
  ];

  // Collect EVERY referenced plain hash across all maps so we ONLY bundle needed assets!
  referencedPlainHashes.addAll(
    profileCodeHashes.values.where((v) => !v.startsWith('assets/')),
  );
  referencedPlainHashes.addAll(hardwareCodeHashes.values);
  referencedPlainHashes.addAll(hardwareKeywordRules.map((e) => e['hash']!));

  if (missingJids.isNotEmpty) {
    throw StateError('Missing jids: $missingJids');
  }
  for (final h in referencedPlainHashes) {
    if (!rawImagesByHash.containsKey(h)) {
      throw StateError('Referenced image hash $h does not exist in rawImagesByHash!');
    }
  }

  // Write compressed JPEGs to assets/alupro/
  final outAssetsDir = Directory('assets/alupro');
  if (outAssetsDir.existsSync()) {
    outAssetsDir.deleteSync(recursive: true);
  }
  outAssetsDir.createSync(recursive: true);

  int totalBytesWritten = 0;
  for (final h in referencedPlainHashes.toList()..sort()) {
    final rawBytes = rawImagesByHash[h]!;
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw StateError('Failed to decode image for hash $h');
    }
    final reencoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 82));
    final bestBytes = reencoded.length < rawBytes.length ? reencoded : rawBytes;
    final outFile = File('${outAssetsDir.path}/$h.jpg');
    await outFile.writeAsBytes(bestBytes);
    totalBytesWritten += bestBytes.length;
  }

  for (final entry in generatedCustomJpegs.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    final outFile = File('${outAssetsDir.path}/${entry.key}');
    await outFile.writeAsBytes(entry.value);
    totalBytesWritten += entry.value.length;
  }

  // Copy & optimize glass.jpg
  final glassSourceFile = File(_glassDownloadPath).existsSync()
      ? File(_glassDownloadPath)
      : File('$_backupAssetsDir/glass.jpg');
  final glassRaw = await glassSourceFile.readAsBytes();
  final glassDecoded = img.decodeImage(glassRaw)!;
  final glassResized = glassDecoded.width > 320
      ? img.copyResize(
          glassDecoded,
          width: 320,
          interpolation: img.Interpolation.average,
        )
      : glassDecoded;
  final glassEncoded = Uint8List.fromList(img.encodeJpg(glassResized, quality: 82));
  final glassBest = glassEncoded.length < glassRaw.length ? glassEncoded : glassRaw;
  await File('${outAssetsDir.path}/glass.jpg').writeAsBytes(glassBest);
  totalBytesWritten += glassBest.length;

  Map<String, String> withExt(Map<String, String> m) =>
      m.map((k, v) => MapEntry(k, v.startsWith('assets/') ? v : '$v.jpg'));

  final jsonPayload = <String, dynamic>{
    'glass': 'glass.jpg',
    'categories': <String, String>{},
    'brands': brandAssets,
    'systems': <String, String>{},
    'patterns': patternFiles,
    'profiles': withExt(profileCodeHashes),
    'profilePrefixes': const <Map<String, String>>[],
    'profileRoles': const <Map<String, String>>[],
    'hardwareCodes': withExt(hardwareCodeHashes),
    'hardwareKeywords': hardwareKeywordRules
        .map((e) => {'kw': e['kw']!, 'file': '${e['hash']!}.jpg'})
        .toList(),
  };

  final mapFile = File('assets/data/alupro_image_map.json');
  await mapFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonPayload),
  );

  // Audit 100% of formulas_168_verified.json & orm_prices_1139.json!
  final formulasList =
      jsonDecode(await File('assets/data/formulas_168_verified.json').readAsString())
          as List<dynamic>;
  int totalCuts = 0, matchedCuts = 0;
  int totalHw = 0, matchedHw = 0;
  for (final item in formulasList) {
    final tbl = VerifiedFormulaTable.fromJson(item as Map<String, dynamic>);
    for (final c in tbl.cuts) {
      totalCuts++;
      if (profileCodeHashes.containsKey(c.code.trim())) {
        matchedCuts++;
      }
    }
    for (final h in tbl.hardware) {
      totalHw++;
      final clean = h.code.trim();
      final hay = '$clean ${h.name}'.toLowerCase();
      final hit = hardwareCodeHashes.containsKey(clean) ||
          hardwareKeywordRules.any((r) => hay.contains(r['kw']!.toLowerCase()));
      if (hit) matchedHw++;
    }
  }

  final ormSkus =
      jsonDecode(await File('assets/data/orm_prices_1139.json').readAsString())
          as List<dynamic>;
  int matchedSkus = 0;
  for (final s in ormSkus) {
    final sku = OrmPriceSku.fromJson(s as Map<String, dynamic>);
    if (profileCodeHashes.containsKey(sku.code.trim())) {
      matchedSkus++;
    }
  }

  final totalFiles = referencedPlainHashes.length + generatedCustomJpegs.length + 1;
  print('=======================================================');
  print('Generated $totalFiles offline images in assets/alupro/');
  print('  - Plain verified hashes : ${referencedPlainHashes.length}');
  print('  - Stamped ALUMET/ICONIQ : ${generatedCustomJpegs.length}');
  print('Total bundled image size  : ${(totalBytesWritten / (1024 * 1024)).toStringAsFixed(2)} MB');
  print('Brands mapped             : ${brandAssets.length}');
  print('Exact Patterns mapped     : ${patternFiles.length}');
  print('Exact Profile CAD codes   : ${profileCodeHashes.length}');
  print('Formula Cuts (exact CAD)  : $matchedCuts/$totalCuts');
  print('Formula Hardware          : $matchedHw/$totalHw');
  print('Price SKUs (exact CAD)    : $matchedSkus/${ormSkus.length}');
  print('=======================================================');
}
