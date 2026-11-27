import '../data/app_database.dart';
import '../models/app_models.dart';
import 'bin_packer.dart';

enum PricingMode {
  actualLength, // ตามระยะใช้จริง (default wastePct = 20%)
  fullBars, // ซื้อเต็มเส้น (resets wastePct = 0%)
}

class ProfileCostLine {
  final ProfileBarGroup group;
  final OrmPriceSku? matchedSku;
  final String matchNote;
  final double? unitPricePerBar;
  final double? lineCost;

  const ProfileCostLine({
    required this.group,
    this.matchedSku,
    required this.matchNote,
    this.unitPricePerBar,
    this.lineCost,
  });

  bool get isMatched => unitPricePerBar != null && lineCost != null;
  bool get isEstimatedPrice =>
      matchedSku != null &&
      matchedSku!.customPrice == null &&
      matchedSku!.isEstimated;
  bool get isCustomPrice =>
      matchedSku != null && matchedSku!.customPrice != null;
}

class GlassCostLine {
  final EvaluatedGlassItem item;
  final double areaSqM;
  final double ratePerSqM;
  final double? lineCost;
  final String note;

  const GlassCostLine({
    required this.item,
    required this.areaSqM,
    required this.ratePerSqM,
    this.lineCost,
    required this.note,
  });

  bool get isPriced => lineCost != null;
}

class HardwareCostLine {
  final AggregatedHardwareItem item;
  final MaterialRateItem? matchedRate;
  final double? unitPrice;
  final double? lineCost;
  final String note;

  const HardwareCostLine({
    required this.item,
    this.matchedRate,
    this.unitPrice,
    this.lineCost,
    required this.note,
  });

  bool get isPriced => lineCost != null;
}

class SellingPriceBreakdown {
  final double materialCost;
  final double openingAreaSqM;
  final LaborCostMode laborMode;
  final double laborRate;
  final double laborCost;
  final double profitPercent;
  final ProfitBaseMode profitBaseMode;
  final double profitAmount;
  final double suggestedSellingPrice;

  const SellingPriceBreakdown({
    required this.materialCost,
    required this.openingAreaSqM,
    required this.laborMode,
    required this.laborRate,
    required this.laborCost,
    required this.profitPercent,
    required this.profitBaseMode,
    required this.profitAmount,
    required this.suggestedSellingPrice,
  });

  double get totalCostWithLabor => PricingEngine.round2(materialCost + laborCost);
}

class PricingSummary {
  final PricingMode mode;
  final double wastePercent;
  final String selectedThickness;
  final String selectedColor;
  final List<ProfileCostLine> lines;
  final int matchedCount;
  final int totalCount;
  final double aluminumCost;

  final bool includeGlass;
  final String selectedGlassKey;
  final double glassRatePerSqM;
  final List<GlassCostLine> glassLines;
  final double totalGlassAreaSqM;
  final double glassCost;

  final bool includeHardware;
  final List<HardwareCostLine> hardwareLines;
  final double hardwareCost;

  /// Grand total material cost based on active toggles (`aluminumCost + glass + hardware`).
  final double totalCost;

  final double openingAreaSqM;
  final LaborCostMode laborMode;
  final double laborRate;
  final double laborCost;
  final double profitPercent;
  final ProfitBaseMode profitBaseMode;
  final double profitAmount;
  final double suggestedSellingPrice;

  const PricingSummary({
    required this.mode,
    required this.wastePercent,
    required this.selectedThickness,
    required this.selectedColor,
    required this.lines,
    required this.matchedCount,
    required this.totalCount,
    required this.aluminumCost,
    this.includeGlass = false,
    this.selectedGlassKey = '',
    this.glassRatePerSqM = 0.0,
    this.glassLines = const [],
    this.totalGlassAreaSqM = 0.0,
    this.glassCost = 0.0,
    this.includeHardware = false,
    this.hardwareLines = const [],
    this.hardwareCost = 0.0,
    required this.totalCost,
    this.openingAreaSqM = 0.0,
    this.laborMode = LaborCostMode.perSqM,
    this.laborRate = 0.0,
    this.laborCost = 0.0,
    this.profitPercent = 0.0,
    this.profitBaseMode = ProfitBaseMode.materialOnly,
    this.profitAmount = 0.0,
    double? suggestedSellingPrice,
  }) : suggestedSellingPrice =
            suggestedSellingPrice ?? (totalCost + laborCost + profitAmount);
}

class PricingCatalogAvailability {
  final bool isComplete;
  final List<String> availableThicknesses;
  final List<String> availableColors;

  const PricingCatalogAvailability({
    required this.isComplete,
    required this.availableThicknesses,
    required this.availableColors,
  });
}

/// Per-item (per-model / per-opening) cost & selling breakdown inside a
/// multi-item project, preserving project-wide bar-packing savings while
/// allocating true aluminum/glass/hardware costs accurately to each model.
class ProjectItemPricingBreakdown {
  final SavedProjectItem item;
  final int totalUnits;
  final double openingAreaSqM;
  final double standaloneAluminumCost;
  final double standaloneGlassCost;
  final double standaloneHardwareCost;
  final double standaloneMaterialCost;
  final double allocatedMaterialCost;
  final double laborCost;
  final double profitAmount;
  final double suggestedTotalPrice;
  final double unitSellingPrice;
  final String effectiveThickness;
  final String effectiveColor;
  final String effectiveGlassLabel;

  const ProjectItemPricingBreakdown({
    required this.item,
    required this.totalUnits,
    required this.openingAreaSqM,
    required this.standaloneAluminumCost,
    required this.standaloneGlassCost,
    required this.standaloneHardwareCost,
    required this.standaloneMaterialCost,
    required this.allocatedMaterialCost,
    required this.laborCost,
    required this.profitAmount,
    required this.suggestedTotalPrice,
    required this.unitSellingPrice,
    this.effectiveThickness = '',
    this.effectiveColor = '',
    this.effectiveGlassLabel = '',
  });

  double get materialCostPerUnit => totalUnits > 0
      ? PricingEngine.round2(allocatedMaterialCost / totalUnits)
      : 0.0;
}

class ResolvedItemMaterialSpec {
  final String thickness;
  final String color;
  final bool includeGlass;
  final String glassKey;
  final double glassRatePerSqM;
  final String glassLabel;
  final bool includeHardware;

  const ResolvedItemMaterialSpec({
    required this.thickness,
    required this.color,
    required this.includeGlass,
    required this.glassKey,
    required this.glassRatePerSqM,
    required this.glassLabel,
    required this.includeHardware,
  });
}

class PricingEngine {
  PricingEngine._();

  static const List<String> standardThicknesses = [
    '0.8 มม.',
    '0.9 มม.',
    '1.0 มม.',
    '1.1 มม.',
    '1.2 มม.',
    '1.3 มม.',
    '1.4 มม.',
    '1.5 มม.',
    '1.7 มม.',
    '1.8 มม.',
    '2.0 มม.',
    '2.2 มม.',
    '2.5 มม.',
    '3.0 มม.',
    '3.1 มม.',
    '4.5 มม.',
    'ไม่ระบุความหนา',
  ];

