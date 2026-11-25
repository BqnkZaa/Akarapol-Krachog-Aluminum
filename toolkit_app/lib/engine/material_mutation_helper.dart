import '../models/app_models.dart';
import 'bin_packer.dart';

/// Pure immutable helpers for editing, swapping, adding, and deleting material
/// items (Aluminum cuts / profile groups, Glass panels, and Hardware) on a
/// [CalculationOutput], automatically re-running 1D Bin-Packing every time.
class MaterialMutationHelper {
  MaterialMutationHelper._();

  static String effectiveBrandOf(EvaluatedCutItem cut, String fallbackBrand) {
    final ov = cut.brandOverride?.trim();
    return (ov != null && ov.isNotEmpty) ? ov : fallbackBrand;
  }

  static CalculationOutput repack(
    CalculationOutput output, {
    List<EvaluatedSetResult>? sets,
    List<AggregatedHardwareItem>? hardware,
  }) {
    final nextSets = sets ?? output.sets;
    final nextHardware = hardware ?? output.hardware;
    final repacked = BinPacker.packSingleCalculation(
      brandKey: output.priceBrandKey,
      sets: nextSets,
    );
    return output.copyWith(
      sets: nextSets,
      hardware: nextHardware,
      barGroups: repacked,
    );
  }

  /// Reconstructs a live editable [CalculationOutput] from a saved project item.
  static CalculationOutput fromSavedProjectItem(SavedProjectItem item) {
    final sets = item.evaluatedSets.isNotEmpty
        ? item.evaluatedSets
        : [
            EvaluatedSetResult(
              setIndex: 1,
              sizeRow: item.sizeRows.isNotEmpty
                  ? item.sizeRows.first
                  : const SizeRowInput(widthMm: 1000, heightMm: 1000, qty: 1),
              cuts: const [],
              glasses: const [],
            ),
          ];
    return CalculationOutput(
      brandTitle: item.brandTitle,
      priceBrandKey: item.priceBrandKey,
      systemTitle: item.systemTitle,
      patternId: item.patternId,
      patternTitle: item.patternTitle,
      selectedOptions: item.selectedOptions,
      sets: sets,
      hardware: item.hardware,
      barGroups: BinPacker.packSingleCalculation(
        brandKey: item.priceBrandKey,
        sets: sets,
      ),
    );
  }

  /// Helper for creating a direct-bar (site-measured) aluminum profile entry.
  static EvaluatedCutItem buildDirectBarCut({
    required String section,
    required String code,
    required String name,
    required int stockMm,
    required int barCount,
    String? brandOverride,
  }) {
    final safeBars = barCount < 1 ? 1 : barCount;
    final usableMm =
        (stockMm - BinPacker.endTrimAllowanceMm).clamp(100, 20000);
    return EvaluatedCutItem(
      section: section.trim().isEmpty ? 'เพิ่มเติม' : section.trim(),
      code: code.trim(),
      name: name.trim(),
      stockMm: stockMm,
      isSiteMeasured: true,
      lengthMm: null,
      estimatedTotalMm: (safeBars * usableMm).toDouble(),
      qtyPerSet: safeBars,
      totalQty: safeBars,
      angle: 'สั่งเต็มเส้น',
      brandOverride:
          brandOverride?.trim().isNotEmpty == true ? brandOverride!.trim() : null,
    );
  }

  /// Helper for creating a cut-length aluminum entry that feeds into 1D Bin-Packing.
  static EvaluatedCutItem buildCutLengthItem({
    required String section,
    required String code,
    required String name,
    required int stockMm,
    required double lengthMm,
    required int totalQty,
    String angle = '90° / 90°',
    String? brandOverride,
  }) {
    final safeQty = totalQty < 1 ? 1 : totalQty;
    final safeLen = lengthMm < 1 ? 1.0 : lengthMm;
    return EvaluatedCutItem(
      section: section.trim().isEmpty ? 'เพิ่มเติม' : section.trim(),
      code: code.trim(),
      name: name.trim(),
      stockMm: stockMm,
      isSiteMeasured: false,
      lengthMm: safeLen,
      estimatedTotalMm: null,
      qtyPerSet: safeQty,
      totalQty: safeQty,
      angle: angle.trim().isEmpty ? '90° / 90°' : angle.trim(),
      brandOverride:
          brandOverride?.trim().isNotEmpty == true ? brandOverride!.trim() : null,
    );
  }

