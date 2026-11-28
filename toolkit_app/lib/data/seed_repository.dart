import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/app_models.dart';
import 'alupro_image_registry.dart';
import 'app_database.dart';

class SeedRepository {
  SeedRepository._();
  static final SeedRepository instance = SeedRepository._();

  bool _initialized = false;
  final Map<String, VerifiedFormulaTable> _formulaTables = {};
  final Map<String, VerifiedFormulaTable> _customFormulaTables = {};
  final Map<String, PatternFormulaOverride> _formulaOverrides = {};
  final List<OrmPriceSku> _ormPrices = [];
  final List<OrmPriceSku> _allCatalogPrices = [];
  final List<MaterialRateItem> _glassRates = [];
  final List<MaterialRateItem> _hardwareRates = [];
  final List<CustomProfileSystem> _customSystems = [];
  Map<String, dynamic> _staticContent = {};

  bool get isInitialized => _initialized;
  Map<String, VerifiedFormulaTable> get formulaTables => _formulaTables;
  Map<String, PatternFormulaOverride> get formulaOverrides =>
      Map.unmodifiable(_formulaOverrides);
  List<OrmPriceSku> get ormPrices => _ormPrices;
  List<OrmPriceSku> get allCatalogPrices =>
      _allCatalogPrices.isNotEmpty ? _allCatalogPrices : _ormPrices;
  List<MaterialRateItem> get glassRates => _glassRates;
  List<MaterialRateItem> get hardwareRates => _hardwareRates;
  List<MaterialRateItem> get visibleHardwareRates =>
      _hardwareRates.where((r) => r.visibleInCatalog).toList();
  List<CustomProfileSystem> get customSystems => _customSystems;
  Map<String, dynamic> get staticContent => _staticContent;

  Future<void> ensureLoaded({String? testAssetsDir}) async {
    if (_initialized) return;

    final String formulasRaw = await _readJsonString(
      'assets/data/formulas_168_verified.json',
      testAssetsDir,
    );
    final String pricesRaw = await _readJsonString(
      'assets/data/orm_prices_1139.json',
      testAssetsDir,
    );
    final String staticRaw = await _readJsonString(
      'assets/data/static_content.json',
      testAssetsDir,
    );

    final List<dynamic> fList = jsonDecode(formulasRaw) as List<dynamic>;
    _formulaTables.clear();
    for (final item in fList) {
      final tbl = VerifiedFormulaTable.fromJson(item as Map<String, dynamic>);
      _formulaTables[tbl.key] = tbl;
    }

    final List<dynamic> pList = jsonDecode(pricesRaw) as List<dynamic>;
    _ormPrices
      ..clear()
      ..addAll(
          pList.map((e) => OrmPriceSku.fromJson(e as Map<String, dynamic>)));

    // Load complete multi-brand + glass + hardware seed catalog
    try {
      final String fullSeedRaw = await _readJsonString(
        'assets/data/catalog_prices_seed.json',
        testAssetsDir,
      );
      final Map<String, dynamic> fullMap =
          jsonDecode(fullSeedRaw) as Map<String, dynamic>;
      final List<dynamic> allProfs =
          fullMap['profiles'] as List<dynamic>? ?? [];
      final List<dynamic> gList = fullMap['glassRates'] as List<dynamic>? ?? [];
      final List<dynamic> hList =
          fullMap['hardwareRates'] as List<dynamic>? ?? [];

      _allCatalogPrices
        ..clear()
        ..addAll(allProfs
            .map((e) => OrmPriceSku.fromJson(e as Map<String, dynamic>)));
      _glassRates
        ..clear()
        ..addAll(gList
            .map((e) => MaterialRateItem.fromJson(e as Map<String, dynamic>)));
      _hardwareRates
        ..clear()
        ..addAll(hList
            .map((e) => MaterialRateItem.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      _allCatalogPrices
        ..clear()
        ..addAll(_ormPrices);
    }

    _staticContent = jsonDecode(staticRaw) as Map<String, dynamic>;

    try {
      final String imgMapRaw = await _readJsonString(
        'assets/data/alupro_image_map.json',
        testAssetsDir,
      );
      AluproImageRegistry.instance.loadFromJson(
        jsonDecode(imgMapRaw) as Map<String, dynamic>,
      );
    } catch (_) {
      final fallbackFile = File('assets/data/alupro_image_map.json');
      if (fallbackFile.existsSync()) {
        AluproImageRegistry.instance.loadFromJson(
          jsonDecode(await fallbackFile.readAsString()) as Map<String, dynamic>,
        );
      }
    }

    AluproImageRegistry.instance.syncHardwareCatalogImages(_hardwareRates);
    await reloadCustomSystems();
    await reloadFormulaOverrides();
    _initialized = true;
  }

  Future<void> reloadCustomSystems() async {
    try {
      final list = await AppDatabase.instance.listCustomProfileSystems();
      setCustomSystemsInMemory(list);
    } catch (_) {
      // Ignore when running pure-Dart formula tests without SQLite initialized
    }
  }

  Future<void> reloadFormulaOverrides() async {
    try {
      final map = await AppDatabase.instance.getAllFormulaOverrides();
      setFormulaOverridesInMemory(map);
    } catch (_) {
      // Ignore when running pure-Dart formula tests without SQLite initialized
    }
  }

  void setFormulaOverridesInMemory(Map<String, PatternFormulaOverride> map) {
    _formulaOverrides
      ..clear()
      ..addAll(map);
  }

  PatternFormulaOverride? getFormulaOverride(String patternId) =>
      _formulaOverrides[patternId];

  void setCustomSystemsInMemory(List<CustomProfileSystem> list) {
    _customSystems
      ..clear()
      ..addAll(list);
    _customFormulaTables.clear();
    for (final s in list) {
      _customFormulaTables[s.formulaTable.key] = s.formulaTable;
      _customFormulaTables[s.id] = s.formulaTable;
    }
    AluproImageRegistry.instance.syncCustomSystems(list);
  }

  Future<String> _readJsonString(String assetPath, String? testDir) async {
    if (testDir != null) {
      final fileName = assetPath.split('/').last;
      return File('$testDir/$fileName').readAsString();
    }
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      final localFile = File(assetPath);
      if (localFile.existsSync()) {
        return localFile.readAsString();
      }
      rethrow;
    }
  }

  VerifiedFormulaTable? getFormulaTable(String key) =>
      _customFormulaTables[key] ?? _formulaTables[key];
}