  /// Official 19 ALUMET Thailand color codes (ALUMET Hub 010867 & 110569).
  static const List<String> alumetColors = [
    'ตัวดิบ MILL',
    'ชุบขาว (E&A)',
    'ชุบชา (512)',
    'ชุบน้ำตาล (514)',
    'ชุบดำ (518)',
    'แพลทินั่ม (502)',
    'แชมเปญ (504)',
    'ชุบชาเข้ม (510)',
    'อบขาว (8911)',
    'อบดำ (8816)',
    'เทาซาฮาร่า (8820)',
    'อบดำเงา (8815)',
    'อบเทา (8859)',
    'อบน้ำตาล (8823)',
    'น้ำตาลซาฮาร่า (8825)',
    'ดำซาฮาร่า (8819)',
    'ทรายซาฮาร่า (8515)',
    'ลายไม้สักน้ำตาล (15656)',
    'ลายไม้วอลนัท (15659)',
  ];

  static const List<String> standardColors = [
    'ตัวดิบ MILL',
    'ชุบขาว',
    'ชุบขาว (E&A)',
    'ชุบชา (512)',
    'ชุบน้ำตาล (514)',
    'ชุบดำ (518)',
    'แพลทินั่ม (502)',
    'แชมเปญ (504)',
    'ชุบชาเข้ม (510)',
    'อบขาว (8911)',
    'อบดำ (8816)',
    'เทาซาฮาร่า (8820)',
    'อบดำเงา (8815)',
    'อบเทา (8859)',
    'อบน้ำตาล (8823)',
    'น้ำตาลซาฮาร่า (8825)',
    'ดำซาฮาร่า (8819)',
    'ทรายซาฮาร่า (8515)',
    'สีชา',
    'ลายไม้ (15656 / 15659)',
    'ลายไม้สักน้ำตาล (15656)',
    'ลายไม้วอลนัท (15659)',
    'พ่นขาว คอตตอน ไวท์',
    'พ่นดำ ซุปเปอร์แบล็ค',
    'พ่นเทา แชมเปญเกรย์ (สีใหม่)',
    'พ่นเมทัลลิค (สีเดิม) / กาแล็คซี่ (สีใหม่)',
    'ลายไม้ สักทอง / โอ๊ค / เดนมาร์ค',
  ];

  static const List<String> fallbackDefaultColors = [
    'ตัวดิบ MILL',
    'ชุบขาว',
    'อบขาว (8911)',
    'อบดำ (8816)',
    'เทาซาฮาร่า (8820)',
    'ทรายซาฮาร่า (8515)',
    'ลายไม้ (15656 / 15659)',
  ];

  static const List<String> fallbackDefaultThicknesses = [
    '1.2 มม.',
    '1.5 มม.',
    '1.8 มม.',
    '2.0 มม.',
  ];

  static double round2(double v) => (v * 100.0).round() / 100.0;

  static SellingPriceBreakdown computeSellingBreakdown({
    required double materialCost,
    double openingAreaSqM = 0.0,
    LaborCostMode laborMode = LaborCostMode.perSqM,
    double laborRate = 0.0,
    double profitPercent = 20.0,
    ProfitBaseMode profitBaseMode = ProfitBaseMode.materialOnly,
  }) {
    final safeMat = materialCost < 0 ? 0.0 : materialCost;
    final safeArea = openingAreaSqM < 0 ? 0.0 : openingAreaSqM;
    final safeLaborRate = laborRate < 0 ? 0.0 : laborRate;
    final safeProfitPct = profitPercent.clamp(0.0, 200.0);

    final double effectiveLaborRate;
    final double laborCost;
    switch (laborMode) {
      case LaborCostMode.perSqM:
        effectiveLaborRate = safeLaborRate;
        laborCost = round2(safeArea * effectiveLaborRate);
        break;
      case LaborCostMode.flatBaht:
        effectiveLaborRate = safeLaborRate;
        laborCost = round2(effectiveLaborRate);
        break;
      case LaborCostMode.percentOfMaterial:
        effectiveLaborRate = safeLaborRate.clamp(0.0, 200.0);
        laborCost = round2(safeMat * (effectiveLaborRate / 100.0));
        break;
    }

    final profitBase = profitBaseMode == ProfitBaseMode.materialAndLabor
        ? (safeMat + laborCost)
        : safeMat;
    final profitAmount = round2(profitBase * (safeProfitPct / 100.0));
    final suggestedSellingPrice = round2(safeMat + laborCost + profitAmount);

    return SellingPriceBreakdown(
      materialCost: round2(safeMat),
      openingAreaSqM: round2(safeArea),
      laborMode: laborMode,
      laborRate: effectiveLaborRate,
      laborCost: laborCost,
      profitPercent: safeProfitPct,
      profitBaseMode: profitBaseMode,
      profitAmount: profitAmount,
      suggestedSellingPrice: suggestedSellingPrice,
    );
  }

  /// Allocates a target selling total across project items proportionally by
  /// explicit [itemWeights] (e.g. per-model cost/selling breakdown) when
  /// provided and positive, otherwise falling back to opening area or unit
  /// count, returning per-unit selling prices aligned with [items].
  static List<double> allocateUnitSellingPrices({
    required List<({double areaSqM, int qty})> items,
    required double targetTotal,
    List<double>? itemWeights,
  }) {
    if (items.isEmpty) return const [];
    if (targetTotal <= 0) return List<double>.filled(items.length, 0.0);

    final useExplicitWeights = itemWeights != null &&
        itemWeights.length == items.length &&
        itemWeights.every((w) => w > 0);
    final allHaveArea = items.every((e) => e.areaSqM > 0);
    final weights = List<double>.generate(items.length, (i) {
      if (useExplicitWeights) return itemWeights[i];
      final e = items[i];
      return allHaveArea ? e.areaSqM : (e.qty > 0 ? e.qty.toDouble() : 1.0);
    });
    final totalWeight = weights.fold(0.0, (s, w) => s + w);
    if (totalWeight <= 0) return List<double>.filled(items.length, 0.0);

    final result = <double>[];
    double allocatedSum = 0.0;
    for (int i = 0; i < items.length; i++) {
      final qty = items[i].qty > 0 ? items[i].qty : 1;
      if (i == items.length - 1 && qty == 1) {
        final rem =
            round2((targetTotal - allocatedSum).clamp(0.0, double.infinity));
        result.add(rem);
        allocatedSum = round2(allocatedSum + rem);
      } else {
        final share = targetTotal * (weights[i] / totalWeight);
        final unitPrice = round2(share / qty);
        result.add(unitPrice);
        allocatedSum = round2(allocatedSum + (unitPrice * qty));
      }
    }
    return result;
  }