  // --- Aluminum: Individual Cut Piece Operations (Tab 1) ---

  static CalculationOutput addCutItem(
    CalculationOutput output, {
    int setListIndex = 0,
    required EvaluatedCutItem cut,
  }) {
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    if (nextSets.isEmpty) {
      nextSets.add(
        EvaluatedSetResult(
          setIndex: 1,
          sizeRow: const SizeRowInput(widthMm: 1000, heightMm: 1000, qty: 1),
          cuts: [cut],
          glasses: const [],
        ),
      );
    } else {
      final idx = setListIndex.clamp(0, nextSets.length - 1);
      final target = nextSets[idx];
      nextSets[idx] = target.copyWith(cuts: [...target.cuts, cut]);
    }
    return repack(output, sets: nextSets);
  }

  static CalculationOutput updateCutItem(
    CalculationOutput output, {
    required int setListIndex,
    required int cutIndex,
    required EvaluatedCutItem cut,
  }) {
    if (setListIndex < 0 || setListIndex >= output.sets.length) return output;
    final target = output.sets[setListIndex];
    if (cutIndex < 0 || cutIndex >= target.cuts.length) return output;

    final nextCuts = List<EvaluatedCutItem>.from(target.cuts);
    nextCuts[cutIndex] = cut;
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    nextSets[setListIndex] = target.copyWith(cuts: nextCuts);
    return repack(output, sets: nextSets);
  }

  static CalculationOutput deleteCutItem(
    CalculationOutput output, {
    required int setListIndex,
    required int cutIndex,
  }) {
    if (setListIndex < 0 || setListIndex >= output.sets.length) return output;
    final target = output.sets[setListIndex];
    if (cutIndex < 0 || cutIndex >= target.cuts.length) return output;

    final nextCuts = List<EvaluatedCutItem>.from(target.cuts)
      ..removeAt(cutIndex);
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    nextSets[setListIndex] = target.copyWith(cuts: nextCuts);
    return repack(output, sets: nextSets);
  }

  // --- Aluminum: Grouped Profile Operations (Tab 2 & Tab 4) ---

  /// Swaps all cut pieces matching `(oldBrand, oldCode, oldStockMm)` to a new
  /// profile (optionally from another brand) while keeping cut lengths intact.
  /// If [overrideDirectBars] is set, replaces matching pieces with a single
  /// direct-bar entry of that bar count.
  static CalculationOutput swapProfileGroup(
    CalculationOutput output, {
    required String oldBrand,
    required String oldCode,
    required int oldStockMm,
    required String newBrand,
    required String newCode,
    required String newName,
    required int newStockMm,
    int? overrideDirectBars,
  }) {
    final normOldBrand = oldBrand.trim().toUpperCase();
    final normOldCode = oldCode.trim();
    final cleanNewBrand = newBrand.trim();
    final brandOverride =
        cleanNewBrand.toUpperCase() == output.priceBrandKey.trim().toUpperCase()
            ? null
            : cleanNewBrand;

    if (overrideDirectBars != null && overrideDirectBars > 0) {
      final withoutOld = deleteProfileGroup(
        output,
        brand: oldBrand,
        code: oldCode,
        stockMm: oldStockMm,
      );
      return addCutItem(
        withoutOld,
        setListIndex: 0,
        cut: buildDirectBarCut(
          section: 'เพิ่มเติม',
          code: newCode,
          name: newName,
          stockMm: newStockMm,
          barCount: overrideDirectBars,
          brandOverride: brandOverride,
        ),
      );
    }

    final nextSets = output.sets.map((s) {
      final nextCuts = s.cuts.map((c) {
        final effBrand = effectiveBrandOf(c, output.priceBrandKey).toUpperCase();
        if (effBrand == normOldBrand &&
            c.code.trim() == normOldCode &&
            c.stockMm == oldStockMm) {
          final isCodeChanged = c.code.trim() != newCode.trim();
          final updatedName = (isCodeChanged || newName.trim().isNotEmpty)
              ? newName.trim()
              : c.name;
          return c.copyWith(
            code: newCode.trim(),
            name: updatedName,
            stockMm: newStockMm,
            brandOverride: brandOverride,
            clearBrandOverride: brandOverride == null,
          );
        }
        return c;
      }).toList();
      return s.copyWith(cuts: nextCuts);
    }).toList();

    return repack(output, sets: nextSets);
  }

