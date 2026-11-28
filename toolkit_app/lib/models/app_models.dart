import 'dart:convert';

enum InputTableMode {
  /// Standard VIP multi-size table: starts with 1 row (W, H, Qty=1) + '+ เพิ่มขนาดอื่น'
  standardMultiRow,

  /// Fuji Eurotech (Cat 3): pre-renders 4 blank rows with Qty=1
  fujiFourRow,

  /// SMART PLUS Euro 90°: 4 columns (กว้าง W | สูง H | สูง H1 | จำนวน) + H/H1 guide button
  smartPlus90FourCol,

  /// Single-set form with W, H, Qty (and optional H1 / H_t / W2 / W_f)
  singleSet,

  /// Corner 90° form with W1 (left), W2 (right), H, Qty
  cornerW1W2,
}

enum AuxDimensionType {
  none,
  /// Reference height H1 of main sliding/door/window section (transom = H - H1)
  refHeightH1,
  /// Direct transom / bottom-fix height H_t (main section = H - H_t)
  transomHeightHt,
  /// Side fixed width W_f (e.g. HOMELIFE 250-004-CG)
  sideFixWf,
  /// Second casement width W2 (e.g. HOMELIFE 260-002-CM/FM/NM)
  secondWidthW2,
}

enum OptionControlType {
  chips,
  dropdown,
  checkbox,
  switchToggle,
}

class OptionChoice {
  final String id;
  final String label;
  final String? subtitle;
  final bool enabled;
  final String? disabledBadge;

  const OptionChoice({
    required this.id,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.disabledBadge,
  });
}

class OptionGroupDef {
  final String id;
  final String title;
  final OptionControlType controlType;
  final List<OptionChoice> choices;
  final String defaultValue;

  const OptionGroupDef({
    required this.id,
    required this.title,
    this.controlType = OptionControlType.chips,
    required this.choices,
    required this.defaultValue,
  });
}

class PatternCardDef {
  final String id;
  final String title;
  final String? subtitle;
  final String? warningBadge; // e.g. 'รางตบรอยืนยัน' (still enabled!)
  final bool enabled;
  final String? disabledBadge; // e.g. 'รออัปเดต', 'รอสูตรคำนวณ'
  final String baseFormulaKey;
  final InputTableMode tableMode;
  final AuxDimensionType auxType;
  final String? auxLabel;
  final List<OptionGroupDef> optionGroups;
  // Optional parametric folding metadata (N-L-R)
  final int? foldingTotalPanels;
  final int? foldingLeftPanels;
  final int? foldingRightPanels;
  final String? foldingFamily; // 'orm90', 'orm101', 'fuji_std', 'fuji_u', 'sch240', 'sp_fold', 'alu_fold'

  const PatternCardDef({
    required this.id,
    required this.title,
    this.subtitle,
    this.warningBadge,
    this.enabled = true,
    this.disabledBadge,
    this.baseFormulaKey = '',
    this.tableMode = InputTableMode.standardMultiRow,
    this.auxType = AuxDimensionType.none,
    this.auxLabel,
    this.optionGroups = const [],
    this.foldingTotalPanels,
    this.foldingLeftPanels,
    this.foldingRightPanels,
    this.foldingFamily,
  });
}

class SubSystemDef {
  final String id;
  final String title;
  final String? subtitle;
  final bool enabled;
  final String? disabledBadge;
  final String? emptyMessage; // e.g. 'ยังไม่มีระบบที่เปิดใช้งาน'
  final List<PatternCardDef> patterns;
  /// Optional sub-tabs (e.g. SMART PLUS Euro 'เฟรมประกอบ 45°' / 'เฟรมประกอบ 90°' or ALUFRAME tabs)
  final List<SubSystemDef> subTabs;

  const SubSystemDef({
    required this.id,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.disabledBadge,
    this.emptyMessage,
    this.patterns = const [],
    this.subTabs = const [],
  });
}

class BrandDef {
  final String id;
  final String title;
  final String subtitle;
  final String priceBrandKey; // 'ORM', 'SCHIMMER', 'ALUMET', 'SMART_PLUS', 'UAI', 'FUJI', 'ALUFRAME', 'MARKET'
  final bool enabled;
  final String? disabledBadge;
  final List<SubSystemDef> systems;
  /// Direct patterns when a brand skips sub-system menu
  final List<PatternCardDef> directPatterns;

  const BrandDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceBrandKey,
    this.enabled = true,
    this.disabledBadge,
    this.systems = const [],
    this.directPatterns = const [],
  });
}

class CategoryDef {
  final String id;
  final String title;
  final String subtitle;
  final bool enabled;
  final String? disabledBadge;
  final List<BrandDef> brands;
  final List<SubSystemDef> directSystems;

  const CategoryDef({
    required this.id,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.disabledBadge,
    this.brands = const [],
    this.directSystems = const [],
  });
}

class SizeRowInput {
  final double widthMm;
  final double heightMm;
  final double? auxMm; // H1, H_t, W2, or W_f
  final int qty;

  const SizeRowInput({
    required this.widthMm,
    required this.heightMm,
    this.auxMm,
    this.qty = 1,
  });

  Map<String, dynamic> toJson() => {
        'widthMm': widthMm,
        'heightMm': heightMm,
        if (auxMm != null) 'auxMm': auxMm,
        'qty': qty,
      };

  factory SizeRowInput.fromJson(Map<String, dynamic> j) => SizeRowInput(
        widthMm: (j['widthMm'] as num).toDouble(),
        heightMm: (j['heightMm'] as num).toDouble(),
        auxMm: j['auxMm'] != null ? (j['auxMm'] as num).toDouble() : null,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
      );
}

class CutPieceSpec {
  final String section;
  final String code;
  final String name;
  final int stockMm;
  final int qty;
  final String qtyText;
  final String angle;
  final String formula;
  final String? brandOverride;

  const CutPieceSpec({
    required this.section,
    required this.code,
    required this.name,
    required this.stockMm,
    required this.qty,
    required this.qtyText,
    required this.angle,
    required this.formula,
    this.brandOverride,
  });

  factory CutPieceSpec.fromJson(Map<String, dynamic> j) => CutPieceSpec(
        section: j['section'] as String? ?? 'อลูมิเนียม',
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        stockMm: (j['stockMm'] as num?)?.toInt() ?? 6400,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        qtyText: j['qtyText'] as String? ?? '1 ชิ้น',
        angle: j['angle'] as String? ?? '90° / 90°',
        formula: j['formula'] as String? ?? 'วัดตามจริง',
        brandOverride: j['brandOverride'] as String?,
      );