  /// Allocates selling prices per quotation line using each item's true
  /// allocated [materialCost], [areaSqM], and active labor/profit settings so
  /// different profile series (e.g. ICONIQ vs Smart X vs NEX 200) of the exact
  /// same opening size receive distinct, cost-accurate unit prices while
  /// summing to [targetTotal].
  static List<double> allocateQuotationLineUnitPrices({
    required List<({double materialCost, double areaSqM, int qty})> items,
    required LaborCostMode laborMode,
    required double laborRate,
    required double profitPercent,
    required ProfitBaseMode profitBaseMode,
    required double targetTotal,
  }) {
    if (items.isEmpty) return const [];
    if (targetTotal <= 0) return List<double>.filled(items.length, 0.0);

    final hasCostForAll = items.every((e) => e.materialCost > 0);
    if (!hasCostForAll) {
      return allocateUnitSellingPrices(
        items: items.map((e) => (areaSqM: e.areaSqM, qty: e.qty)).toList(),
        targetTotal: targetTotal,
      );
    }

    final safeLaborRate = laborRate < 0 ? 0.0 : laborRate;
    final safeProfitPct = profitPercent.clamp(0.0, 200.0);
    final totalArea = items.fold<double>(0.0, (s, e) => s + (e.areaSqM > 0 ? e.areaSqM : 0.0));
    final totalMat = items.fold<double>(0.0, (s, e) => s + e.materialCost);

    final sellingWeights = <double>[];
    for (final it in items) {
      final double itemLabor;
      switch (laborMode) {
        case LaborCostMode.perSqM:
          itemLabor = (it.areaSqM > 0 ? it.areaSqM : 0.0) * safeLaborRate;
          break;
        case LaborCostMode.percentOfMaterial:
          itemLabor = it.materialCost * (safeLaborRate.clamp(0.0, 200.0) / 100.0);
          break;
        case LaborCostMode.flatBaht:
          final ratio = totalArea > 0
              ? ((it.areaSqM > 0 ? it.areaSqM : 0.0) / totalArea)
              : (totalMat > 0 ? (it.materialCost / totalMat) : (1.0 / items.length));
          itemLabor = safeLaborRate * ratio;
          break;
      }
      final profitBase = profitBaseMode == ProfitBaseMode.materialAndLabor
          ? (it.materialCost + itemLabor)
          : it.materialCost;
      final itemProfit = profitBase * (safeProfitPct / 100.0);
      sellingWeights.add(it.materialCost + itemLabor + itemProfit);
    }

    return allocateUnitSellingPrices(
      items: items.map((e) => (areaSqM: e.areaSqM, qty: e.qty)).toList(),
      targetTotal: targetTotal,
      itemWeights: sellingWeights,
    );
  }

  /// Resolves a catalog glass rate entry from `(glassType, glassThick)` or explicit `glassKey`.
  static MaterialRateItem? matchGlassRateFromSpec({
    String? explicitGlassKey,
    String? glassType,
    String? glassThick,
    required List<MaterialRateItem> mergedGlassRates,
  }) {
    if (mergedGlassRates.isEmpty) return null;
    final expKey = explicitGlassKey?.trim() ?? '';
    if (expKey.isNotEmpty) {
      for (final r in mergedGlassRates) {
        if (r.rateKey == expKey) return r;
      }
    }
    final gType = glassType?.trim() ?? '';
    final gThick = glassThick?.trim() ?? '';
    if (gType.isEmpty || gType == 'ไม่ระบุ' || gType == 'ตามรายการ') {
      if (gThick.isNotEmpty && gThick != 'ไม่ระบุ' && gThick != 'ตามรายการ') {
        for (final r in mergedGlassRates) {
          if (r.rateKey.contains('กระจกใส') && r.rateKey.contains(gThick)) {
            return r;
          }
        }
      }
      return null;
    }
    if (gType == 'ไม่รวมกระจก') return null;

    if (gThick.isNotEmpty && gThick != 'ไม่ระบุ' && gThick != 'ตามรายการ') {
      final exactKey = 'GLASS|$gType $gThick';
      for (final r in mergedGlassRates) {
        if (r.rateKey == exactKey) return r;
      }
      for (final r in mergedGlassRates) {
        if (r.rateKey.contains(gType) && r.rateKey.contains(gThick)) {
          return r;
        }
      }
    }
    // Type-only match (e.g., กระจกลามิเนต -> GLASS|กระจกลามิเนต 6+6 มม.)
    for (final r in mergedGlassRates) {
      if (r.rateKey.contains(gType) || r.name.contains(gType)) {
        return r;
      }
    }
    return null;
  }

  /// Resolves a single [SavedProjectItem]'s effective aluminum & glass specs
  /// (falling back gracefully to project-level defaults only when the item has
  /// no saved spec of its own).
  static ResolvedItemMaterialSpec resolveItemMaterialSpec({
    required SavedProjectItem item,
    required String fallbackThickness,
    required String fallbackColor,
    required bool fallbackIncludeGlass,
    required String fallbackGlassKey,
    required double fallbackGlassRatePerSqM,
    required bool fallbackIncludeHardware,
    List<MaterialRateItem> mergedGlassRates = const [],
  }) {
    final opts = item.selectedOptions;
    String pickValid(List<String?> cands, String fb) {
      for (final c in cands) {
        final t = c?.trim() ?? '';
        if (t.isNotEmpty && t != 'ไม่ระบุ' && t != 'ตามรายการ') {
          return t;
        }
      }
      return fb;
    }

    final rawThickOpt = opts['thickness']?.trim() ?? '';
    final normThickOpt = rawThickOpt.isNotEmpty
        ? (rawThickOpt.endsWith('มม.') ? rawThickOpt : '$rawThickOpt มม.')
        : '';

    final effThick = pickValid(
      [opts['pricing_alu_thick'], opts['spec_alu_thick'], normThickOpt],
      fallbackThickness,
    );
    final effColor = pickValid(
      [opts['pricing_alu_color'], opts['spec_alu_color']],
      fallbackColor,
    );

    final specGlassType = opts['spec_glass_type']?.trim() ?? '';
    final specGlassThick = opts['spec_glass_thick']?.trim() ?? '';
    final rawIncGlass = opts['pricing_include_glass']?.trim() ?? '';
    bool effIncludeGlass = fallbackIncludeGlass;
    if (rawIncGlass == 'false' || specGlassType == 'ไม่รวมกระจก') {
      effIncludeGlass = false;
    } else if (rawIncGlass == 'true') {
      effIncludeGlass = true;
    }

    final matchedGlass = matchGlassRateFromSpec(
      explicitGlassKey: opts['pricing_glass_key'],
      glassType: specGlassType,
      glassThick: specGlassThick,
      mergedGlassRates: mergedGlassRates,
    );

    final effGlassKey = matchedGlass?.rateKey ??
        ((opts['pricing_glass_key']?.trim() ?? '').isNotEmpty
            ? opts['pricing_glass_key']!.trim()
            : fallbackGlassKey);
    final effGlassRate = matchedGlass?.effectivePrice ?? fallbackGlassRatePerSqM;
    final effGlassLabel = !effIncludeGlass
        ? 'ไม่รวมกระจก'
        : (matchedGlass != null
            ? matchedGlass.rateKey.replaceFirst('GLASS|', '')
            : (effGlassKey.replaceFirst('GLASS|', '').isNotEmpty
                ? effGlassKey.replaceFirst('GLASS|', '')
                : 'กระจกใส 6 มม.'));

    final rawIncHw = opts['pricing_include_hw']?.trim() ?? '';
    final effIncludeHw = rawIncHw == 'false'
        ? false
        : (rawIncHw == 'true' ? true : fallbackIncludeHardware);

    return ResolvedItemMaterialSpec(
      thickness: effThick,
      color: effColor,
      includeGlass: effIncludeGlass,
      glassKey: effGlassKey,
      glassRatePerSqM: effGlassRate,
      glassLabel: effGlassLabel,
      includeHardware: effIncludeHw,
    );
  }

