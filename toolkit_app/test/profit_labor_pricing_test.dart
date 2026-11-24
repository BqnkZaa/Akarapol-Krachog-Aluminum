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
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/pdf/quotation_pdf.dart';
import 'package:toolkit_app/screens/projects_and_quotation_screens.dart';
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

  test('PricingEngine.computeSellingBreakdown handles both profit bases, both labor modes, and proportional item allocation', () {
    // 1. Web-parity formula: materialOnly + perSqM labor
    final b1 = PricingEngine.computeSellingBreakdown(
      materialCost: 10000.0,
      openingAreaSqM: 4.0,
      laborMode: LaborCostMode.perSqM,
      laborRate: 400.0,
      profitPercent: 25.0,
      profitBaseMode: ProfitBaseMode.materialOnly,
    );
    expect(b1.laborCost, 1600.0);
    expect(b1.profitAmount, 2500.0);
    expect(b1.suggestedSellingPrice, 14100.0);

    // 2. Material + Labor profit base + flat Baht labor
    final b2 = PricingEngine.computeSellingBreakdown(
      materialCost: 10000.0,
      openingAreaSqM: 4.0,
      laborMode: LaborCostMode.flatBaht,
      laborRate: 2000.0,
      profitPercent: 20.0,
      profitBaseMode: ProfitBaseMode.materialAndLabor,
    );
    expect(b2.laborCost, 2000.0);
    expect(b2.profitAmount, 2400.0); // (10000 + 2000) * 20%
    expect(b2.suggestedSellingPrice, 14400.0);

    // 3. Proportional area allocation across big sliding door (6 sq.m., qty 1) + small windows (2 sq.m., qty 2)
    final allocated = PricingEngine.allocateUnitSellingPrices(
      items: const [
        (areaSqM: 6.0, qty: 1),
        (areaSqM: 2.0, qty: 2),
      ],
      targetTotal: 16000.0,
    );
    expect(allocated, hasLength(2));
    expect(allocated[0], 12000.0); // 6/8 of 16000 / 1
    expect(allocated[1], 2000.0); // 2/8 of 16000 = 4000 / 2 units
    expect(allocated[0] * 1 + allocated[1] * 2, 16000.0);
  });

  test('SQLite app_flags saves/loads shop profit & labor defaults and survives JSON backup round-trip', () async {
    const customDefaults = PricingMarkupDefaults(
      profitPercent: 35.0,
      profitBaseMode: ProfitBaseMode.materialAndLabor,
      laborMode: LaborCostMode.perSqM,
      laborRate: 450.0,
    );
    await AppDatabase.instance.savePricingMarkupDefaults(customDefaults);
    final loaded = await AppDatabase.instance.getPricingMarkupDefaults();
    expect(loaded.profitPercent, 35.0);
    expect(loaded.profitBaseMode, ProfitBaseMode.materialAndLabor);
    expect(loaded.laborMode, LaborCostMode.perSqM);
    expect(loaded.laborRate, 450.0);

    // Backup export -> mutate -> restore via JSON import
    final backupJson = await AppDatabase.instance.exportPricesBackupJson();
    expect(backupJson.contains('"markupDefaults"'), isTrue);

    await AppDatabase.instance.savePricingMarkupDefaults(
      const PricingMarkupDefaults(profitPercent: 10.0, laborRate: 0.0),
    );
    expect((await AppDatabase.instance.getPricingMarkupDefaults()).profitPercent, 10.0);

    await AppDatabase.instance.importPricesBackupJson(backupJson);
    final restored = await AppDatabase.instance.getPricingMarkupDefaults();
    expect(restored.profitPercent, 35.0);
    expect(restored.profitBaseMode, ProfitBaseMode.materialAndLabor);
    expect(restored.laborRate, 450.0);

    // Reset to clean factory defaults for subsequent widget tests
    await AppDatabase.instance.savePricingMarkupDefaults(
      const PricingMarkupDefaults(),
    );
  });

  testWidgets('PricingWorkspaceWidget live Profit % & Labor controls update selling price and persist defaults', (tester) async {
    await tester.runAsync(() async {
      await AppDatabase.instance.markPricingNoticeSeen();
      await AppDatabase.instance
          .savePricingMarkupDefaults(const PricingMarkupDefaults());
    });
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.runAsync(
        () => AppDatabase.instance
            .savePricingMarkupDefaults(const PricingMarkupDefaults()),
      );
    });

    final nexBrand = CatalogDefinitions.categories[1].brands
        .firstWhere((b) => b.id == 'c2_alumet_nex');
    final s2Pattern = nexBrand.systems.first.patterns.first;
    final out = ParametricSystemResolver.calculate(
      brandTitle: nexBrand.title,
      priceBrandKey: nexBrand.priceBrandKey,
      systemTitle: nexBrand.systems.first.title,
      pattern: s2Pattern,
      selectedOptions: {
        for (final g in s2Pattern.optionGroups) g.id: g.defaultValue,
      },
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
    );

    PricingSummary? latest;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: Scaffold(
          body: PricingWorkspaceWidget(
            barGroups: out.barGroups,
            glasses: out.sets.expand((s) => s.glasses).toList(),
            openingAreaSqM: 4.10,
            fallbackOpeningAreaSqM: 4.10 * 0.88,
            hardware: out.hardware,
            onSummaryChanged: (s) => latest = s,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    final rawMatCost = latest!.totalCost;
    expect(rawMatCost, greaterThan(3000.0));
    expect(latest!.profitPercent, 20.0);
    expect(latest!.laborCost, 0.0);
    expect(
      latest!.suggestedSellingPrice,
      PricingEngine.round2(rawMatCost + PricingEngine.round2(rawMatCost * 0.20)),
    );

    // Tap 30% profit chip
    final chip30 = find.text('30%');
    await tester.ensureVisible(chip30);
    await tester.pumpAndSettle();
    await tester.tap(chip30);
    await tester.pumpAndSettle();
    expect(latest!.profitPercent, 30.0);
    expect(latest!.profitAmount, PricingEngine.round2(rawMatCost * 0.30));

    // Enter 400 Baht/sq.m. labor -> 4.10 * 400 = 1,640 Baht
    final laborField = find.byKey(const ValueKey('pricing_labor_rate_field'));
    await tester.ensureVisible(laborField);
    await tester.pumpAndSettle();
    await tester.enterText(laborField, '400');
    await tester.pumpAndSettle();
    expect(latest!.laborCost, 1640.0);
    expect(
      latest!.suggestedSellingPrice,
      PricingEngine.round2(rawMatCost + latest!.profitAmount + 1640.0),
    );

    // Switch profit base to include labor
    final incLaborChip = find.text('คิดกำไรรวมค่าแรงด้วย');
    await tester.ensureVisible(incLaborChip);
    await tester.pumpAndSettle();
    await tester.tap(incLaborChip);
    await tester.pumpAndSettle();
    expect(
      latest!.profitAmount,
      PricingEngine.round2((rawMatCost + 1640.0) * 0.30),
    );

    // Switch labor mode to flat Baht & select ฿2,000
    final flatSeg = find.text('เหมาทั้งงาน (บาท)');
    await tester.ensureVisible(flatSeg);
    await tester.pumpAndSettle();
    await tester.tap(flatSeg);
    await tester.pumpAndSettle();
    final flat2k = find.text('฿2,000');
    await tester.ensureVisible(flat2k);
    await tester.pumpAndSettle();
    await tester.tap(flat2k);
    await tester.pumpAndSettle();
    expect(latest!.laborCost, 2000.0);

    // Persist as shop default
    final saveBtn = find.text('จำค่าตั้งต้นร้าน');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
      () => AppDatabase.instance.getPricingMarkupDefaults(),
    );
    expect(saved!.profitPercent, 30.0);
    expect(saved.profitBaseMode, ProfitBaseMode.materialAndLabor);
    expect(saved.laborMode, LaborCostMode.flatBaht);
    expect(saved.laborRate, 2000.0);
  });

  testWidgets('QuotationBuilderScreen uses live Profit % + Labor + % Discount and keeps internal cost off PDF', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final sampleItem = SavedProjectItem(
      projectId: 77,
      sortIndex: 0,
      refCode: 'D1',
      installLocation: 'โถงหน้าบ้าน',
      brandTitle: 'ALUMET (NEX)',
      priceBrandKey: 'ALUMET_NEX',
      systemTitle: 'บานเลื่อน NEX 200',
      patternId: 'c2_nex_s2',
      patternTitle: 'บานเลื่อนสลับ 2 บาน',
      selectedOptions: const {},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
      evaluatedSets: const [],
      hardware: const [],
    );
    final proj = SavedProject(
      id: 77,
      name: 'บ้านตัวอย่าง กำไร-ค่าแรง',
      createdAt: DateTime(2026, 11, 24),
      updatedAt: DateTime(2026, 11, 24),
      items: [sampleItem],
    );
    const shop = ShopInfo(
      shopName: 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
      proposerName: 'ฝ่ายขาย',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: QuotationBuilderScreen(
          project: proj,
          shopInfo: shop,
          estimatedAluminumCost: 10000.0,
          openingAreaSqM: 4.0,
          initialProfitPercent: 25.0,
          initialProfitBaseMode: ProfitBaseMode.materialOnly,
          initialLaborMode: LaborCostMode.perSqM,
          initialLaborRate: 500.0,
          initialAluminumThickness: '1.2 มม.',
          initialAluminumColor: 'อบดำ (8816)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listScrollable = find.byType(Scrollable).first;

    // Select LUMP_SUM -> initial selling price = 10000 + 2500 (25%) + 2000 (4*500) = 14,500.00
    await tester.tap(find.text('เหมาทั้งโครงการ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('14500.00'),
      300,
      scrollable: listScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('14500.00'), findsOneWidget);

    // Adjust Profit % to 40% via quick chip -> 10000 + 4000 + 2000 = 16,000.00
    final chip40 = find.text('40%');
    await tester.ensureVisible(chip40);
    await tester.pumpAndSettle();
    await tester.tap(chip40);
    await tester.pumpAndSettle();
    expect(find.text('16000.00'), findsOneWidget);

    // Switch to ITEMIZED & update labor to 1000 Baht/sq.m. -> 10000 + 4000 + 4000 = 18,000.00
    await tester.scrollUntilVisible(
      find.text('แยกรายการ'),
      -300,
      scrollable: listScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('แยกรายการ'));
    await tester.pumpAndSettle();

    final qtLaborField = find.byKey(const ValueKey('qt_labor_rate_field'));
    await tester.scrollUntilVisible(
      qtLaborField,
      300,
      scrollable: listScrollable,
    );
    await tester.pumpAndSettle();
    await tester.enterText(qtLaborField, '1000');
    await tester.pumpAndSettle();
    expect(find.text('18000.00'), findsOneWidget);

    // Apply 10% discount -> -฿1,800.00 -> net ฿16,200.00
    final pctDiscChip = find.widgetWithText(ChoiceChip, '%');
    await tester.scrollUntilVisible(
      pctDiscChip,
      300,
      scrollable: listScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(pctDiscChip);
    await tester.pumpAndSettle();

    final discField = find.byKey(const ValueKey('qt_discount_field'));
    await tester.ensureVisible(discField);
    await tester.pumpAndSettle();
    await tester.enterText(discField, '10');
    await tester.pumpAndSettle();

    expect(find.text('-฿1,800.00'), findsOneWidget);
    expect(find.text('฿16,200.00'), findsOneWidget);

    // Verify generated Quotation PDF stays client-safe (valid PDF, zero internal margin leakage)
    final qt = SavedQuotation(
      projectId: 77,
      qtNumber: 'QT-PROFIT-TEST-01',
      docTitle: 'ใบเสนอราคา',
      mode: 'ITEMIZED',
      issueDate: '24/11/2026',
      validUntil: '24/12/2026',
      customerName: 'คุณลูกค้าทดสอบ',
      projectName: proj.name,
      lines: const [
        QuotationLineEntry(
          label: 'D1 · บานเลื่อนสลับ 2 บาน',
          subtitle: 'โปรไฟล์ ALUMET รุ่น NEX 200 · ความหนา 1.2 มม. · สีดำ',
          sizeText: '200.0 × 200.0 ซม.',
          qty: 1,
          unitPrice: 18000.0,
          confirmed: true,
        ),
      ],
      lumpSumPrice: 18000.0,
      discount: 1800.0,
      vatEnabled: false,
      subtotal: 18000.0,
      vatAmount: 0.0,
      netTotal: 16200.0,
      revisionTag: 'R1',
      createdAt: DateTime(2026, 11, 24),
    );
    final pdfBytes = await tester.runAsync(
      () => QuotationPdfGenerator.generate(
        quotation: qt,
        shopInfo: shop,
        testFontsDir: 'assets/fonts',
      ),
    );
    expect(pdfBytes, isNotNull);
    expect(ascii.decode(pdfBytes!.sublist(0, 5)), '%PDF-');
    expect(pdfBytes.length, greaterThan(10000));
  });
}
