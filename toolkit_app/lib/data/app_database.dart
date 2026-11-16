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
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'akkaraphon_toolkit_v1.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> initForTesting(Database testDb) async {
    _db = testDb;
    await _onCreate(testDb, 1);
  }

  Future<void> _onCreate(Database db, int version) async {
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
    final db = await database;
    final rows = await db.query(
      'app_flags',
      where: 'flag_key = ?',
      whereArgs: ['pricing_beta_ack'],
    );
    return rows.isNotEmpty;
  }

  Future<void> markPricingNoticeSeen() async {
    final db = await database;
    await db.insert(
      'app_flags',
      {'flag_key': 'pricing_beta_ack', 'flag_value': '1'},
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

  // --- Custom Prices ---
  Future<Map<String, CustomPriceOverride>> getAllCustomPrices() async {
    final db = await database;
    final rows = await db.query('custom_prices');
    final map = <String, CustomPriceOverride>{};
    for (final r in rows) {
      final item = CustomPriceOverride.fromMap(r);
      map[item.skuKey] = item;
    }
    return map;
  }

  Future<void> upsertCustomPrice(CustomPriceOverride override) async {
    final db = await database;
    await db.insert(
      'custom_prices',
      override.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomPrice(String skuKey) async {
    final db = await database;
    await db.delete('custom_prices', where: 'sku_key = ?', whereArgs: [skuKey]);
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
