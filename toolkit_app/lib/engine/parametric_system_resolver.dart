import '../data/catalog_definitions.dart';
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

    for (int i = 0; i < sizeRows.length; i++) {
      final row = sizeRows[i];
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
            brandOverride: c.brandOverride,
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

    // Aggregate hardware across sizeRows (with exact HYDA HD-641 height step scaling)
    final aggregatedHw = _aggregateHardware(
      table.hardware,
      sizeRows,
      pattern,
    );

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
      if (pattern.baseFormulaKey.startsWith('alu_ext:iq:door:')) {
        final rawWf = aux > 0 ? aux : (w * 0.62);
        vars['W_f'] = rawWf.clamp(300.0, (w - 200.0).clamp(300.0, w));
      } else {
        vars['W_f'] = aux > 0 ? aux : (w * 0.35);
      }
    } else if (pattern.auxType == AuxDimensionType.secondWidthW2) {
      vars['W1'] = w;
      vars['W2'] = aux > 0 ? aux : w;
    }

    return vars;
  }

  static List<AggregatedHardwareItem> _aggregateHardware(
    List<HardwareItemSpec> perSetSpecs,
    List<SizeRowInput> sizeRows,
    PatternCardDef pattern,
  ) {
    final out = <AggregatedHardwareItem>[];
    final rows = sizeRows.isNotEmpty
        ? sizeRows
        : const [SizeRowInput(widthMm: 2000, heightMm: 2100, qty: 1)];
    int totalSets = 0;
    for (final r in rows) {
      totalSets += r.qty;
    }
    final mult = totalSets > 0 ? totalSets : 1;
    final isHydaHeightScaled = pattern.foldingFamily == 'orm90' ||
        pattern.foldingFamily == 'orm101' ||
        pattern.foldingFamily == 'sp_fold' ||
        pattern.foldingFamily == 'alu_fold' ||
        pattern.baseFormulaKey.startsWith('c4_orm') ||
        pattern.baseFormulaKey.startsWith('c4_sp_') ||
        pattern.baseFormulaKey.startsWith('c4_alu_');

    for (final h in perSetSpecs) {
      final qt = h.qtyText.trim();
      if (qt.startsWith('AREA_SQM')) {
        final unit = qt.substring('AREA_SQM'.length).trim();
        final resolvedUnit = unit.isEmpty ? 'ตร.ม.' : unit;
        final hasTransomH1 =
            pattern.auxType == AuxDimensionType.refHeightH1 ||
                pattern.auxType == AuxDimensionType.transomHeightHt ||
                pattern.tableMode == InputTableMode.smartPlus90FourCol ||
                pattern.id.contains('_top_') ||
                pattern.id.contains('_bot_');
        double areaSum = 0.0;
        for (final r in rows) {
          final vars = _buildVariables(pattern, r, null);
          final effW = pattern.tableMode == InputTableMode.cornerW1W2
              ? ((vars['W1'] ?? r.widthMm) + (vars['W2'] ?? 0.0))
              : r.widthMm;
          final effH = hasTransomH1 ? (vars['H1'] ?? r.heightMm) : r.heightMm;
          areaSum += ((effW * effH) / 1000000.0) * (r.qty > 0 ? r.qty : 1);
        }
        final roundedArea = ((areaSum * 100.0).round() / 100.0);
        out.add(
          AggregatedHardwareItem(
            code: h.code,
            name: h.name,
            decimalQty: roundedArea > 0 ? roundedArea : 0.01,
            unitOrNote: resolvedUnit,
          ),
        );
        continue;
      }

      final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(qt);
      if (m != null) {
        final baseN = int.parse(m.group(1)!);
        final unit = m.group(2)!.trim().isEmpty ? 'ชิ้น' : m.group(2)!.trim();
        int sumQty = 0;
        if (isHydaHeightScaled &&
            (h.code == 'HD-641' || h.code == 'AKL-SMBF003')) {
          final axes = pattern.foldingTotalPanels ??
              (baseN == 4 ? 2 : (baseN >= 9 ? (baseN ~/ 3) : 2));
          for (final r in rows) {
            final extraPerAxis = r.heightMm >= 2200
                ? (((r.heightMm.floor() - 2200) ~/ 500) + 1)
                : 0;
            sumQty += (baseN + axes * extraPerAxis) * (r.qty > 0 ? r.qty : 1);
          }
        } else {
          sumQty = baseN * mult;
        }
        out.add(
          AggregatedHardwareItem(
            code: h.code,
            name: h.name,
            numericQty: sumQty,
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
    bool ignoreUserOverride = false,
  }) {
    if (!ignoreUserOverride) {
      final userOverride = seed.getFormulaOverride(pattern.id);
      if (userOverride != null) {
        return userOverride.formulaTable;
      }
    }

    // 1. Category 4 Parametric Folding Family (136 active cards)
    if (pattern.foldingFamily != null) {
      final foldTable = _resolveFoldingTable(pattern, selectedOptions, seed);
      final foldCuts = foldTable.cuts.map((c) => c.copyWith()).toList();
      final foldHw = List<HardwareItemSpec>.from(foldTable.hardware);
      _applyUniversalMosquitoModifier(
        pattern: pattern,
        opts: selectedOptions,
        cuts: foldCuts,
        hardware: foldHw,
      );
      return VerifiedFormulaTable(
        key: foldTable.key,
        header: foldTable.header,
        cuts: foldCuts,
        glasses: foldTable.glasses,
        hardware: foldHw,
      );
    }

    // 1B. Category 5 Shower (4 patterns) & Frameless Door (25 patterns) — VVP / RP
    if (pattern.baseFormulaKey.startsWith('c5_shw:')) {
      return _resolveShowerTable(pattern, selectedOptions);
    }
    if (pattern.baseFormulaKey.startsWith('c5_fl:')) {
      return _resolveFramelessDoorTable(pattern, selectedOptions);
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

    final base = key.startsWith('alu_ext:')
        ? _resolveAlumetExtendedTable(key, pattern.title)
        : (key.startsWith('smx_hang:')
            ? _resolveSmartXHangingTable(key, pattern.title, selectedOptions)
            : seed.getFormulaTable(key));
    if (base == null) {
      throw StateError('Formula table not found for key: $key (${pattern.id})');
    }

    var cuts = base.cuts.map((c) => c.copyWith()).toList();
    var glasses = List<GlassPieceSpec>.from(base.glasses);
    var hardware = List<HardwareItemSpec>.from(base.hardware);
    if (key.startsWith('c4_sch_') && hardware.isEmpty) {
      hardware = _buildSchimmer240Hardware(key);
    }

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
    } else if (pattern.id.startsWith('c2_nex_s')) {
      _applyCat2AlumetNexSlidingModifiers(
        patternId: pattern.id,
        opts: selectedOptions,
        cuts: cuts,
        hardware: hardware,
      );
    } else if (pattern.id.startsWith('c2_nex_win')) {
      _applyCat2AlumetNexCasementModifiers(
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

    _applyUniversalMosquitoModifier(
      pattern: pattern,
      opts: selectedOptions,
      cuts: cuts,
      hardware: hardware,
    );

    return VerifiedFormulaTable(
      key: base.key,
      header: base.header,
      cuts: cuts,
      glasses: glasses,
      hardware: hardware,
    );
  }

  /// Universal 3-Type Mosquito Screen Modifier applied to every operable pattern
  /// across all categories (EXCEPT pure fixed windows & shower systems).
  /// When `mosquito` is unset or `'none'` / `'false'`, this is a strict no-op,
  /// guaranteeing 0 regressions on all 194 verified factory formula tables.
  static void _applyUniversalMosquitoModifier({
    required PatternCardDef pattern,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final raw = (opts['mosquito'] ?? 'none').trim();
    if (raw.isEmpty || raw == 'none' || raw == 'false') return;
    if (CatalogDefinitions.isFixedOnlyPattern(pattern)) return;

    final pid = pattern.id.toLowerCase();
    final title = pattern.title.toLowerCase();
    final hasTransomH1 =
        pattern.auxType == AuxDimensionType.refHeightH1 ||
            pattern.auxType == AuxDimensionType.transomHeightHt ||
            pattern.tableMode == InputTableMode.smartPlus90FourCol ||
            pid.contains('_top_') ||
            pid.contains('_bot_');
    final hVar = hasTransomH1 ? 'H1' : 'H';

    final isFolding = pattern.foldingFamily != null ||
        pid.contains('fold') ||
        pid.startsWith('c4_') ||
        title.contains('เฟี้ยม');
    final isSliding = !isFolding &&
        (pid.contains('_s2') ||
            pid.contains('_s3') ||
            pid.contains('_s4') ||
            pid.contains('_s5') ||
            pid.contains('_s6') ||
            pid.contains('hang') ||
            title.contains('เลื่อน'));
    final isDoubleLeaf = pid.contains('_s4') ||
        pid.contains('_s6') ||
        pid.contains('case2') ||
        pid.contains('win2') ||
        pid.contains('win3') ||
        pid.contains('win7') ||
        pid.contains('awn2') ||
        pid.contains('door2') ||
        pid.contains('sw2') ||
        pid.contains('hang2') ||
        title.contains('คู่') ||
        title.contains('แบ่ง 4') ||
        title.contains('4 บาน') ||
        title.contains('6 บาน') ||
        (pattern.foldingTotalPanels ?? 0) >= 4;
    final is3PanelSliding =
        isSliding && (pid.contains('_s3') || title.contains('3 บาน'));

    final mosqPanels = isDoubleLeaf ? 2 : 1;

    // 1. Pleated Screen (มุ้งจีบ — ชุดสำเร็จรูปคิดตาม ตร.ม. ไม่แยกเส้นตัด)
    if (raw == 'pleated') {
      hardware.add(
        const HardwareItemSpec(
          code: 'MS-PLEATED',
          name: 'ชุดมุ้งจีบสำเร็จรูป (รวมรางและมุ้ง)',
          qtyText: 'AREA_SQM ตร.ม.',
        ),
      );
      return;
    }

    // 2. Security Mesh Screen (มุ้งนิรภัย — กรอบมุ้งนิรภัย + คิ้วตบ + ตาข่ายสแตนเลส + ล็อก)
    if (raw == 'security') {
      final horizFormula = isSliding
          ? (is3PanelSliding
              ? '(W - 50) / 3'
              : (isDoubleLeaf ? '(W - 60) / 2' : '(W - 50) / 2'))
          : (isDoubleLeaf ? '(W - 60) / 2' : 'W - 50');
      final beadHorizFormula = isSliding
          ? (is3PanelSliding
              ? '(W - 110) / 3'
              : (isDoubleLeaf ? '(W - 120) / 2' : '(W - 110) / 2'))
          : (isDoubleLeaf ? '(W - 120) / 2' : 'W - 110');

      cuts.addAll([
        CutPieceSpec(
          section: 'มุ้งนิรภัย',
          code: 'MS-SEC-F',
          name: 'กรอบมุ้งนิรภัยแนวตั้ง',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '45° / 45°',
          formula: '$hVar - 50',
          brandOverride: 'MOSQUITO',
        ),
        CutPieceSpec(
          section: 'มุ้งนิรภัย',
          code: 'MS-SEC-F',
          name: 'กรอบมุ้งนิรภัยแนวนอน',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '45° / 45°',
          formula: horizFormula,
          brandOverride: 'MOSQUITO',
        ),
        CutPieceSpec(
          section: 'มุ้งนิรภัย',
          code: 'MS-SEC-C',
          name: 'คิ้วตบกรอบมุ้งนิรภัยแนวตั้ง',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '90° / 90°',
          formula: '$hVar - 110',
          brandOverride: 'MOSQUITO',
        ),
        CutPieceSpec(
          section: 'มุ้งนิรภัย',
          code: 'MS-SEC-C',
          name: 'คิ้วตบกรอบมุ้งนิรภัยแนวนอน',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '90° / 90°',
          formula: beadHorizFormula,
          brandOverride: 'MOSQUITO',
        ),
      ]);
      hardware.addAll([
        const HardwareItemSpec(
          code: 'MS-MESH-SEC',
          name: 'ตาข่ายสแตนเลสมุ้งนิรภัย (304)',
          qtyText: 'AREA_SQM ตร.ม.',
        ),
        HardwareItemSpec(
          code: 'MS-LOCK-SEC',
          name: 'ชุดมือจับและล็อกมุ้งนิรภัย',
          qtyText: '$mosqPanels ชุด',
        ),
        HardwareItemSpec(
          code: 'MS-ACC-SEC',
          name: 'ลูกล้อ/บานพับมุ้งนิรภัย',
          qtyText: '${4 * mosqPanels} ตัว',
        ),
      ]);
      return;
    }

    // 3. Fiber Mosquito Screen (มุ้งไฟเบอร์: fiber | small_mkt | true)
    if (raw == 'fiber' || raw == 'small_mkt' || raw == 'true') {
      final alreadyHasMosqCuts =
          cuts.any((c) => c.section.contains('มุ้ง') || c.name.contains('มุ้ง'));
      if (!alreadyHasMosqCuts) {
        final horizFormula = isSliding
            ? (is3PanelSliding
                ? '(W - 47) / 3'
                : (isDoubleLeaf ? '(W - 55) / 2' : '(W - 47) / 2'))
            : (isDoubleLeaf ? '(W - 55) / 2' : 'W - 47');
        final barFormula = isSliding
            ? (is3PanelSliding
                ? '(W - 134) / 3'
                : (isDoubleLeaf ? '(W - 142) / 2' : '(W - 134) / 2'))
            : (isDoubleLeaf ? '(W - 142) / 2' : 'W - 134');

        cuts.addAll([
          CutPieceSpec(
            section: 'มุ้งไฟเบอร์',
            code: 'MS-FIBER-F',
            name: 'กรอบมุ้งไฟเบอร์แนวตั้ง (2006)',
            stockMm: 6400,
            qty: 2 * mosqPanels,
            qtyText: '${2 * mosqPanels} ชิ้น',
            angle: '45° / 45°',
            formula: '$hVar - 54',
            brandOverride: 'MOSQUITO',
          ),
          CutPieceSpec(
            section: 'มุ้งไฟเบอร์',
            code: 'MS-FIBER-F',
            name: 'กรอบมุ้งไฟเบอร์แนวนอน (2006)',
            stockMm: 6400,
            qty: 2 * mosqPanels,
            qtyText: '${2 * mosqPanels} ชิ้น',
            angle: '45° / 45°',
            formula: horizFormula,
            brandOverride: 'MOSQUITO',
          ),
          CutPieceSpec(
            section: 'มุ้งไฟเบอร์',
            code: 'MS-FIBER-B',
            name: 'เส้นคาดกลางมุ้งไฟเบอร์ (2005)',
            stockMm: 6400,
            qty: mosqPanels,
            qtyText: '$mosqPanels ชิ้น',
            angle: '90° / 90°',
            formula: barFormula,
            brandOverride: 'MOSQUITO',
          ),
        ]);
      }

      // Add fiber mesh & accessories only if not already provided by native NEX/Fuji/SmartX table
      final alreadyHasMosqHw = hardware.any((h) => h.name.contains('มุ้ง'));
      if (!alreadyHasMosqHw) {
        hardware.addAll([
          const HardwareItemSpec(
            code: 'MS-MESH-FIBER',
            name: 'ผ้ามุ้งไฟเบอร์ + ยางอัดมุ้ง',
            qtyText: 'AREA_SQM ตร.ม.',
          ),
          HardwareItemSpec(
            code: 'MS-CORNER-F',
            name: 'มุมมุ้งพลาสติก',
            qtyText: '${4 * mosqPanels} ตัว',
          ),
          HardwareItemSpec(
            code: 'MS-ACC-F',
            name: 'ลูกล้อ/บานพับมุ้งไฟเบอร์',
            qtyText: '${2 * mosqPanels} ตัว',
          ),
        ]);
      }
    }
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
              section: 'เฟรมและวงกบ',
              code: 'เฟรมบนไม่ติดกล่อง',
              name: 'เฟรมบนไม่ติดกล่อง',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 13'),
          CutPieceSpec(
              section: 'เฟรมและวงกบ',
              code: 'เฟรมล่างไม่ติดกล่อง',
              name: 'เฟรมล่างไม่ติดกล่อง',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 13'),
          CutPieceSpec(
              section: 'เฟรมและวงกบ',
              code: 'เฟรมข้างไม่ติดกล่อง',
              name: 'เฟรมข้างไม่ติดกล่อง',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H'),
          CutPieceSpec(
              section: 'เฟรมและวงกบ',
              code: 'เสากุญแจ',
              name: 'เสากุญแจ',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H - 20'),
          CutPieceSpec(
              section: 'เฟรมและวงกบ',
              code: 'เสาเกี่ยว',
              name: 'เสาเกี่ยว',
              stockMm: 6400,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: 'H - 20'),
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
    } else if (patternId == 'c1_pat_s2_alt' &&
        frameMode == 'box_frame' &&
        usageType != 'window') {
      // Doors / Exterior doors on box_frame use plain floor sill between box jambs (H - 50 instead of H - 90)
      for (int i = 0; i < cuts.length; i++) {
        if (cuts[i].code == 'เฟรมล่างติดกล่อง') {
          cuts[i] = cuts[i].copyWith(
            code: 'เฟรมล่างไม่ติดกล่อง',
            name: 'เฟรมล่างไม่ติดกล่อง',
          );
        } else if (cuts[i].code == 'เสากุญแจ' || cuts[i].code == 'เสาเกี่ยว') {
          cuts[i] = cuts[i].copyWith(formula: 'H - 50');
        }
      }
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
              code: 'กล่องเรียบแนวขวางบน',
              name: 'กล่องเรียบแนวขวางบน',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 90'),
          const CutPieceSpec(
              section: 'วงกบกล่องเรียบ',
              code: 'กล่องเรียบแนวขวางล่าง',
              name: 'กล่องเรียบแนวขวางล่าง',
              stockMm: 6400,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90°',
              formula: 'W - 90'),
          const CutPieceSpec(
              section: 'อุปกรณ์เสริม',
              code: 'ฉากข้อต่อ',
              name: 'ฉากข้อต่อ',
              stockMm: 0,
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
            final d = double.parse(f.substring(4)) + 91;
            f = 'H - ${FormulaEvaluator.formatMm(d)}';
          } else if (f.startsWith('W - ')) {
            final d = double.parse(f.substring(4)) + 90;
            f = 'W - ${FormulaEvaluator.formatMm(d)}';
          } else if (f.contains('/ 2') || f.contains('/ 4')) {
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
          final keepPlainSill =
              usageType != 'window' && c.code == 'เฟรมล่างไม่ติดกล่อง';
          String nm = keepPlainSill
              ? c.name
              : c.name.replaceAll('ไม่ติดกล่อง', 'ติดกล่อง');
          String cd = keepPlainSill
              ? c.code
              : c.code.replaceAll('ไม่ติดกล่อง', 'ติดกล่อง');
          if (f == 'H - 20') {
            f = usageType == 'window' ? 'H - 90' : 'H - 50';
          } else if (f.startsWith('W - ')) {
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
        updated.add(
          const CutPieceSpec(
              section: 'อุปกรณ์เสริม',
              code: 'ฉากข้อต่อ',
              name: 'ฉากข้อต่อ',
              stockMm: 0,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90°',
              formula: '95 (ค่าคงที่)'),
        );
        cuts
          ..clear()
          ..addAll(updated);
      }
    }

    // Exterior door swaps 1 regular lock handle per set for keyed lock handle
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
              name: 'มือจับฝังล็อก+กุญแจ',
              qtyText: '1 ชุด',
            ),
          );
        } else {
          hardware[idx] = const HardwareItemSpec(
            code: '',
            name: 'มือจับฝังล็อก+กุญแจ',
            qtyText: '1 ชุด',
          );
        }
      }
    }

    // Bumper rubber type (round = 2 per 2-panel set; square = 4 per 2-panel set)
    if (bumper == 'square') {
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('ยางกันกระแทก')) {
          final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(hardware[i].qtyText);
          final baseN = m != null ? int.parse(m.group(1)!) : 2;
          final unit = m != null && m.group(2)!.trim().isNotEmpty
              ? m.group(2)!.trim()
              : 'ตัว';
          hardware[i] = HardwareItemSpec(
            code: hardware[i].code,
            name: 'ยางกันกระแทกแบบสี่เหลี่ยม',
            qtyText: '${baseN * 2} $unit',
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

    // Ensure Union glazing bead carries Toolkit's exact estimation formula 2*(W + H - 238) without stock bar packing
    final hasBead = cuts.any((c) => c.name.contains('คิ้ว'));
    if (!hasBead) {
      cuts.add(
        const CutPieceSpec(
          section: 'อลูมิเนียมวัดตัดตามจริง',
          code: 'คิ้วยูเนี่ยน',
          name: 'วัดตามจริง · ความยาวรวมสำหรับสั่งซื้อ (ไม่คำนวณจำนวนเส้น stock)',
          stockMm: 0,
          qty: 4,
          qtyText: '4 ชิ้น',
          angle: 'วัดตามจริง',
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
    final baseStileDedPerPair = isBase75 ? 52 : 0; // 75mm vs 53mm per 2-panel pair
    final targetStileDedPerPair =
        stile == '75' ? 52 : (stile == '65' ? 22 : 0);
    final baseJambDed = isBase75 ? 60 : 40;
    final targetJambDed = jamb == '30' ? 60 : 40;
    final is4Panel = patternId.contains('_s4');
    final railDelta = (targetJambDed - baseJambDed) +
        (is4Panel ? 2 : 1) * (targetStileDedPerPair - baseStileDedPerPair);

    for (int i = 0; i < cuts.length; i++) {
      var c = cuts[i];
      // Sill code
      if (c.code == '801-01' || c.code == '801-02') {
        c = c.copyWith(
          code: sill == 'high' ? '801-02' : '801-01',
          name: 'เฟรมล่าง',
        );
      }
      // Jamb code (20mm = 801-04, 30mm = 801-05)
      if (c.code == '801-04' || c.code == '801-05') {
        c = c.copyWith(code: jamb == '30' ? '801-05' : '801-04');
      }
      // Frame horizontal W - 40 vs W - 60
      if (c.formula == 'W - 40' || c.formula == 'W - 60') {
        c = c.copyWith(formula: 'W - $targetJambDed');
      } else if (c.code == '801-08' && railDelta != 0) {
        c = c.copyWith(
          formula: c.formula.replaceFirstMapped(RegExp(r'W - (\d+)'), (m) {
            final v = int.parse(m.group(1)!) + railDelta;
            return 'W - $v';
          }),
        );
      }
      // Stile profile code (53 -> 801-06/801-09, 65 -> 801-07/801-10, 75 -> 801-27/801-28)
      if (c.code == '801-06' || c.code == '801-07' || c.code == '801-27') {
        final newStile = stile == '75'
            ? '801-27'
            : (stile == '65' ? '801-07' : '801-06');
        c = c.copyWith(code: newStile, name: 'เสากุญแจ/เกี่ยว');
      } else if (c.code == '801-09' || c.code == '801-10' || c.code == '801-28') {
        final newCap = stile == '75'
            ? '801-28'
            : (stile == '65' ? '801-10' : '801-09');
        c = c.copyWith(
          code: newCap,
          name: 'ตบเสาเกี่ยว · บากหลบเฟรมบน/ล่างหลังปรับล้อ',
        );
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
          code: 'HD-626',
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
        if (c.code == 'SS-0138') {
          c = c.copyWith(
              section: 'กรอบบาน 45°', code: 'SS-X219', angle: '45° / 45°');
        } else if (c.code == 'SS-0139') {
          c = c.copyWith(code: 'SS-X216');
        } else if (c.code == 'SS-X217') {
          // 45° miter rail adds +131mm per sash width compared to 90° butt rail
          String newF = c.formula;
          if (newF == '(W - 246) / 2') {
            newF = '(W + 16) / 2';
          } else if (newF == '(W - 436) / 4') {
            newF = '(W + 88) / 4';
          } else if (newF.contains('/ 3')) {
            newF = newF.replaceFirstMapped(RegExp(r'W - (\d+)'), (m) {
              final next = 393 - int.parse(m.group(1)!);
              return next >= 0 ? 'W + $next' : 'W - ${-next}';
            });
          }
          c = c.copyWith(
            section: 'กรอบบาน 45°',
            code: 'SS-X219',
            angle: '45° / 45°',
            formula: newF,
          );
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

  static void _applyCat2AlumetNexSlidingModifiers({
    required String patternId,
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final series = opts['nex_series'] ?? 'nex200';
    final usage = opts['usage_type'] ?? 'door';
    final roller = opts['roller_type'] ?? 'cartridge';
    final mosq = opts['mosquito'] ?? 'none';
    final hasTopTransom = patternId.contains('_top') ||
        patternId.contains('_arch') ||
        patternId.contains('_tb');
    final hVar = hasTopTransom ? 'H1' : 'H';

    String adjustedRailFormula(String orig) {
      if (series == 'nex100') {
        if (orig == '(W - 168) / 2') return '(W - 154) / 2';
        if (orig == '(W - 180) / 3') return '(W - 166) / 3';
        if (orig == '(W - 280) / 4') return '(W - 256) / 4';
      } else if (usage == 'window') {
        // Window stile PS-0209 (40mm) is 15.5mm narrower than door stile PS-0206 (55.5mm)
        if (orig == '(W - 168) / 2') return '(W - 137) / 2';
        if (orig == '(W - 180) / 3') return '(W - 149) / 3';
        if (orig == '(W - 280) / 4') return '(W - 218) / 4';
      }
      return orig;
    }

    final updatedCuts = <CutPieceSpec>[];
    for (final raw in cuts) {
      var c = raw;

      if (series == 'nex100') {
        // NEX 100 omits PS-0111 & SS-X206 and uses standard market stiles 4011 / 4012
        if (c.code == 'PS-0111' || c.code == 'SS-X206') continue;
        if (c.code == 'PS-0206') {
          c = c.copyWith(code: '4011', name: 'เสากุญแจ ชุดมาตรฐาน (เน็กซ์ 100)');
        } else if (c.code == 'PS-0208') {
          c = c.copyWith(code: '4012', name: 'เสาเกี่ยว ชุดมาตรฐาน (เน็กซ์ 100)');
        }
      } else if (usage == 'window' && c.code == 'PS-0206') {
        c = c.copyWith(
          code: 'PS-0209',
          name: 'เสากุญแจหน้าต่างบานเลื่อน เน็กซ์ (40 มม.)',
        );
      }

      if (c.code == 'PS-0207') {
        final nextFormula = adjustedRailFormula(c.formula);
        if (roller == 'market') {
          c = c.copyWith(
            code: 'PS-0210',
            name: c.name.replaceAll('ล้อตลับ', 'ล้อตลาด'),
            formula: nextFormula,
          );
        } else if (nextFormula != c.formula) {
          c = c.copyWith(formula: nextFormula);
        }
      }

      updatedCuts.add(c);
    }

    if (series == 'nex100' && patternId.contains('_s4')) {
      updatedCuts.add(
        CutPieceSpec(
          section: 'กรอบบานเลื่อน',
          code: '4016',
          name: 'ประกบกลาง ชุดมาตรฐาน (เน็กซ์ 100)',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: '$hVar - 47',
        ),
      );
    }

    if (mosq == 'fiber') {
      final is4Panel = patternId.contains('_s4');
      final is3Panel = patternId.contains('_s3');
      final mosqPanels = is4Panel ? 2 : 1;
      final horizFormula = is3Panel
          ? '(W - 47) / 3'
          : (is4Panel ? '(W - 55) / 2' : '(W - 47) / 2');
      final barFormula = is3Panel
          ? '(W - 134) / 3'
          : (is4Panel ? '(W - 142) / 2' : '(W - 134) / 2');
      updatedCuts.addAll([
        CutPieceSpec(
          section: 'มุ้งไฟเบอร์ (รางใน)',
          code: '2006',
          name: 'กรอบมุ้งแนวตั้ง (2006)',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '45° / 45°',
          formula: '$hVar - 54',
        ),
        CutPieceSpec(
          section: 'มุ้งไฟเบอร์ (รางใน)',
          code: '2006',
          name: 'กรอบมุ้งแนวนอน (2006)',
          stockMm: 6400,
          qty: 2 * mosqPanels,
          qtyText: '${2 * mosqPanels} ชิ้น',
          angle: '45° / 45°',
          formula: horizFormula,
        ),
        CutPieceSpec(
          section: 'มุ้งไฟเบอร์ (รางใน)',
          code: '4017',
          name: 'ชนกลางมุ้ง (4017)',
          stockMm: 6400,
          qty: mosqPanels,
          qtyText: '$mosqPanels ชิ้น',
          angle: '90° / 90°',
          formula: '$hVar - 54',
        ),
        CutPieceSpec(
          section: 'มุ้งไฟเบอร์ (รางใน)',
          code: '2005',
          name: 'เส้นคาดกลางมุ้ง (2005)',
          stockMm: 6400,
          qty: mosqPanels,
          qtyText: '$mosqPanels ชิ้น',
          angle: '90° / 90°',
          formula: barFormula,
        ),
      ]);
      hardware.addAll([
        HardwareItemSpec(
          code: '',
          name: 'ลูกล้อมุ้งไฟเบอร์',
          qtyText: '${4 * mosqPanels} ตัว',
        ),
        HardwareItemSpec(
          code: '',
          name: 'มุมมุ้งพลาสติก',
          qtyText: '${4 * mosqPanels} ตัว',
        ),
      ]);
    }

    cuts
      ..clear()
      ..addAll(updatedCuts);

    if (roller == 'market') {
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('ล้อตลับ')) {
          hardware[i] = HardwareItemSpec(
            code: '',
            name: 'ล้อตลาดบานเลื่อน NEX',
            qtyText: hardware[i].qtyText,
          );
        }
      }
    }
  }

  static void _applyCat2AlumetNexCasementModifiers({
    required Map<String, String> opts,
    required List<CutPieceSpec> cuts,
    required List<HardwareItemSpec> hardware,
  }) {
    final lockSys = opts['lock_system'] ?? 'nex200';
    final openMode = opts['open_mode'] ?? 'awning';

    if (lockSys == 'nex100') {
      for (int i = 0; i < cuts.length; i++) {
        var c = cuts[i];
        if (c.code == 'PC-0104' || c.code == 'PC-0105') {
          final nextFormula = c.formula == 'W - 50' ? 'W - 50.8' : c.formula;
          c = c.copyWith(
            code: '030065',
            name: c.name
                .replaceAll('บานกระทุ้ง มัลติพอยท์ เน็กซ์', 'กล่องก้าน 1 นิ้ว เน็กซ์ 100')
                .replaceAll('มัลติพอยท์ เน็กซ์', 'กล่องก้าน 1 นิ้ว เน็กซ์ 100'),
            formula: nextFormula,
          );
        } else if (c.code == 'PC-0204') {
          c = c.copyWith(
            code: 'PC-0203',
            name: c.name.replaceAll('มัลติพอยท์', 'ซิงเกิลล็อก'),
          );
        }
        cuts[i] = c;
      }

      // Replace multi-point lock gear with single-lock handle
      hardware.removeWhere(
        (h) => h.name.contains('เกียร์') || h.name.contains('ปุ่มล็อก'),
      );
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('มือจับ')) {
          hardware[i] = HardwareItemSpec(
            code: '',
            name: 'มือจับกระทุ้งซิงเกิลล็อก',
            qtyText: hardware[i].qtyText,
          );
        }
      }
    }

    if (openMode == 'casement') {
      for (int i = 0; i < hardware.length; i++) {
        if (hardware[i].name.contains('บานพับกระทุ้ง')) {
          hardware[i] = HardwareItemSpec(
            code: '',
            name: 'บานพับบานเปิด',
            qtyText: hardware[i].qtyText,
          );
        }
      }
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

    if (mosq && trackMode == '2t') {
      // Only 2-track adds auxiliary mosquito sash; 3-track c3_fuji_s2_mosq keeps standard 9 profiles
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
    final headCode = is101 ? '805-12' : '805-01';
    final jambCode = is101 ? '805-13' : '805-02';
    final sillCode = is101 ? '805-14' : '805-03';
    const sillName = 'เฟรมล่าง';

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
      final hw = swept.hardware.isNotEmpty
          ? List<HardwareItemSpec>.from(swept.hardware)
          : _buildHydaFoldingHardware(n, l, r);
      final hasOddLeaf = (l % 2 == 1) || (r % 2 == 1);
      final hasTwoOddLeaves = (l % 2 == 1) && (r % 2 == 1);
      if (hasOddLeaf && !hw.any((h) => h.name.contains('เสื้อกุญแจ'))) {
        hw.addAll([
          const HardwareItemSpec(
            code: '',
            name: 'เสื้อกุญแจ 35×85 + ไส้กุญแจ',
            qtyText: '1 ชุด',
          ),
          const HardwareItemSpec(
            code: '',
            name: 'มือจับเขาควายมีรูกุญแจ',
            qtyText: '1 คู่',
          ),
          if (hasTwoOddLeaves)
            const HardwareItemSpec(
              code: '',
              name: 'มือจับเขาควายดัมมี่',
              qtyText: '1 คู่',
            ),
        ]);
      }
      return VerifiedFormulaTable(
        key: exactKey,
        header: 'ORM Euro Folding | บานเฟี้ยม $n-$l-$r',
        cuts: adaptedCuts,
        glasses: List<GlassPieceSpec>.from(swept.glasses),
        hardware: hw,
      );
    }

    // Closed-form exact ORM Euro Folding formula for un-swept (n, l, r)
    final isEvenEven = l > 0 && r > 0 && (l % 2 == 0) && (r % 2 == 0);
    final hasOddLeaf = (l % 2 == 1) || (r % 2 == 1);
    final sashDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 8.0 * n);
    final beadDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 168.0 * n);
    final glassDed = FormulaEvaluator.formatMm(
        (isEvenEven ? 80.0 : 52.0) + 138.0 * n);

    final cGrooveQty = ((l ~/ 2) + (r ~/ 2)) > 0 ? ((l ~/ 2) + (r ~/ 2)) : 1;

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
      if (isEvenEven)
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '805-11',
            name: 'โปรไฟล์ปิดชนกลาง',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 85')
      else if (hasOddLeaf)
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '805-06',
            name: 'โปรไฟล์ปิดชนกลาง',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 85'),
      CutPieceSpec(
          section: 'เส้น C-กรุ๊ฟ',
          code: 'เส้น C-กรุ๊ฟ',
          name: 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
          stockMm: 6400,
          qty: cGrooveQty,
          qtyText: '$cGrooveQty ชิ้น',
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
        if (c.code == 'F7973' && c.name.contains('แนวนอน')) {
          return c.copyWith(qty: 1, qtyText: '1 ชิ้น');
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
      if ((l % 2 == 1) || (r % 2 == 1))
        CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: 'F7975',
            name: 'บังใบ',
            stockMm: 6400,
            qty: ((l % 2 == 1) ? 1 : 0) + ((r % 2 == 1) ? 1 : 0),
            qtyText: '${((l % 2 == 1) ? 1 : 0) + ((r % 2 == 1) ? 1 : 0)} ชิ้น',
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

    final pairs = ((l ~/ 2) + (r ~/ 2)) > 0 ? ((l ~/ 2) + (r ~/ 2)) : 1;
    final hasOddLeaf = (l % 2 == 1) || (r % 2 == 1);
    final isSplitMeeting = l > 0 && r > 0;
    final hw = <HardwareItemSpec>[
      HardwareItemSpec(
          code: 'HD-640',
          name: 'HD-640 · บานพับกรอบบน',
          qtyText: '$pairs ชิ้น'),
      HardwareItemSpec(
          code: 'HD-641',
          name: 'HD-641 · บานพับกลาง',
          qtyText: '${2 * n + 3} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-642',
          name: 'HD-642 · บานพับพร้อมมือจับ',
          qtyText: '$pairs ชิ้น'),
      HardwareItemSpec(
          code: 'HD-643',
          name: 'HD-643 · บานพับไกด์ล่าง',
          qtyText: '$pairs ชิ้น'),
      HardwareItemSpec(
          code: 'HD-474',
          name: 'HD-474 · มือจับตอนเลื่อนบาน',
          qtyText: '$pairs ชิ้น'),
      HardwareItemSpec(
          code: 'HD-312',
          name: 'HD-312 · ตัวล็อกกลางบาน',
          qtyText: '$pairs ชิ้น'),
      HardwareItemSpec(
          code: 'HD-1180',
          name: 'HD-1180 · ปลายกลอน',
          qtyText: '${2 * pairs} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-214',
          name: 'HD-214 · ฉากเข้ามุมปรับได้',
          qtyText: '${4 * n} ชิ้น'),
      HardwareItemSpec(
          code: 'HD-200',
          name: 'HD-200 · ฉากประคองบาน',
          qtyText: '${12 * n} ชิ้น'),
      if (hasOddLeaf) ...[
        const HardwareItemSpec(
            code: 'HD-481A',
            name: 'HD-481A · มือจับเขาควาย',
            qtyText: '1 ชิ้น'),
        const HardwareItemSpec(
            code: 'HD-1115',
            name: 'HD-1115 · เสื้อกุญแจ',
            qtyText: '1 ชิ้น'),
        const HardwareItemSpec(
            code: 'HD-851',
            name: 'HD-851 · ไส้กุญแจ',
            qtyText: '1 ชิ้น'),
        const HardwareItemSpec(
            code: 'HD-801',
            name: 'HD-801 · เพลทรับกลอน',
            qtyText: '1 ชิ้น'),
        if (isSplitMeeting)
          const HardwareItemSpec(
              code: 'HD-305',
              name: 'HD-305 · ตัวล็อกเสริมบานเปิดคู่',
              qtyText: '2 ชิ้น'),
      ],
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

    final isSingleDir = l == 0 || r == 0;
    final isEvenEven = l > 0 && r > 0 && (l % 2 == 0) && (r % 2 == 0);
    final isOddOdd = l > 0 && r > 0 && (l % 2 == 1) && (r % 2 == 1);
    final isEvenOdd = l > 0 && r > 0 && !isEvenEven && !isOddOdd;
    final baseDed = isSingleDir
        ? (48.0 + 8.0 * n)
        : (isEvenEven
            ? (80.0 + 10.0 * n)
            : (isOddOdd ? (86.0 + 8.0 * n) : (113.0 + 8.0 * n)));
    final sashDed = FormulaEvaluator.formatMm(baseDed);
    final beadDed = FormulaEvaluator.formatMm(baseDed + 160.0 * n);
    final glassDed = FormulaEvaluator.formatMm(baseDed + 140.0 * n);
    final cGrooveQty = ((l ~/ 2) + (r ~/ 2)) > 0 ? ((l ~/ 2) + (r ~/ 2)) : 1;

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
      if (isEvenEven)
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '15178',
            name: 'แกนกลางเฟี้ยม',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 78')
      else if (isOddOdd)
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '15181',
            name: 'แกนกลางบังใบเฟี้ยม',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 78')
      else if (isEvenOdd) ...[
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '15181',
            name: 'แกนกลางบังใบเฟี้ยม',
            stockMm: 6400,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 78'),
        const CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: '15178',
            name: 'แกนกลางเฟี้ยม',
            stockMm: 6400,
            qty: 1,
            qtyText: '1 ชิ้น',
            angle: '90° / 90°',
            formula: 'H - 78'),
      ],
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
          qty: cGrooveQty,
          qtyText: '$cGrooveQty ชิ้น',
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

    // Exact 3-way vertical deduction from ALUMET Smart X 2026 Shop Drawings (pp. 51–55):
    //   SB-0115 (recessed U, 0 mm):   sash H - 67, bead H - 191, glass H - 201
    //   SB-0116 (interior, 15 mm):    sash H - 82, bead H - 206, glass H - 216
    //   SB-0103 (exterior, 22 mm):    sash H - 89, bead H - 213, glass H - 223
    final targetSashH = sillCode == 'SB-0115'
        ? 'H - 67'
        : (sillCode == 'SB-0103' ? 'H - 89' : 'H - 82');
    final targetBeadH = sillCode == 'SB-0115'
        ? 'H - 191'
        : (sillCode == 'SB-0103' ? 'H - 213' : 'H - 206');
    final targetGlassH = sillCode == 'SB-0115'
        ? 'H - 201'
        : (sillCode == 'SB-0103' ? 'H - 223' : 'H - 216');

    String exactKey = 'c4_alu_$n$l$r';
    if (n == 4 && l == 4 && r == 0) exactKey = 'c4_alu_440_nothresh';
    if (n == 6 && l == 3 && r == 3) exactKey = 'c4_alu_633_nogroove';

    final swept = seed.getFormulaTable(exactKey);
    if (swept != null) {
      final adaptedCuts = swept.cuts.map((c) {
        var next = c.copyWith();
        if (c.code == 'SB-0116' || c.code == 'SB-0103' || c.code == 'SB-0115') {
          next = next.copyWith(code: sillCode, name: sillName);
        }
        if (c.formula == 'H - 191' ||
            c.formula == 'H - 206' ||
            c.formula == 'H - 213') {
          next = next.copyWith(formula: targetBeadH);
        } else if (c.formula == 'H - 67' ||
            c.formula == 'H - 82' ||
            c.formula == 'H - 89') {
          next = next.copyWith(formula: targetSashH);
        }
        return next;
      }).toList();
      final adaptedGlasses = swept.glasses.map((g) {
        var hF = g.hFormula;
        if (hF == 'H - 201' || hF == 'H - 216' || hF == 'H - 223') {
          hF = targetGlassH;
        }
        return GlassPieceSpec(
          name: g.name,
          qty: g.qty,
          qtyText: g.qtyText,
          siteCut: g.siteCut,
          wFormula: g.wFormula,
          hFormula: hF,
        );
      }).toList();
      return VerifiedFormulaTable(
        key: exactKey,
        header: 'ALUMET Smart X Folding | $n-$l-$r',
        cuts: adaptedCuts,
        glasses: adaptedGlasses,
        hardware: _buildAlumetFoldingHardware(n, l, r),
      );
    }

    // Closed-form exact 5-case geometry from ALUMET Smart X 2026 Catalog (p. 57):
    //   Case 1 (single-dir odd,  e.g. 5-5-0):   sashDed = 45.6 + 7.5*N, SB-0113=0, SB-0117=1
    //   Case 2 (single-dir even, e.g. 6-6-0):   sashDed = 96.0 + 7.5*N, SB-0113=1, SB-0117=0
    //   Case 3 (odd + odd,       e.g. 8-7-1):   sashDed = 70.8 + 7.5*N, SB-0113=0, SB-0117=2
    //   Case 4 (even + even,     e.g. 8-4-4):   sashDed = 120.0 + 7.5*N, SB-0113=2, SB-0117=0
    //   Case 5 (even + odd, e.g. 7-5-2, 7-4-3): sashDed = 101.0 + 7.5*N, SB-0113=1, SB-0117=1
    final isSingleDir = l == 0 || r == 0;
    final singleSide = l > 0 ? l : r;
    final double baseSashDed;
    final int sb0113Qty;
    final int sb0117Qty;
    if (isSingleDir) {
      if (singleSide % 2 == 1) {
        baseSashDed = 45.6 + 7.5 * n;
        sb0113Qty = 0;
        sb0117Qty = 1;
      } else {
        baseSashDed = 96.0 + 7.5 * n;
        sb0113Qty = 1;
        sb0117Qty = 0;
      }
    } else if ((l % 2 == 0) && (r % 2 == 0)) {
      baseSashDed = 120.0 + 7.5 * n;
      sb0113Qty = 2;
      sb0117Qty = 0;
    } else if ((l % 2 == 1) && (r % 2 == 1)) {
      baseSashDed = 70.8 + 7.5 * n;
      sb0113Qty = 0;
      sb0117Qty = 2;
    } else {
      baseSashDed = 101.0 + 7.5 * n;
      sb0113Qty = 1;
      sb0117Qty = 1;
    }

    final sashDed = FormulaEvaluator.formatMm(baseSashDed);
    final beadDed = FormulaEvaluator.formatMm(baseSashDed + 164.0 * n);
    final glassDed = FormulaEvaluator.formatMm(baseSashDed + 134.0 * n);
    final cGrooveQty = ((l ~/ 2) + (r ~/ 2)) > 0 ? ((l ~/ 2) + (r ~/ 2)) : 1;

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
          formula: targetBeadH),
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
          formula: targetBeadH),
      CutPieceSpec(
          section: 'คิ้วกระจก',
          code: 'SB-0109',
          name: 'คิ้วภายในแนวนอน',
          stockMm: 6400,
          qty: 2 * n,
          qtyText: '${2 * n} ชิ้น',
          angle: '90° / 90°',
          formula: '(W - $beadDed) / $n'),
      if (sb0113Qty > 0)
        CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: 'SB-0113',
            name: 'เสาบานเปิดคู่บานเฟี้ยม',
            stockMm: 6400,
            qty: sb0113Qty,
            qtyText: '$sb0113Qty ชิ้น',
            angle: '90° / 90°',
            formula: targetSashH),
      if (sb0117Qty > 0)
        CutPieceSpec(
            section: 'เส้นเฉพาะ Layout',
            code: 'SB-0117',
            name: 'เสริมเสาบานเปิดกลาง บานเฟี้ยม',
            stockMm: 6400,
            qty: sb0117Qty,
            qtyText: '$sb0117Qty ชิ้น',
            angle: '90° / 90°',
            formula: targetSashH),
      CutPieceSpec(
          section: 'เส้น C-กรุ๊ฟ',
          code: 'เส้น C-กรุ๊ฟ',
          name: 'เส้น C-กรุ๊ฟ · ชุดล็อกกลางบาน',
          stockMm: 6400,
          qty: cGrooveQty,
          qtyText: '$cGrooveQty ชิ้น',
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
          formula: targetSashH),
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
          hFormula: targetGlassH,
        ),
      ],
      hardware: _buildAlumetFoldingHardware(n, l, r),
    );
  }

  /// Authentic ALUMET Smart X Bi-Folding Hardware (ALUMET Hub 2026 Official Sheets: 3-3-0, 4-3-1, 4-4-0, 5-5-0, 6-3-3, 8-4-4).
  static List<HardwareItemSpec> _buildAlumetFoldingHardware(int n, int l, int r) {
    int countEvenCarriers = 0; // Even-side carriers (AKL-SMBF019 / AKL-SMBF020)
    int countOddCarriers = 0; // Odd-side carriers (AKL-SMBF001 / AKL-SMBF002)
    int oddSidesCount = 0;
    for (final s in [l, r]) {
      if (s <= 0) continue;
      if (s % 2 == 0) {
        countEvenCarriers += s ~/ 2;
      } else {
        oddSidesCount += 1;
        countOddCarriers += s ~/ 2;
      }
    }
    final carrierPairs = (l ~/ 2) + (r ~/ 2);
    final cPairs = carrierPairs > 0 ? carrierPairs : 1;
    final hasOddLeaf = oddSidesCount > 0;
    final hasTwoOddLeaves = oddSidesCount == 2;
    final cdqQty = carrierPairs + oddSidesCount;
    final safeCdq = cdqQty > 0 ? cdqQty : 1;
    final duckHandleQty =
        (carrierPairs + (hasTwoOddLeaves ? 1 : 0)).clamp(1, 99);

    final hw = <HardwareItemSpec>[];
    if (countEvenCarriers > 0) {
      hw.add(HardwareItemSpec(
        code: 'AKL-SMBF019',
        name: 'ล้อบนบานเฟี้ยมคู่ ALUMET',
        qtyText: '$countEvenCarriers ชิ้น',
      ));
    }
    if (countOddCarriers > 0) {
      hw.add(HardwareItemSpec(
        code: 'AKL-SMBF001',
        name: 'บานพับล้อบนบานเฟี้ยม ALUMET',
        qtyText: '$countOddCarriers ชิ้น',
      ));
    }
    if (countEvenCarriers > 0) {
      hw.add(HardwareItemSpec(
        code: 'AKL-SMBF020',
        name: 'ไกด์ล่างบานเฟี้ยมคู่ ALUMET',
        qtyText: '$countEvenCarriers ชิ้น',
      ));
    }
    if (countOddCarriers > 0) {
      hw.add(HardwareItemSpec(
        code: 'AKL-SMBF002',
        name: 'บานพับไกด์ล่างบานเฟี้ยม ALUMET',
        qtyText: '$countOddCarriers ชิ้น',
      ));
    }
    hw.addAll([
      HardwareItemSpec(
        code: 'AKL-SMBF003',
        name: 'บานพับบานเฟี้ยม ALUMET',
        qtyText: '${n == 2 ? 4 : 3 * n} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'AKL-SMBF004',
        name: 'บานพับมือจับบานเฟี้ยม ALUMET',
        qtyText: '$cPairs ชิ้น',
      ),
      HardwareItemSpec(
        code: 'AKL-SMBF005',
        name: 'CDQ 20 สองทาง ALUMET',
        qtyText: '$safeCdq ชิ้น',
      ),
      HardwareItemSpec(
        code: 'AKL-SMBF031',
        name: 'มือจับปากเป็ดบานเฟี้ยม ALUMET',
        qtyText: '$duckHandleQty ชิ้น',
      ),
      HardwareItemSpec(
        code: 'AKL-SMBF030',
        name: 'ปลายกลอนบานเฟี้ยม ALUMET',
        qtyText: '${2 * safeCdq} ชิ้น',
      ),
    ]);
    if (hasOddLeaf) {
      hw.addAll([
        const HardwareItemSpec(
          code: 'AKL-SMBF013',
          name: 'ไส้กุญแจทางเดียว (37/37 มม.) ALUMET',
          qtyText: '1 ชิ้น',
        ),
        const HardwareItemSpec(
          code: 'AKL-SMBF022',
          name: 'เสื้อกุญแจ #32-85 มัลติพ้อยท์ล็อก ALUMET',
          qtyText: '1 ชิ้น',
        ),
        const HardwareItemSpec(
          code: 'AKL-SMBF023',
          name: 'มือจับประตูบานเฟี้ยม ALUMET',
          qtyText: '1 ชุด',
        ),
        if (hasTwoOddLeaves)
          const HardwareItemSpec(
            code: 'AKL-SMBF024',
            name: 'มือจับประตูดัมมี่บานเฟี้ยม ALUMET',
            qtyText: '1 ชุด',
          ),
        const HardwareItemSpec(
          code: 'AKL-SMBF029',
          name: 'เพลทรับกลอนประตูบานเฟี้ยม ALUMET',
          qtyText: '1 ชิ้น',
        ),
      ]);
    }
    hw.add(
      const HardwareItemSpec(
        code: 'AKL-SMBF021',
        name: 'ยางลูกโป่งบานเฟี้ยม (100 เมตร) ALUMET',
        qtyText: '1 ม้วน',
      ),
    );
    return hw;
  }

  /// Completes Schimmer HOMELIFE 240 folding hardware for swept tables with empty HW.
  static List<HardwareItemSpec> _buildSchimmer240Hardware(String key) {
    int l = 2, r = 0;
    if (key == 'c4_sch_3_3l') {
      l = 3;
      r = 0;
    } else if (key == 'c4_sch_4_1l3r') {
      l = 1;
      r = 3;
    } else if (key == 'c4_sch_4_2l2r') {
      l = 2;
      r = 2;
    } else if (key == 'c4_sch_4_4l') {
      l = 4;
      r = 0;
    }
    final carrierSets = (l ~/ 2) + (r ~/ 2);
    final hasOdd = (l % 2 == 1) || (r % 2 == 1);
    final hw = <HardwareItemSpec>[
      if (l > 0)
        const HardwareItemSpec(
          code: '05-006',
          name: 'LEFT HAND PIVOT SET',
          qtyText: '1 ชุด',
        ),
      if (r > 0)
        const HardwareItemSpec(
          code: '05-007',
          name: 'RIGHT HAND PIVOT SET',
          qtyText: '1 ชุด',
        ),
      if (carrierSets > 0)
        HardwareItemSpec(
          code: '05-008',
          name: 'INTERMEDIATE CARRIER SET',
          qtyText: '$carrierSets ชุด',
        ),
      HardwareItemSpec(
        code: '05-004',
        name: 'STANDARD HINGE HANDLE SET',
        qtyText: '${carrierSets > 0 ? carrierSets : 1} ชุด',
      ),
      HardwareItemSpec(
        code: '00-019',
        name: 'MORTISE FLUSH BOLT · OPTION 1',
        qtyText: '${2 * (carrierSets > 0 ? carrierSets : 1)} ชุด',
      ),
      if (hasOdd)
        const HardwareItemSpec(
          code: '00-024',
          name: 'MORTISE LOCK HANDLE SET',
          qtyText: '1 ชุด',
        ),
    ];
    return hw;
  }

  /// ALUMET Pro Smart X Hanging Sliding Door (Single & Double Leaf)
  /// Official Spec: Smart X_Catalogue 2026 pp. 08 & 14 (SS-X116/SS-X113, SS-X114, SS-X115).
  static VerifiedFormulaTable _resolveSmartXHangingTable(
    String key,
    String title,
    Map<String, String> opts,
  ) {
    final isDouble = key == 'smx_hang:double';
    final leaves = isDouble ? 2 : 1;
    final trackCode = opts['track_type'] ?? 'SS-X116';
    final isSideMount = trackCode == 'SS-X116';
    final sashProfile = opts['sash_profile'] ?? '45_12';
    final isSoftClose = (opts['hang_hw'] ?? 'soft_close') == 'soft_close';

    final String vertCode;
    final String vertName;
    final String horizCode;
    final String horizName;
    final String sashAngle;
    switch (sashProfile) {
      case '45_15':
        vertCode = 'SS-X219';
        vertName = 'เสากุญแจเข้ามุม 45° ร่อง 9.5 (1.5 มม.)';
        horizCode = 'SS-X219';
        horizName = 'ขวางบน-ล่าง เข้ามุม 45° (1.5 มม.)';
        sashAngle = '45° / 45°';
        break;
      case '90_12':
        vertCode = 'SS-0138';
        vertName = 'เสากุญแจมัลติพอยท์ ร่อง 9.5 (1.2 มม.)';
        horizCode = 'SS-X217';
        horizName = 'ขวางบน-ล่าง ร่อง 9.5 (1.2 มม.)';
        sashAngle = '90° / 90°';
        break;
      case '90_15':
        vertCode = 'SS-X209';
        vertName = 'เสากุญแจมัลติพอยท์ ร่อง 9.5 (1.5 มม.)';
        horizCode = 'SS-X210';
        horizName = 'ขวางบน-ล่าง ร่อง 9.5 (1.5 มม.)';
        sashAngle = '90° / 90°';
        break;
      case '45_12':
      default:
        vertCode = 'SS-X212';
        vertName = 'เสากุญแจเข้ามุม 45° ร่อง 9.5 (1.2 มม.)';
        horizCode = 'SS-X212';
        horizName = 'ขวางบน-ล่าง เข้ามุม 45° (1.2 มม.)';
        sashAngle = '45° / 45°';
        break;
    }

    // Section A heights from Smart X 2026 p.08:
    //   SS-X116 (wall-mount above opening): floor gap 7 + top roller gap 15 => H - 22
    //   SS-X113 (ceiling/head mount inside opening): track 41.5 + gaps 21.5 => H - 63
    final sashHExpr = isSideMount ? 'H - 22' : 'H - 63';
    final glassHExpr = isSideMount ? 'H - 144' : 'H - 185';
    final sashWExpr = isDouble ? '(W + 24) / 2' : 'W';
    final glassWExpr = isDouble ? '(W - 220) / 2' : 'W - 122';

    final cuts = <CutPieceSpec>[
      CutPieceSpec(
        section: 'ชุดรางแขวนบน',
        code: trackCode,
        name: isSideMount
            ? 'รางแขวนยึดผนังด้านข้าง สมาร์ท เอ็กซ์'
            : 'รางแขวนยึดผนังด้านบน สมาร์ท เอ็กซ์',
        stockMm: 6400,
        qty: 1,
        qtyText: '1 ชิ้น',
        angle: '90° / 90°',
        formula: '2 * W',
      ),
      const CutPieceSpec(
        section: 'ชุดรางแขวนบน',
        code: 'SS-X114',
        name: 'ฝาครอบปิดรางแขวน สมาร์ท เอ็กซ์',
        stockMm: 6400,
        qty: 1,
        qtyText: '1 ชิ้น',
        angle: '90° / 90°',
        formula: '2 * W',
      ),
      CutPieceSpec(
        section: 'ชุดรางแขวนบน',
        code: 'SS-X115',
        name: 'เสริมยึดล้อรางแขวน สมาร์ท เอ็กซ์ (หัวกรอบบาน)',
        stockMm: 6400,
        qty: leaves,
        qtyText: '$leaves ชิ้น',
        angle: '90° / 90°',
        formula: sashWExpr,
      ),
      if (isSideMount)
        const CutPieceSpec(
          section: 'ชุดรางแขวนบน',
          code: 'iS-0209',
          name: 'ฝาปิดสกรูรางแขวนยึดผนังข้าง',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: '2 * W',
        ),
      CutPieceSpec(
        section: 'กรอบบานเลื่อน',
        code: vertCode,
        name: '$vertName (แนวตั้ง)',
        stockMm: 6400,
        qty: 2 * leaves,
        qtyText: '${2 * leaves} ชิ้น',
        angle: sashAngle,
        formula: sashHExpr,
      ),
      CutPieceSpec(
        section: 'กรอบบานเลื่อน',
        code: horizCode,
        name: '$horizName (แนวนอน)',
        stockMm: 6400,
        qty: 2 * leaves,
        qtyText: '${2 * leaves} ชิ้น',
        angle: sashAngle,
        formula: sashWExpr,
      ),
      CutPieceSpec(
        section: 'เสริมกรอบและกันช่องว่าง',
        code: 'SS-X216',
        name: 'ตบเกี่ยว/บังใบปิดช่องว่างข้างบาน',
        stockMm: 6400,
        qty: leaves,
        qtyText: '$leaves ชิ้น',
        angle: '90° / 90°',
        formula: sashHExpr,
      ),
      if (!isDouble) ...[
        CutPieceSpec(
          section: 'เสริมกรอบและกันช่องว่าง',
          code: 'SS-0120',
          name: 'เสริมปีกเฟรมข้างรับบาน',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H',
        ),
        CutPieceSpec(
          section: 'เสริมกรอบและกันช่องว่าง',
          code: 'SS-0117',
          name: 'ฝาปิดเสริมเสากุญแจตัวผู้',
          stockMm: 6400,
          qty: 1,
          qtyText: '1 ชิ้น',
          angle: '90° / 90°',
          formula: 'H',
        ),
      ],
    ];

    final glasses = <GlassPieceSpec>[
      GlassPieceSpec(
        name: isDouble
            ? 'กระจกบานเลื่อนรางแขวนบานคู่ (ร่อง 9.5 มม.)'
            : 'กระจกบานเลื่อนรางแขวนบานเดี่ยว (ร่อง 9.5 มม.)',
        qty: leaves,
        qtyText: '$leaves แผ่น',
        siteCut: false,
        wFormula: glassWExpr,
        hFormula: glassHExpr,
      ),
    ];

    final hardware = <HardwareItemSpec>[
      HardwareItemSpec(
        code: isSoftClose ? 'AKL-MTSL062' : 'SMX-HANG-STD',
        name: isSoftClose
            ? 'ล้อรางแขวน Soft Close (Set) ALUMET'
            : 'ชุดล้อรางแขวน Pro Smart X มาตรฐาน (120 กก.)',
        qtyText: '$leaves ชุด',
      ),
      const HardwareItemSpec(
        code: 'AHD-ICSL050',
        name: 'รับล็อกบานเลื่อน (HD-1127) ALUMET',
        qtyText: '2 ชิ้น',
      ),
      HardwareItemSpec(
        code: 'ATP-MTSL060',
        name: 'สปริกอสบานเลื่อนยูโร สมาร์ท เอ็กซ์ 9.8×22 มม.',
        qtyText: '${4 * leaves} ชิ้น',
      ),
      const HardwareItemSpec(
        code: 'ACF-MTSL041',
        name: 'ตัว T มัลติพ้อยท์ล็อก (ยาว 23 มม.) สีดำ',
        qtyText: '1 ชิ้น',
      ),
      const HardwareItemSpec(
        code: 'AAL-MTSL024',
        name: 'ตะขอล็อกบานเลื่อน ALUMET',
        qtyText: '2 ชิ้น',
      ),
      const HardwareItemSpec(
        code: 'AKL-MTSL026',
        name: 'มือจับฝังล็อก+ดัมมี่ ALUMET',
        qtyText: '1 ชิ้น',
      ),
      if (isDouble)
        const HardwareItemSpec(
          code: 'AKL-MTSL027',
          name: 'มือจับฝังดัมมี่ ALUMET',
          qtyText: '2 ชิ้น',
        ),
      const HardwareItemSpec(
        code: 'AAL-EUCA034',
        name: 'ฉากสแตนเลส 6.6 มม.',
        qtyText: '1 แพค',
      ),
      HardwareItemSpec(
        code: 'AAL-MTSL002',
        name: 'ยางกันชนบานเลื่อน ALUMET',
        qtyText: '${2 * leaves} ชิ้น',
      ),
      const HardwareItemSpec(
        code: 'AKL-MTSL036',
        name: 'สักหลาด 6×4 มม. (300 เมตร)',
        qtyText: 'ตามหน้างาน',
      ),
    ];

    return VerifiedFormulaTable(
      key: key,
      header: 'ALUMET Pro Smart X | $title',
      cuts: cuts,
      glasses: glasses,
      hardware: hardware,
    );
  }

  /// Category 5: Shower Enclosures (4 official patterns × VVP & RP Steel Glass)
  /// Default uses 0 aluminum bars (pure glass + hardware fittings); optional U-channel adds U-12 cuts.
  static VerifiedFormulaTable _resolveShowerTable(
    PatternCardDef pattern,
    Map<String, String> opts,
  ) {
    final parts = pattern.baseFormulaKey.split(':'); // c5_shw:<BRAND>:<NUM2>
    final brandKey = parts.length > 1 ? parts[1] : 'VVP';
    final num2 = parts.length > 2 ? parts[2] : '01';
    final isRp = brandKey == 'RP';
    final finish = opts['shower_finish'] ?? 'ss'; // ss | black | gold
    final useStabilizer = (opts['stabilizer_bar'] ?? 'yes') == 'yes';
    final useUChannel = (opts['u_channel'] ?? 'clamps') == 'u_alu';

    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hardware = <HardwareItemSpec>[];

    // Helper for RP finish suffix
    String rpFinishCode(String base) {
      if (!isRp) return base;
      if (finish == 'black') return '${base}B';
      if (finish == 'gold') return '${base}G';
      return base;
    }

    int fixedPanels = 0;
    int clampCount = 0;
    bool hasDoor = true;
    bool doorGlassToGlass = false;

    switch (num2) {
      case '01': // F + D + F (3 sections)
        fixedPanels = 2;
        clampCount = 8;
        doorGlassToGlass = true;
        glasses.addAll(const [
          GlassPieceSpec(
            name: 'กระจกบานเปิดกลาง (เทมเปอร์)',
            qty: 1,
            qtyText: '1 แผ่น',
            siteCut: false,
            wFormula: 'W / 3 - 8',
            hFormula: 'H - 12',
          ),
          GlassPieceSpec(
            name: 'กระจกบานติดตายซ้าย-ขวา (เทมเปอร์)',
            qty: 2,
            qtyText: '2 แผ่น',
            siteCut: false,
            wFormula: 'W / 3 - 4',
            hFormula: 'H - 4',
          ),
        ]);
        if (useUChannel) {
          cuts.addAll(const [
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดกระจกติดตาย (แนวตั้งผนัง)',
              stockMm: 6000,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90° / 90°',
              formula: 'H',
            ),
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดกระจกติดตาย (แนวนอนพื้น)',
              stockMm: 6000,
              qty: 2,
              qtyText: '2 ชิ้น',
              angle: '90° / 90°',
              formula: 'W / 3',
            ),
          ]);
        }
        break;
      case '02': // Walk-in single fixed panel
        hasDoor = false;
        fixedPanels = 1;
        clampCount = 5;
        glasses.add(
          const GlassPieceSpec(
            name: 'กระจกติดตายกั้นอาบน้ำ Walk-in (เทมเปอร์)',
            qty: 1,
            qtyText: '1 แผ่น',
            siteCut: false,
            wFormula: 'W - 4',
            hFormula: 'H - 4',
          ),
        );
        if (useUChannel) {
          cuts.addAll(const [
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดผนัง (แนวตั้ง)',
              stockMm: 6000,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90° / 90°',
              formula: 'H',
            ),
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดพื้น (แนวนอน)',
              stockMm: 6000,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90° / 90°',
              formula: 'W',
            ),
          ]);
        }
        break;
      case '03': // D + F (2 sections)
        fixedPanels = 1;
        clampCount = 4;
        doorGlassToGlass = false;
        glasses.addAll(const [
          GlassPieceSpec(
            name: 'กระจกบานเปิดห้องอาบน้ำ (เทมเปอร์)',
            qty: 1,
            qtyText: '1 แผ่น',
            siteCut: false,
            wFormula: 'W / 2 - 8',
            hFormula: 'H - 12',
          ),
          GlassPieceSpec(
            name: 'กระจกบานติดตายข้าง (เทมเปอร์)',
            qty: 1,
            qtyText: '1 แผ่น',
            siteCut: false,
            wFormula: 'W / 2 - 4',
            hFormula: 'H - 4',
          ),
        ]);
        if (useUChannel) {
          cuts.addAll(const [
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดผนังบานติดตาย (แนวตั้ง)',
              stockMm: 6000,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90° / 90°',
              formula: 'H',
            ),
            CutPieceSpec(
              section: 'รางอลูมิเนียมตัวยู (เสริม)',
              code: 'U-12',
              name: 'รางตัวยูยึดพื้นบานติดตาย (แนวนอน)',
              stockMm: 6000,
              qty: 1,
              qtyText: '1 ชิ้น',
              angle: '90° / 90°',
              formula: 'W / 2',
            ),
          ]);
        }
        break;
      case '04': // Single swing shower door in wall opening
      default:
        fixedPanels = 0;
        clampCount = 0;
        doorGlassToGlass = false;
        glasses.add(
          const GlassPieceSpec(
            name: 'กระจกประตูห้องอาบน้ำบานเปิดเดี่ยว (เทมเปอร์)',
            qty: 1,
            qtyText: '1 แผ่น',
            siteCut: false,
            wFormula: 'W - 10',
            hFormula: 'H - 12',
          ),
        );
        break;
    }

    // Authentic VVP / RP Steel Glass Shower Hardware
    if (hasDoor) {
      if (isRp) {
        final hingeCode = doorGlassToGlass
            ? rpFinishCode('RP-304')
            : rpFinishCode('RP-303');
        final hingeName = doorGlassToGlass
            ? 'บานพับกระจกยึดกระจก 180° $hingeCode'
            : 'บานพับยึดผนัง-กระจก $hingeCode';
        hardware.add(
          HardwareItemSpec(code: hingeCode, name: hingeName, qtyText: '2 ชิ้น'),
        );
        final handleCode = finish == 'black'
            ? 'RPS-502B'
            : (finish == 'gold' ? 'RPS-503G' : 'RPS-501');
        hardware.add(
          HardwareItemSpec(
            code: handleCode,
            name: 'มือจับแขวนผ้าประตูห้องน้ำ RP ($handleCode)',
            qtyText: '1 ชุด',
          ),
        );
        hardware.addAll(const [
          HardwareItemSpec(
            code: 'SS-01',
            name: 'ยางกันน้ำขอบประตู (เส้นตรง) SS-01',
            qtyText: '1 เส้น',
          ),
          HardwareItemSpec(
            code: 'SS-07',
            name: 'ยางกันน้ำล่างประตู (กวาดพื้น) SS-07',
            qtyText: '1 เส้น',
          ),
          HardwareItemSpec(
            code: 'SS-50',
            name: 'แถบยางแม่เหล็กกันน้ำ 180° SS-50',
            qtyText: '1 คู่',
          ),
        ]);
      } else {
        final hingeCode = doorGlassToGlass ? 'SW 304' : 'SW 303';
        final hingeName = doorGlassToGlass
            ? 'บานพับชาวเวอร์คู่ กระจก-กระจก 180° VVP SW 304'
            : 'บานพับชาวเวอร์เดี่ยว ผนัง-กระจก VVP SW 303';
        hardware.addAll([
          HardwareItemSpec(code: hingeCode, name: hingeName, qtyText: '2 ชิ้น'),
          const HardwareItemSpec(
            code: 'SK-1',
            name: 'ปุ่มจับประตูห้องน้ำสเตนเลส VVP SK-1',
            qtyText: '1 ชิ้น',
          ),
          const HardwareItemSpec(
            code: 'VVP-SEAL',
            name: 'คิ้วกันน้ำ / ยางแม่เหล็กห้องน้ำ VVP (2.2 ม.)',
            qtyText: '2 เส้น',
          ),
        ]);
      }
    }

    if (clampCount > 0 && !useUChannel) {
      hardware.add(
        HardwareItemSpec(
          code: isRp ? 'BL-201' : 'GC-502',
          name: isRp
              ? 'ตัวหนีบกระจกผนัง-กระจก RP BL-201'
              : 'ตัวหนีบกระจกห้องน้ำ ผนัง-กระจก VVP GC-502',
          qtyText: '$clampCount ชิ้น',
        ),
      );
    }

    if (useStabilizer && fixedPanels > 0) {
      if (isRp) {
        final wallBracket = finish == 'black'
            ? 'BL-900B'
            : (finish == 'gold' ? 'BL-900G' : 'BL-101');
        hardware.addAll([
          HardwareItemSpec(
            code: wallBracket,
            name: 'ร้อยท่อยึดผนัง RP $wallBracket (แป๊ป 19 มม.)',
            qtyText: '${fixedPanels >= 2 ? 2 : 1} ชิ้น',
          ),
          HardwareItemSpec(
            code: 'BL-102',
            name: 'ร้อยท่อจับกระจกสเตนเลส RP BL-102',
            qtyText: '$fixedPanels ชิ้น',
          ),
          const HardwareItemSpec(
            code: 'BL-02',
            name: 'แป๊ปกลมสเตนเลสกันแกว่ง 19 มม. RP BL-02',
            qtyText: '1 เส้น',
          ),
        ]);
      } else {
        hardware.addAll([
          HardwareItemSpec(
            code: 'SB 900',
            name: 'ตัวยึดท่อกันแกว่งผนังทรงกลม VVP SB 900',
            qtyText: '${fixedPanels >= 2 ? 2 : 1} ชิ้น',
          ),
          HardwareItemSpec(
            code: 'SB 902',
            name: 'ตัวยึดท่อกันแกว่งจับกระจก VVP SB 902',
            qtyText: '$fixedPanels ชิ้น',
          ),
        ]);
      }
    }

    return VerifiedFormulaTable(
      key: pattern.baseFormulaKey,
      header: '${isRp ? 'RP Steel Glass' : 'VVP'} | ${pattern.title}',
      cuts: cuts,
      glasses: glasses,
      hardware: hardware,
    );
  }

  /// Category 5: Frameless Glass Doors & Partitions (All 25 official customer album patterns)
  static VerifiedFormulaTable _resolveFramelessDoorTable(
    PatternCardDef pattern,
    Map<String, String> opts,
  ) {
    final parts = pattern.baseFormulaKey.split(':'); // c5_fl:<BRAND>:<NUM2>
    final brandKey = parts.length > 1 ? parts[1] : 'VVP';
    final num2 = parts.length > 2 ? parts[2] : '17';
    final isRp = brandKey == 'RP';
    final closerModel = opts['frameless_closer'] ?? 'FC 34';
    final isOverheadCloser = closerModel == 'OC 35';
    final useUChannel = (opts['u_channel'] ?? 'clamps') == 'u_alu';

    // Exact topology specification for all 25 album patterns
    int doors = 1;
    int fixedPanels = 0;
    int totalCols = 1;
    bool hasTransom = false;
    int ft30Qty = 0;
    int ft40Qty = 0;
    int ft41Qty = 0;
    int ft42Qty = 0;
    int extraClamps = 0;

    switch (num2) {
      case '01': // 2F + D/Top (3 cols)
        doors = 1; fixedPanels = 2; totalCols = 3; hasTransom = true; ft30Qty = 1; ft40Qty = 1; break;
      case '02': // DD + Top
        doors = 2; fixedPanels = 0; totalCols = 2; hasTransom = true; ft30Qty = 2; break;
      case '03': // DD
      case '04': // DD alt
        doors = 2; fixedPanels = 0; totalCols = 2; break;
      case '05': // F + D/Top + F (FT40 + FT42)
        doors = 1; fixedPanels = 2; totalCols = 3; hasTransom = true; ft40Qty = 1; ft42Qty = 1; break;
      case '06': // F + D/Top + F (FT41 fin + FT42)
        doors = 1; fixedPanels = 2; totalCols = 3; hasTransom = true; ft41Qty = 1; ft42Qty = 1; break;
      case '07': // F + D + F
      case '09': // F + D + F right
        doors = 1; fixedPanels = 2; totalCols = 3; break;
      case '08': // F + D + F with side clamps
        doors = 1; fixedPanels = 2; totalCols = 3; extraClamps = 4; break;
      case '10': // D/Top + F (FT40)
        doors = 1; fixedPanels = 1; totalCols = 2; hasTransom = true; ft40Qty = 1; break;
      case '11': // D/Top + F (FT30 + FT40)
        doors = 1; fixedPanels = 1; totalCols = 2; hasTransom = true; ft30Qty = 1; ft40Qty = 1; break;
      case '12': // 2F + D/Top + 2F (5 cols)
        doors = 1; fixedPanels = 4; totalCols = 5; hasTransom = true; ft40Qty = 1; ft42Qty = 1; extraClamps = 4; break;
      case '13': // D + F
      case '14': // D + F alt
        doors = 1; fixedPanels = 1; totalCols = 2; break;
      case '15': // D + Top
        doors = 1; fixedPanels = 0; totalCols = 1; hasTransom = true; ft30Qty = 1; break;
      case '16': // D + Top + FT42
        doors = 1; fixedPanels = 0; totalCols = 1; hasTransom = true; ft30Qty = 1; ft42Qty = 1; break;
      case '17': // D single left
      case '18': // D single right
        doors = 1; fixedPanels = 0; totalCols = 1; break;
      case '19': // 6F fixed glass wall partition
        doors = 0; fixedPanels = 6; totalCols = 6; extraClamps = 12; break;
      case '20': // F + D + 5F partition (7 cols)
        doors = 1; fixedPanels = 6; totalCols = 7; extraClamps = 12; break;
      case '21': // F + DD/Top + F (FT40 x2)
        doors = 2; fixedPanels = 2; totalCols = 4; hasTransom = true; ft40Qty = 2; break;
      case '22': // F + DD/Top + F (FT41 x2)
        doors = 2; fixedPanels = 2; totalCols = 4; hasTransom = true; ft41Qty = 2; break;
      case '23': // F + DD + F
        doors = 2; fixedPanels = 2; totalCols = 4; break;
      case '24': // F + DD + F with side clamps
        doors = 2; fixedPanels = 2; totalCols = 4; extraClamps = 4; break;
      case '25': // DD + Top (FT30 x2 + FT42 x2)
        doors = 2; fixedPanels = 0; totalCols = 2; hasTransom = true; ft30Qty = 2; ft42Qty = 2; break;
    }

    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hardware = <HardwareItemSpec>[];

    final doorHExpr = hasTransom ? 'H1 - 12' : 'H - 12';
    final doorWExpr = totalCols == 1
        ? 'W - 6'
        : (totalCols == 2 && doors == 2
            ? '(W - 10) / 2'
            : 'W / $totalCols - 6');

    if (doors > 0) {
      glasses.add(
        GlassPieceSpec(
          name: doors == 2
              ? 'กระจกประตูบานเปลือยเปิดคู่ (เทมเปอร์)'
              : 'กระจกประตูบานเปลือยเดี่ยว (เทมเปอร์)',
          qty: doors,
          qtyText: '$doors แผ่น',
          siteCut: false,
          wFormula: doorWExpr,
          hFormula: doorHExpr,
        ),
      );
    }

    if (hasTransom) {
      final transomWExpr = totalCols == doors
          ? 'W - 4'
          : (doors == 2 ? 'W * 2 / $totalCols - 4' : 'W / $totalCols - 4');
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงบนเหนือประตู (เทมเปอร์)',
          qty: 1,
          qtyText: '1 แผ่น',
          siteCut: false,
          wFormula: transomWExpr,
          hFormula: 'H - H1 - 4',
        ),
      );
    }

    if (fixedPanels > 0) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกบานติดตายข้าง / ผนังเปลือย (เทมเปอร์)',
          qty: fixedPanels,
          qtyText: '$fixedPanels แผ่น',
          siteCut: false,
          wFormula: 'W / $totalCols - 4',
          hFormula: 'H - 4',
        ),
      );
      if (useUChannel) {
        cuts.add(
          CutPieceSpec(
            section: 'รางอลูมิเนียมตัวยู (เสริม)',
            code: 'U-12',
            name: 'รางตัวยูยึดกระจกติดตายบน-ล่าง',
            stockMm: 6000,
            qty: 2,
            qtyText: '2 ชิ้น',
            angle: '90° / 90°',
            formula: 'W * $fixedPanels / $totalCols',
          ),
        );
      }
    }

    // Authentic Hardware BOM (100% matched in VVP / RP catalog_prices_seed.json)
    if (doors > 0) {
      final closerName = closerModel == 'FC 49'
          ? 'โช้คฝังพื้น VVP FC 49 Heavy Duty'
          : (closerModel == 'OC 35'
              ? 'โช้คบนฝังในวงกบ VVP OC 35'
              : 'โช้คฝังพื้น VVP FC 34');
      hardware.addAll([
        HardwareItemSpec(
          code: closerModel,
          name: closerName,
          qtyText: '$doors ชุด',
        ),
        HardwareItemSpec(
          code: 'FT 10',
          name: 'ตัวหนีบล่าง VVP FT 10 (Bottom Patch)',
          qtyText: '$doors ชิ้น',
        ),
        HardwareItemSpec(
          code: isOverheadCloser ? 'FT 22' : 'FT 20',
          name: isOverheadCloser
              ? 'ตัวหนีบโช้คบน VVP FT 22 (Top Patch for OC)'
              : 'ตัวหนีบบน VVP FT 20 (Top Patch)',
          qtyText: '$doors ชิ้น',
        ),
        if (!hasTransom && !isOverheadCloser)
          HardwareItemSpec(
            code: 'AT 190',
            name: 'แกนหมุนบน VVP AT 190 (Top Pivot)',
            qtyText: '$doors ชิ้น',
          ),
        HardwareItemSpec(
          code: 'FL 50',
          name: 'กุญแจล็อคประตูกระจกกับพื้น VVP FL 50',
          qtyText: '$doors ชุด',
        ),
        HardwareItemSpec(
          code: isRp ? 'RPS-511' : 'VVP-H600',
          name: isRp
              ? 'มือจับประตูสเตนเลสตัว H ยาว RP RPS-511'
              : 'มือจับสเตนเลสตัว H บานเปลือย VVP (60 ซม.)',
          qtyText: '$doors คู่',
        ),
      ]);
    }

    if (ft30Qty > 0) {
      hardware.add(
        HardwareItemSpec(
          code: 'FT 30',
          name: 'ตัวหนีบช่องแสงบน VVP FT 30 (Over-panel Pivot)',
          qtyText: '$ft30Qty ชิ้น',
        ),
      );
    }
    if (ft40Qty > 0) {
      hardware.add(
        HardwareItemSpec(
          code: 'FT 40',
          name: 'ตัวหนีบช่องแสงบนและข้างมีแกนหมุน VVP FT 40',
          qtyText: '$ft40Qty ชิ้น',
        ),
      );
    }
    if (ft41Qty > 0) {
      hardware.add(
        HardwareItemSpec(
          code: 'FT 41',
          name: 'ตัวหนีบช่องแสงบนและข้างมีครีบ VVP FT 41',
          qtyText: '$ft41Qty ชิ้น',
        ),
      );
    }
    if (ft42Qty > 0) {
      hardware.add(
        HardwareItemSpec(
          code: 'FT 42',
          name: 'ตัวหนีบช่องแสงบนและข้างเล็ก VVP FT 42',
          qtyText: '$ft42Qty ชิ้น',
        ),
      );
    }
    if (extraClamps > 0 && !useUChannel) {
      hardware.add(
        HardwareItemSpec(
          code: isRp ? 'BL-201' : 'GC-502',
          name: isRp
              ? 'ตัวหนีบยึดกระจกติดตาย RP BL-201'
              : 'ตัวหนีบยึดกระจกติดตาย VVP GC-502',
          qtyText: '$extraClamps ชิ้น',
        ),
      );
    }

    return VerifiedFormulaTable(
      key: pattern.baseFormulaKey,
      header: '${isRp ? 'RP Steel Glass' : 'VVP'} | ${pattern.title}',
      cuts: cuts,
      glasses: glasses,
      hardware: hardware,
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
    int countA = 0;
    int countB = 0;
    for (final s in [l, r]) {
      if (s >= 2) {
        if (s % 2 == 0) {
          countA += 1;
          countB += (s ~/ 2) - 1;
        } else {
          countB += (s ~/ 2);
        }
      }
    }
    final carrierPairs = (l ~/ 2) + (r ~/ 2);
    final cPairs = carrierPairs > 0 ? carrierPairs : 1;
    final hasOddLeaf = (l % 2 == 1) || (r % 2 == 1);
    final hasTwoOddLeaves = (l % 2 == 1) && (r % 2 == 1);
    final hw = <HardwareItemSpec>[];
    if (countA > 0) {
      hw.add(HardwareItemSpec(
        code: 'HD-640A',
        name: 'HD-640A ล้อบนตัวจบชนบานคู่',
        qtyText: '$countA ชิ้น',
      ));
    }
    if (countB > 0) {
      hw.add(HardwareItemSpec(
        code: 'HD-640B',
        name: 'HD-640B ล้อบนปกติ',
        qtyText: '$countB ชิ้น',
      ));
    }
    if (countA > 0) {
      hw.add(HardwareItemSpec(
        code: 'HD-643A',
        name: 'HD-643A บานพับไกด์ล่างตัวจบชนบานคู่',
        qtyText: '$countA ชิ้น',
      ));
    }
    if (countB > 0) {
      hw.add(HardwareItemSpec(
        code: 'HD-643B',
        name: 'HD-643B บานพับไกด์ล่างปกติ',
        qtyText: '$countB ชิ้น',
      ));
    }
    hw.addAll([
      HardwareItemSpec(
        code: 'HD-641',
        name: 'HD-641 บานพับปกติ',
        qtyText: '${n == 2 ? 4 : 3 * n} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-642',
        name: 'HD-642 บานพับมือจับ',
        qtyText: '${(n + 1) ~/ 2} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-321',
        name: 'HD-321 CDQ',
        qtyText: '$cPairs ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-320',
        name: 'HD-320 ปลายกลอนบานเฟี้ยม',
        qtyText: '${2 * cPairs} ชิ้น',
      ),
      HardwareItemSpec(
        code: 'HD-474',
        name: 'HD-474 มือจับปากเป็ด',
        qtyText: '$cPairs ชิ้น',
      ),
    ]);
    if (hasOddLeaf) {
      hw.addAll([
        const HardwareItemSpec(
          code: '',
          name: 'เสื้อกุญแจ 35×85 + ไส้กุญแจ',
          qtyText: '1 ชุด',
        ),
        const HardwareItemSpec(
          code: '',
          name: 'มือจับเขาควายมีรูกุญแจ',
          qtyText: '1 คู่',
        ),
        if (hasTwoOddLeaves)
          const HardwareItemSpec(
            code: '',
            name: 'มือจับเขาควายดัมมี่',
            qtyText: '1 คู่',
          ),
      ]);
    }
    return hw;
  }

  // ===========================================================================
  // ALUMET 6-Album Extended Parametric Pattern Resolver
  // Supports: sx (Smart X), nex (NEX 100/200), iq (Iconiq Euro)
  // Families: slide, case, awn, fix, door (ICONIQ ONLY!)
  // ===========================================================================
  static VerifiedFormulaTable _resolveAlumetExtendedTable(
    String key,
    String patternTitle,
  ) {
    final parts = key.split(':');
    // Format: alu_ext:<series>:<family>:<p1>[:<p2>]
    final series = parts.length > 1 ? parts[1] : 'sx';
    final family = parts.length > 2 ? parts[2] : 'fix';
    final p1 = parts.length > 3 ? parts[3] : '1';
    final p2 = parts.length > 4 ? parts[4] : 'plain';

    switch (family) {
      case 'slide':
        return _buildAlumetExtendedSliding(series, p1, key, patternTitle);
      case 'case':
      case 'awn':
        final n = int.tryParse(p1) ?? 1;
        return _buildAlumetExtendedCasementOrAwning(
          series: series,
          isAwning: family == 'awn',
          panels: n,
          transom: p2,
          key: key,
          title: patternTitle,
        );
      case 'fix':
        final n = int.tryParse(p1) ?? 1;
        return _buildAlumetExtendedFixed(
          series: series,
          cols: n,
          transom: p2,
          key: key,
          title: patternTitle,
        );
      case 'door':
        return _buildIconiqExtendedSwingDoor(
          variant: p1,
          key: key,
          title: patternTitle,
        );
      default:
        throw StateError('Unknown ALUMET extended formula family: $key');
    }
  }

  static CutPieceSpec _c(
    String section,
    String code,
    String name,
    String formula,
    int qty, {
    int stockMm = 6400,
    String angle = '90° / 90°',
  }) {
    return CutPieceSpec(
      section: section,
      code: code,
      name: name,
      stockMm: stockMm,
      qty: qty,
      qtyText: '$qty ชิ้น',
      angle: angle,
      formula: formula,
    );
  }

  static VerifiedFormulaTable _buildAlumetExtendedSliding(
    String series,
    String variant,
    String key,
    String title,
  ) {
    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hw = <HardwareItemSpec>[];

    // Combo: 2 flanking casements + 3 center fixed bays
    if (variant == 'combo_c2_f3' || variant == 'combo_c2_f3_bot') {
      final hasBot = variant == 'combo_c2_f3_bot';
      final hWing = hasBot ? 'H1' : 'H';

      if (series == 'sx') {
        cuts.addAll([
          _c('ชุดเฟรมหลัก', 'SC-X107', 'วงกบข้างซ้าย/ขวา', 'H', 2),
          _c('ชุดเฟรมหลัก', 'SC-X107', 'วงกบบนเต็มความกว้าง', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'SC-X108', 'วงกบล่างเต็มความกว้าง', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'SC-X104', 'เสาซอยแบ่งช่องหลัก', 'H - 50', 4),
          if (hasBot)
            _c('ช่องแสงล่างใต้บานเปิด', 'SF-X109', 'ขวางแบ่งช่องแสงล่าง', '(W - 140) / 5', 2),
          _c('กรอบบานเปิดซ้าย-ขวา', 'SC-X204', 'กรอบบานแนวตั้ง', '$hWing - 36', 4, angle: '45° / 45°'),
          _c('กรอบบานเปิดซ้าย-ขวา', 'SC-X204', 'กรอบบานแนวนอน', '(W - 140) / 5', 4, angle: '45° / 45°'),
          _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกแนวตั้ง (บานเปิด + บานตาย)', 'H - 90', 10),
          _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกแนวนอน', '(W - 180) / 5', hasBot ? 14 : 10),
        ]);
      } else if (series == 'nex') {
        cuts.addAll([
          _c('ชุดเฟรมหลัก', 'PC-0104', 'เฟรมบน-ข้าง บานเปิด-กระทุ้ง เน็กซ์', 'H', 2),
          _c('ชุดเฟรมหลัก', 'PC-0104', 'เฟรมบนเต็มความกว้าง เน็กซ์', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'PC-0105', 'เฟรมล่างเต็มความกว้าง เน็กซ์', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'PC-0106', 'ซอยเฟรมแบ่งช่องหลัก เน็กซ์', 'H - 50', 4),
          if (hasBot)
            _c('ช่องแสงล่างใต้บานเปิด', 'PC-0107', 'ตบเฟรมแบ่งช่องแสงล่าง เน็กซ์', '(W - 140) / 5', 2),
          _c('กรอบบานเปิดซ้าย-ขวา', 'PC-0204', 'กรอบบานเปิดแนวตั้ง เน็กซ์', '$hWing - 36', 4, angle: '45° / 45°'),
          _c('กรอบบานเปิดซ้าย-ขวา', 'PC-0204', 'กรอบบานเปิดแนวนอน เน็กซ์', '(W - 140) / 5', 4, angle: '45° / 45°'),
          _c('คิ้วกระจกช่องแสง', 'A30274', 'คิ้วช่องแสงแนวตั้ง', 'H - 80', 6),
          _c('คิ้วกระจกช่องแสง', 'A30274', 'คิ้วช่องแสงแนวนอน', '(W - 160) / 5', hasBot ? 10 : 6),
        ]);
      } else {
        // Iconiq Euro
        cuts.addAll([
          _c('ชุดเฟรมหลัก', 'iC-0101', 'วงกบข้างซ้าย/ขวา ไอคอนิค', 'H', 2),
          _c('ชุดเฟรมหลัก', 'iC-0101', 'วงกบบนเต็มความกว้าง ไอคอนิค', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'iC-0102', 'วงกบล่างเต็มความกว้าง ไอคอนิค', 'W - 50', 1),
          _c('ชุดเฟรมหลัก', 'iF-0104', 'เสาซอยแบ่งช่องหลัก ไอคอนิค', 'H - 50', 4),
          if (hasBot)
            _c('ช่องแสงล่างใต้บานเปิด', 'iF-0102', 'ขวางแบ่งช่องแสงล่าง ไอคอนิค', '(W - 140) / 5', 2),
          _c('กรอบบานเปิดซ้าย-ขวา', 'iC-0201', 'กรอบบานเปิดแนวตั้ง ไอคอนิค', '$hWing - 36', 4, angle: '45° / 45°'),
          _c('กรอบบานเปิดซ้าย-ขวา', 'iC-0201', 'กรอบบานเปิดแนวนอน ไอคอนิค', '(W - 140) / 5', 4, angle: '45° / 45°'),
          _c('ชุดตบร่องและคิ้ว', 'SC-X105', 'ตบร่องเฟรมแนวตั้ง', 'H', 2),
          _c('ชุดตบร่องและคิ้ว', 'iO-0203', 'คิ้วกระจกแนวตั้ง ไอคอนิค', 'H - 110', 10),
          _c('ชุดตบร่องและคิ้ว', 'iO-0203', 'คิ้วกระจกแนวนอน ไอคอนิค', '(W - 190) / 5', hasBot ? 14 : 10),
        ]);
      }

      glasses.addAll([
        GlassPieceSpec(
          name: 'กระจกบานเปิดข้างซ้าย-ขวา',
          siteCut: false,
          wFormula: '((W - 140) / 5) - 70',
          hFormula: '$hWing - 116',
          qty: 2,
          qtyText: '2 แผ่น',
        ),
        const GlassPieceSpec(
          name: 'กระจกบานติดตายกลาง 3 ช่อง',
          siteCut: false,
          wFormula: '((W - 140) / 5) - 20',
          hFormula: 'H - 60',
          qty: 3,
          qtyText: '3 แผ่น',
        ),
        if (hasBot)
          const GlassPieceSpec(
            name: 'กระจกช่องแสงล่างใต้บานเปิด',
            siteCut: false,
            wFormula: '((W - 140) / 5) - 20',
            hFormula: '(H - H1) - 35',
            qty: 2,
            qtyText: '2 แผ่น',
          ),
      ]);
      hw.addAll(const [
        HardwareItemSpec(code: '', name: 'บานพับกระทุ้ง', qtyText: '2 คู่'),
        HardwareItemSpec(code: '', name: 'มือจับกระทุ้ง มัลติพอยท์', qtyText: '2 ชุด'),
        HardwareItemSpec(code: '', name: 'ตลับเกียร์มัลติพอยท์', qtyText: '2 ชุด'),
        HardwareItemSpec(code: '', name: 'ฉากประคองมุม TL 6.5 มิล', qtyText: '8 ตัว'),
      ]);

      return VerifiedFormulaTable(
        key: key,
        header: title,
        cuts: cuts,
        glasses: glasses,
        hardware: hw,
      );
    }

    // Sliding variants:
    // s2_top2, s3_1f2s, s3_top, s4_top, s4_top4, s4_arch, s3_1f2s_tb, s3_1f2s_tb_asym
    final is4 = variant.startsWith('s4');
    final is3 = variant.startsWith('s3');
    final is2 = variant.startsWith('s2');
    final isArch = variant == 's4_arch';
    final isTb = variant == 's3_1f2s_tb' || variant == 's3_1f2s_tb_asym';
    final isTopOnly = variant == 's2_top2' ||
        variant == 's3_top' ||
        variant == 's4_top' ||
        variant == 's4_top4';
    final hasTransomH1 = isTopOnly || isArch || isTb;
    final hSlide = hasTransomH1 ? 'H1' : 'H';
    final panelCount = is4 ? 4 : (is3 ? 3 : 2);
    final slidingLeaves = variant.contains('1f2s') ? 2 : (is4 ? 2 : panelCount);
    final topCells = variant == 's4_top4'
        ? 4
        : (variant == 's2_top2'
            ? 2
            : (variant == 's3_1f2s_tb'
                ? 3
                : (variant == 's3_1f2s_tb_asym' ? 2 : (is3 ? 3 : 1))));

    // Rail width formula matching existing verified deductions per panel count
    final railFormula = is4
        ? '(W - 280) / 4'
        : (is3 ? '(W - 180) / 3' : '(W - 168) / 2');
    final stileQty = panelCount * 2;
    final railQty = panelCount * 2;
    final interlockQty = is4 ? 2 : (is3 ? 2 : 2);

    if (series == 'sx') {
      cuts.addAll([
        _c('วงกบและเฟรมบานเลื่อน', 'SS-X101', 'เฟรมบนบานเลื่อน สมาร์ท เอ็กซ์', 'W - 50', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'SS-X102', 'เฟรมล่างบานเลื่อน สมาร์ท เอ็กซ์', 'W - 50', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'SS-X103', 'เฟรมข้างกล่องเรียบ สมาร์ท เอ็กซ์', hSlide, 2),
        if (hasTransomH1)
          _c('ชุดต่อช่องแสง', 'SS-X104', 'ตบเฟรมต่อช่องแสง สมาร์ท เอ็กซ์', 'W - 50', isTb ? 2 : 1),
        _c('กรอบบานเลื่อน', 'SS-X209', 'เสากุญแจมัลติพอยท์ สมาร์ท เอ็กซ์', '$hSlide - 56', stileQty),
        _c('กรอบบานเลื่อน', 'SS-X210', 'ขวางบน-ล่าง (ล้อตลับ) สมาร์ท เอ็กซ์', railFormula, railQty),
        _c('กรอบบานเลื่อน', 'SS-0139', 'ตบเกี่ยวเสา สมาร์ท เอ็กซ์', '$hSlide - 56', interlockQty),
      ]);
      if (isArch) {
        cuts.addAll([
          _c('ช่องแสงโค้งครึ่งวงกลม', 'SF-X110', 'เฟรมดัดโค้งช่องแสงบน (เผื่อดัดโค้ง)', '(W * 1.571) + 100', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'SF-X109', 'ฐานช่องแสงโค้งแนวนอน', 'W - 50', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'SF-X105', 'ซี่รัศมีแบ่งช่องแสงโค้ง', '(W / 2) - 40', 4),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'SF-X108', 'คิ้วกระจกดัดโค้งช่องแสงบน', '(W * 1.571) + 60', 1),
        ]);
      } else if (isTopOnly) {
        cuts.addAll([
          _c('ช่องแสงบน', 'SF-X110', 'เฟรมบนช่องแสง สมาร์ท เอ็กซ์', 'W - 50', 1),
          _c('ช่องแสงบน', 'SF-X110', 'เฟรมข้างช่องแสงบน', 'H - H1', 2),
          if (topCells > 1)
            _c('ช่องแสงบน', 'SF-X105', 'เสาซอยแบ่งช่องแสงบน', '(H - H1) - 25', topCells - 1),
          _c('ช่องแสงบน', 'SF-X108', 'คิ้วกระจกช่องแสงแนวนอน', '(W - 70) / $topCells', topCells * 2),
          _c('ช่องแสงบน', 'SF-X108', 'คิ้วกระจกช่องแสงแนวตั้ง', '(H - H1) - 35', topCells * 2),
        ]);
      } else if (isTb) {
        cuts.addAll([
          _c('ช่องแสงบน-ล่าง', 'SF-X110', 'เฟรมบน-ล่างช่องแสง สมาร์ท เอ็กซ์', 'W - 50', 2),
          _c('ช่องแสงบน-ล่าง', 'SF-X110', 'เฟรมข้างช่องแสงบน-ล่าง', '(H - H1) / 2', 4),
          _c('ช่องแสงบน-ล่าง', 'SF-X105', 'เสาซอยแบ่งช่องแสงบน-ล่าง', '((H - H1) / 2) - 25', topCells + 1),
          _c('ช่องแสงบน-ล่าง', 'SF-X108', 'คิ้วกระจกช่องแสงแนวนอน', '(W - 80) / 3', 10),
        ]);
      }
    } else if (series == 'nex') {
      final topTrack = is3 ? 'PS-0113' : 'PS-0107';
      final botTrack = is3 ? 'PS-0114' : 'PS-0108';
      final trackLabel = is3 ? '3 ราง' : '2 ราง';
      cuts.addAll([
        _c('วงกบและเฟรมบานเลื่อน', topTrack, 'เฟรมบน $trackLabel เน็กซ์', 'W - 40', 1),
        _c('วงกบและเฟรมบานเลื่อน', botTrack, 'เฟรมล่าง $trackLabel เน็กซ์', 'W - 40', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'PS-0106', 'เฟรมข้างกล่องเรียบ เน็กซ์', hSlide, 2),
        _c('วงกบและเฟรมบานเลื่อน', 'PS-0109', 'ฝาตบเฟรมบน เน็กซ์', 'W - 40', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'PS-0110', 'ตบธรณีเฟรมล่าง เน็กซ์', 'W - 40', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'PS-0111', 'เสริมรับล็อกเฟรมข้าง เน็กซ์', '$hSlide - 40', 2),
        if (hasTransomH1)
          _c('ชุดต่อช่องแสง', 'PS-0112', 'ตบเฟรมบนต่อช่องแสง เน็กซ์', 'W - 40', isTb ? 2 : 1),
        _c('กรอบบานเลื่อน', 'PS-0206', 'เสากุญแจประตูบานเลื่อน เน็กซ์', '$hSlide - 47', stileQty ~/ 2),
        _c('กรอบบานเลื่อน', 'PS-0208', 'เสาเกี่ยว เน็กซ์', '$hSlide - 47', stileQty ~/ 2),
        _c('กรอบบานเลื่อน', 'PS-0207', 'ขวางบน-ล่าง ล้อตลับ เน็กซ์', railFormula, railQty),
      ]);
      if (isArch) {
        cuts.addAll([
          _c('ช่องแสงโค้งครึ่งวงกลม', 'PF-0103', 'กล่องร่องดัดโค้งช่องแสงบน (เผื่อดัดโค้ง)', '(W * 1.571) + 100', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'PF-0101', 'กล่องเปิดฐานช่องแสงโค้ง', 'W - 40', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'PF-0103', 'ซี่รัศมีแบ่งช่องแสงโค้ง', '(W / 2) - 40', 4),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'A10261', 'ตบร่องช่องแสงโค้ง', '(W * 1.571) + 60', 1),
        ]);
      } else if (isTopOnly) {
        cuts.addAll([
          _c('ช่องแสงบน', 'PF-0103', 'กล่องร่องเฟรมบนช่องแสง เน็กซ์', 'W - 40', 1),
          _c('ช่องแสงบน', 'PF-0103', 'กล่องร่องเฟรมข้างช่องแสงบน', 'H - H1', 2),
          if (topCells > 1)
            _c('ช่องแสงบน', 'PF-0103', 'กล่องร่องซอยแบ่งช่องแสงบน', '(H - H1) - 25', topCells - 1),
          _c('ช่องแสงบน', 'PF-0102', 'ฝาปิดกล่องช่องแสงบน', 'W - 40', 1),
          _c('ช่องแสงบน', 'A10261', 'ตบร่องช่องแสงบน', '(H - H1) - 25', topCells + 1),
        ]);
      } else if (isTb) {
        cuts.addAll([
          _c('ช่องแสงบน-ล่าง', 'PF-0103', 'กล่องร่องเฟรมบน-ล่างช่องแสง เน็กซ์', 'W - 40', 2),
          _c('ช่องแสงบน-ล่าง', 'PF-0103', 'กล่องร่องเฟรมข้างช่องแสงบน-ล่าง', '(H - H1) / 2', 4),
          _c('ช่องแสงบน-ล่าง', 'PF-0103', 'กล่องร่องซอยแบ่งช่องแสงบน-ล่าง', '((H - H1) / 2) - 25', topCells + 1),
          _c('ช่องแสงบน-ล่าง', 'A10261', 'ตบร่องช่องแสงบน-ล่าง', 'W - 50', 2),
        ]);
      }
    } else {
      // Iconiq Euro
      cuts.addAll([
        _c('วงกบและเฟรมบานเลื่อน', 'iS-0101', 'เฟรมบน-ล่างบานเลื่อน ไอคอนิค', 'W - 50', 2),
        _c('วงกบและเฟรมบานเลื่อน', 'iS-0102', 'เฟรมข้างบานเลื่อน ไอคอนิค', hSlide, 2),
        _c('วงกบและเฟรมบานเลื่อน', 'iS-0104', 'ตบรางล้อบานเลื่อน ไอคอนิค', 'W - 50', 2),
        _c('วงกบและเฟรมบานเลื่อน', 'iS-0113', 'ตบเฟรมบนบานเลื่อน ไอคอนิค', 'W - 50', 1),
        _c('วงกบและเฟรมบานเลื่อน', 'iS-0114', 'ตบธรณีบานเลื่อน ไอคอนิค', 'W - 50', 1),
        if (hasTransomH1)
          _c('ชุดต่อช่องแสง', 'iS-0116', 'เสริมช่องแสงเฟรมบานเลื่อน ไอคอนิค', 'W - 50', isTb ? 2 : 1),
        _c('กรอบบานเลื่อน', 'iS-0201', 'กรอบบานเลื่อนแนวตั้ง ไอคอนิค', '$hSlide - 62', stileQty, angle: '45° / 45°'),
        _c('กรอบบานเลื่อน', 'iS-0201', 'กรอบบานเลื่อนแนวนอน ไอคอนิค', railFormula, railQty, angle: '45° / 45°'),
        _c('คิ้วกรอบบาน', 'iS-0202', 'คิ้วกรอบบานแนวตั้ง ไอคอนิค', '$hSlide - 160', stileQty),
        _c('คิ้วกรอบบาน', 'iS-0202', 'คิ้วกรอบบานแนวนอน ไอคอนิค', '$railFormula - 80', railQty),
      ]);
      if (isArch) {
        cuts.addAll([
          _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0101', 'เฟรมดัดโค้งช่องแสงบน ไอคอนิค (เผื่อดัดโค้ง)', '(W * 1.571) + 100', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0102', 'เฟรมฐานช่องแสงโค้ง ไอคอนิค', 'W - 50', 1),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0104', 'ซี่รัศมีแบ่งช่องแสงโค้ง ไอคอนิค', '(W / 2) - 40', 4),
          _c('ช่องแสงโค้งครึ่งวงกลม', 'iO-0203', 'คิ้วกระจกช่องแสงโค้ง ไอคอนิค', '(W * 1.571) + 60', 1),
        ]);
      } else if (isTopOnly) {
        cuts.addAll([
          _c('ช่องแสงบน', 'iF-0101', 'เฟรมบนช่องแสง ไอคอนิค', 'W - 50', 1),
          _c('ช่องแสงบน', 'iF-0101', 'เฟรมข้างช่องแสงบน ไอคอนิค', 'H - H1', 2),
          if (topCells > 1)
            _c('ช่องแสงบน', 'iF-0104', 'เสาซอยแบ่งช่องแสงบน ไอคอนิค', '(H - H1) - 25', topCells - 1),
          _c('ช่องแสงบน', 'iO-0203', 'คิ้วกระจกช่องแสงแนวนอน ไอคอนิค', '(W - 80) / $topCells', topCells * 2),
        ]);
      } else if (isTb) {
        cuts.addAll([
          _c('ช่องแสงบน-ล่าง', 'iF-0101', 'เฟรมบนช่องแสง ไอคอนิค', 'W - 50', 1),
          _c('ช่องแสงบน-ล่าง', 'iF-0102', 'เฟรมล่างช่องแสง ไอคอนิค', 'W - 50', 1),
          _c('ช่องแสงบน-ล่าง', 'iF-0101', 'เฟรมข้างช่องแสงบน-ล่าง ไอคอนิค', '(H - H1) / 2', 4),
          _c('ช่องแสงบน-ล่าง', 'iF-0104', 'เสาซอยแบ่งช่องแสงบน-ล่าง ไอคอนิค', '((H - H1) / 2) - 25', topCells + 1),
          _c('ช่องแสงบน-ล่าง', 'iO-0203', 'คิ้วกระจกช่องแสงบน-ล่าง ไอคอนิค', '(W - 80) / 3', 10),
        ]);
      }
    }

    // Glasses for sliding
    final slideGlassW = is4
        ? '(W - 360) / 4'
        : (is3 ? '(W - 260) / 3' : '(W - 220) / 2');
    glasses.add(
      GlassPieceSpec(
        name: 'กระจกบานเลื่อน ($panelCount ช่อง)',
        siteCut: false,
        wFormula: slideGlassW,
        hFormula: '$hSlide - 140',
        qty: panelCount,
        qtyText: '$panelCount แผ่น',
      ),
    );
    if (isArch) {
      glasses.add(
        const GlassPieceSpec(
          name: 'กระจกช่องแสงโค้งครึ่งวงกลม (วัดตัดตามแบบโค้งหน้างาน)',
          siteCut: true,
          qty: 4,
          qtyText: '4 แผ่น',
        ),
      );
    } else if (isTopOnly) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงบน ($topCells ช่อง)',
          siteCut: false,
          wFormula: '(W - ${40 + topCells * 25}) / $topCells',
          hFormula: '(H - H1) - 35',
          qty: topCells,
          qtyText: '$topCells แผ่น',
        ),
      );
    } else if (isTb) {
      glasses.addAll([
        GlassPieceSpec(
          name: 'กระจกช่องแสงบน ($topCells ช่อง)',
          siteCut: false,
          wFormula: '(W - ${40 + topCells * 25}) / $topCells',
          hFormula: '((H - H1) / 2) - 30',
          qty: topCells,
          qtyText: '$topCells แผ่น',
        ),
        const GlassPieceSpec(
          name: 'กระจกช่องแสงล่าง (3 ช่อง)',
          siteCut: false,
          wFormula: '(W - 115) / 3',
          hFormula: '((H - H1) / 2) - 30',
          qty: 3,
          qtyText: '3 แผ่น',
        ),
      ]);
    }

    hw.addAll([
      HardwareItemSpec(
        code: '',
        name: 'ล้อตลับบานเลื่อน NEX',
        qtyText: '${slidingLeaves * 2} ตัว',
      ),
      HardwareItemSpec(
        code: '',
        name: 'มือจับฝังล็อก ซิงเกิลล็อก',
        qtyText: '${is2 || is3 ? 2 : 2} ชุด',
      ),
      HardwareItemSpec(
        code: '',
        name: 'ยางกันกระแทกบานเลื่อน',
        qtyText: '${slidingLeaves * 2} ตัว',
      ),
      const HardwareItemSpec(
        code: '',
        name: 'สักหลาดกันเสียง 2 ชั้น',
        qtyText: '1 ม้วน',
      ),
    ]);

    return VerifiedFormulaTable(
      key: key,
      header: title,
      cuts: cuts,
      glasses: glasses,
      hardware: hw,
    );
  }

  static VerifiedFormulaTable _buildAlumetExtendedCasementOrAwning({
    required String series,
    required bool isAwning,
    required int panels,
    required String transom, // plain | top | bot | tb
    required String key,
    required String title,
  }) {
    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hw = <HardwareItemSpec>[];

    final hasTop = transom == 'top' || transom == 'tb';
    final hasBot = transom == 'bot' || transom == 'tb';
    final hasTransom = hasTop || hasBot;
    final sashH = hasTransom ? 'H1' : 'H';
    final transomH = transom == 'tb' ? '(H - H1) / 2' : '(H - H1)';
    final transomDivCount = transom == 'tb' ? 2 : (hasTransom ? 1 : 0);
    final sashW = panels == 1
        ? 'W - 36'
        : '(W - ${36 + (panels - 1) * 24}) / $panels';
    final glassW = panels == 1
        ? 'W - 120'
        : '((W - ${36 + (panels - 1) * 24}) / $panels) - 80';
    final transomGlassW = panels == 1
        ? 'W - 60'
        : '(W - ${40 + panels * 24}) / $panels';
    final leafLabel = isAwning ? 'บานกระทุ้ง' : 'บานเปิด';

    if (series == 'sx') {
      cuts.addAll([
        _c('ชุดวงกบ', 'SC-X107', 'วงกบข้างซ้าย/ขวา สมาร์ท เอ็กซ์', 'H', 2),
        _c('ชุดวงกบ', 'SC-X107', 'วงกบบน สมาร์ท เอ็กซ์', 'W - 50', 1),
        _c('ชุดวงกบ', 'SC-X108', 'วงกบล่าง สมาร์ท เอ็กซ์', 'W - 50', 1),
        if (panels == 2 && !isAwning)
          _c('เสาแบ่งบาน', 'SC-0212', 'เสารับกลางบานเปิดคู่ สมาร์ท เอ็กซ์', '$sashH - 36', 1)
        else if (panels > 1)
          _c('เสาแบ่งบาน', 'SC-X104', 'เสาซอยแบ่งช่อง$leafLabel สมาร์ท เอ็กซ์', '$sashH - 36', panels - 1),
        if (transomDivCount > 0)
          _c('ชุดช่องแสง', 'SF-X109', 'เฟรมขวางแบ่งช่องแสง สมาร์ท เอ็กซ์', 'W - 50', transomDivCount),
        if (hasTransom && panels > 1)
          _c('ชุดช่องแสง', 'SF-X105', 'เสาซอยแบ่งช่องแสง สมาร์ท เอ็กซ์', '$transomH - 25', (panels - 1) * transomDivCount),
        _c('กรอบ$leafLabel', 'SC-X204', 'กรอบ$leafLabelแนวตั้ง สมาร์ท เอ็กซ์', '$sashH - 36', panels * 2, angle: '45° / 45°'),
        _c('กรอบ$leafLabel', 'SC-X204', 'กรอบ$leafLabelแนวนอน สมาร์ท เอ็กซ์', sashW, panels * 2, angle: '45° / 45°'),
        _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกกรอบบานแนวตั้ง', '$sashH - 110', panels * 2),
        _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกกรอบบานแนวนอน', '$sashW - 60', panels * 2),
        if (hasTransom)
          _c('คิ้วกระจกช่องแสง', 'SF-X108', 'คิ้วกระจกช่องแสงแนวนอน', transomGlassW, panels * 2 * transomDivCount),
      ]);
    } else if (series == 'nex') {
      cuts.addAll([
        _c('ชุดวงกบ', 'PC-0104', 'เฟรมข้าง บานเปิด-กระทุ้ง เน็กซ์', 'H', 2),
        _c('ชุดวงกบ', 'PC-0104', 'เฟรมบน บานเปิด-กระทุ้ง เน็กซ์', 'W - 50', 1),
        _c('ชุดวงกบ', 'PC-0105', 'เฟรมล่าง บานเปิด-กระทุ้ง เน็กซ์', 'W - 50', 1),
        if (panels == 2 && !isAwning)
          _c('เสาแบ่งบาน', 'PC-0205', 'เสาเสริมบานเปิดคู่ เน็กซ์', '$sashH - 36', 1)
        else if (panels > 1)
          _c('เสาแบ่งบาน', 'PC-0106', 'ซอยเฟรมแบ่งช่อง$leafLabel เน็กซ์', '$sashH - 36', panels - 1),
        if (hasTop)
          _c('ชุดช่องแสงบน', 'PC-0106', 'ซอยเฟรมต่อช่องแสงบน เน็กซ์', 'W - 50', 1),
        if (hasBot)
          _c('ชุดช่องแสงล่าง', 'PC-0107', 'ตบเฟรมต่อช่องแสงล่าง เน็กซ์', 'W - 50', 1),
        if (hasTransom && panels > 1)
          _c('ชุดช่องแสง', 'PC-0106', 'ซอยเฟรมแบ่งช่องแสงแนวตั้ง เน็กซ์', '$transomH - 25', (panels - 1) * transomDivCount),
        _c('กรอบ$leafLabel', 'PC-0204', 'กรอบ$leafLabelแนวตั้ง เน็กซ์', '$sashH - 36', panels * 2, angle: '45° / 45°'),
        _c('กรอบ$leafLabel', 'PC-0204', 'กรอบ$leafLabelแนวนอน เน็กซ์', sashW, panels * 2, angle: '45° / 45°'),
        if (hasTransom) ...[
          _c('คิ้วช่องแสง', 'A30274', 'คิ้วช่องแสงแนวนอน เน็กซ์', transomGlassW, panels * 2 * transomDivCount),
          _c('คิ้วช่องแสง', 'A30274', 'คิ้วช่องแสงแนวตั้ง เน็กซ์', '$transomH - 30', panels * 2 * transomDivCount),
        ],
      ]);
    } else {
      // Iconiq Euro
      final frameTop = isAwning ? 'iC-0107' : 'iC-0101';
      final frameBot = isAwning ? 'iC-0108' : 'iC-0102';
      cuts.addAll([
        _c('ชุดวงกบ', frameTop, 'วงกบข้างซ้าย/ขวา ไอคอนิค', 'H', 2),
        _c('ชุดวงกบ', frameTop, 'วงกบบน ไอคอนิค', 'W - 50', 1),
        _c('ชุดวงกบ', frameBot, 'วงกบล่าง ไอคอนิค', 'W - 50', 1),
        if (panels == 2 && !isAwning)
          _c('เสาแบ่งบาน', 'SC-0212', 'เสริมเสาบานเปิดคู่ ไอคอนิค', '$sashH - 36', 1)
        else if (panels > 1)
          _c('เสาแบ่งบาน', 'iF-0104', 'เสาซอยแบ่งช่อง$leafLabel ไอคอนิค', '$sashH - 36', panels - 1),
        if (transomDivCount > 0)
          _c('ชุดช่องแสง', 'iF-0104', 'ตบช่องแสงที่แนวแบ่ง ไอคอนิค', 'W - 50', transomDivCount),
        if (hasTransom && panels > 1)
          _c('ชุดช่องแสง', 'SC-X106', 'เสาซอยแบ่งช่องแสง ไอคอนิค', '$transomH - 25', (panels - 1) * transomDivCount),
        _c('กรอบ$leafLabel', 'iC-0201', 'กรอบ$leafLabelแนวตั้ง ไอคอนิค', '$sashH - 36', panels * 2, angle: '45° / 45°'),
        _c('กรอบ$leafLabel', 'iC-0201', 'กรอบ$leafLabelแนวนอน ไอคอนิค', sashW, panels * 2, angle: '45° / 45°'),
        _c('ตบร่องเฟรม', 'SC-X105', 'ตบร่องเฟรมแนวตั้ง', 'H', 2),
        _c('ตบร่องเฟรม', 'SC-X105', 'ตบร่องเฟรมแนวนอน', 'W - 50', 2),
        _c('คิ้วกระจก', 'iO-0203', 'คิ้วกระจกแนวตั้ง ไอคอนิค', '$sashH - 120', panels * 2),
        _c('คิ้วกระจก', 'iO-0203', 'คิ้วกระจกแนวนอน ไอคอนิค', '$sashW - 80', panels * 2),
      ]);
    }

    glasses.add(
      GlassPieceSpec(
        name: 'กระจก$leafLabel ($panels บาน)',
        siteCut: false,
        wFormula: glassW,
        hFormula: '$sashH - 116',
        qty: panels,
        qtyText: '$panels แผ่น',
      ),
    );
    if (hasTop) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงบน ($panels ช่อง)',
          siteCut: false,
          wFormula: transomGlassW,
          hFormula: '$transomH - 30',
          qty: panels,
          qtyText: '$panels แผ่น',
        ),
      );
    }
    if (hasBot) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงล่าง ($panels ช่อง)',
          siteCut: false,
          wFormula: transomGlassW,
          hFormula: '$transomH - 30',
          qty: panels,
          qtyText: '$panels แผ่น',
        ),
      );
    }

    hw.addAll([
      HardwareItemSpec(
        code: '',
        name: 'บานพับกระทุ้ง',
        qtyText: '$panels คู่',
      ),
      HardwareItemSpec(
        code: '',
        name: 'มือจับกระทุ้ง มัลติพอยท์',
        qtyText: '$panels ชุด',
      ),
      if (!isAwning)
        HardwareItemSpec(
          code: '',
          name: 'ตลับเกียร์มัลติพอยท์',
          qtyText: '$panels ชุด',
        ),
      HardwareItemSpec(
        code: '',
        name: 'ฉากประคองมุม TL 6.5 มิล',
        qtyText: '${panels * 4} ตัว',
      ),
    ]);

    return VerifiedFormulaTable(
      key: key,
      header: title,
      cuts: cuts,
      glasses: glasses,
      hardware: hw,
    );
  }

  static VerifiedFormulaTable _buildAlumetExtendedFixed({
    required String series,
    required int cols,
    required String transom, // plain | top | tb
    required String key,
    required String title,
  }) {
    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hw = <HardwareItemSpec>[];

    final hasTop = transom == 'top' || transom == 'tb';
    final hasBot = transom == 'tb';
    final hasTransom = hasTop || hasBot;
    final centerH = hasTransom ? 'H1' : 'H';
    final transomH = transom == 'tb' ? '(H - H1) / 2' : '(H - H1)';
    final transomBars = transom == 'tb' ? 2 : (hasTop ? 1 : 0);
    final cellGlassW = cols == 1
        ? 'W - 45'
        : '(W - ${45 + (cols - 1) * 26}) / $cols';

    if (series == 'sx') {
      cuts.addAll([
        _c('ชุดเฟรมช่องแสง', 'SF-X110', 'เฟรมข้างช่องแสง สมาร์ท เอ็กซ์', 'H', 2),
        _c('ชุดเฟรมช่องแสง', 'SF-X110', 'เฟรมบนช่องแสง สมาร์ท เอ็กซ์', 'W - 50', 1),
        _c('ชุดเฟรมช่องแสง', 'SF-X109', 'เฟรมล่างช่องแสง สมาร์ท เอ็กซ์', 'W - 50', 1),
        if (cols > 1)
          _c('ชุดซอยแบ่งช่อง', 'SF-X105', 'เสาซอยแบ่งช่องแนวตั้ง สมาร์ท เอ็กซ์', 'H - 50', cols - 1),
        if (transomBars > 0)
          _c('ชุดซอยแบ่งช่อง', 'SF-X105', 'ขวางแบ่งช่องแสงแนวนอน สมาร์ท เอ็กซ์', 'W - 50', transomBars),
        _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกแนวตั้ง สมาร์ท เอ็กซ์', '$centerH - 55', cols * 2),
        _c('คิ้วกระจก', 'SF-X108', 'คิ้วกระจกแนวนอน สมาร์ท เอ็กซ์', cellGlassW, cols * 2 * (1 + transomBars)),
      ]);
    } else if (series == 'nex') {
      cuts.addAll([
        _c('กรอบช่องแสงสลิม 1 นิ้ว', 'PF-0103', 'กล่องร่องข้างซ้าย/ขวา เน็กซ์', 'H', 2),
        _c('กรอบช่องแสงสลิม 1 นิ้ว', 'PF-0103', 'กล่องร่องบน เน็กซ์', 'W - 50.8', 1),
        _c('กรอบช่องแสงสลิม 1 นิ้ว', 'PF-0101', 'กล่องเปิดล่าง เน็กซ์', 'W - 50.8', 1),
        _c('กรอบช่องแสงสลิม 1 นิ้ว', 'PF-0102', 'ฝาปิดกล่องเปิดล่าง เน็กซ์', 'W - 50.8', 1),
        if (cols > 1)
          _c('ชุดซอยแบ่งช่อง', 'PF-0103', 'กล่องร่องซอยแนวตั้ง เน็กซ์', 'H - 50.8', cols - 1),
        if (transomBars > 0)
          _c('ชุดซอยแบ่งช่อง', 'PF-0103', 'กล่องร่องซอยแนวนอน เน็กซ์', 'W - 50.8', transomBars),
        _c('ชุดตบร่อง', 'A10261', 'ตบร่องช่องแสง เน็กซ์', 'H - 50.8', cols + 1),
        _c('ชุดตบร่อง', 'A10261', 'ตบร่องแนวนอน เน็กซ์', 'W - 50.8', 2 + transomBars),
      ]);
    } else {
      // Iconiq Euro
      cuts.addAll([
        _c('ชุดเฟรมช่องแสง', 'iF-0101', 'เฟรมข้างช่องแสง ไอคอนิค', 'H', 2),
        _c('ชุดเฟรมช่องแสง', 'iF-0101', 'เฟรมบนช่องแสง ไอคอนิค', 'W - 50', 1),
        _c('ชุดเฟรมช่องแสง', 'iF-0102', 'เฟรมล่างช่องแสง ไอคอนิค', 'W - 50', 1),
        if (cols > 1)
          _c('ชุดซอยแบ่งช่อง', 'iF-0104', 'ตบช่องแสง / เสาซอยแนวตั้ง ไอคอนิค', 'H - 50', cols - 1),
        if (transomBars > 0)
          _c('ชุดซอยแบ่งช่อง', 'iF-0104', 'ตบช่องแสงแนวนอน ไอคอนิค', 'W - 50', transomBars),
        _c('คิ้วกระจก', 'iO-0203', 'คิ้วกระจกช่องแสงแนวตั้ง ไอคอนิค', '$centerH - 60', cols * 2),
        _c('คิ้วกระจก', 'iO-0203', 'คิ้วกระจกช่องแสงแนวนอน ไอคอนิค', cellGlassW, cols * 2 * (1 + transomBars)),
      ]);
    }

    glasses.add(
      GlassPieceSpec(
        name: 'กระจกบานติดตายหลัก ($cols ช่อง)',
        siteCut: false,
        wFormula: cellGlassW,
        hFormula: '$centerH - 45',
        qty: cols,
        qtyText: '$cols แผ่น',
      ),
    );
    if (hasTop) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงบน ($cols ช่อง)',
          siteCut: false,
          wFormula: cellGlassW,
          hFormula: '$transomH - 30',
          qty: cols,
          qtyText: '$cols แผ่น',
        ),
      );
    }
    if (hasBot) {
      glasses.add(
        GlassPieceSpec(
          name: 'กระจกช่องแสงล่าง ($cols ช่อง)',
          siteCut: false,
          wFormula: cellGlassW,
          hFormula: '$transomH - 30',
          qty: cols,
          qtyText: '$cols แผ่น',
        ),
      );
    }

    hw.addAll([
      HardwareItemSpec(
        code: '',
        name: 'สกรูยึดเฟรมช่องแสง',
        qtyText: '${8 + cols * 4} ตัว',
      ),
      HardwareItemSpec(
        code: '',
        name: 'ยางอัดกระจกช่องแสง',
        qtyText: '$cols ชุด',
      ),
      const HardwareItemSpec(
        code: '',
        name: 'ซิลิโคนยาแนว',
        qtyText: '2 หลอด',
      ),
    ]);

    return VerifiedFormulaTable(
      key: key,
      header: title,
      cuts: cuts,
      glasses: glasses,
      hardware: hw,
    );
  }

  /// ICONIQ-ONLY Extended Swing Doors (Album 5: ชุดประตูบานเปิด — 9 new variants + 2 existing = 11 total)
  static VerifiedFormulaTable _buildIconiqExtendedSwingDoor({
    required String variant,
    required String key,
    required String title,
  }) {
    final cuts = <CutPieceSpec>[];
    final glasses = <GlassPieceSpec>[];
    final hw = <HardwareItemSpec>[];

    final isDouble = variant.startsWith('2_');
    final isLouver = variant.contains('louver');
    final isFramedLouver = variant.contains('louver_frame');
    final isSide1 = variant == '1_side1';
    final isSide2Glass = variant == '2_louver_side2_glass';
    final isSide2Louver = variant == '2_louver_side2_louver';
    final isSide2 = isSide2Glass || isSide2Louver;
    final isTop = variant == '2_top';
    final isArch = variant == '2_arch';
    final hDoor = (isTop || isArch) ? 'H1' : 'H';

    // Outer frame
    cuts.addAll([
      _c('วงกบประตู ICONIQ', 'iC-0101', 'วงกบข้างซ้าย/ขวา ไอคอนิค', isArch ? 'H1' : 'H', 2),
      if (!isArch)
        _c('วงกบประตู ICONIQ', 'iC-0101', 'วงกบบน ไอคอนิค', 'W - 50', 1),
      _c('วงกบประตู ICONIQ', 'iO-0101', 'ธรณีล่างประตูบานเปิด ไอคอนิค', 'W - 50', 1),
      _c('ตบร่องเฟรม', 'SC-X105', 'ตบร่องเฟรมข้าง ไอคอนิค', isArch ? 'H1' : 'H', 2),
      if (!isArch)
        _c('ตบร่องเฟรม', 'SC-X105', 'ตบร่องเฟรมบน ไอคอนิค', 'W - 50', 1),
    ]);

    // Door sash dimensions
    final String sashWFormula;
    final int sashVertQty = isDouble ? 4 : 2;
    final int sashHorizQty = isDouble ? 4 : 2;
    if (isSide1) {
      sashWFormula = 'W_f - 36';
    } else if (isSide2) {
      sashWFormula = '(W_f - 26) / 2';
    } else if (isDouble) {
      sashWFormula = '(W - 26) / 2';
    } else {
      sashWFormula = 'W - 36';
    }

    cuts.addAll([
      _c('กรอบบานประตู ICONIQ', 'iO-0201', 'กรอบบานประตูแนวตั้ง ไอคอนิค', '$hDoor - 36', sashVertQty, angle: '45° / 45°'),
      _c('กรอบบานประตู ICONIQ', 'iO-0201', 'กรอบบานประตูแนวนอน ไอคอนิค', sashWFormula, sashHorizQty, angle: '45° / 45°'),
      if (isDouble)
        _c('กรอบบานประตู ICONIQ', 'SC-0212', 'เสริมเสาบานเปิดคู่ ไอคอนิค', '$hDoor - 36', 1),
    ]);

    // Infill: Aluminum Louver/Slat vs Glass
    if (isLouver) {
      final slatsPerLeaf = isFramedLouver ? 16 : 18;
      final totalSlats = isDouble ? slatsPerLeaf * 2 : slatsPerLeaf;
      final slatW = isSide2
          ? '((W_f - 26) / 2) - 160'
          : (isDouble ? '((W - 26) / 2) - 160' : 'W - 196');
      cuts.addAll([
        _c('ลูกฟัก / เกล็ดอลูมิเนียม', 'iO-0205', 'ใบเกล็ด/ลูกฟักอลูมิเนียม ประตู ไอคอนิค', slatW, totalSlats),
        _c('คิ้วลูกฟัก', 'iO-0203', 'คิ้วกรอบบานแนวตั้ง ไอคอนิค', '$hDoor - 167', sashVertQty),
        _c('คิ้วลูกฟัก', 'iO-0203', 'คิ้วกรอบบานแนวนอน ไอคอนิค', slatW, isFramedLouver ? sashHorizQty * 2 : sashHorizQty),
      ]);
    } else {
      final glassW = isSide1
          ? 'W_f - 196'
          : (isDouble ? '((W - 26) / 2) - 160' : 'W - 196');
      cuts.addAll([
        _c('คิ้วกระจกประตู', 'iO-0203', 'คิ้วกระจกแนวนอน ไอคอนิค', glassW, sashHorizQty),
        _c('คิ้วกระจกประตู', 'iO-0203', 'คิ้วกระจกแนวตั้ง ไอคอนิค', '$hDoor - 167', sashVertQty),
      ]);
      glasses.add(
        GlassPieceSpec(
          name: isDouble ? 'กระจกบานประตูคู่ (2 บาน)' : 'กระจกบานประตูเดี่ยว',
          siteCut: false,
          wFormula: glassW,
          hFormula: '$hDoor - 170',
          qty: isDouble ? 2 : 1,
          qtyText: isDouble ? '2 แผ่น' : '1 แผ่น',
        ),
      );
    }

    // Sidelights & Transoms
    if (isSide1) {
      cuts.addAll([
        _c('ช่องแสงข้าง 1 ช่อง', 'iF-0104', 'เสาซอยแบ่งช่องแสงข้าง ไอคอนิค', 'H - 50', 1),
        _c('ช่องแสงข้าง 1 ช่อง', 'iO-0203', 'คิ้วกระจกช่องแสงข้างแนวตั้ง', 'H - 80', 2),
        _c('ช่องแสงข้าง 1 ช่อง', 'iO-0203', 'คิ้วกระจกช่องแสงข้างแนวนอน', '(W - W_f) - 55', 2),
      ]);
      glasses.add(
        const GlassPieceSpec(
          name: 'กระจกช่องแสงข้างประตู',
          siteCut: false,
          wFormula: '(W - W_f) - 50',
          hFormula: 'H - 55',
          qty: 1,
          qtyText: '1 แผ่น',
        ),
      );
    } else if (isSide2) {
      cuts.addAll([
        _c('ช่องข้างซ้าย-ขวา', 'iF-0104', 'เสาซอยแบ่งช่องข้างซ้าย-ขวา ไอคอนิค', 'H - 50', 2),
        _c('ช่องข้างซ้าย-ขวา', 'iO-0203', 'คิ้วกรอบช่องข้างแนวตั้ง', 'H - 80', 4),
        _c('ช่องข้างซ้าย-ขวา', 'iO-0203', 'คิ้วกรอบช่องข้างแนวนอน', '((W - W_f) / 2) - 50', 4),
      ]);
      if (isSide2Louver) {
        cuts.add(
          _c('ช่องเกล็ดซ้าย-ขวา', 'iO-0205', 'ใบเกล็ดอลูมิเนียมช่องข้างซ้าย-ขวา ไอคอนิค', '((W - W_f) / 2) - 55', 32),
        );
      } else {
        glasses.add(
          const GlassPieceSpec(
            name: 'กระจกช่องแสงซ้าย-ขวา (2 ช่อง)',
            siteCut: false,
            wFormula: '((W - W_f) / 2) - 45',
            hFormula: 'H - 55',
            qty: 2,
            qtyText: '2 แผ่น',
          ),
        );
      }
    } else if (isTop) {
      cuts.addAll([
        _c('ช่องแสงบน', 'iF-0104', 'ขวางแบ่งช่องแสงบน ไอคอนิค', 'W - 50', 1),
        _c('ช่องแสงบน', 'iO-0203', 'คิ้วกระจกช่องแสงบนแนวนอน', 'W - 80', 2),
        _c('ช่องแสงบน', 'iO-0203', 'คิ้วกระจกช่องแสงบนแนวตั้ง', '(H - H1) - 40', 2),
      ]);
      glasses.add(
        const GlassPieceSpec(
          name: 'กระจกช่องแสงบนประตู',
          siteCut: false,
          wFormula: 'W - 60',
          hFormula: '(H - H1) - 35',
          qty: 1,
          qtyText: '1 แผ่น',
        ),
      );
    } else if (isArch) {
      cuts.addAll([
        _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0101', 'เฟรมดัดโค้งช่องแสงบน ไอคอนิค (เผื่อดัดโค้ง)', '(W * 1.571) + 100', 1),
        _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0104', 'ขวางฐานช่องแสงโค้ง ไอคอนิค', 'W - 50', 1),
        _c('ช่องแสงโค้งครึ่งวงกลม', 'iF-0104', 'ซี่รัศมีแบ่งช่องแสงโค้ง ไอคอนิค', '(W / 2) - 40', 4),
        _c('ช่องแสงโค้งครึ่งวงกลม', 'iO-0203', 'คิ้วกระจกดัดโค้งช่องแสงบน ไอคอนิค', '(W * 1.571) + 60', 1),
      ]);
      glasses.add(
        const GlassPieceSpec(
          name: 'กระจกช่องแสงโค้งครึ่งวงกลม (วัดตัดตามแบบโค้งหน้างาน)',
          siteCut: true,
          qty: 4,
          qtyText: '4 แผ่น',
        ),
      );
    }

    hw.addAll([
      HardwareItemSpec(
        code: '',
        name: 'บานพับประตูบานเปิด ไอคอนิค',
        qtyText: isDouble ? '6 ตัว' : '3 ตัว',
      ),
      const HardwareItemSpec(
        code: '',
        name: 'ชุดกุญแจมือจับก้านโยกประตู ไอคอนิค',
        qtyText: '1 ชุด',
      ),
      if (isDouble)
        const HardwareItemSpec(
          code: '',
          name: 'กลอนฝังประตูบานคู่ (Flush Bolt)',
          qtyText: '2 ตัว',
        ),
      HardwareItemSpec(
        code: '',
        name: 'ฉากยึดมุมกรอบบานประตู',
        qtyText: isDouble ? '8 ตัว' : '4 ตัว',
      ),
    ]);

    return VerifiedFormulaTable(
      key: key,
      header: title,
      cuts: cuts,
      glasses: glasses,
      hardware: hw,
    );
  }
}
