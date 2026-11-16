import '../data/app_database.dart';
import '../models/app_models.dart';

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
}

class PricingSummary {
  final PricingMode mode;
  final double wastePercent;
  final String selectedThickness;
  final String selectedColor;
  final List<ProfileCostLine> lines;
  final int matchedCount;
  final int totalCount;
  final double totalCost;

  const PricingSummary({
    required this.mode,
    required this.wastePercent,
    required this.selectedThickness,
    required this.selectedColor,
    required this.lines,
    required this.matchedCount,
    required this.totalCount,
    required this.totalCost,
  });
}

class PricingEngine {
  PricingEngine._();

  static const List<String> standardThicknesses = [
    '1.0 มม.',
    '1.2 มม.',
    '1.5 มม.',
    '1.6 มม.',
    '1.7 มม.',
    '1.8 มม.',
    '2.0 มม.',
    'ไม่ระบุความหนา',
  ];

  static const List<String> standardColors = [
    'ตัวดิบ MILL',
    'ชา 512',
    'ชา 513',
    'ชา 514',
    'ขาวนม PC',
    'ดำ PC',
    'เทาซาฮาร่า SAHARA',
    'ขาวมุก',
    'ลายไม้สัก',
    'ลายไม้โอ๊ค',
  ];

  static double round2(double v) => (v * 100.0).round() / 100.0;

  /// Exact 3-Step Toolkit v0.1.7 Auto-Matcher:
  /// 1. Exact `(brand, code, selectedThickness, selectedColor)`
  /// 2. Wildcard thickness `(brand, code, 'ไม่ระบุความหนา', selectedColor)`
  /// 3. Single-manufactured-thickness fallback `(brand, code, *, selectedColor)`
  ///    when the manufacturer only makes 1 thickness in that color (e.g. `801-23` at `1.5 มม.`).
  static OrmPriceSku? matchSku({
    required String brand,
    required String code,
    required String selectedThickness,
    required String selectedColor,
    required List<OrmPriceSku> catalog,
    required Map<String, CustomPriceOverride> overrides,
  }) {
    final normCode = code.trim();
    // Apply custom overrides & custom-added SKUs
    final merged = <String, OrmPriceSku>{};
    for (final s in catalog) {
      final ov = overrides[s.skuKey];
      merged[s.skuKey] = ov != null
          ? s.withOverride(ov.pricePerBar, stock: ov.inStock)
          : s;
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

    final candidates = merged.values
        .where((s) =>
            s.brand.toUpperCase() == brand.toUpperCase() &&
            s.code == normCode &&
            s.color == selectedColor &&
            s.inStock)
        .toList();

    if (candidates.isEmpty) return null;

    // Step 1: Exact thickness
    for (final c in candidates) {
      if (c.thickness == selectedThickness) return c;
    }

    // Step 2: Unspecified thickness ('ไม่ระบุความหนา')
    for (final c in candidates) {
      if (c.thickness == 'ไม่ระบุความหนา') return c;
    }

    // Step 3: Single-manufactured-thickness fallback
    final distinctThick = candidates.map((e) => e.thickness).toSet();
    if (distinctThick.length == 1) {
      return candidates.first;
    }

    return null;
  }

  static PricingSummary evaluate({
    required List<ProfileBarGroup> barGroups,
    required PricingMode mode,
    required double wastePercent,
    required String selectedThickness,
    required String selectedColor,
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
  }) {
    final lines = <ProfileCostLine>[];
    int matched = 0;
    double sum = 0.0;

    for (final grp in barGroups) {
      final sku = matchSku(
        brand: grp.brand,
        code: grp.code,
        selectedThickness: selectedThickness,
        selectedColor: selectedColor,
        catalog: ormCatalog,
        overrides: customOverrides,
      );

      if (sku == null) {
        lines.add(
          ProfileCostLine(
            group: grp,
            matchNote: 'ไม่พบราคา (${grp.brand} · ${grp.code})',
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
          cost = round2((usedM / stockM) * barPrice * (1.0 + wastePercent / 100.0));
        } else {
          // Site-measured profile with estimated bars
          cost = round2(grp.totalBars * barPrice);
        }
      } else {
        cost = round2(grp.totalBars * barPrice * (1.0 + wastePercent / 100.0));
      }

      matched++;
      sum = round2(sum + cost);

      lines.add(
        ProfileCostLine(
          group: grp,
          matchedSku: sku,
          matchNote: '${sku.thickness} · ${sku.color}',
          unitPricePerBar: barPrice,
          lineCost: cost,
        ),
      );
    }

    return PricingSummary(
      mode: mode,
      wastePercent: wastePercent,
      selectedThickness: selectedThickness,
      selectedColor: selectedColor,
      lines: lines,
      matchedCount: matched,
      totalCount: barGroups.length,
      totalCost: sum,
    );
  }
}