  /// Evaluates a multi-item project accurately, preserving each item's own
  /// selected aluminum `(thickness, color)` and glass rate when
  /// [useItemOwnMaterialSpecs] is true (default), while still allowing
  /// cross-item bar packing ONLY among cuts sharing the exact same
  /// `(brand, code, stockMm, thickness, color)`.
  static PricingSummary evaluateProject({
    required List<SavedProjectItem> items,
    required PricingMode mode,
    required double wastePercent,
    required String fallbackThickness,
    required String fallbackColor,
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
    required bool includeGlass,
    required String fallbackGlassKey,
    required double fallbackGlassRatePerSqM,
    required bool includeHardware,
    List<MaterialRateItem> glassCatalog = const [],
    List<MaterialRateItem> hardwareCatalog = const [],
    Map<String, CustomMaterialRateOverride> materialOverrides = const {},
    bool useItemOwnMaterialSpecs = true,
    LaborCostMode laborMode = LaborCostMode.perSqM,
    double laborRate = 0.0,
    double profitPercent = 0.0,
    ProfitBaseMode profitBaseMode = ProfitBaseMode.materialOnly,
  }) {
    final mergedGlass = mergeMaterialRates(
      glassCatalog,
      materialOverrides,
      category: 'GLASS',
    );
    final packedGroups = BinPacker.packProjectItems(
      items,
      separateByItemMaterialSpec: useItemOwnMaterialSpecs,
    );

    final perItemGlassEntries = <({
      EvaluatedGlassItem glass,
      double ratePerSqM,
      String glassLabel,
      double fallbackOpeningSqM,
    })>[];

    final mergedHardwareMap = <String, AggregatedHardwareItem>{};
    double totalOpeningArea = 0.0;
    double totalFallbackGlassArea = 0.0;

    for (final it in items) {
      final itemArea = it.totalOpeningAreaSqM;
      totalOpeningArea += itemArea;
      final spec = useItemOwnMaterialSpecs
          ? resolveItemMaterialSpec(
              item: it,
              fallbackThickness: fallbackThickness,
              fallbackColor: fallbackColor,
              fallbackIncludeGlass: includeGlass,
              fallbackGlassKey: fallbackGlassKey,
              fallbackGlassRatePerSqM: fallbackGlassRatePerSqM,
              fallbackIncludeHardware: includeHardware,
              mergedGlassRates: mergedGlass,
            )
          : ResolvedItemMaterialSpec(
              thickness: fallbackThickness,
              color: fallbackColor,
              includeGlass: includeGlass,
              glassKey: fallbackGlassKey,
              glassRatePerSqM: fallbackGlassRatePerSqM,
              glassLabel: fallbackGlassKey.replaceFirst('GLASS|', ''),
              includeHardware: includeHardware,
            );

      final itemGlasses = it.evaluatedSets.expand((s) => s.glasses).toList();
      if (includeGlass && spec.includeGlass) {
        final sitePanels = itemGlasses
            .where((g) => g.siteCut || (g.widthMm ?? 0) <= 0 || (g.heightMm ?? 0) <= 0)
            .fold<int>(0, (s, g) => s + g.totalPanels);
        final itemFallbackSqM = itemArea * 0.88;
        if (sitePanels > 0) totalFallbackGlassArea += itemFallbackSqM;
        for (final g in itemGlasses) {
          final isSite = g.siteCut || (g.widthMm ?? 0) <= 0 || (g.heightMm ?? 0) <= 0;
          perItemGlassEntries.add((
            glass: g,
            ratePerSqM: spec.glassRatePerSqM,
            glassLabel: spec.glassLabel,
            fallbackOpeningSqM: (isSite && sitePanels > 0)
                ? (itemFallbackSqM * (g.totalPanels / sitePanels))
                : 0.0,
          ));
        }
      }

      if (includeHardware && spec.includeHardware) {
        for (final h in it.hardware) {
          final key = '${h.code}|${h.name}|${h.unitOrNote}';
          final ex = mergedHardwareMap[key];
          if (ex == null) {
            mergedHardwareMap[key] = h;
          } else if (ex.decimalQty != null && h.decimalQty != null) {
            mergedHardwareMap[key] = AggregatedHardwareItem(
              code: ex.code,
              name: ex.name,
              decimalQty: round2(ex.decimalQty! + h.decimalQty!),
              unitOrNote: ex.unitOrNote,
            );
          } else if (ex.numericQty != null && h.numericQty != null) {
            mergedHardwareMap[key] = AggregatedHardwareItem(
              code: ex.code,
              name: ex.name,
              numericQty: ex.numericQty! + h.numericQty!,
              unitOrNote: ex.unitOrNote,
            );
          }
        }
      }
    }

    return evaluate(
      barGroups: packedGroups,
      mode: mode,
      wastePercent: wastePercent,
      selectedThickness: fallbackThickness,
      selectedColor: fallbackColor,
      useGroupSpecs: useItemOwnMaterialSpecs,
      ormCatalog: ormCatalog,
      customOverrides: customOverrides,
      glasses: perItemGlassEntries.map((e) => e.glass).toList(),
      perItemGlassEntries: perItemGlassEntries,
      openingAreaSqM: totalOpeningArea,
      fallbackOpeningAreaSqM: totalFallbackGlassArea,
      hardware: mergedHardwareMap.values.toList(),
      includeGlass: includeGlass,
      selectedGlassKey: fallbackGlassKey,
      glassRatePerSqM: fallbackGlassRatePerSqM,
      includeHardware: includeHardware,
      hardwareCatalog: hardwareCatalog,
      materialOverrides: materialOverrides,
      laborMode: laborMode,
      laborRate: laborRate,
      profitPercent: profitPercent,
      profitBaseMode: profitBaseMode,
    );
  }

