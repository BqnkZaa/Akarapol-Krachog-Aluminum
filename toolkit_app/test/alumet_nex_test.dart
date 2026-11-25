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
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/engine/quotation_spec_formatter.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/pdf/quotation_pdf.dart';
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

  test('All 15 official ALUMET NEX SKUs match exact 21/11/2569 retail prices across all 4 stock colors', () {
    final catalog = SeedRepository.instance.allCatalogPrices;

    // Exact table from official PDF: Update 21/11/2569 (8911, 8816, 8820, Mill)
    const officialTable = <String, (String, double, double, double, double)>{
      'PS-0206': ('1.2 มม.', 1185, 1185, 1250, 1100),
      'PS-0208': ('1.2 มม.', 1030, 1030, 1085, 955),
      'PS-0207': ('1.2 มม.', 1150, 1150, 1210, 1070),
      'PS-0210': ('1.2 มม.', 1110, 1110, 1165, 1030),
      'PS-0107': ('1.2 มม.', 1840, 1840, 1935, 1710),
      'PS-0108': ('1.2 มม.', 2090, 2090, 2200, 1940),
      'PS-0106': ('1.2 มม.', 1290, 1290, 1355, 1200),
      'PS-0111': ('1.2 มม.', 670, 670, 705, 625),
      'PC-0203': ('1.0 มม.', 940, 940, 990, 870),
      'PC-0104': ('1.0 มม.', 1460, 1460, 1535, 1380),
      'PC-0105': ('1.0 มม.', 1580, 1580, 1660, 1465),
      'PC-0204': ('1.0 มม.', 1505, 1505, 1585, 1395),
      'PF-0101': ('1.2 มม.', 1670, 1670, 1755, 1550),
      'PF-0102': ('1.2 มม.', 510, 520, 535, 485), // Exact 510 vs 520!
      'PF-0103': ('1.2 มม.', 1560, 1560, 1640, 1450),
    };

    for (final entry in officialTable.entries) {
      final code = entry.key;
      final (thick, pWhite, pBlack, pGrey, pMill) = entry.value;
      final expectedByColor = {
        'อบขาว (8911)': pWhite,
        'อบดำ (8816)': pBlack,
        'เทาซาฮาร่า (8820)': pGrey,
        'ตัวดิบ MILL': pMill,
      };
      for (final ce in expectedByColor.entries) {
        final matched = PricingEngine.matchSku(
          brand: 'ALUMET',
          code: code,
          selectedThickness: thick,
          selectedColor: ce.key,
          catalog: catalog,
          overrides: const {},
        );
        expect(matched, isNotNull, reason: 'Missing $code ${ce.key}');
        expect(
          matched!.factoryPrice,
          ce.value,
          reason: '$code (${ce.key}) mismatch',
        );
        expect(
          matched.isEstimated,
          isFalse,
          reason: '$code (${ce.key}) should be official non-estimated price',
        );
      }
    }
  });

  test('All 12 ALUMET NEX patterns across NEX 200 / NEX 100 / roller / mosquito / lock options resolve cuts, CAD images, and 100% pricing', () {
    final nexBrand = CatalogDefinitions.categories[1].brands
        .firstWhere((b) => b.id == 'c2_alumet_nex');
    expect(nexBrand.systems, hasLength(3));

    final reg = AluproImageRegistry.instance;
    final logoPath = reg.resolveBrandAsset(nexBrand.id);
    expect(logoPath, 'assets/brands/brand_alumet_nex.png');
    expect(File(logoPath!).existsSync(), isTrue);

    int patternCount = 0;
    for (final sys in nexBrand.systems) {
      final allSysPatterns = <PatternCardDef>[
        ...sys.patterns,
        for (final tab in sys.subTabs) ...tab.patterns,
      ];
      for (final pat in allSysPatterns) {
        if (!pat.enabled) continue;
        patternCount++;
        final patImg = reg.resolvePatternAsset(pat.id);
        expect(patImg, isNotNull, reason: 'Missing pattern diagram for ${pat.id}');
        expect(File(patImg!).existsSync(), isTrue);

        // Build option combinations to test
        final optionSets = <Map<String, String>>[
          {for (final g in pat.optionGroups) g.id: g.defaultValue},
        ];
        if (pat.id.startsWith('c2_nex_s')) {
          optionSets.addAll(const [
            {
              'nex_series': 'nex200',
              'usage_type': 'window',
              'roller_type': 'market',
              'mosquito': 'fiber',
            },
            {
              'nex_series': 'nex100',
              'usage_type': 'door',
              'roller_type': 'cartridge',
              'mosquito': 'fiber',
            },
          ]);
        } else if (pat.id.startsWith('c2_nex_win')) {
          optionSets.add(const {
            'lock_system': 'nex100',
            'open_mode': 'casement',
          });
        }

        for (final opts in optionSets) {
          final out = ParametricSystemResolver.calculate(
            brandTitle: nexBrand.title,
            priceBrandKey: nexBrand.priceBrandKey,
            systemTitle: sys.title,
            pattern: pat,
            selectedOptions: opts,
            sizeRows: const [
              SizeRowInput(widthMm: 2200, heightMm: 2100, auxMm: 1650, qty: 1),
            ],
          );

          expect(out.sets.single.cuts, isNotEmpty);
          expect(out.barGroups, isNotEmpty);

          // Every profile code must have a verified CAD asset on disk
          for (final grp in out.barGroups) {
            final cad = reg.resolveProfileAsset(
              code: grp.code,
              brandKey: 'ALUMET',
            );
            expect(
              cad,
              isNotNull,
              reason: 'Missing CAD image for ${grp.code} in ${pat.id} ($opts)',
            );
            expect(File(cad!).existsSync(), isTrue);
          }

          final avail = PricingEngine.computeAvailability(
            barGroups: out.barGroups,
            ormCatalog: SeedRepository.instance.allCatalogPrices,
            customOverrides: const {},
          );
          final thick = avail.availableThicknesses.contains('1.2 มม.')
              ? '1.2 มม.'
              : avail.availableThicknesses.first;

          final summary = PricingEngine.evaluate(
            barGroups: out.barGroups,
            mode: PricingMode.actualLength,
            wastePercent: 20.0,
            selectedThickness: thick,
            selectedColor: 'อบดำ (8816)',
            ormCatalog: SeedRepository.instance.allCatalogPrices,
            customOverrides: const {},
            glasses: out.sets.expand((s) => s.glasses).toList(),
            fallbackOpeningAreaSqM: (2200 * 2100) / 1000000.0 * 0.88,
            hardware: out.hardware,
            includeGlass: true,
            selectedGlassKey: 'GLASS|กระจกใส 6 มม.',
            glassRatePerSqM: 205.0,
            includeHardware: true,
            hardwareCatalog: SeedRepository.instance.hardwareRates,
          );

          expect(
            summary.matchedCount,
            summary.totalCount,
            reason:
                '${pat.id} ($opts) unmatched: ${summary.lines.where((l) => !l.isMatched).map((l) => l.group.code).toList()}',
          );
          expect(summary.aluminumCost, greaterThan(0));
          expect(summary.glassCost, greaterThan(0));
          expect(summary.hardwareCost, greaterThan(0));
        }
      }
    }
    expect(patternCount, greaterThanOrEqualTo(60));
  });

  test('QuotationSpecFormatter & QuotationPdfGenerator label ALUMET NEX 200 and NEX 100 properly', () async {
    final itemNex200 = SavedProjectItem(
      projectId: 1,
      sortIndex: 0,
      refCode: 'SD1',
      installLocation: 'ห้องรับแขก',
      brandTitle: 'ALUMET (NEX)',
      priceBrandKey: 'ALUMET',
      systemTitle: 'บานเลื่อน อลูเม็ท เน็กซ์',
      patternId: 'c2_nex_s2_card',
      patternTitle: 'บานเลื่อนสลับ 2 บาน',
      selectedOptions: const {'nex_series': 'nex200'},
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
      evaluatedSets: const [],
      hardware: const [],
    );
    expect(
      QuotationSpecFormatter.formatProfileSeriesName(itemNex200),
      'โปรไฟล์ ALUMET รุ่น NEX 200',
    );

    final itemNex100 = SavedProjectItem(
      projectId: 1,
      sortIndex: 1,
      brandTitle: 'ALUMET (NEX)',
      priceBrandKey: 'ALUMET',
      systemTitle: 'บานเปิด - บานกระทุ้ง อลูเม็ท เน็กซ์',
      patternId: 'c2_nex_win1_card',
      patternTitle: 'หน้าต่างบานกระทุ้ง / บานเปิด เดี่ยว',
      selectedOptions: const {'lock_system': 'nex100'},
      sizeRows: const [SizeRowInput(widthMm: 800, heightMm: 1200, qty: 1)],
      evaluatedSets: const [],
      hardware: const [],
    );
    expect(
      QuotationSpecFormatter.formatProfileSeriesName(itemNex100),
      'โปรไฟล์ ALUMET รุ่น NEX 100',
    );

    final pdf = await QuotationPdfGenerator.generate(
      quotation: SavedQuotation(
        projectId: 1,
        qtNumber: 'QT-NEX-20261123',
        docTitle: 'ใบเสนอราคา',
        mode: 'ITEMIZED',
        issueDate: '23/11/2026',
        validUntil: '23/12/2026',
        customerName: 'ลูกค้าทดสอบ NEX',
        projectName: 'โครงการ อลูเม็ท เน็กซ์',
        lines: [
          QuotationLineEntry(
            label: QuotationSpecFormatter.formatLineTitle(itemNex200, 1),
            subtitle: QuotationSpecFormatter.buildItemSpecSubtitle(
              item: itemNex200,
              globalAluThickness: '1.2 มม.',
              globalAluColor: 'สีดำ',
              globalGlassType: 'กระจกใส',
              globalGlassThickness: '6 มม.',
            ),
            sizeText: QuotationSpecFormatter.formatQuotationSize(itemNex200),
            qty: 1,
            unitPrice: 8900,
            confirmed: true,
          ),
        ],
        lumpSumPrice: 8900,
        subtotal: 8900,
        vatAmount: 0,
        netTotal: 8900,
        revisionTag: 'R1',
        createdAt: DateTime(2026, 11, 23),
      ),
      shopInfo: const ShopInfo(
        shopName: 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
        proposerName: 'ฝ่ายขาย',
      ),
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
  });

  testWidgets('ALUMET NEX Tab 4 PricingWorkspace renders 8/8 matched official prices on phone screen', (tester) async {
    await tester.runAsync(() => AppDatabase.instance.markPricingNoticeSeen());
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final nexBrand = CatalogDefinitions.categories[1].brands
        .firstWhere((b) => b.id == 'c2_alumet_nex');
    final s2Pat = nexBrand.systems.first.patterns.first;
    final out = ParametricSystemResolver.calculate(
      brandTitle: nexBrand.title,
      priceBrandKey: nexBrand.priceBrandKey,
      systemTitle: nexBrand.systems.first.title,
      pattern: s2Pat,
      selectedOptions: {
        for (final g in s2Pat.optionGroups) g.id: g.defaultValue,
      },
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 1)],
    );

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

    await tester.tap(find.text('ทำราคา'));
    await tester.pumpAndSettle();

    expect(find.text('จับคู่ราคาเส้นได้ 8/8 รายการ'), findsOneWidget);
    expect(find.textContaining('฿0.00'), findsNothing);
    expect(find.textContaining('PS-0107'), findsWidgets);
    expect(find.text('฿1,840.00 / เส้น'), findsOneWidget);
  });
}
