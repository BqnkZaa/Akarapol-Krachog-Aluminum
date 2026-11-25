import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/material_mutation_helper.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/engine/quotation_spec_formatter.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/screens/projects_and_quotation_screens.dart';
import 'package:toolkit_app/screens/result_and_pricing_screens.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (int i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    if (finder.evaluate().isNotEmpty) {
      // Allow any MaterialPageRoute transition / Hero flight to complete cleanly
      await tester.pump(const Duration(milliseconds: 450));
      return;
    }
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      (call) async {
        if (call.method == 'printingInfo') {
          return <String, dynamic>{
            'directPrint': false,
            'dynamicLayout': false,
            'canPrint': false,
            'canConvertHtml': false,
            'canShare': false,
            'canRaster': false,
          };
        }
        return null;
      },
    );
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

  test('Feature 3: All 3 mosquito screens exist on every operable profile, excluded on fixed windows, and resolve 100% pricing', () {
    int operableChecked = 0;
    int fixedChecked = 0;

    void inspectPatterns(
      List<PatternCardDef> patterns, {
      required String catId,
      required String brandTitle,
      required String brandKey,
      required String sysId,
      required String sysTitle,
    }) {
      for (final p in patterns) {
        if (!p.enabled) continue;
        final isFixed = CatalogDefinitions.isFixedOnlyPattern(
          p,
          categoryId: catId,
          systemId: sysId,
        );
        final groups = CatalogDefinitions.effectiveOptionGroupsFor(
          p,
          categoryId: catId,
          systemId: sysId,
        );
        final mosqGroups = groups.where((g) => g.id == 'mosquito').toList();

        if (isFixed) {
          fixedChecked++;
          expect(
            mosqGroups,
            isEmpty,
            reason: 'Fixed pattern ${p.id} (${p.title}) must NOT have mosquito options',
          );
        } else {
          operableChecked++;
          expect(
            mosqGroups,
            hasLength(1),
            reason: 'Operable pattern ${p.id} (${p.title}) must have mosquito option group',
          );
          final enabledIds = mosqGroups.first.choices
              .where((c) => c.enabled)
              .map((c) => c.id)
              .toSet();
          expect(
            enabledIds.contains('none'),
            isTrue,
            reason: '${p.id} must default to none',
          );
          expect(
            enabledIds.any((id) => id == 'fiber' || id == 'small_mkt' || id == 'true'),
            isTrue,
            reason: '${p.id} must include fiber mosquito option',
          );
          expect(
            enabledIds.contains('pleated'),
            isTrue,
            reason: '${p.id} must include pleated mosquito option',
          );
          expect(
            enabledIds.contains('security'),
            isTrue,
            reason: '${p.id} must include security mosquito option',
          );
        }
      }
    }

    for (final cat in CatalogDefinitions.categories) {
      for (final sys in cat.directSystems) {
        inspectPatterns(
          sys.patterns,
          catId: cat.id,
          brandTitle: cat.title,
          brandKey: 'MARKET',
          sysId: sys.id,
          sysTitle: sys.title,
        );
      }
      for (final b in cat.brands) {
        if (!b.enabled) continue;
        inspectPatterns(
          b.directPatterns,
          catId: cat.id,
          brandTitle: b.title,
          brandKey: b.priceBrandKey,
          sysId: b.id,
          sysTitle: b.subtitle,
        );
        for (final sys in b.systems) {
          inspectPatterns(
            sys.patterns,
            catId: cat.id,
            brandTitle: b.title,
            brandKey: b.priceBrandKey,
            sysId: sys.id,
            sysTitle: sys.title,
          );
          for (final tab in sys.subTabs) {
            inspectPatterns(
              tab.patterns,
              catId: cat.id,
              brandTitle: b.title,
              brandKey: b.priceBrandKey,
              sysId: tab.id,
              sysTitle: tab.title,
            );
          }
        }
      }
    }

    expect(fixedChecked, greaterThanOrEqualTo(5));
    expect(operableChecked, greaterThan(200));

    // Verify full calculation & 100% pricing match on representative systems (Market, ORM, NEX, Folding)
    final sampleIds = [
      'c1_pat_s2_alt',
      'c2_orm_s2_card',
      'c2_nex_s2_top_card',
      'c3_fuji_s2_card',
      'c4_sch_2l_card',
    ];

    for (final pid in sampleIds) {
      final found = CatalogDefinitions.findPatternById(pid);
      expect(found, isNotNull, reason: 'Pattern $pid should be resolvable');
      final pat = found!.pattern;
      final brandKey = found.brand?.priceBrandKey ?? 'MARKET';
      final brandTitle = found.brand?.title ?? found.category.title;
      final sysTitle = found.system?.title ?? found.brand?.subtitle ?? '';

      for (final mosqVal in ['fiber', 'pleated', 'security']) {
        final effGroups = CatalogDefinitions.effectiveOptionGroupsFor(pat);
        final mosqGrp = effGroups.firstWhere((g) => g.id == 'mosquito');
        final chosenId = mosqVal == 'fiber'
            ? mosqGrp.choices
                .firstWhere((c) =>
                    c.id == 'fiber' || c.id == 'small_mkt' || c.id == 'true')
                .id
            : mosqVal;

        final opts = {
          for (final g in effGroups) g.id: g.defaultValue,
          'mosquito': chosenId,
        };
        final row = pat.id.contains('_top_')
            ? const SizeRowInput(widthMm: 2000, heightMm: 2400, auxMm: 2000, qty: 1)
            : const SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1);

        final out = ParametricSystemResolver.calculate(
          brandTitle: brandTitle,
          priceBrandKey: brandKey,
          systemTitle: sysTitle,
          pattern: pat,
          selectedOptions: opts,
          sizeRows: [row],
        );

        final pricing = PricingEngine.evaluate(
          barGroups: out.barGroups,
          mode: PricingMode.actualLength,
          wastePercent: 20.0,
          selectedThickness: '1.2 มม.',
          selectedColor: 'อบดำ (8816)',
          ormCatalog: SeedRepository.instance.allCatalogPrices,
          customOverrides: const {},
          glasses: out.sets.expand((s) => s.glasses).toList(),
          hardware: out.hardware,
          includeHardware: true,
          hardwareCatalog: SeedRepository.instance.hardwareRates,
        );

        expect(
          pricing.matchedCount,
          pricing.totalCount,
          reason: '$pid + $mosqVal must have 100% matched aluminum prices',
        );

        if (mosqVal == 'pleated') {
          final pleatedHw =
              out.hardware.where((h) => h.code == 'MS-PLEATED').toList();
          expect(pleatedHw, hasLength(1));
          // For c2_nex_s2_top_card (W=2000, H=2400, H1=2000), operable area = 4.00 sq.m. (NOT 4.80!)
          expect(pleatedHw.first.decimalQty, 4.0);
          final pleatedLine = pricing.hardwareLines
              .firstWhere((l) => l.item.code == 'MS-PLEATED');
          expect(pleatedLine.lineCost, 4800.0); // 4.0 sq.m. * 1,200 Baht
        } else if (mosqVal == 'security') {
          expect(
            out.sets.first.cuts.any((c) => c.code == 'MS-SEC-F'),
            isTrue,
            reason: '$pid + security must inject security frame cuts',
          );
          expect(
            out.hardware.any((h) => h.code == 'MS-MESH-SEC'),
            isTrue,
            reason: '$pid + security must inject stainless mesh',
          );
        }
      }
    }

    // Verify QuotationSpecFormatter labels for all 3 mosquito types
    SavedProjectItem makeMosqItem(String m) => SavedProjectItem(
          projectId: 1,
          sortIndex: 0,
          brandTitle: 'ORM',
          priceBrandKey: 'ORM',
          systemTitle: 'บานเลื่อน',
          patternId: 'c2_orm_s2_card',
          patternTitle: 'บานเลื่อนสลับ 2 บาน',
          selectedOptions: {'mosquito': m},
          sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
          evaluatedSets: const [],
          hardware: const [],
        );
    expect(QuotationSpecFormatter.detectMosquitoNote(makeMosqItem('fiber')),
        'เสริมมุ้งไฟเบอร์');
    expect(QuotationSpecFormatter.detectMosquitoNote(makeMosqItem('pleated')),
        'เสริมมุ้งจีบ');
    expect(QuotationSpecFormatter.detectMosquitoNote(makeMosqItem('security')),
        'เสริมมุ้งนิรภัย (ตาข่ายสแตนเลส)');
    expect(QuotationSpecFormatter.detectMosquitoNote(makeMosqItem('none')),
        isNull);
  });

  test('Feature 4: LaborCostMode.percentOfMaterial computes exact labor % across both profit bases and survives SQLite + JSON backup', () async {
    final bMatOnly = PricingEngine.computeSellingBreakdown(
      materialCost: 10000.0,
      openingAreaSqM: 4.0,
      laborMode: LaborCostMode.percentOfMaterial,
      laborRate: 15.0,
      profitPercent: 25.0,
      profitBaseMode: ProfitBaseMode.materialOnly,
    );
    expect(bMatOnly.laborCost, 1500.0);
    expect(bMatOnly.profitAmount, 2500.0);
    expect(bMatOnly.suggestedSellingPrice, 14000.0);

    final bMatAndLabor = PricingEngine.computeSellingBreakdown(
      materialCost: 10000.0,
      openingAreaSqM: 4.0,
      laborMode: LaborCostMode.percentOfMaterial,
      laborRate: 20.0,
      profitPercent: 25.0,
      profitBaseMode: ProfitBaseMode.materialAndLabor,
    );
    expect(bMatAndLabor.laborCost, 2000.0);
    expect(bMatAndLabor.profitAmount, 3000.0); // (10000 + 2000) * 25%
    expect(bMatAndLabor.suggestedSellingPrice, 15000.0);

    // SQLite & JSON Backup persistence
    const pctDefaults = PricingMarkupDefaults(
      profitPercent: 30.0,
      profitBaseMode: ProfitBaseMode.materialAndLabor,
      laborMode: LaborCostMode.percentOfMaterial,
      laborRate: 18.0,
    );
    await AppDatabase.instance.savePricingMarkupDefaults(pctDefaults);
    final loaded = await AppDatabase.instance.getPricingMarkupDefaults();
    expect(loaded.laborMode, LaborCostMode.percentOfMaterial);
    expect(loaded.laborRate, 18.0);

    final backupJson = await AppDatabase.instance.exportPricesBackupJson();
    await AppDatabase.instance
        .savePricingMarkupDefaults(const PricingMarkupDefaults());
    await AppDatabase.instance.importPricesBackupJson(backupJson);
    final restored = await AppDatabase.instance.getPricingMarkupDefaults();
    expect(restored.laborMode, LaborCostMode.percentOfMaterial);
    expect(restored.laborRate, 18.0);

    await AppDatabase.instance
        .savePricingMarkupDefaults(const PricingMarkupDefaults());
  });

  test('Feature 1: MaterialMutationHelper.updateProjectItemQuantities scales cuts, glass, integer hw, and decimal sq.m. hw accurately', () {
    final found = CatalogDefinitions.findPatternById('c2_orm_s2_card')!;
    final out = ParametricSystemResolver.calculate(
      brandTitle: found.brand!.title,
      priceBrandKey: found.brand!.priceBrandKey,
      systemTitle: found.system!.title,
      pattern: found.pattern,
      selectedOptions: const {'mosquito': 'pleated'},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
    );
    final orig = SavedProjectItem(
      id: 99,
      projectId: 1,
      sortIndex: 0,
      brandTitle: out.brandTitle,
      priceBrandKey: out.priceBrandKey,
      systemTitle: out.systemTitle,
      patternId: out.patternId,
      patternTitle: out.patternTitle,
      selectedOptions: out.selectedOptions,
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
      evaluatedSets: out.sets,
      hardware: out.hardware,
    );

    final scaled = MaterialMutationHelper.updateProjectItemQuantities(orig, [3]);
    expect(scaled.totalUnits, 3);
    expect(scaled.totalOpeningAreaSqM, closeTo(12.0, 0.001));
    expect(
      scaled.evaluatedSets.first.cuts.first.totalQty,
      orig.evaluatedSets.first.cuts.first.totalQty * 3,
    );
    expect(
      scaled.evaluatedSets.first.glasses.first.totalPanels,
      orig.evaluatedSets.first.glasses.first.totalPanels * 3,
    );
    final pleated = scaled.hardware.firstWhere((h) => h.code == 'MS-PLEATED');
    expect(pleated.decimalQty, closeTo(12.0, 0.01));
  });

  testWidgets('Feature 1 + 2 E2E: Adjust qty inline, edit pattern/size/mosquito in-place without deleting, and edit saved quotation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final found = CatalogDefinitions.findPatternById('c2_nex_s2_card')!;
    final initOut = ParametricSystemResolver.calculate(
      brandTitle: found.brand!.title,
      priceBrandKey: found.brand!.priceBrandKey,
      systemTitle: found.system!.title,
      pattern: found.pattern,
      selectedOptions: {
        for (final g in CatalogDefinitions.effectiveOptionGroupsFor(found.pattern))
          g.id: g.defaultValue,
      },
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
    );

    late int projectId;
    late int itemId;
    await tester.runAsync(() async {
      await AppDatabase.instance.markPricingNoticeSeen();
      await AppDatabase.instance.saveShopInfo(
        const ShopInfo(
          shopName: 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
          proposerName: 'ฝ่ายขาย',
        ),
      );
      projectId = await AppDatabase.instance.createProject(name: 'บ้านทดสอบ v0.1.11');
      itemId = await AppDatabase.instance.addProjectItem(
        SavedProjectItem(
          projectId: projectId,
          sortIndex: 0,
          refCode: 'D1',
          installLocation: 'โถงหน้าบ้าน',
          brandTitle: initOut.brandTitle,
          priceBrandKey: initOut.priceBrandKey,
          systemTitle: initOut.systemTitle,
          patternId: initOut.patternId,
          patternTitle: initOut.patternTitle,
          selectedOptions: initOut.selectedOptions,
          sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
          evaluatedSets: initOut.sets,
          hardware: initOut.hardware,
        ),
      );
    });

    // 1. Open ProjectDetailScreen -> bump qty inline 1 -> 2
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: ProjectDetailScreen(projectId: projectId),
      ),
    );
    await _pumpUntilFound(tester, find.text('1 ชุด'));

    expect(find.text('1 ชุด'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('proj_qty_plus_$itemId')));
    await _pumpUntilFound(tester, find.text('2 ชุด'));
    expect(find.text('2 ชุด'), findsOneWidget);

    final afterQty = await tester.runAsync(
      () => AppDatabase.instance.getProject(projectId),
    );
    expect(afterQty!.items, hasLength(1));
    expect(afterQty.items.first.id, itemId);
    expect(afterQty.items.first.totalUnits, 2);

    // 2. Tap 'แก้ไขแบบ / ขนาด' -> select มุ้งจีบ -> recalculate -> save in-place!
    await tester.tap(find.byKey(ValueKey('proj_edit_pattern_$itemId')));
    await tester.pumpAndSettle();

    expect(find.text('คำนวณและอัปเดตงานเดิม'), findsOneWidget);
    expect(find.text('มุ้งจีบ'), findsOneWidget);
    await tester.tap(find.text('มุ้งจีบ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('คำนวณและอัปเดตงานเดิม'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('btn_save_result_middle')));
    await _pumpUntilFound(tester, find.byKey(ValueKey('proj_edit_pattern_$itemId')));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify in-place update: STILL 1 item, SAME id & refCode 'D1', NOW with pleated mosquito!
    final afterPatternEdit = await tester.runAsync(
      () => AppDatabase.instance.getProject(projectId),
    );
    expect(afterPatternEdit!.items, hasLength(1));
    expect(afterPatternEdit.items.first.id, itemId);
    expect(afterPatternEdit.items.first.refCode, 'D1');
    expect(afterPatternEdit.items.first.selectedOptions['mosquito'], 'pleated');
    expect(
      afterPatternEdit.items.first.hardware.any((h) => h.code == 'MS-PLEATED'),
      isTrue,
    );

    // 3. Save a quotation, open QuotationHistoryScreen, edit it & adjust qty
    late int qtId;
    await tester.runAsync(() async {
      qtId = await AppDatabase.instance.saveQuotation(
        SavedQuotation(
          projectId: projectId,
          qtNumber: 'QT-20261125-EDIT01',
          docTitle: 'ใบเสนอราคา',
          mode: 'ITEMIZED',
          issueDate: '25/11/2026',
          validUntil: '25/12/2026',
          customerName: 'คุณสมชาย (เดิม)',
          projectName: 'บ้านทดสอบ v0.1.11',
          lines: const [
            QuotationLineEntry(
              label: 'D1 · บานเลื่อนสลับ 2 บาน',
              subtitle: 'โปรไฟล์ ALUMET รุ่น NEX 200\nเสริมมุ้งจีบ',
              sizeText: '2000 × 2050 มม.',
              qty: 2,
              unitPrice: 12000.0,
              confirmed: true,
            ),
          ],
          lumpSumPrice: 24000.0,
          discount: 0,
          vatEnabled: false,
          subtotal: 24000.0,
          vatAmount: 0,
          netTotal: 24000.0,
          revisionTag: 'R1-1',
          createdAt: DateTime(2026, 11, 25),
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: QuotationHistoryScreen(projectId: projectId),
      ),
    );
    await _pumpUntilFound(tester, find.text('QT-20261125-EDIT01'));

    expect(find.text('QT-20261125-EDIT01'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qt_hist_edit_0')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('qt_btn_edit_project_patterns')),
    );

    // Verify edit-mode buttons & editable qty stepper on QuotationBuilderScreen
    expect(find.byKey(const ValueKey('qt_btn_edit_project_patterns')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('qt_btn_sync_project_items')),
        findsOneWidget);

    final listScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('qt_line_qty_plus_0')),
      220,
      scrollable: listScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qt_line_qty_plus_0')));
    await tester.pumpAndSettle();

    // Qty increased 2 -> 3, line total = 3 * 12,000 = 36,000.00!
    expect(find.text('รวม ฿36,000.00'), findsOneWidget);

    // Preview and overwrite existing quotation (keeps same qtNumber & id!)
    await tester.tap(find.text('ดูตัวอย่างใบเสนอราคา'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('qt_preview_save_btn')));

    expect(find.byKey(const ValueKey('qt_preview_save_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qt_preview_save_btn')));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('qt_preview_edit_btn')));

    final savedQts = await tester.runAsync(
      () => AppDatabase.instance.listQuotationsForProject(projectId),
    );
    expect(savedQts, hasLength(1));
    expect(savedQts!.first.id, qtId);
    expect(savedQts.first.qtNumber, 'QT-20261125-EDIT01');
    expect(savedQts.first.lines.first.qty, 3);
    expect(savedQts.first.netTotal, 36000.0);
  });

  testWidgets('Feature 4 UI: Labor % mode works live in PricingWorkspaceWidget and QuotationBuilderScreen', (tester) async {
    await tester.runAsync(() async {
      await AppDatabase.instance.markPricingNoticeSeen();
      await AppDatabase.instance
          .savePricingMarkupDefaults(const PricingMarkupDefaults());
    });
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.runAsync(() => AppDatabase.instance
          .savePricingMarkupDefaults(const PricingMarkupDefaults()));
    });

    final found = CatalogDefinitions.findPatternById('c2_nex_s2_card')!;
    final out = ParametricSystemResolver.calculate(
      brandTitle: found.brand!.title,
      priceBrandKey: found.brand!.priceBrandKey,
      systemTitle: found.system!.title,
      pattern: found.pattern,
      selectedOptions: {
        for (final g in CatalogDefinitions.effectiveOptionGroupsFor(found.pattern))
          g.id: g.defaultValue,
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
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    final rawMat = latest!.totalCost;
    final pctChip = find.byKey(const ValueKey('pricing_labor_pct_chip'));
    await tester.ensureVisible(pctChip);
    await tester.pumpAndSettle();
    await tester.tap(pctChip);
    await tester.pumpAndSettle();

    final laborField = find.byKey(const ValueKey('pricing_labor_rate_field'));
    await tester.enterText(laborField, '15');
    await tester.pumpAndSettle();

    expect(latest!.laborMode, LaborCostMode.percentOfMaterial);
    expect(latest!.laborRate, 15.0);
    expect(latest!.laborCost, PricingEngine.round2(rawMat * 0.15));
    expect(
      latest!.suggestedSellingPrice,
      PricingEngine.round2(rawMat + latest!.laborCost + latest!.profitAmount),
    );
  });
}