  CutPieceSpec copyWith({
    String? section,
    String? code,
    String? name,
    int? stockMm,
    int? qty,
    String? qtyText,
    String? angle,
    String? formula,
    String? brandOverride,
  }) =>
      CutPieceSpec(
        section: section ?? this.section,
        code: code ?? this.code,
        name: name ?? this.name,
        stockMm: stockMm ?? this.stockMm,
        qty: qty ?? this.qty,
        qtyText: qtyText ?? this.qtyText,
        angle: angle ?? this.angle,
        formula: formula ?? this.formula,
        brandOverride: brandOverride ?? this.brandOverride,
      );

  Map<String, dynamic> toJson() => {
        'section': section,
        'code': code,
        'name': name,
        'stockMm': stockMm,
        'qty': qty,
        'qtyText': qtyText,
        'angle': angle,
        'formula': formula,
        if (brandOverride != null && brandOverride!.trim().isNotEmpty)
          'brandOverride': brandOverride!.trim(),
      };
}

class GlassPieceSpec {
  final String name;
  final int qty;
  final String qtyText;
  final bool siteCut;
  final String wFormula;
  final String hFormula;

  const GlassPieceSpec({
    required this.name,
    required this.qty,
    required this.qtyText,
    required this.siteCut,
    this.wFormula = '',
    this.hFormula = '',
  });

  factory GlassPieceSpec.fromJson(Map<String, dynamic> j) => GlassPieceSpec(
        name: j['name'] as String? ?? 'กระจก',
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        qtyText: j['qtyText'] as String? ?? '1 แผ่น',
        siteCut: j['siteCut'] as bool? ?? true,
        wFormula: j['wFormula'] as String? ?? '',
        hFormula: j['hFormula'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'qtyText': qtyText,
        'siteCut': siteCut,
        'wFormula': wFormula,
        'hFormula': hFormula,
      };
}

class HardwareItemSpec {
  final String code;
  final String name;
  final String qtyText;

  const HardwareItemSpec({
    required this.code,
    required this.name,
    required this.qtyText,
  });

  factory HardwareItemSpec.fromJson(Map<String, dynamic> j) => HardwareItemSpec(
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        qtyText: j['qtyText'] as String? ?? '1 ชิ้น',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'qtyText': qtyText,
      };
}

class VerifiedFormulaTable {
  final String key;
  final String header;
  final List<CutPieceSpec> cuts;
  final List<GlassPieceSpec> glasses;
  final List<HardwareItemSpec> hardware;

  const VerifiedFormulaTable({
    required this.key,
    required this.header,
    required this.cuts,
    required this.glasses,
    required this.hardware,
  });

