import '../data/seed_repository.dart';
import '../models/app_models.dart';
import 'bin_packer.dart';
import 'formula_evaluator.dart';

class ParametricSystemResolver {
  ParametricSystemResolver._();

  /// Resolves the exact formula table for [pattern] + [selectedOptions],
  /// evaluates all [sizeRows], aggregates BOM hardware, and runs 1D FFD bin-packing.
  static CalculationOutput calculate({
    required String brandTitle,
    required String priceBrandKey,
    required String systemTitle,
    required PatternCardDef pattern,
    required Map<String, String> selectedOptions,
    required List<SizeRowInput> sizeRows,
    double? dripTrayLengthMm,
    SeedRepository? repo,
  }) {
    final seed = repo ?? SeedRepository.instance;
    final table = resolveFormulaTable(
      pattern: pattern,
      selectedOptions: selectedOptions,
      dripTrayLengthMm: dripTrayLengthMm,
      seed: seed,
    );

    final isAlumetCornerFloor = pattern.baseFormulaKey == 'c2_alu_s5_23' ||
        pattern.baseFormulaKey == 'c2_alu_s5_32' ||
        pattern.baseFormulaKey == 'c2_alu_s6_33';

    final evaluatedSets = <EvaluatedSetResult>[];
    int totalUnitsAcrossRows = 0;

    for (int i = 0; i < sizeRows.length; i++) {
      final row = sizeRows[i];
      totalUnitsAcrossRows += row.qty;
      final vars = _buildVariables(pattern, row, dripTrayLengthMm);

      final evaluatedCuts = <EvaluatedCutItem>[];
      for (final c in table.cuts) {
        final useFloor = isAlumetCornerFloor && c.formula.contains('/ 3');
        final res = FormulaEvaluator.evaluate(
          c.formula,
          vars,
          floorDivision: useFloor,
        );
        evaluatedCuts.add(
          EvaluatedCutItem(
            section: c.section,
            code: c.code,
            name: c.name,
            stockMm: c.stockMm,
            isSiteMeasured: res.isSiteMeasured,
            lengthMm: res.valueMm,
            estimatedTotalMm: res.estimatedMm != null
                ? res.estimatedMm! * row.qty
                : null,
            qtyPerSet: c.qty,
            totalQty: c.qty * row.qty,
            angle: c.angle,
          ),
        );
      }

      final evaluatedGlasses = <EvaluatedGlassItem>[];
      for (final g in table.glasses) {
        if (g.siteCut) {
          evaluatedGlasses.add(
            EvaluatedGlassItem(
              name: g.name,
              siteCut: true,
              totalPanels: g.qty * row.qty,
              setIndex: i + 1,
            ),
          );
        } else {
          final gw = FormulaEvaluator.evaluateNumber(g.wFormula, vars);
          final gh = FormulaEvaluator.evaluateNumber(g.hFormula, vars);
          evaluatedGlasses.add(
            EvaluatedGlassItem(
              name: g.name,
              siteCut: false,
              widthMm: gw,
              heightMm: gh,
              totalPanels: g.qty * row.qty,
              setIndex: i + 1,
            ),
          );
        }
      }

      evaluatedSets.add(
        EvaluatedSetResult(
          setIndex: i + 1,
          sizeRow: row,
          cuts: evaluatedCuts,
          glasses: evaluatedGlasses,
        ),
      );
    }

    // Aggregate hardware across totalUnitsAcrossRows
    final aggregatedHw = _aggregateHardware(table.hardware, totalUnitsAcrossRows);

    // Run 1D FFD Bin-Packing
    final barGroups = BinPacker.packSingleCalculation(
      brandKey: priceBrandKey,
      sets: evaluatedSets,
    );

    return CalculationOutput(
      brandTitle: brandTitle,
      priceBrandKey: priceBrandKey,
      systemTitle: systemTitle,
      patternId: pattern.id,
      patternTitle: pattern.title,
      selectedOptions: Map<String, String>.from(selectedOptions),
      sets: evaluatedSets,
      hardware: aggregatedHw,
      barGroups: barGroups,
    );
  }

  static Map<String, double> _buildVariables(
    PatternCardDef pattern,
    SizeRowInput row,
    double? dripTrayLengthMm,
  ) {
    final w = row.widthMm;
    final h = row.heightMm;
    final aux = row.auxMm ?? 0.0;
    final vars = <String, double>{
      'W': w,
      'H': h,
      'W1': w,
      'W2': aux > 0 ? aux : w,
      'H1': h - 450.0,
      'H_t': 450.0,
      'W_f': 900.0,
      'N': (pattern.foldingTotalPanels ?? 2).toDouble(),
      'DripLen': dripTrayLengthMm ?? w,
    };

    if (pattern.tableMode == InputTableMode.cornerW1W2) {
      vars['W1'] = w;
      vars['W2'] = aux > 0 ? aux : w;
    } else if (pattern.tableMode == InputTableMode.smartPlus90FourCol ||
        pattern.auxType == AuxDimensionType.refHeightH1) {
      final h1Val = aux > 0 ? aux : (h > 500 ? h - 400.0 : h * 0.75);
      vars['H1'] = h1Val;
      vars['H_t'] = h - h1Val;
    } else if (pattern.auxType == AuxDimensionType.transomHeightHt) {
      final htVal = aux > 0 ? aux : 450.0;
      vars['H_t'] = htVal;
      vars['H1'] = h - htVal;
    } else if (pattern.auxType == AuxDimensionType.sideFixWf) {
      vars['W_f'] = aux > 0 ? aux : (w * 0.35);
    } else if (pattern.auxType == AuxDimensionType.secondWidthW2) {
      vars['W1'] = w;
      vars['W2'] = aux > 0 ? aux : w;
    }

    return vars;
  }

