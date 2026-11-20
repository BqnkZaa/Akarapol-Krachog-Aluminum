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
  });
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

  static const List<String> standardColors = [
    'ตัวดิบ MILL',
    'ชุบขาว',
    'อบขาว (8911)',
    'อบดำ (8816)',
    'เทาซาฮาร่า (8820)',
    'ทรายซาฮาร่า (8515)',
    'สีชา',
    'ลายไม้ (15656 / 15659)',
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

  static String colorFamily(String rawColor) {
    final c = rawColor.trim().toLowerCase();
    if (c.contains('mill') || c.contains('ตัวดิบ')) return 'mill';
    if (c.contains('ชุบขาว')) return 'na';
    if (c.contains('อบขาว') || c.contains('คอตตอน') || c.contains('ไวท์')) {
      return 'white';
    }
    if (c.contains('อบดำ') || c.contains('แบล็ค') || c == 'สีดำ') {
      return 'black';
    }
    if (c.contains('เทาซาฮาร่า') ||
        c.contains('แชมเปญ') ||
        c.contains('เมทัลลิค') ||
        c.contains('กาแล็คซี่')) {
      return 'grey_sahara';
    }
    if (c.contains('ทรายซาฮาร่า') || c.contains('สีชา') || c.contains('ชุบชา')) {
      return 'sand_bronze';
    }
    if (c.contains('ลายไม้')) return 'wood';
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
    required List<OrmPriceSku> ormCatalog,
    required Map<String, CustomPriceOverride> customOverrides,
    List<EvaluatedGlassItem> glasses = const [],
    double fallbackOpeningAreaSqM = 0.0,
    List<AggregatedHardwareItem> hardware = const [],
    bool includeGlass = false,
    String selectedGlassKey = '',
    double glassRatePerSqM = 0.0,
    bool includeHardware = false,
    List<MaterialRateItem> hardwareCatalog = const [],
    Map<String, CustomMaterialRateOverride> materialOverrides = const {},
  }) {
    final lines = <ProfileCostLine>[];
    int matched = 0;
    double aluSum = 0.0;

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

    // Evaluate Glass Cost Lines
    final glassLines = <GlassCostLine>[];
    double glassAreaSum = 0.0;
    double glassSum = 0.0;
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
      final qty = h.numericQty;
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
    );
  }
}