  factory VerifiedFormulaTable.fromJson(Map<String, dynamic> j) =>
      VerifiedFormulaTable(
        key: j['key'] as String,
        header: j['header'] as String,
        cuts: (j['cuts'] as List<dynamic>? ?? [])
            .map((e) => CutPieceSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        glasses: (j['glasses'] as List<dynamic>? ?? [])
            .map((e) => GlassPieceSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        hardware: (j['hardware'] as List<dynamic>? ?? [])
            .map((e) => HardwareItemSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'header': header,
        'cuts': cuts.map((e) => e.toJson()).toList(),
        'glasses': glasses.map((e) => e.toJson()).toList(),
        'hardware': hardware.map((e) => e.toJson()).toList(),
      };
}

class EvaluatedCutItem {
  final String section;
  final String code;
  final String name;
  final int stockMm;
  final bool isSiteMeasured;
  final double? lengthMm;
  final double? estimatedTotalMm;
  final int qtyPerSet;
  final int totalQty;
  final String angle;
  final String? brandOverride;

  const EvaluatedCutItem({
    required this.section,
    required this.code,
    required this.name,
    required this.stockMm,
    required this.isSiteMeasured,
    this.lengthMm,
    this.estimatedTotalMm,
    required this.qtyPerSet,
    required this.totalQty,
    required this.angle,
    this.brandOverride,
  });

  EvaluatedCutItem copyWith({
    String? section,
    String? code,
    String? name,
    int? stockMm,
    bool? isSiteMeasured,
    double? lengthMm,
    bool clearLengthMm = false,
    double? estimatedTotalMm,
    bool clearEstimatedTotalMm = false,
    int? qtyPerSet,
    int? totalQty,
    String? angle,
    String? brandOverride,
    bool clearBrandOverride = false,
  }) =>
      EvaluatedCutItem(
        section: section ?? this.section,
        code: code ?? this.code,
        name: name ?? this.name,
        stockMm: stockMm ?? this.stockMm,
        isSiteMeasured: isSiteMeasured ?? this.isSiteMeasured,
        lengthMm: clearLengthMm ? null : (lengthMm ?? this.lengthMm),
        estimatedTotalMm: clearEstimatedTotalMm
            ? null
            : (estimatedTotalMm ?? this.estimatedTotalMm),
        qtyPerSet: qtyPerSet ?? this.qtyPerSet,
        totalQty: totalQty ?? this.totalQty,
        angle: angle ?? this.angle,
        brandOverride:
            clearBrandOverride ? null : (brandOverride ?? this.brandOverride),
      );

  Map<String, dynamic> toJson() => {
        'section': section,
        'code': code,
        'name': name,
        'stockMm': stockMm,
        'isSiteMeasured': isSiteMeasured,
        'lengthMm': lengthMm,
        'estimatedTotalMm': estimatedTotalMm,
        'qtyPerSet': qtyPerSet,
        'totalQty': totalQty,
        'angle': angle,
        if (brandOverride != null && brandOverride!.trim().isNotEmpty)
          'brandOverride': brandOverride!.trim(),
      };

  factory EvaluatedCutItem.fromJson(Map<String, dynamic> j) => EvaluatedCutItem(
        section: j['section'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        stockMm: (j['stockMm'] as num).toInt(),
        isSiteMeasured: j['isSiteMeasured'] as bool,
        lengthMm: (j['lengthMm'] as num?)?.toDouble(),
        estimatedTotalMm: (j['estimatedTotalMm'] as num?)?.toDouble(),
        qtyPerSet: (j['qtyPerSet'] as num).toInt(),
        totalQty: (j['totalQty'] as num).toInt(),
        angle: j['angle'] as String,
        brandOverride: j['brandOverride'] as String?,
      );
}

class EvaluatedGlassItem {
  final String name;
  final bool siteCut;
  final double? widthMm;
  final double? heightMm;
  final int totalPanels;
  final int setIndex;

  const EvaluatedGlassItem({
    required this.name,
    required this.siteCut,
    this.widthMm,
    this.heightMm,
    required this.totalPanels,
    required this.setIndex,
  });

  EvaluatedGlassItem copyWith({
    String? name,
    bool? siteCut,
    double? widthMm,
    bool clearWidthMm = false,
    double? heightMm,
    bool clearHeightMm = false,
    int? totalPanels,
    int? setIndex,
  }) =>
      EvaluatedGlassItem(
        name: name ?? this.name,
        siteCut: siteCut ?? this.siteCut,
        widthMm: clearWidthMm ? null : (widthMm ?? this.widthMm),
        heightMm: clearHeightMm ? null : (heightMm ?? this.heightMm),
        totalPanels: totalPanels ?? this.totalPanels,
        setIndex: setIndex ?? this.setIndex,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'siteCut': siteCut,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'totalPanels': totalPanels,
        'setIndex': setIndex,
      };

  factory EvaluatedGlassItem.fromJson(Map<String, dynamic> j) =>
      EvaluatedGlassItem(
        name: j['name'] as String,
        siteCut: j['siteCut'] as bool,
        widthMm: (j['widthMm'] as num?)?.toDouble(),
        heightMm: (j['heightMm'] as num?)?.toDouble(),
        totalPanels: (j['totalPanels'] as num).toInt(),
        setIndex: (j['setIndex'] as num?)?.toInt() ?? 1,
      );
}

class EvaluatedSetResult {
  final int setIndex;
  final SizeRowInput sizeRow;
  final List<EvaluatedCutItem> cuts;
  final List<EvaluatedGlassItem> glasses;

  const EvaluatedSetResult({
    required this.setIndex,
    required this.sizeRow,
    required this.cuts,
    required this.glasses,
  });

  EvaluatedSetResult copyWith({
    int? setIndex,
    SizeRowInput? sizeRow,
    List<EvaluatedCutItem>? cuts,
    List<EvaluatedGlassItem>? glasses,
  }) =>
      EvaluatedSetResult(
        setIndex: setIndex ?? this.setIndex,
        sizeRow: sizeRow ?? this.sizeRow,
        cuts: cuts ?? this.cuts,
        glasses: glasses ?? this.glasses,
      );

  Map<String, dynamic> toJson() => {
        'setIndex': setIndex,
        'sizeRow': sizeRow.toJson(),
        'cuts': cuts.map((e) => e.toJson()).toList(),
        'glasses': glasses.map((e) => e.toJson()).toList(),
      };

  factory EvaluatedSetResult.fromJson(Map<String, dynamic> j) =>
      EvaluatedSetResult(
        setIndex: (j['setIndex'] as num).toInt(),
        sizeRow: SizeRowInput.fromJson(j['sizeRow'] as Map<String, dynamic>),
        cuts: (j['cuts'] as List<dynamic>)
            .map((e) => EvaluatedCutItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        glasses: (j['glasses'] as List<dynamic>)
            .map((e) => EvaluatedGlassItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AggregatedHardwareItem {
  final String code;
  final String name;
  final int? numericQty;
  final double? decimalQty;
  final String unitOrNote;

  const AggregatedHardwareItem({
    required this.code,
    required this.name,
    this.numericQty,
    this.decimalQty,
    required this.unitOrNote,
  });

  double? get effectiveQty => decimalQty ?? numericQty?.toDouble();

  AggregatedHardwareItem copyWith({
    String? code,
    String? name,
    int? numericQty,
    bool clearNumericQty = false,
    double? decimalQty,
    bool clearDecimalQty = false,
    String? unitOrNote,
  }) =>
      AggregatedHardwareItem(
        code: code ?? this.code,
        name: name ?? this.name,
        numericQty: clearNumericQty ? null : (numericQty ?? this.numericQty),
        decimalQty: clearDecimalQty ? null : (decimalQty ?? this.decimalQty),
        unitOrNote: unitOrNote ?? this.unitOrNote,
      );

  String get displayQty {
    if (decimalQty != null) {
      return '${decimalQty!.toStringAsFixed(2)} $unitOrNote';
    }
    return numericQty != null ? '$numericQty $unitOrNote' : unitOrNote;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'numericQty': numericQty,
        if (decimalQty != null) 'decimalQty': decimalQty,
        'unitOrNote': unitOrNote,
      };

  factory AggregatedHardwareItem.fromJson(Map<String, dynamic> j) =>
      AggregatedHardwareItem(
        code: j['code'] as String,
        name: j['name'] as String,
        numericQty: (j['numericQty'] as num?)?.toInt(),
        decimalQty: (j['decimalQty'] as num?)?.toDouble(),
        unitOrNote: j['unitOrNote'] as String,
      );
}

class PlacedCut {
  final double lengthMm;
  final String partName;
  final String? itemTag; // e.g. '[01]' in project-wide bin packing

  const PlacedCut({
    required this.lengthMm,
    required this.partName,
    this.itemTag,
  });
}

class BarAssignment {
  final int barIndex;
  final int stockLengthMm;
  final List<PlacedCut> cuts;

  const BarAssignment({
    required this.barIndex,
    required this.stockLengthMm,
    required this.cuts,
  });

  int get usableLengthMm => stockLengthMm - 100;
  int get kerfTotalMm => cuts.length > 1 ? (cuts.length - 1) * 4 : 0;
  double get usedLengthMm =>
      cuts.fold(0.0, (sum, c) => sum + c.lengthMm) + kerfTotalMm;
  double get remnantMm => usableLengthMm - usedLengthMm;
}

class ProfileBarGroup {
  final String brand;
  final String code;
  final String combinedNames;
  final int stockLengthMm;
  final List<BarAssignment> confirmedBars;
  final int estimatedBars;
  final double exactCutSumMm;
  final String? specThickness;
  final String? specColor;

  const ProfileBarGroup({
    required this.brand,
    required this.code,
    required this.combinedNames,
    required this.stockLengthMm,
    required this.confirmedBars,
    this.estimatedBars = 0,
    required this.exactCutSumMm,
    this.specThickness,
    this.specColor,
  });

  int get totalBars => confirmedBars.length + estimatedBars;
  double get totalRemnantMm =>
      confirmedBars.fold(0.0, (s, b) => s + b.remnantMm);
}

class CalculationOutput {
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final String patternId;
  final String patternTitle;
  final Map<String, String> selectedOptions;
  final List<EvaluatedSetResult> sets;
  final List<AggregatedHardwareItem> hardware;
  final List<ProfileBarGroup> barGroups;

  const CalculationOutput({
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.patternId,
    required this.patternTitle,
    required this.selectedOptions,
    required this.sets,
    required this.hardware,
    required this.barGroups,
  });

  CalculationOutput copyWith({
    String? brandTitle,
    String? priceBrandKey,
    String? systemTitle,
    String? patternId,
    String? patternTitle,
    Map<String, String>? selectedOptions,
    List<EvaluatedSetResult>? sets,
    List<AggregatedHardwareItem>? hardware,
    List<ProfileBarGroup>? barGroups,
  }) =>
      CalculationOutput(
        brandTitle: brandTitle ?? this.brandTitle,
        priceBrandKey: priceBrandKey ?? this.priceBrandKey,
        systemTitle: systemTitle ?? this.systemTitle,
        patternId: patternId ?? this.patternId,
        patternTitle: patternTitle ?? this.patternTitle,
        selectedOptions: selectedOptions ?? this.selectedOptions,
        sets: sets ?? this.sets,
        hardware: hardware ?? this.hardware,
        barGroups: barGroups ?? this.barGroups,
      );

  int get totalSetsCount => sets.fold(0, (s, e) => s + e.sizeRow.qty);
  int get totalStockBars => barGroups.fold(0, (s, g) => s + g.totalBars);
  double get totalRemnantMm => barGroups.fold(0.0, (s, g) => s + g.totalRemnantMm);

  Map<String, dynamic> toJson() => {
        'brandTitle': brandTitle,
        'priceBrandKey': priceBrandKey,
        'systemTitle': systemTitle,
        'patternId': patternId,
        'patternTitle': patternTitle,
        'selectedOptions': selectedOptions,
        'sets': sets.map((e) => e.toJson()).toList(),
        'hardware': hardware.map((e) => e.toJson()).toList(),
      };
}

class OrmPriceSku {
  final String brand;
  final String code;
  final String name;
  final String thickness;
  final String color;
  final double stockM;
  final double factoryPrice;
  final double? customPrice;
  final bool inStock;
  final bool isEstimated;

  const OrmPriceSku({
    required this.brand,
    required this.code,
    required this.name,
    required this.thickness,
    required this.color,
    required this.stockM,
    required this.factoryPrice,
    this.customPrice,
    this.inStock = true,
    this.isEstimated = false,
  });

  double get effectivePrice => customPrice ?? factoryPrice;
  String get skuKey => '$brand|$code|$thickness|$color';

  factory OrmPriceSku.fromJson(Map<String, dynamic> j) => OrmPriceSku(
        brand: j['brand'] as String? ?? 'ORM',
        code: j['code'] as String,
        name: j['name'] as String,
        thickness: j['thickness'] as String,
        color: j['color'] as String,
        stockM: (j['stockM'] as num).toDouble(),
        factoryPrice: (j['price'] as num).toDouble(),
        isEstimated: j['isEstimated'] as bool? ?? false,
      );

  OrmPriceSku withOverride(double? overridePrice, {bool? stock}) => OrmPriceSku(
        brand: brand,
        code: code,
        name: name,
        thickness: thickness,
        color: color,
        stockM: stockM,
        factoryPrice: factoryPrice,
        customPrice: overridePrice,
        inStock: stock ?? inStock,
        isEstimated: isEstimated,
      );
}

class ShopInfo {
  final String shopName;
  final String defaultDocTitle;
  final String proposerName;
  final String address;
  final String phone;
  final String email;
  final String taxId;
  final String? logoPath;

  const ShopInfo({
    this.shopName = '',
    this.defaultDocTitle = 'ใบเสนอราคา',
    this.proposerName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxId = '',
    this.logoPath,
  });

  bool get isConfigured => shopName.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': 1,
        'shop_name': shopName,
        'default_doc_title': defaultDocTitle,
        'proposer_name': proposerName,
        'address': address,
        'phone': phone,
        'email': email,
        'tax_id': taxId,
        'logo_path': logoPath,
      };

  factory ShopInfo.fromMap(Map<String, dynamic> m) => ShopInfo(
        shopName: m['shop_name'] as String? ?? '',
        defaultDocTitle: m['default_doc_title'] as String? ?? 'ใบเสนอราคา',
        proposerName: m['proposer_name'] as String? ?? '',
        address: m['address'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        email: m['email'] as String? ?? '',
        taxId: m['tax_id'] as String? ?? '',
        logoPath: m['logo_path'] as String?,
      );
}

class SavedProjectItem {
  final int? id;
  final int projectId;
  final int sortIndex;
  final String refCode;
  final String installLocation;
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final String patternId;
  final String patternTitle;
  final Map<String, String> selectedOptions;
  final List<SizeRowInput> sizeRows;
  final List<EvaluatedSetResult> evaluatedSets;
  final List<AggregatedHardwareItem> hardware;

  const SavedProjectItem({
    this.id,
    required this.projectId,
    required this.sortIndex,
    this.refCode = '',
    this.installLocation = '',
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.patternId,
    required this.patternTitle,
    required this.selectedOptions,
    required this.sizeRows,
    required this.evaluatedSets,
    required this.hardware,
  });

  String displayOrderTag(int oneBasedIdx) =>
      refCode.trim().isNotEmpty ? refCode.trim() : oneBasedIdx.toString().padLeft(2, '0');

  int get totalUnits => sizeRows.fold(0, (s, r) => s + r.qty);

  double get totalOpeningAreaSqM => sizeRows.fold(
        0.0,
        (s, r) => s + ((r.widthMm * r.heightMm) / 1000000.0) * r.qty,
      );

  String get sizeSummaryText => sizeRows
      .map((r) => '${r.widthMm.toStringAsFixed(1)} × ${r.heightMm.toStringAsFixed(1)} (${r.qty})')
      .join(', ');

  SavedProjectItem copyWith({
    int? id,
    int? projectId,
    int? sortIndex,
    String? refCode,
    String? installLocation,
    String? brandTitle,
    String? priceBrandKey,
    String? systemTitle,
    String? patternId,
    String? patternTitle,
    Map<String, String>? selectedOptions,
    List<SizeRowInput>? sizeRows,
    List<EvaluatedSetResult>? evaluatedSets,
    List<AggregatedHardwareItem>? hardware,
  }) =>
      SavedProjectItem(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        sortIndex: sortIndex ?? this.sortIndex,
        refCode: refCode ?? this.refCode,
        installLocation: installLocation ?? this.installLocation,
        brandTitle: brandTitle ?? this.brandTitle,
        priceBrandKey: priceBrandKey ?? this.priceBrandKey,
        systemTitle: systemTitle ?? this.systemTitle,
        patternId: patternId ?? this.patternId,
        patternTitle: patternTitle ?? this.patternTitle,
        selectedOptions: selectedOptions ?? this.selectedOptions,
        sizeRows: sizeRows ?? this.sizeRows,
        evaluatedSets: evaluatedSets ?? this.evaluatedSets,
        hardware: hardware ?? this.hardware,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'project_id': projectId,
        'sort_index': sortIndex,
        'ref_code': refCode,
        'install_location': installLocation,
        'brand_title': brandTitle,
        'price_brand_key': priceBrandKey,
        'system_title': systemTitle,
        'pattern_id': patternId,
        'pattern_title': patternTitle,
        'selected_options_json': jsonEncode(selectedOptions),
        'size_rows_json': jsonEncode(sizeRows.map((e) => e.toJson()).toList()),
        'evaluated_sets_json':
            jsonEncode(evaluatedSets.map((e) => e.toJson()).toList()),
        'hardware_json': jsonEncode(hardware.map((e) => e.toJson()).toList()),
      };

  factory SavedProjectItem.fromMap(Map<String, dynamic> m) => SavedProjectItem(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        sortIndex: m['sort_index'] as int? ?? 0,
        refCode: m['ref_code'] as String? ?? '',
        installLocation: m['install_location'] as String? ?? '',
        brandTitle: m['brand_title'] as String,
        priceBrandKey: m['price_brand_key'] as String,
        systemTitle: m['system_title'] as String,
        patternId: m['pattern_id'] as String,
        patternTitle: m['pattern_title'] as String,
        selectedOptions: Map<String, String>.from(
            jsonDecode(m['selected_options_json'] as String) as Map),
        sizeRows: (jsonDecode(m['size_rows_json'] as String) as List<dynamic>)
            .map((e) => SizeRowInput.fromJson(e as Map<String, dynamic>))
            .toList(),
        evaluatedSets:
            (jsonDecode(m['evaluated_sets_json'] as String) as List<dynamic>)
                .map((e) =>
                    EvaluatedSetResult.fromJson(e as Map<String, dynamic>))
                .toList(),
        hardware: (jsonDecode(m['hardware_json'] as String) as List<dynamic>)
            .map((e) =>
                AggregatedHardwareItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SavedProject {
  final int? id;
  final String name;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SavedProjectItem> items;

  const SavedProject({
    this.id,
    required this.name,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  double get totalOpeningAreaSqM =>
      items.fold(0.0, (sum, it) => sum + it.totalOpeningAreaSqM);
}

class QuotationLineEntry {
  final String label;
  final String subtitle;
  final String sizeText;
  final int qty;
  final double unitPrice;
  final bool confirmed;
  final String? patternId;
  final String? imageAssetPath;

  const QuotationLineEntry({
    required this.label,
    required this.subtitle,
    required this.sizeText,
    required this.qty,
    required this.unitPrice,
    this.confirmed = false,
    this.patternId,
    this.imageAssetPath,
  });

  double get lineTotal => unitPrice * qty;

  Map<String, dynamic> toJson() => {
        'label': label,
        'subtitle': subtitle,
        'sizeText': sizeText,
        'qty': qty,
        'unitPrice': unitPrice,
        'confirmed': confirmed,
        if (patternId != null && patternId!.isNotEmpty) 'patternId': patternId,
        if (imageAssetPath != null && imageAssetPath!.isNotEmpty)
          'imageAssetPath': imageAssetPath,
      };

  factory QuotationLineEntry.fromJson(Map<String, dynamic> j) =>
      QuotationLineEntry(
        label: j['label'] as String,
        subtitle: j['subtitle'] as String,
        sizeText: j['sizeText'] as String,
        qty: (j['qty'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        confirmed: j['confirmed'] as bool? ?? true,
        patternId: j['patternId'] as String?,
        imageAssetPath: j['imageAssetPath'] as String?,
      );
}

class SavedQuotation {
  final int? id;
  final int projectId;
  final String qtNumber;
  final String docTitle;
  final String mode; // 'ITEMIZED' | 'LUMP_SUM'
  final String issueDate;
  final String validUntil;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final String projectName;
  final String projectLocation;
  final List<QuotationLineEntry> lines;
  final double lumpSumPrice;
  final double discount;
  final bool vatEnabled;
  final double subtotal;
  final double vatAmount;
  final double netTotal;
  final String paymentTerms;
  final String leadTime;
  final String warranty;
  final String remarks;
  final String revisionTag;
  final DateTime createdAt;

  const SavedQuotation({
    this.id,
    required this.projectId,
    required this.qtNumber,
    required this.docTitle,
    required this.mode,
    required this.issueDate,
    required this.validUntil,
    required this.customerName,
    this.customerAddress = '',
    this.customerContact = '',
    required this.projectName,
    this.projectLocation = '',
    required this.lines,
    required this.lumpSumPrice,
    this.discount = 0,
    this.vatEnabled = false,
    required this.subtotal,
    required this.vatAmount,
    required this.netTotal,
    this.paymentTerms = '',
    this.leadTime = '',
    this.warranty = '',
    this.remarks = '',
    required this.revisionTag,
    required this.createdAt,
  });

  String get modeThaiLabel =>
      mode == 'ITEMIZED' ? 'แยกรายการ' : 'เหมาทั้งโครงการ';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'project_id': projectId,
        'qt_number': qtNumber,
        'doc_title': docTitle,
        'mode': mode,
        'issue_date': issueDate,
        'valid_until': validUntil,
        'customer_name': customerName,
        'customer_address': customerAddress,
        'customer_contact': customerContact,
        'project_name': projectName,
        'project_location': projectLocation,
        'lines_json': jsonEncode(lines.map((e) => e.toJson()).toList()),
        'lump_sum_price': lumpSumPrice,
        'discount': discount,
        'vat_enabled': vatEnabled ? 1 : 0,
        'subtotal': subtotal,
        'vat_amount': vatAmount,
        'net_total': netTotal,
        'payment_terms': paymentTerms,
        'lead_time': leadTime,
        'warranty': warranty,
        'remarks': remarks,
        'revision_tag': revisionTag,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavedQuotation.fromMap(Map<String, dynamic> m) => SavedQuotation(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        qtNumber: m['qt_number'] as String,
        docTitle: m['doc_title'] as String,
        mode: m['mode'] as String,
        issueDate: m['issue_date'] as String,
        validUntil: m['valid_until'] as String,
        customerName: m['customer_name'] as String,
        customerAddress: m['customer_address'] as String? ?? '',
        customerContact: m['customer_contact'] as String? ?? '',
        projectName: m['project_name'] as String,
        projectLocation: m['project_location'] as String? ?? '',
        lines: (jsonDecode(m['lines_json'] as String) as List<dynamic>)
            .map((e) => QuotationLineEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        lumpSumPrice: (m['lump_sum_price'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        vatEnabled: (m['vat_enabled'] as int) == 1,
        subtotal: (m['subtotal'] as num).toDouble(),
        vatAmount: (m['vat_amount'] as num).toDouble(),
        netTotal: (m['net_total'] as num).toDouble(),
        paymentTerms: m['payment_terms'] as String? ?? '',
        leadTime: m['lead_time'] as String? ?? '',
        warranty: m['warranty'] as String? ?? '',
        remarks: m['remarks'] as String? ?? '',
        revisionTag: m['revision_tag'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class MaterialRateItem {
  final String rateKey; // e.g. 'GLASS|กระจกใส 6 มม.' or 'HW|HD-414-C2'
  final String category; // 'GLASS' | 'HARDWARE'
  final String code;
  final String name;
  final String unit; // 'ตร.ม.', 'ชิ้น', 'ชุด', 'ตัว', 'คู่', 'ม้วน', 'หลอด'
  final double factoryPrice;
  final double? customPrice;
  final bool isEstimated;
  final String brand; // e.g. 'ALUMET', 'VVP', 'RP', ''
  final String subCategory; // e.g. 'บานเลื่อน', 'บานเปิด', 'บานกระทุ้ง', 'บานเฟี้ยม', 'สกรู / ทั่วไป', 'บานพับชาวเวอร์'
  final String? colorNote;
  final String? imageAssetPath;
  final bool visibleInCatalog;

  const MaterialRateItem({
    required this.rateKey,
    required this.category,
    required this.code,
    required this.name,
    required this.unit,
    required this.factoryPrice,
    this.customPrice,
    this.isEstimated = false,
    this.brand = '',
    this.subCategory = '',
    this.colorNote,
    this.imageAssetPath,
    this.visibleInCatalog = true,
  });

  double get effectivePrice => customPrice ?? factoryPrice;

  MaterialRateItem withOverride(double? overridePrice) => MaterialRateItem(
        rateKey: rateKey,
        category: category,
        code: code,
        name: name,
        unit: unit,
        factoryPrice: factoryPrice,
        customPrice: overridePrice,
        isEstimated: isEstimated,
        brand: brand,
        subCategory: subCategory,
        colorNote: colorNote,
        imageAssetPath: imageAssetPath,
        visibleInCatalog: visibleInCatalog,
      );

  factory MaterialRateItem.fromJson(Map<String, dynamic> j) => MaterialRateItem(
        rateKey: j['rateKey'] as String,
        category: j['category'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String,
        unit: j['unit'] as String? ?? 'ชิ้น',
        factoryPrice: (j['price'] as num).toDouble(),
        isEstimated: j['isEstimated'] as bool? ?? false,
        brand: j['brand'] as String? ?? '',
        subCategory: j['subCategory'] as String? ?? '',
        colorNote: j['colorNote'] as String?,
        imageAssetPath: j['imageAssetPath'] as String?,
        visibleInCatalog: j['visibleInCatalog'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'rateKey': rateKey,
        'category': category,
        'code': code,
        'name': name,
        'unit': unit,
        'price': effectivePrice,
        'isEstimated': isEstimated,
        if (brand.isNotEmpty) 'brand': brand,
        if (subCategory.isNotEmpty) 'subCategory': subCategory,
        if (colorNote != null && colorNote!.isNotEmpty) 'colorNote': colorNote,
        if (imageAssetPath != null && imageAssetPath!.isNotEmpty)
          'imageAssetPath': imageAssetPath,
        'visibleInCatalog': visibleInCatalog,
      };
}

class CustomProfileSystem {
  final String id;
  final String categoryId;
  final String brandId;
  final String brandTitle;
  final String priceBrandKey;
  final String? brandLogoPath;
  final String systemTitle;
  final String patternTitle;
  final String patternSubtitle;
  final String? patternImagePath;
  final InputTableMode tableMode;
  final AuxDimensionType auxType;
  final String? auxLabel;
  final VerifiedFormulaTable formulaTable;
  final Map<String, String> profileImagePaths;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomProfileSystem({
    required this.id,
    required this.categoryId,
    required this.brandId,
    required this.brandTitle,
    required this.priceBrandKey,
    this.brandLogoPath,
    required this.systemTitle,
    required this.patternTitle,
    this.patternSubtitle = '',
    this.patternImagePath,
    this.tableMode = InputTableMode.standardMultiRow,
    this.auxType = AuxDimensionType.none,
    this.auxLabel,
    required this.formulaTable,
    this.profileImagePaths = const {},
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  PatternCardDef toPatternCardDef() => PatternCardDef(
        id: id,
        title: patternTitle,
        subtitle: patternSubtitle.trim().isNotEmpty
            ? patternSubtitle.trim()
            : 'ชุดโปรไฟล์ที่เพิ่มเอง',
        enabled: enabled,
        disabledBadge: enabled ? null : 'ปิดใช้งานชั่วคราว',
        baseFormulaKey: formulaTable.key,
        tableMode: tableMode,
        auxType: auxType,
        auxLabel: auxLabel,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'brand_id': brandId,
        'brand_title': brandTitle,
        'price_brand_key': priceBrandKey,
        'brand_logo_path': brandLogoPath,
        'system_title': systemTitle,
        'pattern_title': patternTitle,
        'pattern_subtitle': patternSubtitle,
        'pattern_image_path': patternImagePath,
        'table_mode': tableMode.name,
        'aux_type': auxType.name,
        'aux_label': auxLabel,
        'formula_json': jsonEncode(formulaTable.toJson()),
        'profile_images_json': jsonEncode(profileImagePaths),
        'enabled': enabled ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CustomProfileSystem.fromMap(Map<String, dynamic> m) {
    final modeName = m['table_mode'] as String? ?? 'standardMultiRow';
    final auxName = m['aux_type'] as String? ?? 'none';
    final imgRaw = m['profile_images_json'] as String?;
    return CustomProfileSystem(
      id: m['id'] as String,
      categoryId: m['category_id'] as String,
      brandId: m['brand_id'] as String,
      brandTitle: m['brand_title'] as String,
      priceBrandKey: m['price_brand_key'] as String,
      brandLogoPath: m['brand_logo_path'] as String?,
      systemTitle: m['system_title'] as String,
      patternTitle: m['pattern_title'] as String,
      patternSubtitle: m['pattern_subtitle'] as String? ?? '',
      patternImagePath: m['pattern_image_path'] as String?,
      tableMode: InputTableMode.values.firstWhere(
        (e) => e.name == modeName,
        orElse: () => InputTableMode.standardMultiRow,
      ),
      auxType: AuxDimensionType.values.firstWhere(
        (e) => e.name == auxName,
        orElse: () => AuxDimensionType.none,
      ),
      auxLabel: m['aux_label'] as String?,
      formulaTable: VerifiedFormulaTable.fromJson(
        jsonDecode(m['formula_json'] as String) as Map<String, dynamic>,
      ),
      profileImagePaths: imgRaw != null && imgRaw.isNotEmpty
          ? Map<String, String>.from(jsonDecode(imgRaw) as Map)
          : const {},
      enabled: (m['enabled'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'brandId': brandId,
        'brandTitle': brandTitle,
        'priceBrandKey': priceBrandKey,
        'brandLogoPath': brandLogoPath,
        'systemTitle': systemTitle,
        'patternTitle': patternTitle,
        'patternSubtitle': patternSubtitle,
        'patternImagePath': patternImagePath,
        'tableMode': tableMode.name,
        'auxType': auxType.name,
        'auxLabel': auxLabel,
        'formulaTable': formulaTable.toJson(),
        'profileImagePaths': profileImagePaths,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomProfileSystem.fromJson(Map<String, dynamic> j) =>
      CustomProfileSystem(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String? ?? 'cat2_pattana',
        brandId: j['brandId'] as String? ?? 'cust_brand',
        brandTitle: j['brandTitle'] as String? ?? 'ชุดโปรไฟล์ใหม่',
        priceBrandKey: j['priceBrandKey'] as String? ?? 'CUSTOM',
        brandLogoPath: j['brandLogoPath'] as String?,
        systemTitle: j['systemTitle'] as String? ?? 'บานเลื่อน',
        patternTitle: j['patternTitle'] as String? ?? 'รูปแบบบานใหม่',
        patternSubtitle: j['patternSubtitle'] as String? ?? '',
        patternImagePath: j['patternImagePath'] as String?,
        tableMode: InputTableMode.values.firstWhere(
          (e) => e.name == (j['tableMode'] as String? ?? 'standardMultiRow'),
          orElse: () => InputTableMode.standardMultiRow,
        ),
        auxType: AuxDimensionType.values.firstWhere(
          (e) => e.name == (j['auxType'] as String? ?? 'none'),
          orElse: () => AuxDimensionType.none,
        ),
        auxLabel: j['auxLabel'] as String?,
        formulaTable: VerifiedFormulaTable.fromJson(
          j['formulaTable'] as Map<String, dynamic>,
        ),
        profileImagePaths: j['profileImagePaths'] is Map
            ? Map<String, String>.from(j['profileImagePaths'] as Map)
            : const {},
        enabled: j['enabled'] as bool? ?? true,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : DateTime.now(),
      );
}

enum LaborCostMode {
  perSqM, // คิดตามพื้นที่ช่องเปิด (บาท/ตร.ม.)
  flatBaht, // เหมาทั้งงาน (บาท)
  percentOfMaterial, // คิดเป็น % จากต้นทุนวัสดุ
}

enum ProfitBaseMode {
  materialOnly, // กำไรคิดจากต้นทุนวัสดุ + บวกค่าแรง (ตรงกับเวอร์ชันเว็บ)
  materialAndLabor, // กำไรคิดจาก (ต้นทุนวัสดุ + ค่าแรง)
}

class PricingMarkupDefaults {
  final double profitPercent;
  final ProfitBaseMode profitBaseMode;
  final LaborCostMode laborMode;
  final double laborRate;

  const PricingMarkupDefaults({
    this.profitPercent = 20.0,
    this.profitBaseMode = ProfitBaseMode.materialOnly,
    this.laborMode = LaborCostMode.perSqM,
    this.laborRate = 0.0,
  });

  PricingMarkupDefaults copyWith({
    double? profitPercent,
    ProfitBaseMode? profitBaseMode,
    LaborCostMode? laborMode,
    double? laborRate,
  }) =>
      PricingMarkupDefaults(
        profitPercent: profitPercent ?? this.profitPercent,
        profitBaseMode: profitBaseMode ?? this.profitBaseMode,
        laborMode: laborMode ?? this.laborMode,
        laborRate: laborRate ?? this.laborRate,
      );

  Map<String, dynamic> toJson() => {
        'profitPercent': profitPercent,
        'profitBaseMode': profitBaseMode.name,
        'laborMode': laborMode.name,
        'laborRate': laborRate,
      };

  factory PricingMarkupDefaults.fromJson(Map<String, dynamic> j) =>
      PricingMarkupDefaults(
        profitPercent:
            ((j['profitPercent'] as num?)?.toDouble() ?? 20.0).clamp(0.0, 200.0),
        profitBaseMode: ProfitBaseMode.values.firstWhere(
          (e) => e.name == (j['profitBaseMode'] as String? ?? 'materialOnly'),
          orElse: () => ProfitBaseMode.materialOnly,
        ),
        laborMode: LaborCostMode.values.firstWhere(
          (e) => e.name == (j['laborMode'] as String? ?? 'perSqM'),
          orElse: () => LaborCostMode.perSqM,
        ),
        laborRate: ((j['laborRate'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 10000000.0),
      );
}

/// Persisted per-project pricing preferences (stored in `app_flags` under
/// `project_pricing_<projectId>` so multiple concurrent projects never
/// overwrite each other's aluminum, glass, hardware, labor, or profit settings).
class ProjectPricingConfig {
  final String modeName; // 'actualLength' | 'fullBars'
  final double wastePercent;
  final bool useItemOwnMaterialSpecs;
  final String selectedThickness;
  final String selectedColor;
  final bool includeGlass;
  final String selectedGlassKey;
  final bool includeHardware;
  final double profitPercent;
  final ProfitBaseMode profitBaseMode;
  final LaborCostMode laborMode;
  final double laborRate;

  const ProjectPricingConfig({
    this.modeName = 'actualLength',
    this.wastePercent = 20.0,
    this.useItemOwnMaterialSpecs = true,
    this.selectedThickness = '',
    this.selectedColor = '',
    this.includeGlass = true,
    this.selectedGlassKey = 'GLASS|กระจกใส 6 มม.',
    this.includeHardware = true,
    this.profitPercent = 20.0,
    this.profitBaseMode = ProfitBaseMode.materialOnly,
    this.laborMode = LaborCostMode.perSqM,
    this.laborRate = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'modeName': modeName,
        'wastePercent': wastePercent,
        'useItemOwnMaterialSpecs': useItemOwnMaterialSpecs,
        'selectedThickness': selectedThickness,
        'selectedColor': selectedColor,
        'includeGlass': includeGlass,
        'selectedGlassKey': selectedGlassKey,
        'includeHardware': includeHardware,
        'profitPercent': profitPercent,
        'profitBaseMode': profitBaseMode.name,
        'laborMode': laborMode.name,
        'laborRate': laborRate,
      };

  factory ProjectPricingConfig.fromJson(Map<String, dynamic> j) =>
      ProjectPricingConfig(
        modeName: j['modeName'] as String? ?? 'actualLength',
        wastePercent:
            ((j['wastePercent'] as num?)?.toDouble() ?? 20.0).clamp(0.0, 200.0),
        useItemOwnMaterialSpecs: j['useItemOwnMaterialSpecs'] as bool? ?? true,
        selectedThickness: j['selectedThickness'] as String? ?? '',
        selectedColor: j['selectedColor'] as String? ?? '',
        includeGlass: j['includeGlass'] as bool? ?? true,
        selectedGlassKey:
            j['selectedGlassKey'] as String? ?? 'GLASS|กระจกใส 6 มม.',
        includeHardware: j['includeHardware'] as bool? ?? true,
        profitPercent:
            ((j['profitPercent'] as num?)?.toDouble() ?? 20.0).clamp(0.0, 200.0),
        profitBaseMode: ProfitBaseMode.values.firstWhere(
          (e) => e.name == (j['profitBaseMode'] as String? ?? 'materialOnly'),
          orElse: () => ProfitBaseMode.materialOnly,
        ),
        laborMode: LaborCostMode.values.firstWhere(
          (e) => e.name == (j['laborMode'] as String? ?? 'perSqM'),
          orElse: () => LaborCostMode.perSqM,
        ),
        laborRate: ((j['laborRate'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 10000000.0),
      );
}

/// Shop-wide remembered selection defaults saved via the "จำค่าตั้งต้นร้าน"
/// shortcut across input, pricing, and quotation screens (stored in `app_flags`
/// with zero SQLite schema migration).
class ShopSelectionDefaults {
  final Map<String, String> brandAluThicknesses;
  final Map<String, String> brandAluColors;
  final Map<String, String> brandGlassTypes;
  final Map<String, String> brandGlassThicknesses;
  final Map<String, String> optionDefaults;
  final String? pricingMode;
  final double? pricingWastePct;
  final bool? pricingUseItemOwnSpecs;
  final bool? pricingIncludeGlass;
  final bool? pricingIncludeHw;
  final String? qtMode;
  final bool? qtIncludeImages;
  final bool? qtVatEnabled;
  final String? qtPaymentTerms;
  final String? qtLeadTime;
  final String? qtWarranty;

  const ShopSelectionDefaults({
    this.brandAluThicknesses = const {},
    this.brandAluColors = const {},
    this.brandGlassTypes = const {},
    this.brandGlassThicknesses = const {},
    this.optionDefaults = const {},
    this.pricingMode,
    this.pricingWastePct,
    this.pricingUseItemOwnSpecs,
    this.pricingIncludeGlass,
    this.pricingIncludeHw,
    this.qtMode,
    this.qtIncludeImages,
    this.qtVatEnabled,
    this.qtPaymentTerms,
    this.qtLeadTime,
    this.qtWarranty,
  });

  ShopSelectionDefaults copyWith({
    Map<String, String>? brandAluThicknesses,
    Map<String, String>? brandAluColors,
    Map<String, String>? brandGlassTypes,
    Map<String, String>? brandGlassThicknesses,
    Map<String, String>? optionDefaults,
    String? pricingMode,
    double? pricingWastePct,
    bool? pricingUseItemOwnSpecs,
    bool? pricingIncludeGlass,
    bool? pricingIncludeHw,
    String? qtMode,
    bool? qtIncludeImages,
    bool? qtVatEnabled,
    String? qtPaymentTerms,
    String? qtLeadTime,
    String? qtWarranty,
  }) =>
      ShopSelectionDefaults(
        brandAluThicknesses: brandAluThicknesses ?? this.brandAluThicknesses,
        brandAluColors: brandAluColors ?? this.brandAluColors,
        brandGlassTypes: brandGlassTypes ?? this.brandGlassTypes,
        brandGlassThicknesses:
            brandGlassThicknesses ?? this.brandGlassThicknesses,
        optionDefaults: optionDefaults ?? this.optionDefaults,
        pricingMode: pricingMode ?? this.pricingMode,
        pricingWastePct: pricingWastePct ?? this.pricingWastePct,
        pricingUseItemOwnSpecs:
            pricingUseItemOwnSpecs ?? this.pricingUseItemOwnSpecs,
        pricingIncludeGlass: pricingIncludeGlass ?? this.pricingIncludeGlass,
        pricingIncludeHw: pricingIncludeHw ?? this.pricingIncludeHw,
        qtMode: qtMode ?? this.qtMode,
        qtIncludeImages: qtIncludeImages ?? this.qtIncludeImages,
        qtVatEnabled: qtVatEnabled ?? this.qtVatEnabled,
        qtPaymentTerms: qtPaymentTerms ?? this.qtPaymentTerms,
        qtLeadTime: qtLeadTime ?? this.qtLeadTime,
        qtWarranty: qtWarranty ?? this.qtWarranty,
      );

  Map<String, dynamic> toJson() => {
        'brandAluThicknesses': brandAluThicknesses,
        'brandAluColors': brandAluColors,
        'brandGlassTypes': brandGlassTypes,
        'brandGlassThicknesses': brandGlassThicknesses,
        'optionDefaults': optionDefaults,
        if (pricingMode != null) 'pricingMode': pricingMode,
        if (pricingWastePct != null) 'pricingWastePct': pricingWastePct,
        if (pricingUseItemOwnSpecs != null)
          'pricingUseItemOwnSpecs': pricingUseItemOwnSpecs,
        if (pricingIncludeGlass != null)
          'pricingIncludeGlass': pricingIncludeGlass,
        if (pricingIncludeHw != null) 'pricingIncludeHw': pricingIncludeHw,
        if (qtMode != null) 'qtMode': qtMode,
        if (qtIncludeImages != null) 'qtIncludeImages': qtIncludeImages,
        if (qtVatEnabled != null) 'qtVatEnabled': qtVatEnabled,
        if (qtPaymentTerms != null) 'qtPaymentTerms': qtPaymentTerms,
        if (qtLeadTime != null) 'qtLeadTime': qtLeadTime,
        if (qtWarranty != null) 'qtWarranty': qtWarranty,
      };

  factory ShopSelectionDefaults.fromJson(Map<String, dynamic> j) {
    Map<String, String> mapOf(Object? raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return const {};
    }

    return ShopSelectionDefaults(
      brandAluThicknesses: mapOf(j['brandAluThicknesses']),
      brandAluColors: mapOf(j['brandAluColors']),
      brandGlassTypes: mapOf(j['brandGlassTypes']),
      brandGlassThicknesses: mapOf(j['brandGlassThicknesses']),
      optionDefaults: mapOf(j['optionDefaults']),
      pricingMode: j['pricingMode'] as String?,
      pricingWastePct: (j['pricingWastePct'] as num?)?.toDouble(),
      pricingUseItemOwnSpecs: j['pricingUseItemOwnSpecs'] as bool?,
      pricingIncludeGlass: j['pricingIncludeGlass'] as bool?,
      pricingIncludeHw: j['pricingIncludeHw'] as bool?,
      qtMode: j['qtMode'] as String?,
      qtIncludeImages: j['qtIncludeImages'] as bool?,
      qtVatEnabled: j['qtVatEnabled'] as bool?,
      qtPaymentTerms: j['qtPaymentTerms'] as String?,
      qtLeadTime: j['qtLeadTime'] as String?,
      qtWarranty: j['qtWarranty'] as String?,
    );
  }
}

/// User-edited formula override for any built-in pattern (allows editing cuts,
/// glass formulas, hardware, or clearing all aluminum cuts to 0 bars, and
/// resetting back to factory default at any time).
class PatternFormulaOverride {
  final String patternId;
  final VerifiedFormulaTable formulaTable;
  final DateTime updatedAt;

  const PatternFormulaOverride({
    required this.patternId,
    required this.formulaTable,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'patternId': patternId,
        'formulaTable': formulaTable.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PatternFormulaOverride.fromJson(Map<String, dynamic> j) =>
      PatternFormulaOverride(
        patternId: j['patternId'] as String,
        formulaTable: VerifiedFormulaTable.fromJson(
          j['formulaTable'] as Map<String, dynamic>,
        ),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : DateTime.now(),
      );
}