  /// Evaluates each [SavedProjectItem] individually using either its own saved
  /// material specs (when [useItemOwnMaterialSpecs] is true) or [projectSummary]
  /// global specs, reconciles bar-packing savings proportionally so allocated
  /// material sums match [projectSummary.totalCost], and computes accurate
  /// per-model labor, profit, and unit selling prices.
  static List<ProjectItemPricingBreakdown> evaluateProjectItems({
    required List<SavedProjectItem> items,
    required PricingSummary projectSummary,
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
    List<MaterialRateItem> glassCatalog = const [],
    List<MaterialRateItem> hardwareCatalog = const [],
    Map<String, CustomMaterialRateOverride> materialOverrides = const {},
    bool useItemOwnMaterialSpecs = true,
  }) {
    if (items.isEmpty) return const [];

    final mergedGlass = mergeMaterialRates(
      glassCatalog,
      materialOverrides,
      category: 'GLASS',
    );

    final standaloneEvals = <({
      SavedProjectItem item,
      int qty,
      double areaSqM,
      double alu,
      double glass,
      double hw,
      double totalMat,
      String effThick,
      String effColor,
      String effGlassLabel,
    })>[];

    for (final it in items) {
      final spec = useItemOwnMaterialSpecs
          ? resolveItemMaterialSpec(
              item: it,
              fallbackThickness: projectSummary.selectedThickness,
              fallbackColor: projectSummary.selectedColor,
              fallbackIncludeGlass: projectSummary.includeGlass,
              fallbackGlassKey: projectSummary.selectedGlassKey,
              fallbackGlassRatePerSqM: projectSummary.glassRatePerSqM,
              fallbackIncludeHardware: projectSummary.includeHardware,
              mergedGlassRates: mergedGlass,
            )
          : ResolvedItemMaterialSpec(
              thickness: projectSummary.selectedThickness,
              color: projectSummary.selectedColor,
              includeGlass: projectSummary.includeGlass,
              glassKey: projectSummary.selectedGlassKey,
              glassRatePerSqM: projectSummary.glassRatePerSqM,
              glassLabel:
                  projectSummary.selectedGlassKey.replaceFirst('GLASS|', ''),
              includeHardware: projectSummary.includeHardware,
            );

      final itemGroups = BinPacker.packSingleCalculation(
        brandKey: it.priceBrandKey,
        sets: it.evaluatedSets,
        specThickness: spec.thickness,
        specColor: spec.color,
      );
      final itemGlasses =
          it.evaluatedSets.expand((s) => s.glasses).toList();
      final itemArea = it.totalOpeningAreaSqM;
      final effIncGlass = projectSummary.includeGlass && spec.includeGlass;
      final effIncHw = projectSummary.includeHardware && spec.includeHardware;

      final ev = evaluate(
        barGroups: itemGroups,
        mode: projectSummary.mode,
        wastePercent: projectSummary.wastePercent,
        selectedThickness: spec.thickness,
        selectedColor: spec.color,
        useGroupSpecs: useItemOwnMaterialSpecs,
        ormCatalog: ormCatalog,
        customOverrides: customOverrides,
        glasses: itemGlasses,
        openingAreaSqM: itemArea,
        fallbackOpeningAreaSqM: itemArea * 0.88,
        hardware: it.hardware,
        includeGlass: effIncGlass,
        selectedGlassKey: spec.glassKey,
        glassRatePerSqM: spec.glassRatePerSqM,
        includeHardware: effIncHw,
        hardwareCatalog: hardwareCatalog,
        materialOverrides: materialOverrides,
        laborMode: LaborCostMode.perSqM,
        laborRate: 0.0,
        profitPercent: 0.0,
        profitBaseMode: projectSummary.profitBaseMode,
      );

      standaloneEvals.add((
        item: it,
        qty: it.totalUnits > 0 ? it.totalUnits : 1,
        areaSqM: itemArea,
        alu: ev.aluminumCost,
        glass: effIncGlass ? ev.glassCost : 0.0,
        hw: effIncHw ? ev.hardwareCost : 0.0,
        totalMat: ev.totalCost,
        effThick: spec.thickness,
        effColor: spec.color,
        effGlassLabel: effIncGlass ? spec.glassLabel : 'ไม่รวมกระจก',
      ));
    }

    final sumStandaloneMat =
        standaloneEvals.fold<double>(0.0, (s, e) => s + e.totalMat);
    final totalArea =
        standaloneEvals.fold<double>(0.0, (s, e) => s + e.areaSqM);
    final totalUnitsAll =
        standaloneEvals.fold<int>(0, (s, e) => s + e.qty);

    // Reconcile per-item material cost so sum == projectSummary.totalCost
    final allocatedMats = <double>[];
    double matRunning = 0.0;
    for (int i = 0; i < standaloneEvals.length; i++) {
      final e = standaloneEvals[i];
      if (i == standaloneEvals.length - 1) {
        final rem = round2(
          (projectSummary.totalCost - matRunning).clamp(0.0, double.infinity),
        );
        allocatedMats.add(rem);
        matRunning = round2(matRunning + rem);
      } else {
        final double weight;
        if (sumStandaloneMat > 0) {
          weight = e.totalMat / sumStandaloneMat;
        } else if (totalArea > 0) {
          weight = e.areaSqM / totalArea;
        } else {
          weight = totalUnitsAll > 0
              ? (e.qty / totalUnitsAll)
              : (1.0 / standaloneEvals.length);
        }
        final share = round2(projectSummary.totalCost * weight);
        allocatedMats.add(share);
        matRunning = round2(matRunning + share);
      }
    }

    // Compute cost-weighted unit selling prices via unified allocator
    final unitPrices = allocateQuotationLineUnitPrices(
      items: List.generate(
        standaloneEvals.length,
        (i) => (
          materialCost: allocatedMats[i],
          areaSqM: standaloneEvals[i].areaSqM,
          qty: standaloneEvals[i].qty,
        ),
      ),
      laborMode: projectSummary.laborMode,
      laborRate: projectSummary.laborRate,
      profitPercent: projectSummary.profitPercent,
      profitBaseMode: projectSummary.profitBaseMode,
      targetTotal: projectSummary.suggestedSellingPrice,
    );

    final out = <ProjectItemPricingBreakdown>[];
    for (int i = 0; i < standaloneEvals.length; i++) {
      final e = standaloneEvals[i];
      final allocMat = allocatedMats[i];
      final double itemLabor;
      switch (projectSummary.laborMode) {
        case LaborCostMode.perSqM:
          itemLabor = round2(e.areaSqM * projectSummary.laborRate);
          break;
        case LaborCostMode.percentOfMaterial:
          itemLabor = round2(
            allocMat * (projectSummary.laborRate.clamp(0.0, 200.0) / 100.0),
          );
          break;
        case LaborCostMode.flatBaht:
          final ratio = totalArea > 0
              ? (e.areaSqM / totalArea)
              : (projectSummary.totalCost > 0
                  ? (allocMat / projectSummary.totalCost)
                  : (1.0 / standaloneEvals.length));
          itemLabor = round2(projectSummary.laborCost * ratio);
          break;
      }
      final profitBase =
          projectSummary.profitBaseMode == ProfitBaseMode.materialAndLabor
              ? (allocMat + itemLabor)
              : allocMat;
      final itemProfit =
          round2(profitBase * (projectSummary.profitPercent / 100.0));
      final uPrice = unitPrices[i];
      final lineTotal = round2(uPrice * e.qty);

      out.add(
        ProjectItemPricingBreakdown(
          item: e.item,
          totalUnits: e.qty,
          openingAreaSqM: round2(e.areaSqM),
          standaloneAluminumCost: e.alu,
          standaloneGlassCost: e.glass,
          standaloneHardwareCost: e.hw,
          standaloneMaterialCost: e.totalMat,
          allocatedMaterialCost: allocMat,
          laborCost: itemLabor,
          profitAmount: itemProfit,
          suggestedTotalPrice: lineTotal,
          unitSellingPrice: uPrice,
          effectiveThickness: e.effThick,
          effectiveColor: e.effColor,
          effectiveGlassLabel: e.effGlassLabel,
        ),
      );
    }
    return out;
  }

