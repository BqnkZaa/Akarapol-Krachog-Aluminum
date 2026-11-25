import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/alupro_image_registry.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/bin_packer.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/screens/projects_and_quotation_screens.dart';

SavedProjectItem _makeProjectItem({
  required String patternId,
  required String orderTag,
  required int sortIndex,
  required double w,
  required double h,
  required int qty,
  Map<String, String>? optionsOverride,
}) {
  final found = CatalogDefinitions.findPatternById(patternId)!;
  final pat = found.pattern;
  final brand = found.brand!;
  final opts = optionsOverride ??
      {for (final g in pat.optionGroups) g.id: g.defaultValue};
  final rows = [SizeRowInput(widthMm: w, heightMm: h, qty: qty)];
  final out = ParametricSystemResolver.calculate(
    brandTitle: brand.title,
    priceBrandKey: brand.priceBrandKey,
    systemTitle: found.system?.title ?? brand.subtitle,
    pattern: pat,
    selectedOptions: opts,
    sizeRows: rows,
  );
  return SavedProjectItem(
    projectId: 1,
    sortIndex: sortIndex,
    refCode: orderTag,
    brandTitle: out.brandTitle,
    priceBrandKey: out.priceBrandKey,
    systemTitle: out.systemTitle,
    patternId: out.patternId,
    patternTitle: out.patternTitle,
    selectedOptions: out.selectedOptions,
    sizeRows: rows,
    evaluatedSets: out.sets,
    hardware: out.hardware,
  );
}

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
    AluproImageRegistry.instance.loadFromJson(
      jsonDecode(File('assets/data/alupro_image_map.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await AppDatabase.instance.saveShopInfo(
      const ShopInfo(
        shopName: 'บจก. อัครพลกระจกอลูมิเนียม',
        address: 'นนทบุรี',
        phone: '081-234-5678',
      ),
    );
  });

  group('v0.1.12 Feature 1: Per-Model Cost-Weighted Allocation (Customer 20:33 Bug Fix)', () {
    test('3 different ALUMET series of exact same size (2250x2950 x 4 sets) receive distinct cost-accurate unit selling prices', () {
      final items = [
        _makeProjectItem(
          patternId: 'c3_alu_s2_card',
          orderTag: '01',
          sortIndex: 0,
          w: 2250,
          h: 2950,
          qty: 4,
        ),
        _makeProjectItem(
          patternId: 'c2_alu_s2_card',
          orderTag: '02',
          sortIndex: 1,
          w: 2250,
          h: 2950,
          qty: 4,
          optionsOverride: const {
            'frame_join': '45',
            'thickness_tier': '1.5',
            'wheel_type': 'market',
          },
        ),
        _makeProjectItem(
          patternId: 'c2_nex_s2_card',
          orderTag: '03',
          sortIndex: 2,
          w: 2250,
          h: 2950,
          qty: 4,
          optionsOverride: const {
            'nex_series': 'nex200',
            'usage_type': 'door',
            'roller_type': 'cartridge',
            'mosquito': 'none',
          },
        ),
      ];

      // Confirm all 3 have identical opening area (same size & qty!)
      expect(items[0].totalOpeningAreaSqM, closeTo(items[1].totalOpeningAreaSqM, 0.001));
      expect(items[1].totalOpeningAreaSqM, closeTo(items[2].totalOpeningAreaSqM, 0.001));

      final packed = BinPacker.packProjectItems(items);
      final glasses = items.expand((i) => i.evaluatedSets.expand((s) => s.glasses)).toList();
      final totalArea = items.fold<double>(0.0, (s, i) => s + i.totalOpeningAreaSqM);

      for (final laborMode in LaborCostMode.values) {
        final laborRate = laborMode == LaborCostMode.perSqM
            ? 450.0
            : (laborMode == LaborCostMode.flatBaht ? 18000.0 : 15.0);
        final summary = PricingEngine.evaluate(
          barGroups: packed,
          mode: PricingMode.actualLength,
          wastePercent: 20.0,
          selectedThickness: '1.5 มม.',
          selectedColor: 'อบดำ (8816)',
          ormCatalog: SeedRepository.instance.allCatalogPrices,
          customOverrides: const {},
          glasses: glasses,
          openingAreaSqM: totalArea,
          fallbackOpeningAreaSqM: totalArea * 0.88,
          includeGlass: true,
          selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
          glassRatePerSqM: 205.0,
          includeHardware: false,
          laborMode: laborMode,
          laborRate: laborRate,
          profitPercent: 25.0,
          profitBaseMode: ProfitBaseMode.materialOnly,
        );

        final breakdowns = PricingEngine.evaluateProjectItems(
          items: items,
          projectSummary: summary,
          ormCatalog: SeedRepository.instance.allCatalogPrices,
          customOverrides: const {},
          hardwareCatalog: SeedRepository.instance.hardwareRates,
        );

        expect(breakdowns, hasLength(3));

        // All 3 models MUST have strictly distinct unit selling prices!
        final pIconiq = breakdowns[0].unitSellingPrice;
        final pSmartX = breakdowns[1].unitSellingPrice;
        final pNex = breakdowns[2].unitSellingPrice;
        expect(pIconiq, isNot(closeTo(pSmartX, 1.0)),
            reason: 'Iconiq ($pIconiq) and Smart X ($pSmartX) must NOT be equally averaged!');
        expect(pSmartX, isNot(closeTo(pNex, 1.0)),
            reason: 'Smart X ($pSmartX) and NEX ($pNex) must NOT be equally averaged!');
        expect(pIconiq, greaterThan(pNex),
            reason: 'Euro ICONIQ ($pIconiq) should be priced higher than slim NEX 200 ($pNex)');

        // Total of all allocated items matches project selling price cleanly
        final allocatedGrandTotal =
            breakdowns.fold<double>(0.0, (s, b) => s + b.suggestedTotalPrice);
        expect(allocatedGrandTotal, closeTo(summary.suggestedSellingPrice, 0.25));
      }
    });

    testWidgets('ProjectPricingScreen & QuotationBuilderScreen show distinct per-model unit prices and preserve cost ratios on live markup adjustment', (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final items = [
        _makeProjectItem(patternId: 'c3_alu_s2_card', orderTag: '01', sortIndex: 0, w: 2250, h: 2950, qty: 4),
        _makeProjectItem(patternId: 'c2_alu_s2_card', orderTag: '02', sortIndex: 1, w: 2250, h: 2950, qty: 4),
        _makeProjectItem(patternId: 'c2_nex_s2_card', orderTag: '03', sortIndex: 2, w: 2250, h: 2950, qty: 4),
      ];
      final proj = SavedProject(
        id: 77,
        name: 'บ้านทดสอบ 3 รุ่นขนาดเท่ากัน',
        createdAt: DateTime(2026, 11, 25),
        updatedAt: DateTime(2026, 11, 25),
        items: items,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: ProjectPricingScreen(project: proj),
        ),
      );
      await tester.pumpAndSettle();

      // Wait for PricingWorkspaceWidget's async SQLite overrides load to finish
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // Scroll to per-model breakdown card inside ProjectPricingScreen
      final cardFinder = find.byKey(const ValueKey('pricing_per_model_breakdown_card'));
      await tester.scrollUntilVisible(cardFinder, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(cardFinder, findsOneWidget);

      final p0Text = (tester.widget<Text>(find.byKey(const ValueKey('proj_model_unit_price_0'))).data ?? '');
      final p1Text = (tester.widget<Text>(find.byKey(const ValueKey('proj_model_unit_price_1'))).data ?? '');
      final p2Text = (tester.widget<Text>(find.byKey(const ValueKey('proj_model_unit_price_2'))).data ?? '');
      expect(p0Text, isNot(equals(p1Text)));
      expect(p1Text, isNot(equals(p2Text)));
      expect(p0Text, isNot(equals(p2Text)));

      // Navigate to QuotationBuilderScreen (wait for async SQLite getShopInfo)
      await tester.tap(find.textContaining('สร้างใบเสนอราคา'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.byType(QuotationBuilderScreen), findsOneWidget);

      // Scroll inside QuotationBuilderScreen to & select ITEMIZED mode
      final qtScroll = find.descendant(
        of: find.byType(QuotationBuilderScreen),
        matching: find.byType(Scrollable),
      ).first;
      final itemizedBtn = find.text('แยกรายการ');
      await tester.scrollUntilVisible(itemizedBtn, 300, scrollable: qtScroll);
      await tester.pumpAndSettle();
      await tester.tap(itemizedBtn);
      await tester.pumpAndSettle();

      // Scroll down until all 3 itemized cards are rendered in the ListView
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qt_line_qty_val_2')),
        300,
        scrollable: qtScroll,
      );
      await tester.pumpAndSettle();
      List<String> readQtUnitPrices() {
        return tester
            .widgetList<TextField>(
              find.descendant(
                of: find.byType(QuotationBuilderScreen),
                matching: find.byType(TextField),
              ),
            )
            .where((tf) {
              if (tf.decoration?.labelText != 'ราคาขาย / ชุด (บาท)') {
                return false;
              }
              final txt = tf.controller?.text ?? '';
              return RegExp(r'^\d+\.\d{2}$').hasMatch(txt) &&
                  double.parse(txt) > 100;
            })
            .map((tf) => tf.controller!.text)
            .take(3)
            .toList();
      }

      final qtPricesBefore = readQtUnitPrices();
      expect(qtPricesBefore, hasLength(3));
      expect(
        qtPricesBefore.toSet().length,
        3,
        reason: 'Quotation itemized unit prices must be distinct per model: $qtPricesBefore',
      );

      // Adjust Profit % to 40% live inside QuotationBuilderScreen -> all 3 must increase & stay distinct!
      final chip40 = find.widgetWithText(ChoiceChip, '40%');
      await tester.scrollUntilVisible(chip40, -300, scrollable: qtScroll);
      await tester.pumpAndSettle();
      await tester.tap(chip40);
      await tester.pumpAndSettle();

      // Scroll back down to the 3 itemized cards and verify all 3 increased & stay distinct!
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qt_line_qty_val_2')),
        300,
        scrollable: qtScroll,
      );
      await tester.pumpAndSettle();
      final qtPricesAfter = readQtUnitPrices();
      expect(qtPricesAfter, hasLength(3));
      expect(qtPricesAfter.toSet().length, 3,
          reason: 'Live markup change must preserve distinct per-model prices: $qtPricesAfter');
      for (int i = 0; i < 3; i++) {
        expect(double.parse(qtPricesAfter[i]),
            greaterThan(double.parse(qtPricesBefore[i])));
      }
    });
  });

  group('v0.1.12 Feature 2: ALUMET 6-Album Pattern Expansion & ICONIQ-Only Doors', () {
    test('All 4 ALUMET series resolve 100% non-zero cuts, catalog pricing, and on-disk PNG diagrams', () {
      final reg = AluproImageRegistry.instance;
      final allCatalog = SeedRepository.instance.allCatalogPrices;

      final alumetBrands = <BrandDef>[
        for (final cat in CatalogDefinitions.categories)
          for (final b in cat.brands)
            if (b.id == 'c2_alumet' ||
                b.id == 'c2_alumet_nex' ||
                b.id == 'c3_alumet_iconiq' ||
                b.id == 'c4_alumet_fold')
              b,
      ];
      expect(alumetBrands, hasLength(4));

      int totalAlumetActive = 0;
      final missingAssets = <String>[];
      final pricingFailures = <String>[];

      for (final b in alumetBrands) {
        final cards = <({String sysId, String sysTitle, PatternCardDef pat})>[
          for (final p in b.directPatterns) (sysId: b.id, sysTitle: b.subtitle, pat: p),
          for (final s in b.systems) ...[
            for (final p in s.patterns) (sysId: s.id, sysTitle: s.title, pat: p),
            for (final tab in s.subTabs)
              for (final p in tab.patterns) (sysId: s.id, sysTitle: tab.title, pat: p),
          ],
        ];

        for (final entry in cards) {
          final pat = entry.pat;
          if (!pat.enabled) continue;
          totalAlumetActive++;

          // 1. Pattern diagram PNG exists on disk (mandatory for all new v0.1.12 patterns & ICONIQ doors)
          final asset = reg.resolvePatternAsset(pat.id);
          final mustHaveAsset = pat.baseFormulaKey.startsWith('alu_ext:') ||
              entry.sysId == 'c3_alu_doors' ||
              pat.id == 'fold_alu_5_5_0' ||
              pat.id == 'fold_alu_8_4_4' ||
              b.id == 'c2_alumet_nex';
          if (mustHaveAsset && (asset == null || !File(asset).existsSync())) {
            missingAssets.add('${b.id}:${pat.id} -> $asset');
          } else if (asset != null && !File(asset).existsSync()) {
            missingAssets.add('${b.id}:${pat.id} -> missing file $asset');
          }

          // 2. Mosquito rule: fixed-only patterns have NO mosquito option; operable ones have all 3
          final effOpts = CatalogDefinitions.effectiveOptionGroupsFor(
            pat,
            systemId: entry.sysId,
          );
          final isFixed = CatalogDefinitions.isFixedOnlyPattern(pat, systemId: entry.sysId);
          if (entry.sysId.contains('fixed')) {
            expect(isFixed, isTrue, reason: '${pat.id} under ${entry.sysId} must be fixed-only');
            expect(effOpts.any((g) => g.id == 'mosquito'), isFalse);
          } else {
            expect(effOpts.any((g) => g.id == 'mosquito'), isTrue,
                reason: 'Operable ${pat.id} must offer 3 mosquito screen types');
          }

          // 3. Parametric calculation & 100% catalog pricing match
          final opts = {for (final g in pat.optionGroups) g.id: g.defaultValue};
          final out = ParametricSystemResolver.calculate(
            brandTitle: b.title,
            priceBrandKey: b.priceBrandKey,
            systemTitle: entry.sysTitle,
            pattern: pat,
            selectedOptions: opts,
            sizeRows: const [
              SizeRowInput(widthMm: 2200, heightMm: 2100, auxMm: 1650, qty: 1),
            ],
          );
          expect(out.barGroups, isNotEmpty, reason: '${pat.id} produced no barGroups');

          final avail = PricingEngine.computeAvailability(
            barGroups: out.barGroups,
            ormCatalog: allCatalog,
            customOverrides: const {},
          );
          final thick = avail.availableThicknesses.contains('1.5 มม.')
              ? '1.5 มม.'
              : avail.availableThicknesses.first;
          final color = avail.availableColors.contains('อบดำ (8816)')
              ? 'อบดำ (8816)'
              : avail.availableColors.first;

          final summary = PricingEngine.evaluate(
            barGroups: out.barGroups,
            mode: PricingMode.actualLength,
            wastePercent: 20.0,
            selectedThickness: thick,
            selectedColor: color,
            ormCatalog: allCatalog,
            customOverrides: const {},
          );
          if (summary.matchedCount < summary.totalCount || summary.aluminumCost <= 0) {
            final miss = summary.lines
                .where((l) => !l.isMatched)
                .map((l) => l.group.code)
                .join(', ');
            pricingFailures.add('${pat.id} (${summary.matchedCount}/${summary.totalCount}: $miss)');
          }
        }
      }

      expect(totalAlumetActive, greaterThan(200));
      expect(missingAssets, isEmpty, reason: 'Missing pattern assets: $missingAssets');
      expect(pricingFailures, isEmpty, reason: 'Unmatched ALUMET pricing: $pricingFailures');
    });

    test('Strict Customer Rule (16:18): 11-pattern Swing Door suite is ONLY in ALUMET (Iconiq Euro)', () {
      final smartX = CatalogDefinitions.categories[1].brands
          .firstWhere((b) => b.id == 'c2_alumet');
      final nex = CatalogDefinitions.categories[1].brands
          .firstWhere((b) => b.id == 'c2_alumet_nex');
      final iconiq = CatalogDefinitions.categories[2].brands
          .firstWhere((b) => b.id == 'c3_alumet_iconiq');
      final fold = CatalogDefinitions.categories[3].brands
          .firstWhere((b) => b.id == 'c4_alumet_fold');

      // ICONIQ has dedicated 11-pattern Swing Door system
      final iqDoors = iconiq.systems.firstWhere((s) => s.id == 'c3_alu_doors');
      expect(iqDoors.patterns, hasLength(11));
      expect(iqDoors.patterns.any((p) => p.id == 'c3_alu_d2_arch_card'), isTrue);
      expect(iqDoors.patterns.any((p) => p.id == 'c3_alu_d2_louver_side2_louver_card'), isTrue);

      // Smart X keeps ONLY its original 2 swing doors (untouched!)
      final sxDoors = smartX.systems.firstWhere((s) => s.id == 'c2_alu_doors');
      expect(sxDoors.patterns, hasLength(2));

      // NEX keeps 3 systems with ZERO swing door systems
      expect(nex.systems, hasLength(3));
      expect(nex.systems.any((s) => s.id.contains('door')), isFalse);

      // ALUMET Folding has 16 active layouts including newly added 5-5-0 and 8-4-4
      expect(fold.directPatterns, hasLength(16));
      expect(fold.directPatterns.any((p) => p.id == 'fold_alu_5_5_0'), isTrue);
      expect(fold.directPatterns.any((p) => p.id == 'fold_alu_8_4_4'), isTrue);
    });
  });
}