  static List<AggregatedHardwareItem> _aggregateHardware(
    List<HardwareItemSpec> perSetSpecs,
    int totalSets,
  ) {
    final out = <AggregatedHardwareItem>[];
    final mult = totalSets > 0 ? totalSets : 1;
    for (final h in perSetSpecs) {
      final qt = h.qtyText.trim();
      final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(qt);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        final unit = m.group(2)!.trim().isEmpty ? 'ชิ้น' : m.group(2)!.trim();
        out.add(
          AggregatedHardwareItem(
            code: h.code,
            name: h.name,
            numericQty: n * mult,
            unitOrNote: unit,
          ),
        );
      } else {
        out.add(
          AggregatedHardwareItem(
            code: h.code,
            name: h.name,
            numericQty: null,
            unitOrNote: qt,
          ),
        );
      }
    }
    return out;
  }

  // ===========================================================================
  // Master Formula Table Resolver (All 5 Categories + 136 Folding Cards)
  // ===========================================================================
  static VerifiedFormulaTable resolveFormulaTable({
    required PatternCardDef pattern,
    required Map<String, String> selectedOptions,
    double? dripTrayLengthMm,
    required SeedRepository seed,
  }) {
    // 1. Category 4 Parametric Folding Family (136 active cards)
    if (pattern.foldingFamily != null) {
      return _resolveFoldingTable(pattern, selectedOptions, seed);
    }

    // 2. Determine Base Key (accounting for direct variant tables in seed)
    String key = pattern.baseFormulaKey;
    if (pattern.id == 'c1_pat_s2_alt') {
      final fm = selectedOptions['frame_mode'] ?? 'plain';
      if (fm == 'smooth_box') key = 'c1_s2_smoothbox';
      if (fm == 'box_frame') key = 'c1_s2_boxframe';
    } else if (pattern.id == 'c2_uai_s2_card') {
      if (selectedOptions['mosq_sash'] == 'true') {
        key = 'c2_uai_s2_mosq';
      }
    } else if (pattern.id == 'c3_orm_s2_card') {
      if (selectedOptions['sash_code'] == '804-15') {
        key = 'c3_orm_s2_altsash';
      }
    } else if (pattern.id == 'c3_af_w1_card') {
      if (selectedOptions['frame_style'] == 'plaster') {
        key = 'c3_af_w1_case_plaster';
      }
    }

    final base = seed.getFormulaTable(key);
    if (base == null) {
      throw StateError('Formula table not found for key: $key (${pattern.id})');
    }

    var cuts = base.cuts.map((c) => c.copyWith()).toList();
    var glasses = List<GlassPieceSpec>.from(base.glasses);
    var hardware = List<HardwareItemSpec>.from(base.hardware);

    // 3. Apply Exact Option & Pattern Modifiers per System
    if (pattern.id.startsWith('c1_pat_s')) {
      _applyCat1MarketSlidingModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
        hardware: hardware,
      );
    } else if (pattern.id.startsWith('c1_pat_union_')) {
      _applyCat1UnionModifiers(
        opts: selectedOptions,
        cuts: cuts,
        hardware: hardware,
      );
    } else if (pattern.id.startsWith('c2_orm_s')) {
      _applyCat2OrmSlidingModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
      );
    } else if (pattern.id.startsWith('c2_orm_case')) {
      _applyCat2OrmCasementModifiers(
        opts: selectedOptions,
        cuts: cuts,
        glasses: glasses,
        hardware: hardware,
      );
    } else if (pattern.id.startsWith('c2_sch_250_')) {
      _applySchimmer250Modifiers(selectedOptions, glasses, hardware);
    } else if (pattern.id.startsWith('c2_sch_260_')) {
      _applySchimmer260Modifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        dripTrayLengthMm: dripTrayLengthMm,
        cuts: cuts,
        glasses: glasses,
        hardware: hardware,
      );
    } else if (pattern.id.startsWith('c2_alu_s') &&
        pattern.tableMode != InputTableMode.cornerW1W2) {
      _applyCat2AlumetSlidingModifiers(
        opts: selectedOptions,
        cuts: cuts,
        hardware: hardware,
      );
    } else if (pattern.id == 'c2_sp_s2_card') {
      if (selectedOptions['sill_height'] == 'high') {
        cuts = cuts
            .map((c) => c.code == '15101'
                ? c.copyWith(code: '15102', name: 'เฟรมล่างขาสูง')
                : c)
            .toList();
      }
    } else if (pattern.id == 'c2_sp_case1_top_card' ||
        pattern.id == 'c2_sp_awn1_top_card') {
      _applyCat2SmartPlusTopTransom(cuts, glasses);
    } else if (pattern.id.startsWith('c3_orm_s') &&
        selectedOptions['sash_code'] == '804-15') {
      cuts = cuts
          .map((c) => c.code == '804-20' ? c.copyWith(code: '804-15') : c)
          .toList();
    } else if (pattern.id.startsWith('c3_fuji_')) {
      _applyCat3FujiSlidingModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
        glasses: glasses,
        seed: seed,
      );
    } else if (pattern.id.startsWith('c3_alu_s')) {
      _applyCat3IconiqSlidingModifiers(selectedOptions, cuts);
    } else if (pattern.id.startsWith('c3_sp_')) {
      _applyCat3SmartPlusEuroModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
        glasses: glasses,
      );
    } else if (pattern.id.startsWith('c3_af_s')) {
      _applyCat3AluframeSlidingModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
        glasses: glasses,
      );
    }

    return VerifiedFormulaTable(
      key: base.key,
      header: base.header,
      cuts: cuts,
      glasses: glasses,
      hardware: hardware,
    );
  }

  // ---------------------------------------------------------------------------
  // Category 1 Modifiers (Market Sliding & Union)
  // ---------------------------------------------------------------------------
  static void _applyCat1MarketSlidingModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final frameMode = opts['frame_mode'] ?? 'plain';
    final usageType = opts['usage_type'] ?? 'window';
    final bumper = opts['bumper_rubber'] ?? 'round';

    // Adjust c1_pat_s2_alt when frame_mode == 'plain' (base was c1_s2_boxframe)
    if (patternId == 'c1_pat_s2_alt' && frameMode == 'plain') {
      cuts
        ..clear()
        ..addAll(const [
          CutPieceSpec(
              section: 'เฟรม',
              code: 'เฟรมข้างไม่ติดกล่อง',
              name: 'เฟรมข้างไม่ติดกล่อง',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H'),
          CutPieceSpec(
              section: 'เฟรม',
              code: 'เฟรมบนไม่ติดกล่อง',
              name: 'เฟรมบนไม่ติดกล่อง',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 13'),
          CutPieceSpec(
              section: 'เฟรม',
              code: 'เฟรมล่างไม่ติดกล่อง',
              name: 'เฟรมล่างไม่ติดกล่อง',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 13'),
          CutPieceSpec(
              section: 'กรอบบาน',
              code: 'เสากุญแจ',
              name: 'เสากุญแจ',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H - 41'),
          CutPieceSpec(
              section: 'กรอบบาน',
              code: 'เสาเกี่ยว',
              name: 'เสาเกี่ยว',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H - 41'),
          CutPieceSpec(
              section: 'กรอบบาน',
              code: 'กรอบบานขวางบน',
              name: 'กรอบบานขวางบน',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: '(W - 153) / 2'),
          CutPieceSpec(
              section: 'กรอบบาน',
              code: 'กรอบบานขวางล่าง',
              name: 'กรอบบานขวางล่าง',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: '(W - 153) / 2'),
        ]);
    } else if (patternId == 'c1_pat_s2_1s1f' || patternId == 'c1_pat_s4_ctr') {
      // Base tables c1_s2_1s1f and c1_s4_center are plain frame; adapt if smooth_box or box_frame
      if (frameMode == 'smooth_box') {
        final updated = <CutPieceSpec>[
          const CutPieceSpec(
              section: 'วงกบกล่องเรียบ',
              code: 'กล่องเรียบแนวตั้ง',
              name: 'กล่องเรียบแนวตั้ง',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H'),
          const CutPieceSpec(
              section: 'วงกบกล่องเรียบ',
              code: 'กล่องเรียบแนวขวาง',
              name: 'กล่องเรียบแนวขวางบน-ล่าง',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'W - 90'),
          const CutPieceSpec(
              section: 'อุปกรณ์เสริม',
              code: 'ฉากข้อต่อ',
              name: 'ฉากข้อต่อ',
              stockMm: 6400,
              qty: 4,
              qtyText: '4 ชิ้น',
              angle: '90°',
              formula: '95 (ค่าคงที่)'),
        ];
        for (final c in cuts) {
          String f = c.formula;
          if (f == 'H') {
            f = 'H - 91';
          } else if (f.startsWith('H - ')) {
            final d = double.parse(f.substring(4)) + 70;
            f = 'H - ${FormulaEvaluator.formatMm(d)}';
          } else if (f.startsWith('W - ')) {
            final d = double.parse(f.substring(4)) + 90;
            f = 'W - ${FormulaEvaluator.formatMm(d)}';
          } else if (f.contains('/ 2')) {
            f = f.replaceFirstMapped(RegExp(r'W - ([0-9.]+)'), (m) {
              final d = double.parse(m.group(1)!) + 90;
              return 'W - ${FormulaEvaluator.formatMm(d)}';
            });
          } else if (f.contains('/ 4')) {
            f = f.replaceFirstMapped(RegExp(r'W - ([0-9.]+)'), (m) {
              final d = double.parse(m.group(1)!) + 90;
              return 'W - ${FormulaEvaluator.formatMm(d)}';
            });
          }
          updated.add(c.copyWith(formula: f));
        }
        cuts
          ..clear()
          ..addAll(updated);
      } else if (frameMode == 'box_frame') {
        final updated = <CutPieceSpec>[];
        for (final c in cuts) {
          String f = c.formula;
          String nm = c.name.replaceAll('ไม่ติดกล่อง', 'ติดกล่อง');
          String cd = c.code.replaceAll('ไม่ติดกล่อง', 'ติดกล่อง');
          if (f.startsWith('W - ')) {
            final d = double.parse(f.substring(4)) + 64;
            f = 'W - ${FormulaEvaluator.formatMm(d)}';
          } else if (f.contains('/')) {
            f = f.replaceFirstMapped(RegExp(r'W - ([0-9.]+)'), (m) {
              final d = double.parse(m.group(1)!) + 64;
              return 'W - ${FormulaEvaluator.formatMm(d)}';
            });
          }
          updated.add(c.copyWith(code: cd, name: nm, formula: f));
        }
        cuts
          ..clear()
          ..addAll(updated);
      }
    }

    // Exterior door swaps 1 regular lock handle for keyed lock handle
    if (usageType == 'ext_door') {
      final idx = hardware.indexWhere((h) => h.name.contains('มือจับฝังล็อก'));
      if (idx >= 0) {
        final cur = hardware[idx];
        final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(cur.qtyText);
        final count = m != null ? int.parse(m.group(1)!) : 2;
        if (count > 1) {
          hardware[idx] = HardwareItemSpec(
            code: cur.code,
            name: cur.name,
            qtyText: '${count - 1} ชุด',
          );
          hardware.insert(
            idx + 1,
            const HardwareItemSpec(
              code: '',
              name: 'มือจับฝังล็อกมีกุญแจ',
              qtyText: '1 ชุด',
            ),
          );
        } else {
          hardware[idx] = const HardwareItemSpec(
            code: '',
            name: 'มือจับฝังล็อกมีกุญแจ',
            qtyText: '1 ชุด',
          );
        }
      }
    }

    // Bumper rubber type
    if (bumper == 'square') {
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('ยางกันกระแทก')) {
          hardware[i] = HardwareItemSpec(
            code: hardware[i].code,
            name: 'ยางกันกระแทกแบบสี่เหลี่ยม',
            qtyText: hardware[i].qtyText,
          );
        }
      }
    }
  }

  static void _applyCat1UnionModifiers({
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final hingeSize = opts['hinge_size'] ?? '6 นิ้ว';
    final side = opts['handle_side'] ?? 'ซ้าย';

    // Ensure Union glazing bead carries Toolkit's exact estimation formula 2*(W + H - 238)
    final hasBead = cuts.any((c) => c.name.contains('คิ้วลูกฟัก'));
    if (!hasBead) {
      cuts.add(
        const CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'คิ้วลูกฟัก',
          name: 'คิ้วลูกฟัก',
          stockMm: 6400,
          qty: 4,
          qtyText: '4 ชิ้น',
          angle: '90° / 90°',
          formula: 'วัดตามจริง (ประมาณการรวม 2*(W + H - 238))',
        ),
      );
    }

    for (int i = 0; i < hardware.length; i++) {
      final h = hardware[i];
      if (h.name.contains('บานพับกระทุ้งยูเนี่ยน')) {
        hardware[i] = HardwareItemSpec(
          code: h.code,
          name: 'บานพับกระทุ้งยูเนี่ยน $hingeSize',
          qtyText: h.qtyText,
        );
      } else if (h.name.contains('มือจับกระทุ้งยูเนี่ยน')) {
        hardware[i] = HardwareItemSpec(
          code: h.code,
          name: 'มือจับกระทุ้งยูเนี่ยน ติด$side',
          qtyText: h.qtyText,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Category 2 Modifiers (ORM Asian Trop, Schimmer, ALUMET Smart X, SMART PLUS)
  // ---------------------------------------------------------------------------
  static void _applyCat2OrmSlidingModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
  }) {
    final stile = opts['stile_size'] ?? '53';
    final jamb = opts['jamb_size'] ?? '20';
    final sill = opts['sill_type'] ?? 'low';

    final isBase75 = patternId == 'c2_orm_s2_card'; // baseFormulaKey == c2_orm_s2_win75 (30mm jamb, high sill, 75mm stile)
    for (int i = 0; i < cuts.length; i++) {
      var c = cuts[i];
      // Sill code
      if (c.code == '801-01' || c.code == '801-02') {
        c = c.copyWith(
          code: sill == 'high' ? '801-02' : '801-01',
          name: sill == 'high' ? 'เฟรมล่างธรณีสูง' : 'เฟรมล่าง',
        );
      }
      // Jamb code (20mm = 801-04, 30mm = 801-05)
      if (c.code == '801-04' || c.code == '801-05') {
        c = c.copyWith(code: jamb == '30' ? '801-05' : '801-04');
      }
      // Adjust W deductions when jamb switches between 20mm (W-40) and 30mm (W-60)
      if (isBase75 && jamb == '20') {
        if (c.formula == 'W - 60') c = c.copyWith(formula: 'W - 40');
        if (c.formula == '(W - 284) / 2') c = c.copyWith(formula: '(W - 264) / 2');
      } else if (!isBase75 && jamb == '30') {
        if (c.formula == 'W - 40') c = c.copyWith(formula: 'W - 60');
        if (c.formula.contains('W - ')) {
          c = c.copyWith(
            formula: c.formula.replaceFirstMapped(RegExp(r'W - (\d+)'), (m) {
              final v = int.parse(m.group(1)!) + 20;
              return 'W - $v';
            }),
          );
        }
      }
      // Stile profile code (53 -> 801-06/801-09, 65 -> 801-07/801-10, 75 -> 801-27/801-28)
      if (c.code == '801-06' || c.code == '801-07' || c.code == '801-27') {
        final newStile = stile == '75'
            ? '801-27'
            : (stile == '65' ? '801-07' : '801-06');
        c = c.copyWith(code: newStile, name: 'เสากุญแจ/เกี่ยว $stile มม.');
      } else if (c.code == '801-09' || c.code == '801-10' || c.code == '801-28') {
        final newCap = stile == '75'
            ? '801-28'
            : (stile == '65' ? '801-10' : '801-09');
        c = c.copyWith(code: newCap, name: 'ตบเสาเกี่ยว $stile มม.');
      }
      cuts[i] = c;
    }
  }

  static void _applyCat2OrmCasementModifiers({
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<GlassPieceSpec> glasses,
    required List<HardwareItemSpec> hardware,
  }) {
    final openMode = opts['open_mode'] ?? 'awning';
    final outerFrame = opts['outer_frame'] ?? '803-01';
    final beadCode = opts['bead_code'] ?? '803-04';
    final strikerCode = opts['striker_code'] ?? 'HD-1100';

    for (int i = 0; i < cuts.length; i++) {
      var c = cuts[i];
      if (c.code == '803-01' && outerFrame == '802-06') {
        c = c.copyWith(
            code: '802-06',
            name: c.name.replaceAll('เฟรมบานตาย', 'เฟรมบานตาย 4 นิ้ว'));
      }
      if (openMode == 'casement' && c.code == '803-09') {
        c = c.copyWith(
            code: '803-10',
            name: c.name.replaceAll('กรอบบานกระทุ้ง', 'กรอบบานตัวใหญ่ซีกรู๊ฟ'));
      }
      if (c.code == '803-04' && beadCode == '803-05') {
        c = c.copyWith(
            code: '803-05',
            name: c.name.replaceAll('12.6 mm', '16.9 mm'));
      }
      if (openMode == 'casement' && c.code == 'เส้น C-กรุ๊ฟ' && c.formula == 'W - 233') {
        c = c.copyWith(formula: 'H - 233');
      }
      cuts[i] = c;
    }

    for (int i = 0; i < hardware.length; i++) {
      final h = hardware[i];
      if (h.code == 'HD-1100' && strikerCode == 'HD-1101') {
        hardware[i] = HardwareItemSpec(
          code: 'HD-1101',
          name: 'จุดรับล็อครุ่นสกรู',
          qtyText: h.qtyText,
        );
      } else if (openMode == 'casement' && h.code == 'HD-622') {
        hardware[i] = HardwareItemSpec(
          code: 'HD-621',
          name: 'บานพับบานเปิด',
          qtyText: h.qtyText,
        );
      }
    }
  }

  static void _applySchimmer250Modifiers(
    Map<String, String> opts,
    List<GlassPieceSpec> glasses,
    List<HardwareItemSpec> hardware,
  ) {
    final gThick = opts['glass_thick'] ?? '5';
    if (gThick == '6') {
      for (int i = 0; i < glasses.length; i++) {
        glasses[i] = GlassPieceSpec(
          name: glasses[i].name.replaceAll('5 มม.', '6 มม.'),
          qty: glasses[i].qty,
          qtyText: glasses[i].qtyText,
          siteCut: glasses[i].siteCut,
          wFormula: glasses[i].wFormula,
          hFormula: glasses[i].hFormula,
        );
      }
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('5 มม.')) {
          hardware[i] = HardwareItemSpec(
            code: '02-034',
            name: hardware[i].name.replaceAll('5 มม.', '6 มม.'),
            qtyText: hardware[i].qtyText,
          );
        }
      }
    }
  }

  static void _applySchimmer260Modifiers({
    required String patternId,
    required Map<String, String> opts,
    required double? dripTrayLengthMm,
    required List<CutPieceSpec> cuts,
    required List<GlassPieceSpec> glasses,
    required List<HardwareItemSpec> hardware,
  }) {
    final gThick = opts['glass_thick'] ?? '5';
    final hingeFam = opts['hinge_family'] ?? '03-001';
    final hingeSize = opts['hinge_size'] ?? '08';
    final handle = opts['handle'] ?? '00-017-L · มือจับสี่เหลี่ยม · ซ้าย';
    final dripTray = opts['drip_tray'] ?? 'none';
    final addPlate = opts['add_backing_plate'] == 'true';
    final addRivet = opts['add_rivet'] == 'true';

    // Handle 260-002-FM (mullion) vs 260-002-NM (no mullion)
    if (patternId == 'c2_sch_260_nm_card') {
      cuts.removeWhere((c) => c.name.contains('เสาประกบ') || c.name.contains('เสากลาง'));
    }

    if (dripTray != 'none') {
      final trayFormula = (dripTrayLengthMm != null && dripTrayLengthMm > 0)
          ? 'DripLen'
          : 'W';
      cuts.add(
        CutPieceSpec(
          section: 'อุปกรณ์เสริม',
          code: dripTray,
          name: 'ถาดรองน้ำ $dripTray',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: trayFormula,
        ),
      );
    }

    if (gThick == '6') {
      for (int i = 0; i < glasses.length; i++) {
        glasses[i] = GlassPieceSpec(
          name: glasses[i].name.replaceAll('5 มม.', '6 มม.'),
          qty: glasses[i].qty,
          qtyText: glasses[i].qtyText,
          siteCut: glasses[i].siteCut,
          wFormula: glasses[i].wFormula,
          hFormula: glasses[i].hFormula,
        );
      }
    }

    final hingeCode = '$hingeFam-$hingeSize';
    final handleParts = handle.split(' · ');
    final handleCode = handleParts.first.trim();
    for (int i = 0; i < hardware.length; i++) {
      final h = hardware[i];
      if (h.code.startsWith('03-001') || h.code.startsWith('03-006')) {
        hardware[i] = HardwareItemSpec(
          code: hingeCode,
          name: 'บานพับแขนค้ำ ${int.parse(hingeSize)} นิ้ว ($hingeCode)',
          qtyText: h.qtyText,
        );
      } else if (h.code.startsWith('00-017') || h.code.startsWith('00-018')) {
        hardware[i] = HardwareItemSpec(
          code: handleCode,
          name: handle,
          qtyText: h.qtyText,
        );
      }
    }

    final leafCount = patternId == 'c2_sch_260_001_card' ? 1 : 2;
    if (addPlate) {
      hardware.add(
        HardwareItemSpec(
          code: '03-007-$hingeSize',
          name: 'แผ่นรองบานพับแขนค้ำ 03-007-$hingeSize',
          qtyText: '${2 * leafCount} ชิ้น',
        ),
      );
    }
    if (addRivet) {
      hardware.add(
        HardwareItemSpec(
          code: '09',
          name: 'รีเวท 4.8 มม.',
          qtyText: '${8 * leafCount} ตัว',
        ),
      );
    }
  }

  static void _applyCat2AlumetSlidingModifiers({
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final thick = opts['thickness'] ?? '1.2';
    final angle = opts['sash_angle'] ?? '90';
    final roller = opts['roller_type'] ?? 'cartridge';
    final mosq = opts['mosquito'] ?? 'none';

    for (int i = 0; i < cuts.length; i++) {
      var c = cuts[i];
      if (thick == '1.5') {
        if (c.code == 'SS-X110') c = c.copyWith(code: 'SS-X101');
        if (c.code == 'SS-X109') c = c.copyWith(code: 'SS-X102');
        if (c.code == 'SS-X111') c = c.copyWith(code: 'SS-X103');
      }
      if (angle == '45') {
        if (c.code == 'SS-0138' || c.code == 'SS-X217') {
          c = c.copyWith(code: 'SS-X219', angle: '45° / 45°');
        }
      }
      cuts[i] = c;
    }

    if (roller == 'market') {
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('ล้อ')) {
          hardware[i] = HardwareItemSpec(
            code: 'SS-0105',
            name: 'ล้อตลาด Smart X',
            qtyText: hardware[i].qtyText,
          );
        }
      }
    }

    if (mosq == 'small_mkt') {
      cuts.addAll(const [
        CutPieceSpec(
          section: 'มุ้งลวด',
          code: 'กรอบมุ้งตลาดเล็ก',
          name: 'กรอบมุ้งแนวตั้ง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '45° / 45°',
          formula: 'H - 62',
        ),
        CutPieceSpec(
          section: 'มุ้งลวด',
          code: 'กรอบมุ้งตลาดเล็ก',
          name: 'กรอบมุ้งแนวนอน',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '45° / 45°',
          formula: '(W - 40) / 2',
        ),
      ]);
    }
  }

  static void _applyCat2SmartPlusTopTransom(
    List<CutPieceSpec> cuts,
    List<GlassPieceSpec> glasses,
  ) {
    for (int i = 0; i < cuts.length; i++) {
      final c = cuts[i];
      if (c.formula == 'H - 36') {
        cuts[i] = c.copyWith(formula: 'H1 - 36');
      } else if (c.formula == 'H - 154') {
        cuts[i] = c.copyWith(formula: 'H1 - 154');
      }
    }
    cuts.addAll(const [
      CutPieceSpec(
        section: 'ช่องแสงบน',
        code: '15115',
        name: 'คั่นกลางช่องแสงบน',
        stockMm: 6400,
        qty: 1,
        qtyText: '1 ชิ้น',
        angle: '90° / 90°',
        formula: 'W - 50',
      ),
      CutPieceSpec(
        section: 'ช่องแสงบน',
        code: '15120',
        name: 'คิ้วช่องแสงบนแนวตั้ง',
        stockMm: 6400,
        qty: 2,
        qtyText: '2 ชิ้น',
        angle: '90° / 90°',
        formula: '(H - H1) - 30',
      ),
      CutPieceSpec(
        section: 'ช่องแสงบน',
        code: '15120',
        name: 'คิ้วช่องแสงบนแนวนอน',
        stockMm: 6400,
        qty: 2,
        qtyText: '2 ชิ้น',
        angle: '90° / 90°',
        formula: 'W - 90',
      ),
    ]);
    for (int i = 0; i < glasses.length; i++) {
      final g = glasses[i];
      if (g.hFormula.startsWith('H - ')) {
        glasses[i] = GlassPieceSpec(
          name: g.name,
          qty: g.qty,
          qtyText: g.qtyText,
          siteCut: g.siteCut,
          wFormula: g.wFormula,
          hFormula: g.hFormula.replaceFirst('H - ', 'H1 - '),
        );
      }
    }
    glasses.add(
      const GlassPieceSpec(
        name: 'กระจกช่องแสงบน',
        qty: 1,
        qtyText: '1 แผ่น',
        siteCut: false,
        wFormula: 'W - 80',
        hFormula: '(H - H1) - 35',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category 3 Modifiers (Fuji Eurotech, ALUMET Iconiq, SMART PLUS Euro, ALUFRAME)
  // ---------------------------------------------------------------------------
  static void _applyCat3FujiSlidingModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<GlassPieceSpec> glasses,
    required SeedRepository seed,
  }) {
    if (!patternId.startsWith('c3_fuji_s') && !patternId.contains('_int_card')) {
      return;
    }

    final sashCode = opts['sash_code'] ?? 'F7980';
    final trackMode = opts['track_mode'] ?? '3t';
    final mosq = opts['mosquito'] == 'true';

    if (sashCode == 'F7981' && trackMode == '2t' && patternId == 'c3_fuji_s2_card') {
      final t2 = seed.getFormulaTable('c3_fuji_s2_f7981_2t');
      if (t2 != null) {
        cuts
          ..clear()
          ..addAll(t2.cuts.map((c) => c.copyWith()));
        glasses
          ..clear()
          ..addAll(t2.glasses);
      }
    } else {
      for (int i = 0; i < cuts.length; i++) {
        var c = cuts[i];
        if (sashCode == 'F7981' && c.code == 'F7980') {
          c = c.copyWith(code: 'F7981');
        }
        if (trackMode == '2t') {
          if (c.code == 'F7976') c = c.copyWith(code: 'F7977');
          if (c.code == 'F7978') c = c.copyWith(code: 'F7979');
          if ((c.code == 'F7994' || c.code == 'F7993') && c.qty == 3) {
            c = c.copyWith(qty: 2, qtyText: '2 ชิ้น');
          }
        }
        cuts[i] = c;
      }
    }

    // Multi-panel scaling for 3, 4, 5 panels
    int panels = 2;
    if (patternId == 'c3_fuji_s3_card') panels = 3;
    if (patternId.contains('s4') || patternId == 'c3_fuji_4t_int_card') panels = 4;
    if (patternId == 'c3_fuji_s5_card' || patternId == 'c3_fuji_5t_int_card') panels = 5;

    if (panels > 2) {
      for (int i = 0; i < cuts.length; i++) {
        final c = cuts[i];
        if (c.code == 'F7980' || c.code == 'F7981' || c.code == 'F7919') {
          final newQty = 2 * panels;
          final newFormula = c.formula.replaceAll('/ 2', '/ $panels');
          cuts[i] = c.copyWith(
            qty: newQty,
            qtyText: '$newQty ชิ้น',
            formula: newFormula,
          );
        } else if (c.code == 'F7983') {
          final newQty = 2 * (panels - 1);
          cuts[i] = c.copyWith(qty: newQty, qtyText: '$newQty ชิ้น');
        }
      }
      if (glasses.isNotEmpty) {
        final g = glasses.first;
        glasses[0] = GlassPieceSpec(
          name: g.name,
          qty: panels,
          qtyText: '$panels แผ่น',
          siteCut: g.siteCut,
          wFormula: g.wFormula.replaceAll('/ 2', '/ $panels'),
          hFormula: g.hFormula,
        );
      }
    }

    if (mosq) {
      cuts.addAll(const [
        CutPieceSpec(
          section: 'มุ้งลวด',
          code: 'F7982',
          name: 'กรอบมุ้งลวดแนวตั้ง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '45° / 45°',
          formula: 'H - 74',
        ),
        CutPieceSpec(
          section: 'มุ้งลวด',
          code: 'F7982',
          name: 'กรอบมุ้งลวดแนวนอน',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '45° / 45°',
          formula: '(W + 28) / 2',
        ),
      ]);
    }
  }

  static void _applyCat3IconiqSlidingModifiers(
    Map<String, String> opts,
    List<CutPieceSpec> cuts,
  ) {
    final loc = opts['location_type'] ?? 'ext';
    final bead = opts['bead_code'] ?? 'iS-0202';

    if (loc == 'int') {
      cuts.removeWhere((c) => c.code == 'iS-0105'); // Interior omits exterior weep cover
    }
    if (bead == 'iS-0204') {
      for (int i = 0; i < cuts.length; i++) {
        if (cuts[i].code == 'iS-0202') {
          cuts[i] = cuts[i].copyWith(
            code: 'iS-0204',
            name: 'คิ้วกระจกทางเลือก iS-0204 (วัดตามจริง)',
            formula: 'วัดตามจริง',
          );
        }
      }
    }
  }

  static void _applyCat3SmartPlusEuroModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<GlassPieceSpec> glasses,
  }) {
    final sash = opts['sash_code'];
    if (sash != null && sash.isNotEmpty) {
      for (int i = 0; i < cuts.length; i++) {
        final c = cuts[i];
        if ((c.code == '15146' || c.code == '15147' || c.code == '15209') &&
            (sash == '15146' || sash == '15147' || sash == '15209')) {
          cuts[i] = c.copyWith(code: sash);
        } else if ((c.code == '15117' || c.code == '15141') &&
            (sash == '15117' || sash == '15141')) {
          cuts[i] = c.copyWith(code: sash);
        } else if ((c.code == '15141' || c.code == '15144') &&
            (sash == '15141' || sash == '15144')) {
          cuts[i] = c.copyWith(code: sash);
        }
      }
    }

    // Transom column subdivision (1..4 columns -> cols - 1 vertical mullions 15143)
    final colsStr = opts['transom_cols'];
    if (colsStr != null) {
      final cols = int.tryParse(colsStr) ?? 1;
      if (cols > 1) {
        cuts.add(
          CutPieceSpec(
            section: 'ช่องแสงบน',
            code: '15143',
            name: 'เสาแบ่งช่องแสงบน ($cols ช่อง)',
            stockMm: 6400,
            qty: cols - 1,
            qtyText: '${cols - 1} ชิ้น',
            angle: '90° / 90°',
            formula: '(H - H1) - 32',
          ),
        );
        for (int i = 0; i < glasses.length; i++) {
          if (glasses[i].name.contains('ช่องแสง')) {
            glasses[i] = GlassPieceSpec(
              name: glasses[i].name,
              qty: cols,
              qtyText: '$cols แผ่น',
              siteCut: glasses[i].siteCut,
              wFormula: '(W - ${50 + 30 * cols}) / $cols',
              hFormula: glasses[i].hFormula,
            );
          }
        }
      }
    }
  }

  static void _applyCat3AluframeSlidingModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<GlassPieceSpec> glasses,
  }) {
    final stile = opts['stile_width'] ?? '77';
    if (stile == '87') {
      for (int i = 0; i < cuts.length; i++) {
        if (cuts[i].name.contains('77')) {
          cuts[i] = cuts[i].copyWith(name: cuts[i].name.replaceAll('77', '87'));
        }
      }
    }

    int panels = 2;
    if (patternId == 'c3_af_s3_card') panels = 3;
    if (patternId.contains('_s4_')) panels = 4;
    if (patternId == 'c3_af_s6_ctr_card') panels = 6;

    if (panels > 2) {
      for (int i = 0; i < cuts.length; i++) {
        final c = cuts[i];
        if (c.formula.contains('/ 2')) {
          final scaledQty = (c.qty * panels) ~/ 2;
          cuts[i] = c.copyWith(
            qty: scaledQty,
            qtyText: '$scaledQty ชิ้น',
            formula: c.formula.replaceAll('/ 2', '/ $panels'),
          );
        } else if (c.section.contains('กรอบบาน') && c.formula.startsWith('H')) {
          final scaledQty = (c.qty * panels) ~/ 2;
          cuts[i] = c.copyWith(qty: scaledQty, qtyText: '$scaledQty ชิ้น');
        }
      }
      for (int i = 0; i < glasses.length; i++) {
        final g = glasses[i];
        glasses[i] = GlassPieceSpec(
          name: g.name,
          qty: panels,
          qtyText: '$panels แผ่น',
          siteCut: g.siteCut,
          wFormula: g.wFormula.replaceAll('/ 2', '/ $panels'),
          hFormula: g.hFormula,
        );
      }
    }
  }

  // ===========================================================================
  // Category 4 Parametric Folding Resolver (All 136 Active Cards)
  // ===========================================================================
  static VerifiedFormulaTable _resolveFoldingTable(
    PatternCardDef pattern,
    Map<String, String> opts,
    SeedRepository seed,
  ) {
    final fam = pattern.foldingFamily!;
    final n = pattern.foldingTotalPanels ?? 2;
    final l = pattern.foldingLeftPanels ?? n;
    final r = pattern.foldingRightPanels ?? 0;

    switch (fam) {
      case 'orm90':
      case 'orm101':
        return _resolveOrmFolding(fam, n, l, r, opts, seed);
      case 'fuji_std':
      case 'fuji_u':
        return _resolveFujiFolding(fam, n, l, r, seed);
      case 'sp_fold':
        return _resolveSmartPlusFolding(n, l, r, seed);
      case 'alu_fold':
        return _resolveAlumetFolding(pattern.id, n, l, r, opts, seed);
      case 'sch240':
        return _resolveSchimmer240FivePanel();
      default:
        throw StateError('Unknown folding family: $fam');
    }
  }

  static VerifiedFormulaTable _resolveOrmFolding(
    String fam,
    int n,
    int l,
    int r,
    Map<String, String> opts,
    SeedRepository seed,
  ) {
    final is101 = fam == 'orm101';
    final lowSill = opts['sill_mode'] == 'low';
    final headCode = is101 ? '805-12' : '805-01';
    final jambCode = is101 ? '805-13' : '805-02';
    final sillCode = lowSill ? '805-04' : (is101 ? '805-14' : '805-03');
    final sillName = lowSill ? 'รางธรณีต่ำ' : 'เฟรมล่าง';

    final exactKey = 'c4_${fam}_$n$l$r';
    final fallback90Key = 'c4_orm90_$n$l$r';
    final swept = seed.getFormulaTable(exactKey) ?? seed.getFormulaTable(fallback90Key);

    if (swept != null) {
      final adaptedCuts = swept.cuts.map((c) {
        if (c.code == '805-01' || c.code == '805-12') {
          return c.copyWith(code: headCode);
        }
        if (c.code == '805-02' || c.code == '805-13') {
          return c.copyWith(code: jambCode);
        }
        if (c.code == '805-03' || c.code == '805-14') {
          return c.copyWith(code: sillCode, name: sillName);
        }
        return c.copyWith();
      }).toList();
      return VerifiedFormulaTable(
        key: exactKey,
        header: 'ORM Euro Folding | บานเฟี้ยม $n-$l-$r',
        cuts: adaptedCuts,
        glasses: List<GlassPieceSpec>.from(swept.glasses),
        hardware: List<HardwareItemSpec>.from(swept.hardware),
      );
    }

    // Closed-form exact ORM Euro Folding formula for un-swept (n, l, r)
    final isEvenEven = l > 0 && r > 0 && (l % 2 == 0) && (r % 2 == 0);
    final sashDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 8.0 * n);
    final beadDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 168.0 * n);
    final glassDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 138.0 * n);

    final cuts = <CutPieceSpec>[
      CutPieceSpec(
          section: 'วงกบ',
          code: headCode,
          name: 'เฟรมบน',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 40'),
      CutPieceSpec(
          section: 'วงกบ',
          code: sillCode,
          name: sillName,
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 40'),
      CutPieceSpec(
          section: 'วงกบ',
          code: jambCode,
          name: 'เฟรมข้าง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'กรอบบานเฟี้ยมมาตรฐาน',
          name: 'กรอบบานแนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: 'H - 85'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'กรอบบานเฟี้ยมมาตรฐาน',
          name: 'กรอบบานแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: '(W - $sashDed) / $n'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: '805-05',
          name: 'คิ้วแนวตั้ง',
          stockMm: 6400,
          qty: 4 * n,
          qtyText: '${4 * n} ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 130'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: '805-05',
          name: 'คิ้วแนวนอน',
          stockMm: 6400,
          qty: 4 * n,
          qtyText: '${4 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
      CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: isEvenEven ? '805-11' : '805-06',
          name: 'โปรไฟล์ปิดชนกลาง',
          stockMm: 6400,
          qty: isEvenEven ? 2 : 1,
          qtyText: isEvenEven ? '2 ชิ้น' : '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 85'),
      CutPieceSpec(
          section: 'เส้น C-กรุ๊ฟ',
          code: 'เส้น C-กรุ๊ฟ',
          name: 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
          stockMm: 6400,
          qty: isEvenEven ? 2 : 1,
          qtyText: isEvenEven ? '2 ชิ้น' : '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 85'),
    ];

    final glasses = [
      GlassPieceSpec(
        name: 'กระจกบานเฟี้ยม $n-$l-$r',
        qty: n,
        qtyText: '$n แผ่น',
        siteCut: false,
        wFormula: '(W - $glassDed) / $n',
        hFormula: 'H - 215',
      ),
    ];

    return VerifiedFormulaTable(
      key: exactKey,
      header: 'ORM Euro Folding | บานเฟี้ยม $n-$l-$r',
      cuts: cuts,
      glasses: glasses,
      hardware: _buildHydaFoldingHardware(n, l, r),
    );
  }

  static VerifiedFormulaTable _resolveFujiFolding(
    String fam,
    int n,
    int l,
    int r,
    SeedRepository seed,
  ) {
    final isU = fam == 'fuji_u';
    final exactKey = 'c4_${fam}_$n$l$r';
    final stdKey = 'c4_fuji_std_$n$l$r';
    final sweptExact = seed.getFormulaTable(exactKey);
    if (sweptExact != null) return sweptExact;

    final sweptStd = seed.getFormulaTable(stdKey);
    if (sweptStd != null && isU) {
      final adaptedCuts = sweptStd.cuts.map((c) {
        if (c.code == 'F7969') {
          return c.copyWith(code: 'F7932', name: 'ราง U');
        }
        if (c.formula == 'H - 120') return c.copyWith(formula: 'H - 75');
        if (c.formula == 'H - 92') return c.copyWith(formula: 'H - 67');
        if (c.formula == 'H - 252') return c.copyWith(formula: 'H - 227');
        return c.copyWith();
      }).toList();
      final adaptedGlasses = sweptStd.glasses
          .map((g) => GlassPieceSpec(
                name: g.name,
                qty: g.qty,
                qtyText: g.qtyText,
                siteCut: g.siteCut,
                wFormula: g.wFormula,
                hFormula: 'H - 197',
              ))
          .toList();
      return VerifiedFormulaTable(
        key: exactKey,
        header: 'Fuji Eurotech Folding | บานเฟี้ยม $n-$l-$r-u',
        cuts: adaptedCuts,
        glasses: adaptedGlasses,
        hardware: List<HardwareItemSpec>.from(sweptStd.hardware),
      );
    }

    // Parametric Fuji Eurotech Folding for N = 2..10
    final sashHExpr = isU ? 'H - 67' : 'H - 92';
    final subJambExpr = isU ? 'H - 75' : 'H - 120';
    final beadVertExpr = isU ? 'H - 227' : 'H - 252';
    final glassHExpr = isU ? 'H - 197' : 'H - 222';
    final sashDed = FormulaEvaluator.formatMm(66.0 + 11.4 * n);
    final beadDed = FormulaEvaluator.formatMm(66.0 + 131.4 * n);
    final glassDed = FormulaEvaluator.formatMm(66.0 + 141.4 * n);

    final cuts = <CutPieceSpec>[
      const CutPieceSpec(
          section: 'วงกบ',
          code: 'F7968',
          name: 'วงกบบน',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 36'),
      CutPieceSpec(
          section: 'วงกบ',
          code: isU ? 'F7932' : 'F7969',
          name: isU ? 'ราง U' : 'วงกบล่าง',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 36'),
      const CutPieceSpec(
          section: 'วงกบ',
          code: 'F7970',
          name: 'วงกบข้าง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H'),
      CutPieceSpec(
          section: 'วงกบ',
          code: 'F7971',
          name: 'ตบวงกบข้าง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: subJambExpr),
      CutPieceSpec(
          section: 'วงกบ',
          code: 'F7973',
          name: 'ตัวปิดร่องแนวนอน',
          stockMm: 6400,
          qty: isU ? 1 : 2,
          qtyText: isU ? '1 ชิ้น' : '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 40'),
      CutPieceSpec(
          section: 'วงกบ',
          code: 'F7973',
          name: 'ตัวปิดร่องแนวตั้ง',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: subJambExpr),
      CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: 'F7975',
          name: 'บังใบ',
          stockMm: 6400,
          qty: (l > 0 && r > 0) ? 2 : 1,
          qtyText: (l > 0 && r > 0) ? '2 ชิ้น' : '1 ชิ้น',
          angle: '90° / 90°',
          formula: sashHExpr),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'F7972',
          name: 'กรอบบานแนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: sashHExpr),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'F7972',
          name: 'กรอบบานแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: '(W - $sashDed) / $n'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'F7935',
          name: 'คิ้วกระจกแนวตั้ง 5–12 mm',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90°',
          formula: beadVertExpr),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'F7935',
          name: 'คิ้วกระจกแนวนอน 5–12 mm',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90°',
          formula: '(W - $beadDed) / $n'),
    ];

    final hw = <HardwareItemSpec>[
      HardwareItemSpec(
          code: 'HD-640',
          name: 'HD-640 · บานพับกรอบบน',
          qtyText: '${(n ~/ 2)} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-641',
          name: 'HD-641 · บานพับกลาง',
          qtyText: '${3 * (n - 1)} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-642',
          name: 'HD-642 · บานพับพร้อมมือจับ',
          qtyText: '${(n ~/ 2)} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-643',
          name: 'HD-643 · บานพับไกด์ล่าง',
          qtyText: '${(n ~/ 2)} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-214',
          name: 'HD-214 · ฉากเข้ามุมปรับได้',
          qtyText: '${4 * n} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-200',
          name: 'HD-200 · ฉากประคองบาน',
          qtyText: '${12 * n} ชิ้น'),
    ];

    return VerifiedFormulaTable(
      key: exactKey,
      header: 'Fuji Eurotech Folding | บานเฟี้ยม $n-$l-$r${isU ? "-u" : ""}',
      cuts: cuts,
      glasses: [
        GlassPieceSpec(
          name: 'กระจกบานเฟี้ยม',
          qty: n,
          qtyText: '$n แผ่น',
          siteCut: false,
          wFormula: '(W - $glassDed) / $n',
          hFormula: glassHExpr,
        ),
      ],
      hardware: hw,
    );
  }

  static VerifiedFormulaTable _resolveSmartPlusFolding(
    int n,
    int l,
    int r,
    SeedRepository seed,
  ) {
    final exactKey = 'c4_sp_$n$l$r';
    final swept = seed.getFormulaTable(exactKey);
    if (swept != null && swept.hardware.isNotEmpty) {
      return swept;
    }
    if (swept != null) {
      return VerifiedFormulaTable(
        key: swept.key,
        header: swept.header,
        cuts: swept.cuts,
        glasses: swept.glasses,
        hardware: _buildHydaFoldingHardware(n, l, r),
      );
    }

    final isEvenEven = l > 0 && r > 0 && (l % 2 == 0) && (r % 2 == 0);
    final sashDed = FormulaEvaluator.formatMm((isEvenEven ? 88.0 : 60.0) + 9.7 * n);
    final beadDed = FormulaEvaluator.formatMm((isEvenEven ? 88.0 : 60.0) + 169.7 * n);
    final glassDed = FormulaEvaluator.formatMm((isEvenEven ? 88.0 : 60.0) + 149.7 * n);

    final cuts = <CutPieceSpec>[
      const CutPieceSpec(
          section: 'วงกบ',
          code: '15167',
          name: 'เฟรมบนเฟี้ยม',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 40'),
      const CutPieceSpec(
          section: 'วงกบ',
          code: '15168',
          name: 'เฟรมล่างเฟี้ยม',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 40'),
      const CutPieceSpec(
          section: 'วงกบ',
          code: '15169',
          name: 'เฟรมข้างเฟี้ยม',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: '15171',
          name: 'เสาบานเฟี้ยม แนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: 'H - 86'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: '15171',
          name: 'เสาบานเฟี้ยม แนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: '(W - $sashDed) / $n'),
      CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: isEvenEven ? '15178' : '15181',
          name: isEvenEven ? 'แกนกลางเฟี้ยม' : 'แกนกลางบังใบเฟี้ยม',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 78'),
      const CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: '15156',
          name: 'ตบปิดกล่องก้าน',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H'),
      CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: 'เส้น C-กรุ๊ฟ',
          name: 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
          stockMm: 6400,
          qty: isEvenEven ? 2 : 1,
          qtyText: isEvenEven ? '2 ชิ้น' : '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 85'),
      CutPieceSpec(
          section: 'คิ้วกระจกนอก',
          code: '15173',
          name: 'คิ้วนอกบานเฟี้ยมร่องกระจก 12.7 มิล แนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 214'),
      CutPieceSpec(
          section: 'คิ้วกระจกนอก',
          code: '15173',
          name: 'คิ้วนอกบานเฟี้ยมร่องกระจก 12.7 มิล แนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
      CutPieceSpec(
          section: 'คิ้วกระจกใน',
          code: '15174',
          name: 'คิ้วในบานเฟี้ยมร่องกระจก 12.7 มิล แนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 214'),
      CutPieceSpec(
          section: 'คิ้วกระจกใน',
          code: '15174',
          name: 'คิ้วในบานเฟี้ยมร่องกระจก 12.7 มิล แนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
    ];

    return VerifiedFormulaTable(
      key: exactKey,
      header: 'SMART PLUS EURO PROFILE | ชุดบานเฟี้ยม $n-$l-$r',
      cuts: cuts,
      glasses: [
        GlassPieceSpec(
          name: 'กระจกบานเฟี้ยม $n-$l-$r',
          qty: n,
          qtyText: '$n แผ่น',
          siteCut: false,
          wFormula: '(W - $glassDed) / $n',
          hFormula: 'H - 224',
        ),
      ],
      hardware: _buildHydaFoldingHardware(n, l, r),
    );
  }

  static VerifiedFormulaTable _resolveAlumetFolding(
    String patternId,
    int n,
    int l,
    int r,
    Map<String, String> opts,
    SeedRepository seed,
  ) {
    final sillCode = opts['sill_code'] ?? 'SB-0116';
    final sillName = sillCode == 'SB-0103'
        ? 'เฟรมล่างบานเฟี้ยมภายนอก'
        : (sillCode == 'SB-0115' ? 'เฟรมยูฝังพื้น' : 'เฟรมล่างบานเฟี้ยมภายใน');

    String exactKey = 'c4_alu_$n$l$r';
    if (n == 4 && l == 4 && r == 0) exactKey = 'c4_alu_440_nothresh';
    if (n == 6 && l == 3 && r == 3) exactKey = 'c4_alu_633_nogroove';

    final swept = seed.getFormulaTable(exactKey);
    if (swept != null) {
      final adaptedCuts = swept.cuts.map((c) {
        if (c.code == 'SB-0116' || c.code == 'SB-0103' || c.code == 'SB-0115') {
          return c.copyWith(code: sillCode, name: sillName);
        }
        return c.copyWith();
      }).toList();
      return VerifiedFormulaTable(
        key: exactKey,
        header: 'ALUMET Smart X Folding | $n-$l-$r',
        cuts: adaptedCuts,
        glasses: List<GlassPieceSpec>.from(swept.glasses),
        hardware: swept.hardware.isNotEmpty
            ? List<HardwareItemSpec>.from(swept.hardware)
            : _buildHydaFoldingHardware(n, l, r),
      );
    }

    // Parametric ALUMET Smart X Folding for remaining 7-5-2 & 7-4-3
    final sashDed = FormulaEvaluator.formatMm(93.6 + 10.0 * n);
    final beadDed = FormulaEvaluator.formatMm(93.6 + 174.0 * n);
    final glassDed = FormulaEvaluator.formatMm(93.6 + 144.0 * n);

    final cuts = <CutPieceSpec>[
      const CutPieceSpec(
          section: 'วงกบ',
          code: 'SB-0105',
          name: 'เฟรมข้างบานเฟี้ยม',
          stockMm: 6400,
          qty: 2,
          qtyText: '2 ชิ้น',
          angle: '90° / 90°',
          formula: 'H'),
      const CutPieceSpec(
          section: 'วงกบ',
          code: 'SB-0101',
          name: 'เฟรมบนบานเฟี้ยม',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 38'),
      CutPieceSpec(
          section: 'วงกบ',
          code: sillCode,
          name: sillName,
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'W - 38'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'SB-0108',
          name: 'คิ้วภายนอกแนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 206'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'SB-0108',
          name: 'คิ้วภายนอกแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'SB-0109',
          name: 'คิ้วภายในแนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 206'),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'SB-0109',
          name: 'คิ้วภายในแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
      const CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: 'SB-0113',
          name: 'บังใบบานคู่',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 82'),
      const CutPieceSpec(
          section: 'เส้นเฉพาะ Layout',
          code: 'SB-0117',
          name: 'บังใบบานคี่',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 82'),
      const CutPieceSpec(
          section: 'เส้น C-กรุ๊ฟ',
          code: 'เส้น C-กรุ๊ฟ',
          name: 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H - 85'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'SB-0114',
          name: 'กรอบบานแนวตั้ง',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: 'H - 82'),
      CutPieceSpec(
          section: 'กรอบบานเฟี้ยม',
          code: 'SB-0114',
          name: 'กรอบบานแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '45° / 45°',
          formula: '(W - $sashDed) / $n'),
    ];

    return VerifiedFormulaTable(
      key: exactKey,
      header: 'ALUMET Smart X Folding | $n-$l-$r',
      cuts: cuts,
      glasses: [
        GlassPieceSpec(
          name: 'กระจกบานเฟี้ยม',
          qty: n,
          qtyText: '$n แผ่น',
          siteCut: false,
          wFormula: '(W - $glassDed) / $n',
          hFormula: 'H - 216',
        ),
      ],
      hardware: _buildHydaFoldingHardware(n, l, r),
    );
  }

  static VerifiedFormulaTable _resolveSchimmer240FivePanel() {
    return const VerifiedFormulaTable(
      key: 'c4_sch_5_4l1r',
      header: 'SMS SCHIMMER / Schimmer | บานเฟี้ยม 5 บาน ซ้าย 4 · ขวา 1 (4L-1R)',
      cuts: [
        CutPieceSpec(
            section: 'วงกบ',
            code: 'B24001',
            name: 'HEAD',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 60'),
        CutPieceSpec(
            section: 'วงกบ',
            code: 'B24003',
            name: 'SILL',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 60'),
        CutPieceSpec(
            section: 'วงกบ',
            code: 'B24005',
            name: 'LEFT JAMB',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H'),
        CutPieceSpec(
            section: 'วงกบ',
            code: 'B24005',
            name: 'RIGHT JAMB',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H'),
        CutPieceSpec(
            section: 'ตัวหยุดบาน',
            code: 'B24002',
            name: 'DOOR STOP HEAD',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 60'),
        CutPieceSpec(
            section: 'ตัวหยุดบาน',
            code: 'B24004',
            name: 'DOOR STOP SILL',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'W - 60'),
        CutPieceSpec(
            section: 'ตัวหยุดบาน',
            code: 'B24006',
            name: 'LEFT DOOR STOP JAMB',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 96'),
        CutPieceSpec(
            section: 'ตัวหยุดบาน',
            code: 'B24006',
            name: 'RIGHT DOOR STOP JAMB',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 96'),
        CutPieceSpec(
            section: 'ตัวหยุดบาน',
            code: 'B24009',
            name: 'SASH STOP · B24009-001',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 92'),
        CutPieceSpec(
            section: 'กรอบบาน',
            code: 'B24007',
            name: 'TOP SASH HORIZONTAL',
            stockMm: 6400,
            qty: 5,
            qtyText: '5 ชิ้น',
            angle: '90° / 90°',
            formula: '(W - 640) / 5'),
        CutPieceSpec(
            section: 'กรอบบาน',
            code: 'B24007',
            name: 'BOTTOM SASH HORIZONTAL',
            stockMm: 6400,
            qty: 5,
            qtyText: '5 ชิ้น',
            angle: '90° / 90°',
            formula: '(W - 640) / 5'),
        CutPieceSpec(
            section: 'กรอบบาน',
            code: 'B24007',
            name: 'STANDARD VERTICAL SASH',
            stockMm: 6400,
            qty: 8,
            qtyText: '8 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 92'),
        CutPieceSpec(
            section: 'กรอบบาน',
            code: 'B24007',
            name: 'LOCK VERTICAL SASH',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 92'),
        CutPieceSpec(
            section: 'คิ้วกระจก',
            code: 'B24008',
            name: 'HORIZONTAL GLAZING BEAD',
            stockMm: 6400,
            qty: 10,
            qtyText: '10 ชิ้น',
            angle: '90° / 90°',
            formula: '(W - 640) / 5'),
        CutPieceSpec(
            section: 'คิ้วกระจก',
            code: 'B24008',
            name: 'VERTICAL GLAZING BEAD',
            stockMm: 6400,
            qty: 10,
            qtyText: '10 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 242'),
      ],
      glasses: [
        GlassPieceSpec(
          name: 'กระจก 6 มม.',
          qty: 5,
          qtyText: '5 แผ่น',
          siteCut: false,
          wFormula: '(W - 705) / 5',
          hFormula: 'H - 215',
        ),
      ],
      hardware: [
        HardwareItemSpec(
            code: '05-006', name: 'LEFT HAND PIVOT SET', qtyText: '1 ชุด'),
        HardwareItemSpec(
            code: '05-007', name: 'RIGHT HAND PIVOT SET', qtyText: '1 ชุด'),
        HardwareItemSpec(
            code: '05-008', name: 'INTERMEDIATE CARRIER SET', qtyText: '2 ชุด'),
        HardwareItemSpec(
            code: '05-004',
            name: 'STANDARD HINGE HANDLE SET',
            qtyText: '2 ชุด'),
        HardwareItemSpec(
            code: '00-019',
            name: 'MORTISE FLUSH BOLT · OPTION 1',
            qtyText: '4 ชุด'),
        HardwareItemSpec(
            code: '00-024',
            name: 'MORTISE LOCK HANDLE SET',
            qtyText: '1 ชุด'),
      ],
    );
  }

  static List<HardwareItemSpec> _buildHydaFoldingHardware(int n, int l, int r) {
    final carrierPairs = (l ~/ 2) + (r ~/ 2);
    final hasSwingLeaf = (l % 2 == 1) || (r % 2 == 1);
    final hw = <HardwareItemSpec>[
      HardwareItemSpec(
        code: hasSwingLeaf ? 'HD-640B' : 'HD-640A',
        name: hasSwingLeaf ? 'HD-640B ล้อบนปกติ' : 'HD-640A ล้อบนตัวจบชนบานคู่',
        qtyText: '${carrierPairs > 0 ? carrierPairs : 1} ชิ้น',
      ),
      HardwareItemSpec(
        code: hasSwingLeaf ? 'HD-643B' : 'HD-643A',
        name: hasSwingLeaf
            ? 'HD-643B บานพับไกด์ล่างปกติ'
            : 'HD-643A บานพับไกด์ล่างตัวจบชนบานคู่',
        qtyText: '${carrierPairs > 0 ? carrierPairs : 1} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-641',
        name: 'HD-641 บานพับปกติ',
        qtyText: '${3 * (n - 1)} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-642',
        name: 'HD-642 บานพับมือจับ',
        qtyText: '${carrierPairs > 0 ? carrierPairs : 1} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-321',
        name: 'HD-321 CDQ',
        qtyText: '${carrierPairs > 0 ? carrierPairs : 1} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-320',
        name: 'HD-320 ปลายกลอนบานเฟี้ยม',
        qtyText: '${2 * (carrierPairs > 0 ? carrierPairs : 1)} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-474',
        name: 'HD-474 มือจับปากเป็ด',
        qtyText: '${carrierPairs > 0 ? carrierPairs : 1} ชิ้น',
      ),
    ];
    if (hasSwingLeaf) {
      hw.addAll(const [
        HardwareItemSpec(
          code: '',
          name: 'เสื้อกุญแจ 35×85 + ไส้กุญแจ',
          qtyText: '1 ชุด',
        ),
        HardwareItemSpec(
          code: '',
          name: 'มือจับเขาควายมีรูกุญแจ',
          qtyText: '1 คู่',
        ),
      ]);
    }
    return hw;
  }
}