  static CalculationOutput deleteProfileGroup(
    CalculationOutput output, {
    required String brand,
    required String code,
    required int stockMm,
  }) {
    final normBrand = brand.trim().toUpperCase();
    final normCode = code.trim();
    final nextSets = output.sets.map((s) {
      final nextCuts = s.cuts.where((c) {
        final effBrand = effectiveBrandOf(c, output.priceBrandKey).toUpperCase();
        return !(effBrand == normBrand &&
            c.code.trim() == normCode &&
            c.stockMm == stockMm);
      }).toList();
      return s.copyWith(cuts: nextCuts);
    }).toList();
    return repack(output, sets: nextSets);
  }

  // --- Glass Operations (Tab 1, Tab 2, Tab 4) ---

  static CalculationOutput addGlassItem(
    CalculationOutput output, {
    int setListIndex = 0,
    required EvaluatedGlassItem glass,
  }) {
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    if (nextSets.isEmpty) {
      nextSets.add(
        EvaluatedSetResult(
          setIndex: 1,
          sizeRow: const SizeRowInput(widthMm: 1000, heightMm: 1000, qty: 1),
          cuts: const [],
          glasses: [glass],
        ),
      );
    } else {
      final idx = setListIndex.clamp(0, nextSets.length - 1);
      final target = nextSets[idx];
      nextSets[idx] = target.copyWith(
        glasses: [...target.glasses, glass.copyWith(setIndex: target.setIndex)],
      );
    }
    return output.copyWith(sets: nextSets);
  }

  static CalculationOutput updateGlassByFlatIndex(
    CalculationOutput output, {
    required int flatIndex,
    required EvaluatedGlassItem glass,
  }) {
    int cursor = 0;
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    for (int si = 0; si < nextSets.length; si++) {
      final gList = nextSets[si].glasses;
      if (flatIndex >= cursor && flatIndex < cursor + gList.length) {
        final localIdx = flatIndex - cursor;
        final updated = List<EvaluatedGlassItem>.from(gList);
        updated[localIdx] = glass.copyWith(setIndex: nextSets[si].setIndex);
        nextSets[si] = nextSets[si].copyWith(glasses: updated);
        return output.copyWith(sets: nextSets);
      }
      cursor += gList.length;
    }
    return output;
  }

  static CalculationOutput deleteGlassByFlatIndex(
    CalculationOutput output, {
    required int flatIndex,
  }) {
    int cursor = 0;
    final nextSets = List<EvaluatedSetResult>.from(output.sets);
    for (int si = 0; si < nextSets.length; si++) {
      final gList = nextSets[si].glasses;
      if (flatIndex >= cursor && flatIndex < cursor + gList.length) {
        final localIdx = flatIndex - cursor;
        final updated = List<EvaluatedGlassItem>.from(gList)
          ..removeAt(localIdx);
        nextSets[si] = nextSets[si].copyWith(glasses: updated);
        return output.copyWith(sets: nextSets);
      }
      cursor += gList.length;
    }
    return output;
  }

  // --- Hardware Operations (Tab 2 & Tab 4) ---

  static CalculationOutput addHardwareItem(
    CalculationOutput output,
    AggregatedHardwareItem item,
  ) {
    return output.copyWith(hardware: [...output.hardware, item]);
  }

  static CalculationOutput updateHardwareItem(
    CalculationOutput output,
    int index,
    AggregatedHardwareItem item,
  ) {
    if (index < 0 || index >= output.hardware.length) return output;
    final next = List<AggregatedHardwareItem>.from(output.hardware);
    next[index] = item;
    return output.copyWith(hardware: next);
  }

  static CalculationOutput deleteHardwareItem(
    CalculationOutput output,
    int index,
  ) {
    if (index < 0 || index >= output.hardware.length) return output;
    final next = List<AggregatedHardwareItem>.from(output.hardware)
      ..removeAt(index);
    return output.copyWith(hardware: next);
  }
}
