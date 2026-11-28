import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../data/seed_repository.dart';
import '../engine/material_mutation_helper.dart';
import '../engine/pricing_engine.dart';
import '../models/app_models.dart';
import 'alupro_thumbnail_widgets.dart';
import 'theme_tokens.dart';

final NumberFormat _pickerBahtFmt = NumberFormat('#,##0', 'en_US');

class CatalogProfileOption {
  final String brand;
  final String code;
  final String name;
  final double stockM;
  final double minPrice;
  final int skuCount;

  const CatalogProfileOption({
    required this.brand,
    required this.code,
    required this.name,
    required this.stockM,
    required this.minPrice,
    required this.skuCount,
  });

  int get stockMm => (stockM * 1000).round();
}

enum MaterialEditActionType { save, delete }

class AluminumCutEditResult {
  final MaterialEditActionType type;
  final EvaluatedCutItem? cut;
  final String? newBrand;
  final String? newCode;
  final String? newName;
  final int? newStockMm;
  final int? overrideDirectBars;

  const AluminumCutEditResult.saveCut(this.cut)
      : type = MaterialEditActionType.save,
        newBrand = null,
        newCode = null,
        newName = null,
        newStockMm = null,
        overrideDirectBars = null;

  const AluminumCutEditResult.swapGroup({
    required this.newBrand,
    required this.newCode,
    required this.newName,
    required this.newStockMm,
    this.overrideDirectBars,
  })  : type = MaterialEditActionType.save,
        cut = null;

  const AluminumCutEditResult.delete()
      : type = MaterialEditActionType.delete,
        cut = null,
        newBrand = null,
        newCode = null,
        newName = null,
        newStockMm = null,
        overrideDirectBars = null;
}

class GlassEditResult {
  final MaterialEditActionType type;
  final EvaluatedGlassItem? glass;

  const GlassEditResult.save(this.glass) : type = MaterialEditActionType.save;
  const GlassEditResult.delete()
      : type = MaterialEditActionType.delete,
        glass = null;
}

class HardwareEditResult {
  final MaterialEditActionType type;
  final AggregatedHardwareItem? hardware;

  const HardwareEditResult.save(this.hardware)
      : type = MaterialEditActionType.save;
  const HardwareEditResult.delete()
      : type = MaterialEditActionType.delete,
        hardware = null;
}

/// Builds deduplicated selectable aluminum profiles from the full catalog + user overrides.
List<CatalogProfileOption> buildCatalogProfileOptions({
  required List<OrmPriceSku> catalog,
  required Map<String, CustomPriceOverride> customOverrides,
}) {
  final merged = PricingEngine.mergeProfileCatalog(catalog, customOverrides);
  final grouped = <String, List<OrmPriceSku>>{};
  for (final sku in merged.values) {
    if (!sku.inStock) continue;
    final key = '${sku.brand.toUpperCase()}|${sku.code.trim()}';
    grouped.putIfAbsent(key, () => []).add(sku);
  }

  final out = <CatalogProfileOption>[];
  for (final list in grouped.values) {
    final first = list.first;
    double minP = list.first.effectivePrice;
    String bestName = first.name.trim();
    for (final s in list) {
      if (s.effectivePrice < minP) minP = s.effectivePrice;
      if (bestName.isEmpty && s.name.trim().isNotEmpty) {
        bestName = s.name.trim();
      }
    }
    out.add(
      CatalogProfileOption(
        brand: first.brand,
        code: first.code.trim(),
        name: bestName.isEmpty ? first.code.trim() : bestName,
        stockM: first.stockM > 0 ? first.stockM : 6.4,
        minPrice: minP,
        skuCount: list.length,
      ),
    );
  }

  out.sort((a, b) {
    final bc = a.brand.compareTo(b.brand);
    return bc != 0 ? bc : a.code.compareTo(b.code);
  });
  return out;
}

/// Searchable full-catalog Aluminum Profile Picker (supports cross-brand swap!).
Future<CatalogProfileOption?> showProfileCatalogPicker({
  required BuildContext context,
  required String currentBrandKey,
  Map<String, CustomPriceOverride> customOverrides = const {},
}) {
  return showModalBottomSheet<CatalogProfileOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ProfileCatalogPickerBody(
      currentBrandKey: currentBrandKey,
      customOverrides: customOverrides,
    ),
  );
}

class _ProfileCatalogPickerBody extends StatefulWidget {
  final String currentBrandKey;
  final Map<String, CustomPriceOverride> customOverrides;

  const _ProfileCatalogPickerBody({
    required this.currentBrandKey,
    required this.customOverrides,
  });

  @override
  State<_ProfileCatalogPickerBody> createState() =>
      _ProfileCatalogPickerBodyState();
}

