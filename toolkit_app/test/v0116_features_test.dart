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
import 'package:toolkit_app/pdf/project_pdf.dart';
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

  group('v0.1.16 Complete 505-Pattern Hardware, Code & Catalog Integrity', () {
    test('100% of all enabled patterns resolve non-empty coded and priced hardware', () {
      final allHwRates = PricingEngine.mergeMaterialRates(
        SeedRepository.instance.hardwareRates,
        const {},
        category: 'HARDWARE',
      );
      int total = 0;
      for (final cat in CatalogDefinitions.categories) {
        if (!cat.enabled) continue;
        void check(String bk, String bt, String st, PatternCardDef p) {
          if (!p.enabled) return;
          total++;
          final opts = {for (final g in p.optionGroups) g.id: g.defaultValue};
          final out = ParametricSystemResolver.calculate(
            brandTitle: bt,
            priceBrandKey: bk,
            systemTitle: st,
            pattern: p,
            selectedOptions: opts,
            sizeRows: const [
              SizeRowInput(widthMm: 2000, heightMm: 2100, auxMm: 1650, qty: 1),
            ],
          );
          expect(out.hardware, isNotEmpty, reason: '${p.id} must have hardware');
          for (final h in out.hardware) {
            expect(
              h.code.trim(),
              isNotEmpty,
              reason: '${p.id} hardware "${h.name}" must have a code',
            );
            if ((h.effectiveQty ?? 0) > 0) {
              final r = PricingEngine.matchHardwareRate(
                hw: h,
                mergedHwRates: allHwRates,
              );
              expect(
                r,
                isNotNull,
                reason: '${p.id} hardware "${h.code} · ${h.name}" must be priced',
              );
            }
          }
        }

        for (final sys in cat.directSystems) {
          if (!sys.enabled) continue;
          for (final p in sys.patterns) {
            check('MARKET', 'ชุดตลาด', sys.title, p);
          }
          for (final st in sys.subTabs) {
            for (final p in st.patterns) {
              check('MARKET', 'ชุดตลาด', st.title, p);
            }
          }
        }
        for (final b in cat.brands) {
          if (!b.enabled) continue;
          for (final p in b.directPatterns) {
            check(b.priceBrandKey, b.title, b.title, p);
          }
          for (final sys in b.systems) {
            if (!sys.enabled) continue;
            for (final p in sys.patterns) {
              check(b.priceBrandKey, b.title, sys.title, p);
            }
            for (final st in sys.subTabs) {
              for (final p in st.patterns) {
                check(b.priceBrandKey, b.title, st.title, p);
              }
            }
          }
        }
      }
      expect(total, greaterThanOrEqualTo(500));
    });

    test('Visible catalog stays strictly 258 items with cleaned ALUMET names and realistic pack pricing', () {
      final visible = SeedRepository.instance.visibleHardwareRates;
      expect(visible.length, 258);
      final alu = visible.where((h) => h.brand == 'ALUMET').toList();
      expect(alu.length, 133);
      for (final h in alu) {
        expect(h.code.trim(), isNotEmpty);
        expect(h.name.trim(), isNot(h.code.trim()),
            reason: '${h.code} must have Thai description, not raw code');
        expect(h.name.contains('หมายเหตุ'), isFalse,
            reason: '${h.code} must not leak PDF footer text');
      }
      expect(
        alu.firstWhere((h) => h.code == 'ATP-MTSL060').name,
        contains('สปริกอส'),
      );
      expect(
        alu.firstWhere((h) => h.code == 'ACF-EUCA036').name,
        contains('มือจับหลบมุ้ง'),
      );

      // Pack-unit pricing safety check on ALUMET Smart X 2-panel (c2_alu_s2_card)
      final s2 = CatalogDefinitions.findPatternById('c2_alu_s2_card')!.pattern;
      final outS2 = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: s2,
        selectedOptions: {for (final g in s2.optionGroups) g.id: g.defaultValue},
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2100, qty: 1)],
      );
      final cornerCleat =
          outS2.hardware.firstWhere((h) => h.code == 'AAL-EUCA034');
      expect(cornerCleat.numericQty, 1);
      expect(cornerCleat.unitOrNote, 'แพค');

      final pricing = PricingEngine.evaluate(
        barGroups: outS2.barGroups,
        mode: PricingMode.actualLength,
        wastePercent: 20.0,
        selectedThickness: '1.2 มม.',
        selectedColor: 'อบดำ (8816)',
        ormCatalog: SeedRepository.instance.allCatalogPrices,
        customOverrides: const {},
        hardware: outS2.hardware,
        includeHardware: true,
        hardwareCatalog: SeedRepository.instance.hardwareRates,
      );
      // Realistic Smart X 2-panel hardware total (not inflated by 32 × 200 pack price!)
      expect(pricing.hardwareCost, greaterThan(1000));
      expect(pricing.hardwareCost, lessThan(3000));
    });
  });

  group('v0.1.16 Project Detail BOM UI, Tab 2 Coded BOM & Project PDF', () {
    testWidgets('ProjectDetailScreen Accordion 4 displays Aluminum, Glass & Merged Hardware (including 0-bar Shower + ALUMET Smart X 4-panel)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final projId = (await tester.runAsync(() async {
        final id = await AppDatabase.instance.createProject(
          name: 'บ้านตัวอย่าง v0.1.16',
          note: 'ทดสอบใบถอดของรวม',
        );

        // Item 1: VVP Shower 3-section (0 aluminum bars, pure glass + hardware)
        final shwPat = CatalogDefinitions.findPatternById('c5_vvp_shw_01')!.pattern;
        final shwOut = ParametricSystemResolver.calculate(
          brandTitle: 'VVP',
          priceBrandKey: 'VVP',
          systemTitle: 'ชุดชาวเวอร์',
          pattern: shwPat,
          selectedOptions: {
            for (final g in shwPat.optionGroups) g.id: g.defaultValue,
          },
          sizeRows: const [SizeRowInput(widthMm: 1800, heightMm: 2000, qty: 1)],
        );
        await AppDatabase.instance.addProjectItem(
          SavedProjectItem(
            projectId: id,
            sortIndex: 0,
            brandTitle: shwOut.brandTitle,
            priceBrandKey: shwOut.priceBrandKey,
            systemTitle: shwOut.systemTitle,
            patternId: shwOut.patternId,
            patternTitle: shwOut.patternTitle,
            selectedOptions: shwOut.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 1800, heightMm: 2000, qty: 1)],
            evaluatedSets: shwOut.sets,
            hardware: shwOut.hardware,
          ),
        );

        // Item 2: ALUMET Smart X 4-panel (previously 0 hardware -> now full coded ALUMET hardware!)
        final s4Pat = CatalogDefinitions.findPatternById('c2_alu_s4_card')!.pattern;
        final s4Out = ParametricSystemResolver.calculate(
          brandTitle: 'ALUMET (Smart X)',
          priceBrandKey: 'ALUMET',
          systemTitle: 'บานเลื่อน Smart X',
          pattern: s4Pat,
          selectedOptions: {
            for (final g in s4Pat.optionGroups) g.id: g.defaultValue,
          },
          sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2100, qty: 1)],
        );
        expect(s4Out.hardware.length, greaterThanOrEqualTo(9));
        await AppDatabase.instance.addProjectItem(
          SavedProjectItem(
            projectId: id,
            sortIndex: 1,
            brandTitle: s4Out.brandTitle,
            priceBrandKey: s4Out.priceBrandKey,
            systemTitle: s4Out.systemTitle,
            patternId: s4Out.patternId,
            patternTitle: s4Out.patternTitle,
            selectedOptions: s4Out.selectedOptions,
            sizeRows: const [SizeRowInput(widthMm: 3600, heightMm: 2100, qty: 1)],
            evaluatedSets: s4Out.sets,
            hardware: s4Out.hardware,
          ),
        );

        // Verify Project PDF generates cleanly with 0-bar Shower + ALUMET Smart X
        final loadedProj = (await AppDatabase.instance.getProject(id))!;
        final pdfBytes = await ProjectPdfGenerator.generate(
          loadedProj,
          const ProjectPdfOptions(),
          testFontsDir: 'assets/fonts',
        );
        expect(pdfBytes.length, greaterThan(5000));
        return id;
      }))!;

      // Verify ProjectDetailScreen Accordion 4 displays ALL 3 material groups!
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: ProjectDetailScreen(projectId: projId),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();

      final projScroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;

      final bomAcc = find.byKey(const ValueKey('proj_detail_bom_accordion'));
      await tester.scrollUntilVisible(
        bomAcc,
        250,
        scrollable: projScroll,
      );
      await tester.tap(find.textContaining('4. รายการวัสดุรวม'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('อุปกรณ์ประกอบรวมทั้งโครงการ'),
        250,
        scrollable: projScroll,
      );
      await tester.pumpAndSettle();

      // Both VVP Shower codes and ALUMET Smart X 4-panel codes appear in Project BOM!
      await tester.scrollUntilVisible(
        find.text('SW 304'),
        200,
        scrollable: projScroll,
      );
      expect(find.text('SW 304'), findsWidgets);
      expect(find.text('GC-502'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('AKL-MTSL030'),
        200,
        scrollable: projScroll,
      );
      expect(find.text('AKL-MTSL030'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('ATP-MTSL060'),
        200,
        scrollable: projScroll,
      );
      expect(find.text('ATP-MTSL060'), findsWidgets);
    });

    testWidgets('ResultScreen Tab 2 shows coded ALUMET hardware on previously-empty ICONIQ sliding and supports autocomplete add', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final iqPat = CatalogDefinitions.findPatternById('c3_alu_s2_card')!.pattern;
      final out = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (ICONIQ Euro)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน ICONIQ',
        pattern: iqPat,
        selectedOptions: {for (final g in iqPat.optionGroups) g.id: g.defaultValue},
        sizeRows: const [SizeRowInput(widthMm: 2200, heightMm: 2100, qty: 1)],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: ResultScreen(
            output: out,
            sizeRows: const [SizeRowInput(widthMm: 2200, heightMm: 2100, qty: 1)],
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 2: ถอดรายการ
      await tester.tap(find.text('ถอดรายการ'));
      await tester.pumpAndSettle();

      final verticalScroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;

      final hwCard = find.text('อุปกรณ์ประกอบ');
      await tester.scrollUntilVisible(
        hwCard,
        250,
        scrollable: verticalScroll,
      );
      await tester.pumpAndSettle();

      expect(find.text('ไม่มีรายการอุปกรณ์ประกอบ'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('AAL-EUCA034'),
        180,
        scrollable: verticalScroll,
      );
      expect(find.text('AAL-EUCA034'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AHD-ICSL047'),
        180,
        scrollable: verticalScroll,
      );
      expect(find.text('AHD-ICSL047'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AKL-MTSL031'),
        180,
        scrollable: verticalScroll,
      );
      expect(find.text('AKL-MTSL031'), findsOneWidget);

      // Tap "+ เพิ่มอุปกรณ์" -> autocomplete sheet opens -> type partial 'fc34' -> select FC 34 -> save
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tab2_add_hw')),
        -250,
        scrollable: verticalScroll,
      );
      await tester.tap(find.byKey(const ValueKey('tab2_add_hw')));
      await tester.pumpAndSettle();

      final codeField = find.byKey(const ValueKey('edit_hw_code_field'));
      await tester.tap(codeField);
      await tester.enterText(codeField, 'fc34');
      await tester.pumpAndSettle();

      expect(find.text('FC 34'), findsWidgets);
      await tester.tap(find.text('FC 34').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_save_material')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('FC 34'),
        200,
        scrollable: verticalScroll,
      );
      expect(find.text('FC 34'), findsOneWidget);
    });
  });
}
