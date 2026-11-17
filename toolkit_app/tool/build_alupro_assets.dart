// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/models/app_models.dart';

const String _outputsDir =
    r'C:\Users\ayumg\.gemini\antigravity\brain\e96a7de5-9a54-42b4-b7f2-ed54af4f20d0\browser_sandbox\outputs';
const String _glassDownloadPath =
    r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265\browser_sandbox\downloads\glass.jpg';

const List<int> _processStepNums = [
  241, 243, 245, 250, 252, 256, 260, 262, 264, 266, 268, 270, 272, 274, 276, 278, 282,
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

void main() async {
  final rawImagesByHash = <String, Uint8List>{};
  final processCodeToHash = <String, String>{};
  final homeItems = <Map<String, dynamic>>[];
  final jidToHash = <String, String>{};

  // 1. Load all extracted process.php outputs (CAD profile cross-sections + hardware photos)
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
    final codeRegex = RegExp(
      r'^([A-Za-z0-9]+(?:-[A-Za-z0-9.]+)*)\s*[ก-๙A-Za-z(]',
    );
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final h = (m['imgHash'] as String? ?? '').trim();
      final rawText = (m['rawText'] as String? ?? '').trim();
      if (h.isEmpty || !rawImagesByHash.containsKey(h)) continue;
      final match = codeRegex.firstMatch(rawText);
      if (match != null) {
        final code = match.group(1)!.trim();
        if (code.length >= 4 && !code.startsWith('ขนาด')) {
          processCodeToHash.putIfAbsent(code, () => h);
        }
      }
    }
  }

  // 2. Load all extracted home.php outputs (Window/Door/Folding/Shower pattern diagrams)
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
  print('Auto-detected ${processCodeToHash.length} direct profile CAD codes & ${jidToHash.length} pattern jids.');

  final missingJids = <String>{};
  String jidHash(String jid) {
    final h = jidToHash[jid];
    if (h == null) {
      missingJids.add(jid);
      return '';
    }
    return h;
  }

  // Parse all folding diagrams from homeItems (g08b01, u09b01, g04b01, u04b01, g02b01, u06b01, u08b01)
  final foldingEntries = <_FoldingDiagramEntry>[];
  for (final it in homeItems) {
    final cat = it['cat'] as String? ?? '';
    if (!cat.contains('b0')) continue;
    final name = it['name'] as String? ?? '';
    final hash = it['hash'] as String;
    final jid = it['jid'] as String? ?? '';

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
  print('Parsed ${foldingEntries.length} folding diagrams across brands.');

  String resolveFoldingHash(String family, int n, int l, int r) {
    final preferredCat = switch (family) {
      'orm90' || 'orm101' => 'g08b01',
      'fuji_std' || 'fuji_u' => 'u09b01',
      'sch240' => 'g04b01',
      'sp_fold' => 'u04b01',
      'alu_fold' => 'g02b01',
      _ => 'g08b01',
    };

    // 1. Exact (n, l, r) in brand's own category
    for (final e in foldingEntries) {
      if (e.cat == preferredCat && e.n == n && e.l == l && e.r == r) {
        return e.hash;
      }
    }
    // 2. Mirror (n, r, l) in brand's own category
    for (final e in foldingEntries) {
      if (e.cat == preferredCat && e.n == n && e.l == r && e.r == l) {
        return e.hash;
      }
    }
    // 3. Exact (n, l, r) across any extracted folding category
    const fallbackOrder = ['u09b01', 'g08b01', 'u04b01', 'g02b01', 'g04b01', 'u06b01', 'u08b01'];
    for (final cat in fallbackOrder) {
      for (final e in foldingEntries) {
        if (e.cat == cat && e.n == n && e.l == l && e.r == r) {
          return e.hash;
        }
      }
    }
    // 4. Mirror (n, r, l) across any folding category
    for (final cat in fallbackOrder) {
      for (final e in foldingEntries) {
        if (e.cat == cat && e.n == n && e.l == r && e.r == l) {
          return e.hash;
        }
      }
    }
    // 5. Same total panel count n in brand's own category or any category
    for (final e in foldingEntries) {
      if (e.cat == preferredCat && e.n == n) return e.hash;
    }
    for (final e in foldingEntries) {
      if (e.n == n) return e.hash;
    }
    return jidHash('g08b0104');
  }

  // 3. Category & Brand & Pattern Image Mapping via exact AluProSmart jid
  final categoryHashes = <String, String>{
    'cat1_market': jidHash('g01s0101'),
    'cat2_pattana': jidHash('g08s0201'),
    'cat3_euro': jidHash('g08s0105'),
    'cat4_folding': jidHash('g08b0104'),
    'cat5_shower': jidHash('g01g0201'),
  };

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

  final explicitPatternJids = <String, String>{
    // Category 1: ชุดตลาด
    'c1_pat_s2_alt': 'g01s0101',
    'c1_pat_s2_1s1f': 'g01s0116',
    'c1_pat_s4_ctr': 'g01s0201',
    'c1_dis_s3': 'g01s0301',
    'c1_dis_s2_top': 'g01s0105',
    'c1_dis_s2_bot': 'g01s0103',
    'c1_dis_1s1f_top': 'g01s0109',
    'c1_dis_1s1f_bot': 'g01s0110',
    'c1_dis_s4_top': 'g01s0203',
    'c1_dis_s4_bot': 'g01s0204',
    'c1_pat_swing1': 'g01w0101',
    'c1_pat_swing2': 'g01w0103',
    'c1_pat_hang1': 'g01h0101',
    'c1_pat_hang2': 'g01h0106',
    'c1_pat_union_case1': 'g01c0126',
    'c1_pat_union_awn1': 'g01c0104',

    // Category 2: ORM (Asian Trop)
    'c2_orm_s2_card': 'g08s0201',
    'c2_orm_s2_top_card': 'g08s0403',
    'c2_orm_s2_bot_card': 'g08s0407',
    'c2_orm_s4_card': 'g08s0204',
    'c2_orm_s4_top_card': 'g08s0411',
    'c2_orm_s4_bot_card': 'g08s0415',
    'c2_orm_case1_card': 'g08c0101',
    'c2_orm_case1_top_card': 'g08c0107',
    'c2_orm_case1_bot_card': 'g08c0106',
    'c2_orm_case_div2_card': 'g08c0102',
    'c2_orm_case_div3_card': 'g08c0109',
    'c2_orm_case_div4_card': 'g08c0118',
    'c2_orm_fix1_card': 'g08f0101',
    'c2_orm_wood1_card': 'g08o0101',
    'c2_orm_wood2_dis': 'g08o0102',
    'c2_orm_wood_top_dis': 'g08o0111',

    // Category 2: SMS SCHIMMER
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

    // Category 2: ALUMET Smart X
    'c2_alu_s2_card': 'g02s0104',
    'c2_alu_s2_top_card': 'g02s0308',
    'c2_alu_s3_card': 'g02s0201',
    'c2_alu_s3_top_card': 'g02s0309',
    'c2_alu_s4_card': 'g02s0105',
    'c2_alu_s4_top_card': 'g02s0102',
    'c2_alu_corner22_card': 'g04s0211',
    'c2_alu_corner23_card': 'g04s0213',
    'c2_alu_corner32_card': 'g04s0213',
    'c2_alu_corner33_card': 'g04s0214',
    'c2_alu_hang_dis': 'g01h0101',
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

    // Category 2: SMART PLUS Semi Euro
    'c2_sp_s2_card': 'u04s0103',
    'c2_sp_s4_card': 'u04s0104',
    'c2_sp_s3_card': 'u04s0101',
    'c2_sp_s2_sec_card': 'u04s0103',
    'c2_sp_more_dis': 'u04s0102',
    'c2_sp_case1_card': 'u04c0201',
    'c2_sp_case1_top_card': 'u04c0109',
    'c2_sp_awn1_card': 'u04c0101',
    'c2_sp_awn1_top_card': 'u04c0109',

    // Category 2: UAI Super Frame
    'c2_uai_s2_card': 'u06s0101',
    'c2_uai_s3_dis': 'u06s0205',
    'c2_uai_s4_card': 'u06s0201',
    'c2_uai_s6_card': 'u08s0304',
    'c2_uai_24_1': 'u06c0101',
    'c2_uai_24_2': 'u06c0201',
    'c2_uai_24_3': 'u06c0209',
    'c2_uai_25_1': 'u09f0101',
    'c2_uai_25_2': 'u09f0102',
    'c2_uai_25_3': 'u09f0103',
    'c2_uai_25_4': 'u06s0102',
    'c2_uai_25_5': 'u06s0103',
    'c2_uai_25_6': 'g08s0421',

    // Category 3: ORM Pano Suit
    'c3_orm_s2_card': 'g08s0105',
    'c3_orm_s3_card': 'g08s0104',
    'c3_orm_s4_ctr_card': 'g08s0102',
    'c3_orm_s4_1w_card': 'g08s0103',
    'c3_orm_case1_card': 'g08c0110',
    'c3_orm_case2_dis': 'g08c0111',
    'c3_orm_awn1_card': 'g08c0202',
    'c3_orm_awn2_dis': 'g08c0102',

    // Category 3: Fuji Eurotech
    'c3_fuji_s2_card': 'u09s0101',
    'c3_fuji_s2_1s1f_card': 'u09s0101',
    'c3_fuji_s3_card': 'u09s0105',
    'c3_fuji_s4_ctr_card': 'u09s0102',
    'c3_fuji_4t_int_card': 'u09s0106',
    'c3_fuji_5t_int_card': 'u09s0107',
    'c3_fuji_s4_2t_card': 'u09s0102',
    'c3_fuji_s4_3t_card': 'u09s0104',
    'c3_fuji_s5_card': 'u09s0107',
    'c3_fuji_dis_1': 'u06s0102',
    'c3_fuji_dis_2': 'u06s0103',
    'c3_fuji_dis_3': 'g08s0502',
    'c3_fuji_dis_4': 'g08s0407',
    'c3_fuji_dis_5': 'u06s0202',
    'c3_fuji_dis_6': 'u06s0203',
    'c3_fuji_dis_7': 'g08s0421',
    'c3_fuji_dis_8': 'g08s0421',
    'c3_fuji_dis_9': 'g04s0211',
    'c3_fuji_dis_10': 'g04s0213',
    'c3_fuji_w1_card': 'u09c0101',
    'c3_fuji_w2_card': 'u09c0102',
    'c3_fuji_w1_mosq_card': 'u09c0201',
    'c3_fuji_w1_bot_card': 'u09c0111',
    'c3_fuji_w2_bot_card': 'u09c0112',
    'c3_fuji_d_dis1': 'u09o0101',
    'c3_fuji_d_dis2': 'g02o0105',
    'c3_fuji_d_dis3': 'u06o0102',
    'c3_fuji_d_dis4': 'g02o0109',
    'c3_fuji_d_dis5': 'g02o0103',
    'c3_fuji_d_dis6': 'g02o0111',
    'c3_fuji_f_dis1': 'u09f0101',
    'c3_fuji_f_dis2': 'u09f0102',
    'c3_fuji_f_dis3': 'u09f0103',
    'c3_fuji_f_dis4': 'u09f0104',
    'c3_fuji_f_dis5': 'g01f0146',

    // Category 3: ALUMET Iconiq Euro
    'c3_alu_s2_card': 'g02s0301',
    'c3_alu_s2_in_mosq_card': 'g02s0203',
    'c3_alu_s2_top_card': 'g02s0308',
    'c3_alu_s3_card': 'g02s0302',
    'c3_alu_s4_ctr_card': 'g02s0303',
    'c3_alu_s4_ctr_top_card': 'g02s0306',
    'c3_alu_s4_1w_card': 'u09s0106',
    'c3_alu_s4_1w_top_card': 'g02s0306',
    'c3_alu_s6_corner_dis': 'g04s0214',
    'c3_alu_awn1_card': 'g02c0101',
    'c3_alu_awn1_bot_card': 'g02c0111',
    'c3_alu_case1_card': 'g02c0201',
    'c3_alu_case2_card': 'g02c0202',
    'c3_alu_d1_card': 'g02o0101',
    'c3_alu_d2_card': 'g02o0105',
    'c3_alu_fix1_dis': 'g02f0101',
    'c3_alu_fix2_dis': 'g02f0102',

    // Category 3: SMART PLUS Euro
    'c3_sp_s2_2t_card': 'u04s0201',
    'c3_sp_s4_2t_card': 'u04s0202',
    'c3_sp_s2_3t_45_card': 'u04s0201',
    'c3_sp_s3_3t_euro_card': 'u04s0203',
    'c3_sp_s4_3t_45_card': 'u04s0202',
    'c3_sp_s4_4t_card': 'u04s0202',
    'c3_sp_s2_3t_sec_card': 'u04s0201',
    'c3_sp_s4_3t_sec_card': 'u04s0202',
    'c3_sp_corner_dis': 'g04s0211',
    'c3_sp_90_s2_card': 'u04s0204',
    'c3_sp_90_s2_top_card': 'u08s0109',
    'c3_sp_90_s3_card': 'u04s0203',
    'c3_sp_90_s3_top_card': 'g08s0502',
    'c3_sp_90_s4_card': 'u04s0205',
    'c3_sp_90_s4_top_card': 'u08s0117',
    'c3_sp_win1_top_card': 'u08c0403',
    'c3_sp_win2_card': 'u04c0202',
    'c3_sp_win2_top_card': 'u06c0206',
    'c3_sp_w_sec1_dis': 'u04c0201',
    'c3_sp_w_sec2_dis': 'u04c0202',
    'c3_sp_w_sec3_dis': 'u04c0101',
    'c3_sp_w_fix_dis': 'u04f0102',
    'c3_sp_door1_card': 'u04o0105',
    'c3_sp_door2_card': 'u04o0103',
    'c3_sp_door1_top_dis': 'u06o0102',
    'c3_sp_door2_top_dis': 'g08o0111',

    // Category 3: ALUFRAME Euro
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

    // Category 4: Non-parametric Schimmer & SmartPlus corner disabled cards
    'c4_sch_2l_card': 'g04b0101',
    'c4_sch_3_1l2r_card': 'g04b0105',
    'c4_sch_3_3l_card': 'g04b0103',
    'c4_sch_4_1l3r_card': 'g04b0109',
    'c4_sch_4_2l2r_card': 'g04b0111',
    'c4_sch_4_4l_card': 'g04b0107',
    'fold_sp_corner_1': 'g04s0211',
    'fold_sp_corner_2': 'g04s0212',
  };

  // Walk the entire CatalogDefinitions tree to populate ALL patternHashes & systemHashes
  final patternHashes = <String, String>{};
  final systemHashes = <String, String>{
    'c1_sys_fixed': jidHash('g01f0102'),
    'c2_uai_doors': jidHash('u06o0101'),
    'c3_orm_fixed_dis': jidHash('g08f0101'),
    'c3_orm_cw_dis': jidHash('g08f0115'),
    'c3_fuji_wood_dis': jidHash('u09o0101'),
  };

  void registerPattern(PatternCardDef p) {
    if (explicitPatternJids.containsKey(p.id)) {
      patternHashes[p.id] = jidHash(explicitPatternJids[p.id]!);
    } else if (p.foldingFamily != null &&
        p.foldingTotalPanels != null &&
        p.foldingLeftPanels != null &&
        p.foldingRightPanels != null) {
      patternHashes[p.id] = resolveFoldingHash(
        p.foldingFamily!,
        p.foldingTotalPanels!,
        p.foldingLeftPanels!,
        p.foldingRightPanels!,
      );
    } else {
      throw StateError('Unmapped PatternCardDef: ${p.id} (${p.title})');
    }
  }

  void registerSystem(SubSystemDef sys) {
    for (final p in sys.patterns) {
      registerPattern(p);
    }
    for (final tab in sys.subTabs) {
      registerSystem(tab);
    }
    if (!systemHashes.containsKey(sys.id)) {
      if (sys.patterns.isNotEmpty) {
        systemHashes[sys.id] = patternHashes[sys.patterns.first.id]!;
      } else if (sys.subTabs.isNotEmpty && sys.subTabs.first.patterns.isNotEmpty) {
        systemHashes[sys.id] = patternHashes[sys.subTabs.first.patterns.first.id]!;
      }
    }
  }

  for (final cat in CatalogDefinitions.categories) {
    if (!categoryHashes.containsKey(cat.id)) {
      throw StateError('Unmapped CategoryDef: ${cat.id}');
    }
    for (final sys in cat.directSystems) {
      registerSystem(sys);
    }
    for (final brand in cat.brands) {
      if (!brandAssets.containsKey(brand.id)) {
        throw StateError('Unmapped BrandDef: ${brand.id}');
      }
      for (final p in brand.directPatterns) {
        registerPattern(p);
      }
      for (final sys in brand.systems) {
        registerSystem(sys);
      }
    }
  }

  // 4. Profile CAD Cross-Section Map (Direct + Sister Variants + Market Thai Roles)
  final profileCodeHashes = <String, String>{
    ...processCodeToHash,

    // Market (ชุดตลาด) Thai descriptive codes
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
    'ฉากประกอบบานหลัก 6 มม.': '3c052cea',
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

    // ORM sister variants & descriptive codes
    '801-01': '51f67a71',
    '801-05': 'b1fdd5d1',
    '801-23': 'b1585ca3',
    '801-25': '8bc440e6',
    '801-27': 'd7eda83e',
    '801-28': '42281481',
    '803-05': '6be7223a',
    '803-06': '7f6e8434',
    '803-07': '494c4785',
    '803-08': '494c4785',
    '803-10': '19f42d81',
    '803-17': '494c4785',
    'รอยืนยัน': '494c4785',
    '804-20': '2b5e8698',
    '811-13': '9df04014',
    '812-11': '60f41ccb',
    'คิ้วบานยูโร · เลือกตามชุด (812-10 / 812-11)': '60f41ccb',
    'กรอบบานเฟี้ยมมาตรฐาน': '7fca1b97',
    '805-11': '25a63e03',
    '805-12': 'db6f131f',
    '805-13': '7537f9ff',
    '805-14': '94b78c45',
    'เส้น C-กรุ๊ฟ': '9ace630c',
    'เส้นซีกรุฟ (C-Groove)': '9ace630c',

    // SMS SCHIMMER sister variants
    'B20014': '47603309',
    'B20016': '47603309',
    'B20020': '27b8c312',
    'B30006': 'b5aa1807',
    'B26003': 'b3e11316',
    'B10002': '81f41889',
    'B10003': '399fffcf',
    'B10004': '81f41889',
    'B10010': '399fffcf',
    'B10016': '7345e974',
    'B10019': '7345e974',
    'B10023': '7345e974',

    // ALUMET Smart X & Iconiq sister variants
    'SS-X101': '463e473d',
    'SS-X104': '463e473d',
    'SS-X105': '6e502055',
    'SS-X106': '6e502055',
    'SS-X107': 'c270ebc2',
    'SS-X107 / SS-0120': 'c270ebc2',
    'SS-X109': '463e473d',
    'SS-X110': '463e473d',
    'SS-X111': '0ca0c2f7',
    'SS-X212': 'ded15733',
    'SS-X213': 'a6b5c2b2',
    'SS-X214': 'a6b5c2b2',
    'SS-X216': '5aca9cf2',
    'SS-X217': 'c8eed1e0',
    'SS-X219': 'ded15733',
    'SS-0141': 'a6b5c2b2',
    'SC-X104': 'f14db19f',
    'SC-X106': '2b04e9c6',
    'SC-X107': 'f14db19f',
    'SC-X108': '2b04e9c6',
    'SC-X204': '2df967cb',
    'SC-0212': '2b04e9c6',
    'SO-X201': '2df967cb',
    'SF-X105': '3fd1cdb5',
    'SF-X108': '3fd1cdb5',
    'SF-X109': 'f14db19f',
    'SF-X110': 'f14db19f',
    'SF-X111': '3fd1cdb5',
    'iC-0101': 'a0c1bce1',
    'iC-0102': 'a0c1bce1',
    'iC-0107': 'a0c1bce1',
    'iC-0108': 'a0c1bce1',
    'iC-0201': 'aef67579',
    'iF-0101': 'a0c1bce1',
    'iF-0102': 'a0c1bce1',
    'iF-0104': 'a1220bab',
    'iS-0113': '53aaea59',
    'iS-0116': '30b11915',
    'iS-0201': '1dcc50a7',
    'iS-0202': '373eac56',
    'iS-0205': '1dcc50a7',
    'SB-0101': '74bdc4bc',
    'SB-0103': '0432ce65',
    'SB-0105': 'd8833d5c',
    'SB-0108': 'f28f221b',
    'SB-0109': '69aafbc1',
    'SB-0113': 'e874a7b3',
    'SB-0114': 'fc51c5cb',
    'SB-0115': '0432ce65',
    'SB-0116': '0432ce65',
    'SB-0117': 'e874a7b3',

    // SMART PLUS sister variants
    '15107': '7300ca95',
    '15111': '2c7f0014',
    '15117': 'f29b54fd',
    '15124': '80e30949',
    '15128': '9889fac0',
    '15131': 'b226e534',
    '15132': '6db307c3',
    '15133': 'a4362899',
    '15138': 'ddcc64c6',
    '15140': '8505ef5c',
    '15141': 'a9ecf803',
    '15142': 'e55d9f10',
    '15143': 'b226e534',
    '15145': 'a4362899',
    '15155': 'b226e534',
    '15159': 'f1248b70',
    '15160': '80e30949',
    '15162': '9343d9b8',
    '15163': 'f1248b70',
    '15177': 'e874a7b3',
    '15178': 'e874a7b3',
    '15179': '11e8d959',
    '15181': 'e874a7b3',
    '15182': '9343d9b8',
    '15183': '2f350747',
    '15190': '9343d9b8',
    '15191': '80e30949',
    '15192': '6db307c3',
    '15212': '80e30949',
    '23 มม. ×4 ต่อมุ้ง · เส้น 6000 มม. · ใบตัด 4 มม./ครั้ง': '3c052cea',

    // UAI sister variants
    'SLI-32019': '149d1b26',
    'SLI-30756': '0e103c0b',
    'SLI-30753': '0e103c0b',
    'SLI-30755': '2fd5b1db',
    'SLI-33089': 'd688d976',
    'SLI-33001': 'd688d976',
    'SLI-33002': '77ba44b6',
    'SLI-30754': '77ba44b6',
    'SLI-30900': '0e103c0b',
    'SLI-30909': '0e103c0b',

    // Fuji Eurotech sister variants
    'F7980': 'b94c37b2',
    'F7983': '8ed8c3fe',
    'F7992': '33988e70',
    'F7997': 'fbb12d6c',
    'F7860': '82969d36',
    'F7944': 'f9d4fbc6',
    'F7949': '82969d36',
    'F7945': 'fbb12d6c',
    'F7974': '6542e872',
    'F7961': 'e820173b',
    'F7962': '6542e872',
    'F7932': '1d961b64',

    // ALUFRAME codes
    'A2-002-15': '999a058e',
    'A2-003-15': '999a058e',
    'A2-006-15': '999a058e',
    'A2-010-15': '35996529',
    'A2-012-12': '2c65a3d2',
    'A2-016-12': '999a058e',
    'A2-018-14': '344974c5',
    'A1-001-15': '5118d06e',
    'A1-002-15': '5118d06e',
    'A1-007-15': '5118d06e',
    'A1-009-15': '6db307c3',
    'A1-011-14R': 'f1248b70',
    'A1-018-11': 'c24a9c8d',
    'A1-021-12': '2c65a3d2',
    'A1-024-17': 'cb0bceea',
    'A1-026-15': '80e30949',
    'A1-027-15': 'ddcc64c6',
    'A1-028-15': '2f350747',
  };

  // Prefix fallbacks for any remaining ORM / brand SKUs in orm_prices_1139.json
  final profilePrefixHashes = <Map<String, String>>[
    {'prefix': '801-', 'hash': '809d85d0'},
    {'prefix': '802-', 'hash': '5cb798dd'},
    {'prefix': '803-', 'hash': '494c4785'},
    {'prefix': '804-', 'hash': '2b5e8698'},
    {'prefix': '805-', 'hash': '7fca1b97'},
    {'prefix': '806-', 'hash': '5cb798dd'},
    {'prefix': '807-', 'hash': 'e5c54c5d'},
    {'prefix': '808-', 'hash': '13596996'},
    {'prefix': '809-', 'hash': '13596996'},
    {'prefix': '810-', 'hash': '9ace630c'},
    {'prefix': '811-', 'hash': '923d6928'},
    {'prefix': '812-', 'hash': '7cbec794'},
    {'prefix': 'B200', 'hash': 'e7b129c6'},
    {'prefix': 'B240', 'hash': '99039356'},
    {'prefix': 'B250', 'hash': '81f41889'},
    {'prefix': 'B260', 'hash': 'b3e11316'},
    {'prefix': 'SS-', 'hash': 'ded15733'},
    {'prefix': 'SC-', 'hash': 'f14db19f'},
    {'prefix': 'SF-', 'hash': '3fd1cdb5'},
    {'prefix': 'SB-', 'hash': 'fc51c5cb'},
    {'prefix': 'iS-', 'hash': '1dcc50a7'},
    {'prefix': 'iO-', 'hash': 'aef67579'},
    {'prefix': 'iC-', 'hash': 'a0c1bce1'},
    {'prefix': 'iF-', 'hash': 'a0c1bce1'},
    {'prefix': 'SLI-', 'hash': '0e103c0b'},
    {'prefix': 'F79', 'hash': 'b94c37b2'},
    {'prefix': 'F78', 'hash': '7bd74382'},
    {'prefix': '151', 'hash': '6db307c3'},
    {'prefix': '156', 'hash': '999a058e'},
    {'prefix': '159', 'hash': '5118d06e'},
    {'prefix': 'A1-', 'hash': '5118d06e'},
    {'prefix': 'A2-', 'hash': '999a058e'},
    {'prefix': 'M04', 'hash': 'ce723f4b'},
    {'prefix': 'M40', 'hash': '200a1410'},
    {'prefix': 'M03', 'hash': '13596996'},
    {'prefix': 'M05', 'hash': '2cfa5183'},
  ];

  // Role keyword fallbacks for custom user-entered profile names
  final profileRoleKeywords = <Map<String, String>>[
    {'kw': 'ฉาก', 'hash': '3c052cea'},
    {'kw': 'คิ้ว', 'hash': '6be7223a'},
    {'kw': 'เสากุญแจ', 'hash': '685151f2'},
    {'kw': 'เสาเกี่ยว', 'hash': '1f65d563'},
    {'kw': 'ตบเกี่ยว', 'hash': 'f7e8daf3'},
    {'kw': 'เฟรมบน', 'hash': '809d85d0'},
    {'kw': 'เฟรมล่าง', 'hash': '51f67a71'},
    {'kw': 'เฟรมข้าง', 'hash': 'b1fdd5d1'},
    {'kw': 'กรอบบาน', 'hash': '2b5e8698'},
    {'kw': 'วงกบ', 'hash': '494c4785'},
    {'kw': 'ขวาง', 'hash': 'db7d7740'},
    {'kw': 'กล่อง', 'hash': '13596996'},
    {'kw': 'ราง', 'hash': '923d6928'},
  ];

  // 5. Hardware Code & Keyword Rules
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
    'HD-414': 'f1545b21',
    'HD-414D': 'f1545b21',
    'HD-414-C2': 'f1545b21',
    'HD-414-B': 'c3183fcd',
    '00-001': 'f1545b21',
    '00-030': 'ae8dc36a',
    '00-031': 'ae8dc36a',
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
    {'kw': 'มือจับกระทุ้ง', 'hash': 'b8e27ded'},
    {'kw': 'spindle', 'hash': 'b8e27ded'},
    {'kw': 'เขาควาย', 'hash': '3fa25e09'},
    {'kw': 'mortise lock', 'hash': '3fa25e09'},
    {'kw': 'มือจับบานพร้อมกุญแจ', 'hash': '3fa25e09'},
    {'kw': 'auto lock', 'hash': 'f1545b21'},
    {'kw': 'multi point', 'hash': 'f1545b21'},
    {'kw': 'multi-point', 'hash': 'f1545b21'},
    {'kw': 'multi-lock', 'hash': 'f1545b21'},
    {'kw': 'มัลติพอยท์', 'hash': 'f1545b21'},
    {'kw': 'มัลติพ้อย', 'hash': 'f1545b21'},
    {'kw': 'ยกล็อค', 'hash': 'f1545b21'},
    {'kw': 'hd-414', 'hash': 'f1545b21'},
    {'kw': 'ปากนกแก้ว', 'hash': 'ae8dc36a'},
    {'kw': 'มือจับฝัง', 'hash': 'c3183fcd'},
    {'kw': 'มือจับดัมมี่', 'hash': 'c3183fcd'},
    {'kw': 'dummy', 'hash': 'c3183fcd'},
    {'kw': 'มือจับ', 'hash': 'c3183fcd'},
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
    {'kw': 'อุปกรณ์', 'hash': 'f1545b21'},
    {'kw': 'ผู้ใช้กำหนด', 'hash': 'f1545b21'},
  ];

  // Collect EVERY referenced hash across all maps so we ONLY bundle needed assets!
  final referencedHashes = <String>{
    ...categoryHashes.values,
    ...systemHashes.values,
    ...patternHashes.values,
    ...profileCodeHashes.values,
    ...profilePrefixHashes.map((e) => e['hash']!),
    ...profileRoleKeywords.map((e) => e['hash']!),
    ...hardwareCodeHashes.values,
    ...hardwareKeywordRules.map((e) => e['hash']!),
  };

  if (missingJids.isNotEmpty) {
    final availCats = homeItems.map((e) => e['cat']).toSet().toList()..sort();
    throw StateError('Missing jids: $missingJids (available cats: $availCats)');
  }
  for (final h in referencedHashes) {
    if (!rawImagesByHash.containsKey(h)) {
      throw StateError('Referenced image hash $h does not exist in extracted AluProSmart JSON!');
    }
  }

  // Write compressed JPEGs to assets/alupro/
  final outAssetsDir = Directory('assets/alupro');
  if (outAssetsDir.existsSync()) {
    outAssetsDir.deleteSync(recursive: true);
  }
  outAssetsDir.createSync(recursive: true);

  int totalBytesWritten = 0;
  for (final h in referencedHashes.toList()..sort()) {
    final rawBytes = rawImagesByHash[h]!;
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw StateError('Failed to decode image for hash $h');
    }
    final reencoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 82));
    // Keep whichever is smaller (re-encoded Q82 vs original)
    final bestBytes = reencoded.length < rawBytes.length ? reencoded : rawBytes;
    final outFile = File('${outAssetsDir.path}/$h.jpg');
    await outFile.writeAsBytes(bestBytes);
    totalBytesWritten += bestBytes.length;
  }

  // Copy & optimize glass.jpg
  final glassRaw = await File(_glassDownloadPath).readAsBytes();
  final glassDecoded = img.decodeImage(glassRaw)!;
  final glassResized = glassDecoded.width > 320
      ? img.copyResize(glassDecoded, width: 320, interpolation: img.Interpolation.average)
      : glassDecoded;
  final glassEncoded = Uint8List.fromList(img.encodeJpg(glassResized, quality: 82));
  final glassBest = glassEncoded.length < glassRaw.length ? glassEncoded : glassRaw;
  await File('${outAssetsDir.path}/glass.jpg').writeAsBytes(glassBest);
  totalBytesWritten += glassBest.length;

  // Build assets/data/alupro_image_map.json
  Map<String, String> withExt(Map<String, String> m) =>
      m.map((k, v) => MapEntry(k, '$v.jpg'));

  final jsonPayload = <String, dynamic>{
    'glass': 'glass.jpg',
    'categories': withExt(categoryHashes),
    'brands': brandAssets,
    'systems': withExt(systemHashes),
    'patterns': withExt(patternHashes),
    'profiles': withExt(profileCodeHashes),
    'profilePrefixes': profilePrefixHashes
        .map((e) => {'prefix': e['prefix']!, 'file': '${e['hash']!}.jpg'})
        .toList(),
    'profileRoles': profileRoleKeywords
        .map((e) => {'kw': e['kw']!, 'file': '${e['hash']!}.jpg'})
        .toList(),
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
  final unmatchedCuts = <String>{};
  final unmatchedHw = <String>{};

  String? testResolveProfile(String code, String name) {
    final clean = code.trim();
    if (profileCodeHashes.containsKey(clean)) return profileCodeHashes[clean];
    for (final p in profilePrefixHashes) {
      if (clean.startsWith(p['prefix']!)) return p['hash'];
    }
    final combined = '$clean $name';
    for (final r in profileRoleKeywords) {
      if (combined.contains(r['kw']!)) return r['hash'];
    }
    return null;
  }

  String? testResolveHw(String code, String name) {
    final clean = code.trim();
    if (hardwareCodeHashes.containsKey(clean)) return hardwareCodeHashes[clean];
    final hay = '$clean $name'.toLowerCase();
    for (final r in hardwareKeywordRules) {
      if (hay.contains(r['kw']!.toLowerCase())) return r['hash'];
    }
    return null;
  }

  for (final item in formulasList) {
    final tbl = VerifiedFormulaTable.fromJson(item as Map<String, dynamic>);
    for (final c in tbl.cuts) {
      totalCuts++;
      if (testResolveProfile(c.code, c.name) != null) {
        matchedCuts++;
      } else {
        unmatchedCuts.add('${tbl.key}: ${c.code} (${c.name})');
      }
    }
    for (final h in tbl.hardware) {
      totalHw++;
      if (testResolveHw(h.code, h.name) != null) {
        matchedHw++;
      } else {
        unmatchedHw.add('${tbl.key}: ${h.code} | ${h.name}');
      }
    }
  }

  final ormSkus =
      jsonDecode(await File('assets/data/orm_prices_1139.json').readAsString())
          as List<dynamic>;
  int matchedSkus = 0;
  for (final s in ormSkus) {
    final sku = OrmPriceSku.fromJson(s as Map<String, dynamic>);
    if (testResolveProfile(sku.code, sku.name) != null) {
      matchedSkus++;
    }
  }

  print('=======================================================');
  print('Generated ${referencedHashes.length + 1} offline images in assets/alupro/');
  print('Total bundled image size: ${(totalBytesWritten / (1024 * 1024)).toStringAsFixed(2)} MB');
  print('Categories mapped : ${categoryHashes.length}/${CatalogDefinitions.categories.length}');
  print('Brands mapped     : ${brandAssets.length}');
  print('SubSystems mapped : ${systemHashes.length}');
  print('Patterns mapped   : ${patternHashes.length}');
  print('Formula Cuts      : $matchedCuts/$totalCuts (unmatched: ${unmatchedCuts.length})');
  print('Formula Hardware  : $matchedHw/$totalHw (unmatched: ${unmatchedHw.length})');
  print('Price SKUs        : $matchedSkus/${ormSkus.length}');
  if (unmatchedCuts.isNotEmpty) {
    print('Unmatched cuts: ${unmatchedCuts.take(10).join(" ; ")}');
  }
  if (unmatchedHw.isNotEmpty) {
    print('Unmatched hw: ${unmatchedHw.take(10).join(" ; ")}');
  }
  print('=======================================================');
}
