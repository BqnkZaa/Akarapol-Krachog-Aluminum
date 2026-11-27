import '../models/app_models.dart';

class AluproKeywordRule {
  final String keywordLower;
  final String file;

  const AluproKeywordRule({required this.keywordLower, required this.file});
}

class AluproImageRegistry {
  AluproImageRegistry._();
  static final AluproImageRegistry instance = AluproImageRegistry._();

  static const String _assetPrefix = 'assets/alupro/';

  String? _glassFile;
  final Map<String, String> _categories = {};
  final Map<String, String> _brands = {};
  final Map<String, String> _patterns = {};
  final Map<String, String> _profiles = {};
  final Map<String, String> _hardwareCodes = {};
  final List<AluproKeywordRule> _hardwareKeywords = [];

  // User-created custom profile system images (stored in app documents directory)
  final Map<String, String> _userBrandImages = {};
  final Map<String, String> _userPatternImages = {};
  final Map<String, String> _userProfileImages = {}; // 'BRAND|CODE' -> path

  bool get isLoaded => _patterns.isNotEmpty || _profiles.isNotEmpty;

  void loadFromJson(Map<String, dynamic> json) {
    _glassFile = json['glass'] as String?;

    void fillMap(Map<String, String> target, Object? raw) {
      target.clear();
      if (raw is Map) {
        for (final e in raw.entries) {
          final k = e.key.toString();
          final v = e.value?.toString() ?? '';
          if (k.isNotEmpty && v.isNotEmpty) {
            target[k] = v;
          }
        }
      }
    }

    fillMap(_categories, json['categories']);
    fillMap(_brands, json['brands']);
    fillMap(_patterns, json['patterns']);
    fillMap(_profiles, json['profiles']);
    fillMap(_hardwareCodes, json['hardwareCodes']);

    _hardwareKeywords.clear();
    final rawHwKeywords = json['hardwareKeywords'];
    if (rawHwKeywords is List) {
      for (final item in rawHwKeywords) {
        if (item is Map) {
          final kw = item['kw']?.toString().toLowerCase() ?? '';
          final file = item['file']?.toString() ?? '';
          if (kw.isNotEmpty && file.isNotEmpty) {
            _hardwareKeywords.add(
              AluproKeywordRule(keywordLower: kw, file: file),
            );
          }
        }
      }
    }
  }

  void syncCustomSystems(List<CustomProfileSystem> systems) {
    _userBrandImages.clear();
    _userPatternImages.clear();
    _userProfileImages.clear();

    for (final s in systems) {
      if (s.brandLogoPath != null && s.brandLogoPath!.trim().isNotEmpty) {
        _userBrandImages[s.brandId] = s.brandLogoPath!.trim();
      }
      if (s.patternImagePath != null && s.patternImagePath!.trim().isNotEmpty) {
        _userPatternImages[s.id] = s.patternImagePath!.trim();
      }
      final bUpper = s.priceBrandKey.trim().toUpperCase();
      for (final e in s.profileImagePaths.entries) {
        final cClean = e.key.trim();
        final imgPath = e.value.trim();
        if (cClean.isNotEmpty && imgPath.isNotEmpty) {
          _userProfileImages['$bUpper|$cClean'] = imgPath;
          _userProfileImages['$bUpper|${cClean.toUpperCase()}'] = imgPath;
        }
      }
    }
  }

  static const Map<String, String> _defaultCategoryLogos = {
    'cat1_market': 'assets/brands/cat1_market.png',
    'cat2_pattana': 'assets/brands/cat2_pattana.png',
    'cat3_euro': 'assets/brands/cat3_euro.png',
    'cat4_folding': 'assets/brands/cat4_folding.png',
    'cat5_shower': 'assets/brands/cat5_shower.png',
  };

