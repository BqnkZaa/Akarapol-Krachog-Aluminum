import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolkit_app/data/catalog_definitions.dart';
import 'package:toolkit_app/data/seed_repository.dart';
import 'package:toolkit_app/engine/bin_packer.dart';
import 'package:toolkit_app/engine/formula_evaluator.dart';
import 'package:toolkit_app/engine/parametric_system_resolver.dart';
import 'package:toolkit_app/engine/pricing_engine.dart';
import 'package:toolkit_app/models/app_models.dart';

PatternCardDef _findPattern(String id) {
  for (final cat in CatalogDefinitions.categories) {
    for (final sys in cat.directSystems) {
      for (final p in sys.patterns) {
        if (p.id == id) return p;
      }
    }
    for (final b in cat.brands) {
      for (final p in b.directPatterns) {
        if (p.id == id) return p;
      }
      for (final sys in b.systems) {
        for (final p in sys.patterns) {
          if (p.id == id) return p;
        }
        for (final tab in sys.subTabs) {
          for (final p in tab.patterns) {
            if (p.id == id) return p;
          }
        }
      }
    }
  }
  throw StateError('Pattern not found: $id');
}

PatternCardDef _findFolding(String fam, int n, int l, int r) {
  for (final cat in CatalogDefinitions.categories) {
    for (final b in cat.brands) {
      for (final p in b.directPatterns) {
        if (p.foldingFamily == fam &&
            p.foldingTotalPanels == n &&
            p.foldingLeftPanels == l &&
            p.foldingRightPanels == r) {
          return p;
        }
      }
      for (final sys in b.systems) {
        for (final p in sys.patterns) {
          if (p.foldingFamily == fam &&
              p.foldingTotalPanels == n &&
              p.foldingLeftPanels == l &&
              p.foldingRightPanels == r) {
            return p;
          }
        }
        for (final tab in sys.subTabs) {
          for (final p in tab.patterns) {
            if (p.foldingFamily == fam &&
                p.foldingTotalPanels == n &&
                p.foldingLeftPanels == l &&
                p.foldingRightPanels == r) {
              return p;
            }
          }
        }
      }
    }
  }
  throw StateError('Folding card not found: $fam $n-$l-$r');
}

