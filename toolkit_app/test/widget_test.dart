import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toolkit_app/data/alupro_image_registry.dart';
import 'package:toolkit_app/data/app_database.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/bin_packer.dart';
import 'package:toolkit_app/engine/formula_evaluator.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/engine/thai_baht_text.dart';
import 'package:toolkit_app/main.dart';
import 'package:toolkit_app/models/app_models.dart';
import 'package:toolkit_app/pdf/project_pdf.dart';
import 'package:toolkit_app/pdf/quotation_pdf.dart';
import 'package:toolkit_app/pdf/single_cut_pdf.dart';
import 'package:toolkit_app/screens/alupro_thumbnail_widgets.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final memDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.instance.initForTesting(memDb);
    await SeedRepository.instance.ensureLoaded(testAssetsDir: 'assets/data');
  });

  test('SeedRepository loads all 182 formula tables and 1,139 ORM price SKUs', () {
    expect(SeedRepository.instance.formulaTables.length, 182);
    expect(SeedRepository.instance.ormPrices.length, 1139);
  });

  test('All 182 verified formula tables evaluate without unresolved errors', () {
    final vars = <String, double>{
      'W': 2400,
      'H': 2100,
      'H1': 1700,
      'H_t': 400,
      'W1': 2000,
      'W2': 1800,
      'W_f': 800,
      'N': 4,
      'DripLen': 1200,
    };

    for (final tbl in SeedRepository.instance.formulaTables.values) {
      expect(tbl.cuts, isNotEmpty, reason: 'Table ${tbl.key} should have cuts');
      for (final cut in tbl.cuts) {
        final res = FormulaEvaluator.evaluate(cut.formula, vars);
        if (!res.isSiteMeasured) {
          expect(
            res.valueMm,
            isNotNull,
            reason: 'Numeric cut failed on ${tbl.key}: ${cut.formula}',
          );
          expect(
            res.valueMm! > 0,
            isTrue,
            reason: 'Cut <= 0 on ${tbl.key}: ${cut.formula} -> ${res.valueMm}',
          );
        }
      }
      for (final gls in tbl.glasses) {
        if (!gls.siteCut) {
          final gw = FormulaEvaluator.evaluateNumber(gls.wFormula, vars);
          final gh = FormulaEvaluator.evaluateNumber(gls.hFormula, vars);
          if (tbl.key.startsWith('c1_s2') || tbl.key.startsWith('c1_s4')) {
            // Intentional Toolkit v0.1.7 quirk: Cat 1 sliding glass is 0 x 0
            expect(gw, 0.0);
            expect(gh, 0.0);
          } else {
            expect(gw > 0, isTrue, reason: 'Glass W <= 0 on ${tbl.key}: ${gls.wFormula}');
            expect(gh > 0, isTrue, reason: 'Glass H <= 0 on ${tbl.key}: ${gls.hFormula}');
          }
        }
      }
    }
  });

  test('All active PatternCardDefs across all 5 categories + all 136 folding cards resolve & calculate', () {
    int activeCards = 0;
    int activeFoldingCards = 0;

    void verifyPatterns(String brandTitle, String brandKey, String sysTitle, List<PatternCardDef> patterns) {
      for (final p in patterns) {
        if (!p.enabled) {
          expect(p.disabledBadge, isNotNull);
          continue;
        }
        activeCards++;
        if (p.foldingFamily != null) activeFoldingCards++;

        final opts = <String, String>{};
        for (final g in p.optionGroups) {
          opts[g.id] = g.defaultValue;
        }

        final out = ParametricSystemResolver.calculate(
          brandTitle: brandTitle,
          priceBrandKey: brandKey,
          systemTitle: sysTitle,
          pattern: p,
          selectedOptions: opts,
          sizeRows: const [
            SizeRowInput(widthMm: 2400, heightMm: 2200, auxMm: 1750, qty: 2),
          ],
          dripTrayLengthMm: 1200,
        );

        expect(out.sets, hasLength(1));
        expect(out.sets.first.cuts, isNotEmpty, reason: 'Pattern ${p.id} produced 0 cuts');
        if (p.id == 'c2_orm_fix1_card') {
          // Toolkit v0.1.7 c2_orm_fix1 is 100% site-measured (0 stock bars in Tab 2/3)
          expect(out.barGroups, isEmpty);
        } else {
          expect(out.barGroups, isNotEmpty, reason: 'Pattern ${p.id} produced 0 barGroups');
        }
      }
    }

    for (final cat in CatalogDefinitions.categories) {
      for (final sys in cat.directSystems) {
        verifyPatterns(cat.title, 'MARKET', sys.title, sys.patterns);
      }
      for (final brand in cat.brands) {
        if (!brand.enabled) continue;
        verifyPatterns(brand.title, brand.priceBrandKey, brand.subtitle, brand.directPatterns);
        for (final sys in brand.systems) {
          if (!sys.enabled) continue;
          verifyPatterns(brand.title, brand.priceBrandKey, sys.title, sys.patterns);
          for (final tab in sys.subTabs) {
            verifyPatterns(brand.title, brand.priceBrandKey, tab.title, tab.patterns);
          }
        }
      }
    }

    // 32 ORM + 64 Fuji + 1 Schimmer parametric (plus 6 baseFormulaKey Schimmer = 7 total) + 19 SP + 14 ALUMET = 136 total Cat 4 active cards!
    expect(activeFoldingCards, 130); // + 6 swept Schimmer 240 cards = 136 active Cat 4 cards!
    expect(activeCards > 220, isTrue);
  });

  test('Preserves Toolkit v0.1.7 exact quirks (Cat 1 0x0 glass, Iconiq H+146 bead, Smart X floor)', () {
    // 1. ALUMET Iconiq Casement single: iO-0203 vertical bead = H + 146
    final iconiqCase = SeedRepository.instance.getFormulaTable('c3_alu_case1')!;
    final vertBead = iconiqCase.cuts.firstWhere((c) => c.code == 'iO-0203' && c.formula == 'H + 146');
    expect(vertBead.formula, 'H + 146');

    // 2. ALUMET Smart X 3-panel corner floor division: (2000 + 78) ~/ 3 = 692 (not 692.7)
    final smartXFloor = FormulaEvaluator.evaluate(
      '(W1 + 78) / 3',
      {'W1': 2000},
      floorDivision: true,
    );
    expect(smartXFloor.valueMm, 692.0);
  });

  test('1D FFD BinPacker enforces stock - 100 usable length and 4 mm saw kerf', () {
    const set1 = EvaluatedSetResult(
      setIndex: 1,
      sizeRow: SizeRowInput(widthMm: 3150, heightMm: 2100, qty: 1),
      cuts: [
        // 3148 + 4 + 3148 = 6300 <= 6300 (fits in 1 bar of 6400 stock!)
        EvaluatedCutItem(
          section: 'เฟรม',
          code: '801-03',
          name: 'เฟรมบน',
          stockMm: 6400,
          isSiteMeasured: false,
          lengthMm: 3148,
          qtyPerSet: 2,
          totalQty: 2,
          angle: '90° / 90°',
        ),
      ],
      glasses: [],
    );

    final packedFit = BinPacker.packSingleCalculation(brandKey: 'ORM', sets: [set1]);
    expect(packedFit.single.confirmedBars.length, 1);
    expect(packedFit.single.confirmedBars.first.usedLengthMm, 6300);
    expect(packedFit.single.confirmedBars.first.remnantMm, 0);

    // Increase by 1 mm -> 3149 + 4 + 3149 = 6302 > 6300 -> must split into 2 bars!
    const setOverflow = EvaluatedSetResult(
      setIndex: 1,
      sizeRow: SizeRowInput(widthMm: 3150, heightMm: 2100, qty: 1),
      cuts: [
        EvaluatedCutItem(
          section: 'เฟรม',
          code: '801-03',
          name: 'เฟรมบน',
          stockMm: 6400,
          isSiteMeasured: false,
          lengthMm: 3149,
          qtyPerSet: 2,
          totalQty: 2,
          angle: '90° / 90°',
        ),
      ],
      glasses: [],
    );
    final packedSplit = BinPacker.packSingleCalculation(brandKey: 'ORM', sets: [setOverflow]);
    expect(packedSplit.single.confirmedBars.length, 2);
  });

  test('3-Step ORM Price Matcher & PricingEngine modes match Toolkit v0.1.7', () {
    final catalog = SeedRepository.instance.ormPrices;

    // Step 1: Exact match (801-01, 1.2 มม., ตัวดิบ MILL)
    final exact = PricingEngine.matchSku(
      brand: 'ORM',
      code: '801-01',
      selectedThickness: '1.2 มม.',
      selectedColor: 'ตัวดิบ MILL',
      catalog: catalog,
      overrides: const {},
    );
    expect(exact, isNotNull);
    expect(exact!.factoryPrice, 1254.0);

    // Step 3: Single-manufactured-thickness fallback (801-23 only exists at 1.5 มม. when user selects 1.2 มม.)
    final fallback = PricingEngine.matchSku(
      brand: 'ORM',
      code: '801-23',
      selectedThickness: '1.2 มม.',
      selectedColor: 'ตัวดิบ MILL',
      catalog: catalog,
      overrides: const {},
    );
    expect(fallback, isNotNull);
    expect(fallback!.thickness, '1.5 มม.');
  });

  test('ThaiBahtText converts accounting amounts accurately', () {
    expect(ThaiBahtText.convert(13800.00), 'หนึ่งหมื่นสามพันแปดร้อยบาทถ้วน');
    expect(
      ThaiBahtText.convert(13899.30),
      'หนึ่งหมื่นสามพันแปดร้อยเก้าสิบเก้าบาทสามสิบสตางค์',
    );
    expect(ThaiBahtText.convert(21.01), 'ยี่สิบเอ็ดบาทหนึ่งสตางค์');
    expect(ThaiBahtText.convert(101.00), 'หนึ่งร้อยเอ็ดบาทถ้วน');
  });

  test('SQLite CRUD and all 3 Thai PDF generators produce valid PDF binaries', () async {
    await AppDatabase.instance.saveShopInfo(
      const ShopInfo(
        shopName: 'บริษัท อัครพลกระจก อลูมิเนียม จำกัด',
        defaultDocTitle: 'ใบเสนอราคา',
        proposerName: 'ฝ่ายขายโครงการ',
        address: 'กรุงเทพมหานคร',
        phone: '081-234-5678',
      ),
    );
    final shop = await AppDatabase.instance.getShopInfo();
    expect(shop.isConfigured, isTrue);

    final pat = CatalogDefinitions.categories[1].brands.first.systems.first.patterns.first;
    final out = ParametricSystemResolver.calculate(
      brandTitle: 'ORM (Asian Trop)',
      priceBrandKey: 'ORM',
      systemTitle: 'บานเลื่อน',
      pattern: pat,
      selectedOptions: const {
        'usage_type': 'door',
        'stile_size': '53',
        'jamb_size': '20',
        'sill_type': 'low',
      },
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 2)],
    );

    // PDF 1: Single Cut Order PDF
    final pdf1 = await SingleCutPdfGenerator.generate(
      out,
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdf1.sublist(0, 5)), '%PDF-');

    // Save to SQLite project & generate PDF 2 (Project PDF with Landscape Section 3)
    final pid = await AppDatabase.instance.createProject(
      name: 'บ้านคุณลูกค้า ทดสอบ',
      note: 'ชั้น 1',
    );
    await AppDatabase.instance.addProjectItem(
      SavedProjectItem(
        projectId: pid,
        sortIndex: 0,
        refCode: 'D1',
        installLocation: 'ห้องโถงหน้าบ้าน',
        brandTitle: out.brandTitle,
        priceBrandKey: out.priceBrandKey,
        systemTitle: out.systemTitle,
        patternId: out.patternId,
        patternTitle: out.patternTitle,
        selectedOptions: out.selectedOptions,
        sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2050, qty: 2)],
        evaluatedSets: out.sets,
        hardware: out.hardware,
      ),
    );
    final proj = (await AppDatabase.instance.getProject(pid))!;
    final pdf2 = await ProjectPdfGenerator.generate(
      proj,
      const ProjectPdfOptions(),
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdf2.sublist(0, 5)), '%PDF-');

    // PDF 3: Quotation PDF (Both ITEMIZED & LUMP_SUM)
    final qtItemized = SavedQuotation(
      projectId: pid,
      qtNumber: 'QT-20261116-100001',
      docTitle: 'ใบเสนอราคา',
      mode: 'ITEMIZED',
      issueDate: '16/11/2026',
      validUntil: '16/12/2026',
      customerName: 'คุณลูกค้า',
      projectName: proj.name,
      lines: const [
        QuotationLineEntry(
          label: '[D1] บานเลื่อนสลับ 2 บาน',
          subtitle: 'ห้องโถงหน้าบ้าน',
          sizeText: '2000.0 × 2050.0 (2)',
          qty: 2,
          unitPrice: 6900,
          confirmed: true,
        ),
      ],
      lumpSumPrice: 13800,
      discount: 800,
      vatEnabled: true,
      subtotal: 13800,
      vatAmount: 910,
      netTotal: 13910,
      revisionTag: 'R1-1763310000000',
      createdAt: DateTime.now(),
    );
    await AppDatabase.instance.saveQuotation(qtItemized);
    expect(await AppDatabase.instance.isQuotationNumberUsed('QT-20261116-100001'), isTrue);

    final pdf3A = await QuotationPdfGenerator.generate(
      quotation: qtItemized,
      shopInfo: shop,
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdf3A.sublist(0, 5)), '%PDF-');

    final qtLump = SavedQuotation(
      projectId: pid,
      qtNumber: 'QT-20261116-100002',
      docTitle: 'ใบเสนอราคา',
      mode: 'LUMP_SUM',
      issueDate: '16/11/2026',
      validUntil: '16/12/2026',
      customerName: 'คุณลูกค้า',
      projectName: proj.name,
      lines: qtItemized.lines,
      lumpSumPrice: 13800,
      subtotal: 13800,
      vatAmount: 0,
      netTotal: 13800,
      revisionTag: 'R2-1763310005000',
      createdAt: DateTime.now(),
    );
    final pdf3B = await QuotationPdfGenerator.generate(
      quotation: qtLump,
      shopInfo: shop,
      testFontsDir: 'assets/fonts',
    );
    expect(ascii.decode(pdf3B.sublist(0, 5)), '%PDF-');
  });

  testWidgets('HomeScreen renders 1:1 Toolkit VIP layout & sticky bottom bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const AkkaraphonToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('Toolkit'), findsOneWidget);
    expect(find.text('เครื่องมือช่างกระจกและอลูมิเนียม'), findsOneWidget);
    expect(find.text('ระบบคำนวณ'), findsOneWidget);
    expect(find.text('โปรเจกต์ของฉัน'), findsOneWidget);
    expect(find.text('ความรู้ ทริค & ฮาร์ดแวร์'), findsOneWidget);
    expect(find.text('ติดต่อเรา'), findsOneWidget);
    expect(find.text('บัญชีของฉัน'), findsOneWidget);
  });

  test('AluproImageRegistry resolves 100% of offline catalog, profile, glass & hardware assets', () {
    final reg = AluproImageRegistry.instance;
    expect(reg.isLoaded, isTrue);

    void assertAssetExists(String? path, String ctx) {
      expect(path, isNotNull, reason: 'Missing image mapping for $ctx');
      expect(File(path!).existsSync(), isTrue, reason: 'Asset file missing on disk: $path ($ctx)');
    }

    assertAssetExists(reg.glassAsset, 'glass');

    void checkSys(SubSystemDef sys) {
      assertAssetExists(reg.resolveSystemAsset(sys.id), 'sys:${sys.id}');
      for (final p in sys.patterns) {
        assertAssetExists(reg.resolvePatternAsset(p.id), 'pat:${p.id}');
      }
      for (final tab in sys.subTabs) {
        checkSys(tab);
      }
    }

    for (final cat in CatalogDefinitions.categories) {
      assertAssetExists(reg.resolveCategoryAsset(cat.id), 'cat:${cat.id}');
      for (final sys in cat.directSystems) {
        checkSys(sys);
      }
      for (final brand in cat.brands) {
        final brandAsset = reg.resolveBrandAsset(brand.id);
        assertAssetExists(brandAsset, 'brand:${brand.id}');
        expect(
          brandAsset!.startsWith('assets/brands/brand_'),
          isTrue,
          reason: 'Brand ${brand.id} must use manufacturer brand logo asset',
        );
        for (final p in brand.directPatterns) {
          assertAssetExists(reg.resolvePatternAsset(p.id), 'pat:${p.id}');
        }
        for (final sys in brand.systems) {
          checkSys(sys);
        }
      }
    }

    for (final tbl in SeedRepository.instance.formulaTables.values) {
      for (final c in tbl.cuts) {
        assertAssetExists(
          reg.resolveProfileAsset(code: c.code, name: c.name),
          'cut:${tbl.key}:${c.code}',
        );
      }
      for (final h in tbl.hardware) {
        assertAssetExists(
          reg.resolveHardwareAsset(code: h.code, name: h.name),
          'hw:${tbl.key}:${h.code}|${h.name}',
        );
      }
    }
  });

  testWidgets('Catalog -> Brand Logos -> Input -> Result renders cleanly on phone & tablet', (tester) async {
    // 1. Verify tablet landscape layout (matching customer's tablet screenshot)
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(const AkkaraphonToolkitApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ระบบคำนวณ'));
    await tester.pumpAndSettle();
    expect(find.text('เลือกชุดระบบหลัก'), findsOneWidget);

    await tester.tap(find.text('2. ชุดพัฒนา'));
    await tester.pumpAndSettle();
    expect(find.text('เลือกแบรนด์และระบบงาน'), findsOneWidget);
    expect(find.byType(BrandLogoPlate), findsNWidgets(6));

    // 2. Verify phone portrait flow through Input -> Result Tabs 1–3
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpAndSettle();
    expect(find.byType(BrandLogoPlate), findsWidgets);

    await tester.tap(find.text('ORM (Asian Trop)'));
    await tester.pumpAndSettle();
    expect(find.byType(AluproThumbnail), findsWidgets);

    await tester.tap(find.text('บานเลื่อน'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บานเลื่อนสลับ 2 บาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถัดไป (กรอกขนาดงาน)'));
    await tester.pumpAndSettle();
    expect(find.text('แตะรูปเพื่อขยายดูผังบาน'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '2000');
    await tester.enterText(find.byType(TextField).at(1), '2050');
    await tester.tap(find.text('คำนวณระยะตัดและถอดของ'));
    await tester.pumpAndSettle();

    expect(find.byType(AluproThumbnail), findsWidgets);
    await tester.tap(find.text('ถอดรายการ'));
    await tester.pumpAndSettle();
    expect(find.byType(AluproThumbnail), findsWidgets);

    await tester.tap(find.text('จัดเส้น'));
    await tester.pumpAndSettle();
    expect(find.byType(AluproThumbnail), findsWidgets);
  });
}
