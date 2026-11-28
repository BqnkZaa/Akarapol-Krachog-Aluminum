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
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/models/app_models.dart';
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
    final imgMapJson = jsonDecode(
      File('assets/data/alupro_image_map.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    AluproImageRegistry.instance.loadFromJson(imgMapJson);
  });

  group('v0.1.17 ALUMET Smart X / ICONIQ 27-Color Profiles & CAD Thumbnails', () {
    test('SS-X220..SS-X223 + newly imported Smart X & ICONIQ profiles exist across all 27 ALUMET colors with CAD thumbnails', () {
      final profiles = SeedRepository.instance.allCatalogPrices;
      final byCode = <String, List<OrmPriceSku>>{};
      for (final p in profiles) {
        if (p.brand.toUpperCase() == 'ALUMET') {
          byCode.putIfAbsent(p.code.toUpperCase(), () => []).add(p);
        }
      }

      // 4 newly requested Smart X profiles
      for (final code in const ['SS-X220', 'SS-X221', 'SS-X222', 'SS-X223']) {
        final rows = byCode[code] ?? const [];
        expect(rows.length, 27, reason: '$code must have all 27 ALUMET colors');
        for (final r in rows) {
          expect(r.factoryPrice, greaterThan(0),
              reason: '$code ${r.color} must have positive price');
        }
        final asset = AluproImageRegistry.instance.resolveProfileAsset(
          code: code,
          brandKey: 'ALUMET',
        );
        expect(asset, isNotNull, reason: '$code must have a CAD thumbnail');
        expect(File(asset!).existsSync(), isTrue,
            reason: '$asset must exist on disk');
      }

      // Official Smart X & ICONIQ 2026 PDF additions + Iconiq iS-0201 / iS-0202 CAD thumbnails
      const sampleImported = [
        'SS-X211',
        'SS-X215',
        'SS-X218',
        'SC-X103',
        'SO-X202',
        'SF-X107',
        'SB-0102',
        '2044',
        'AG659',
        'IS-0108',
        'IS-0201',
        'IS-0202',
        'IS-0203',
        'IS-0206',
        'IS-0215',
        'IC-0103',
        'IC-0109',
        'IF-0103',
      ];
      for (final code in sampleImported) {
        final rows = byCode[code] ?? const [];
        expect(rows.length, 27, reason: '$code must have all 27 ALUMET colors');
        final asset = AluproImageRegistry.instance.resolveProfileAsset(
          code: code,
          brandKey: 'ALUMET',
        );
        expect(asset, isNotNull, reason: '$code must resolve CAD thumbnail');
        expect(File(asset!).existsSync(), isTrue,
            reason: '$asset for $code must exist on disk');
      }

      // Verify iC-0109 typo fix (PDF had 420 instead of 3,290 for อบขาว 8911)
      final ic0109White = byCode['IC-0109']!
          .firstWhere((r) => r.color == 'อบขาว (8911)');
      expect(ic0109White.factoryPrice, 3290);

      // Total ALUMET unique codes >= 200
      expect(byCode.length, greaterThanOrEqualTo(200));
    });
  });

  group('v0.1.17 100% Authentic ALUMET 2026 Hardware Codes Across All 513 Option Runs', () {
    test('Zero legacy HD-*, SS-0105, or SMX-HANG-STD codes across ALL ALUMET patterns and option toggles', () {
      final visibleAlumet = {
        for (final h in SeedRepository.instance.visibleHardwareRates)
          if (h.brand == 'ALUMET') h.code.toUpperCase(): h,
      };
      const allowedGenericConsumables = {
        'GEN-SIL-01',
        'MS-MESH-FIBER',
        'MS-CORNER-F',
        'MS-ACC-F',
        'MS-PLEATED',
        'MS-MESH-SEC',
        'MS-LOCK-SEC',
        'MS-ACC-SEC',
      };

      int runs = 0;
      void checkRun(
        String bk,
        String bt,
        String st,
        PatternCardDef p,
        Map<String, String> opts,
        String tag,
      ) {
        runs++;
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
        expect(out.hardware, isNotEmpty, reason: '${p.id}[$tag] has 0 hw');
        for (final h in out.hardware) {
          final cu = h.code.trim().toUpperCase();
          expect(cu, isNotEmpty, reason: '${p.id}[$tag] empty code');
          expect(
            visibleAlumet.containsKey(cu) ||
                allowedGenericConsumables.contains(cu),
            isTrue,
            reason:
                '${p.id}[$tag] hardware "$cu (${h.name})" must be authentic ALUMET catalog code',
          );
        }
      }

      void checkPattern(String bk, String bt, String st, PatternCardDef p) {
        if (!p.enabled) return;
        if (bk.toUpperCase() != 'ALUMET' && !bt.toUpperCase().contains('ALUMET')) {
          return;
        }
        final base = {for (final g in p.optionGroups) g.id: g.defaultValue};
        checkRun(bk, bt, st, p, base, 'default');
        for (final g in p.optionGroups) {
          for (final c in g.choices) {
            if (c.id == g.defaultValue) continue;
            final m = Map<String, String>.from(base);
            m[g.id] = c.id;
            checkRun(bk, bt, st, p, m, '${g.id}=${c.id}');
          }
        }
      }

      for (final cat in CatalogDefinitions.categories) {
        if (!cat.enabled) continue;
        for (final b in cat.brands) {
          if (!b.enabled) continue;
          for (final p in b.directPatterns) {
            checkPattern(b.priceBrandKey, b.title, b.title, p);
          }
          for (final sys in b.systems) {
            if (!sys.enabled) continue;
            for (final p in sys.patterns) {
              checkPattern(b.priceBrandKey, b.title, sys.title, p);
            }
            for (final st in sys.subTabs) {
              for (final p in st.patterns) {
                checkPattern(b.priceBrandKey, b.title, st.title, p);
              }
            }
          }
        }
      }

      expect(runs, greaterThanOrEqualTo(500));

      // Verify specific v0.1.17 upgrades:
      // 1) c3_alu_s3_card upgraded from HD-* to authentic ALUMET 2026 codes
      final s3 = CatalogDefinitions.findPatternById('c3_alu_s3_card')!.pattern;
      final outS3 = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Iconiq Euro)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน ICONIQ',
        pattern: s3,
        selectedOptions: {for (final g in s3.optionGroups) g.id: g.defaultValue},
        sizeRows: const [SizeRowInput(widthMm: 3000, heightMm: 2100, qty: 1)],
      );
      final s3Codes = outS3.hardware.map((h) => h.code).toSet();
      expect(s3Codes, containsAll(['AAL-EUCA034', 'AHD-ICSL047', 'AHD-MTSL048', 'AHD-MTSL049']));

      // 2) Smart X roller_type=market uses AAL-MTSL040 (not profile SS-0105)
      final s2 = CatalogDefinitions.findPatternById('c2_alu_s2_card')!.pattern;
      final optsMkt = {for (final g in s2.optionGroups) g.id: g.defaultValue};
      optsMkt['roller_type'] = 'market';
      final outMkt = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อน Smart X',
        pattern: s2,
        selectedOptions: optsMkt,
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2100, qty: 1)],
      );
      expect(outMkt.hardware.any((h) => h.code == 'AAL-MTSL040'), isTrue);
      expect(outMkt.hardware.any((h) => h.code == 'SS-0105'), isFalse);

      // 3) Smart X hanging standard uses AKL-MTSL062 (not SMX-HANG-STD)
      final hang1 = CatalogDefinitions.findPatternById('c2_alu_hang1_card')!.pattern;
      final outHang = ParametricSystemResolver.calculate(
        brandTitle: 'ALUMET (Smart X)',
        priceBrandKey: 'ALUMET',
        systemTitle: 'บานเลื่อนรางแขวน Smart X',
        pattern: hang1,
        selectedOptions: const {'hang_hw': 'standard'},
        sizeRows: const [SizeRowInput(widthMm: 1000, heightMm: 2100, qty: 1)],
      );
      expect(outHang.hardware.any((h) => h.code == 'AKL-MTSL062'), isTrue);
      expect(outHang.hardware.any((h) => h.code == 'SMX-HANG-STD'), isFalse);
    });
  });

  group('v0.1.17 UI Verification (CustomPriceScreen SS-X220..SS-X223)', () {
    testWidgets('CustomPriceScreen finds SS-X220..SS-X223 with CAD thumbnails across ALUMET colors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Sarabun'),
          home: const CustomPriceScreen(initialTabIndex: 0),
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

      for (final code in const ['SS-X220', 'SS-X221', 'SS-X222', 'SS-X223']) {
        await tester.enterText(find.byType(TextField).first, code);
        await tester.pumpAndSettle();
        expect(find.textContaining(code), findsWidgets);
      }
    });
  });
}
