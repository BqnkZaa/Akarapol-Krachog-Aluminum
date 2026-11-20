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
import 'package:toolkit_app/pdf/single_cut_pdf.dart';
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

  test('100% of active patterns across all 8 brands resolve complete non-zero pricing', () {
    final allCatalog = SeedRepository.instance.allCatalogPrices;
    expect(allCatalog.length, greaterThan(3500));
    expect(SeedRepository.instance.glassRates.length, greaterThanOrEqualTo(15));
    expect(SeedRepository.instance.hardwareRates.length, greaterThan(200));

    int testedPatterns = 0;
    final unmatchedFailures = <String>[];

    void checkPatternList(
      String brandTitle,
      String brandKey,
      String sysTitle,
      List<PatternCardDef> patterns,
    ) {
      for (final p in patterns) {
        if (!p.enabled) continue;
        final opts = <String, String>{
          for (final g in p.optionGroups) g.id: g.defaultValue,
        };
        final out = ParametricSystemResolver.calculate(
          brandTitle: brandTitle,
          priceBrandKey: brandKey,
          systemTitle: sysTitle,
          pattern: p,
          selectedOptions: opts,
          sizeRows: const [
            SizeRowInput(widthMm: 2000, heightMm: 2050, auxMm: 1650, qty: 1),
          ],
          dripTrayLengthMm: 1200,
        );

        if (out.barGroups.isEmpty) continue;
        testedPatterns++;

        final avail = PricingEngine.computeAvailability(
          barGroups: out.barGroups,
          ormCatalog: allCatalog,
          customOverrides: const {},
        );
        expect(
          avail.availableColors,
          isNotEmpty,
          reason: '${p.id} ($brandKey) had empty availableColors',
        );
        expect(
          avail.availableThicknesses,
          isNotEmpty,
          reason: '${p.id} ($brandKey) had empty availableThicknesses',
        );

        final color = avail.availableColors.first;
        final thick = avail.availableThicknesses.contains('1.2 มม.')
            ? '1.2 มม.'
            : avail.availableThicknesses.first;

        final summary = PricingEngine.evaluate(
          barGroups: out.barGroups,
          mode: PricingMode.actualLength,
          wastePercent: 20.0,
          selectedThickness: thick,
          selectedColor: color,
          ormCatalog: allCatalog,
          customOverrides: const {},
        );

        if (summary.matchedCount < summary.totalCount ||
            summary.aluminumCost <= 0) {
          final missing = summary.lines
              .where((l) => !l.isMatched)
              .map((l) => '${l.group.brand}:${l.group.code}')
              .join(', ');
          unmatchedFailures.add(
            '${p.id} ($brandKey) matched ${summary.matchedCount}/${summary.totalCount} [missing: $missing]',
          );
        }
      }
    }

    for (final cat in CatalogDefinitions.categories) {
      for (final sys in cat.directSystems) {
        checkPatternList(cat.title, 'MARKET', sys.title, sys.patterns);
      }
      for (final b in cat.brands.where((b) => b.enabled)) {
        checkPatternList(b.title, b.priceBrandKey, b.subtitle, b.directPatterns);
        for (final sys in b.systems.where((s) => s.enabled)) {
          checkPatternList(b.title, b.priceBrandKey, sys.title, sys.patterns);
          for (final tab in sys.subTabs.where((t) => t.enabled)) {
            checkPatternList(b.title, b.priceBrandKey, tab.title, tab.patterns);
          }
        }
      }
    }

    expect(testedPatterns, greaterThan(220));
    expect(
      unmatchedFailures,
      isEmpty,
      reason: 'Unmatched patterns:\n${unmatchedFailures.join('\n')}',
    );
  });

  test('ALUMET Smart X 2-panel sliding matches exact 10/10 official ALUMET Hub 2569 prices + Glass + Hardware', () {
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

    expect(out.barGroups.length, 10);

    final summary = PricingEngine.evaluate(
      barGroups: out.barGroups,
      mode: PricingMode.actualLength,
      wastePercent: 20.0,
      selectedThickness: '1.2 มม.',
      selectedColor: 'อบดำ (8816)',
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: const {},
      glasses: out.sets.expand((s) => s.glasses).toList(),
      fallbackOpeningAreaSqM: (1950 * 2000) / 1000000.0 * 0.88,
      hardware: out.hardware,
      includeGlass: true,
      selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
      glassRatePerSqM: 205.0,
      includeHardware: true,
      hardwareCatalog: SeedRepository.instance.hardwareRates,
    );

    expect(summary.matchedCount, 10);
    expect(summary.totalCount, 10);
    expect(summary.aluminumCost, greaterThan(3500.0));
    expect(summary.glassCost, greaterThan(600.0));
    expect(summary.hardwareCost, greaterThan(300.0));
    expect(
      summary.totalCost,
      PricingEngine.round2(
          summary.aluminumCost + summary.glassCost + summary.hardwareCost),
    );

    // Check official ALUMET Hub 2569 bar prices on key codes
    final byCode = {for (final l in summary.lines) l.group.code: l.unitPricePerBar};
    expect(byCode['SS-X110'], 2410.0);
    expect(byCode['SS-X109'], 3010.0);
    expect(byCode['SS-X111'], 1645.0);
    expect(byCode['SS-X107 / SS-0120'], 595.0);
    expect(byCode['SS-0117'], 330.0);
    expect(byCode['SS-0138'], 1640.0);
    expect(byCode['SS-X217'], 1680.0);
    expect(byCode['SS-0139'], 645.0);
  });

  test('Missing code never locks out dropdowns, and Bulk Update + JSON Backup round-trip work accurately', () async {
    await AppDatabase.instance.resetBrandCustomPrices();

    final groups = [
      const ProfileBarGroup(
        brand: 'ALUMET',
        code: 'SS-X109',
        combinedNames: 'เฟรมล่าง',
        stockLengthMm: 6400,
        confirmedBars: [],
        estimatedBars: 1,
        exactCutSumMm: 2000,
      ),
      const ProfileBarGroup(
        brand: 'ALUMET',
        code: 'FUTURE-999',
        combinedNames: 'รหัสอนาคตยังไม่มีราคา',
        stockLengthMm: 6400,
        confirmedBars: [],
        estimatedBars: 1,
        exactCutSumMm: 2000,
      ),
    ];

    final avail = PricingEngine.computeAvailability(
      barGroups: groups,
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: const {},
    );
    expect(avail.isComplete, isFalse);
    expect(avail.availableColors, isNotEmpty);
    expect(avail.availableThicknesses, isNotEmpty);

    // Bulk +10% on ALUMET อบดำ (8816)
    final mergedBefore = PricingEngine.mergeProfileCatalog(
      SeedRepository.instance.allCatalogPrices,
      await AppDatabase.instance.getAllCustomPrices(),
    ).values.toList();

    final count = await AppDatabase.instance.applyBulkPriceAdjustment(
      currentMergedSkus: mergedBefore,
      brandFilter: 'ALUMET',
      colorFilter: 'อบดำ (8816)',
      percentDelta: 10.0,
    );
    expect(count, greaterThan(40));

    final ovAfter = await AppDatabase.instance.getAllCustomPrices();
    final ssX109After = PricingEngine.matchSku(
      brand: 'ALUMET',
      code: 'SS-X109',
      selectedThickness: '1.2 มม.',
      selectedColor: 'อบดำ (8816)',
      catalog: SeedRepository.instance.allCatalogPrices,
      overrides: ovAfter,
    );
    expect(ssX109After!.effectivePrice, 3311.0); // 3010 * 1.10 = 3311.0

    // Backup JSON export -> reset -> import round-trip
    final backupJson = await AppDatabase.instance.exportPricesBackupJson();
    await AppDatabase.instance.resetBrandCustomPrices();
    expect((await AppDatabase.instance.getAllCustomPrices()).isEmpty, isTrue);

    final imported =
        await AppDatabase.instance.importPricesBackupJson(backupJson);
    expect(imported.profilesImported, count);

    await AppDatabase.instance.resetBrandCustomPrices();
  });

  test('CustomProfileSystem E2E: save to SQLite -> merge into Catalog -> calculate -> price -> PDF', () async {
    final now = DateTime(2026, 11, 20);
    final customSys = CustomProfileSystem(
      id: 'cust_sys_tiger_2027',
      categoryId: 'cat3_euro',
      brandId: 'cust_brand_tiger',
      brandTitle: 'TIGER EURO 2027',
      priceBrandKey: 'TIGER',
      systemTitle: 'บานเลื่อน พรีเมียม',
      patternTitle: 'บานเลื่อนสลับ 2 บาน (TIGER)',
      patternSubtitle: 'ชุดโปรไฟล์ใหม่ทดสอบ',
      formulaTable: const VerifiedFormulaTable(
        key: 'cust_sys_tiger_2027',
        header: 'บานเลื่อนสลับ 2 บาน (TIGER)',
        cuts: [
          CutPieceSpec(
            section: 'วงกบ / เฟรม',
            code: 'TG-101',
            name: 'เฟรมบน',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 40',
          ),
          CutPieceSpec(
            section: 'วงกบ / เฟรม',
            code: 'TG-102',
            name: 'เฟรมข้าง',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H',
          ),
          CutPieceSpec(
            section: 'กรอบบาน',
            code: 'TG-201',
            name: 'เสากรอบบาน',
            stockMm: 6400,
            qty: 4,
            qtyText: '4 ชิ้น',
            angle: '45° / 45°',
            formula: 'H - 64',
          ),
        ],
        glasses: [
          GlassPieceSpec(
            name: 'กระจกบานเลื่อน TIGER',
            qty: 2,
            qtyText: '2 แผ่น',
            siteCut: false,
            wFormula: '(W / 2) - 70',
            hFormula: 'H - 150',
          ),
        ],
        hardware: [
          HardwareItemSpec(
            code: 'TG-HW1',
            name: 'ล้อคู่สแตนเลส TIGER',
            qtyText: '2 คู่',
          ),
        ],
      ),
      createdAt: now,
      updatedAt: now,
    );

    await AppDatabase.instance.upsertCustomProfileSystem(customSys);
    await AppDatabase.instance.upsertCustomPricesBatch(const [
      CustomPriceOverride(
        skuKey: 'TIGER|TG-101|1.2 มม.|อบดำ (8816)',
        brand: 'TIGER',
        code: 'TG-101',
        name: 'เฟรมบน',
        thickness: '1.2 มม.',
        color: 'อบดำ (8816)',
        stockM: 6.4,
        pricePerBar: 2150,
      ),
      CustomPriceOverride(
        skuKey: 'TIGER|TG-102|1.2 มม.|อบดำ (8816)',
        brand: 'TIGER',
        code: 'TG-102',
        name: 'เฟรมข้าง',
        thickness: '1.2 มม.',
        color: 'อบดำ (8816)',
        stockM: 6.4,
        pricePerBar: 1750,
      ),
      CustomPriceOverride(
        skuKey: 'TIGER|TG-201|1.2 มม.|อบดำ (8816)',
        brand: 'TIGER',
        code: 'TG-201',
        name: 'เสากรอบบาน',
        thickness: '1.2 มม.',
        color: 'อบดำ (8816)',
        stockM: 6.4,
        pricePerBar: 1890,
      ),
    ]);

    await SeedRepository.instance.reloadCustomSystems();
    final mergedCats = CatalogDefinitions.mergedCategories();
    final cat3 = mergedCats.firstWhere((c) => c.id == 'cat3_euro');
    expect(cat3.brands.any((b) => b.title == 'TIGER EURO 2027'), isTrue);

    final out = ParametricSystemResolver.calculate(
      brandTitle: customSys.brandTitle,
      priceBrandKey: customSys.priceBrandKey,
      systemTitle: customSys.systemTitle,
      pattern: customSys.toPatternCardDef(),
      selectedOptions: const {},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
    );

    expect(out.sets.single.cuts.first.lengthMm, 1960.0); // 2000 - 40
    expect(out.sets.single.glasses.first.widthMm, 930.0); // (2000 / 2) - 70
    expect(out.barGroups.length, 3);

    final ov = await AppDatabase.instance.getAllCustomPrices();
    final summary = PricingEngine.evaluate(
      barGroups: out.barGroups,
      mode: PricingMode.fullBars,
      wastePercent: 0,
      selectedThickness: '1.2 มม.',
      selectedColor: 'อบดำ (8816)',
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: ov,
    );
    expect(summary.matchedCount, 3);
    expect(summary.aluminumCost, greaterThan(5000.0));

    final savedItem = SavedProjectItem(
      projectId: 1,
      sortIndex: 0,
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
    expect(
      QuotationSpecFormatter.formatProfileSeriesName(savedItem),
      'โปรไฟล์ TIGER EURO 2027 รุ่น บานเลื่อน พรีเมียม',
    );

    final pdfBytes = await SingleCutPdfGenerator.generate(
      out,
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');

    // Clean up custom system & overrides so static catalog state is pristine
    await AppDatabase.instance.deleteCustomProfileSystem(customSys.id);
    await AppDatabase.instance.resetBrandCustomPrices();
    await SeedRepository.instance.reloadCustomSystems();
  });

  testWidgets('Tab 4 PricingWorkspaceWidget, 3-Tab CustomPriceScreen, and CustomSystemEditorScreen render cleanly', (tester) async {
    await tester.runAsync(() => AppDatabase.instance.markPricingNoticeSeen());
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: ResultScreen(
          output: out,
          sizeRows: const [SizeRowInput(widthMm: 1950, heightMm: 2000, qty: 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ทำราคา'));
    await tester.pumpAndSettle();

    expect(find.text('จับคู่ราคาเส้นได้ 10/10 รายการ'), findsOneWidget);
    expect(find.textContaining('฿0.00'), findsNothing);

    // Open 3-Tab Price Center
    await tester.tap(find.text('ศูนย์จัดการ/อัปเดตราคา'));
    await tester.pumpAndSettle();
    expect(find.text('ศูนย์จัดการและอัปเดตราคา'), findsOneWidget);
    expect(find.text('เส้นอลูมิเนียม'), findsOneWidget);
    expect(find.text('กระจก & อุปกรณ์'), findsOneWidget);
    expect(find.text('ปรับราคาทั้งชุด'), findsOneWidget);

    await tester.tap(find.text('ปรับราคาทั้งชุด'));
    await tester.pumpAndSettle();
    expect(find.text('ปรับราคาเส้นอลูมิเนียมขึ้น / ลง ทั้งชุด'), findsOneWidget);

    // Mount CustomSystemEditorScreen and check live formula preview
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: const CustomSystemEditorScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มชุดโปรไฟล์ใหม่'), findsOneWidget);
    expect(find.textContaining('ระยะตัดสด = 1950 มม.'), findsWidgets);
  });
}
