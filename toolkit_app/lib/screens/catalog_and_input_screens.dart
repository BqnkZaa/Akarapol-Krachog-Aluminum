import 'package:flutter/material.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../data/catalog_definitions.dart';
import '../data/seed_repository.dart';
import '../engine/parametric_system_resolver.dart';
import '../engine/quotation_spec_formatter.dart';
import '../models/app_models.dart';
import 'alupro_thumbnail_widgets.dart';
import 'custom_system_studio_screens.dart';
import 'result_and_pricing_screens.dart';
import 'theme_tokens.dart';

class PickedPatternSelection {
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final PatternCardDef pattern;

  const PickedPatternSelection({
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.pattern,
  });
}

class CategorySelectScreen extends StatefulWidget {
  final int? targetProjectId;
  final bool pickMode;

  const CategorySelectScreen({
    super.key,
    this.targetProjectId,
    this.pickMode = false,
  });

  @override
  State<CategorySelectScreen> createState() => _CategorySelectScreenState();
}

class _CategorySelectScreenState extends State<CategorySelectScreen> {
  Future<void> _openStudio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomSystemListScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cats = CatalogDefinitions.mergedCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickMode
              ? 'เลือกแบบบาน / โปรไฟล์ใหม่'
              : 'เลือกหมวดระบบอลูมิเนียม',
        ),
        actions: [
          if (!widget.pickMode)
            IconButton(
              tooltip: 'เพิ่ม / จัดการชุดโปรไฟล์ใหม่',
              onPressed: _openStudio,
              icon: const Icon(Icons.add_box_outlined),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availW = constraints.maxWidth;
          final plateW = availW < 420
              ? 98.0
              : (availW < 600 ? 110.0 : 124.0);
          final plateH = availW < 420
              ? 61.0
              : (availW < 600 ? 68.0 : 77.0);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'เลือกชุดระบบหลัก',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: ToolkitColors.slateDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'เลือกประเภทชุดที่ตรงกับงานที่กำลังทำ',
                style: TextStyle(
                  fontSize: 13.5,
                  color: ToolkitColors.slateMuted,
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < cats.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Builder(
                  builder: (_) {
                    final cat = cats[i];
                    final catIconAsset = AluproImageRegistry.instance
                        .resolveCategoryAsset(cat.id);
                    return _NavCard(
                      title: '${i + 1}. ${cat.title}',
                      subtitle: cat.subtitle,
                      leadingWidget: BrandLogoPlate(
                        assetPath: catIconAsset,
                        width: plateW,
                        height: plateH,
                        enabled: cat.enabled,
                      ),
                      enabled: cat.enabled,
                      disabledBadge: cat.disabledBadge,
                      onTap: () async {
                        if (cat.directSystems.isNotEmpty) {
                          final picked =
                              await Navigator.push<PickedPatternSelection>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubSystemSelectScreen(
                                brandTitle: cat.title,
                                priceBrandKey: 'MARKET',
                                systems: cat.directSystems,
                                targetProjectId: widget.targetProjectId,
                                pickMode: widget.pickMode,
                              ),
                            ),
                          );
                          if (widget.pickMode &&
                              picked != null &&
                              context.mounted) {
                            Navigator.pop(context, picked);
                            return;
                          }
                        } else {
                          final picked =
                              await Navigator.push<PickedPatternSelection>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BrandSelectScreen(
                                category: cat,
                                targetProjectId: widget.targetProjectId,
                                pickMode: widget.pickMode,
                              ),
                            ),
                          );
                          if (widget.pickMode &&
                              picked != null &&
                              context.mounted) {
                            Navigator.pop(context, picked);
                            return;
                          }
                        }
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: ToolkitColors.royalBlue),
                  foregroundColor: ToolkitColors.royalBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openStudio,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                label: const Text(
                  'เพิ่ม / จัดการชุดโปรไฟล์ใหม่',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BrandSelectScreen extends StatefulWidget {
  final CategoryDef category;
  final int? targetProjectId;
  final bool pickMode;

  const BrandSelectScreen({
    super.key,
    required this.category,
    this.targetProjectId,
    this.pickMode = false,
  });

  @override
  State<BrandSelectScreen> createState() => _BrandSelectScreenState();
}

class _BrandSelectScreenState extends State<BrandSelectScreen> {
  CategoryDef get _activeCategory {
    final merged = CatalogDefinitions.mergedCategories();
    return merged.firstWhere(
      (c) => c.id == widget.category.id,
      orElse: () => widget.category,
    );
  }

  Future<void> _openStudioForCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomSystemListScreen(
          initialCategoryId: widget.category.id,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final category = _activeCategory;
    return Scaffold(
      appBar: AppBar(
        title: Text(category.title),
        actions: [
          IconButton(
            tooltip: 'เพิ่มชุดโปรไฟล์ในหมวดนี้',
            onPressed: _openStudioForCategory,
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'เลือกแบรนด์และระบบงาน',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: ToolkitColors.slateDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'เลือกแบรนด์หรือตระกูลผลิตภัณฑ์ที่ต้องการใช้งาน',
            style: TextStyle(
              fontSize: 13.5,
              color: ToolkitColors.slateMuted,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < category.brands.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _BrandCard(
              brand: category.brands[i],
              logoAsset: AluproImageRegistry.instance
                  .resolveBrandAsset(category.brands[i].id),
              onTap: () async {
                final brand = category.brands[i];
                if (brand.directPatterns.isNotEmpty) {
                  final picked =
                      await Navigator.push<PickedPatternSelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatternSelectScreen(
                        brandTitle: brand.title,
                        priceBrandKey: brand.priceBrandKey,
                        systemTitle: brand.subtitle,
                        patterns: brand.directPatterns,
                        targetProjectId: widget.targetProjectId,
                        pickMode: widget.pickMode,
                      ),
                    ),
                  );
                  if (widget.pickMode && picked != null && context.mounted) {
                    Navigator.pop(context, picked);
                  }
                } else {
                  final picked =
                      await Navigator.push<PickedPatternSelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubSystemSelectScreen(
                        brandTitle: brand.title,
                        priceBrandKey: brand.priceBrandKey,
                        systems: brand.systems,
                        targetProjectId: widget.targetProjectId,
                        pickMode: widget.pickMode,
                      ),
                    ),
                  );
                  if (widget.pickMode && picked != null && context.mounted) {
                    Navigator.pop(context, picked);
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final BrandDef brand;
  final String? logoAsset;
  final VoidCallback onTap;

  const _BrandCard({
    required this.brand,
    required this.logoAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final isCompact = cardW < 520;
        final isNarrowPhone = cardW < 390;
        final hasDisabledBadge = !brand.enabled && brand.disabledBadge != null;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: brand.enabled ? onTap : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrowPhone ? 14 : 18,
              vertical: isNarrowPhone ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: brand.enabled ? Colors.white : ToolkitColors.disabledBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: Row(
              children: [
                BrandLogoPlate(
                  assetPath: logoAsset,
                  width: isNarrowPhone ? 86 : 104,
                  height: isNarrowPhone ? 46 : 54,
                  enabled: brand.enabled,
                ),
                SizedBox(width: isNarrowPhone ? 13 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.title,
                        style: TextStyle(
                          fontSize: isNarrowPhone ? 15.5 : 16,
                          fontWeight: FontWeight.w800,
                          color: brand.enabled
                              ? ToolkitColors.slateDark
                              : ToolkitColors.slateMuted,
                        ),
                      ),
                      if (brand.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          brand.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                      if (isCompact && hasDisabledBadge) ...[
                        const SizedBox(height: 7),
                        buildStatusBadge(brand.disabledBadge!),
                      ],
                    ],
                  ),
                ),
                if (!isCompact && hasDisabledBadge) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: buildStatusBadge(brand.disabledBadge!),
                  ),
                ] else if (brand.enabled) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ToolkitColors.slateMuted,
                    size: 23,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class SubSystemSelectScreen extends StatelessWidget {
  final String brandTitle;
  final String priceBrandKey;
  final List<SubSystemDef> systems;
  final int? targetProjectId;
  final bool pickMode;

  const SubSystemSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systems,
    this.targetProjectId,
    this.pickMode = false,
  });

  ({IconData icon, Color fg, Color bg}) _systemBadgeStyle(SubSystemDef sys) {
    final t = sys.title;
    if (t.contains('เลื่อน') || t.contains('200')) {
      return (
        icon: Icons.swap_horiz_rounded,
        fg: const Color(0xFF1E56C5),
        bg: const Color(0xFFEAF1FE),
      );
    }
    if (t.contains('ประตู') || t.contains('สวิง') || t.contains('250')) {
      return (
        icon: Icons.door_front_door_outlined,
        fg: const Color(0xFFD99014),
        bg: const Color(0xFFFDF3DF),
      );
    }
    if (t.contains('เฟี้ยม')) {
      return (
        icon: Icons.sensor_door_outlined,
        fg: const Color(0xFFC0425A),
        bg: const Color(0xFFFAEDEF),
      );
    }
    if (t.contains('ตาย') ||
        t.contains('ฟิก') ||
        t.contains('FIX') ||
        t.contains('ผนังกระจก')) {
      return (
        icon: Icons.grid_on_rounded,
        fg: const Color(0xFF4F46E5),
        bg: const Color(0xFFEEF2FF),
      );
    }
    return (
      icon: Icons.window_rounded,
      fg: const Color(0xFF1F7A5A),
      bg: const Color(0xFFE7F5EE),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(brandTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: systems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final sys = systems[i];
          final badge = _systemBadgeStyle(sys);
          return _NavCard(
            title: sys.title,
            subtitle: sys.subtitle,
            leadingWidget: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sys.enabled ? badge.bg : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                badge.icon,
                color: sys.enabled ? badge.fg : ToolkitColors.slateMuted,
                size: 23,
              ),
            ),
            enabled: sys.enabled,
            disabledBadge: sys.disabledBadge,
            onTap: () async {
              if (sys.emptyMessage != null) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _EmptySystemScreen(
                      title: sys.title,
                      message: sys.emptyMessage!,
                    ),
                  ),
                );
              } else if (sys.subTabs.isNotEmpty) {
                final picked =
                    await Navigator.push<PickedPatternSelection>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubTabbedPatternSelectScreen(
                      brandTitle: brandTitle,
                      priceBrandKey: priceBrandKey,
                      systemTitle: sys.title,
                      subTabs: sys.subTabs,
                      targetProjectId: targetProjectId,
                      pickMode: pickMode,
                    ),
                  ),
                );
                if (pickMode && picked != null && context.mounted) {
                  Navigator.pop(context, picked);
                }
              } else {
                final picked =
                    await Navigator.push<PickedPatternSelection>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatternSelectScreen(
                      brandTitle: brandTitle,
                      priceBrandKey: priceBrandKey,
                      systemTitle: sys.title,
                      patterns: sys.patterns,
                      targetProjectId: targetProjectId,
                      pickMode: pickMode,
                    ),
                  ),
                );
                if (pickMode && picked != null && context.mounted) {
                  Navigator.pop(context, picked);
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _EmptySystemScreen extends StatelessWidget {
  final String title;
  final String message;

  const _EmptySystemScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ToolkitColors.slateMuted,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-Tabbed Pattern Selection (SMART PLUS Euro 45°/90° & ALUFRAME 3 Tabs)
// =============================================================================
class SubTabbedPatternSelectScreen extends StatefulWidget {
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final List<SubSystemDef> subTabs;
  final int? targetProjectId;
  final bool pickMode;

  const SubTabbedPatternSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.subTabs,
    this.targetProjectId,
    this.pickMode = false,
  });

  @override
  State<SubTabbedPatternSelectScreen> createState() =>
      _SubTabbedPatternSelectScreenState();
}

class _SubTabbedPatternSelectScreenState
    extends State<SubTabbedPatternSelectScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  PatternCardDef? _selected;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.subTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selected = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.brandTitle} · ${widget.systemTitle}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: widget.subTabs.length > 2,
          tabAlignment: widget.subTabs.length > 2
              ? TabAlignment.start
              : TabAlignment.fill,
          labelColor: ToolkitColors.royalBlue,
          unselectedLabelColor: ToolkitColors.slateMuted,
          indicatorColor: ToolkitColors.royalBlue,
          tabs: widget.subTabs.map((t) => Tab(text: t.title)).toList(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.subTabs.map((tab) {
                return _PatternListBody(
                  patterns: tab.patterns,
                  selectedId: _selected?.id,
                  onSelect: (p) => setState(() => _selected = p),
                );
              }).toList(),
            ),
          ),
          _NextStickyBar(
            enabled: _selected != null,
            label: widget.pickMode ? 'ใช้แบบบานนี้' : 'ถัดไป (กรอกขนาดงาน)',
            onPressed: _selected == null
                ? null
                : () {
                    final curTab = widget.subTabs[_tabController.index];
                    final resolvedSys =
                        '${widget.systemTitle} (${curTab.title})';
                    if (widget.pickMode) {
                      Navigator.pop(
                        context,
                        PickedPatternSelection(
                          brandTitle: widget.brandTitle,
                          priceBrandKey: widget.priceBrandKey,
                          systemTitle: resolvedSys,
                          pattern: _selected!,
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SizeAndSpecInputScreen(
                          brandTitle: widget.brandTitle,
                          priceBrandKey: widget.priceBrandKey,
                          systemTitle: resolvedSys,
                          pattern: _selected!,
                          targetProjectId: widget.targetProjectId,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Standard Pattern Selection Screen
// =============================================================================
class PatternSelectScreen extends StatefulWidget {
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final List<PatternCardDef> patterns;
  final int? targetProjectId;
  final bool pickMode;

  const PatternSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.patterns,
    this.targetProjectId,
    this.pickMode = false,
  });

  @override
  State<PatternSelectScreen> createState() => _PatternSelectScreenState();
}

class _PatternSelectScreenState extends State<PatternSelectScreen> {
  PatternCardDef? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.systemTitle)),
      body: Column(
        children: [
          Expanded(
            child: _PatternListBody(
              patterns: widget.patterns,
              selectedId: _selected?.id,
              onSelect: (p) => setState(() => _selected = p),
            ),
          ),
          _NextStickyBar(
            enabled: _selected != null,
            label: widget.pickMode ? 'ใช้แบบบานนี้' : 'ถัดไป (กรอกขนาดงาน)',
            onPressed: _selected == null
                ? null
                : () {
                    if (widget.pickMode) {
                      Navigator.pop(
                        context,
                        PickedPatternSelection(
                          brandTitle: widget.brandTitle,
                          priceBrandKey: widget.priceBrandKey,
                          systemTitle: widget.systemTitle,
                          pattern: _selected!,
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SizeAndSpecInputScreen(
                          brandTitle: widget.brandTitle,
                          priceBrandKey: widget.priceBrandKey,
                          systemTitle: widget.systemTitle,
                          pattern: _selected!,
                          targetProjectId: widget.targetProjectId,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _PatternListBody extends StatelessWidget {
  final List<PatternCardDef> patterns;
  final String? selectedId;
  final ValueChanged<PatternCardDef> onSelect;

  const _PatternListBody({
    required this.patterns,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final listW = constraints.maxWidth;
        final isCompact = listW < 560;
        final thumbW = listW < 400 ? 60.0 : 68.0;
        final thumbH = listW < 400 ? 44.0 : 48.0;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patterns.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final p = patterns[i];
            final isSel = p.id == selectedId;
            final imgAsset =
                AluproImageRegistry.instance.resolvePatternAsset(p.id);
            final hasDisabledBadge = !p.enabled && p.disabledBadge != null;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: p.enabled ? () => onSelect(p) : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.enabled
                      ? (isSel ? ToolkitColors.softBlueBg : Colors.white)
                      : ToolkitColors.disabledBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel
                        ? ToolkitColors.royalBlue
                        : ToolkitColors.cardBorder,
                    width: isSel ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      p.enabled
                          ? (isSel
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded)
                          : Icons.lock_clock_outlined,
                      color: p.enabled
                          ? (isSel
                              ? ToolkitColors.royalBlue
                              : ToolkitColors.slateMuted)
                          : ToolkitColors.slateMuted,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    if (imgAsset != null) ...[
                      AluproThumbnail(
                        assetPath: imgAsset,
                        width: thumbW,
                        height: thumbH,
                        enableTapToZoom: false,
                        opacity: p.enabled ? 1.0 : 0.55,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: p.enabled
                                  ? ToolkitColors.slateDark
                                  : ToolkitColors.slateMuted,
                            ),
                          ),
                          if (p.subtitle != null && p.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.subtitle!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ToolkitColors.slateMuted,
                              ),
                            ),
                          ],
                          if (p.warningBadge != null) ...[
                            const SizedBox(height: 6),
                            buildStatusBadge(p.warningBadge!, isWarning: true),
                          ],
                          if (isCompact && hasDisabledBadge) ...[
                            const SizedBox(height: 6),
                            buildStatusBadge(p.disabledBadge!),
                          ],
                        ],
                      ),
                    ),
                    if (!isCompact && hasDisabledBadge) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: buildStatusBadge(p.disabledBadge!),
                      ),
                    ] else if (p.enabled && imgAsset != null) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'ซูมดูผังบาน',
                        onPressed: () => showAluproImageZoomDialog(
                          ctx,
                          assetPath: imgAsset,
                          title: p.title,
                          subtitle: p.subtitle,
                        ),
                        icon: const Icon(
                          Icons.zoom_in_rounded,
                          size: 20,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NextStickyBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;
  final String label;

  const _NextStickyBar({
    required this.enabled,
    required this.onPressed,
    this.label = 'ถัดไป (กรอกขนาดงาน)',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ToolkitColors.royalBlue,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: enabled ? onPressed : null,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leadingWidget;
  final bool enabled;
  final String? disabledBadge;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    this.subtitle,
    this.leadingWidget,
    this.enabled = true,
    this.disabledBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final hasDisabledBadge = !enabled && disabledBadge != null;

        return InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : ToolkitColors.disabledBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: Row(
              children: [
                if (leadingWidget != null) ...[
                  leadingWidget!,
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? ToolkitColors.slateDark
                              : ToolkitColors.slateMuted,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                      if (isCompact && hasDisabledBadge) ...[
                        const SizedBox(height: 7),
                        buildStatusBadge(disabledBadge!),
                      ],
                    ],
                  ),
                ),
                if (!isCompact && hasDisabledBadge) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: buildStatusBadge(disabledBadge!),
                  ),
                ] else if (enabled) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ToolkitColors.slateMuted,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Size & Spec Input Screen (All 5 Table Modes + All Option Controls)
// =============================================================================
class _MutableSizeRow {
  final TextEditingController wCtrl;
  final TextEditingController hCtrl;
  final TextEditingController auxCtrl;
  final TextEditingController qtyCtrl;

  _MutableSizeRow({
    String w = '',
    String h = '',
    String aux = '',
    String qty = '1',
  })  : wCtrl = TextEditingController(text: w),
        hCtrl = TextEditingController(text: h),
        auxCtrl = TextEditingController(text: aux),
        qtyCtrl = TextEditingController(text: qty);

  void dispose() {
    wCtrl.dispose();
    hCtrl.dispose();
    auxCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class SizeAndSpecInputScreen extends StatefulWidget {
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final PatternCardDef pattern;
  final int? targetProjectId;
  final SavedProjectItem? editingProjectItem;

  const SizeAndSpecInputScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.pattern,
    this.targetProjectId,
    this.editingProjectItem,
  });

  @override
  State<SizeAndSpecInputScreen> createState() => _SizeAndSpecInputScreenState();
}

class _SizeAndSpecInputScreenState extends State<SizeAndSpecInputScreen> {
  late String _brandTitle;
  late String _priceBrandKey;
  late String _systemTitle;
  late PatternCardDef _pattern;
  final Map<String, String> _selectedOpts = {};
  final List<_MutableSizeRow> _rows = [];
  final TextEditingController _dripLenCtrl = TextEditingController();

  List<OptionGroupDef> get _effectiveOptionGroups =>
      CatalogDefinitions.effectiveOptionGroupsFor(_pattern);

  static String _fmtDim(double v) {
    if ((v - v.roundToDouble()).abs() < 0.005) {
      return v.round().toString();
    }
    return v.toStringAsFixed(1);
  }

  void _initOptionsForPattern(
    PatternCardDef pat, {
    Map<String, String>? carryOver,
  }) {
    _selectedOpts.clear();
    final groups = CatalogDefinitions.effectiveOptionGroupsFor(pat);
    for (final g in groups) {
      String val = g.defaultValue;
      final prev = carryOver?[g.id];
      if (prev != null && prev.isNotEmpty) {
        if (g.choices.any((c) => c.id == prev && c.enabled)) {
          val = prev;
        } else if (g.id == 'mosquito') {
          if (prev == 'false') {
            val = 'none';
          } else if (prev == 'fiber' || prev == 'small_mkt' || prev == 'true') {
            final fiberChoice = g.choices.where(
              (c) =>
                  c.enabled &&
                  (c.id == 'fiber' || c.id == 'small_mkt' || c.id == 'true'),
            );
            if (fiberChoice.isNotEmpty) val = fiberChoice.first.id;
          }
        }
      }
      _selectedOpts[g.id] = val;
    }
    // Preserve optional quotation/material spec metadata or populate sensible defaults
    if (carryOver != null) {
      for (final k in const [
        'spec_alu_thick',
        'spec_alu_color',
        'spec_glass_type',
        'spec_glass_thick',
        'pricing_alu_thick',
        'pricing_alu_color',
        'pricing_glass_key',
        'pricing_include_glass',
        'pricing_include_hw',
      ]) {
        if (carryOver.containsKey(k)) {
          _selectedOpts[k] = carryOver[k]!;
        }
      }
    }
    final hasOwnThick = groups.any((g) => g.id == 'thickness');
    final isHeavySeries = pat.id.startsWith('c3_') ||
        pat.id.startsWith('fold_') ||
        pat.foldingFamily != null ||
        _systemTitle.contains('ICONIQ') ||
        _systemTitle.contains('ยูโร');
    if (!hasOwnThick &&
        (_selectedOpts['spec_alu_thick']?.trim().isEmpty ?? true)) {
      _selectedOpts['spec_alu_thick'] = isHeavySeries ? '1.5 มม.' : '1.2 มม.';
    }
    if (_selectedOpts['spec_alu_color']?.trim().isEmpty ?? true) {
      _selectedOpts['spec_alu_color'] =
          _priceBrandKey.toUpperCase() == 'ALUMET' ? 'อบดำ (8816)' : 'สีดำ';
    } else {
      final validColors = QuotationSpecFormatter.aluminumColorChoicesForBrand(
        _priceBrandKey,
        includePerItemOption: false,
        includeUnspecifiedOption: true,
      );
      if (!validColors.contains(_selectedOpts['spec_alu_color'])) {
        final normalized =
            QuotationSpecFormatter.normalizePricingColorForQuotation(
          _selectedOpts['spec_alu_color'],
          brandKey: _priceBrandKey,
        );
        final fallback =
            _priceBrandKey.toUpperCase() == 'ALUMET' ? 'อบดำ (8816)' : 'สีดำ';
        _selectedOpts['spec_alu_color'] =
            validColors.contains(normalized) ? normalized : fallback;
        _selectedOpts.remove('pricing_alu_color');
      }
    }
    final isCat5Frameless = _priceBrandKey.toUpperCase() == 'VVP' ||
        _priceBrandKey.toUpperCase() == 'RP' ||
        pat.id.startsWith('c5_');
    if (_selectedOpts['spec_glass_type']?.trim().isEmpty ?? true) {
      _selectedOpts['spec_glass_type'] =
          isCat5Frameless ? 'กระจกเทมเปอร์ใส' : 'กระจกใส';
    }
    final hasOwnGlassThick = groups.any((g) => g.id == 'glass_thick');
    if (!hasOwnGlassThick &&
        (_selectedOpts['spec_glass_thick']?.trim().isEmpty ?? true)) {
      _selectedOpts['spec_glass_thick'] = isCat5Frameless
          ? '10 มม.'
          : (_priceBrandKey.toUpperCase() == 'MARKET' ? '5 มม.' : '6 มม.');
    }
  }

  Future<void> _applySavedShopSelectionDefaults() async {
    if (widget.editingProjectItem != null) return;
    final defs = await AppDatabase.instance.getShopSelectionDefaults();
    if (!mounted) return;
    final bKey = _priceBrandKey.trim().toUpperCase();
    final groups = _effectiveOptionGroups;
    setState(() {
      for (final g in groups) {
        final saved = defs.optionDefaults[g.id];
        if (saved != null &&
            g.choices.any((c) => c.id == saved && c.enabled)) {
          _selectedOpts[g.id] = saved;
        }
      }
      final savedThick = defs.brandAluThicknesses[bKey];
      if (savedThick != null && savedThick.isNotEmpty) {
        _selectedOpts['spec_alu_thick'] = savedThick;
        if (savedThick != 'ไม่ระบุ') {
          _selectedOpts['pricing_alu_thick'] = savedThick;
        }
      }
      final savedColor = defs.brandAluColors[bKey];
      if (savedColor != null && savedColor.isNotEmpty) {
        final validColors = QuotationSpecFormatter.aluminumColorChoicesForBrand(
          bKey,
          includePerItemOption: false,
          includeUnspecifiedOption: true,
        );
        if (validColors.contains(savedColor)) {
          _selectedOpts['spec_alu_color'] = savedColor;
          if (savedColor != 'ไม่ระบุ') {
            _selectedOpts['pricing_alu_color'] = savedColor;
          }
        }
      }
      final savedGlassType = defs.brandGlassTypes[bKey];
      if (savedGlassType != null && savedGlassType.isNotEmpty) {
        _selectedOpts['spec_glass_type'] = savedGlassType;
        _selectedOpts['pricing_include_glass'] =
            savedGlassType == 'ไม่รวมกระจก' ? 'false' : 'true';
      }
      final savedGlassThick = defs.brandGlassThicknesses[bKey];
      if (savedGlassThick != null && savedGlassThick.isNotEmpty) {
        _selectedOpts['spec_glass_thick'] = savedGlassThick;
      }
    });
  }

  Future<void> _saveCurrentOptionsAsShopDefault() async {
    final cur = await AppDatabase.instance.getShopSelectionDefaults();
    final nextOpts = Map<String, String>.from(cur.optionDefaults);
    for (final g in _effectiveOptionGroups) {
      final v = _selectedOpts[g.id];
      if (v != null && v.isNotEmpty) nextOpts[g.id] = v;
    }
    await AppDatabase.instance.saveShopSelectionDefaults(
      cur.copyWith(optionDefaults: nextOpts),
    );
    if (!mounted) return;
    showToolkitSnackBar(
      context,
      'จำค่าตั้งต้นร้านสำหรับตัวเลือกสเปกและอุปกรณ์เรียบร้อยแล้ว',
    );
  }

  Future<void> _saveMaterialSpecAsShopDefault() async {
    final bKey = _priceBrandKey.trim().toUpperCase();
    final cur = await AppDatabase.instance.getShopSelectionDefaults();
    final nextThicks = Map<String, String>.from(cur.brandAluThicknesses);
    final nextColors = Map<String, String>.from(cur.brandAluColors);
    final nextGTypes = Map<String, String>.from(cur.brandGlassTypes);
    final nextGThicks = Map<String, String>.from(cur.brandGlassThicknesses);

    final aThick = _selectedOpts['spec_alu_thick']?.trim() ?? '';
    final aColor = _selectedOpts['spec_alu_color']?.trim() ?? '';
    final gType = _selectedOpts['spec_glass_type']?.trim() ?? '';
    final gThick = _selectedOpts['spec_glass_thick']?.trim() ?? '';

    if (aThick.isNotEmpty) nextThicks[bKey] = aThick;
    if (aColor.isNotEmpty) nextColors[bKey] = aColor;
    if (gType.isNotEmpty) nextGTypes[bKey] = gType;
    if (gThick.isNotEmpty) nextGThicks[bKey] = gThick;

    await AppDatabase.instance.saveShopSelectionDefaults(
      cur.copyWith(
        brandAluThicknesses: nextThicks,
        brandAluColors: nextColors,
        brandGlassTypes: nextGTypes,
        brandGlassThicknesses: nextGThicks,
      ),
    );
    if (!mounted) return;
    showToolkitSnackBar(
      context,
      'จำค่าตั้งต้นร้าน ($bKey · $aColor · $gType $gThick) เรียบร้อยแล้ว',
    );
  }

  @override
  void initState() {
    super.initState();
    _brandTitle = widget.brandTitle;
    _priceBrandKey = widget.priceBrandKey;
    _systemTitle = widget.systemTitle;
    _pattern = widget.pattern;

    final edit = widget.editingProjectItem;
    _initOptionsForPattern(_pattern, carryOver: edit?.selectedOptions);
    if (edit == null) {
      _applySavedShopSelectionDefaults();
    }

    if (edit != null && edit.sizeRows.isNotEmpty) {
      for (final r in edit.sizeRows) {
        _rows.add(
          _MutableSizeRow(
            w: _fmtDim(r.widthMm),
            h: _fmtDim(r.heightMm),
            aux: r.auxMm != null ? _fmtDim(r.auxMm!) : '',
            qty: r.qty.toString(),
          ),
        );
      }
    } else {
      final initialCount =
          _pattern.tableMode == InputTableMode.fujiFourRow ? 4 : 1;
      for (int i = 0; i < initialCount; i++) {
        _rows.add(_MutableSizeRow());
      }
    }
  }

  Future<void> _onPickAnotherPattern() async {
    final picked = await Navigator.push<PickedPatternSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectScreen(pickMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    final prevOpts = Map<String, String>.from(_selectedOpts);
    setState(() {
      _brandTitle = picked.brandTitle;
      _priceBrandKey = picked.priceBrandKey;
      _systemTitle = picked.systemTitle;
      _pattern = picked.pattern;
      _initOptionsForPattern(_pattern, carryOver: prevOpts);
      if (_rows.isEmpty) {
        _rows.add(_MutableSizeRow());
      }
    });
    showToolkitSnackBar(
      context,
      'เปลี่ยนแบบเป็น $_brandTitle · ${_pattern.title} แล้ว (คงขนาดเดิมไว้ครบ)',
    );
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _dripLenCtrl.dispose();
    super.dispose();
  }

  bool get _needsAuxField =>
      _pattern.tableMode == InputTableMode.smartPlus90FourCol ||
      _pattern.tableMode == InputTableMode.cornerW1W2 ||
      _pattern.auxType != AuxDimensionType.none;

  bool get _showsDripTrayLength =>
      _pattern.id.startsWith('c2_sch_260_') &&
      (_selectedOpts['drip_tray'] ?? 'none') != 'none';

  Future<void> _onCalculate() async {
    final validRows = <SizeRowInput>[];

    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final wTxt = r.wCtrl.text.trim();
      final hTxt = r.hCtrl.text.trim();
      final auxTxt = r.auxCtrl.text.trim();

      // In Fuji 4-row or multi-row mode, skip completely blank extra rows
      if (wTxt.isEmpty && hTxt.isEmpty && _rows.length > 1) {
        continue;
      }

      final w = double.tryParse(wTxt);
      final h = double.tryParse(hTxt);
      final qty = int.tryParse(r.qtyCtrl.text.trim()) ?? 1;

      if (w == null || w <= 0 || h == null || h <= 0) {
        showToolkitSnackBar(
          context,
          'กรุณากรอกความกว้างและความสูงให้ถูกต้อง (มม.)',
        );
        return;
      }
      if (qty <= 0) {
        showToolkitSnackBar(context, 'จำนวนชุดต้องมากกว่า 0');
        return;
      }

      double? auxVal;
      if (_needsAuxField) {
        auxVal = double.tryParse(auxTxt);
        if (auxVal == null || auxVal <= 0) {
          final lbl = _pattern.tableMode == InputTableMode.cornerW1W2
              ? 'ความกว้างฝั่งขวา W2'
              : (_pattern.auxLabel ?? 'ค่า H1');
          showToolkitSnackBar(context, 'กรุณากรอก $lbl ให้ถูกต้อง');
          return;
        }
        if ((_pattern.auxType == AuxDimensionType.refHeightH1 ||
                _pattern.id.contains('_top_')) &&
            auxVal >= h) {
          showToolkitSnackBar(
            context,
            'ความสูง H1 ต้องน้อยกว่าความสูงรวม H',
          );
          return;
        }
      }

      validRows.add(
        SizeRowInput(
          widthMm: w,
          heightMm: h,
          auxMm: auxVal,
          qty: qty,
        ),
      );
    }

    if (validRows.isEmpty) {
      showToolkitSnackBar(context, 'กรุณากรอกขนาดอย่างน้อย 1 รายการ');
      return;
    }

    double? dripLen;
    if (_showsDripTrayLength && _dripLenCtrl.text.trim().isNotEmpty) {
      dripLen = double.tryParse(_dripLenCtrl.text.trim());
    }

    final output = ParametricSystemResolver.calculate(
      brandTitle: _brandTitle,
      priceBrandKey: _priceBrandKey,
      systemTitle: _systemTitle,
      pattern: _pattern,
      selectedOptions: _selectedOpts,
      sizeRows: validRows,
      dripTrayLengthMm: dripLen,
    );

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          output: output,
          sizeRows: validRows,
          targetProjectId: widget.targetProjectId,
          editingProjectItem: widget.editingProjectItem,
        ),
      ),
    );
    if (widget.editingProjectItem != null && saved == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pat = _pattern;
    final optionGroups = _effectiveOptionGroups;
    final isEditing = widget.editingProjectItem != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'แก้ไขแบบ · $_brandTitle · ${pat.title}'
              : '$_brandTitle · ${pat.title}',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Summary Banner with Pattern Diagram Preview + Switch Pattern button
                Builder(
                  builder: (ctx) {
                    final patAsset = AluproImageRegistry.instance
                        .resolvePatternAsset(pat.id);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ToolkitColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (patAsset != null) ...[
                                AluproThumbnail(
                                  assetPath: patAsset,
                                  width: 108,
                                  height: 76,
                                  borderRadius: 10,
                                  padding: const EdgeInsets.all(4),
                                  showZoomBadge: true,
                                  zoomTitle: pat.title,
                                  zoomSubtitle: '$_brandTitle · $_systemTitle',
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pat.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: ToolkitColors.slateDark,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$_brandTitle · $_systemTitle · หน่วยมิลลิเมตร (มม.)',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: ToolkitColors.slateMuted,
                                      ),
                                    ),
                                    if (patAsset != null) ...[
                                      const SizedBox(height: 5),
                                      const Text(
                                        'แตะรูปเพื่อขยายดูผังบาน',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: ToolkitColors.royalBlue,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const ValueKey('btn_change_pattern'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ToolkitColors.royalBlue,
                                    side: BorderSide(
                                      color: ToolkitColors.royalBlue
                                          .withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _onPickAnotherPattern,
                                  icon: const Icon(Icons.swap_horiz_rounded,
                                      size: 16),
                                  label: const Text(
                                    'เปลี่ยนแบบบาน',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (_) {
                                  final hasOv = SeedRepository.instance
                                          .getFormulaOverride(pat.id) !=
                                      null;
                                  return OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_input_edit_formula'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: hasOv
                                          ? ToolkitColors.vipGoldText
                                          : ToolkitColors.slateDark,
                                      backgroundColor: hasOv
                                          ? ToolkitColors.vipGoldBg
                                          : null,
                                      side: BorderSide(
                                        color: hasOv
                                            ? ToolkitColors.vipGoldText
                                                .withValues(alpha: 0.5)
                                            : ToolkitColors.cardBorder,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 10),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async {
                                      final changed =
                                          await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FormulaOverrideEditorScreen(
                                            pattern: pat,
                                            brandTitle: _brandTitle,
                                            priceBrandKey: _priceBrandKey,
                                            systemTitle: _systemTitle,
                                            selectedOptions: _selectedOpts,
                                          ),
                                        ),
                                      );
                                      if (changed == true && mounted) {
                                        setState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.tune_rounded,
                                        size: 16),
                                    label: Text(
                                      hasOv ? 'สูตรแก้เอง' : 'แก้ไขสูตร',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Option Groups (Chips / Dropdown / Checkbox / Switch) + Universal 3 Mosquito Screens
                if (optionGroups.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ToolkitColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'ตัวเลือกสเปกและอุปกรณ์',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: ToolkitColors.slateDark,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: const ValueKey(
                                  'btn_input_save_option_defaults'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              onPressed: _saveCurrentOptionsAsShopDefault,
                              icon: const Icon(Icons.bookmark_added_outlined,
                                  size: 15),
                              label: const Text(
                                'จำค่าตั้งต้นร้าน',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...optionGroups.map(_buildOptionControl),
                        if (_showsDripTrayLength) ...[
                          const SizedBox(height: 6),
                          TextField(
                            controller: _dripLenCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'ความยาวถาดรองน้ำ (มม.) — เว้นว่างใช้ความกว้าง W',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // SMART PLUS Euro 90° H / H1 Guide Button
                if (pat.tableMode == InputTableMode.smartPlus90FourCol) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showH1GuideDialog(context),
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: const Text('ดูตำแหน่งวัด H และ H1'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Dimension Table / Form
                _buildSizeInputSection(),
                const SizedBox(height: 14),

                // Optional Material & Glass Spec for Quotation
                _buildQuotationSpecCard(),
              ],
            ),
          ),

          // Sticky Calculate CTA
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isEditing
                        ? ToolkitColors.successGreen
                        : ToolkitColors.royalBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _onCalculate,
                  icon: Icon(
                    isEditing
                        ? Icons.update_rounded
                        : Icons.calculate_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isEditing
                        ? 'คำนวณและอัปเดตงานเดิม'
                        : 'คำนวณระยะตัดและถอดของ',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionControl(OptionGroupDef grp) {
    final curVal = _selectedOpts[grp.id] ?? grp.defaultValue;

    switch (grp.controlType) {
      case OptionControlType.chips:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                grp.title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ToolkitColors.slateBody,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: grp.choices.map((ch) {
                  final selected = curVal == ch.id;
                  if (!ch.enabled) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: ToolkitColors.disabledPillBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ToolkitColors.cardBorder),
                      ),
                      child: Text(
                        ch.disabledBadge != null
                            ? '${ch.label} (${ch.disabledBadge})'
                            : ch.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                    );
                  }
                  return ChoiceChip(
                    label: Text(ch.label),
                    selected: selected,
                    selectedColor: ToolkitColors.softBlueBg,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? ToolkitColors.royalBlue
                          : ToolkitColors.slateBody,
                    ),
                    side: BorderSide(
                      color: selected
                          ? ToolkitColors.royalBlue
                          : ToolkitColors.cardBorder,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedOpts[grp.id] = ch.id);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case OptionControlType.dropdown:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            initialValue: curVal,
            decoration: InputDecoration(
              labelText: grp.title,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: grp.choices
                .where((c) => c.enabled)
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(
                      c.label,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedOpts[grp.id] = v);
            },
          ),
        );

      case OptionControlType.checkbox:
        final checked = curVal == 'true';
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: checked,
          title: Text(
            grp.title,
            style: const TextStyle(fontSize: 13.5, color: ToolkitColors.slateBody),
          ),
          onChanged: (v) {
            setState(() => _selectedOpts[grp.id] = (v ?? false) ? 'true' : 'false');
          },
        );

      case OptionControlType.switchToggle:
        final toggled = curVal == 'true';
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: toggled,
          title: Text(
            grp.title,
            style: const TextStyle(fontSize: 13.5, color: ToolkitColors.slateBody),
          ),
          onChanged: (v) {
            setState(() => _selectedOpts[grp.id] = v ? 'true' : 'false');
          },
        );
    }
  }

  Widget _buildSizeInputSection() {
    final mode = _pattern.tableMode;

    if (mode == InputTableMode.cornerW1W2 || mode == InputTableMode.singleSet) {
      final row = _rows.first;
      final isCorner = mode == InputTableMode.cornerW1W2;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ToolkitColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorner ? 'ขนาดชุดเข้ามุม 90° (มม.)' : 'ขนาดชุดงาน (มม.)',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: ToolkitColors.slateDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isCorner
                    ? 'ความกว้างฝั่งซ้าย W1 (มม.) *'
                    : (_pattern.auxType == AuxDimensionType.secondWidthW2
                        ? 'ความกว้างบานที่ 1 W1 (มม.) *'
                        : 'ความกว้าง W (มม.) *'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (isCorner || _pattern.auxType != AuxDimensionType.none) ...[
              TextField(
                controller: row.auxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isCorner
                      ? 'ความกว้างฝั่งขวา W2 (มม.) *'
                      : '${_pattern.auxLabel ?? "ระยะเสริม (มม.)"} *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: row.hCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ความสูงรวม H (มม.) *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวนชุด *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      );
    }

    // Multi-Row Table (standardMultiRow, fujiFourRow, smartPlus90FourCol)
    final hasAuxCol = mode == InputTableMode.smartPlus90FourCol ||
        _pattern.auxType != AuxDimensionType.none;
    final auxHeader = mode == InputTableMode.smartPlus90FourCol
        ? 'สูง H1'
        : 'H1 (มม.)';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการขนาดงาน (มม.)',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.slateDark,
                ),
              ),
              Text(
                '${_rows.length} แถว',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ToolkitColors.slateMuted,
                ),
              ),
            ],
          ),
          if (_pattern.auxLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'หมายเหตุ: ${_pattern.auxLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: ToolkitColors.royalBlue,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...List.generate(_rows.length, (idx) {
            final r = _rows[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '#${idx + 1}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ToolkitColors.slateMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _compactNumField(r.wCtrl, 'กว้าง W'),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: _compactNumField(r.hCtrl, 'สูง H'),
                  ),
                  if (hasAuxCol) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: _compactNumField(r.auxCtrl, auxHeader),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _compactNumField(r.qtyCtrl, 'จำนวน', integer: true),
                  ),
                  if (_rows.length > 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          final removed = _rows.removeAt(idx);
                          removed.dispose();
                        });
                      },
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _rows.add(_MutableSizeRow()));
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('เพิ่มขนาดอื่น'),
          ),
        ],
      ),
    );
  }

  Widget _compactNumField(
    TextEditingController ctrl,
    String label, {
    bool integer = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: integer
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  void _showH1GuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตำแหน่งการวัด H และ H1 (เฟรม 90°)'),
        content: const Text(
          '• ความสูงรวม H = ความสูงตั้งแต่ขอบวงกบบนสุดถึงพื้นล่างสุด (มม.)\n'
          '• ความสูง H1 = ความสูงเฉพาะส่วนชุดบานเลื่อนหลัก (มม.)\n'
          '• กรณีมีช่องแสงบน ระบบจะคำนวณความสูงช่องแสงบนจาก (H − H1) โดยอัตโนมัติ',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationSpecCard() {
    final pat = _pattern;
    final hasOwnThickness = pat.optionGroups.any((g) => g.id == 'thickness');
    final hasOwnGlassThick = pat.optionGroups.any((g) => g.id == 'glass_thick');

    final curAluThick = _selectedOpts['spec_alu_thick'] ?? '1.2 มม.';
    final curAluColor = _selectedOpts['spec_alu_color'] ??
        (_priceBrandKey.toUpperCase() == 'ALUMET' ? 'อบดำ (8816)' : 'สีดำ');
    final curGlassType = _selectedOpts['spec_glass_type'] ?? 'กระจกใส';
    final curGlassThick = _selectedOpts['spec_glass_thick'] ??
        (_priceBrandKey.toUpperCase() == 'MARKET' ? '5 มม.' : '6 มม.');
    final aluThickInputChoices = QuotationSpecFormatter.aluminumThicknessChoices
        .where((c) => c != 'ตามรายการ')
        .toList();
    final colorChoices = QuotationSpecFormatter.aluminumColorChoicesForBrand(
      _priceBrandKey,
      includePerItemOption: false,
      includeUnspecifiedOption: true,
    );
    final glassTypeInputChoices = QuotationSpecFormatter.glassTypeChoices
        .where((c) => c != 'ตามรายการ')
        .toList();
    final glassThickInputChoices = QuotationSpecFormatter.glassThicknessChoices
        .where((c) => c != 'ตามรายการ')
        .toList();

    final summaryBadges = <String>[
      if (!hasOwnThickness &&
          curAluThick != 'ตามรายการ' &&
          curAluThick != 'ไม่ระบุ')
        'หนา $curAluThick',
      if (curAluColor != 'ไม่ระบุ') curAluColor,
      if (curGlassType != 'ไม่ระบุ')
        (curGlassType == 'ไม่รวมกระจก' ||
                hasOwnGlassThick ||
                curGlassThick == 'ไม่ระบุ')
            ? curGlassType
            : '$curGlassType $curGlassThick'
      else if (!hasOwnGlassThick && curGlassThick != 'ไม่ระบุ')
        'กระจก $curGlassThick',
    ];

    final isAlumetBrand = _priceBrandKey.toUpperCase() == 'ALUMET';

    Widget chipGroup({
      required String label,
      required List<String> choices,
      required String current,
      required ValueChanged<String> onPick,
      bool showAlumetSwatches = false,
      Widget? headerTrailing,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ToolkitColors.slateBody,
                    ),
                  ),
                ),
                ?headerTrailing,
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: choices.map((ch) {
                final sel = current == ch;
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: AlumetColorLabelRow(
                    colorName: ch,
                    showSwatch: showAlumetSwatches,
                  ),
                  selected: sel,
                  selectedColor: ToolkitColors.softBlueBg,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? ToolkitColors.royalBlue
                        : ToolkitColors.slateBody,
                  ),
                  side: BorderSide(
                    color: sel
                        ? ToolkitColors.royalBlue
                        : ToolkitColors.cardBorder,
                  ),
                  onSelected: (_) => onPick(ch),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text(
          'ระบุความหนา / สี / ประเภทกระจก (สำหรับใบเสนอราคา)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ToolkitColors.slateDark,
          ),
        ),
        subtitle: Text(
          summaryBadges.isEmpty
              ? 'ไม่บังคับ — เลือกไว้ล่วงหน้าหรือกำหนดตอนสร้างใบเสนอราคาได้'
              : summaryBadges.join(' · '),
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                summaryBadges.isEmpty ? FontWeight.w400 : FontWeight.w600,
            color: summaryBadges.isEmpty
                ? ToolkitColors.slateMuted
                : ToolkitColors.royalBlue,
          ),
        ),
        children: [
          if (!hasOwnThickness)
            chipGroup(
              label: 'ความหนาอลูมิเนียม',
              choices: aluThickInputChoices,
              current: curAluThick,
              onPick: (v) => setState(() {
                _selectedOpts['spec_alu_thick'] = v;
                if (v != 'ไม่ระบุ') {
                  _selectedOpts['pricing_alu_thick'] = v;
                } else {
                  _selectedOpts.remove('pricing_alu_thick');
                }
              }),
            ),
          chipGroup(
            label: isAlumetBrand
                ? 'รหัสสีอลูมิเนียม ALUMET (27 สี · มีตัวอย่างเนื้อสี)'
                : 'สีอลูมิเนียม',
            showAlumetSwatches: isAlumetBrand,
            headerTrailing: isAlumetBrand
                ? TextButton.icon(
                    key: const ValueKey('btn_open_alumet_color_chart'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () => showAlumetColorChartDialog(
                      context,
                      selectedColor: curAluColor,
                      onPick: (v) => setState(() {
                        _selectedOpts['spec_alu_color'] = v;
                        _selectedOpts['pricing_alu_color'] = v;
                      }),
                    ),
                    icon: const Icon(Icons.palette_outlined, size: 15),
                    label: const Text(
                      'ดูตารางสีใหญ่',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            choices: colorChoices,
            current: curAluColor,
            onPick: (v) => setState(() {
              _selectedOpts['spec_alu_color'] = v;
              if (v != 'ไม่ระบุ') {
                _selectedOpts['pricing_alu_color'] = v;
              } else {
                _selectedOpts.remove('pricing_alu_color');
              }
            }),
          ),
          chipGroup(
            label: 'ประเภทกระจก',
            choices: glassTypeInputChoices,
            current: curGlassType,
            onPick: (v) => setState(() {
              _selectedOpts['spec_glass_type'] = v;
              _selectedOpts.remove('pricing_glass_key');
              _selectedOpts['pricing_include_glass'] =
                  v == 'ไม่รวมกระจก' ? 'false' : 'true';
            }),
          ),
          if (curGlassType != 'ไม่รวมกระจก' && !hasOwnGlassThick)
            chipGroup(
              label: 'ความหนากระจก',
              choices: glassThickInputChoices,
              current: curGlassThick,
              onPick: (v) => setState(() {
                _selectedOpts['spec_glass_thick'] = v;
                _selectedOpts.remove('pricing_glass_key');
              }),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('btn_input_save_material_defaults'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: _saveMaterialSpecAsShopDefault,
              icon: const Icon(Icons.bookmark_added_outlined, size: 16),
              label: const Text(
                'จำค่าตั้งต้นร้าน (ความหนา · สี · กระจก)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