  static String colorFamily(String rawColor) {
    final c = rawColor.trim().toLowerCase();
    if (c.contains('mill') || c.contains('ตัวดิบ')) return 'mill';
    if (c.contains('ชุบขาว') || c.contains('e&a') || c.contains('(na)')) {
      return 'na';
    }
    if (c.contains('อบขาว') ||
        c.contains('8911') ||
        c.contains('คอตตอน') ||
        c.contains('ไวท์') ||
        c.contains('สีขาว')) {
      return 'white';
    }
    if (c.contains('อบดำ') ||
        c.contains('ชุบดำ') ||
        c.contains('ดำซาฮาร่า') ||
        c.contains('8816') ||
        c.contains('8815') ||
        c.contains('8819') ||
        c.contains('518') ||
        c.contains('แบล็ค') ||
        c == 'สีดำ') {
      return 'black';
    }
    if (c.contains('เทาซาฮาร่า') ||
        c.contains('อบเทา') ||
        c.contains('แพลทินั่ม') ||
        c.contains('แชมเปญ') ||
        c.contains('เมทัลลิค') ||
        c.contains('กาแล็คซี่') ||
        c.contains('8820') ||
        c.contains('8859') ||
        c.contains('502') ||
        c.contains('504')) {
      return 'grey_sahara';
    }
    if (c.contains('ทรายซาฮาร่า') ||
        c.contains('น้ำตาล') ||
        c.contains('สีชา') ||
        c.contains('ชุบชา') ||
        c.contains('8515') ||
        c.contains('8823') ||
        c.contains('8825') ||
        c.contains('510') ||
        c.contains('512') ||
        c.contains('514')) {
      return 'sand_bronze';
    }
    if (c.contains('ลายไม้') ||
        c.contains('15656') ||
        c.contains('15659')) {
      return 'wood';
    }
    return 'other';
  }

  static List<String> expandCandidateCodes(String rawCode) {
    final clean = rawCode.trim();
    if (clean.isEmpty) return const [];
    final out = <String>[clean];

    if (clean.contains('/')) {
      for (final part in clean.split('/')) {
        final p = part.trim();
        if (p.isNotEmpty && !out.contains(p)) {
          out.add(p);
        }
      }
    }

    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(clean);
    if (parenMatch != null) {
      final inner = parenMatch.group(1)!;
      for (final part in inner.split('/')) {
        final p = part.trim();
        if (p.isNotEmpty && !out.contains(p)) {
          out.add(p);
        }
      }
    }

    return out;
  }

  static double? _parseThickMm(String t) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  /// 4-Step Auto-Matcher:
  /// 1. Exact `(brand, code, selectedThickness, selectedColor)`
  /// 2. Wildcard thickness `(brand, code, 'ไม่ระบุความหนา', selectedColor)`
  /// 3. Single-manufactured-thickness fallback `(brand, code, *, selectedColor)`
  /// 4. Closest-manufactured-thickness + compound code (`SS-X107 / SS-0120`) + cross-brand color family fallback
  static OrmPriceSku? matchSku({
    required String brand,
    required String code,
    required String selectedThickness,
    required String selectedColor,
    required List<OrmPriceSku> catalog,
    required Map<String, CustomPriceOverride> overrides,
  }) {
    if (selectedThickness.isEmpty || selectedColor.isEmpty) return null;
    final merged = mergeProfileCatalog(catalog, overrides);
    final candidateCodes = expandCandidateCodes(code);
    if (candidateCodes.isEmpty) return null;

    final targetBrand = brand.trim().toUpperCase();
    final targetFam = colorFamily(selectedColor);

    for (final candCode in candidateCodes) {
      final brandCodeSkus = merged.values
          .where((s) =>
              s.brand.toUpperCase() == targetBrand &&
              s.code == candCode &&
              s.inStock)
          .toList();
      if (brandCodeSkus.isEmpty) continue;

      // Exact color match first; fallback to same color family for multi-brand projects;
      // and single-manufactured-finish fallback for anodized/mill-only roller tracks (e.g. ORM 804-03)
      var colorCandidates =
          brandCodeSkus.where((s) => s.color == selectedColor).toList();
      if (colorCandidates.isEmpty && targetFam != 'other') {
        colorCandidates = brandCodeSkus
            .where((s) => colorFamily(s.color) == targetFam)
            .toList();
      }
      if (colorCandidates.isEmpty) {
        final distinctColors = brandCodeSkus.map((s) => s.color).toSet();
        if (distinctColors.length == 1 ||
            distinctColors.every(
                (c) => colorFamily(c) == 'na' || colorFamily(c) == 'mill')) {
          colorCandidates = brandCodeSkus;
        }
      }
      if (colorCandidates.isEmpty) continue;

      // Step 1: Exact thickness
      for (final c in colorCandidates) {
        if (c.thickness == selectedThickness) return c;
      }

      // Step 2: Unspecified thickness ('ไม่ระบุความหนา')
      for (final c in colorCandidates) {
        if (c.thickness == 'ไม่ระบุความหนา') return c;
      }

      // Step 3: Single-manufactured-thickness fallback
      final distinctThick = colorCandidates.map((e) => e.thickness).toSet();
      if (distinctThick.length == 1) {
        return colorCandidates.first;
      }

      // Step 4: Closest numeric thickness fallback
      final targetMm = _parseThickMm(selectedThickness);
      if (targetMm != null) {
        OrmPriceSku? best;
        double bestDiff = double.infinity;
        for (final c in colorCandidates) {
          final cMm = _parseThickMm(c.thickness);
          if (cMm != null) {
            final diff = (cMm - targetMm).abs();
            if (diff < bestDiff) {
              bestDiff = diff;
              best = c;
            }
          }
        }
        if (best != null) return best;
      }

      return colorCandidates.first;
    }

    return null;
  }

  static Map<String, OrmPriceSku> mergeProfileCatalog(
    List<OrmPriceSku> catalog,
    Map<String, CustomPriceOverride> overrides,
  ) {
    final merged = <String, OrmPriceSku>{};
    for (final s in catalog) {
      final ov = overrides[s.skuKey];
      merged[s.skuKey] =
          ov != null ? s.withOverride(ov.pricePerBar, stock: ov.inStock) : s;
    }
    for (final ov in overrides.values) {
      if (!merged.containsKey(ov.skuKey)) {
        merged[ov.skuKey] = OrmPriceSku(
          brand: ov.brand,
          code: ov.code,
          name: ov.name,
          thickness: ov.thickness,
          color: ov.color,
          stockM: ov.stockM,
          factoryPrice: ov.pricePerBar,
          customPrice: ov.pricePerBar,
          inStock: ov.inStock,
        );
      }
    }
    return merged;
  }

  static List<MaterialRateItem> mergeMaterialRates(
    List<MaterialRateItem> seedRates,
    Map<String, CustomMaterialRateOverride> overrides, {
    required String category,
  }) {
    final map = <String, MaterialRateItem>{};
    for (final r in seedRates) {
      if (r.category != category) continue;
      final ov = overrides[r.rateKey];
      map[r.rateKey] = ov != null ? r.withOverride(ov.price) : r;
    }
    for (final ov in overrides.values) {
      if (ov.category == category && !map.containsKey(ov.rateKey)) {
        map[ov.rateKey] = MaterialRateItem(
          rateKey: ov.rateKey,
          category: ov.category,
          code: ov.code,
          name: ov.name,
          unit: ov.unit,
          factoryPrice: ov.price,
          customPrice: ov.price,
        );
      }
    }
    return map.values.toList();
  }

  static MaterialRateItem? matchHardwareRate({
    required AggregatedHardwareItem hw,
    required List<MaterialRateItem> mergedHwRates,
  }) {
    final cleanCode = hw.code.trim();
    final cleanName = hw.name.trim();
    final exactKey = cleanCode.isNotEmpty
        ? 'HW|$cleanCode|$cleanName'
        : 'HW||$cleanName';

    for (final r in mergedHwRates) {
      if (r.rateKey == exactKey) return r;
    }
    if (cleanCode.isNotEmpty) {
      for (final r in mergedHwRates) {
        if (r.code.trim().toUpperCase() == cleanCode.toUpperCase()) return r;
      }
    }
    for (final r in mergedHwRates) {
      if (r.name.trim().toLowerCase() == cleanName.toLowerCase()) return r;
    }
    return null;
  }