  static const Map<String, String> _defaultBrandLogos = {
    'c2_orm': 'assets/brands/brand_orm.png',
    'c2_schimmer': 'assets/brands/brand_schimmer.png',
    'c2_alumet': 'assets/brands/brand_alumet.png',
    'c2_alumet_nex': 'assets/brands/brand_alumet_nex.png',
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

  static const Map<String, String> _customPatternOverrides = {
    'c2_nex_s2_card': 'assets/profiles/nex_pat_s2.png',
    'c2_nex_s2_top_card': 'assets/profiles/nex_pat_s2_top.png',
    'c2_nex_s3_card': 'assets/profiles/nex_pat_s3.png',
    'c2_nex_s4_card': 'assets/profiles/nex_pat_s4.png',
    'c2_nex_win1_card': 'assets/profiles/nex_pat_win1.png',
    'c2_nex_win1_bot_card': 'assets/profiles/nex_pat_win1_bot.png',
    'c2_nex_win1_top_card': 'assets/profiles/nex_pat_win1_top.png',
    'c2_nex_win2_card': 'assets/profiles/nex_pat_win2.png',
    'c2_nex_fix1_card': 'assets/profiles/nex_pat_fix1.png',
    'c2_nex_fix2_card': 'assets/profiles/nex_pat_fix2.png',
    'c2_nex_fix3_card': 'assets/profiles/nex_pat_fix3.png',
    'c2_nex_fix4_card': 'assets/profiles/nex_pat_fix4.png',
    'c2_alu_hang1_card': 'assets/profiles/alumet_pat_hang1.png',
    'c2_alu_hang2_card': 'assets/profiles/alumet_pat_hang2.png',
  };

  static const Map<String, String> _customProfileOverrides = {
    'SS-X219': 'assets/profiles/ss_x219.png',
    'SS-X206': 'assets/profiles/nex_ss_x206.png',
    'PS-0106': 'assets/profiles/nex_ps_0106.png',
    'PS-0107': 'assets/profiles/nex_ps_0107.png',
    'PS-0108': 'assets/profiles/nex_ps_0108.png',
    'PS-0109': 'assets/profiles/nex_ps_0109.png',
    'PS-0110': 'assets/profiles/nex_ps_0110.png',
    'PS-0111': 'assets/profiles/nex_ps_0111.png',
    'PS-0112': 'assets/profiles/nex_ps_0112.png',
    'PS-0113': 'assets/profiles/nex_ps_0113.png',
    'PS-0114': 'assets/profiles/nex_ps_0114.png',
    'PS-0206': 'assets/profiles/nex_ps_0206.png',
    'PS-0207': 'assets/profiles/nex_ps_0207.png',
    'PS-0208': 'assets/profiles/nex_ps_0208.png',
    'PS-0209': 'assets/profiles/nex_ps_0209.png',
    'PS-0210': 'assets/profiles/nex_ps_0210.png',
    'PC-0104': 'assets/profiles/nex_pc_0104.png',
    'PC-0105': 'assets/profiles/nex_pc_0105.png',
    'PC-0106': 'assets/profiles/nex_pc_0106.png',
    'PC-0107': 'assets/profiles/nex_pc_0107.png',
    'PC-0203': 'assets/profiles/nex_pc_0203.png',
    'PC-0204': 'assets/profiles/nex_pc_0204.png',
    'PC-0205': 'assets/profiles/nex_pc_0205.png',
    'PF-0101': 'assets/profiles/nex_pf_0101.png',
    'PF-0102': 'assets/profiles/nex_pf_0102.png',
    'PF-0103': 'assets/profiles/nex_pf_0103.png',
    'A30274': 'assets/profiles/nex_a30274.png',
    'A10261': 'assets/profiles/nex_a10261.png',
    '4011': 'assets/profiles/nex_4011.png',
    '4012': 'assets/profiles/nex_4012.png',
    '4016': 'assets/profiles/nex_4016.png',
    '2006': 'assets/profiles/nex_2006.png',
    '4017': 'assets/profiles/nex_4017.png',
    '2005': 'assets/profiles/nex_2005.png',
    '030065': 'assets/profiles/nex_030065.png',
    '010129': 'assets/profiles/nex_010129.png',
    '010009': 'assets/profiles/nex_010009.png',
    '010010': 'assets/profiles/nex_010010.png',
  };

  static final RegExp _thaiCharRegex = RegExp(r'[ก-๙]');

  static const Set<String> _alumetNexSharedCodes = {
    '030038',
    '4011',
    '4012',
    '4016',
    '2006',
    '4017',
    '2005',
    '030065',
    '010129',
    'A30274',
    'A10261',
    '010009',
    '010010',
  };

  bool _codeMatchesBrand(String cleanCode, String? brandKey) {
    if (brandKey == null || brandKey.isEmpty) return true;
    final upper = cleanCode.toUpperCase();
    switch (brandKey) {
      case 'MARKET':
        return _thaiCharRegex.hasMatch(cleanCode);
      case 'ORM':
        return cleanCode.startsWith('8');
      case 'SCHIMMER':
        return upper.startsWith('B');
      case 'ALUMET':
        return upper.startsWith('SS-') ||
            upper.startsWith('SC-') ||
            upper.startsWith('SF-') ||
            upper.startsWith('SB-') ||
            upper.startsWith('SO-') ||
            upper.startsWith('IS-') ||
            upper.startsWith('IO-') ||
            upper.startsWith('IC-') ||
            upper.startsWith('IF-') ||
            upper.startsWith('PS-') ||
            upper.startsWith('PC-') ||
            upper.startsWith('PF-') ||
            _alumetNexSharedCodes.contains(upper);
      case 'SMART_PLUS':
        return cleanCode.startsWith('151') || cleanCode.startsWith('152');
      case 'UAI':
        return upper.startsWith('SLI-') || cleanCode == '27490';
      case 'FUJI':
        return upper.startsWith('F7');
      case 'ALUFRAME':
        return cleanCode.startsWith('156') ||
            cleanCode.startsWith('159') ||
            cleanCode.startsWith('160') ||
            cleanCode == '42029' ||
            upper.startsWith('A1-') ||
            upper.startsWith('A2-');
      default:
        return false;
    }
  }

  String? _toAsset(String? file) {
    if (file == null || file.isEmpty) return null;
    if (file.startsWith('assets/')) return file;
    if (file.contains('/') || file.contains('\\')) return file;
    return '$_assetPrefix$file';
  }

  String? get glassAsset => _toAsset(_glassFile);

  String? resolveCategoryAsset(String categoryId) =>
      _toAsset(_categories[categoryId] ?? _defaultCategoryLogos[categoryId]);

  String? resolveBrandAsset(String brandId) => _toAsset(
      _userBrandImages[brandId] ?? _brands[brandId] ?? _defaultBrandLogos[brandId]);

  static final RegExp _alumetMatrixPatternRe = RegExp(
    r'^(?:c2_alu|c2_nex_win|c2_nex|c3_alu)_(case|awn|fix)_([1-5])_(plain|top|bot|tb)_card$',
  );

  /// Maps all ALUMET 6-album extended pattern IDs (Smart X, NEX, Iconiq, Folding)
  /// cleanly to the optimized official elevation PNGs in `assets/profiles/`.
  static String? _resolveAlumetPatternAsset(String patternId) {
    final m = _alumetMatrixPatternRe.firstMatch(patternId);
    if (m != null) {
      final fam = m.group(1)!;
      final n = m.group(2)!;
      final mode = m.group(3)!;
      final suffix = mode == 'plain' ? '' : '_$mode';
      return 'assets/profiles/alumet_pat_${fam}_$n$suffix.png';
    }

    // Folding Album #6 upgrades (including newly added 5-5-0 and 8-4-4)
    const foldingMap = {
      'fold_alu_3_3_0': 'assets/profiles/alumet_pat_fold_3_3_0.png',
      'fold_alu_3_2_1': 'assets/profiles/alumet_pat_fold_3_2_1.png',
      'fold_alu_4_2_2': 'assets/profiles/alumet_pat_fold_4_2_2.png',
      'fold_alu_4_3_1': 'assets/profiles/alumet_pat_fold_4_3_1.png',
      'fold_alu_5_5_0': 'assets/profiles/alumet_pat_fold_5_5_0.png',
      'fold_alu_6_5_1': 'assets/profiles/alumet_pat_fold_6_5_1.png',
      'fold_alu_6_3_3': 'assets/profiles/alumet_pat_fold_6_3_3.png',
      'fold_alu_8_4_4': 'assets/profiles/alumet_pat_fold_8_4_4.png',
    };
    if (foldingMap.containsKey(patternId)) return foldingMap[patternId];

    // ICONIQ-only Swing Door Album #5 (all 11 diagrams)
    const iconiqDoorMap = {
      'c3_alu_d1_card': 'assets/profiles/alumet_pat_door_1_glass.png',
      'c3_alu_d1_louver_card': 'assets/profiles/alumet_pat_door_1_louver.png',
      'c3_alu_d1_louver_frame_card':
          'assets/profiles/alumet_pat_door_1_louver_frame.png',
      'c3_alu_d1_side1_card': 'assets/profiles/alumet_pat_door_1_side1.png',
      'c3_alu_d2_card': 'assets/profiles/alumet_pat_door_2_glass.png',
      'c3_alu_d2_louver_card': 'assets/profiles/alumet_pat_door_2_louver.png',
      'c3_alu_d2_louver_frame_card':
          'assets/profiles/alumet_pat_door_2_louver_frame.png',
      'c3_alu_d2_top_card': 'assets/profiles/alumet_pat_door_2_top.png',
      'c3_alu_d2_arch_card': 'assets/profiles/alumet_pat_door_2_arch.png',
      'c3_alu_d2_louver_side2_glass_card':
          'assets/profiles/alumet_pat_door_2_louver_side2_glass.png',
      'c3_alu_d2_louver_side2_louver_card':
          'assets/profiles/alumet_pat_door_2_louver_side2_louver.png',
    };
    if (iconiqDoorMap.containsKey(patternId)) return iconiqDoorMap[patternId];

    // Existing Smart X & Iconiq window cards upgraded with clean ALUMET elevations
    const existingWindowMap = {
      'c2_alu_win1_card': 'assets/profiles/alumet_pat_case_1.png',
      'c2_alu_win3_card': 'assets/profiles/alumet_pat_case_2_top.png',
      'c2_alu_win4_card': 'assets/profiles/alumet_pat_awn_1.png',
      'c2_alu_win5_card': 'assets/profiles/alumet_pat_awn_1_top.png',
      'c2_alu_win6_card': 'assets/profiles/alumet_pat_awn_2.png',
      'c2_alu_win7_card': 'assets/profiles/alumet_pat_awn_2_top.png',
      'c3_alu_case1_card': 'assets/profiles/alumet_pat_case_1.png',
      'c3_alu_case2_card': 'assets/profiles/alumet_pat_case_2.png',
      'c3_alu_awn1_card': 'assets/profiles/alumet_pat_awn_1.png',
      'c3_alu_awn1_bot_card': 'assets/profiles/alumet_pat_awn_1_bot.png',
    };
    if (existingWindowMap.containsKey(patternId)) {
      return existingWindowMap[patternId];
    }

    // Sliding & Combo Album #1 across Smart X, NEX, and Iconiq
    if (patternId.startsWith('c2_alu_') ||
        patternId.startsWith('c2_nex_') ||
        patternId.startsWith('c3_alu_')) {
      if (patternId.endsWith('_s3_1f2s_card')) {
        return 'assets/profiles/alumet_pat_s3_1f2s.png';
      }
      if (patternId.endsWith('_s2_top2_card')) {
        return 'assets/profiles/alumet_pat_s2_top2.png';
      }
      if (patternId.endsWith('_s3_top_card')) {
        return 'assets/profiles/alumet_pat_s4_top4.png';
      }
      if (patternId.endsWith('_s4_top_card') ||
          patternId.endsWith('_s4_top4_card') ||
          patternId.endsWith('_s4_ctr_top_card')) {
        return 'assets/profiles/alumet_pat_s4_top4.png';
      }
      if (patternId.endsWith('_s4_arch_card')) {
        return 'assets/profiles/alumet_pat_s4_arch.png';
      }
      if (patternId.endsWith('_s3_1f2s_tb_asym_card')) {
        return 'assets/profiles/alumet_pat_s3_1f2s_tb_asym.png';
      }
      if (patternId.endsWith('_s3_1f2s_tb_card')) {
        return 'assets/profiles/alumet_pat_s3_1f2s_tb.png';
      }
      if (patternId.endsWith('_combo_c2_f3_card')) {
        return 'assets/profiles/alumet_pat_combo_c2_f3.png';
      }
      if (patternId.endsWith('_combo_c2_f3_bot_card')) {
        return 'assets/profiles/alumet_pat_combo_c2_f3_bot.png';
      }
      if (patternId == 'c2_alu_s2_card' || patternId == 'c3_alu_s2_card') {
        return 'assets/profiles/alumet_pat_s2.png';
      }
      if (patternId == 'c2_alu_s2_top_card' ||
          patternId == 'c3_alu_s2_top_card') {
        return 'assets/profiles/alumet_pat_s2_top1.png';
      }
      if (patternId == 'c2_alu_s3_card' || patternId == 'c3_alu_s3_card') {
        return 'assets/profiles/alumet_pat_s3_all.png';
      }
      if (patternId == 'c2_alu_s4_card' ||
          patternId == 'c3_alu_s4_ctr_card') {
        return 'assets/profiles/alumet_pat_s4.png';
      }
    }

    return null;
  }

  String? resolvePatternAsset(String patternId) => _toAsset(
      _userPatternImages[patternId] ??
          _customPatternOverrides[patternId] ??
          _resolveAlumetPatternAsset(patternId) ??
          _patterns[patternId]);

  /// Resolves ONLY exact 1:1 verified profile CAD cross-sections for the matching brand,
  /// plus any user-uploaded custom profile cross-section for that brand+code.
  String? resolveProfileAsset({
    required String code,
    String name = '',
    String? brandKey,
  }) {
    final clean = code.trim();
    if (clean.isEmpty) return null;

    if (brandKey != null && brandKey.isNotEmpty) {
      final bUpper = brandKey.trim().toUpperCase();
      final userImg = _userProfileImages['$bUpper|$clean'] ??
          _userProfileImages['$bUpper|${clean.toUpperCase()}'];
      if (userImg != null) return _toAsset(userImg);
    }

    if (!_codeMatchesBrand(clean, brandKey)) return null;

    final upper = clean.toUpperCase();
    final custom =
        _customProfileOverrides[clean] ?? _customProfileOverrides[upper];
    if (custom != null) return _toAsset(custom);

    final direct = _profiles[clean] ?? _profiles[upper];
    if (direct != null) return _toAsset(direct);

    return null;
  }

  String? resolveHardwareAsset({required String code, String name = ''}) {
    final clean = code.trim();
    if (clean.isNotEmpty) {
      final direct = _hardwareCodes[clean];
      if (direct != null) return _toAsset(direct);
    }

    final hay = '$clean $name'.toLowerCase();
    for (final rule in _hardwareKeywords) {
      if (hay.contains(rule.keywordLower)) {
        return _toAsset(rule.file);
      }
    }
    return null;
  }
}