class _ProfileCatalogPickerBodyState extends State<_ProfileCatalogPickerBody> {
  late final List<CatalogProfileOption> _allOptions;
  late final List<String> _orderedBrands;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedBrand = 'ทั้งหมด';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allOptions = buildCatalogProfileOptions(
      catalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: widget.customOverrides,
    );
    final distinctBrands = _allOptions.map((o) => o.brand).toSet().toList()
      ..sort();
    _orderedBrands = <String>[
      'ทั้งหมด',
      if (distinctBrands.contains(widget.currentBrandKey))
        widget.currentBrandKey,
      ...distinctBrands.where((b) => b != widget.currentBrandKey),
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = _allOptions.where((o) {
      if (_selectedBrand != 'ทั้งหมด' && o.brand != _selectedBrand) {
        return false;
      }
      if (q.isNotEmpty) {
        return o.code.toLowerCase().contains(q) ||
            o.name.toLowerCase().contains(q) ||
            o.brand.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เลือกหน้าตัดอลูมิเนียมจากแคตตาล็อก',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ToolkitColors.slateDark,
                        ),
                      ),
                      Text(
                        'เลือกเปลี่ยนข้ามแบรนด์ได้ · พบ ${filtered.length} หน้าตัด',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              key: const ValueKey('catalog_profile_search'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded, size: 18),
                      )
                    : null,
                hintText:
                    'ค้นหารหัสหรือชื่อ เช่น PS-0106, SS-X110, เฟรมข้าง...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _orderedBrands.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final b = _orderedBrands[i];
                final sel = _selectedBrand == b;
                final lbl =
                    b == widget.currentBrandKey ? '$b (แบรนด์ปัจจุบัน)' : b;
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(lbl, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  selectedColor: ToolkitColors.softBlueBg,
                  onSelected: (_) => setState(() => _selectedBrand = b),
                );
              },
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่พบหน้าตัดที่ค้นหา ลองคำค้นอื่นหรือพิมพ์กรอกรหัสเอง',
                      style: TextStyle(color: ToolkitColors.slateMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final opt = filtered[i];
                      final profImg = AluproImageRegistry.instance
                          .resolveProfileAsset(
                        code: opt.code,
                        name: opt.name,
                        brandKey: opt.brand,
                      );
                      return InkWell(
                        key: ValueKey('pick_profile_${opt.brand}_${opt.code}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context, opt),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 9, horizontal: 4),
                          child: Row(
                            children: [
                              if (profImg != null)
                                AluproThumbnail(
                                  assetPath: profImg,
                                  width: 50,
                                  height: 38,
                                  showZoomBadge: false,
                                )
                              else
                                Container(
                                  width: 50,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: ToolkitColors.softBlueBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.view_stream_rounded,
                                    size: 20,
                                    color: ToolkitColors.royalBlue,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: ToolkitColors.softBlueBg,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            opt.brand,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: ToolkitColors.royalBlue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            opt.code,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: ToolkitColors.slateDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: ToolkitColors.slateBody,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'เริ่ม ฿${_pickerBahtFmt.format(opt.minPrice)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: ToolkitColors.royalBlue,
                                    ),
                                  ),
                                  Text(
                                    'ยาว ${opt.stockM.toStringAsFixed(1)} ม.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ToolkitColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Searchable Hardware Catalog Picker (240 built-in hardware rates + custom overrides).
Future<MaterialRateItem?> showHardwareCatalogPicker({
  required BuildContext context,
  Map<String, CustomMaterialRateOverride> materialOverrides = const {},
}) {
  return showModalBottomSheet<MaterialRateItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _HardwareCatalogPickerBody(materialOverrides: materialOverrides),
  );
}

class _HardwareCatalogPickerBody extends StatefulWidget {
  final Map<String, CustomMaterialRateOverride> materialOverrides;

  const _HardwareCatalogPickerBody({required this.materialOverrides});

  @override
  State<_HardwareCatalogPickerBody> createState() =>
      _HardwareCatalogPickerBodyState();
}

class _HardwareCatalogPickerBodyState
    extends State<_HardwareCatalogPickerBody> {
  late final List<MaterialRateItem> _allHw;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _brandFilter = 'ทั้งหมด'; // ทั้งหมด | ALUMET | VVP | RP
  String _subCatFilter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _allHw = PricingEngine.mergeMaterialRates(
      SeedRepository.instance.visibleHardwareRates,
      widget.materialOverrides,
      category: 'HARDWARE',
    )..sort((a, b) {
        final bc = a.brand.compareTo(b.brand);
        if (bc != 0) return bc;
        return a.code.compareTo(b.code);
      });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _availableSubCategories() {
    final cats = <String>{};
    for (final h in _allHw) {
      if (_brandFilter != 'ทั้งหมด' && h.brand != _brandFilter) continue;
      if (h.subCategory.trim().isNotEmpty) {
        cats.add(h.subCategory.trim());
      }
    }
    const preferredOrder = [
      'บานเลื่อน',
      'บานเปิด',
      'บานกระทุ้ง',
      'บานเฟี้ยม',
      'สกรู / ทั่วไป',
      'โช้คประตู (บานเปลือย)',
      'ตัวหนีบกระจก (บานเปลือย)',
      'บานพับชาวเวอร์',
      'ตัวหนีบกระจกชาวเวอร์',
      'มือจับ & ตัวยึดกันแกว่ง',
      'ตัวยึดกันแกว่ง & แป๊ป',
      'มือจับประตูห้องน้ำ',
      'กุญแจล็อค & ยางกันน้ำ',
    ];
    final ordered = <String>['ทั้งหมด'];
    for (final p in preferredOrder) {
      if (cats.contains(p)) ordered.add(p);
    }
    for (final c in cats) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final subCats = _availableSubCategories();
    if (!subCats.contains(_subCatFilter)) {
      _subCatFilter = 'ทั้งหมด';
    }
    final q = _query.trim().toLowerCase();
    final filtered = _allHw.where((h) {
      if (_brandFilter != 'ทั้งหมด' && h.brand != _brandFilter) return false;
      if (_subCatFilter != 'ทั้งหมด' && h.subCategory != _subCatFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return h.code.toLowerCase().contains(q) ||
          h.name.toLowerCase().contains(q) ||
          h.subCategory.toLowerCase().contains(q) ||
          h.brand.toLowerCase().contains(q);
    }).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'คลังอุปกรณ์ ALUMET · VVP · RP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ToolkitColors.slateDark,
                        ),
                      ),
                      Text(
                        'พบ ${filtered.length} รายการ (พร้อมรูปภาพและราคามาตรฐาน)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              key: const ValueKey('catalog_hw_search'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded, size: 18),
                      )
                    : null,
                hintText:
                    'ค้นหารหัสหรือชื่อ เช่น AKL, FC 34, RP-303, ล้อ, มือจับ...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final b in const [
                  ('ทั้งหมด', 'ทั้งหมด'),
                  ('ALUMET', 'ALUMET'),
                  ('VVP', 'VVP'),
                  ('RP', 'RP Steel Glass'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(b.$2, style: const TextStyle(fontSize: 12)),
                      selected: _brandFilter == b.$1,
                      selectedColor: ToolkitColors.softBlueBg,
                      onSelected: (_) => setState(() {
                        _brandFilter = b.$1;
                        _subCatFilter = 'ทั้งหมด';
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (subCats.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: subCats
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(c, style: const TextStyle(fontSize: 11.5)),
                          selected: _subCatFilter == c,
                          selectedColor: const Color(0xFFCCFBF1),
                          onSelected: (_) => setState(() => _subCatFilter = c),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const Divider(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่พบอุปกรณ์ที่ค้นหา สามารถพิมพ์กรอกชื่อเองได้',
                      style: TextStyle(color: ToolkitColors.slateMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final hw = filtered[i];
                      final hwImg = hw.imageAssetPath ??
                          AluproImageRegistry.instance
                              .resolveHardwareAsset(code: hw.code, name: hw.name);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context, hw),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 9, horizontal: 4),
                          child: Row(
                            children: [
                              if (hwImg != null)
                                AluproThumbnail(
                                  assetPath: hwImg,
                                  width: 50,
                                  height: 42,
                                  showZoomBadge: false,
                                )
                              else
                                Container(
                                  width: 50,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: ToolkitColors.softBlueBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.hardware_rounded,
                                    size: 19,
                                    color: ToolkitColors.royalBlue,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (hw.code.trim().isNotEmpty)
                                          Text(
                                            hw.code,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: ToolkitColors.royalBlue,
                                            ),
                                          ),
                                        if (hw.brand.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: hw.brand == 'VVP'
                                                  ? const Color(0xFFE0F2FE)
                                                  : (hw.brand == 'RP'
                                                      ? const Color(0xFFF1F5F9)
                                                      : ToolkitColors.softBlueBg),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              hw.subCategory.isNotEmpty
                                                  ? '${hw.brand} · ${hw.subCategory}'
                                                  : hw.brand,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: ToolkitColors.slateDark,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      hw.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: ToolkitColors.slateDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '฿${_pickerBahtFmt.format(hw.effectivePrice)}/${hw.unit}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: ToolkitColors.royalBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Add, Edit, Swap, or Delete an Aluminum Cut Piece or Profile Group.
Future<AluminumCutEditResult?> showAluminumCutEditorSheet({
  required BuildContext context,
  required String defaultBrandKey,
  EvaluatedCutItem? existingCut,
  ProfileBarGroup? existingGroup,
  Map<String, CustomPriceOverride> customPriceOverrides = const {},
}) {
  return showModalBottomSheet<AluminumCutEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AluminumCutEditorBody(
      defaultBrandKey: defaultBrandKey,
      existingCut: existingCut,
      existingGroup: existingGroup,
      customPriceOverrides: customPriceOverrides,
    ),
  );
}

class _AluminumCutEditorBody extends StatefulWidget {
  final String defaultBrandKey;
  final EvaluatedCutItem? existingCut;
  final ProfileBarGroup? existingGroup;
  final Map<String, CustomPriceOverride> customPriceOverrides;

  const _AluminumCutEditorBody({
    required this.defaultBrandKey,
    this.existingCut,
    this.existingGroup,
    required this.customPriceOverrides,
  });

  @override
  State<_AluminumCutEditorBody> createState() => _AluminumCutEditorBodyState();
}

class _AluminumCutEditorBodyState extends State<_AluminumCutEditorBody> {
  late String _activeBrand;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _lenCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _barsCtrl;
  late bool _directBarMode;
  late String _angle;

  bool get _isGroupSwap => widget.existingGroup != null;
  bool get _isEditing =>
      widget.existingCut != null || widget.existingGroup != null;

  @override
  void initState() {
    super.initState();
    final grp = widget.existingGroup;
    final cut = widget.existingCut;
    _activeBrand = grp != null
        ? grp.brand
        : (cut != null
            ? MaterialMutationHelper.effectiveBrandOf(
                cut, widget.defaultBrandKey)
            : widget.defaultBrandKey);
    _codeCtrl = TextEditingController(text: grp?.code ?? cut?.code ?? '');
    _nameCtrl =
        TextEditingController(text: grp?.combinedNames ?? cut?.name ?? '');
    _sectionCtrl = TextEditingController(text: cut?.section ?? 'เพิ่มเติม');
    _stockCtrl = TextEditingController(
      text: (grp?.stockLengthMm ?? cut?.stockMm ?? 6400).toString(),
    );
    _directBarMode = grp != null
        ? (grp.exactCutSumMm <= 0 && grp.estimatedBars > 0)
        : (cut?.isSiteMeasured ?? false);
    _lenCtrl = TextEditingController(
      text: (cut?.lengthMm != null && cut!.lengthMm! > 0)
          ? cut.lengthMm!.toStringAsFixed(cut.lengthMm! % 1 == 0 ? 0 : 1)
          : '2000',
    );
    _qtyCtrl = TextEditingController(text: (cut?.totalQty ?? 2).toString());
    _barsCtrl = TextEditingController(
      text: grp != null
          ? grp.totalBars.clamp(1, 999).toString()
          : (cut?.isSiteMeasured == true
                  ? ((cut!.estimatedTotalMm ?? 6300) /
                          ((cut.stockMm - 100).clamp(100, 20000)))
                      .ceil()
                      .clamp(1, 999)
                  : 1)
              .toString(),
    );
    _angle = cut?.angle ?? '90° / 90°';
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sectionCtrl.dispose();
    _stockCtrl.dispose();
    _lenCtrl.dispose();
    _qtyCtrl.dispose();
    _barsCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty && name.isEmpty) return;
    final safeCode = code.isEmpty ? name : code;
    final safeName = name.isEmpty ? safeCode : name;
    final stockMm =
        (int.tryParse(_stockCtrl.text.trim()) ?? 6400).clamp(500, 12000);

    if (_isGroupSwap) {
      final directBars = _directBarMode
          ? (int.tryParse(_barsCtrl.text.trim()) ?? 1).clamp(1, 999)
          : null;
      Navigator.pop(
        context,
        AluminumCutEditResult.swapGroup(
          newBrand: _activeBrand,
          newCode: safeCode,
          newName: safeName,
          newStockMm: stockMm,
          overrideDirectBars: directBars,
        ),
      );
      return;
    }

    final brandOv = _activeBrand.toUpperCase() ==
            widget.defaultBrandKey.toUpperCase()
        ? null
        : _activeBrand;
    if (_directBarMode) {
      final bars = (int.tryParse(_barsCtrl.text.trim()) ?? 1).clamp(1, 999);
      Navigator.pop(
        context,
        AluminumCutEditResult.saveCut(
          MaterialMutationHelper.buildDirectBarCut(
            section: _sectionCtrl.text,
            code: safeCode,
            name: safeName,
            stockMm: stockMm,
            barCount: bars,
            brandOverride: brandOv,
          ),
        ),
      );
    } else {
      final len = double.tryParse(_lenCtrl.text.trim()) ?? 0.0;
      final qty = (int.tryParse(_qtyCtrl.text.trim()) ?? 1).clamp(1, 9999);
      if (len <= 0) return;
      Navigator.pop(
        context,
        AluminumCutEditResult.saveCut(
          MaterialMutationHelper.buildCutLengthItem(
            section: _sectionCtrl.text,
            code: safeCode,
            name: safeName,
            stockMm: stockMm,
            lengthMm: len,
            totalQty: qty,
            angle: _angle,
            brandOverride: brandOv,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grp = widget.existingGroup;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isGroupSwap
                        ? 'เปลี่ยน / ลบหน้าตัด (${grp!.code})'
                        : (widget.existingCut != null
                            ? 'แก้ไข / เปลี่ยนชิ้นส่วนอลูมิเนียม'
                            : 'เพิ่มเส้นอลูมิเนียมนอกสูตร'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.slateDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('btn_open_profile_catalog'),
                        onPressed: () async {
                          final picked = await showProfileCatalogPicker(
                            context: context,
                            currentBrandKey: _activeBrand,
                            customOverrides: widget.customPriceOverrides,
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _activeBrand = picked.brand;
                              _codeCtrl.text = picked.code;
                              _nameCtrl.text = picked.name;
                              _stockCtrl.text = picked.stockMm.toString();
                            });
                          }
                        },
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text(
                          'เลือก / เปลี่ยนจากแคตตาล็อกหน้าตัด',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ToolkitColors.softBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sell_outlined,
                              size: 15, color: ToolkitColors.royalBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'แบรนด์สำหรับจับคู่ราคา: $_activeBrand'
                              '${_activeBrand.toUpperCase() != widget.defaultBrandKey.toUpperCase() ? " (ข้ามแบรนด์)" : ""}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ToolkitColors.royalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            key: const ValueKey('edit_cut_code_field'),
                            controller: _codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'รหัสเส้น (Code) *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            key: const ValueKey('edit_cut_stock_field'),
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'เส้นโรงงาน (มม.)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [6000, 6400].map((mm) {
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text('$mm มม.',
                              style: const TextStyle(fontSize: 11.5)),
                          selected: _stockCtrl.text.trim() == mm.toString(),
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) =>
                              setState(() => _stockCtrl.text = mm.toString()),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('edit_cut_name_field'),
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อชิ้นส่วน *',
                        hintText: 'เช่น เฟรมข้าง, เสากลางเสริม, คิ้วปิดมุม',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isGroupSwap && grp!.exactCutSumMm > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ToolkitColors.cardBorder),
                        ),
                        child: Text(
                          'ระบบจะเปลี่ยนรหัส/หน้าตัดให้ทุกชิ้นส่วนในกลุ่มนี้ โดยคงระยะตัดเดิมไว้ครบ (ใช้รวม ${(grp.exactCutSumMm / 1000.0).toStringAsFixed(2)} ม.) และจัดเส้น + จับคู่ราคาใหม่ทันที',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ToolkitColors.slateBody,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (!_isGroupSwap) ...[
                        TextField(
                          controller: _sectionCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'หมวดชิ้นส่วน (เช่น วงกบ, กรอบบาน, เพิ่มเติม)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('ระบุระยะตัด (จัดเส้นอัตโนมัติ)',
                                  style: TextStyle(fontSize: 12)),
                              selected: !_directBarMode,
                              selectedColor: ToolkitColors.softBlueBg,
                              onSelected: (_) =>
                                  setState(() => _directBarMode = false),
                            ),
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('ระบุจำนวนเส้นตรงๆ / วัดหน้างาน',
                                  style: TextStyle(fontSize: 12)),
                              selected: _directBarMode,
                              selectedColor: ToolkitColors.softBlueBg,
                              onSelected: (_) =>
                                  setState(() => _directBarMode = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_directBarMode) ...[
                        TextField(
                          key: const ValueKey('edit_cut_bars_field'),
                          controller: _barsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'จำนวนเส้นที่ต้องสั่ง (เส้น) *',
                            suffixText: 'เส้น',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                key: const ValueKey('edit_cut_length_field'),
                                controller: _lenCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'ระยะตัด (มม.) *',
                                  suffixText: 'มม.',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                key: const ValueKey('edit_cut_qty_field'),
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'จำนวนชิ้น *',
                                  suffixText: 'ชิ้น',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: const ['90° / 90°', '45° / 45°', '90° / 45°']
                              .map((a) {
                            return ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(a,
                                  style: const TextStyle(fontSize: 11.5)),
                              selected: _angle == a,
                              selectedColor: ToolkitColors.softBlueBg,
                              onSelected: (_) => setState(() => _angle = a),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Pinned Action Bar (always visible & clickable without scrolling!)
            Row(
              children: [
                if (_isEditing) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('btn_delete_material'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      const AluminumCutEditResult.delete(),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('ลบรายการ'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('btn_save_material'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ToolkitColors.royalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isEditing ? 'บันทึกการเปลี่ยน' : 'เพิ่มเส้นอลูมิเนียม',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add, Edit, or Delete a Glass Item.
Future<GlassEditResult?> showGlassItemEditorSheet({
  required BuildContext context,
  EvaluatedGlassItem? existingGlass,
}) {
  return showModalBottomSheet<GlassEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GlassItemEditorBody(existingGlass: existingGlass),
  );
}

class _GlassItemEditorBody extends StatefulWidget {
  final EvaluatedGlassItem? existingGlass;

  const _GlassItemEditorBody({this.existingGlass});

  @override
  State<_GlassItemEditorBody> createState() => _GlassItemEditorBodyState();
}

class _GlassItemEditorBodyState extends State<_GlassItemEditorBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;
  late final TextEditingController _qtyCtrl;
  late bool _siteCut;

  bool get _isEditing => widget.existingGlass != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGlass;
    _nameCtrl = TextEditingController(text: g?.name ?? 'กระจกช่องแสงเพิ่มเติม');
    _siteCut = g?.siteCut ?? false;
    _wCtrl = TextEditingController(
      text: (g?.widthMm != null && g!.widthMm! > 0)
          ? g.widthMm!.toStringAsFixed(g.widthMm! % 1 == 0 ? 0 : 1)
          : '900',
    );
    _hCtrl = TextEditingController(
      text: (g?.heightMm != null && g!.heightMm! > 0)
          ? g.heightMm!.toStringAsFixed(g.heightMm! % 1 == 0 ? 0 : 1)
          : '1800',
    );
    _qtyCtrl = TextEditingController(text: (g?.totalPanels ?? 1).toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final nm = _nameCtrl.text.trim();
    if (nm.isEmpty) return;
    final panels = (int.tryParse(_qtyCtrl.text.trim()) ?? 1).clamp(1, 9999);
    double? w;
    double? h;
    if (!_siteCut) {
      w = double.tryParse(_wCtrl.text.trim());
      h = double.tryParse(_hCtrl.text.trim());
      if (w == null || w <= 0 || h == null || h <= 0) return;
    }
    Navigator.pop(
      context,
      GlassEditResult.save(
        EvaluatedGlassItem(
          name: nm,
          siteCut: _siteCut,
          widthMm: _siteCut ? null : w,
          heightMm: _siteCut ? null : h,
          totalPanels: panels,
          setIndex: widget.existingGlass?.setIndex ?? 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'แก้ไขรายการกระจก' : 'เพิ่มรายการกระจกนอกสูตร',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.slateDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('edit_glass_name_field'),
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อ / ตำแหน่งกระจก *',
                        hintText: 'เช่น กระจกบานเลื่อน, กระจกช่องแสงบน',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('ระบุขนาดสั่งตัด (มม.)',
                              style: TextStyle(fontSize: 12)),
                          selected: !_siteCut,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) => setState(() => _siteCut = false),
                        ),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('วัดตัดหน้างาน',
                              style: TextStyle(fontSize: 12)),
                          selected: _siteCut,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) => setState(() => _siteCut = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!_siteCut) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('edit_glass_w_field'),
                              controller: _wCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'กว้าง (มม.) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('edit_glass_h_field'),
                              controller: _hCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'สูง (มม.) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      key: const ValueKey('edit_glass_qty_field'),
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนแผ่น *',
                        suffixText: 'แผ่น',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isEditing) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('btn_delete_material'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, const GlassEditResult.delete()),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('ลบรายการ'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('btn_save_material'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ToolkitColors.royalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isEditing ? 'บันทึกกระจก' : 'เพิ่มกระจก',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add, Edit, Swap, or Delete a Hardware Item.
Future<HardwareEditResult?> showHardwareItemEditorSheet({
  required BuildContext context,
  AggregatedHardwareItem? existingHardware,
  Map<String, CustomMaterialRateOverride> materialOverrides = const {},
}) {
  return showModalBottomSheet<HardwareEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HardwareItemEditorBody(
      existingHardware: existingHardware,
      materialOverrides: materialOverrides,
    ),
  );
}

class _HardwareItemEditorBody extends StatefulWidget {
  final AggregatedHardwareItem? existingHardware;
  final Map<String, CustomMaterialRateOverride> materialOverrides;

  const _HardwareItemEditorBody({
    this.existingHardware,
    required this.materialOverrides,
  });

  @override
  State<_HardwareItemEditorBody> createState() =>
      _HardwareItemEditorBodyState();
}

class _HardwareItemEditorBodyState extends State<_HardwareItemEditorBody> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;

  bool get _isEditing => widget.existingHardware != null;

  @override
  void initState() {
    super.initState();
    final hw = widget.existingHardware;
    _codeCtrl = TextEditingController(text: hw?.code ?? '');
    _nameCtrl = TextEditingController(text: hw?.name ?? '');
    _qtyCtrl = TextEditingController(
      text: hw?.numericQty != null
          ? hw!.numericQty.toString()
          : (_isEditing ? '' : '1'),
    );
    _unitCtrl = TextEditingController(
      text: hw?.unitOrNote.trim().isNotEmpty == true
          ? hw!.unitOrNote.trim()
          : 'ชิ้น',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final nm = _nameCtrl.text.trim();
    if (nm.isEmpty) return;
    final rawQty = _qtyCtrl.text.trim();
    final parsedQty = rawQty.isEmpty ? null : int.tryParse(rawQty);
    final unit = _unitCtrl.text.trim().isEmpty
        ? (parsedQty == null ? 'ตามหน้างาน' : 'ชิ้น')
        : _unitCtrl.text.trim();
    Navigator.pop(
      context,
      HardwareEditResult.save(
        AggregatedHardwareItem(
          code: _codeCtrl.text.trim(),
          name: nm,
          numericQty: parsedQty != null && parsedQty > 0 ? parsedQty : null,
          unitOrNote: unit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing
                        ? 'แก้ไข / เปลี่ยนอุปกรณ์ประกอบ'
                        : 'เพิ่มอุปกรณ์ประกอบนอกสูตร',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.slateDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('btn_open_hw_catalog'),
                        onPressed: () async {
                          final picked = await showHardwareCatalogPicker(
                            context: context,
                            materialOverrides: widget.materialOverrides,
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _codeCtrl.text = picked.code;
                              _nameCtrl.text = picked.name;
                              _unitCtrl.text = picked.unit.trim().isEmpty
                                  ? 'ชิ้น'
                                  : picked.unit;
                            });
                          }
                        },
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text(
                          'เลือกจากคลังอุปกรณ์ ALUMET · VVP · RP (258 รายการ)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('edit_hw_code_field'),
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'รหัสอุปกรณ์ (ถ้ามี)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('edit_hw_name_field'),
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่ออุปกรณ์ *',
                        hintText:
                            'เช่น มือจับล็อก, ล้อคู่, สักหลาด, ยางอัดกระจก',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            key: const ValueKey('edit_hw_qty_field'),
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'จำนวน (เว้นว่าง = ตามหน้างาน)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: const ValueKey('edit_hw_unit_field'),
                            controller: _unitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'หน่วย',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      children:
                          const ['ชิ้น', 'ชุด', 'คู่', 'อัน', 'ม.', 'เส้น']
                              .map((u) {
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(u,
                              style: const TextStyle(fontSize: 11.5)),
                          selected: _unitCtrl.text.trim() == u,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) =>
                              setState(() => _unitCtrl.text = u),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isEditing) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('btn_delete_material'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      const HardwareEditResult.delete(),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('ลบรายการ'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('btn_save_material'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ToolkitColors.royalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isEditing ? 'บันทึกอุปกรณ์' : 'เพิ่มอุปกรณ์',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Searchable Autocomplete Helpers & Inline Dropdown Widgets (v0.1.15)
// Supports partial & multi-word search (no need to type full names/codes),
// prioritizes the active brand, shows CAD/hardware photos, and still allows
// free custom text entry.
// =============================================================================

String _normalizeCompact(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\-_/]+'), '');

/// Partial / multi-token fuzzy search over deduplicated aluminum profiles.
/// Empty or placeholder queries (`NEW-...`, `หน้าตัดเพิ่มเติม`, `ชิ้นส่วนใหม่`)
/// return top profiles for [preferredBrand] so tapping the dropdown immediately
/// works as a browseable dropdown list!
List<CatalogProfileOption> searchCatalogProfiles({
  required List<CatalogProfileOption> options,
  required String query,
  String? preferredBrand,
  int limit = 12,
}) {
  final pref = (preferredBrand ?? '').trim().toUpperCase();
  final raw = query.trim();
  final isPlaceholder = raw.isEmpty ||
      raw.toUpperCase().startsWith('NEW-') ||
      raw == 'หน้าตัดเพิ่มเติม' ||
      raw == 'ชิ้นส่วนใหม่';

  if (isPlaceholder) {
    final sorted = List<CatalogProfileOption>.from(options)
      ..sort((a, b) {
        final pa = a.brand.toUpperCase() == pref ? 0 : 1;
        final pb = b.brand.toUpperCase() == pref ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        return a.code.compareTo(b.code);
      });
    return sorted.take(limit).toList();
  }

  final tokens = raw
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final compactQuery = _normalizeCompact(raw);

  final scored = <({CatalogProfileOption opt, int score})>[];
  for (final opt in options) {
    final codeLower = opt.code.toLowerCase();
    final nameLower = opt.name.toLowerCase();
    final brandLower = opt.brand.toLowerCase();
    final hay = '$codeLower $nameLower $brandLower';
    final compactHay = _normalizeCompact('$codeLower $nameLower');

    final allTokensMatch = tokens.every(
      (t) => hay.contains(t) || compactHay.contains(_normalizeCompact(t)),
    );
    if (!allTokensMatch) continue;

    int score = 10;
    if (pref.isNotEmpty && opt.brand.toUpperCase() == pref) score += 60;
    if (codeLower == raw.toLowerCase() ||
        _normalizeCompact(codeLower) == compactQuery) {
      score += 80;
    } else if (codeLower.startsWith(raw.toLowerCase()) ||
        _normalizeCompact(codeLower).startsWith(compactQuery)) {
      score += 45;
    } else if (codeLower.contains(raw.toLowerCase())) {
      score += 25;
    }
    if (nameLower.startsWith(raw.toLowerCase())) score += 20;
    scored.add((opt: opt, score: score));
  }

  scored.sort((a, b) {
    final sc = b.score.compareTo(a.score);
    if (sc != 0) return sc;
    return a.opt.code.compareTo(b.opt.code);
  });

  return scored.take(limit).map((e) => e.opt).toList();
}

/// Partial / multi-token fuzzy search over visible ALUMET / VVP / RP hardware.
List<MaterialRateItem> searchCatalogHardware({
  required List<MaterialRateItem> items,
  required String query,
  String? preferredBrand,
  int limit = 12,
}) {
  final pref = (preferredBrand ?? '').trim().toUpperCase();
  final raw = query.trim();
  final isPlaceholder = raw.isEmpty ||
      raw == 'อุปกรณ์เพิ่มเติม' ||
      raw == 'อุปกรณ์ประกอบ';

  if (isPlaceholder) {
    final sorted = List<MaterialRateItem>.from(items)
      ..sort((a, b) {
        final pa = a.brand.toUpperCase() == pref ? 0 : 1;
        final pb = b.brand.toUpperCase() == pref ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        return a.code.compareTo(b.code);
      });
    return sorted.take(limit).toList();
  }

  final tokens = raw
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final compactQuery = _normalizeCompact(raw);

  final scored = <({MaterialRateItem item, int score})>[];
  for (final h in items) {
    final codeLower = h.code.toLowerCase();
    final nameLower = h.name.toLowerCase();
    final brandLower = h.brand.toLowerCase();
    final catLower = h.subCategory.toLowerCase();
    final hay = '$codeLower $nameLower $brandLower $catLower';
    final compactHay = _normalizeCompact('$codeLower $nameLower');

    final allTokensMatch = tokens.every(
      (t) => hay.contains(t) || compactHay.contains(_normalizeCompact(t)),
    );
    if (!allTokensMatch) continue;

    int score = 10;
    if (pref.isNotEmpty && h.brand.toUpperCase() == pref) score += 60;
    if (codeLower == raw.toLowerCase() ||
        _normalizeCompact(codeLower) == compactQuery) {
      score += 80;
    } else if (codeLower.startsWith(raw.toLowerCase()) ||
        _normalizeCompact(codeLower).startsWith(compactQuery)) {
      score += 45;
    } else if (codeLower.contains(raw.toLowerCase())) {
      score += 25;
    }
    if (nameLower.startsWith(raw.toLowerCase())) score += 20;
    scored.add((item: h, score: score));
  }

  scored.sort((a, b) {
    final sc = b.score.compareTo(a.score);
    if (sc != 0) return sc;
    return a.item.code.compareTo(b.item.code);
  });

  return scored.take(limit).map((e) => e.item).toList();
}

/// Inline searchable autocomplete dropdown for aluminum profile `รหัสหน้าตัด` + `ชื่อชิ้นส่วน`.
/// Stays anchored smoothly inside scrollable ListViews on phones and tablets.
class ProfileAutocompleteFields extends StatefulWidget {
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final List<CatalogProfileOption> profileOptions;
  final String preferredBrand;
  final Map<String, CustomPriceOverride> customPriceOverrides;
  final ValueChanged<CatalogProfileOption> onProfilePicked;
  final VoidCallback? onTextChanged;
  final Key? codeFieldKey;
  final Key? nameFieldKey;
  final Key? toggleKey;
  final String codeLabel;
  final String nameLabel;

  const ProfileAutocompleteFields({
    super.key,
    required this.codeCtrl,
    required this.nameCtrl,
    required this.profileOptions,
    required this.preferredBrand,
    this.customPriceOverrides = const {},
    required this.onProfilePicked,
    this.onTextChanged,
    this.codeFieldKey,
    this.nameFieldKey,
    this.toggleKey,
    this.codeLabel = 'รหัสหน้าตัด',
    this.nameLabel = 'ชื่อชิ้นส่วน',
  });

  @override
  State<ProfileAutocompleteFields> createState() =>
      _ProfileAutocompleteFieldsState();
}

class _ProfileAutocompleteFieldsState extends State<ProfileAutocompleteFields> {
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  bool _dropdownOpen = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(_onFocusChanged);
    _nameFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_codeFocus.hasFocus) {
      setState(() {
        _dropdownOpen = true;
        _activeQuery = widget.codeCtrl.text;
      });
    } else if (_nameFocus.hasFocus) {
      setState(() {
        _dropdownOpen = true;
        _activeQuery = widget.nameCtrl.text;
      });
    }
  }

  @override
  void dispose() {
    _codeFocus.removeListener(_onFocusChanged);
    _nameFocus.removeListener(_onFocusChanged);
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _selectOption(CatalogProfileOption opt) {
    widget.codeCtrl.text = opt.code;
    widget.nameCtrl.text = opt.name;
    widget.onProfilePicked(opt);
    _codeFocus.unfocus();
    _nameFocus.unfocus();
    setState(() {
      _dropdownOpen = false;
      _activeQuery = opt.code;
    });
  }

  Future<void> _openFullCatalogPicker() async {
    _codeFocus.unfocus();
    _nameFocus.unfocus();
    setState(() => _dropdownOpen = false);
    final picked = await showProfileCatalogPicker(
      context: context,
      currentBrandKey: widget.preferredBrand,
      customOverrides: widget.customPriceOverrides,
    );
    if (picked != null && mounted) {
      _selectOption(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _dropdownOpen
        ? searchCatalogProfiles(
            options: widget.profileOptions,
            query: _activeQuery,
            preferredBrand: widget.preferredBrand,
            limit: 10,
          )
        : const <CatalogProfileOption>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                key: widget.codeFieldKey,
                controller: widget.codeCtrl,
                focusNode: _codeFocus,
                decoration: InputDecoration(
                  labelText: widget.codeLabel,
                  hintText: 'พิมพ์รหัส เช่น X110',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: IconButton(
                    key: widget.toggleKey,
                    tooltip: _dropdownOpen ? 'ปิดรายการเส้น' : 'เลือกจากรายการเส้น',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: () {
                      setState(() {
                        _dropdownOpen = !_dropdownOpen;
                        if (_dropdownOpen) {
                          _activeQuery = '';
                        }
                      });
                    },
                    icon: Icon(
                      _dropdownOpen
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: ToolkitColors.royalBlue,
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _dropdownOpen = true;
                    _activeQuery = v;
                  });
                  widget.onTextChanged?.call();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                key: widget.nameFieldKey,
                controller: widget.nameCtrl,
                focusNode: _nameFocus,
                decoration: InputDecoration(
                  labelText: widget.nameLabel,
                  hintText: 'พิมพ์ค้นหาชื่อ เช่น เฟรมบน, เสาเกี่ยว...',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 32),
                  suffixIcon: IconButton(
                    tooltip: 'เปิดคลังหน้าตัดทั้งหมด',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: _openFullCatalogPicker,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: ToolkitColors.royalBlue,
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _dropdownOpen = true;
                    _activeQuery = v;
                  });
                  widget.onTextChanged?.call();
                },
              ),
            ),
          ],
        ),
        if (_dropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 235),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ToolkitColors.royalBlue.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    color: ToolkitColors.softBlueBg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt_rounded,
                          size: 14, color: ToolkitColors.royalBlue),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          matches.isEmpty
                              ? 'ไม่พบในคลัง — ใช้รหัส/ชื่อที่พิมพ์เองได้เลย'
                              : 'เลือกหน้าตัด (${matches.length} รายการแนะนำ · พิมพ์บางคำเพื่อกรอง)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.royalBlue,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _codeFocus.unfocus();
                          _nameFocus.unfocus();
                          setState(() => _dropdownOpen = false);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: ToolkitColors.slateMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (matches.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final opt = matches[idx];
                        final img = AluproImageRegistry.instance
                            .resolveProfileAsset(
                          code: opt.code,
                          name: opt.name,
                          brandKey: opt.brand,
                        );
                        final isSameBrand = opt.brand.toUpperCase() ==
                            widget.preferredBrand.trim().toUpperCase();
                        return InkWell(
                          onTap: () => _selectOption(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                if (img != null)
                                  AluproThumbnail(
                                    assetPath: img,
                                    width: 38,
                                    height: 30,
                                    showZoomBadge: false,
                                  )
                                else
                                  Container(
                                    width: 38,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: ToolkitColors.softBlueBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.view_stream_rounded,
                                      size: 16,
                                      color: ToolkitColors.royalBlue,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            opt.code,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: ToolkitColors.royalBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSameBrand
                                                  ? const Color(0xFFDCFCE7)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              opt.brand,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSameBrand
                                                    ? const Color(0xFF15803D)
                                                    : ToolkitColors.slateMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        opt.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ToolkitColors.slateDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '฿${_pickerBahtFmt.format(opt.minPrice)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: ToolkitColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                InkWell(
                  onTap: _openFullCatalogPicker,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 14, color: ToolkitColors.royalBlue),
                        SizedBox(width: 5),
                        Text(
                          'เปิดคลังหน้าตัดเต็มหน้าจอ (กรองตามแบรนด์ทั้งหมด)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.royalBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Inline searchable autocomplete dropdown for ALUMET / VVP / RP hardware items.
class HardwareAutocompleteFields extends StatefulWidget {
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final List<MaterialRateItem> hardwareItems;
  final String preferredBrand;
  final Map<String, CustomMaterialRateOverride> materialOverrides;
  final ValueChanged<MaterialRateItem> onHardwarePicked;
  final VoidCallback? onTextChanged;
  final Key? codeFieldKey;
  final Key? nameFieldKey;
  final Key? toggleKey;

  const HardwareAutocompleteFields({
    super.key,
    required this.codeCtrl,
    required this.nameCtrl,
    required this.hardwareItems,
    required this.preferredBrand,
    this.materialOverrides = const {},
    required this.onHardwarePicked,
    this.onTextChanged,
    this.codeFieldKey,
    this.nameFieldKey,
    this.toggleKey,
  });

  @override
  State<HardwareAutocompleteFields> createState() =>
      _HardwareAutocompleteFieldsState();
}

class _HardwareAutocompleteFieldsState
    extends State<HardwareAutocompleteFields> {
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  bool _dropdownOpen = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(_onFocusChanged);
    _nameFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_codeFocus.hasFocus) {
      setState(() {
        _dropdownOpen = true;
        _activeQuery = widget.codeCtrl.text;
      });
    } else if (_nameFocus.hasFocus) {
      setState(() {
        _dropdownOpen = true;
        _activeQuery = widget.nameCtrl.text;
      });
    }
  }

  @override
  void dispose() {
    _codeFocus.removeListener(_onFocusChanged);
    _nameFocus.removeListener(_onFocusChanged);
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _selectItem(MaterialRateItem hw) {
    widget.codeCtrl.text = hw.code;
    widget.nameCtrl.text = hw.name;
    widget.onHardwarePicked(hw);
    _codeFocus.unfocus();
    _nameFocus.unfocus();
    setState(() {
      _dropdownOpen = false;
      _activeQuery = hw.code;
    });
  }

  Future<void> _openFullHardwarePicker() async {
    _codeFocus.unfocus();
    _nameFocus.unfocus();
    setState(() => _dropdownOpen = false);
    final picked = await showHardwareCatalogPicker(
      context: context,
      materialOverrides: widget.materialOverrides,
    );
    if (picked != null && mounted) {
      _selectItem(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _dropdownOpen
        ? searchCatalogHardware(
            items: widget.hardwareItems,
            query: _activeQuery,
            preferredBrand: widget.preferredBrand,
            limit: 10,
          )
        : const <MaterialRateItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                key: widget.codeFieldKey,
                controller: widget.codeCtrl,
                focusNode: _codeFocus,
                decoration: InputDecoration(
                  labelText: 'รหัส',
                  hintText: 'เช่น AKL, FC 34',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: IconButton(
                    key: widget.toggleKey,
                    tooltip:
                        _dropdownOpen ? 'ปิดรายการอุปกรณ์' : 'เลือกจากรายการอุปกรณ์',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: () {
                      setState(() {
                        _dropdownOpen = !_dropdownOpen;
                        if (_dropdownOpen) _activeQuery = '';
                      });
                    },
                    icon: Icon(
                      _dropdownOpen
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: ToolkitColors.royalBlue,
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _dropdownOpen = true;
                    _activeQuery = v;
                  });
                  widget.onTextChanged?.call();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                key: widget.nameFieldKey,
                controller: widget.nameCtrl,
                focusNode: _nameFocus,
                decoration: InputDecoration(
                  labelText: 'ชื่ออุปกรณ์',
                  hintText: 'พิมพ์บางคำ เช่น ล้อ, มือจับ, บานพับ...',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 32),
                  suffixIcon: IconButton(
                    tooltip: 'เปิดคลังอุปกรณ์ทั้งหมด',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: _openFullHardwarePicker,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: ToolkitColors.royalBlue,
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _dropdownOpen = true;
                    _activeQuery = v;
                  });
                  widget.onTextChanged?.call();
                },
              ),
            ),
          ],
        ),
        if (_dropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 235),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ToolkitColors.royalBlue.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    color: ToolkitColors.softBlueBg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.handyman_outlined,
                          size: 14, color: ToolkitColors.royalBlue),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          matches.isEmpty
                              ? 'ไม่พบในคลัง — ใช้ชื่อที่พิมพ์เองได้เลย'
                              : 'เลือกอุปกรณ์ (${matches.length} รายการแนะนำ · พิมพ์บางคำเพื่อกรอง)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.royalBlue,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _codeFocus.unfocus();
                          _nameFocus.unfocus();
                          setState(() => _dropdownOpen = false);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: ToolkitColors.slateMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (matches.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final hw = matches[idx];
                        final img = hw.imageAssetPath ??
                            AluproImageRegistry.instance.resolveHardwareAsset(
                              code: hw.code,
                              name: hw.name,
                            );
                        return InkWell(
                          onTap: () => _selectItem(hw),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                if (img != null)
                                  AluproThumbnail(
                                    assetPath: img,
                                    width: 38,
                                    height: 32,
                                    showZoomBadge: false,
                                  )
                                else
                                  Container(
                                    width: 38,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: ToolkitColors.softBlueBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.hardware_rounded,
                                      size: 16,
                                      color: ToolkitColors.royalBlue,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            hw.code,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: ToolkitColors.royalBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (hw.brand.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                hw.subCategory.isNotEmpty
                                                    ? '${hw.brand} · ${hw.subCategory}'
                                                    : hw.brand,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      ToolkitColors.slateMuted,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        hw.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ToolkitColors.slateDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '฿${_pickerBahtFmt.format(hw.effectivePrice)}/${hw.unit}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ToolkitColors.slateDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                InkWell(
                  onTap: _openFullHardwarePicker,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 14, color: ToolkitColors.royalBlue),
                        SizedBox(width: 5),
                        Text(
                          'เปิดคลังอุปกรณ์ ALUMET · VVP · RP เต็มหน้าจอ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.royalBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
