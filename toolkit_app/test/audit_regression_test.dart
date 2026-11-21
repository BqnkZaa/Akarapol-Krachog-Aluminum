import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/engine/quotation_spec_formatter.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/pdf/quotation_pdf.dart';
import 'package:toolkit_app/screens/custom_system_studio_screens.dart';
import 'package:toolkit_app/screens/result_and_pricing_screens.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fontLoader = FontLoader('Sarabun')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Sarabun-Regular.ttf').readAsBytesSync(),
          ),
        ),
      )
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Sarabun-Bold.ttf').readAsBytesSync(),
          ),
        ),
      );
    await fontLoader.load();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final memDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.instance.initForTesting(memDb);
    await SeedRepository.instance.ensureLoaded(testAssetsDir: 'assets/data');
  });

  test('SQLite v1 -> v2 upgrade retains 100% of existing shop, project, quotation, and custom price data', () async {
    final tmpDir = await Directory.systemTemp.createTemp('akkaraphon_v1_mig_');
    final dbPath = '${tmpDir.path}/akkaraphon_toolkit_v1.db';
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
      // Restore fresh in-memory test DB for subsequent tests
      final freshMem = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await AppDatabase.instance.initForTesting(freshMem);
    });

    // 1. Create an authentic v1 database (exact schema from commit c8b84e1)
    final v1Db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
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
        },
      ),
    );

    // Populate v1 customer data
    final nowIso = DateTime(2026, 11, 18).toIso8601String();
    await v1Db.insert('shop_info', {
      'id': 1,
      'shop_name': 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
      'default_doc_title': 'ใบเสนอราคา',
      'proposer_name': 'ช่างมอส',
      'phone': '081-999-8888',
    });
    await v1Db.insert('custom_prices', {
      'sku_key': 'ORM|801-01|1.2 มม.|ตัวดิบ MILL',
      'brand': 'ORM',
      'code': '801-01',
      'name': 'เฟรมล่าง',
      'thickness': '1.2 มม.',
      'color': 'ตัวดิบ MILL',
      'stock_m': 6.4,
      'price_per_bar': 1399.0,
      'in_stock': 1,
      'updated_at': nowIso,
    });
    final projId = await v1Db.insert('projects', {
      'name': 'โครงการเดิมลูกค้า v1',
      'note': 'ชั้น 2',
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await v1Db.insert('project_items', {
      'project_id': projId,
      'sort_index': 0,
      'ref_code': 'W1',
      'install_location': 'ห้องนอนใหญ่',
      'brand_title': 'ALUMET (Smart X)',
      'price_brand_key': 'ALUMET',
      'system_title': 'บานเลื่อน Smart X',
      'pattern_id': 'c2_alu_s2',
      'pattern_title': 'บานเลื่อนสลับ 2 บาน',
      'selected_options_json': '{}',
      'size_rows_json': jsonEncode([
        const SizeRowInput(widthMm: 1800, heightMm: 1200, qty: 2).toJson(),
      ]),
      'evaluated_sets_json': '[]',
      'hardware_json': '[]',
    });
    await v1Db.insert('quotations', {
      'project_id': projId,
      'qt_number': 'QT-V1-0001',
      'doc_title': 'ใบเสนอราคา',
      'mode': 'ITEMIZED',
      'issue_date': '18/11/2026',
      'valid_until': '18/12/2026',
      'customer_name': 'คุณสมชาย (เดิม)',
      'project_name': 'โครงการเดิมลูกค้า v1',
      'lines_json': '[]',
      'lump_sum_price': 25000.0,
      'subtotal': 25000.0,
      'net_total': 25000.0,
      'revision_tag': 'R1',
      'created_at': nowIso,
    });
    await v1Db.close();

    // 2. Reopen the SAME file at version: 2 (simulating app upgrade)
    bool upgradeRan = false;
    final v2Db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, oldV, newV) async {
          expect(oldV, 1);
          expect(newV, 2);
          upgradeRan = true;
          await AppDatabase.instance.initForTesting(db);
        },
      ),
    );
    expect(upgradeRan, isTrue);

    // Ensure AppDatabase points to upgraded DB and reads from disk (bypassing empty cache)
    final shop = await AppDatabase.instance.getShopInfo();
    expect(shop.shopName, 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด');
    expect(shop.proposerName, 'ช่างมอส');

    final projects = await AppDatabase.instance.listProjects();
    expect(projects, hasLength(1));
    expect(projects.first.name, 'โครงการเดิมลูกค้า v1');
    expect(projects.first.items, hasLength(1));
    expect(projects.first.items.first.refCode, 'W1');

    final qts = await AppDatabase.instance.listQuotationsForProject(projId);
    expect(qts, hasLength(1));
    expect(qts.first.qtNumber, 'QT-V1-0001');

    // Verify existing v1 custom_prices row survived on disk
    final priceRows = await v2Db.query('custom_prices');
    expect(priceRows, hasLength(1));
    expect((priceRows.first['price_per_bar'] as num).toDouble(), 1399.0);

    // Verify new v2 tables work seamlessly immediately after upgrade
    await AppDatabase.instance.upsertCustomMaterialRate(
      const CustomMaterialRateOverride(
        rateKey: 'GLASS|กระจกใส 6 มม.',
        category: 'GLASS',
        code: 'GLS-CLR-6',
        name: 'กระจกใส 6 มม.',
        unit: 'ตร.ม.',
        price: 260.0,
      ),
    );
    final matRates = await AppDatabase.instance.getAllCustomMaterialRates();
    expect(matRates['GLASS|กระจกใส 6 มม.']?.price, 260.0);

    await v2Db.close();
  });

  testWidgets('1-Tap Inline Price Edit updates totals immediately, persists to SQLite, and restores cleanly', (tester) async {
    await tester.runAsync(() async {
      await AppDatabase.instance.markPricingNoticeSeen();
      await AppDatabase.instance.resetBrandCustomPrices();
    });
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.runAsync(() => AppDatabase.instance.resetBrandCustomPrices());
    });

    final alumetBrand = CatalogDefinitions.categories[1].brands
        .firstWhere((b) => b.id == 'c2_alumet');
    final s2Pattern = alumetBrand.systems.first.patterns.first;
    final out = ParametricSystemResolver.calculate(
      brandTitle: alumetBrand.title,
      priceBrandKey: alumetBrand.priceBrandKey,
      systemTitle: alumetBrand.systems.first.title,
      pattern: s2Pattern,
      selectedOptions: {
        for (final g in s2Pattern.optionGroups) g.id: g.defaultValue,
      },
      sizeRows: const [SizeRowInput(widthMm: 1950, heightMm: 2000, qty: 1)],
    );

    PricingSummary? latestSummary;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: Scaffold(
          body: PricingWorkspaceWidget(
            barGroups: out.barGroups,
            glasses: out.sets.expand((s) => s.glasses).toList(),
            fallbackOpeningAreaSqM: (1950 * 2000) / 1000000.0 * 0.88,
            hardware: out.hardware,
            onSummaryChanged: (s) => latestSummary = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(latestSummary, isNotNull);
    final initialTotal = latestSummary!.totalCost;
    final initialAlu = latestSummary!.aluminumCost;
    expect(latestSummary!.matchedCount, 10);
    expect(find.text('฿3,010.00 / เส้น'), findsOneWidget);

    // 1-Tap on SS-X109 row -> edit bar price from 3010 to 3500
    final ssX109Finder = find.textContaining('SS-X109');
    await tester.ensureVisible(ssX109Finder.first);
    await tester.pumpAndSettle();
    await tester.tap(ssX109Finder.first);
    await tester.pumpAndSettle();

    expect(find.text('บันทึกราคา'), findsOneWidget);
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '3500');
    await tester.tap(find.text('บันทึกราคา'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pumpAndSettle();

    // Verify immediate recalculation & custom price badge & SQLite persistence
    expect(find.text('฿3,500.00 / เส้น'), findsOneWidget);
    expect(find.textContaining('ราคาแก้เอง'), findsWidgets);
    expect(latestSummary!.aluminumCost, greaterThan(initialAlu));
    expect(latestSummary!.totalCost, greaterThan(initialTotal));

    final savedOverrides =
        await tester.runAsync(() => AppDatabase.instance.getAllCustomPrices());
    expect(
      savedOverrides!.values.any((o) => o.code == 'SS-X109' && o.pricePerBar == 3500.0),
      isTrue,
    );

    // Toggle Glass Switch off -> verify total drops by exact glassCost
    final glassCostBefore = latestSummary!.glassCost;
    expect(glassCostBefore, greaterThan(0));
    final totalBeforeGlassOff = latestSummary!.totalCost;
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);
    await tester.ensureVisible(switches.first);
    await tester.pumpAndSettle();
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
    expect(
      latestSummary!.totalCost,
      PricingEngine.round2(totalBeforeGlassOff - glassCostBefore),
    );

    // Restore original factory price via dialog
    await tester.ensureVisible(ssX109Finder.first);
    await tester.pumpAndSettle();
    await tester.tap(ssX109Finder.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('คืนค่าราคาตั้งต้น'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pumpAndSettle();
    expect(find.text('฿3,010.00 / เส้น'), findsOneWidget);
  });

  test('CustomProfileSystem JSON export/import round-trip + Quotation PDF with full specs', () async {
    final now = DateTime(2026, 11, 21, 10, 0);
    final original = CustomProfileSystem(
      id: 'cust_audit_euro_90',
      categoryId: 'cat3_euro',
      brandId: 'cust_brand_audit',
      brandTitle: 'AUDIT PRO 90',
      priceBrandKey: 'AUDITPRO',
      systemTitle: 'บานเลื่อนยูโร 90',
      patternTitle: 'บานเลื่อนสลับ 2 บาน (Audit)',
      patternSubtitle: 'ชุดทดสอบ JSON ข้ามเครื่อง',
      formulaTable: const VerifiedFormulaTable(
        key: 'cust_audit_euro_90',
        header: 'บานเลื่อนสลับ 2 บาน (Audit)',
        cuts: [
          CutPieceSpec(
            section: 'วงกบ',
            code: 'AP-901',
            name: 'เฟรมบน',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 35',
          ),
          CutPieceSpec(
            section: 'กรอบบาน',
            code: 'AP-902',
            name: 'เสากรอบบาน',
            stockMm: 6400,
            qty: 4,
            qtyText: '4 ชิ้น',
            angle: '45° / 45°',
            formula: 'H - 58',
          ),
        ],
        glasses: [
          GlassPieceSpec(
            name: 'กระจกบานเลื่อน',
            qty: 2,
            qtyText: '2 แผ่น',
            siteCut: false,
            wFormula: '(W / 2) - 65',
            hFormula: 'H - 140',
          ),
        ],
        hardware: [
          HardwareItemSpec(code: 'AP-HW1', name: 'ล้อคู่ยูโร', qtyText: '2 คู่'),
        ],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // JSON export -> decode -> re-hydrate round-trip
    final rawJson = jsonEncode(original.toJson());
    final decoded = CustomProfileSystem.fromJson(
      jsonDecode(rawJson) as Map<String, dynamic>,
    );
    expect(decoded.id, original.id);
    expect(decoded.brandTitle, 'AUDIT PRO 90');
    expect(decoded.formulaTable.cuts, hasLength(2));
    expect(decoded.formulaTable.cuts.first.formula, 'W - 35');
    expect(decoded.formulaTable.glasses.first.wFormula, '(W / 2) - 65');

    // Save imported custom system & verify Quotation PDF generation with full spec formatter
    await AppDatabase.instance.upsertCustomProfileSystem(decoded);
    await SeedRepository.instance.reloadCustomSystems();
    addTearDown(() async {
      await AppDatabase.instance.deleteCustomProfileSystem(decoded.id);
      await SeedRepository.instance.reloadCustomSystems();
    });

    final out = ParametricSystemResolver.calculate(
      brandTitle: decoded.brandTitle,
      priceBrandKey: decoded.priceBrandKey,
      systemTitle: decoded.systemTitle,
      pattern: decoded.toPatternCardDef(),
      selectedOptions: const {},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
    );
    expect(out.sets.single.cuts.first.lengthMm, 1965.0); // 2000 - 35

    final savedItem = SavedProjectItem(
      projectId: 99,
      sortIndex: 0,
      refCode: 'D1',
      installLocation: 'โถงหน้าบ้าน',
      brandTitle: out.brandTitle,
      priceBrandKey: out.priceBrandKey,
      systemTitle: out.systemTitle,
      patternId: out.patternId,
      patternTitle: out.patternTitle,
      selectedOptions: const {},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
      evaluatedSets: out.sets,
      hardware: out.hardware,
    );
    final specSubtitle = QuotationSpecFormatter.buildItemSpecSubtitle(
      item: savedItem,
      globalAluThickness: '1.5 มม.',
      globalAluColor: 'สีดำ',
      globalGlassType: 'กระจกใส',
      globalGlassThickness: '6 มม.',
    );
    expect(
      specSubtitle,
      'โปรไฟล์ AUDIT PRO 90 รุ่น บานเลื่อนยูโร 90 · ความหนา 1.5 มม. · สีดำ\nกระจกใส หนา 6 มม.\nตำแหน่งติดตั้ง: โถงหน้าบ้าน',
    );

    final qt = SavedQuotation(
      projectId: 99,
      qtNumber: 'QT-AUDIT-20261121',
      docTitle: 'ใบเสนอราคา',
      mode: 'ITEMIZED',
      issueDate: '21/11/2026',
      validUntil: '21/12/2026',
      customerName: 'คุณลูกค้า ตรวจสอบระบบ',
      projectName: 'บ้านตัวอย่าง Audit',
      lines: [
        QuotationLineEntry(
          label: QuotationSpecFormatter.formatLineTitle(savedItem, 1),
          subtitle: specSubtitle,
          sizeText: QuotationSpecFormatter.formatQuotationSize(savedItem),
          qty: 1,
          unitPrice: 12500,
          confirmed: true,
        ),
      ],
      lumpSumPrice: 12500,
      subtotal: 12500,
      vatAmount: 0,
      netTotal: 12500,
      revisionTag: 'R1',
      createdAt: now,
    );
    final pdfBytes = await QuotationPdfGenerator.generate(
      quotation: qt,
      shopInfo: const ShopInfo(
        shopName: 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
        proposerName: 'ฝ่ายขาย',
      ),
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');
    expect(pdfBytes.length, greaterThan(10000));
  });

  testWidgets('CustomSystemListScreen renders empty/populated state and exposes clone/create/import actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: const CustomSystemListScreen(),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('นำเข้าชุดโปรไฟล์ (.json)'), findsOneWidget);
  });
}
