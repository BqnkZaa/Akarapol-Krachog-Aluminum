import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/alupro_image_registry.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/engine/quotation_spec_formatter.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/screens/catalog_and_input_screens.dart';
import 'package:toolkit_app/screens/custom_system_studio_screens.dart';
import 'package:toolkit_app/screens/home_and_aux_screens.dart';

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

  group('Workstream 1 & 2: Shower (4) & Frameless Door (25) × VVP & RP', () {
    test('cat5_shower is unlocked with VVP & RP Steel Glass, 4 Shower + 25 Frameless patterns each, real assets & 100% priced hardware', () {
      final cat5 = CatalogDefinitions.categories
          .firstWhere((c) => c.id == 'cat5_shower');
      expect(cat5.brands.length, 2);
      expect(cat5.brands.every((b) => b.enabled), isTrue);

      for (final brand in cat5.brands) {
        final brandImg = AluproImageRegistry.instance.resolveBrandAsset(brand.id);
        expect(brandImg, isNotNull, reason: 'Brand logo for ${brand.id}');
        expect(File(brandImg!).existsSync(), isTrue, reason: brandImg);

        expect(brand.systems.length, 2);
        final showerSys = brand.systems[0];
        final framelessSys = brand.systems[1];
        expect(showerSys.patterns.length, 4);

        final allFrameless =
            framelessSys.subTabs.expand((t) => t.patterns).toList();
        expect(allFrameless.length, 25);

        // Verify NO mosquito options leak into any Cat 5 Shower or Frameless pattern
        for (final pat in [...showerSys.patterns, ...allFrameless]) {
          final effOpts = CatalogDefinitions.effectiveOptionGroupsFor(pat);
          expect(
            effOpts.any((g) => g.id == 'mosquito'),
            isFalse,
            reason: '${pat.id} must NOT have mosquito option',
          );

          final imgPath =
              AluproImageRegistry.instance.resolvePatternAsset(pat.id);
          expect(imgPath, isNotNull, reason: 'Pattern asset for ${pat.id}');
          expect(File(imgPath!).existsSync(), isTrue, reason: imgPath);

          final out = ParametricSystemResolver.calculate(
            brandTitle: brand.title,
            priceBrandKey: brand.priceBrandKey,
            systemTitle: pat.id.contains('_shw_') ? 'ชุดชาวเวอร์' : 'ชุดบานเปลือย',
            pattern: pat,
            selectedOptions: const {},
            sizeRows: const [
              SizeRowInput(widthMm: 2400, heightMm: 2200, auxMm: 1850, qty: 1),
            ],
          );

          // Default frameless uses 0 aluminum bars!
          expect(out.barGroups, isEmpty, reason: '${pat.id} default = 0 aluminum bars');
          expect(out.sets.first.glasses, isNotEmpty, reason: '${pat.id} has tempered glass');
          expect(out.hardware, isNotEmpty, reason: '${pat.id} has authentic fittings');

          // Verify 100% of hardware items resolve price & real product photo!
          final price = PricingEngine.evaluate(
            barGroups: out.barGroups,
            mode: PricingMode.actualLength,
            wastePercent: 20,
            selectedThickness: '1.2 มม.',
            selectedColor: 'อบดำ (8816)',
            ormCatalog: SeedRepository.instance.allCatalogPrices,
            customOverrides: const {},
            glasses: out.sets.first.glasses,
            includeGlass: true,
            selectedGlassKey: 'GLASS|กระจกเทมเปอร์ใส 10 มม.',
            glassRatePerSqM: 850,
            hardware: out.hardware,
            includeHardware: true,
            hardwareCatalog: SeedRepository.instance.hardwareRates,
          );
          expect(price.aluminumCost, 0.0);
          expect(price.glassCost, greaterThan(0), reason: '${pat.id} glass cost > 0');
          expect(price.hardwareCost, greaterThan(0), reason: '${pat.id} hardware cost > 0');
          expect(
            price.hardwareLines.every((l) => l.isPriced),
            isTrue,
            reason: '${pat.id} every hardware SKU must match seed price: '
                '${price.hardwareLines.where((l) => !l.isPriced).map((l) => l.item.code).toList()}',
          );
        }
      }
    });
  });

  group('Workstream 3, 4 & 5: Categorized ALUMET / VVP / RP Hardware Catalog (258 visible items)', () {
    test('visibleHardwareRates contains strictly ALUMET (133), VVP (46), RP (79) with real images and categories', () {
      final visible = SeedRepository.instance.visibleHardwareRates;
      expect(visible.length, 258);

      final brands = visible.map((e) => e.brand).toSet();
      expect(brands, equals({'ALUMET', 'VVP', 'RP'}));

      final alumet = visible.where((e) => e.brand == 'ALUMET').toList();
      final vvp = visible.where((e) => e.brand == 'VVP').toList();
      final rp = visible.where((e) => e.brand == 'RP').toList();
      expect(alumet.length, 133);
      expect(vvp.length, 46);
      expect(rp.length, 79);

      // ALUMET exact 5 categories requested by customer
      expect(
        alumet.map((e) => e.subCategory).toSet(),
        containsAll(['บานเลื่อน', 'บานเปิด', 'บานกระทุ้ง', 'บานเฟี้ยม', 'สกรู / ทั่วไป']),
      );

      // Every single visible hardware item has a real extracted image on disk!
      for (final h in visible) {
        final img = h.imageAssetPath ??
            AluproImageRegistry.instance
                .resolveHardwareAsset(code: h.code, name: h.name);
        expect(img, isNotNull, reason: 'Missing image for ${h.brand} ${h.code}');
        expect(File(img!).existsSync(), isTrue, reason: 'Missing file $img');
      }

      // Legacy fallback hardware still exists silently for pricing compatibility
      expect(SeedRepository.instance.hardwareRates.length, greaterThan(visible.length));
    });

    testWidgets('HardwareCatalogScreen renders ALUMET/VVP/RP tabs, sub-categories & product photos', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: const HardwareCatalogScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALUMET (133)'), findsOneWidget);
      expect(find.text('VVP (46)'), findsOneWidget);
      expect(find.text('RP Steel Glass (79)'), findsOneWidget);
      expect(find.text('บานเฟี้ยม'), findsWidgets);
      expect(find.text('บานเลื่อน'), findsWidgets);
    });
  });

  group('Workstream 6: 0-Aluminum Unlock, Built-in Formula Override & Folding/Hanging Parity', () {
    test('FormulaOverrideEditor persists custom formula (including 0 aluminum bars) and cleanly resets to factory', () async {
      final found = CatalogDefinitions.findPatternById('c2_alu_s2_card')!;
      const rows = [SizeRowInput(widthMm: 2000, heightMm: 2100, qty: 1)];

      final before = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: found.pattern,
        selectedOptions: const {},
        sizeRows: rows,
      );
      expect(before.barGroups, isNotEmpty);

      // Save an override with 0 aluminum bars + custom glass formula
      final ov = PatternFormulaOverride(
        patternId: found.pattern.id,
        formulaTable: const VerifiedFormulaTable(
          key: 'c2_alu_s2_override',
          header: 'Custom Frameless Override',
          cuts: [],
          glasses: [
            GlassPieceSpec(
              name: 'กระจกเทมเปอร์พิเศษ',
              qty: 2,
              qtyText: '2 แผ่น',
              siteCut: false,
              wFormula: 'W / 2 - 5',
              hFormula: 'H - 10',
            ),
          ],
          hardware: [
            HardwareItemSpec(code: 'FC 34', name: 'โช้คฝังพื้น VVP FC 34', qtyText: '2 ชุด'),
          ],
        ),
        updatedAt: DateTime.now(),
      );
      await AppDatabase.instance.saveFormulaOverride(ov);
      await SeedRepository.instance.reloadFormulaOverrides();

      final overridden = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: found.pattern,
        selectedOptions: const {},
        sizeRows: rows,
      );
      expect(overridden.barGroups, isEmpty);
      expect(overridden.sets.first.glasses.first.widthMm, closeTo(995.0, 0.1));
      expect(overridden.hardware.first.code, 'FC 34');

      // Reset back to factory default
      await AppDatabase.instance.deleteFormulaOverride(found.pattern.id);
      await SeedRepository.instance.reloadFormulaOverrides();

      final restored = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: found.pattern,
        selectedOptions: const {},
        sizeRows: rows,
      );
      expect(restored.barGroups.length, before.barGroups.length);
    });

    testWidgets('CustomSystemEditorScreen allows clearing all aluminum cuts to 0 bars', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: const CustomSystemEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final clearBtn = find.byKey(const ValueKey('btn_clear_all_aluminum_cuts'));
      await tester.scrollUntilVisible(
        clearBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('ไม่ใช้เส้นอลูมิเนียม (0 เส้น)'), findsOneWidget);
    });
  });

  group('Workstream 7 & 8: 27 ALUMET Swatch Thumbnails (strictly ALUMET only) & Shop Default Shortcuts', () {
    test('All 27 ALUMET color codes have real photographed swatch files on disk; non-ALUMET returns null', () {
      expect(PricingEngine.alumetColors.length, 27);
      expect(QuotationSpecFormatter.alumetColorChoices.length, 27);
      for (final col in PricingEngine.alumetColors) {
        final swatch = AluproImageRegistry.resolveAlumetColorSwatch(col);
        expect(swatch, isNotNull, reason: 'Missing swatch for $col');
        expect(File(swatch!).existsSync(), isTrue, reason: 'Missing swatch file $swatch');
      }
      // Strictly ALUMET only: generic non-ALUMET colors must NOT get ALUMET swatches
      expect(AluproImageRegistry.resolveAlumetColorSwatch('สีดำ'), isNull);
      expect(AluproImageRegistry.resolveAlumetColorSwatch('สีขาวอบ'), isNull);
      expect(AluproImageRegistry.resolveAlumetColorSwatch('พ่นดำ ซุปเปอร์แบล็ค'), isNull);
    });

    testWidgets('ShopSelectionDefaults saves & auto-loads on SizeAndSpecInputScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await AppDatabase.instance.saveShopSelectionDefaults(
          const ShopSelectionDefaults(
            brandAluThicknesses: {'ALUMET': '1.5 มม.'},
            brandAluColors: {'ALUMET': 'ลายไม้มูจิ (15622)'},
            brandGlassTypes: {'ALUMET': 'กระจกเขียวตัดแสง'},
            brandGlassThicknesses: {'ALUMET': '8 มม.'},
          ),
        );
      });

      final pat = CatalogDefinitions.findPatternById('c2_alu_s2_card')!.pattern;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: SizeAndSpecInputScreen(
            brandTitle: 'ALUMET (Smart X)',
            priceBrandKey: 'ALUMET',
            systemTitle: 'บานเลื่อน Smart X',
            pattern: pat,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal the Material/Color/Glass ExpansionTile at the bottom
      final specTile = find.textContaining('ระบุความหนา / สี / ประเภทกระจก');
      await tester.scrollUntilVisible(
        specTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Subtitle of spec card immediately reflects saved shop defaults!
      expect(find.textContaining('ลายไม้มูจิ (15622)'), findsOneWidget);
      expect(find.textContaining('กระจกเขียวตัดแสง 8 มม.'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_input_save_option_defaults')), findsOneWidget);

      // Scroll back to top to verify Edit Formula button
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('btn_input_edit_formula')), findsOneWidget);

      // Clean up defaults after test
      await tester.runAsync(() async {
        await AppDatabase.instance
            .saveShopSelectionDefaults(const ShopSelectionDefaults());
      });
    });
  });
}