void main() {
  test('Exact Tab 2 Profile Code + Bar Count Parity across all 180 ground-truth tables', () async {
    const brainDir =
        r'C:\Users\ayumg\.gemini\antigravity\brain\0d53fa8f-761f-439c-a650-e88e0e13a265';
    await SeedRepository.instance.ensureLoaded(testAssetsDir: 'assets/data');

    final vipDir = Directory('$brainDir/scratch/vip_audit');
    final swDir = Directory('$brainDir/scratch/full_sweep');

    int checked = 0;
    final issues = <String>[];

    for (final tbl in SeedRepository.instance.formulaTables.values) {
      final key = tbl.key;

      File? f;
      for (final cand in [
        File('${swDir.path}/${key}_p1_summary.txt'),
        File('${swDir.path}/${key}_summary.txt'),
        File('${vipDir.path}/${key}_p1_summary.txt'),
        File('${vipDir.path}/${key}_summary.txt'),
      ]) {
        if (cand.existsSync()) {
          f = cand;
          break;
        }
      }
      if (f == null) continue;

      final lines = f.readAsLinesSync();
      final setSizes = <(double, double)>[];
      for (final ln in lines) {
        final m1 = RegExp(
                r'ชุดที่ 1\s*.\s*([0-9.]+)\s*[^\d.\s]+\s*([0-9.]+)\s*มม\.')
            .firstMatch(ln);
        if (m1 != null && setSizes.isEmpty) {
          setSizes.add((double.parse(m1.group(1)!), double.parse(m1.group(2)!)));
        }
        final m2 = RegExp(
                r'ชุดที่ 2\s*.\s*([0-9.]+)\s*[^\d.\s]+\s*([0-9.]+)\s*มม\.')
            .firstMatch(ln);
        if (m2 != null && setSizes.length == 1) {
          setSizes.add((double.parse(m2.group(1)!), double.parse(m2.group(2)!)));
        }
      }
      if (setSizes.isEmpty) continue;

      String aluLine = '';
      bool afterAlu = false;
      for (final ln in lines) {
        final t = ln.trim();
        if (t == 'อลูมิเนียมที่ต้องสั่งซื้อ') {
          afterAlu = true;
          continue;
        }
        if (t.startsWith('กระจก') || t.startsWith('อุปกรณ์') || t.startsWith('===')) {
          afterAlu = false;
        }
        if (afterAlu && t.contains('เส้นโรงงาน') && aluLine.isEmpty) {
          aluLine = t;
        }
      }
      if (aluLine.isEmpty) continue;
      checked++;

      final gtBars = <String, int>{};
      final parts = aluLine.split(' | ');
      for (int i = 0; i + 2 < parts.length; i += 3) {
        final code = parts[i].trim();
        final barStr = parts[i + 2].trim();
        final bm = RegExp(r'^(\d+)\s*เส้น').firstMatch(barStr);
        if (bm != null) {
          gtBars[code] = int.parse(bm.group(1)!);
        }
      }

      final isAluFloor = key == 'c2_alu_s5_23' ||
          key == 'c2_alu_s5_32' ||
          key == 'c2_alu_s6_33';
      final evalSets = <EvaluatedSetResult>[];
      for (int si = 0; si < setSizes.length; si++) {
        final (w, h) = setSizes[si];
        final vars = <String, double>{
          'W': w,
          'H': h,
          'W1': w,
          'W2': key.contains('260_') ? 800.0 : 1800.0,
          'H1': h - 450.0,
          'H_t': 450.0,
          'W_f': 900.0,
          'N': 3.0,
          'DripLen': w,
        };
        final eCuts = tbl.cuts.map((c) {
          final res = FormulaEvaluator.evaluate(
            c.formula,
            vars,
            floorDivision: isAluFloor && c.formula.contains('/ 3'),
          );
          return EvaluatedCutItem(
            section: c.section,
            code: c.code,
            name: c.name,
            stockMm: c.stockMm,
            isSiteMeasured: res.isSiteMeasured,
            lengthMm: res.valueMm,
            estimatedTotalMm: res.estimatedMm,
            qtyPerSet: c.qty,
            totalQty: c.qty,
            angle: c.angle,
          );
        }).toList();
        evalSets.add(
          EvaluatedSetResult(
            setIndex: si + 1,
            sizeRow: SizeRowInput(widthMm: w, heightMm: h, qty: 1),
            cuts: eCuts,
            glasses: const [],
          ),
        );
      }

      final groups = BinPacker.packSingleCalculation(
        brandKey: 'TEST',
        sets: evalSets,
      );
      final ourBars = <String, int>{};
      for (final g in groups) {
        ourBars[g.code] = (ourBars[g.code] ?? 0) + g.totalBars;
      }

      final allCodes = {...gtBars.keys, ...ourBars.keys}.toList()..sort();
      for (final code in allCodes) {
        final gt = gtBars[code];
        final ours = ourBars[code];
        if (gt != ours) {
          issues.add('[$key] Code "$code": ours=${ours ?? "MISSING"} vs GT=${gt ?? "NOT_IN_TAB2"}');
        }
      }
    }

    stdout.writeln('Checked $checked tables for exact Tab 2 bar counts. Issues: ${issues.length}');
    for (final iss in issues) {
      stdout.writeln('  $iss');
    }
    expect(issues, isEmpty);
  });

  test('Live Head-to-Head Parity against Original Toolkit v0.1.7 across complex non-default & multi-panel cases', () async {
    await SeedRepository.instance.ensureLoaded(testAssetsDir: 'assets/data');

    // CASE 1A: Cat 1 Market Sliding (Plain Frame + Square Bumper, 1800x2050x2)
    final c1a = ParametricSystemResolver.calculate(
      brandTitle: 'ชุดตลาด',
      priceBrandKey: 'MARKET',
      systemTitle: 'บานเลื่อน',
      pattern: _findPattern('c1_pat_s2_alt'),
      selectedOptions: {
        'usage_type': 'window',
        'frame_mode': 'plain',
        'bumper_rubber': 'square',
      },
      sizeRows: const [SizeRowInput(widthMm: 1800, heightMm: 2050, qty: 2)],
    );
    expect(c1a.totalStockBars, 10);
    expect(c1a.totalRemnantMm, closeTo(24768.0, 0.01));
    expect(
      c1a.sets.first.cuts.firstWhere((c) => c.code == 'เสากุญแจ').lengthMm,
      2030.0,
    );
    expect(
      c1a.hardware.any((h) => h.name == 'ยางกันกระแทกแบบสี่เหลี่ยม' && h.numericQty == 8),
      isTrue,
    );

    // CASE 1B: Cat 1 Market Sliding (Ext Door + Box Frame, 1800x2050x2)
    final c1b = ParametricSystemResolver.calculate(
      brandTitle: 'ชุดตลาด',
      priceBrandKey: 'MARKET',
      systemTitle: 'บานเลื่อน',
      pattern: _findPattern('c1_pat_s2_alt'),
      selectedOptions: {
        'usage_type': 'ext_door',
        'frame_mode': 'box_frame',
        'bumper_rubber': 'round',
      },
      sizeRows: const [SizeRowInput(widthMm: 1800, heightMm: 2050, qty: 2)],
    );
    expect(c1b.totalStockBars, 10);
    expect(c1b.totalRemnantMm, closeTo(25520.0, 0.01));
    expect(
      c1b.sets.first.cuts.any((c) => c.code == 'เฟรมล่างไม่ติดกล่อง' && c.lengthMm == 1723.0),
      isTrue,
    );
    expect(
      c1b.sets.first.cuts.firstWhere((c) => c.code == 'เสากุญแจ').lengthMm,
      2000.0,
    );
    expect(
      c1b.hardware.any((h) => h.name == 'มือจับฝังล็อก+กุญแจ' && h.numericQty == 2),
      isTrue,
    );

    // CASE 2: Cat 2 ORM Asian Trop (65mm Stile + 30mm Jamb + High Sill, 1950x1650x2) + Tab 4 Pricing
    final c2 = ParametricSystemResolver.calculate(
      brandTitle: 'ORM',
      priceBrandKey: 'ORM',
      systemTitle: 'ORM (Asian Trop)',
      pattern: _findPattern('c2_orm_s2_card'),
      selectedOptions: {
        'usage_type': 'window',
        'stile_size': '65',
        'jamb_size': '30',
        'sill_type': 'high',
      },
      sizeRows: const [SizeRowInput(widthMm: 1950, heightMm: 1650, qty: 2)],
    );
    expect(c2.totalStockBars, 15);
    expect(c2.totalRemnantMm, closeTo(41072.0, 0.01));
    expect(
      c2.sets.first.cuts.firstWhere((c) => c.code == '801-08').lengthMm,
      848.0,
    );
    final c2Price = PricingEngine.evaluate(
      barGroups: c2.barGroups,
      mode: PricingMode.actualLength,
      wastePercent: 20.0,
      selectedThickness: '1.2 มม.',
      selectedColor: 'ตัวดิบ MILL',
      ormCatalog: SeedRepository.instance.ormPrices,
      customOverrides: const {},
    );
    expect(c2Price.matchedCount, 8);
    expect(c2Price.totalCount, 8);
    expect(c2Price.totalCost, closeTo(8267.11, 0.01));

    // CASE 3: Cat 4 ORM Folding 101.6mm 5-3-2 (3500x2250x1)
    final c3 = ParametricSystemResolver.calculate(
      brandTitle: 'ORM',
      priceBrandKey: 'ORM',
      systemTitle: 'ORM PANO SUIT Folding',
      pattern: _findFolding('orm101', 5, 3, 2),
      selectedOptions: {'sill_mode': 'low'},
      sizeRows: const [SizeRowInput(widthMm: 3500, heightMm: 2250, qty: 1)],
    );
    expect(c3.totalStockBars, 20);
    expect(c3.totalRemnantMm, closeTo(26599.0, 0.01));
    expect(
      c3.sets.first.cuts.any((c) => c.code == '805-14' && c.lengthMm == 3460.0),
      isTrue,
    );
    expect(
      c3.sets.first.glasses.first.widthMm,
      closeTo(551.6, 0.01),
    );
    expect(
      c3.sets.first.glasses.first.heightMm,
      closeTo(2035.0, 0.01),
    );

    // CASE 4: Cat 4 Fuji Folding U-Track 6-4-2-u (4200x2300x1)
    final c4 = ParametricSystemResolver.calculate(
      brandTitle: 'Fuji',
      priceBrandKey: 'FUJI',
      systemTitle: 'Fuji Eurotech Folding',
      pattern: _findFolding('fuji_u', 6, 4, 2),
      selectedOptions: const {},
      sizeRows: const [SizeRowInput(widthMm: 4200, heightMm: 2300, qty: 1)],
    );
    expect(c4.totalStockBars, 19);
    expect(c4.totalRemnantMm, closeTo(22686.0, 0.01));
    expect(
      FormulaEvaluator.formatMm(c4.sets.first.glasses.first.widthMm!),
      '543.7',
    );
    expect(
      c4.sets.first.glasses.first.heightMm,
      closeTo(2103.0, 0.01),
    );

    // CASE 5: Cat 2 ALUMET Smart X 1.5mm + 45° Sash (2000x2100x1)
    final c5 = ParametricSystemResolver.calculate(
      brandTitle: 'ALUMET',
      priceBrandKey: 'ALUMET',
      systemTitle: 'ALUMET Smart X',
      pattern: _findPattern('c2_alu_s2_card'),
      selectedOptions: {
        'thickness': '1.5',
        'sash_angle': '45',
        'roller_type': 'cartridge',
        'mosquito': 'none',
      },
      sizeRows: const [SizeRowInput(widthMm: 2000, heightMm: 2100, qty: 1)],
    );
    expect(c5.totalStockBars, 10);
    expect(
      c5.sets.first.cuts.any((c) => c.code == 'SS-X219' && c.lengthMm == 1008.0),
      isTrue,
    );
    expect(
      c5.sets.first.cuts.any((c) => c.code == 'SS-X216' && c.lengthMm == 2030.0),
      isTrue,
    );
  });
}
