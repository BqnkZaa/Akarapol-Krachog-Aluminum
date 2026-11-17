import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/app_models.dart';
import 'alupro_image_registry.dart';

class SeedRepository {
  SeedRepository._();
  static final SeedRepository instance = SeedRepository._();

  bool _initialized = false;
  final Map<String, VerifiedFormulaTable> _formulaTables = {};
  final List<OrmPriceSku> _ormPrices = [];
  Map<String, dynamic> _staticContent = {};

  bool get isInitialized => _initialized;
  Map<String, VerifiedFormulaTable> get formulaTables => _formulaTables;
  List<OrmPriceSku> get ormPrices => _ormPrices;
  Map<String, dynamic> get staticContent => _staticContent;

  Future<void> ensureLoaded({String? testAssetsDir}) async {
    if (_initialized) return;

    final String formulasRaw =
        await _readJsonString('assets/data/formulas_168_verified.json', testAssetsDir);
    final String pricesRaw =
        await _readJsonString('assets/data/orm_prices_1139.json', testAssetsDir);
    final String staticRaw =
        await _readJsonString('assets/data/static_content.json', testAssetsDir);

    final List<dynamic> fList = jsonDecode(formulasRaw) as List<dynamic>;
    _formulaTables.clear();
    for (final item in fList) {
      final tbl = VerifiedFormulaTable.fromJson(item as Map<String, dynamic>);
      _formulaTables[tbl.key] = tbl;
    }

    final List<dynamic> pList = jsonDecode(pricesRaw) as List<dynamic>;
    _ormPrices
      ..clear()
      ..addAll(pList.map((e) => OrmPriceSku.fromJson(e as Map<String, dynamic>)));

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

    _initialized = true;
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

  VerifiedFormulaTable? getFormulaTable(String key) => _formulaTables[key];
}
