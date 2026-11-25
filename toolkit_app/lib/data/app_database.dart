import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/app_models.dart';

class CustomPriceOverride {
  final String skuKey;
  final String brand;
  final String code;
  final String name;
  final String thickness;
  final String color;
  final double stockM;
  final double pricePerBar;
  final bool inStock;

  const CustomPriceOverride({
    required this.skuKey,
    required this.brand,
    required this.code,
    required this.name,
    required this.thickness,
    required this.color,
    required this.stockM,
    required this.pricePerBar,
    this.inStock = true,
  });

  Map<String, dynamic> toMap() => {
        'sku_key': skuKey,
        'brand': brand,
        'code': code,
        'name': name,
        'thickness': thickness,
        'color': color,
        'stock_m': stockM,
        'price_per_bar': pricePerBar,
        'in_stock': inStock ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory CustomPriceOverride.fromMap(Map<String, dynamic> m) =>
       CustomPriceOverride(
        skuKey: m['sku_key'] as String,
        brand: m['brand'] as String,
        code: m['code'] as String,
        name: m['name'] as String? ?? '',
        thickness: m['thickness'] as String,
        color: m['color'] as String,
        stockM: (m['stock_m'] as num?)?.toDouble() ?? 6.4,
        pricePerBar: (m['price_per_bar'] as num).toDouble(),
        inStock: (m['in_stock'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toJson() => {
        'skuKey': skuKey,
        'brand': brand,
        'code': code,
        'name': name,
        'thickness': thickness,
        'color': color,
        'stockM': stockM,
        'pricePerBar': pricePerBar,
        'inStock': inStock,
      };

  factory CustomPriceOverride.fromJson(Map<String, dynamic> j) =>
      CustomPriceOverride(
        skuKey: j['skuKey'] as String,
        brand: j['brand'] as String,
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        thickness: j['thickness'] as String,
        color: j['color'] as String,
        stockM: (j['stockM'] as num?)?.toDouble() ?? 6.4,
        pricePerBar: (j['pricePerBar'] as num).toDouble(),
        inStock: j['inStock'] as bool? ?? true,
      );
}

class CustomMaterialRateOverride {
  final String rateKey;
  final String category; // 'GLASS' | 'HARDWARE'
  final String code;
  final String name;
  final String unit;
  final double price;

  const CustomMaterialRateOverride({
    required this.rateKey,
    required this.category,
    required this.code,
    required this.name,
    required this.unit,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
        'rate_key': rateKey,
        'category': category,
        'code': code,
        'name': name,
        'unit': unit,
        'price': price,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory CustomMaterialRateOverride.fromMap(Map<String, dynamic> m) =>
      CustomMaterialRateOverride(
        rateKey: m['rate_key'] as String,
        category: m['category'] as String,
        code: m['code'] as String? ?? '',
        name: m['name'] as String? ?? '',
        unit: m['unit'] as String? ?? 'ชิ้น',
        price: (m['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'rateKey': rateKey,
        'category': category,
        'code': code,
        'name': name,
        'unit': unit,
        'price': price,
      };

  factory CustomMaterialRateOverride.fromJson(Map<String, dynamic> j) =>
      CustomMaterialRateOverride(
        rateKey: j['rateKey'] as String,
        category: j['category'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        unit: j['unit'] as String? ?? 'ชิ้น',
        price: (j['price'] as num).toDouble(),
      );
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Map<String, CustomPriceOverride>? _cachedCustomPrices;
  Map<String, CustomMaterialRateOverride>? _cachedMaterialRates;
  bool? _cachedPricingNoticeSeen;
  PricingMarkupDefaults? _cachedMarkupDefaults;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'akkaraphon_toolkit_v1.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) => _ensureAllTables(db),
      onUpgrade: (db, _, _) => _ensureAllTables(db),
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> initForTesting(Database testDb) async {
    _db = testDb;
    _cachedCustomPrices = {};
    _cachedMaterialRates = {};
    _cachedPricingNoticeSeen = false;
    _cachedMarkupDefaults = const PricingMarkupDefaults();
    await _ensureAllTables(testDb);
  }

  Future<void> _ensureAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_flags (
        flag_key TEXT PRIMARY KEY,
        flag_value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_info (
        id INTEGER PRIMARY KEY,
        shop_name TEXT NOT NULL DEFAULT '',
        default_doc_title TEXT NOT NULL DEFAULT 'ใบเสนอราคา',
        proposer_name TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        tax_id TEXT NOT NULL DEFAULT '',
        logo_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_prices (
        sku_key TEXT PRIMARY KEY,
        brand TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        thickness TEXT NOT NULL,
        color TEXT NOT NULL,
        stock_m REAL NOT NULL DEFAULT 6.4,
        price_per_bar REAL NOT NULL,
        in_stock INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_material_rates (
        rate_key TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        code TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'ชิ้น',
        price REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_profile_systems (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        brand_id TEXT NOT NULL,
        brand_title TEXT NOT NULL,
        price_brand_key TEXT NOT NULL,
        brand_logo_path TEXT,
        system_title TEXT NOT NULL,
        pattern_title TEXT NOT NULL,
        pattern_subtitle TEXT NOT NULL DEFAULT '',
        pattern_image_path TEXT,
        table_mode TEXT NOT NULL DEFAULT 'standardMultiRow',
        aux_type TEXT NOT NULL DEFAULT 'none',
        aux_label TEXT,
        formula_json TEXT NOT NULL,
        profile_images_json TEXT NOT NULL DEFAULT '{}',
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        sort_index INTEGER NOT NULL DEFAULT 0,
        ref_code TEXT NOT NULL DEFAULT '',
        install_location TEXT NOT NULL DEFAULT '',
        brand_title TEXT NOT NULL,
        price_brand_key TEXT NOT NULL,
        system_title TEXT NOT NULL,
        pattern_id TEXT NOT NULL,
        pattern_title TEXT NOT NULL,
        selected_options_json TEXT NOT NULL,
        size_rows_json TEXT NOT NULL,
        evaluated_sets_json TEXT NOT NULL,
        hardware_json TEXT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        qt_number TEXT NOT NULL UNIQUE,
        doc_title TEXT NOT NULL,
        mode TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        valid_until TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_address TEXT NOT NULL DEFAULT '',
        customer_contact TEXT NOT NULL DEFAULT '',
        project_name TEXT NOT NULL,
        project_location TEXT NOT NULL DEFAULT '',
        lines_json TEXT NOT NULL,
        lump_sum_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        vat_enabled INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        vat_amount REAL NOT NULL DEFAULT 0,
        net_total REAL NOT NULL DEFAULT 0,
        payment_terms TEXT NOT NULL DEFAULT '',
        lead_time TEXT NOT NULL DEFAULT '',
        warranty TEXT NOT NULL DEFAULT '',
        remarks TEXT NOT NULL DEFAULT '',
        revision_tag TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Pricing Beta Notice Flag ---
  Future<bool> hasSeenPricingNotice() async {
    if (_cachedPricingNoticeSeen != null) return _cachedPricingNoticeSeen!;
    final db = await database;
    final rows = await db.query(
      'app_flags',
      where: 'flag_key = ?',
      whereArgs: ['pricing_beta_ack'],
    );
    _cachedPricingNoticeSeen = rows.isNotEmpty;
    return _cachedPricingNoticeSeen!;
  }

  Future<void> markPricingNoticeSeen() async {
    _cachedPricingNoticeSeen = true;
    final db = await database;
    await db.insert(
      'app_flags',
      {'flag_key': 'pricing_beta_ack', 'flag_value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Default Shop Profit % & Labor Cost (stored in app_flags, zero schema migration) ---
  Future<PricingMarkupDefaults> getPricingMarkupDefaults() async {
    if (_cachedMarkupDefaults != null) return _cachedMarkupDefaults!;
    final db = await database;
    final rows = await db.query(
      'app_flags',
      where: 'flag_key = ?',
      whereArgs: ['default_pricing_markup'],
    );
    if (rows.isEmpty) {
      _cachedMarkupDefaults = const PricingMarkupDefaults();
      return _cachedMarkupDefaults!;
    }
    try {
      final raw = rows.first['flag_value'] as String;
      _cachedMarkupDefaults = PricingMarkupDefaults.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _cachedMarkupDefaults = const PricingMarkupDefaults();
    }
    return _cachedMarkupDefaults!;
  }

  Future<void> savePricingMarkupDefaults(PricingMarkupDefaults defaults) async {
    _cachedMarkupDefaults = defaults;
    final db = await database;
    await db.insert(
      'app_flags',
      {
        'flag_key': 'default_pricing_markup',
        'flag_value': jsonEncode(defaults.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Shop Info ---
  Future<ShopInfo> getShopInfo() async {
    final db = await database;
    final rows = await db.query('shop_info', where: 'id = 1');
    if (rows.isEmpty) return const ShopInfo();
    return ShopInfo.fromMap(rows.first);
  }

  Future<void> saveShopInfo(ShopInfo info) async {
    final db = await database;
    await db.insert(
      'shop_info',
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Custom Aluminum Profile Prices ---
  Future<Map<String, CustomPriceOverride>> getAllCustomPrices() async {
    if (_cachedCustomPrices != null) {
      return Map<String, CustomPriceOverride>.from(_cachedCustomPrices!);
    }
    final db = await database;
    final rows = await db.query('custom_prices');
    final map = <String, CustomPriceOverride>{};
    for (final r in rows) {
      final item = CustomPriceOverride.fromMap(r);
      map[item.skuKey] = item;
    }
    _cachedCustomPrices = map;
    return Map<String, CustomPriceOverride>.from(map);
  }

  Future<void> upsertCustomPrice(CustomPriceOverride override) async {
    final db = await database;
    await db.insert(
      'custom_prices',
      override.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedCustomPrices?[override.skuKey] = override;
  }

  Future<void> upsertCustomPricesBatch(List<CustomPriceOverride> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'custom_prices',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cachedCustomPrices?[item.skuKey] = item;
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteCustomPrice(String skuKey) async {
    final db = await database;
    await db.delete('custom_prices', where: 'sku_key = ?', whereArgs: [skuKey]);
    _cachedCustomPrices?.remove(skuKey);
  }

  Future<int> resetBrandCustomPrices({String? brandFilter}) async {
    final db = await database;
    if (brandFilter == null || brandFilter == 'ทั้งหมด') {
      _cachedCustomPrices?.clear();
      return db.delete('custom_prices');
    }
    _cachedCustomPrices?.removeWhere((_, v) => v.brand == brandFilter);
    return db.delete(
      'custom_prices',
      where: 'brand = ?',
      whereArgs: [brandFilter],
    );
  }

  Future<int> applyBulkPriceAdjustment({
    required List<OrmPriceSku> currentMergedSkus,
    String? brandFilter,
    String? colorFilter,
    required double percentDelta,
    double flatBahtDelta = 0.0,
  }) async {
    final targets = currentMergedSkus.where((s) {
      if (brandFilter != null &&
          brandFilter.isNotEmpty &&
          brandFilter != 'ทั้งหมด' &&
          s.brand != brandFilter) {
        return false;
      }
      if (colorFilter != null &&
          colorFilter.isNotEmpty &&
          colorFilter != 'ทั้งหมด' &&
          s.color != colorFilter) {
        return false;
      }
      return true;
    }).toList();

    if (targets.isEmpty) return 0;

    final db = await database;
    final batch = db.batch();
    for (final s in targets) {
      final rawNext =
          s.effectivePrice * (1.0 + percentDelta / 100.0) + flatBahtDelta;
      final nextPrice = ((rawNext < 0 ? 0.0 : rawNext) * 100.0).round() / 100.0;
      final ov = CustomPriceOverride(
        skuKey: s.skuKey,
        brand: s.brand,
        code: s.code,
        name: s.name,
        thickness: s.thickness,
        color: s.color,
        stockM: s.stockM,
        pricePerBar: nextPrice,
        inStock: s.inStock,
      );
      batch.insert(
        'custom_prices',
        ov.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cachedCustomPrices?[ov.skuKey] = ov;
    }
    await batch.commit(noResult: true);
    return targets.length;
  }

  // --- Custom Material Rates (Glass & Hardware) ---
  Future<Map<String, CustomMaterialRateOverride>>
      getAllCustomMaterialRates() async {
    if (_cachedMaterialRates != null) {
      return Map<String, CustomMaterialRateOverride>.from(
          _cachedMaterialRates!);
    }
    final db = await database;
    final rows = await db.query('custom_material_rates');
    final map = <String, CustomMaterialRateOverride>{};
    for (final r in rows) {
      final item = CustomMaterialRateOverride.fromMap(r);
      map[item.rateKey] = item;
    }
    _cachedMaterialRates = map;
    return Map<String, CustomMaterialRateOverride>.from(map);
  }

  Future<void> upsertCustomMaterialRate(
      CustomMaterialRateOverride override) async {
    final db = await database;
    await db.insert(
      'custom_material_rates',
      override.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedMaterialRates?[override.rateKey] = override;
  }

  Future<void> deleteCustomMaterialRate(String rateKey) async {
    final db = await database;
    await db.delete(
      'custom_material_rates',
      where: 'rate_key = ?',
      whereArgs: [rateKey],
    );
    _cachedMaterialRates?.remove(rateKey);
  }

  // --- Pricing JSON Backup Export / Import ---
  Future<String> exportPricesBackupJson() async {
    final profs = await getAllCustomPrices();
    final mats = await getAllCustomMaterialRates();
    final markup = await getPricingMarkupDefaults();
    final payload = {
      'type': 'akkaraphon_price_backup',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'profileOverrides': profs.values.map((e) => e.toJson()).toList(),
      'materialOverrides': mats.values.map((e) => e.toJson()).toList(),
      'markupDefaults': markup.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<({int profilesImported, int materialsImported})>
      importPricesBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final profList = (decoded['profileOverrides'] as List<dynamic>? ?? [])
        .map((e) => CustomPriceOverride.fromJson(e as Map<String, dynamic>))
        .toList();
    final matList = (decoded['materialOverrides'] as List<dynamic>? ?? [])
        .map((e) =>
            CustomMaterialRateOverride.fromJson(e as Map<String, dynamic>))
        .toList();

    final db = await database;
    final batch = db.batch();
    for (final pItem in profList) {
      batch.insert(
        'custom_prices',
        pItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cachedCustomPrices?[pItem.skuKey] = pItem;
    }
    for (final mItem in matList) {
      batch.insert(
        'custom_material_rates',
        mItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cachedMaterialRates?[mItem.rateKey] = mItem;
    }
    await batch.commit(noResult: true);
    if (decoded['markupDefaults'] is Map<String, dynamic>) {
      await savePricingMarkupDefaults(
        PricingMarkupDefaults.fromJson(
          decoded['markupDefaults'] as Map<String, dynamic>,
        ),
      );
    }
    return (
      profilesImported: profList.length,
      materialsImported: matList.length,
    );
  }

  // --- Custom Profile Systems (Studio) ---
  Future<List<CustomProfileSystem>> listCustomProfileSystems() async {
    final db = await database;
    final rows = await db.query(
      'custom_profile_systems',
      orderBy: 'updated_at DESC',
    );
    return rows.map(CustomProfileSystem.fromMap).toList();
  }

  Future<void> upsertCustomProfileSystem(CustomProfileSystem system) async {
    final db = await database;
    await db.insert(
      'custom_profile_systems',
      system.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomProfileSystem(String id) async {
    final db = await database;
    await db.delete(
      'custom_profile_systems',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Projects & Items ---
  Future<List<SavedProject>> listProjects() async {
    final db = await database;
    final pRows = await db.query('projects', orderBy: 'updated_at DESC');
    final result = <SavedProject>[];
    for (final pr in pRows) {
      final pid = pr['id'] as int;
      final itemRows = await db.query(
        'project_items',
        where: 'project_id = ?',
        whereArgs: [pid],
        orderBy: 'sort_index ASC, id ASC',
      );
      result.add(
        SavedProject(
          id: pid,
          name: pr['name'] as String,
          note: pr['note'] as String? ?? '',
          createdAt: DateTime.parse(pr['created_at'] as String),
          updatedAt: DateTime.parse(pr['updated_at'] as String),
          items: itemRows.map(SavedProjectItem.fromMap).toList(),
        ),
      );
    }
    return result;
  }

  Future<SavedProject?> getProject(int projectId) async {
    final db = await database;
    final pRows =
        await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (pRows.isEmpty) return null;
    final pr = pRows.first;
    final itemRows = await db.query(
      'project_items',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_index ASC, id ASC',
    );
    return SavedProject(
      id: projectId,
      name: pr['name'] as String,
      note: pr['note'] as String? ?? '',
      createdAt: DateTime.parse(pr['created_at'] as String),
      updatedAt: DateTime.parse(pr['updated_at'] as String),
      items: itemRows.map(SavedProjectItem.fromMap).toList(),
    );
  }

  Future<int> createProject({required String name, String note = ''}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('projects', {
      'name': name,
      'note': note,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateProjectMeta(int projectId,
      {required String name, required String note}) async {
    final db = await database;
    await db.update(
      'projects',
      {
        'name': name,
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<void> deleteProject(int projectId) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<int> addProjectItem(SavedProjectItem item) async {
    final db = await database;
    final existing = await db.query(
      'project_items',
      columns: ['id'],
      where: 'project_id = ?',
      whereArgs: [item.projectId],
    );
    final toInsert = SavedProjectItem(
      projectId: item.projectId,
      sortIndex: existing.length,
      refCode: item.refCode,
      installLocation: item.installLocation,
      brandTitle: item.brandTitle,
      priceBrandKey: item.priceBrandKey,
      systemTitle: item.systemTitle,
      patternId: item.patternId,
      patternTitle: item.patternTitle,
      selectedOptions: item.selectedOptions,
      sizeRows: item.sizeRows,
      evaluatedSets: item.evaluatedSets,
      hardware: item.hardware,
    );
    final id = await db.insert('project_items', toInsert.toMap());
    await db.update(
      'projects',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [item.projectId],
    );
    return id;
  }

  Future<void> updateProjectItemMeta(int itemId,
      {required String refCode, required String installLocation}) async {
    final db = await database;
    await db.update(
      'project_items',
      {
        'ref_code': refCode,
        'install_location': installLocation,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> updateProjectItemMaterials({
    required int itemId,
    required int projectId,
    required List<EvaluatedSetResult> evaluatedSets,
    required List<AggregatedHardwareItem> hardware,
  }) async {
    final db = await database;
    await db.update(
      'project_items',
      {
        'evaluated_sets_json':
            jsonEncode(evaluatedSets.map((e) => e.toJson()).toList()),
        'hardware_json': jsonEncode(hardware.map((e) => e.toJson()).toList()),
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    await db.update(
      'projects',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<void> deleteProjectItem(int itemId, int projectId) async {
    final db = await database;
    await db.delete('project_items', where: 'id = ?', whereArgs: [itemId]);
    await db.update(
      'projects',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  // --- Quotations ---
  Future<bool> isQuotationNumberUsed(String qtNumber) async {
    final db = await database;
    final rows = await db.query(
      'quotations',
      columns: ['id'],
      where: 'qt_number = ?',
      whereArgs: [qtNumber.trim()],
    );
    return rows.isNotEmpty;
  }

  Future<int> saveQuotation(SavedQuotation qt) async {
    final db = await database;
    return db.insert('quotations', qt.toMap());
  }

  Future<List<SavedQuotation>> listQuotationsForProject(int projectId) async {
    final db = await database;
    final rows = await db.query(
      'quotations',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SavedQuotation.fromMap).toList();
  }
}
