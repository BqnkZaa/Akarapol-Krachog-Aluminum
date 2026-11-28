import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/screens/custom_system_studio_screens.dart';
import 'package:toolkit_app/screens/material_editor_sheets.dart';

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

  group('v0.1.15 Item 1: Partial/Fuzzy Searchable Autocomplete Engine', () {
    test('searchCatalogProfiles supports partial Thai words, hyphen-less codes, and active-brand priority', () {
      final opts = buildCatalogProfileOptions(
        catalog: SeedRepository.instance.allCatalogPrices,
        customOverrides: const {},
      );
      expect(opts.length, greaterThan(100));

      // Hyphen-insensitive partial code search
      final resCode = searchCatalogProfiles(
        options: opts,
        query: 'x110',
        preferredBrand: 'ALUMET',
      );
      expect(resCode, isNotEmpty);
      expect(resCode.first.code, contains('X110'));
      expect(resCode.first.brand, 'ALUMET');

      // Partial multi-word Thai name search (no need to type full name)
      final resThai = searchCatalogProfiles(
        options: opts,
        query: 'เฟรม บน',
        preferredBrand: 'ALUMET',
      );
      expect(resThai, isNotEmpty);
      expect(resThai.first.brand, 'ALUMET');
      expect(resThai.first.name, contains('เฟรมบน'));

      // Empty query acts as instant browseable dropdown for preferredBrand
      final resEmpty = searchCatalogProfiles(
        options: opts,
        query: '',
        preferredBrand: 'ALUMET',
      );
      expect(resEmpty.length, 12);
      expect(resEmpty.every((e) => e.brand == 'ALUMET'), isTrue);
    });

    test('searchCatalogHardware supports partial Thai words & compact codes across ALUMET, VVP, RP', () {
      final hw = SeedRepository.instance.visibleHardwareRates;

      final resVvp = searchCatalogHardware(
        items: hw,
        query: 'fc34',
        preferredBrand: 'VVP',
      );
      expect(resVvp, isNotEmpty);
      expect(resVvp.first.code, 'FC 34');

      final resDuck = searchCatalogHardware(
        items: hw,
        query: 'ปากเป็ด',
        preferredBrand: 'ALUMET',
      );
      expect(resDuck, isNotEmpty);
      expect(resDuck.any((h) => h.code == 'AKL-SMBF031'), isTrue);

      final resRp = searchCatalogHardware(
        items: hw,
        query: 'บานพับ ชาวเวอร์',
        preferredBrand: 'RP',
      );
      expect(resRp, isNotEmpty);
      expect(resRp.first.brand, 'RP');
    });
  });

  group('v0.1.15 Item 1 & 2 Widget Verification: Autocomplete Dropdown + Glass siteCut Switch', () {
    testWidgets('FormulaOverrideEditorScreen dropdown auto-fills code & name on partial search and unlocks siteCut glass formula', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // c2_alu_s2_card has siteCut=true glass by default — perfect match for customer's tablet screenshot!
      final pat = CatalogDefinitions.findPatternById('c2_alu_s2_card')!.pattern;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: FormulaOverrideEditorScreen(
            pattern: pat,
            brandTitle: 'ALUMET (Smart X)',
            priceBrandKey: 'ALUMET',
            systemTitle: 'บานเลื่อน Smart X',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Type partial code 'x116' into Cut #1 name/code field -> dropdown opens -> tap SS-X116 -> both code & name update!
      final codeField = find.byKey(const ValueKey('override_cut_code_0'));
      await tester.tap(codeField);
      await tester.enterText(codeField, 'x116');
      await tester.pumpAndSettle();

      expect(find.text('SS-X116'), findsWidgets);
      await tester.tap(find.text('SS-X116').last);
      await tester.pumpAndSettle();

      final codeWidget = tester.widget<TextField>(codeField);
      final nameWidget = tester.widget<TextField>(
        find.byKey(const ValueKey('override_cut_name_0')),
      );
      expect(codeWidget.controller!.text, 'SS-X116');
      expect(nameWidget.controller!.text, contains('รางแขวน'));

      // 2. Scroll to Glass section & toggle siteCut switch OFF -> unlocks W/H formula fields & shows live preview!
      final siteCutSwitch = find.byKey(const ValueKey('override_glass_sitecut_0'));
      await tester.scrollUntilVisible(
        siteCutSwitch,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final swBefore = tester.widget<SwitchListTile>(siteCutSwitch);
      if (swBefore.value) {
        await tester.tap(siteCutSwitch);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('override_glass_w_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('override_glass_h_0')), findsOneWidget);
      expect(find.textContaining('ขนาดกระจกทดสอบ ='), findsOneWidget);

      // 3. Scroll to Hardware section, type partial Thai 'โช้ค ฝัง' -> dropdown suggests FC 34 -> tap fills code & name!
      final hwNameField = find.byKey(const ValueKey('override_hw_name_0'));
      await tester.scrollUntilVisible(
        hwNameField,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(hwNameField);
      await tester.enterText(hwNameField, 'โช้ค ฝัง');
      await tester.pumpAndSettle();
      expect(find.text('FC 34'), findsWidgets);
      await tester.tap(find.text('FC 34').last);
      await tester.pumpAndSettle();

      final hwCodeWidget = tester.widget<TextField>(
        find.byKey(const ValueKey('override_hw_code_0')),
      );
      expect(hwCodeWidget.controller!.text, 'FC 34');
    });

    testWidgets('CustomSystemEditorScreen exposes searchable profile & hardware autocomplete dropdowns', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: const CustomSystemEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final toggleBtn = find.byKey(const ValueKey('custom_cut_toggle_0'));
      await tester.scrollUntilVisible(
        toggleBtn,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('เลือกหน้าตัด'), findsOneWidget);
    });
  });
}