  /// Computes available thickness and color choices WITHOUT locking out dropdowns
  /// when some profile codes are awaiting user prices.
  static PricingCatalogAvailability computeAvailability({
    required List<ProfileBarGroup> barGroups,
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
    String? preferredColor,
  }) {
    if (barGroups.isEmpty) {
      return const PricingCatalogAvailability(
        isComplete: true,
        availableThicknesses: fallbackDefaultThicknesses,
        availableColors: fallbackDefaultColors,
      );
    }

    final merged = mergeProfileCatalog(ormCatalog, customOverrides);
    final colorSet = <String>{};
    final colorCoverage = <String, int>{};

    for (final grp in barGroups) {
      final candCodes = expandCandidateCodes(grp.code).toSet();
      final grpColors = <String>{};
      for (final s in merged.values) {
        if (s.brand.toUpperCase() == grp.brand.toUpperCase() &&
            candCodes.contains(s.code) &&
            s.inStock) {
          grpColors.add(s.color);
          colorSet.add(s.color);
        }
      }
      for (final c in grpColors) {
        colorCoverage[c] = (colorCoverage[c] ?? 0) + 1;
      }
    }

    if (colorSet.isEmpty) {
      return const PricingCatalogAvailability(
        isComplete: false,
        availableThicknesses: fallbackDefaultThicknesses,
        availableColors: fallbackDefaultColors,
      );
    }

    final orderedColors = colorSet.toList()
      ..sort((a, b) {
        final covCmp = (colorCoverage[b] ?? 0).compareTo(colorCoverage[a] ?? 0);
        if (covCmp != 0) return covCmp;
        final ia = standardColors.indexOf(a);
        final ib = standardColors.indexOf(b);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return a.compareTo(b);
      });

    final activeColor =
        (preferredColor != null && orderedColors.contains(preferredColor))
            ? preferredColor
            : (orderedColors.contains('ตัวดิบ MILL')
                ? 'ตัวดิบ MILL'
                : orderedColors.first);
    final activeFam = colorFamily(activeColor);

    final candidateThicknesses = <String>{};
    for (final grp in barGroups) {
      final candCodes = expandCandidateCodes(grp.code).toSet();
      for (final s in merged.values) {
        if (s.brand.toUpperCase() == grp.brand.toUpperCase() &&
            candCodes.contains(s.code) &&
            (s.color == activeColor ||
                (activeFam != 'other' && colorFamily(s.color) == activeFam)) &&
            s.inStock) {
          candidateThicknesses.add(s.thickness);
        }
      }
    }

    final orderedThicknesses = <String>[
      ...standardThicknesses.where(candidateThicknesses.contains),
      ...candidateThicknesses.where((t) => !standardThicknesses.contains(t)),
    ];

    final finalThicknesses = orderedThicknesses.isNotEmpty
        ? orderedThicknesses
        : fallbackDefaultThicknesses;

    final sampleThick = finalThicknesses.contains('1.2 มม.')
        ? '1.2 มม.'
        : finalThicknesses.first;
    final allMatched = barGroups.every(
      (grp) =>
          matchSku(
            brand: grp.brand,
            code: grp.code,
            selectedThickness: sampleThick,
            selectedColor: activeColor,
            catalog: ormCatalog,
            overrides: customOverrides,
          ) !=
          null,
    );

    return PricingCatalogAvailability(
      isComplete: allMatched,
      availableThicknesses: finalThicknesses,
      availableColors: orderedColors,
    );
  }

