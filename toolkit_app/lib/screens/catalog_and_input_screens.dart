import 'package:flutter/material.dart';
import '../data/alupro_image_registry.dart';
import '../data/catalog_definitions.dart';
import '../engine/parametric_system_resolver.dart';
import '../models/app_models.dart';
import 'alupro_thumbnail_widgets.dart';
import 'result_and_pricing_screens.dart';
import 'theme_tokens.dart';

class CategorySelectScreen extends StatelessWidget {
  final int? targetProjectId;

  const CategorySelectScreen({super.key, this.targetProjectId});

  ({IconData icon, Color fg, Color bg}) _categoryBadgeStyle(String categoryId) {
    switch (categoryId) {
      case 'cat1_market':
        return (
          icon: Icons.grid_view_rounded,
          fg: const Color(0xFF1E56C5),
          bg: const Color(0xFFEAF1FE),
        );
      case 'cat2_pattana':
        return (
          icon: Icons.dashboard_customize_rounded,
          fg: const Color(0xFFD99014),
          bg: const Color(0xFFFDF3DF),
        );
      case 'cat3_euro':
        return (
          icon: Icons.widgets_rounded,
          fg: const Color(0xFF1F7A5A),
          bg: const Color(0xFFE7F5EE),
        );
      case 'cat4_folding':
        return (
          icon: Icons.sensor_door_outlined,
          fg: const Color(0xFFC0425A),
          bg: const Color(0xFFFAEDEF),
        );
      default:
        return (
          icon: Icons.shower_outlined,
          fg: const Color(0xFF4F46E5),
          bg: const Color(0xFFEEF2FF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = CatalogDefinitions.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกหมวดระบบอลูมิเนียม')),
      body: ListView(
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
                final badge = _categoryBadgeStyle(cat.id);
                return _NavCard(
                  title: '${i + 1}. ${cat.title}',
                  subtitle: cat.subtitle,
                  leadingWidget: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: badge.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(badge.icon, color: badge.fg, size: 25),
                  ),
                  enabled: cat.enabled,
                  disabledBadge: cat.disabledBadge,
                  onTap: () {
                    if (cat.directSystems.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubSystemSelectScreen(
                            brandTitle: cat.title,
                            priceBrandKey: 'MARKET',
                            systems: cat.directSystems,
                            targetProjectId: targetProjectId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BrandSelectScreen(
                            category: cat,
                            targetProjectId: targetProjectId,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class BrandSelectScreen extends StatelessWidget {
  final CategoryDef category;
  final int? targetProjectId;

  const BrandSelectScreen({
    super.key,
    required this.category,
    this.targetProjectId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
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
              onTap: () {
                final brand = category.brands[i];
                if (brand.directPatterns.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatternSelectScreen(
                        brandTitle: brand.title,
                        priceBrandKey: brand.priceBrandKey,
                        systemTitle: brand.subtitle,
                        patterns: brand.directPatterns,
                        targetProjectId: targetProjectId,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubSystemSelectScreen(
                        brandTitle: brand.title,
                        priceBrandKey: brand.priceBrandKey,
                        systems: brand.systems,
                        targetProjectId: targetProjectId,
                      ),
                    ),
                  );
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: brand.enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: brand.enabled ? Colors.white : ToolkitColors.disabledBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ToolkitColors.cardBorder),
        ),
        child: Row(
          children: [
            BrandLogoPlate(
              assetPath: logoAsset,
              width: 104,
              height: 54,
              enabled: brand.enabled,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: brand.enabled
                          ? ToolkitColors.slateDark
                          : ToolkitColors.slateMuted,
                    ),
                  ),
                  if (brand.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      brand.subtitle,
                      style: const TextStyle(
                        fontSize: 13.2,
                        color: ToolkitColors.slateMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!brand.enabled && brand.disabledBadge != null)
              buildStatusBadge(brand.disabledBadge!)
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: ToolkitColors.slateMuted,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class SubSystemSelectScreen extends StatelessWidget {
  final String brandTitle;
  final String priceBrandKey;
  final List<SubSystemDef> systems;
  final int? targetProjectId;

  const SubSystemSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systems,
    this.targetProjectId,
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
            onTap: () {
              if (sys.emptyMessage != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _EmptySystemScreen(
                      title: sys.title,
                      message: sys.emptyMessage!,
                    ),
                  ),
                );
              } else if (sys.subTabs.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubTabbedPatternSelectScreen(
                      brandTitle: brandTitle,
                      priceBrandKey: priceBrandKey,
                      systemTitle: sys.title,
                      subTabs: sys.subTabs,
                      targetProjectId: targetProjectId,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatternSelectScreen(
                      brandTitle: brandTitle,
                      priceBrandKey: priceBrandKey,
                      systemTitle: sys.title,
                      patterns: sys.patterns,
                      targetProjectId: targetProjectId,
                    ),
                  ),
                );
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

  const SubTabbedPatternSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.subTabs,
    this.targetProjectId,
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
            onPressed: _selected == null
                ? null
                : () {
                    final curTab = widget.subTabs[_tabController.index];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SizeAndSpecInputScreen(
                          brandTitle: widget.brandTitle,
                          priceBrandKey: widget.priceBrandKey,
                          systemTitle:
                              '${widget.systemTitle} (${curTab.title})',
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

  const PatternSelectScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.patterns,
    this.targetProjectId,
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
            onPressed: _selected == null
                ? null
                : () {
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: patterns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = patterns[i];
        final isSel = p.id == selectedId;
        final imgAsset = AluproImageRegistry.instance.resolvePatternAsset(p.id);
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
                    width: 68,
                    height: 48,
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
                    ],
                  ),
                ),
                if (!p.enabled && p.disabledBadge != null) ...[
                  const SizedBox(width: 8),
                  buildStatusBadge(p.disabledBadge!),
                ] else if (imgAsset != null) ...[
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
  }
}

class _NextStickyBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const _NextStickyBar({required this.enabled, required this.onPressed});

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
            child: const Text(
              'ถัดไป (กรอกขนาดงาน)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              const SizedBox(width: 14),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!enabled && disabledBadge != null)
              buildStatusBadge(disabledBadge!)
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: ToolkitColors.slateMuted,
              ),
          ],
        ),
      ),
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

  const SizeAndSpecInputScreen({
    super.key,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.pattern,
    this.targetProjectId,
  });

  @override
  State<SizeAndSpecInputScreen> createState() => _SizeAndSpecInputScreenState();
}

class _SizeAndSpecInputScreenState extends State<SizeAndSpecInputScreen> {
  final Map<String, String> _selectedOpts = {};
  final List<_MutableSizeRow> _rows = [];
  final TextEditingController _dripLenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final g in widget.pattern.optionGroups) {
      _selectedOpts[g.id] = g.defaultValue;
    }
    final initialCount =
        widget.pattern.tableMode == InputTableMode.fujiFourRow ? 4 : 1;
    for (int i = 0; i < initialCount; i++) {
      _rows.add(_MutableSizeRow());
    }
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
      widget.pattern.tableMode == InputTableMode.smartPlus90FourCol ||
      widget.pattern.tableMode == InputTableMode.cornerW1W2 ||
      widget.pattern.auxType != AuxDimensionType.none;

  bool get _showsDripTrayLength =>
      widget.pattern.id.startsWith('c2_sch_260_') &&
      (_selectedOpts['drip_tray'] ?? 'none') != 'none';

  void _onCalculate() {
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
          final lbl = widget.pattern.tableMode == InputTableMode.cornerW1W2
              ? 'ความกว้างฝั่งขวา W2'
              : (widget.pattern.auxLabel ?? 'ค่า H1');
          showToolkitSnackBar(context, 'กรุณากรอก $lbl ให้ถูกต้อง');
          return;
        }
        if ((widget.pattern.auxType == AuxDimensionType.refHeightH1 ||
                widget.pattern.id.contains('_top_')) &&
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
      brandTitle: widget.brandTitle,
      priceBrandKey: widget.priceBrandKey,
      systemTitle: widget.systemTitle,
      pattern: widget.pattern,
      selectedOptions: _selectedOpts,
      sizeRows: validRows,
      dripTrayLengthMm: dripLen,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          output: output,
          sizeRows: validRows,
          targetProjectId: widget.targetProjectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pat = widget.pattern;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.brandTitle} · ${pat.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Summary Banner with Pattern Diagram Preview
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
                      child: Row(
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
                              zoomSubtitle:
                                  '${widget.brandTitle} · ${widget.systemTitle}',
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
                                  '${widget.brandTitle} · ${widget.systemTitle} · หน่วยมิลลิเมตร (มม.)',
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
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Option Groups (Chips / Dropdown / Checkbox / Switch)
                if (pat.optionGroups.isNotEmpty) ...[
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
                        const Text(
                          'ตัวเลือกสเปกและอุปกรณ์',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...pat.optionGroups.map(_buildOptionControl),
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
                    backgroundColor: ToolkitColors.royalBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _onCalculate,
                  icon: const Icon(Icons.calculate_rounded, size: 20),
                  label: const Text(
                    'คำนวณระยะตัดและถอดของ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
    final mode = widget.pattern.tableMode;

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
                    : (widget.pattern.auxType == AuxDimensionType.secondWidthW2
                        ? 'ความกว้างบานที่ 1 W1 (มม.) *'
                        : 'ความกว้าง W (มม.) *'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (isCorner || widget.pattern.auxType != AuxDimensionType.none) ...[
              TextField(
                controller: row.auxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isCorner
                      ? 'ความกว้างฝั่งขวา W2 (มม.) *'
                      : '${widget.pattern.auxLabel ?? "ระยะเสริม (มม.)"} *',
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
        widget.pattern.auxType != AuxDimensionType.none;
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
          if (widget.pattern.auxLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'หมายเหตุ: ${widget.pattern.auxLabel}',
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
}
