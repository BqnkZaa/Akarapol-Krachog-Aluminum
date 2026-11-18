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

  static const Map<String, String> _customProfileOverrides = {
    'SS-X219': 'assets/profiles/ss_x219.png',
  };

  static final RegExp _thaiCharRegex = RegExp(r'[ก-๙]');

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
            cleanCode == '030038';
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
    return '$_assetPrefix$file';
  }

  String? get glassAsset => _toAsset(_glassFile);

  String? resolveCategoryAsset(String categoryId) =>
      _toAsset(_categories[categoryId] ?? _defaultCategoryLogos[categoryId]);

  String? resolveBrandAsset(String brandId) =>
      _toAsset(_brands[brandId] ?? _defaultBrandLogos[brandId]);

  String? resolvePatternAsset(String patternId) =>
      _toAsset(_patterns[patternId]);

  /// Resolves ONLY exact 1:1 verified profile CAD cross-sections for the matching brand.
  /// Never falls back across brands, prefixes, or generic role keywords.
  String? resolveProfileAsset({
    required String code,
    String name = '',
    String? brandKey,
  }) {
    final clean = code.trim();
    if (clean.isEmpty) return null;
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
