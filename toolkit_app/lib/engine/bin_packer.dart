import '../models/app_models.dart';

class _GroupBucket {
  final String brand;
  final String code;
  final int stockMm;
  final String? specThickness;
  final String? specColor;
  final List<String> partNames = [];
  final List<PlacedCut> cuts = [];
  double estimatedTotalMm = 0.0;

  _GroupBucket({
    required this.brand,
    required this.code,
    required this.stockMm,
    this.specThickness,
    this.specColor,
  });

  void addPartName(String name) {
    if (name.trim().isNotEmpty && !partNames.contains(name.trim())) {
      partNames.add(name.trim());
    }
  }
}

class BinPacker {
  BinPacker._();

  static const int endTrimAllowanceMm = 100;
  static const int sawKerfMm = 4;

  static String _effectiveBrand(EvaluatedCutItem cut, String fallbackBrand) {
    final ov = cut.brandOverride?.trim();
    return (ov != null && ov.isNotEmpty) ? ov : fallbackBrand;
  }

  static String? _cleanOptionSpec(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'ไม่ระบุ' || t == 'ตามรายการ') return null;
    return t;
  }

  static String? _extractItemThickness(SavedProjectItem item) {
    final opts = item.selectedOptions;
    final p = _cleanOptionSpec(opts['pricing_alu_thick']);
    if (p != null) return p;
    final s = _cleanOptionSpec(opts['spec_alu_thick']);
    if (s != null) return s;
    final t = _cleanOptionSpec(opts['thickness']);
    if (t != null) return t.endsWith('มม.') ? t : '$t มม.';
    return null;
  }

  static String? _extractItemColor(SavedProjectItem item) {
    final opts = item.selectedOptions;
    final p = _cleanOptionSpec(opts['pricing_alu_color']);
    if (p != null) return p;
    return _cleanOptionSpec(opts['spec_alu_color']);
  }

  /// Packs cuts from a single calculation (`Tab 3 จัดเส้น` & `Single Cut PDF`).
  static List<ProfileBarGroup> packSingleCalculation({
    required String brandKey,
    required List<EvaluatedSetResult> sets,
    String? specThickness,
    String? specColor,
  }) {
    final buckets = <String, _GroupBucket>{};
    final cleanThick = _cleanOptionSpec(specThickness);
    final cleanColor = _cleanOptionSpec(specColor);

    for (final setRes in sets) {
      for (final cut in setRes.cuts) {
        if (cut.stockMm <= 0) continue;
        final effBrand = _effectiveBrand(cut, brandKey);
        if (cut.isSiteMeasured) {
          if (cut.estimatedTotalMm != null && cut.estimatedTotalMm! > 0) {
            final key = '$effBrand|${cut.code}|${cut.stockMm}';
            final bucket = buckets.putIfAbsent(
              key,
              () => _GroupBucket(
                brand: effBrand,
                code: cut.code,
                stockMm: cut.stockMm,
                specThickness: cleanThick,
                specColor: cleanColor,
              ),
            );
            bucket.addPartName(cut.name);
            bucket.estimatedTotalMm += cut.estimatedTotalMm!;
          }
        } else if (cut.lengthMm != null && cut.lengthMm! > 0) {
          final key = '$effBrand|${cut.code}|${cut.stockMm}';
          final bucket = buckets.putIfAbsent(
            key,
            () => _GroupBucket(
              brand: effBrand,
              code: cut.code,
              stockMm: cut.stockMm,
              specThickness: cleanThick,
              specColor: cleanColor,
            ),
          );
          bucket.addPartName(cut.name);
          for (int i = 0; i < cut.totalQty; i++) {
            bucket.cuts.add(
              PlacedCut(
                lengthMm: cut.lengthMm!,
                partName: cut.name,
              ),
            );
          }
        }
      }
    }

    return _finalizeBuckets(buckets.values);
  }

  /// Cross-item 1D FFD bin-packing across all saved items in a project!
  /// Tags every cut with `[01]`, `[02]`, or custom `[refCode]`.
  /// When [separateByItemMaterialSpec] is true (default), items with different
  /// selected aluminum thickness/color are packed into separate bar stock groups
  /// so different colors or thicknesses never mix on the same 6.4 m bar.
  static List<ProfileBarGroup> packProjectItems(
    List<SavedProjectItem> items, {
    bool separateByItemMaterialSpec = true,
  }) {
    final buckets = <String, _GroupBucket>{};

    for (int idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final tag = '[${item.displayOrderTag(idx + 1)}]';
      final itemThick =
          separateByItemMaterialSpec ? _extractItemThickness(item) : null;
      final itemColor =
          separateByItemMaterialSpec ? _extractItemColor(item) : null;
      final specSuffix = separateByItemMaterialSpec
          ? '|${itemThick ?? ""}|${itemColor ?? ""}'
          : '';
      for (final setRes in item.evaluatedSets) {
        for (final cut in setRes.cuts) {
          if (cut.stockMm <= 0) continue;
          final effBrand = _effectiveBrand(cut, item.priceBrandKey);
          if (cut.isSiteMeasured) {
            if (cut.estimatedTotalMm != null && cut.estimatedTotalMm! > 0) {
              final key = '$effBrand|${cut.code}|${cut.stockMm}$specSuffix';
              final bucket = buckets.putIfAbsent(
                key,
                () => _GroupBucket(
                  brand: effBrand,
                  code: cut.code,
                  stockMm: cut.stockMm,
                  specThickness: itemThick,
                  specColor: itemColor,
                ),
              );
              bucket.addPartName(cut.name);
              bucket.estimatedTotalMm += cut.estimatedTotalMm!;
            }
          } else if (cut.lengthMm != null && cut.lengthMm! > 0) {
            final key = '$effBrand|${cut.code}|${cut.stockMm}$specSuffix';
            final bucket = buckets.putIfAbsent(
              key,
              () => _GroupBucket(
                brand: effBrand,
                code: cut.code,
                stockMm: cut.stockMm,
                specThickness: itemThick,
                specColor: itemColor,
              ),
            );
            bucket.addPartName(cut.name);
            for (int i = 0; i < cut.totalQty; i++) {
              bucket.cuts.add(
                PlacedCut(
                  lengthMm: cut.lengthMm!,
                  partName: cut.name,
                  itemTag: tag,
                ),
              );
            }
          }
        }
      }
    }

    return _finalizeBuckets(buckets.values);
  }

  static List<ProfileBarGroup> _finalizeBuckets(Iterable<_GroupBucket> buckets) {
    final groups = <ProfileBarGroup>[];

    for (final b in buckets) {
      final usableMm = b.stockMm - endTrimAllowanceMm;
      final exactSum = b.cuts.fold(0.0, (s, c) => s + c.lengthMm);

      // Sort cuts descending (First-Fit Decreasing), preserving original order on ties
      final indexed = b.cuts.asMap().entries.toList()
        ..sort((a, c) {
          final cmp = c.value.lengthMm.compareTo(a.value.lengthMm);
          return cmp != 0 ? cmp : a.key.compareTo(c.key);
        });

      final openBars = <List<PlacedCut>>[];
      for (final entry in indexed) {
        final piece = entry.value;
        bool placed = false;
        for (final barCuts in openBars) {
          final currentUsed = barCuts.fold(0.0, (s, x) => s + x.lengthMm) +
              (barCuts.length > 1 ? (barCuts.length - 1) * sawKerfMm : 0);
          final nextUsed = currentUsed + sawKerfMm + piece.lengthMm;
          if (nextUsed <= usableMm + 1e-6) {
            barCuts.add(piece);
            placed = true;
            break;
          }
        }
        if (!placed) {
          openBars.add([piece]);
        }
      }

      final confirmed = <BarAssignment>[];
      for (int i = 0; i < openBars.length; i++) {
        confirmed.add(
          BarAssignment(
            barIndex: i + 1,
            stockLengthMm: b.stockMm,
            cuts: openBars[i],
          ),
        );
      }

      int estBars = 0;
      if (b.estimatedTotalMm > 0) {
        estBars = (b.estimatedTotalMm / usableMm).ceil();
        if (estBars < 1) estBars = 1;
      }

      groups.add(
        ProfileBarGroup(
          brand: b.brand,
          code: b.code,
          combinedNames: b.partNames.isEmpty ? b.code : b.partNames.join(' / '),
          stockLengthMm: b.stockMm,
          confirmedBars: confirmed,
          estimatedBars: estBars,
          exactCutSumMm: exactSum,
          specThickness: b.specThickness,
          specColor: b.specColor,
        ),
      );
    }

    return groups;
  }
}