  static PricingSummary evaluate({
    required List<ProfileBarGroup> barGroups,
    required PricingMode mode,
    required double wastePercent,
    required String selectedThickness,
    required String selectedColor,
    bool useGroupSpecs = true,
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
    List<EvaluatedGlassItem> glasses = const [],
    List<({
      EvaluatedGlassItem glass,
      double ratePerSqM,
      String glassLabel,
      double fallbackOpeningSqM,
    })>? perItemGlassEntries,
    double fallbackOpeningAreaSqM = 0.0,
    double? openingAreaSqM,
    List<AggregatedHardwareItem> hardware = const [],
    bool includeGlass = false,
    String selectedGlassKey = '',
    double glassRatePerSqM = 0.0,
    bool includeHardware = false,
    List<MaterialRateItem> hardwareCatalog = const [],
    Map<String, CustomMaterialRateOverride> materialOverrides = const {},
    LaborCostMode laborMode = LaborCostMode.perSqM,
    double laborRate = 0.0,
    double profitPercent = 0.0,
    ProfitBaseMode profitBaseMode = ProfitBaseMode.materialOnly,
  }) {
    final lines = <ProfileCostLine>[];
    int matched = 0;
    double aluSum = 0.0;

    for (final grp in barGroups) {
      final effThick = (useGroupSpecs &&
              grp.specThickness != null &&
              grp.specThickness!.trim().isNotEmpty)
          ? grp.specThickness!.trim()
          : selectedThickness;
      final effColor = (useGroupSpecs &&
              grp.specColor != null &&
              grp.specColor!.trim().isNotEmpty)
          ? grp.specColor!.trim()
          : selectedColor;
      final sku = matchSku(
        brand: grp.brand,
        code: grp.code,
        selectedThickness: effThick,
        selectedColor: effColor,
        catalog: ormCatalog,
        overrides: customOverrides,
      );

      if (sku == null) {
        lines.add(
          ProfileCostLine(
            group: grp,
            matchNote: 'รอตั้งราคา (${grp.brand} · ${grp.code}) — แตะเพื่อใส่ราคา',
          ),
        );
        continue;
      }

      final barPrice = sku.effectivePrice;
      final stockM = sku.stockM > 0 ? sku.stockM : (grp.stockLengthMm / 1000.0);
      double cost;
      if (mode == PricingMode.actualLength) {
        if (grp.exactCutSumMm > 0) {
          final usedM = grp.exactCutSumMm / 1000.0;
          cost = round2(
              (usedM / stockM) * barPrice * (1.0 + wastePercent / 100.0));
        } else {
          // Site-measured profile with estimated bars
          cost = round2(grp.totalBars * barPrice);
        }
      } else {
        cost = round2(grp.totalBars * barPrice * (1.0 + wastePercent / 100.0));
      }

      matched++;
      aluSum = round2(aluSum + cost);

      final codeHint = sku.code != grp.code.trim() ? '${sku.code} · ' : '';
      final priceOrigin = sku.customPrice != null
          ? ' · ราคาแก้เอง'
          : (sku.isEstimated ? ' · ราคาประมาณการ' : '');

      lines.add(
        ProfileCostLine(
          group: grp,
          matchedSku: sku,
          matchNote: '$codeHint${sku.thickness} · ${sku.color}$priceOrigin',
          unitPricePerBar: barPrice,
          lineCost: cost,
        ),
      );
    }

    // Evaluate Glass Cost Lines (supports per-item distinct glass specs!)
    final glassLines = <GlassCostLine>[];
    double glassAreaSum = 0.0;
    double glassSum = 0.0;

    if (perItemGlassEntries != null) {
      for (final entry in perItemGlassEntries) {
        final g = entry.glass;
        final rate = entry.ratePerSqM;
        final labelTag = entry.glassLabel.trim().isNotEmpty
            ? ' · ${entry.glassLabel.trim()}'
            : '';
        final w = g.widthMm ?? 0.0;
        final h = g.heightMm ?? 0.0;
        if (g.siteCut || w <= 0 || h <= 0) {
          if (entry.fallbackOpeningSqM > 0) {
            final estSqM = entry.fallbackOpeningSqM;
            final cost = round2(estSqM * rate);
            glassAreaSum = round2(glassAreaSum + estSqM);
            glassSum = round2(glassSum + cost);
            glassLines.add(
              GlassCostLine(
                item: g,
                areaSqM: round2(estSqM),
                ratePerSqM: rate,
                lineCost: cost,
                note:
                    'ประมาณการ ~${estSqM.toStringAsFixed(2)} ตร.ม. (${g.totalPanels} แผ่น · วัดตัดหน้างาน)$labelTag',
              ),
            );
          } else {
            glassLines.add(
              GlassCostLine(
                item: g,
                areaSqM: 0.0,
                ratePerSqM: rate,
                lineCost: null,
                note: 'วัดตัดหน้างาน (${g.totalPanels} แผ่น)$labelTag',
              ),
            );
          }
        } else {
          final singleSqM = (w * h) / 1000000.0;
          final totalSqM = singleSqM * g.totalPanels;
          final cost = round2(totalSqM * rate);
          glassAreaSum = round2(glassAreaSum + totalSqM);
          glassSum = round2(glassSum + cost);
          glassLines.add(
            GlassCostLine(
              item: g,
              areaSqM: round2(totalSqM),
              ratePerSqM: rate,
              lineCost: cost,
              note:
                  '${w.round()} × ${h.round()} มม. × ${g.totalPanels} แผ่น (${totalSqM.toStringAsFixed(2)} ตร.ม.)$labelTag',
            ),
          );
        }
      }
    } else {
      final siteCutItems = glasses
          .where((g) => g.siteCut || (g.widthMm ?? 0) <= 0 || (g.heightMm ?? 0) <= 0)
          .toList();
      final totalSitePanels =
          siteCutItems.fold<int>(0, (s, g) => s + g.totalPanels);

      for (final g in glasses) {
        final w = g.widthMm ?? 0.0;
        final h = g.heightMm ?? 0.0;
        if (g.siteCut || w <= 0 || h <= 0) {
          if (fallbackOpeningAreaSqM > 0 && totalSitePanels > 0) {
            final estSqM =
                fallbackOpeningAreaSqM * (g.totalPanels / totalSitePanels);
            final cost = round2(estSqM * glassRatePerSqM);
            glassAreaSum = round2(glassAreaSum + estSqM);
            glassSum = round2(glassSum + cost);
            glassLines.add(
              GlassCostLine(
                item: g,
                areaSqM: round2(estSqM),
                ratePerSqM: glassRatePerSqM,
                lineCost: cost,
                note:
                    'ประมาณการจากช่องเปิด ~${estSqM.toStringAsFixed(2)} ตร.ม. (${g.totalPanels} แผ่น · วัดตัดหน้างาน)',
              ),
            );
          } else {
            glassLines.add(
              GlassCostLine(
                item: g,
                areaSqM: 0.0,
                ratePerSqM: glassRatePerSqM,
                lineCost: null,
                note: 'วัดตัดหน้างาน (${g.totalPanels} แผ่น)',
              ),
            );
          }
        } else {
          final singleSqM = (w * h) / 1000000.0;
          final totalSqM = singleSqM * g.totalPanels;
          final cost = round2(totalSqM * glassRatePerSqM);
          glassAreaSum = round2(glassAreaSum + totalSqM);
          glassSum = round2(glassSum + cost);
          glassLines.add(
            GlassCostLine(
              item: g,
              areaSqM: round2(totalSqM),
              ratePerSqM: glassRatePerSqM,
              lineCost: cost,
              note:
                  '${w.round()} × ${h.round()} มม. × ${g.totalPanels} แผ่น (${totalSqM.toStringAsFixed(2)} ตร.ม.)',
            ),
          );
        }
      }
    }

    // Evaluate Hardware Cost Lines
    final mergedHw = mergeMaterialRates(
      hardwareCatalog,
      materialOverrides,
      category: 'HARDWARE',
    );
    final hwLines = <HardwareCostLine>[];
    double hwSum = 0.0;
    for (final h in hardware) {
      final rate = matchHardwareRate(hw: h, mergedHwRates: mergedHw);
      final qty = h.effectiveQty;
      if (qty == null || qty <= 0) {
        hwLines.add(
          HardwareCostLine(
            item: h,
            matchedRate: rate,
            unitPrice: rate?.effectivePrice,
            lineCost: null,
            note: '${h.displayQty} (ตามหน้างาน)',
          ),
        );
      } else if (rate == null) {
        hwLines.add(
          HardwareCostLine(
            item: h,
            note: '${h.displayQty} · แตะเพื่อตั้งราคาต่อหน่วย',
          ),
        );
      } else {
        final uPrice = rate.effectivePrice;
        final cost = round2(qty * uPrice);
        hwSum = round2(hwSum + cost);
        final tag = rate.customPrice != null
            ? ' · ราคาแก้เอง'
            : (rate.isEstimated ? ' · ราคาประมาณการ' : '');
        hwLines.add(
          HardwareCostLine(
            item: h,
            matchedRate: rate,
            unitPrice: uPrice,
            lineCost: cost,
            note: '${h.displayQty} × ฿${uPrice.toStringAsFixed(2)}/${rate.unit}$tag',
          ),
        );
      }
    }

    final grandTotal = round2(
      aluSum +
          (includeGlass ? glassSum : 0.0) +
          (includeHardware ? hwSum : 0.0),
    );
    final effectiveOpeningSqM = openingAreaSqM ??
        (fallbackOpeningAreaSqM > 0 ? round2(fallbackOpeningAreaSqM / 0.88) : 0.0);
    final selling = computeSellingBreakdown(
      materialCost: grandTotal,
      openingAreaSqM: effectiveOpeningSqM,
      laborMode: laborMode,
      laborRate: laborRate,
      profitPercent: profitPercent,
      profitBaseMode: profitBaseMode,
    );

    return PricingSummary(
      mode: mode,
      wastePercent: wastePercent,
      selectedThickness: selectedThickness,
      selectedColor: selectedColor,
      lines: lines,
      matchedCount: matched,
      totalCount: barGroups.length,
      aluminumCost: aluSum,
      includeGlass: includeGlass,
      selectedGlassKey: selectedGlassKey,
      glassRatePerSqM: glassRatePerSqM,
      glassLines: glassLines,
      totalGlassAreaSqM: glassAreaSum,
      glassCost: glassSum,
      includeHardware: includeHardware,
      hardwareLines: hwLines,
      hardwareCost: hwSum,
      totalCost: grandTotal,
      openingAreaSqM: selling.openingAreaSqM,
      laborMode: selling.laborMode,
      laborRate: selling.laborRate,
      laborCost: selling.laborCost,
      profitPercent: selling.profitPercent,
      profitBaseMode: selling.profitBaseMode,
      profitAmount: selling.profitAmount,
      suggestedSellingPrice: selling.suggestedSellingPrice,
    );
  }
}
