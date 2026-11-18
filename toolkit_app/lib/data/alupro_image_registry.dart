class AluproPrefixRule {
  final String prefix;
  final String file;

  const AluproPrefixRule({required this.prefix, required this.file});
}

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
  final Map<String, String> _systems = {};
  final Map<String, String> _patterns = {};
  final Map<String, String> _profiles = {};
  final List<AluproPrefixRule> _profilePrefixes = [];
  final List<AluproKeywordRule> _profileRoles = [];
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
    fillMap(_systems, json['systems']);
    fillMap(_patterns, json['patterns']);
    fillMap(_profiles, json['profiles']);
    fillMap(_hardwareCodes, json['hardwareCodes']);

    _profilePrefixes.clear();
    final rawPrefixes = json['profilePrefixes'];
    if (rawPrefixes is List) {
      for (final item in rawPrefixes) {
        if (item is Map) {
          final prefix = item['prefix']?.toString() ?? '';
          final file = item['file']?.toString() ?? '';
          if (prefix.isNotEmpty && file.isNotEmpty) {
            _profilePrefixes.add(AluproPrefixRule(prefix: prefix, file: file));
          }
        }
      }
    }

    _profileRoles.clear();
    final rawRoles = json['profileRoles'];
    if (rawRoles is List) {
      for (final item in rawRoles) {
        if (item is Map) {
          final kw = item['kw']?.toString().toLowerCase() ?? '';
          final file = item['file']?.toString() ?? '';
          if (kw.isNotEmpty && file.isNotEmpty) {
            _profileRoles.add(AluproKeywordRule(keywordLower: kw, file: file));
          }
        }
      }
    }

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

  String? _toAsset(String? file) {
    if (file == null || file.isEmpty) return null;
    if (file.startsWith('assets/')) return file;
    return '$_assetPrefix$file';
  }

  String? get glassAsset => _toAsset(_glassFile);

  String? resolveCategoryAsset(String categoryId) =>
      _toAsset(_categories[categoryId]);

  String? resolveBrandAsset(String brandId) =>
      _toAsset(_brands[brandId] ?? _defaultBrandLogos[brandId]);

  String? resolveSystemAsset(String systemId) => _toAsset(_systems[systemId]);

  String? resolvePatternAsset(String patternId) =>
      _toAsset(_patterns[patternId]);

  String? resolveProfileAsset({required String code, String name = ''}) {
    final clean = code.trim();
    if (clean.isNotEmpty) {
      final upper = clean.toUpperCase();
      final custom = _customProfileOverrides[clean] ?? _customProfileOverrides[upper];
      if (custom != null) return _toAsset(custom);

      final direct = _profiles[clean] ?? _profiles[upper];
      if (direct != null) return _toAsset(direct);

      if (clean.contains('/')) {
        for (final part in clean.split('/')) {
          final trimmed = part.trim();
          final sub = _profiles[trimmed] ?? _profiles[trimmed.toUpperCase()];
          if (sub != null) return _toAsset(sub);
        }
      }

      for (final rule in _profilePrefixes) {
        if (clean.startsWith(rule.prefix) ||
            upper.startsWith(rule.prefix.toUpperCase())) {
          return _toAsset(rule.file);
        }
      }
    }

    final hay = '$clean $name'.toLowerCase();
    for (final rule in _profileRoles) {
      if (hay.contains(rule.keywordLower)) {
        return _toAsset(rule.file);
      }
    }
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
