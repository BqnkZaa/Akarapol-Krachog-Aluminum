import '../models/app_models.dart';

class _GroupBucket {
  final String brand;
  final String code;
  final int stockMm;
  final List<String> partNames = [];
  final List<PlacedCut> cuts = [];
  double estimatedTotalMm = 0.0;

  _GroupBucket({
    required this.brand,
    required this.code,
    required this.stockMm,
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

  /// Packs cuts from a single calculation (`Tab 3 จัดเส้น` & `Single Cut PDF`).
  static List<ProfileBarGroup> packSingleCalculation({
    required String brandKey,
    required List<EvaluatedSetResult> sets,
  }) {
    final buckets = <String, _GroupBucket>{};

    for (final setRes in sets) {
      for (final cut in setRes.cuts) {
        // Hardware bracket constants (e.g. 95 mm / 23 mm / 36 mm ฉากข้อต่อ) stay in cut list
        // only when cut from stock bars; in Toolkit v0.1.7 all aluminum rows in Tab 1 with stockMm
        // are grouped by code except pure hardware brackets without profile bars if code == 'ฉากข้อต่อ'
        // Wait: in Toolkit Tab 3, every non-site-measured profile row in Tab 1 is packed by code!
        final key = '$brandKey|${cut.code}|${cut.stockMm}';
        final bucket = buckets.putIfAbsent(
          key,
          () => _GroupBucket(
            brand: brandKey,
            code: cut.code,
            stockMm: cut.stockMm,
          ),
        );
        bucket.addPartName(cut.name);

        if (cut.isSiteMeasured) {
          if (cut.estimatedTotalMm != null && cut.estimatedTotalMm! > 0) {
            bucket.estimatedTotalMm += cut.estimatedTotalMm!;
          } else {
            // When site-measured without formula, Toolkit counts at least 1 estimated bar if no confirmed cuts
            bucket.estimatedTotalMm += 1.0;
          }
        } else if (cut.lengthMm != null && cut.lengthMm! > 0) {
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
  static List<ProfileBarGroup> packProjectItems(List<SavedProjectItem> items) {
    final buckets = <String, _GroupBucket>{};

    for (int idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final tag = '[${item.displayOrderTag(idx + 1)}]';
      for (final setRes in item.evaluatedSets) {
        for (final cut in setRes.cuts) {
          final key = '${item.priceBrandKey}|${cut.code}|${cut.stockMm}';
          final bucket = buckets.putIfAbsent(
            key,
            () => _GroupBucket(
              brand: item.priceBrandKey,
              code: cut.code,
              stockMm: cut.stockMm,
            ),
          );
          bucket.addPartName(cut.name);

          if (cut.isSiteMeasured) {
            if (cut.estimatedTotalMm != null && cut.estimatedTotalMm! > 0) {
              bucket.estimatedTotalMm += cut.estimatedTotalMm!;
            } else {
              bucket.estimatedTotalMm += 1.0;
            }
          } else if (cut.lengthMm != null && cut.lengthMm! > 0) {
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
        ),
      );
    }

    return groups;
  }
}
