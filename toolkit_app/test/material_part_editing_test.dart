import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/bin_packer.dart';
import 'package:toolkit_app/engine/material_mutation_helper.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/screens/projects_and_quotation_screens.dart';
import 'package:toolkit_app/screens/result_and_pricing_screens.dart';

CalculationOutput _buildSampleNexOutput() {
  final nexBrand = CatalogDefinitions.categories[1].brands
      .firstWhere((b) => b.id == 'c2_alumet_nex');
  final s2Pat = nexBrand.systems.first.patterns.first;
  return ParametricSystemResolver.calculate(
    brandTitle: nexBrand.title,
    priceBrandKey: nexBrand.priceBrandKey,
    systemTitle: nexBrand.systems.first.title,
    pattern: s2Pat,
    selectedOptions: {
      for (final g in s2Pat.optionGroups) g.id: g.defaultValue,
    },
    sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
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
  });

  test('MaterialMutationHelper supports cross-brand profile swap, direct bars, cut-length 1D bin-packing, glass, and hardware', () {
    final orig = _buildSampleNexOutput();
    expect(orig.barGroups.length, 8);

    // 1. Cross-brand swap PS-0106 (ALUMET NEX) -> SS-X110 (ALUMET Smart X, 6400mm stock)
    final ps0106Grp = orig.barGroups.firstWhere((g) => g.code == 'PS-0106');
    final swapped = MaterialMutationHelper.swapProfileGroup(
      orig,
      oldBrand: ps0106Grp.brand,
      oldCode: ps0106Grp.code,
      oldStockMm: ps0106Grp.stockLengthMm,
      newBrand: 'ALUMET',
      newCode: 'SS-X110',
      newName: 'เฟรมข้าง Smart X',
      newStockMm: 6400,
    );
    expect(swapped.barGroups.any((g) => g.code == 'PS-0106'), isFalse);
    final ssGrp = swapped.barGroups.firstWhere((g) => g.code == 'SS-X110');
    expect(ssGrp.brand, 'ALUMET');

    final pSwapped = PricingEngine.evaluate(
      barGroups: swapped.barGroups,
      mode: PricingMode.actualLength,
      wastePercent: 20.0,
      selectedThickness: '1.2 มม.',
      selectedColor: 'อบดำ (8816)',
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: const {},
    );
    expect(pSwapped.matchedCount, 8);
    expect(pSwapped.totalCount, 8);
    final ssLine = pSwapped.lines.firstWhere((l) => l.group.code == 'SS-X110');
    expect(ssLine.unitPricePerBar, 2410.0);

    // 2. Add direct-bar off-formula profile (2 bars of PF-0101)
    final withDirect = MaterialMutationHelper.addCutItem(
      swapped,
      cut: MaterialMutationHelper.buildDirectBarCut(
        section: 'เพิ่มเติม',
        code: 'PF-0101',
        name: 'กล่องช่องแสงเสริม',
        stockMm: 6400,
        barCount: 2,
      ),
    );
    final pfGrp = withDirect.barGroups.firstWhere((g) => g.code == 'PF-0101');
    expect(pfGrp.estimatedBars, 2);
    expect(pfGrp.totalBars, 2);

    // 3. Add cut-length off-formula profile (4 pieces × 2200mm on 6400mm stock -> exact 2 bars!)
    final withCut = MaterialMutationHelper.addCutItem(
      withDirect,
      cut: MaterialMutationHelper.buildCutLengthItem(
        section: 'เพิ่มเติม',
        code: 'SS-0138',
        name: 'เสาเสริมพิเศษ',
        stockMm: 6400,
        lengthMm: 2200,
        totalQty: 4,
        brandOverride: 'ALUMET',
      ),
    );
    final cutGrp = withCut.barGroups.firstWhere((g) => g.code == 'SS-0138');
    expect(cutGrp.brand, 'ALUMET');
    expect(cutGrp.confirmedBars.length, 2);
    expect(cutGrp.exactCutSumMm, 8800.0);

    // 4. Add & edit Glass + Hardware
    final withGlass = MaterialMutationHelper.addGlassItem(
      withCut,
      glass: const EvaluatedGlassItem(
        name: 'กระจกช่องแสงเพิ่ม',
        siteCut: false,
        widthMm: 1000,
        heightMm: 1500,
        totalPanels: 2,
        setIndex: 1,
      ),
    );
    final extraGlass = withGlass.sets.first.glasses.last;
    expect(extraGlass.name, 'กระจกช่องแสงเพิ่ม');
    expect(extraGlass.totalPanels, 2);

    final withHw = MaterialMutationHelper.addHardwareItem(
      withGlass,
      const AggregatedHardwareItem(
        code: 'HW-EXTRA',
        name: 'มือจับพิเศษเพิ่มเติม',
        numericQty: 2,
        unitOrNote: 'ชุด',
      ),
    );
    expect(withHw.hardware.any((h) => h.name == 'มือจับพิเศษเพิ่มเติม'), isTrue);
  });

  test('SQLite updateProjectItemMaterials persists cross-brand cuts and updates project bin-packing', () async {
    final orig = _buildSampleNexOutput();
    final pid = await AppDatabase.instance.createProject(
      name: 'ทดสอบแก้ไขวัสดุโปรเจกต์',
      note: 'ชั้น 1',
    );
    final itemId = await AppDatabase.instance.addProjectItem(
      SavedProjectItem(
        projectId: pid,
        sortIndex: 0,
        refCode: 'D1',
        installLocation: 'หน้าบ้าน',
        brandTitle: orig.brandTitle,
        priceBrandKey: orig.priceBrandKey,
        systemTitle: orig.systemTitle,
        patternId: orig.patternId,
        patternTitle: orig.patternTitle,
        selectedOptions: orig.selectedOptions,
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
        evaluatedSets: orig.sets,
        hardware: orig.hardware,
      ),
    );

    final ps0106Grp = orig.barGroups.firstWhere((g) => g.code == 'PS-0106');
    final mutated = MaterialMutationHelper.addHardwareItem(
      MaterialMutationHelper.swapProfileGroup(
        orig,
        oldBrand: ps0106Grp.brand,
        oldCode: ps0106Grp.code,
        oldStockMm: ps0106Grp.stockLengthMm,
        newBrand: 'ALUMET',
        newCode: 'SS-X110',
        newName: 'เฟรมข้าง Smart X',
        newStockMm: 6400,
      ),
      const AggregatedHardwareItem(
        code: 'EX-01',
        name: 'กันชนเสริม',
        numericQty: 3,
        unitOrNote: 'ชิ้น',
      ),
    );

    await AppDatabase.instance.updateProjectItemMaterials(
      itemId: itemId,
      projectId: pid,
      evaluatedSets: mutated.sets,
      hardware: mutated.hardware,
    );

    final reloaded = await AppDatabase.instance.getProject(pid);
    expect(reloaded, isNotNull);
    expect(reloaded!.items, hasLength(1));
    final it = reloaded.items.first;
    expect(it.hardware.any((h) => h.name == 'กันชนเสริม' && h.numericQty == 3), isTrue);

    final packed = BinPacker.packProjectItems(reloaded.items);
    expect(packed.any((g) => g.code == 'PS-0106'), isFalse);
    expect(packed.any((g) => g.brand == 'ALUMET' && g.code == 'SS-X110'), isTrue);

    await AppDatabase.instance.deleteProject(pid);
  });

  testWidgets('ResultScreen live cross-brand swap via Catalog Picker, add hardware, Tab 4 sync, and Reset to original', (tester) async {
    await tester.runAsync(() => AppDatabase.instance.markPricingNoticeSeen());
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final out = _buildSampleNexOutput();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: ResultScreen(
          output: out,
          sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Tap PS-0106 cut piece on Tab 1 -> open editor -> open Catalog Picker -> pick SS-X110
    await tester.tap(find.text('PS-0106').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('btn_open_profile_catalog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('btn_open_profile_catalog')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('catalog_profile_search')),
      'SS-X110',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick_profile_ALUMET_SS-X110')));
    await tester.pumpAndSettle();

    // Save the swapped part
    final saveMatBtn = find.byKey(const ValueKey('btn_save_material'));
    await tester.ensureVisible(saveMatBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveMatBtn);
    await tester.pumpAndSettle();

    // Verify SS-X110 + cross-brand ALUMET tag + Reset button appear live in Tab 1
    expect(find.text('SS-X110'), findsWidgets);
    expect(find.byKey(const ValueKey('btn_reset_materials')), findsOneWidget);

    // 2. Switch to Tab 2 -> verify SS-X110 is present and add off-formula hardware
    await tester.tap(find.text('ถอดรายการ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SS-X110'), findsWidgets);

    final addHwBtn = find.byKey(const ValueKey('tab2_add_hw'));
    await tester.scrollUntilVisible(
      addHwBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addHwBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit_hw_name_field')),
      'กันชนเสริมพิเศษ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit_hw_qty_field')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('btn_save_material')));
    await tester.pumpAndSettle();
    expect(find.textContaining('กันชนเสริมพิเศษ'), findsWidgets);

    // 3. Switch to Tab 4 -> verify SS-X110 priced at ฿2,410.00 / เส้น!
    await tester.tap(find.text('ทำราคา'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SS-X110'), findsWidgets);
    expect(find.text('฿2,410.00 / เส้น'), findsOneWidget);

    // 4. Tap Reset to original formula -> PS-0106 restored, SS-X110 gone!
    await tester.tap(find.byKey(const ValueKey('btn_reset_materials')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PS-0106'), findsWidgets);
    expect(find.textContaining('SS-X110'), findsNothing);
    expect(find.byKey(const ValueKey('btn_reset_materials')), findsNothing);
  });

  testWidgets('ProjectDetailScreen opens saved item editor and saves updated materials back to SQLite', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final orig = _buildSampleNexOutput();
    final pid = await tester.runAsync(
      () => AppDatabase.instance.createProject(name: 'บ้านทดสอบแก้จากโปรเจกต์'),
    );
    final itemId = await tester.runAsync(
      () => AppDatabase.instance.addProjectItem(
        SavedProjectItem(
          projectId: pid!,
          sortIndex: 0,
          refCode: 'W1',
          installLocation: 'ห้องรับแขก',
          brandTitle: orig.brandTitle,
          priceBrandKey: orig.priceBrandKey,
          systemTitle: orig.systemTitle,
          patternId: orig.patternId,
          patternTitle: orig.patternTitle,
          selectedOptions: orig.selectedOptions,
          sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
          evaluatedSets: orig.sets,
          hardware: orig.hardware,
        ),
      ),
    );
    addTearDown(() async {
      await tester.runAsync(() => AppDatabase.instance.deleteProject(pid!));
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Sarabun'),
        home: ProjectDetailScreen(projectId: pid!),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    // Tap 'แก้ไข / เปลี่ยนวัสดุ' on saved item
    final editBtn = find.byKey(ValueKey('proj_edit_mat_$itemId'));
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    // Verify middle button shows 'บันทึกการแก้ไข'
    expect(find.text('บันทึกการแก้ไข'), findsOneWidget);

    // Switch to Tab 2 and add custom hardware
    await tester.tap(find.text('ถอดรายการ'));
    await tester.pumpAndSettle();
    final addHwBtn = find.byKey(const ValueKey('tab2_add_hw'));
    await tester.scrollUntilVisible(
      addHwBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addHwBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit_hw_name_field')),
      'มือจับพิเศษโปรเจกต์',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit_hw_qty_field')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('btn_save_material')));
    await tester.pumpAndSettle();

    // Wait for confirmation SnackBar to dismiss before tapping bottom CTA
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Save edited materials back into SQLite
    await tester.tap(find.byKey(const ValueKey('btn_save_result_middle')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    final reloaded = await tester.runAsync(
      () => AppDatabase.instance.getProject(pid),
    );
    expect(
      reloaded!.items.first.hardware
          .any((h) => h.name == 'มือจับพิเศษโปรเจกต์' && h.numericQty == 3),
      isTrue,
    );
  });
}
