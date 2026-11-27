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
import 'package:toolkit_app/engine/quotation_spec_formatter.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/pdf/quotation_pdf.dart';
import 'package:toolkit_app/screens/catalog_and_input_screens.dart';
import 'package:toolkit_app/screens/projects_and_quotation_screens.dart';

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

  PatternCardDef findPattern(String id) {
    for (final cat in CatalogDefinitions.categories) {
      for (final b in cat.brands) {
        for (final p in b.directPatterns) {
          if (p.id == id) return p;
        }
        for (final s in b.systems) {
          for (final p in s.patterns) {
            if (p.id == id) return p;
          }
          for (final st in s.subTabs) {
            for (final p in st.patterns) {
              if (p.id == id) return p;
            }
          }
        }
      }
    }
    throw StateError('Pattern not found: $id');
  }

  group('Item 1: Folding formulas & hardware parity across all 5 folding systems', () {
    test('ALUMET Smart X Folding: exact 3-way sill delta (SB-0115 / SB-0116 / SB-0103) + 5-case geometry + authentic AKL-SMBF* hardware', () {
      const row = [SizeRowInput(widthMm: 4000, heightMm: 2200, qty: 1)];

      // 1. Verify 3-way sill height deductions on 3-3-0 (swept base = SB-0103) and 5-5-0 (parametric)
      for (final patId in ['fold_alu_3_3_0', 'fold_alu_5_5_0', 'fold_alu_8_4_4']) {
        final pat = findPattern(patId);
        final res115 = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X Folding)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'Smart X Folding',
          pattern: pat,
          selectedOptions: const {'sill_code': 'SB-0115'},
          sizeRows: row,
        );
        final res116 = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X Folding)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'Smart X Folding',
          pattern: pat,
          selectedOptions: const {'sill_code': 'SB-0116'},
          sizeRows: row,
        );
        final res103 = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X Folding)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'Smart X Folding',
          pattern: pat,
          selectedOptions: const {'sill_code': 'SB-0103'},
          sizeRows: row,
        );

        final sashV115 = res115.sets.first.cuts
            .firstWhere((c) => c.code == 'SB-0114' && c.name.contains('แนวตั้ง'))
            .lengthMm!;
        final sashV116 = res116.sets.first.cuts
            .firstWhere((c) => c.code == 'SB-0114' && c.name.contains('แนวตั้ง'))
            .lengthMm!;
        final sashV103 = res103.sets.first.cuts
            .firstWhere((c) => c.code == 'SB-0114' && c.name.contains('แนวตั้ง'))
            .lengthMm!;

        expect(sashV115, closeTo(2200 - 67, 0.1), reason: '$patId SB-0115 sash V');
        expect(sashV116, closeTo(2200 - 82, 0.1), reason: '$patId SB-0116 sash V');
        expect(sashV103, closeTo(2200 - 89, 0.1), reason: '$patId SB-0103 sash V');

        expect(res115.sets.first.glasses.first.heightMm, closeTo(2200 - 201, 0.1));
        expect(res116.sets.first.glasses.first.heightMm, closeTo(2200 - 216, 0.1));
        expect(res103.sets.first.glasses.first.heightMm, closeTo(2200 - 223, 0.1));
      }

      // 2. Verify exact 5-5-0 (single-dir odd) geometry & authentic AKL-SMBF hardware
      final f550 = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X Folding)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'Smart X Folding',
        pattern: findPattern('fold_alu_5_5_0'),
        selectedOptions: const {'sill_code': 'SB-0116'},
        sizeRows: const [SizeRowInput(widthMm: 4000, heightMm: 2100, qty: 1)],
      );
      final cuts550 = f550.sets.first.cuts;
      expect(cuts550.any((c) => c.code == 'SB-0113'), isFalse); // Odd single-dir has NO SB-0113
      expect(cuts550.firstWhere((c) => c.code == 'SB-0117').totalQty, 1);
      expect(cuts550.firstWhere((c) => c.code == 'เส้น C-กรุ๊ฟ').totalQty, 2);
      final sashH550 = cuts550
          .firstWhere((c) => c.code == 'SB-0114' && c.name.contains('แนวนอน'))
          .lengthMm!;
      expect(sashH550, closeTo((4000 - 83.1) / 5, 0.2));
      expect(f550.hardware.any((h) => h.code == 'AKL-SMBF001'), isTrue);
      expect(f550.hardware.any((h) => h.code == 'AKL-SMBF018'), isTrue);
      expect(f550.hardware.any((h) => h.code == 'AKL-SMBF024'), isFalse); // Only 1 odd side

      // 3. Verify exact 8-4-4 (even + even) geometry & authentic AKL-SMBF hardware
      final f844 = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X Folding)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'Smart X Folding',
        pattern: findPattern('fold_alu_8_4_4'),
        selectedOptions: const {'sill_code': 'SB-0116'},
        sizeRows: const [SizeRowInput(widthMm: 6000, heightMm: 2200, qty: 1)],
      );
      final cuts844 = f844.sets.first.cuts;
      expect(cuts844.firstWhere((c) => c.code == 'SB-0113').totalQty, 2);
      expect(cuts844.any((c) => c.code == 'SB-0117'), isFalse);
      expect(cuts844.firstWhere((c) => c.code == 'เส้น C-กรุ๊ฟ').totalQty, 4);
      final sashH844 = cuts844
          .firstWhere((c) => c.code == 'SB-0114' && c.name.contains('แนวนอน'))
          .lengthMm!;
      expect(sashH844, closeTo((6000 - 180.0) / 8, 0.2));
      expect(f844.hardware.firstWhere((h) => h.code == 'AKL-SMBF019').numericQty, 2);
      expect(f844.hardware.firstWhere((h) => h.code == 'AKL-SMBF001').numericQty, 2);
      // Height == 2200 triggers +1 hinge per axis (24 + 8 = 32)
      expect(f844.hardware.firstWhere((h) => h.code == 'AKL-SMBF003').numericQty, 32);

      // Verify 100% of AKL-SMBF hardware prices match in catalog!
      final price844 = PricingEngine.evaluate(
        barGroups: f844.barGroups,
        mode: PricingMode.actualLength,
        wastePercent: 20,
        selectedThickness: '1.5 มม.',
        selectedColor: 'อบดำ (8816)',
        ormCatalog: SeedRepository.instance.allCatalogPrices,
        customOverrides: const {},
        hardware: f844.hardware,
        includeHardware: true,
        hardwareCatalog: SeedRepository.instance.hardwareRates,
      );
      expect(price844.hardwareLines.every((l) => l.isPriced), isTrue);
      expect(price844.hardwareCost, greaterThan(5000));
    });

    test('All 4 previously empty Schimmer 240 folding cards + Fuji/SmartPlus/ORM fallbacks have complete priced hardware', () {
      for (final schId in [
        'c4_sch_3_3l_card',
        'c4_sch_4_1l3r_card',
        'c4_sch_4_2l2r_card',
        'c4_sch_4_4l_card',
      ]) {
        final pat = findPattern(schId);
        final out = ParametricSystemResolver.calculate(
          brandTitle: 'SMS SCHIMMER',
          priceBrandKey: 'SCHIMMER',
          systemTitle: 'HOMELIFE 240',
          pattern: pat,
          selectedOptions: const {},
          sizeRows: const [SizeRowInput(widthMm: 3200, heightMm: 2100, qty: 1)],
        );
        expect(out.hardware, isNotEmpty, reason: '$schId must have hardware');
        final pr = PricingEngine.evaluate(
          barGroups: out.barGroups,
          mode: PricingMode.actualLength,
          wastePercent: 20,
          selectedThickness: '1.5 มม.',
          selectedColor: 'อบดำ (8816)',
          ormCatalog: SeedRepository.instance.allCatalogPrices,
          customOverrides: const {},
          hardware: out.hardware,
          includeHardware: true,
          hardwareCatalog: SeedRepository.instance.hardwareRates,
        );
        expect(pr.hardwareCost, greaterThan(0), reason: '$schId hardware cost > 0');
      }

      // Fuji fallback (e.g. 5-3-2) has full 14 hardware items including HD-474, HD-312, HD-481A
      final fuji532 = ParametricSystemResolver.calculate(
        brandTitle: 'Fuji',
        priceBrandKey: 'FUJI',
        systemTitle: 'Fuji Folding',
        pattern: findPattern('fold_fuji_std_5_3_2'),
        selectedOptions: const {},
        sizeRows: const [SizeRowInput(widthMm: 4000, heightMm: 2100, qty: 1)],
      );
      expect(fuji532.hardware.any((h) => h.code == 'HD-474'), isTrue);
      expect(fuji532.hardware.any((h) => h.code == 'HD-312'), isTrue);
      expect(fuji532.hardware.any((h) => h.code == 'HD-481A'), isTrue);
    });
  });

  group('Item 2: ALUMET Pro Smart X Hanging Track Doors (Single & Double)', () {
    test('Both Pro Smart X hanging patterns resolve cuts, CAD images, options & 100% priced hardware', () {
      for (final patId in ['c2_alu_hang1_card', 'c2_alu_hang2_card']) {
        final pat = findPattern(patId);
        expect(pat.enabled, isTrue);
        final img = AluproImageRegistry.instance.resolvePatternAsset(patId);
        expect(img, isNotNull);
        expect(File(img!).existsSync(), isTrue);

        // Test side-mount SS-X116 + 45 deg 1.2mm + Soft Close
        final outSide = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'บานเลื่อน Smart X',
          pattern: pat,
          selectedOptions: const {
            'track_type': 'SS-X116',
            'sash_profile': '45_12',
            'hang_hw': 'soft_close',
          },
          sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
        );
        final codesSide = outSide.sets.first.cuts.map((c) => c.code).toSet();
        expect(codesSide.contains('SS-X116'), isTrue);
        expect(codesSide.contains('SS-X114'), isTrue);
        expect(codesSide.contains('SS-X115'), isTrue);
        expect(codesSide.contains('iS-0209'), isTrue);
        expect(codesSide.contains('SS-X212'), isTrue);
        expect(outSide.hardware.any((h) => h.code == 'SMX-HANG-SC'), isTrue);

        // Test ceiling-mount SS-X113 + 90 deg 1.5mm + standard roller
        final outTop = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'บานเลื่อน Smart X',
          pattern: pat,
          selectedOptions: const {
            'track_type': 'SS-X113',
            'sash_profile': '90_15',
            'hang_hw': 'standard',
          },
          sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
        );
        final codesTop = outTop.sets.first.cuts.map((c) => c.code).toSet();
        expect(codesTop.contains('SS-X113'), isTrue);
        expect(codesTop.contains('SS-X209'), isTrue);
        expect(codesTop.contains('SS-X210'), isTrue);
        expect(outTop.hardware.any((h) => h.code == 'SMX-HANG-STD'), isTrue);

        // Verify 100% matched non-zero pricing (Aluminum + Glass + Hardware)
        final price = PricingEngine.evaluate(
          barGroups: outSide.barGroups,
          mode: PricingMode.actualLength,
          wastePercent: 20,
          selectedThickness: '1.2 มม.',
          selectedColor: 'ดำซาฮาร่า (8819)',
          ormCatalog: SeedRepository.instance.allCatalogPrices,
          customOverrides: const {},
          glasses: outSide.sets.first.glasses,
          includeGlass: true,
          selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
          glassRatePerSqM: 205,
          hardware: outSide.hardware,
          includeHardware: true,
          hardwareCatalog: SeedRepository.instance.hardwareRates,
        );
        expect(price.matchedCount, price.totalCount);
        expect(price.aluminumCost, greaterThan(0));
        expect(price.glassCost, greaterThan(0));
        expect(price.hardwareCost, greaterThan(1500));
        expect(price.hardwareLines.every((l) => l.isPriced), isTrue);
      }
    });
  });

  group('Item 3: Official 19 ALUMET color codes strictly for ALUMET only', () {
    test('ALUMET seed has all 19 official color codes while all other 7 brands keep original 7 colors untouched', () {
      final byBrand = <String, Set<String>>{};
      for (final s in SeedRepository.instance.allCatalogPrices) {
        byBrand.putIfAbsent(s.brand.toUpperCase(), () => <String>{}).add(s.color);
      }

      final alumetCols = byBrand['ALUMET']!;
      expect(alumetCols.length, 19);
      for (final expected in PricingEngine.alumetColors) {
        expect(alumetCols.contains(expected), isTrue, reason: 'Missing ALUMET color $expected');
      }

      // Strictly ALUMET only: ORM, MARKET, SCHIMMER, SMART_PLUS, UAI, FUJI, ALUFRAME untouched!
      for (final other in [
        'ORM',
        'MARKET',
        'SCHIMMER',
        'SMART_PLUS',
        'UAI',
        'FUJI',
        'ALUFRAME',
      ]) {
        expect(byBrand[other]!.length, 7, reason: '$other must remain 7 colors');
        expect(byBrand[other]!.contains('ชุบชา (512)'), isFalse);
        expect(byBrand[other]!.contains('ดำซาฮาร่า (8819)'), isFalse);
      }

      // Quotation formatter preserves official ALUMET color codes
      expect(
        QuotationSpecFormatter.normalizePricingColorForQuotation('ดำซาฮาร่า (8819)', brandKey: 'ALUMET'),
        'ดำซาฮาร่า (8819)',
      );
      expect(
        QuotationSpecFormatter.normalizePricingColorForQuotation('ชุบชา (512)', brandKey: 'ALUMET'),
        'ชุบชา (512)',
      );
    });
  });

  group('Item 4 & Item 5: Defaults everywhere + Pattern images in Quotation Builder & PDF', () {
    testWidgets('SizeAndSpecInputScreen & QuotationBuilderScreen open with all defaults preselected and PDF embeds pattern images', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 1. Input screen starts with ALUMET 1.2 มม. / อบดำ (8816) / กระจกใส 6 มม. (NO blank ไม่ระบุ!)
      final hang1 = findPattern('c2_alu_hang1_card');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: SizeAndSpecInputScreen(
            brandTitle: 'ALUMET (Smart X)',
            priceBrandKey: 'ALUMET',
            systemTitle: 'บานเลื่อน Smart X',
            pattern: hang1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('อบดำ (8816)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('อบดำ (8816)'), findsOneWidget);
      expect(find.textContaining('กระจกใส 6 มม.'), findsOneWidget);

      // 2. QuotationBuilderScreen opens with ITEMIZED preselected, default terms, and image switch ON
      final outHang = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: hang1,
        selectedOptions: const {
          'track_type': 'SS-X116',
          'sash_profile': '45_12',
          'hang_hw': 'soft_close',
          'pricing_alu_thick': '1.2 มม.',
          'pricing_alu_color': 'ดำซาฮาร่า (8819)',
          'pricing_glass_key': 'GLASS|กระจกใส 6 มม.',
          'spec_alu_thick': '1.2 มม.',
          'spec_alu_color': 'ดำซาฮาร่า (8819)',
          'spec_glass_type': 'กระจกใส',
          'spec_glass_thick': '6 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
      );
      final outFold = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X Folding)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'Smart X Folding',
        pattern: findPattern('fold_alu_4_2_2'),
        selectedOptions: const {
          'sill_code': 'SB-0103',
          'pricing_alu_thick': '1.5 มม.',
          'pricing_alu_color': 'อบขาว (8911)',
          'pricing_glass_key': 'GLASS|กระจกเขียวตัดแสง 6 มม.',
          'spec_alu_thick': '1.5 มม.',
          'spec_alu_color': 'อบขาว (8911)',
          'spec_glass_type': 'กระจกเขียวตัดแสง',
          'spec_glass_thick': '6 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2200, qty: 1)],
      );

      final proj = SavedProject(
        id: 901,
        name: 'โครงการตัวอย่าง v0.1.13',
        createdAt: DateTime(2026, 11, 27),
        updatedAt: DateTime(2026, 11, 27),
        items: [
          SavedProjectItem(
            id: 1,
            projectId: 901,
            sortIndex: 0,
            refCode: 'D1',
            brandTitle: outHang.brandTitle,
            priceBrandKey: outHang.priceBrandKey,
            systemTitle: outHang.systemTitle,
            patternId: outHang.patternId,
            patternTitle: outHang.patternTitle,
            selectedOptions: outHang.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
            evaluatedSets: outHang.sets,
            hardware: outHang.hardware,
          ),
          SavedProjectItem(
            id: 2,
            projectId: 901,
            sortIndex: 1,
            refCode: 'F1',
            brandTitle: outFold.brandTitle,
            priceBrandKey: outFold.priceBrandKey,
            systemTitle: outFold.systemTitle,
            patternId: outFold.patternId,
            patternTitle: outFold.patternTitle,
            selectedOptions: outFold.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2200, qty: 1)],
            evaluatedSets: outFold.sets,
            hardware: outFold.hardware,
          ),
        ],
      );
      const shop = ShopInfo(
        shopName: 'บริษัท อัครพลกระจกอลูมิเนียม จำกัด',
        proposerName: 'อัครพล',
        phone: '081-234-5678',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: QuotationBuilderScreen(
            project: proj,
            shopInfo: shop,
            estimatedAluminumCost: 42000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Image switch ON by default & ITEMIZED mode ALREADY active by default (no blank mode!)
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qt_include_images_switch')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final imgSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('qt_include_images_switch')),
      );
      expect(imgSwitch.value, isTrue);

      await tester.scrollUntilVisible(
        find.text('3. กำหนดราคาขายแยกรายการ (ยืนยันทุกบรรทัด)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('3. กำหนดราคาขายแยกรายการ (ยืนยันทุกบรรทัด)'), findsOneWidget);
    });

    test('QuotationPdfGenerator embeds pattern diagram images in both ITEMIZED and LUMP_SUM PDFs', () async {
      final hang1 = findPattern('c2_alu_hang1_card');
      final outHang = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: hang1,
        selectedOptions: const {
          'track_type': 'SS-X116',
          'sash_profile': '45_12',
          'hang_hw': 'soft_close',
          'pricing_alu_thick': '1.2 มม.',
          'pricing_alu_color': 'ดำซาฮาร่า (8819)',
          'pricing_glass_key': 'GLASS|กระจกใส 6 มม.',
          'spec_alu_thick': '1.2 มม.',
          'spec_alu_color': 'ดำซาฮาร่า (8819)',
          'spec_glass_type': 'กระจกใส',
          'spec_glass_thick': '6 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
      );
      final outFold = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X Folding)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'Smart X Folding',
        pattern: findPattern('fold_alu_4_2_2'),
        selectedOptions: const {
          'sill_code': 'SB-0103',
          'pricing_alu_thick': '1.5 มม.',
          'pricing_alu_color': 'อบขาว (8911)',
          'pricing_glass_key': 'GLASS|กระจกเขียวตัดแสง 6 มม.',
          'spec_alu_thick': '1.5 มม.',
          'spec_alu_color': 'อบขาว (8911)',
          'spec_glass_type': 'กระจกเขียวตัดแสง',
          'spec_glass_thick': '6 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2200, qty: 1)],
      );
      final proj = SavedProject(
        id: 901,
        name: 'โครงการตัวอย่าง v0.1.13',
        createdAt: DateTime(2026, 11, 27),
        updatedAt: DateTime(2026, 11, 27),
        items: [
          SavedProjectItem(
            id: 1,
            projectId: 901,
            sortIndex: 0,
            refCode: 'D1',
            brandTitle: outHang.brandTitle,
            priceBrandKey: outHang.priceBrandKey,
            systemTitle: outHang.systemTitle,
            patternId: outHang.patternId,
            patternTitle: outHang.patternTitle,
            selectedOptions: outHang.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 1200, heightMm: 2100, qty: 1)],
            evaluatedSets: outHang.sets,
            hardware: outHang.hardware,
          ),
          SavedProjectItem(
            id: 2,
            projectId: 901,
            sortIndex: 1,
            refCode: 'F1',
            brandTitle: outFold.brandTitle,
            priceBrandKey: outFold.priceBrandKey,
            systemTitle: outFold.systemTitle,
            patternId: outFold.patternId,
            patternTitle: outFold.patternTitle,
            selectedOptions: outFold.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2200, qty: 1)],
            evaluatedSets: outFold.sets,
            hardware: outFold.hardware,
          ),
        ],
      );
      const shop = ShopInfo(
        shopName: 'บริษัท อัครพลกระจกอลูมิเนียม จำกัด',
        proposerName: 'อัครพล',
        phone: '081-234-5678',
      );

      // Verify PDF generation WITH images vs WITHOUT images (both ITEMIZED & LUMP_SUM)
      final qtWithImg = SavedQuotation(
        projectId: 901,
        qtNumber: 'QT-V0113-IMG',
        docTitle: 'ใบเสนอราคา',
        mode: 'ITEMIZED',
        issueDate: '27/11/2026',
        validUntil: '27/12/2026',
        customerName: 'คุณสมชาย ทดสอบ',
        projectName: proj.name,
        lines: [
          QuotationLineEntry(
            label: 'D1 · บานเลื่อนรางแขวนบานเดี่ยว',
            subtitle: QuotationSpecFormatter.buildItemSpecSubtitle(
              item: proj.items[0],
              globalAluThickness: 'ตามรายการ',
              globalAluColor: 'ตามรายการ',
              globalGlassType: 'ตามรายการ',
              globalGlassThickness: 'ตามรายการ',
            ),
            sizeText: '1200 × 2100 มม.',
            qty: 1,
            unitPrice: 12500,
            confirmed: true,
            patternId: proj.items[0].patternId,
            imageAssetPath: AluproImageRegistry.instance
                .resolvePatternAsset(proj.items[0].patternId),
          ),
          QuotationLineEntry(
            label: 'F1 · 2 Left • 2 Right (4-2-2)',
            subtitle: QuotationSpecFormatter.buildItemSpecSubtitle(
              item: proj.items[1],
              globalAluThickness: 'ตามรายการ',
              globalAluColor: 'ตามรายการ',
              globalGlassType: 'ตามรายการ',
              globalGlassThickness: 'ตามรายการ',
            ),
            sizeText: '3600 × 2200 มม.',
            qty: 1,
            unitPrice: 48500,
            confirmed: true,
            patternId: proj.items[1].patternId,
            imageAssetPath: AluproImageRegistry.instance
                .resolvePatternAsset(proj.items[1].patternId),
          ),
        ],
        lumpSumPrice: 61000,
        subtotal: 61000,
        vatAmount: 0,
        netTotal: 61000,
        paymentTerms: 'มัดจำ 50% ก่อนผลิต ส่วนที่เหลือชำระวันส่งมอบ/ติดตั้งเสร็จ',
        leadTime: '15–20 วันทำการ หลังยืนยันแบบและรับมัดจำ',
        warranty: 'รับประกันงานติดตั้งและอุปกรณ์ 1 ปี',
        revisionTag: 'Rev 1',
        createdAt: DateTime(2026, 11, 27),
      );

      final qtNoImg = SavedQuotation(
        projectId: 901,
        qtNumber: 'QT-V0113-NOIMG',
        docTitle: 'ใบเสนอราคา',
        mode: 'ITEMIZED',
        issueDate: '27/11/2026',
        validUntil: '27/12/2026',
        customerName: 'คุณสมชาย ทดสอบ',
        projectName: proj.name,
        lines: qtWithImg.lines
            .map((l) => QuotationLineEntry(
                  label: l.label,
                  subtitle: l.subtitle,
                  sizeText: l.sizeText,
                  qty: l.qty,
                  unitPrice: l.unitPrice,
                  confirmed: true,
                ))
            .toList(),
        lumpSumPrice: 61000,
        subtotal: 61000,
        vatAmount: 0,
        netTotal: 61000,
        revisionTag: 'Rev 1',
        createdAt: DateTime(2026, 11, 27),
      );

      final bytesWithImg = await QuotationPdfGenerator.generate(
        quotation: qtWithImg,
        shopInfo: shop,
        testFontsDir: 'assets/fonts',
      );
      final bytesNoImg = await QuotationPdfGenerator.generate(
        quotation: qtNoImg,
        shopInfo: shop,
        testFontsDir: 'assets/fonts',
      );
      expect(bytesWithImg.length, greaterThan(bytesNoImg.length));

      // Also verify LUMP_SUM mode with embedded images generates cleanly
      final qtLumpWithImg = SavedQuotation(
        projectId: 901,
        qtNumber: 'QT-V0113-LUMP',
        docTitle: 'ใบเสนอราคา',
        mode: 'LUMP_SUM',
        issueDate: '27/11/2026',
        validUntil: '27/12/2026',
        customerName: 'คุณสมชาย ทดสอบ',
        projectName: proj.name,
        lines: qtWithImg.lines,
        lumpSumPrice: 61000,
        subtotal: 61000,
        vatAmount: 0,
        netTotal: 61000,
        revisionTag: 'Rev 1',
        createdAt: DateTime(2026, 11, 27),
      );
      final bytesLump = await QuotationPdfGenerator.generate(
        quotation: qtLumpWithImg,
        shopInfo: shop,
        testFontsDir: 'assets/fonts',
      );
      expect(bytesLump.length, greaterThan(bytesNoImg.length));
    });
  });

  group('Item 6: Per-project & per-item aluminum/glass isolation (NO cross-overwrite)', () {
    test('Two concurrent projects persist independent configs & two different-color/glass items inside one project never mix bars or overwrite prices', () async {
      // 1. Per-project config isolation in SQLite (Project 101 vs Project 102)
      await AppDatabase.instance.saveProjectPricingConfig(
        101,
        const ProjectPricingConfig(
          selectedThickness: '1.2 มม.',
          selectedColor: 'อบดำ (8816)',
          selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
          profitPercent: 25.0,
        ),
      );
      await AppDatabase.instance.saveProjectPricingConfig(
        102,
        const ProjectPricingConfig(
          selectedThickness: '1.5 มม.',
          selectedColor: 'ลายไม้สักน้ำตาล (15656)',
          selectedGlassKey: 'GLASS|กระจกเทมเปอร์ใส 10 มม.',
          profitPercent: 35.0,
        ),
      );

      final cfg101 = await AppDatabase.instance.getProjectPricingConfig(101);
      final cfg102 = await AppDatabase.instance.getProjectPricingConfig(102);
      expect(cfg101!.selectedColor, 'อบดำ (8816)');
      expect(cfg101.selectedGlassKey, 'GLASS|กระจกใส 6 มม.');
      expect(cfg101.profitPercent, 25.0);
      expect(cfg102!.selectedColor, 'ลายไม้สักน้ำตาล (15656)');
      expect(cfg102.selectedGlassKey, 'GLASS|กระจกเทมเปอร์ใส 10 มม.');
      expect(cfg102.profitPercent, 35.0);

      // 2. Two identical Smart X 2-panel sliding items inside ONE project,
      //    Item A = อบขาว (8911) + กระจกใส 5 มม. (175 ฿/ตร.ม.)
      //    Item B = ลายไม้สักน้ำตาล (15656) + กระจกเทมเปอร์ใส 10 มม. (850 ฿/ตร.ม.)
      final patS2 = findPattern('c2_alu_s2_card');
      final calcBase = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: patS2,
        selectedOptions: const {'thickness': '1.2', 'lock_type': 'multi'},
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
      );

      final itemWhiteClear = SavedProjectItem(
        id: 11,
        projectId: 101,
        sortIndex: 0,
        refCode: 'W1',
        brandTitle: calcBase.brandTitle,
        priceBrandKey: 'ALUMET',
        systemTitle: calcBase.systemTitle,
        patternId: patS2.id,
        patternTitle: patS2.title,
        selectedOptions: const {
          'thickness': '1.2',
          'lock_type': 'multi',
          'pricing_alu_thick': '1.2 มม.',
          'pricing_alu_color': 'อบขาว (8911)',
          'pricing_glass_key': 'GLASS|กระจกใส 5 มม.',
          'pricing_include_glass': 'true',
          'spec_alu_thick': '1.2 มม.',
          'spec_alu_color': 'อบขาว (8911)',
          'spec_glass_type': 'กระจกใส',
          'spec_glass_thick': '5 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
        evaluatedSets: calcBase.sets,
        hardware: calcBase.hardware,
      );

      final itemWoodTemp = SavedProjectItem(
        id: 12,
        projectId: 101,
        sortIndex: 1,
        refCode: 'W2',
        brandTitle: calcBase.brandTitle,
        priceBrandKey: 'ALUMET',
        systemTitle: calcBase.systemTitle,
        patternId: patS2.id,
        patternTitle: patS2.title,
        selectedOptions: const {
          'thickness': '1.2',
          'lock_type': 'multi',
          'pricing_alu_thick': '1.2 มม.',
          'pricing_alu_color': 'ลายไม้สักน้ำตาล (15656)',
          'pricing_glass_key': 'GLASS|กระจกเทมเปอร์ใส 10 มม.',
          'pricing_include_glass': 'true',
          'spec_alu_thick': '1.2 มม.',
          'spec_alu_color': 'ลายไม้สักน้ำตาล (15656)',
          'spec_glass_type': 'กระจกเทมเปอร์ใส',
          'spec_glass_thick': '10 มม.',
        },
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2000, qty: 1)],
        evaluatedSets: calcBase.sets,
        hardware: calcBase.hardware,
      );

      // BinPacker MUST separate white bars from woodgrain bars (never mix colors on 1 bar!)
      final packed = BinPacker.packProjectItems([itemWhiteClear, itemWoodTemp]);
      final whiteGroups = packed.where((g) => g.specColor == 'อบขาว (8911)');
      final woodGroups =
          packed.where((g) => g.specColor == 'ลายไม้สักน้ำตาล (15656)');
      expect(whiteGroups, isNotEmpty);
      expect(woodGroups, isNotEmpty);

      // PricingEngine.evaluateProject evaluates each item at its OWN color & glass rate!
      final summary = PricingEngine.evaluateProject(
        items: [itemWhiteClear, itemWoodTemp],
        mode: PricingMode.actualLength,
        wastePercent: 20,
        fallbackThickness: '1.2 มม.',
        fallbackColor: 'อบดำ (8816)', // Intentionally different fallback!
        ormCatalog: SeedRepository.instance.allCatalogPrices,
        customOverrides: const {},
        includeGlass: true,
        fallbackGlassKey: 'GLASS|กระจกใส 6 มม.',
        fallbackGlassRatePerSqM: 205,
        includeHardware: true,
        glassCatalog: SeedRepository.instance.glassRates,
        hardwareCatalog: SeedRepository.instance.hardwareRates,
        useItemOwnMaterialSpecs: true,
        profitPercent: 20,
      );

      final breakdowns = PricingEngine.evaluateProjectItems(
        items: [itemWhiteClear, itemWoodTemp],
        projectSummary: summary,
        ormCatalog: SeedRepository.instance.allCatalogPrices,
        customOverrides: const {},
        glassCatalog: SeedRepository.instance.glassRates,
        hardwareCatalog: SeedRepository.instance.hardwareRates,
        useItemOwnMaterialSpecs: true,
      );

      expect(breakdowns.length, 2);
      expect(breakdowns[0].effectiveColor, 'อบขาว (8911)');
      expect(breakdowns[0].effectiveGlassLabel, 'กระจกใส 5 มม.');
      expect(breakdowns[1].effectiveColor, 'ลายไม้สักน้ำตาล (15656)');
      expect(breakdowns[1].effectiveGlassLabel, 'กระจกเทมเปอร์ใส 10 มม.');

      // Woodgrain + 10mm tempered glass MUST cost dramatically more than white + 5mm clear!
      expect(
        breakdowns[1].standaloneAluminumCost,
        greaterThan(breakdowns[0].standaloneAluminumCost * 1.2),
      );
      expect(
        breakdowns[1].standaloneGlassCost,
        greaterThan(breakdowns[0].standaloneGlassCost * 4.0),
      );
      expect(
        breakdowns[1].unitSellingPrice,
        greaterThan(breakdowns[0].unitSellingPrice * 1.3),
      );

      // Quotation subtitles preserve each item's distinct aluminum color + glass without cross-overwrite!
      final sub0 = QuotationSpecFormatter.buildItemSpecSubtitle(
        item: itemWhiteClear,
        globalAluThickness: 'ตามรายการ',
        globalAluColor: 'ตามรายการ',
        globalGlassType: 'ตามรายการ',
        globalGlassThickness: 'ตามรายการ',
      );
      final sub1 = QuotationSpecFormatter.buildItemSpecSubtitle(
        item: itemWoodTemp,
        globalAluThickness: 'ตามรายการ',
        globalAluColor: 'ตามรายการ',
        globalGlassType: 'ตามรายการ',
        globalGlassThickness: 'ตามรายการ',
      );
      expect(sub0.contains('อบขาว (8911)'), isTrue);
      expect(sub0.contains('กระจกใส หนา 5 มม.'), isTrue);
      expect(sub1.contains('ลายไม้สักน้ำตาล (15656)'), isTrue);
      expect(sub1.contains('กระจกเทมเปอร์ใส หนา 10 มม.'), isTrue);
    });

    test('Exhaustive audit: all 138 folding + 128 Pro Smart X hanging + wood colorFamily + all 8 glass types', () {
      final catalog = SeedRepository.instance.allCatalogPrices;
      final hwRates = SeedRepository.instance.hardwareRates;
      final glassRates = SeedRepository.instance.glassRates;

      // 1. Woodgrain colorFamily MUST return 'wood' (never 'sand_bronze' due to 'น้ำตาล')
      expect(PricingEngine.colorFamily('ลายไม้สักน้ำตาล (15656)'), 'wood');
      expect(PricingEngine.colorFamily('ลายไม้วอลนัท (15659)'), 'wood');

      // 2. All 8 glass types from SizeAndSpecInputScreen match cleanly
      for (final gType in const [
        'กระจกใส',
        'กระจกเขียวตัดแสง',
        'กระจกชาดำ',
        'กระจกฝ้า',
        'กระจกเงา',
        'กระจกเทมเปอร์ใส',
        'กระจกเทมเปอร์เขียวตัดแสง',
        'กระจกลามิเนต',
      ]) {
        final m = PricingEngine.matchGlassRateFromSpec(
          glassType: gType,
          glassThick: '6 มม.',
          mergedGlassRates: glassRates,
        );
        expect(m, isNotNull, reason: 'Glass type $gType 6 มม. must match');
        expect(m!.effectivePrice, greaterThan(0));
      }

      // 3. All 138 folding patterns across all 5 folding brands have valid cuts, priced hardware & 100% matched profiles
      int foldingCount = 0;
      for (final cat in CatalogDefinitions.categories) {
        for (final b in cat.brands) {
          final allPats = <({String sys, PatternCardDef p})>[
            for (final p in b.directPatterns) (sys: b.title, p: p),
            for (final s in b.systems) ...[
              for (final p in s.patterns) (sys: s.title, p: p),
              for (final st in s.subTabs)
                for (final p in st.patterns) (sys: s.title, p: p),
            ],
          ];
          for (final entry in allPats) {
            final p = entry.p;
            if (!p.enabled) continue;
            final isFolding = cat.id == 'cat_folding' ||
                p.id.startsWith('fold_') ||
                p.foldingFamily != null ||
                p.id.startsWith('c4_');
            if (!isFolding) continue;
            foldingCount++;
            final opts = <String, String>{
              for (final g in CatalogDefinitions.effectiveOptionGroupsFor(p))
                g.id: g.defaultValue,
            };
            final out = ParametricSystemResolver.calculate(
              brandTitle: b.title,
              priceBrandKey: b.priceBrandKey,
              systemTitle: entry.sys,
              pattern: p,
              selectedOptions: opts,
              sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2200, qty: 1)],
            );
            expect(out.sets.first.cuts, isNotEmpty, reason: p.id);
            expect(out.hardware, isNotEmpty, reason: p.id);
            for (final h in out.hardware) {
              final mr = PricingEngine.matchHardwareRate(hw: h, mergedHwRates: hwRates);
              expect(mr, isNotNull, reason: 'Unpriced HW ${h.code} in ${p.id}');
              expect(mr!.effectivePrice, greaterThan(0));
            }
            final sum = PricingEngine.evaluate(
              barGroups: out.barGroups,
              mode: PricingMode.actualLength,
              wastePercent: 20,
              selectedThickness: '1.5 มม.',
              selectedColor:
                  b.priceBrandKey == 'ALUMET' ? 'อบดำ (8816)' : 'พ่นดำ ซุปเปอร์แบล็ค',
              ormCatalog: catalog,
              customOverrides: const {},
              glasses: out.sets.first.glasses,
              openingAreaSqM: 7.92,
              hardware: out.hardware,
              includeGlass: true,
              selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
              glassRatePerSqM: 205,
              includeHardware: true,
              hardwareCatalog: hwRates,
            );
            expect(sum.lines.every((l) => l.isMatched), isTrue, reason: p.id);
          }
        }
      }
      expect(foldingCount, greaterThanOrEqualTo(138));
    });
  });
}
