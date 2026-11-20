import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/app_database.dart';
import '../data/catalog_definitions.dart';
import '../data/seed_repository.dart';
import '../engine/formula_evaluator.dart';
import '../engine/parametric_system_resolver.dart';
import '../models/app_models.dart';
import 'alupro_thumbnail_widgets.dart';
import 'catalog_and_input_screens.dart';
import 'theme_tokens.dart';

class _TemplateEntry {
  final String categoryId;
  final String categoryTitle;
  final String brandTitle;
  final String priceBrandKey;
  final String systemTitle;
  final PatternCardDef pattern;

  const _TemplateEntry({
    required this.categoryId,
    required this.categoryTitle,
    required this.brandTitle,
    required this.priceBrandKey,
    required this.systemTitle,
    required this.pattern,
  });
}

// =============================================================================
// Custom Profile System Studio — List & Management Screen
// =============================================================================
class CustomSystemListScreen extends StatefulWidget {
  final String? initialCategoryId;

  const CustomSystemListScreen({super.key, this.initialCategoryId});

  @override
  State<CustomSystemListScreen> createState() => _CustomSystemListScreenState();
}

class _CustomSystemListScreenState extends State<CustomSystemListScreen> {
  List<CustomProfileSystem> _systems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AppDatabase.instance.listCustomProfileSystems();
    SeedRepository.instance.setCustomSystemsInMemory(list);
    if (!mounted) return;
    setState(() {
      _systems = list;
      _loading = false;
    });
  }

  List<_TemplateEntry> _collectTemplates() {
    final out = <_TemplateEntry>[];
    for (final cat in CatalogDefinitions.categories) {
      for (final sys in cat.directSystems) {
        for (final pat in sys.patterns.where((p) => p.enabled)) {
          out.add(
            _TemplateEntry(
              categoryId: cat.id,
              categoryTitle: cat.title,
              brandTitle: cat.title,
              priceBrandKey: 'MARKET',
              systemTitle: sys.title,
              pattern: pat,
            ),
          );
        }
      }
      for (final brand in cat.brands.where((b) => b.enabled)) {
        for (final pat in brand.directPatterns.where((p) => p.enabled)) {
          out.add(
            _TemplateEntry(
              categoryId: cat.id,
              categoryTitle: cat.title,
              brandTitle: brand.title,
              priceBrandKey: brand.priceBrandKey,
              systemTitle: brand.subtitle.isNotEmpty
                  ? brand.subtitle
                  : 'ชุดระบบโปรไฟล์',
              pattern: pat,
            ),
          );
        }
        for (final sys in brand.systems.where((s) => s.enabled)) {
          for (final pat in sys.patterns.where((p) => p.enabled)) {
            out.add(
              _TemplateEntry(
                categoryId: cat.id,
                categoryTitle: cat.title,
                brandTitle: brand.title,
                priceBrandKey: brand.priceBrandKey,
                systemTitle: sys.title,
                pattern: pat,
              ),
            );
          }
          for (final tab in sys.subTabs.where((t) => t.enabled)) {
            for (final pat in tab.patterns.where((p) => p.enabled)) {
              out.add(
                _TemplateEntry(
                  categoryId: cat.id,
                  categoryTitle: cat.title,
                  brandTitle: brand.title,
                  priceBrandKey: brand.priceBrandKey,
                  systemTitle: '${sys.title} (${tab.title})',
                  pattern: pat,
                ),
              );
            }
          }
        }
      }
    }
    return out;
  }

  Future<void> _openTemplatePicker() async {
    final templates = _collectTemplates();
    String query = '';
    _TemplateEntry? picked;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = query.trim().toLowerCase();
          final filtered = templates.where((t) {
            if (q.isEmpty) return true;
            return t.pattern.title.toLowerCase().contains(q) ||
                t.brandTitle.toLowerCase().contains(q) ||
                t.systemTitle.toLowerCase().contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'เลือกต้นแบบระบบเพื่อคัดลอกสูตร',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ToolkitColors.slateDark,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Text(
                      'ระบบจะคัดลอกรายการชิ้นส่วน สูตรตัด กระจก และอุปกรณ์มาให้ คุณสามารถเปลี่ยนชื่อรุ่น รหัสเส้น และตัวเลขหักระยะได้ทันที',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ToolkitColors.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText:
                            'ค้นหา เช่น บานเลื่อนสลับ, บานเปิดคู่, กระทุ้ง, ALUMET...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (v) => setModal(() => query = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final t = filtered[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            title: Text(
                              t.pattern.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${t.categoryTitle} · ${t.brandTitle} · ${t.systemTitle}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ToolkitColors.slateMuted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.copy_all_rounded,
                              size: 19,
                              color: ToolkitColors.royalBlue,
                            ),
                            onTap: () {
                              picked = t;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (picked == null || !mounted) return;
    final tpl = picked!;
    final defaultOpts = <String, String>{
      for (final g in tpl.pattern.optionGroups) g.id: g.defaultValue,
    };
    final resolvedTbl = ParametricSystemResolver.resolveFormulaTable(
      pattern: tpl.pattern,
      selectedOptions: defaultOpts,
      seed: SeedRepository.instance,
    );

    final newId = 'cust_sys_${DateTime.now().millisecondsSinceEpoch}';
    final draft = CustomProfileSystem(
      id: newId,
      categoryId: widget.initialCategoryId ?? tpl.categoryId,
      brandId: 'cust_brand_${DateTime.now().millisecondsSinceEpoch}',
      brandTitle: '${tpl.brandTitle} (รุ่นใหม่)',
      priceBrandKey: tpl.priceBrandKey,
      systemTitle: tpl.systemTitle,
      patternTitle: '${tpl.pattern.title} (กำหนดเอง)',
      patternSubtitle: 'คัดลอกจาก ${tpl.brandTitle}',
      tableMode: tpl.pattern.tableMode == InputTableMode.cornerW1W2
          ? InputTableMode.cornerW1W2
          : InputTableMode.standardMultiRow,
      auxType: tpl.pattern.auxType,
      auxLabel: tpl.pattern.auxLabel,
      formulaTable: VerifiedFormulaTable(
        key: newId,
        header: '${tpl.pattern.title} (กำหนดเอง)',
        cuts: resolvedTbl.cuts.map((c) => c.copyWith()).toList(),
        glasses: List<GlassPieceSpec>.from(resolvedTbl.glasses),
        hardware: List<HardwareItemSpec>.from(resolvedTbl.hardware),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomSystemEditorScreen(
          initialSystem: draft,
          isNewClone: true,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openCreateBlank() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomSystemEditorScreen(
          defaultCategoryId: widget.initialCategoryId ?? 'cat2_pattana',
        ),
      ),
    );
    _reload();
  }

  Future<void> _importSystemDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('นำเข้าชุดโปรไฟล์ใหม่ (.json)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'วางข้อความ JSON ของชุดโปรไฟล์ที่คัดลอกมาจากเครื่องอื่น แล้วกดนำเข้า',
              style: TextStyle(fontSize: 13, color: ToolkitColors.slateMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{ "id": "cust_sys_...", ... }',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data?.text != null) {
                ctrl.text = data!.text!;
              }
            },
            child: const Text('วางจากคลิปบอร์ด'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final raw = ctrl.text.trim();
                if (raw.isEmpty) return;
                final decoded = jsonDecode(raw);
                if (decoded is List) {
                  for (final item in decoded) {
                    final sys = CustomProfileSystem.fromJson(
                      item as Map<String, dynamic>,
                    );
                    await AppDatabase.instance.upsertCustomProfileSystem(sys);
                  }
                } else if (decoded is Map<String, dynamic>) {
                  final sys = CustomProfileSystem.fromJson(decoded);
                  await AppDatabase.instance.upsertCustomProfileSystem(sys);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _reload();
                if (mounted) {
                  showToolkitSnackBar(
                      context, 'นำเข้าชุดโปรไฟล์ใหม่เรียบร้อยแล้ว');
                }
              } catch (_) {
                if (mounted) {
                  showToolkitSnackBar(
                    context,
                    'รูปแบบข้อมูล JSON ไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง',
                  );
                }
              }
            },
            child: const Text('นำเข้า'),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String catId) {
    for (int i = 0; i < CatalogDefinitions.categories.length; i++) {
      final c = CatalogDefinitions.categories[i];
      if (c.id == catId) return '${i + 1}. ${c.title}';
    }
    return catId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการ / เพิ่มชุดโปรไฟล์ใหม่'),
        actions: [
          IconButton(
            tooltip: 'นำเข้าชุดโปรไฟล์ (.json)',
            onPressed: _importSystemDialog,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // Intro & Primary Action Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ToolkitColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.architecture_rounded,
                            color: ToolkitColors.royalBlue,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'เพิ่มชุดโปรไฟล์และสูตรตัดใหม่ได้ไม่จำกัด',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: ToolkitColors.slateDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'รองรับเมื่อโรงงานออกชุดโปรไฟล์รุ่นใหม่ในอนาคต เมื่อบันทึกแล้วระบบจะซิงก์เข้าเมนูคำนวณหลัก จัดเส้น ทำราคา และออกใบเสนอราคา PDF ทันที',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ToolkitColors.royalBlue,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: _openTemplatePicker,
                          icon: const Icon(Icons.copy_all_rounded, size: 19),
                          label: const Text(
                            'คัดลอกต้นแบบจากระบบที่มีอยู่ (แนะนำ)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _openCreateBlank,
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 19),
                          label: const Text(
                            'สร้างชุดโปรไฟล์ใหม่ตั้งแต่ต้น',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ชุดโปรไฟล์ที่สร้างไว้ (${_systems.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ToolkitColors.slateDark,
                      ),
                    ),
                    if (_systems.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final allJson = const JsonEncoder.withIndent('  ')
                              .convert(
                                  _systems.map((e) => e.toJson()).toList());
                          Clipboard.setData(ClipboardData(text: allJson));
                          showToolkitSnackBar(
                            context,
                            'คัดลอกข้อมูลทุกชุดโปรไฟล์ (.json) ลงคลิปบอร์ดแล้ว',
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: const Text('คัดลอกทั้งหมด'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_systems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ToolkitColors.cardBorder),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 46,
                          color: ToolkitColors.slateMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'ยังไม่มีชุดโปรไฟล์ที่สร้างเพิ่มเอง',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: ToolkitColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'กดปุ่ม "คัดลอกต้นแบบ" หรือ "สร้างชุดโปรไฟล์ใหม่ตั้งแต่ต้น" ด้านบนเพื่อเริ่มต้น',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._systems.map((sys) {
                    final cutsCount = sys.formulaTable.cuts.length;
                    final glsCount = sys.formulaTable.glasses.length;
                    final hwCount = sys.formulaTable.hardware.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (sys.patternImagePath != null &&
                                  sys.patternImagePath!.isNotEmpty) ...[
                                AluproThumbnail(
                                  assetPath: sys.patternImagePath,
                                  width: 56,
                                  height: 44,
                                  zoomTitle: sys.patternTitle,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sys.patternTitle,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: ToolkitColors.slateDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_categoryLabel(sys.categoryId)} · ${sys.brandTitle} · ${sys.systemTitle}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: ToolkitColors.royalBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'อลูมิเนียม $cutsCount รายการ · กระจก $glsCount รายการ · อุปกรณ์ $hwCount รายการ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ToolkitColors.slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: sys.enabled,
                                onChanged: (v) async {
                                  final updated = CustomProfileSystem(
                                    id: sys.id,
                                    categoryId: sys.categoryId,
                                    brandId: sys.brandId,
                                    brandTitle: sys.brandTitle,
                                    priceBrandKey: sys.priceBrandKey,
                                    brandLogoPath: sys.brandLogoPath,
                                    systemTitle: sys.systemTitle,
                                    patternTitle: sys.patternTitle,
                                    patternSubtitle: sys.patternSubtitle,
                                    patternImagePath: sys.patternImagePath,
                                    tableMode: sys.tableMode,
                                    auxType: sys.auxType,
                                    auxLabel: sys.auxLabel,
                                    formulaTable: sys.formulaTable,
                                    profileImagePaths: sys.profileImagePaths,
                                    enabled: v,
                                    createdAt: sys.createdAt,
                                    updatedAt: DateTime.now(),
                                  );
                                  await AppDatabase.instance
                                      .upsertCustomProfileSystem(updated);
                                  _reload();
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SizeAndSpecInputScreen(
                                        brandTitle: sys.brandTitle,
                                        priceBrandKey: sys.priceBrandKey,
                                        systemTitle: sys.systemTitle,
                                        pattern: sys.toPatternCardDef(),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.calculate_outlined,
                                    size: 17),
                                label: const Text('คำนวณทันที'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomSystemEditorScreen(
                                        initialSystem: sys,
                                      ),
                                    ),
                                  );
                                  _reload();
                                },
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('แก้ไขสูตร'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final raw =
                                      const JsonEncoder.withIndent('  ')
                                          .convert(sys.toJson());
                                  Clipboard.setData(ClipboardData(text: raw));
                                  showToolkitSnackBar(
                                    context,
                                    'คัดลอกชุดโปรไฟล์ "${sys.patternTitle}" (.json) แล้ว',
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('แชร์ JSON'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                onPressed: () async {
                                  await AppDatabase.instance
                                      .deleteCustomProfileSystem(sys.id);
                                  await _reload();
                                  if (context.mounted) {
                                    showToolkitSnackBar(
                                      context,
                                      'ลบชุดโปรไฟล์ "${sys.patternTitle}" แล้ว',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 17),
                                label: const Text('ลบ'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

// =============================================================================
// Editable Row Models for Custom System Editor
// =============================================================================
class _EditableCutRow {
  String section;
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController formulaCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController stockMmCtrl;
  String angle;
  final TextEditingController initPriceCtrl;
  String? imagePath;

  _EditableCutRow({
    this.section = 'วงกบ / เฟรม',
    String code = '',
    String name = '',
    String formula = 'W',
    int qty = 1,
    int stockMm = 6400,
    this.angle = '90° / 90°',
    String initPrice = '',
    this.imagePath,
  })  : codeCtrl = TextEditingController(text: code),
        nameCtrl = TextEditingController(text: name),
        formulaCtrl = TextEditingController(text: formula),
        qtyCtrl = TextEditingController(text: qty.toString()),
        stockMmCtrl = TextEditingController(text: stockMm.toString()),
        initPriceCtrl = TextEditingController(text: initPrice);

  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    formulaCtrl.dispose();
    qtyCtrl.dispose();
    stockMmCtrl.dispose();
    initPriceCtrl.dispose();
  }
}

class _EditableGlassRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  bool siteCut;
  final TextEditingController wFormulaCtrl;
  final TextEditingController hFormulaCtrl;

  _EditableGlassRow({
    String name = 'กระจกบานหลัก',
    int qty = 2,
    this.siteCut = false,
    String wFormula = '(W / 2) - 68',
    String hFormula = 'H - 140',
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty.toString()),
        wFormulaCtrl = TextEditingController(text: wFormula),
        hFormulaCtrl = TextEditingController(text: hFormula);

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    wFormulaCtrl.dispose();
    hFormulaCtrl.dispose();
  }
}

class _EditableHwRow {
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController qtyTextCtrl;
  final TextEditingController unitPriceCtrl;

  _EditableHwRow({
    String code = '',
    String name = '',
    String qtyText = '1 ชุด',
    String unitPrice = '',
  })  : codeCtrl = TextEditingController(text: code),
        nameCtrl = TextEditingController(text: name),
        qtyTextCtrl = TextEditingController(text: qtyText),
        unitPriceCtrl = TextEditingController(text: unitPrice);

  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    qtyTextCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

// =============================================================================
// Custom Profile System Editor Screen
// =============================================================================
class CustomSystemEditorScreen extends StatefulWidget {
  final CustomProfileSystem? initialSystem;
  final String defaultCategoryId;
  final bool isNewClone;

  const CustomSystemEditorScreen({
    super.key,
    this.initialSystem,
    this.defaultCategoryId = 'cat2_pattana',
    this.isNewClone = false,
  });

  @override
  State<CustomSystemEditorScreen> createState() =>
      _CustomSystemEditorScreenState();
}

class _CustomSystemEditorScreenState extends State<CustomSystemEditorScreen> {
  late String _systemId;
  late String _categoryId;
  late String _selectedBrandPreset; // existing brand id or '__NEW__'
  late final TextEditingController _brandTitleCtrl;
  late final TextEditingController _priceBrandKeyCtrl;
  late final TextEditingController _systemTitleCtrl;
  late final TextEditingController _patternTitleCtrl;
  late final TextEditingController _patternSubtitleCtrl;
  String? _brandLogoPath;
  String? _patternImagePath;
  late String _dimMode; // 'WH' | 'WH_H1' | 'CORNER_W1W2'

  // Live Formula Test Bench Inputs
  final TextEditingController _testWCtrl = TextEditingController(text: '2000');
  final TextEditingController _testHCtrl = TextEditingController(text: '2050');
  final TextEditingController _testAuxCtrl =
      TextEditingController(text: '1650');

  final List<_EditableCutRow> _cuts = [];
  final List<_EditableGlassRow> _glasses = [];
  final List<_EditableHwRow> _hardware = [];

  @override
  void initState() {
    super.initState();
    final init = widget.initialSystem;
    _systemId = init?.id ?? 'cust_sys_${DateTime.now().millisecondsSinceEpoch}';
    _categoryId = init?.categoryId ?? widget.defaultCategoryId;

    final existingBrands = _brandsForCategory(_categoryId);
    if (init != null && existingBrands.any((b) => b.id == init.brandId)) {
      _selectedBrandPreset = init.brandId;
    } else {
      _selectedBrandPreset = '__NEW__';
    }

    _brandTitleCtrl = TextEditingController(
      text: init?.brandTitle ?? 'แบรนด์โปรไฟล์ใหม่',
    );
    _priceBrandKeyCtrl = TextEditingController(
      text: init?.priceBrandKey ?? 'CUSTOM',
    );
    _systemTitleCtrl = TextEditingController(
      text: init?.systemTitle ?? 'บานเลื่อน',
    );
    _patternTitleCtrl = TextEditingController(
      text: init?.patternTitle ?? 'บานเลื่อนสลับ 2 บาน (ชุดใหม่)',
    );
    _patternSubtitleCtrl = TextEditingController(
      text: init?.patternSubtitle ?? '',
    );
    _brandLogoPath = init?.brandLogoPath;
    _patternImagePath = init?.patternImagePath;

    if (init?.tableMode == InputTableMode.cornerW1W2) {
      _dimMode = 'CORNER_W1W2';
    } else if (init?.auxType == AuxDimensionType.refHeightH1 ||
        init?.auxType == AuxDimensionType.transomHeightHt) {
      _dimMode = 'WH_H1';
    } else {
      _dimMode = 'WH';
    }

    if (init != null) {
      for (final c in init.formulaTable.cuts) {
        _cuts.add(
          _EditableCutRow(
            section: c.section,
            code: c.code,
            name: c.name,
            formula: c.formula,
            qty: c.qty,
            stockMm: c.stockMm,
            angle: c.angle,
            imagePath: init.profileImagePaths[c.code],
          ),
        );
      }
      for (final g in init.formulaTable.glasses) {
        _glasses.add(
          _EditableGlassRow(
            name: g.name,
            qty: g.qty,
            siteCut: g.siteCut,
            wFormula: g.wFormula,
            hFormula: g.hFormula,
          ),
        );
      }
      for (final h in init.formulaTable.hardware) {
        _hardware.add(
          _EditableHwRow(
            code: h.code,
            name: h.name,
            qtyText: h.qtyText,
          ),
        );
      }
    } else {
      // Starter rows for blank creation
      _cuts.addAll([
        _EditableCutRow(
          section: 'วงกบ / เฟรม',
          code: 'NEW-101',
          name: 'เฟรมบน',
          formula: 'W - 50',
          qty: 1,
        ),
        _EditableCutRow(
          section: 'วงกบ / เฟรม',
          code: 'NEW-102',
          name: 'เฟรมล่าง',
          formula: 'W - 50',
          qty: 1,
        ),
        _EditableCutRow(
          section: 'วงกบ / เฟรม',
          code: 'NEW-103',
          name: 'เฟรมข้าง',
          formula: 'H',
          qty: 2,
        ),
        _EditableCutRow(
          section: 'กรอบบาน',
          code: 'NEW-201',
          name: 'เสากรอบบานตั้ง',
          formula: 'H - 65',
          qty: 4,
        ),
        _EditableCutRow(
          section: 'กรอบบาน',
          code: 'NEW-202',
          name: 'ขวางบน/ล่างกรอบบาน',
          formula: '(W / 2) - 8',
          qty: 4,
        ),
      ]);
      _glasses.add(
        _EditableGlassRow(
          name: 'กระจกบานเลื่อน',
          qty: 2,
          siteCut: false,
          wFormula: '(W / 2) - 68',
          hFormula: 'H - 140',
        ),
      );
      _hardware.addAll([
        _EditableHwRow(code: 'HW-01', name: 'ล้อบานเลื่อนคู่', qtyText: '2 คู่'),
        _EditableHwRow(code: 'HW-02', name: 'ชุดมือจับล็อก', qtyText: '1 ชุด'),
      ]);
    }
  }

  @override
  void dispose() {
    _brandTitleCtrl.dispose();
    _priceBrandKeyCtrl.dispose();
    _systemTitleCtrl.dispose();
    _patternTitleCtrl.dispose();
    _patternSubtitleCtrl.dispose();
    _testWCtrl.dispose();
    _testHCtrl.dispose();
    _testAuxCtrl.dispose();
    for (final c in _cuts) {
      c.dispose();
    }
    for (final g in _glasses) {
      g.dispose();
    }
    for (final h in _hardware) {
      h.dispose();
    }
    super.dispose();
  }

  List<BrandDef> _brandsForCategory(String catId) {
    final cat = CatalogDefinitions.categories.firstWhere(
      (c) => c.id == catId,
      orElse: () => CatalogDefinitions.categories[1],
    );
    return cat.brands;
  }

  Map<String, double> _testVariables() {
    final w = double.tryParse(_testWCtrl.text.trim()) ?? 2000.0;
    final h = double.tryParse(_testHCtrl.text.trim()) ?? 2050.0;
    final aux = double.tryParse(_testAuxCtrl.text.trim()) ?? 1650.0;
    return {
      'W': w,
      'H': h,
      'W1': w,
      'W2': aux,
      'H1': aux,
      'H_t': (h - aux).clamp(100.0, h),
      'W_f': 800.0,
      'N': 2.0,
      'DripLen': w,
    };
  }

  Future<String?> _pickAndSaveImage(String prefix) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'custom_systems'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final ext =
        p.extension(xfile.path).isEmpty ? '.png' : p.extension(xfile.path);
    final dest = File(
      p.join(dir.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await dest.writeAsBytes(bytes);
    return dest.path;
  }

  void _appendFormulaToken(TextEditingController ctrl, String token) {
    if (token == 'วัดตามจริง') {
      setState(() => ctrl.text = 'วัดตามจริง');
      return;
    }
    final cur = ctrl.text.trim();
    if (cur == 'วัดตามจริง' || cur.isEmpty) {
      setState(() => ctrl.text = token);
    } else {
      setState(() => ctrl.text = '$cur $token');
    }
  }

  Future<void> _saveSystem() async {
    final patTitle = _patternTitleCtrl.text.trim();
    final bTitle = _brandTitleCtrl.text.trim();
    final sysTitle = _systemTitleCtrl.text.trim();
    if (patTitle.isEmpty) {
      showToolkitSnackBar(context, 'กรุณากรอกชื่อรูปแบบบาน');
      return;
    }
    if (_categoryId != 'cat1_market' && bTitle.isEmpty) {
      showToolkitSnackBar(context, 'กรุณากรอกชื่อแบรนด์ผู้ผลิต');
      return;
    }
    if (_cuts.isEmpty || _cuts.every((c) => c.codeCtrl.text.trim().isEmpty)) {
      showToolkitSnackBar(context, 'กรุณาเพิ่มรายการหน้าตัดอลูมิเนียมอย่างน้อย 1 รายการ');
      return;
    }

    final rawBrandKey = _categoryId == 'cat1_market'
        ? 'MARKET'
        : (_priceBrandKeyCtrl.text.trim().isEmpty
            ? 'CUSTOM'
            : _priceBrandKeyCtrl.text.trim().toUpperCase());

    final resolvedBrandId = _selectedBrandPreset != '__NEW__'
        ? _selectedBrandPreset
        : (widget.initialSystem?.brandId.startsWith('cust_brand_') == true
            ? widget.initialSystem!.brandId
            : 'cust_brand_${rawBrandKey.toLowerCase()}');

    final cutSpecs = <CutPieceSpec>[];
    final profImgMap = <String, String>{};
    final priceBatch = <CustomPriceOverride>[];

    for (final c in _cuts) {
      final code = c.codeCtrl.text.trim();
      if (code.isEmpty) continue;
      final name =
          c.nameCtrl.text.trim().isEmpty ? code : c.nameCtrl.text.trim();
      final qty = (int.tryParse(c.qtyCtrl.text.trim()) ?? 1).clamp(1, 999);
      final stockMm =
          (int.tryParse(c.stockMmCtrl.text.trim()) ?? 6400).clamp(1000, 12000);
      final formula = c.formulaCtrl.text.trim().isEmpty
          ? 'วัดตามจริง'
          : c.formulaCtrl.text.trim();

      cutSpecs.add(
        CutPieceSpec(
          section: c.section,
          code: code,
          name: name,
          stockMm: stockMm,
          qty: qty,
          qtyText: '$qty ชิ้น',
          angle: c.angle,
          formula: formula,
        ),
      );

      if (c.imagePath != null && c.imagePath!.trim().isNotEmpty) {
        profImgMap[code] = c.imagePath!.trim();
      }

      final initPrice = double.tryParse(c.initPriceCtrl.text.trim());
      if (initPrice != null && initPrice > 0) {
        for (final col in const [
          'ตัวดิบ MILL',
          'ชุบขาว',
          'อบขาว (8911)',
          'อบดำ (8816)',
          'เทาซาฮาร่า (8820)',
          'ลายไม้ (15656 / 15659)',
        ]) {
          priceBatch.add(
            CustomPriceOverride(
              skuKey: '$rawBrandKey|$code|1.2 มม.|$col',
              brand: rawBrandKey,
              code: code,
              name: name,
              thickness: '1.2 มม.',
              color: col,
              stockM: stockMm / 1000.0,
              pricePerBar: initPrice,
            ),
          );
        }
      }
    }

    final glassSpecs = <GlassPieceSpec>[];
    for (final g in _glasses) {
      final name = g.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final qty = (int.tryParse(g.qtyCtrl.text.trim()) ?? 1).clamp(1, 99);
      glassSpecs.add(
        GlassPieceSpec(
          name: name,
          qty: qty,
          qtyText: '$qty แผ่น',
          siteCut: g.siteCut,
          wFormula: g.siteCut ? '' : g.wFormulaCtrl.text.trim(),
          hFormula: g.siteCut ? '' : g.hFormulaCtrl.text.trim(),
        ),
      );
    }

    final hwSpecs = <HardwareItemSpec>[];
    for (final h in _hardware) {
      final name = h.nameCtrl.text.trim();
      final code = h.codeCtrl.text.trim();
      if (name.isEmpty && code.isEmpty) continue;
      final effName = name.isEmpty ? code : name;
      final qt = h.qtyTextCtrl.text.trim().isEmpty
          ? '1 ชิ้น'
          : h.qtyTextCtrl.text.trim();
      hwSpecs.add(
        HardwareItemSpec(
          code: code,
          name: effName,
          qtyText: qt,
        ),
      );

      final uPrice = double.tryParse(h.unitPriceCtrl.text.trim());
      if (uPrice != null && uPrice >= 0) {
        final m = RegExp(r'^(\d+)\s*(.*)$').firstMatch(qt);
        final unit = m != null && m.group(2)!.trim().isNotEmpty
            ? m.group(2)!.trim()
            : 'ชิ้น';
        final rKey = code.isNotEmpty ? 'HW|$code|$effName' : 'HW||$effName';
        await AppDatabase.instance.upsertCustomMaterialRate(
          CustomMaterialRateOverride(
            rateKey: rKey,
            category: 'HARDWARE',
            code: code,
            name: effName,
            unit: unit,
            price: uPrice,
          ),
        );
      }
    }

    if (priceBatch.isNotEmpty) {
      await AppDatabase.instance.upsertCustomPricesBatch(priceBatch);
    }

    final tableMode = _dimMode == 'CORNER_W1W2'
        ? InputTableMode.cornerW1W2
        : InputTableMode.standardMultiRow;
    final auxType = _dimMode == 'WH_H1'
        ? AuxDimensionType.refHeightH1
        : AuxDimensionType.none;
    final auxLabel = _dimMode == 'WH_H1' ? 'สูงบานหลัก H1 (มม.)' : null;

    final now = DateTime.now();
    final savedSys = CustomProfileSystem(
      id: _systemId,
      categoryId: _categoryId,
      brandId: resolvedBrandId,
      brandTitle: _categoryId == 'cat1_market' ? 'ชุดตลาด' : bTitle,
      priceBrandKey: rawBrandKey,
      brandLogoPath: _brandLogoPath,
      systemTitle: sysTitle.isEmpty ? 'ชุดโปรไฟล์' : sysTitle,
      patternTitle: patTitle,
      patternSubtitle: _patternSubtitleCtrl.text.trim(),
      patternImagePath: _patternImagePath,
      tableMode: tableMode,
      auxType: auxType,
      auxLabel: auxLabel,
      formulaTable: VerifiedFormulaTable(
        key: _systemId,
        header: patTitle,
        cuts: cutSpecs,
        glasses: glassSpecs,
        hardware: hwSpecs,
      ),
      profileImagePaths: profImgMap,
      enabled: widget.initialSystem?.enabled ?? true,
      createdAt: widget.initialSystem?.createdAt ?? now,
      updatedAt: now,
    );

    await AppDatabase.instance.upsertCustomProfileSystem(savedSys);
    await SeedRepository.instance.reloadCustomSystems();

    if (!mounted) return;
    showToolkitSnackBar(
      context,
      'บันทึกชุดโปรไฟล์ "$patTitle" พร้อมซิงก์เข้าเมนูคำนวณแล้ว',
    );
    Navigator.pop(context, savedSys);
  }

  @override
  Widget build(BuildContext context) {
    final vars = _testVariables();
    final catBrands = _brandsForCategory(_categoryId);
    final isNew = widget.initialSystem == null || widget.isNewClone;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'เพิ่มชุดโปรไฟล์ใหม่' : 'แก้ไขชุดโปรไฟล์'),
        actions: [
          TextButton.icon(
            onPressed: _saveSystem,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: const Text(
              'บันทึก',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // 1. Metadata & Brand Section
          _sectionCard(
            title: '1. หมวดระบบ แบรนด์ และชื่อชุดโปรไฟล์',
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('cat_$_categoryId'),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'หมวดระบบหลัก *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (int i = 0; i < CatalogDefinitions.categories.length; i++)
                    DropdownMenuItem(
                      value: CatalogDefinitions.categories[i].id,
                      child: Text(
                        '${i + 1}. ${CatalogDefinitions.categories[i].title}',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _categoryId = v;
                    _selectedBrandPreset = '__NEW__';
                    if (v == 'cat1_market') {
                      _brandTitleCtrl.text = 'ชุดตลาด';
                      _priceBrandKeyCtrl.text = 'MARKET';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_categoryId != 'cat1_market') ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('bpreset_${_categoryId}_$_selectedBrandPreset'),
                  initialValue: catBrands.any((b) => b.id == _selectedBrandPreset)
                      ? _selectedBrandPreset
                      : '__NEW__',
                  decoration: const InputDecoration(
                    labelText: 'แบรนด์ผู้ผลิต (เลือกของเดิม หรือสร้างแบรนด์ใหม่)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '__NEW__',
                      child: Text(
                        '+ สร้างแบรนด์ใหม่ / พิมพ์ชื่อเอง',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ToolkitColors.royalBlue,
                        ),
                      ),
                    ),
                    ...catBrands.map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          b.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedBrandPreset = v;
                      if (v != '__NEW__') {
                        final b = catBrands.firstWhere((e) => e.id == v);
                        _brandTitleCtrl.text = b.title;
                        _priceBrandKeyCtrl.text = b.priceBrandKey;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _brandTitleCtrl,
                        enabled: _selectedBrandPreset == '__NEW__',
                        decoration: const InputDecoration(
                          labelText: 'ชื่อแบรนด์ผู้ผลิต *',
                          hintText: 'เช่น THAI METAL, ALUMET',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _priceBrandKeyCtrl,
                        enabled: _selectedBrandPreset == '__NEW__',
                        decoration: const InputDecoration(
                          labelText: 'รหัสกลุ่มราคา *',
                          hintText: 'เช่น ALUMET',
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
                controller: _systemTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อระบบย่อย / ซีรีส์โปรไฟล์ *',
                  hintText: 'เช่น บานเลื่อนรุ่นใหม่ 2027, บานกระทุ้ง',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _patternTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อรูปแบบบาน *',
                  hintText: 'เช่น บานเลื่อนสลับ 2 บาน, ประตูบานเปิดคู่',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _patternSubtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'คำอธิบายเพิ่มเติม (ไม่บังคับ)',
                  hintText: 'เช่น เฟรม 100 มม. ร่องยูโร',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('dim_$_dimMode'),
                initialValue: _dimMode,
                decoration: const InputDecoration(
                  labelText: 'ตัวแปรขนาดช่องเปิดที่ใช้ในสูตร',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'WH',
                    child: Text('กว้าง W × สูง H (มาตรฐาน)',
                        style: TextStyle(fontSize: 13.5)),
                  ),
                  DropdownMenuItem(
                    value: 'WH_H1',
                    child: Text('กว้าง W × สูงรวม H × สูงบานหลัก H1 (มีช่องแสง)',
                        style: TextStyle(fontSize: 13.5)),
                  ),
                  DropdownMenuItem(
                    value: 'CORNER_W1W2',
                    child: Text('กว้างซ้าย W1 × กว้างขวา W2 × สูง H (เข้ามุม)',
                        style: TextStyle(fontSize: 13.5)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _dimMode = v);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final p = await _pickAndSaveImage('pattern');
                      if (p != null && mounted) {
                        setState(() => _patternImagePath = p);
                      }
                    },
                    icon: const Icon(Icons.image_outlined, size: 17),
                    label: Text(
                      _patternImagePath != null
                          ? 'เปลี่ยนรูปผังบาน ✓'
                          : 'แนบรูปผังบาน',
                    ),
                  ),
                  if (_selectedBrandPreset == '__NEW__' &&
                      _categoryId != 'cat1_market')
                    OutlinedButton.icon(
                      onPressed: () async {
                        final p = await _pickAndSaveImage('brand');
                        if (p != null && mounted) {
                          setState(() => _brandLogoPath = p);
                        }
                      },
                      icon: const Icon(Icons.shield_outlined, size: 17),
                      label: Text(
                        _brandLogoPath != null
                            ? 'เปลี่ยนโลโก้แบรนด์ ✓'
                            : 'แนบโลโก้แบรนด์',
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Live Formula Test Bench
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ToolkitColors.softBlueBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ToolkitColors.royalBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 18,
                      color: ToolkitColors.royalBlue,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ขนาดจำลองสำหรับเช็กผลลัพธ์สูตรตัดแบบสด (มม.)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ToolkitColors.deepNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _testWCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _dimMode == 'CORNER_W1W2'
                              ? 'กว้าง W1'
                              : 'กว้าง W',
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _testHCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'สูง H',
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_dimMode != 'WH') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _testAuxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                _dimMode == 'CORNER_W1W2' ? 'กว้าง W2' : 'สูง H1',
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Aluminum Profile Cuts Section
          _sectionCard(
            title: '2. ตารางสูตรตัดเส้นอลูมิเนียม (${_cuts.length} รายการ)',
            trailing: FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _cuts.add(
                    _EditableCutRow(
                      section: 'กรอบบาน',
                      code: 'NEW-${100 + _cuts.length + 1}',
                      name: 'ชิ้นส่วนใหม่',
                      formula: 'W',
                      qty: 1,
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่มรหัสเส้น'),
            ),
            children: [
              for (int i = 0; i < _cuts.length; i++) ...[
                if (i > 0) const Divider(height: 22),
                _buildCutEditorItem(i, _cuts[i], vars),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 4. Glass Formulas Section
          _sectionCard(
            title: '3. ตารางสูตรตัดกระจก (${_glasses.length} รายการ)',
            trailing: FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _glasses.add(
                    _EditableGlassRow(
                      name: 'กระจกชุดที่ ${_glasses.length + 1}',
                      qty: 1,
                      siteCut: false,
                      wFormula: 'W - 80',
                      hFormula: 'H - 140',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่มกระจก'),
            ),
            children: [
              if (_glasses.isEmpty)
                const Text(
                  'ไม่มีรายการกระจก (กด + เพิ่มกระจก หากชุดนี้ใช้กระจก)',
                  style: TextStyle(
                      fontSize: 12.5, color: ToolkitColors.slateMuted),
                ),
              for (int i = 0; i < _glasses.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _buildGlassEditorItem(i, _glasses[i], vars),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 5. Hardware Section
          _sectionCard(
            title: '4. รายการอุปกรณ์ประกอบ (${_hardware.length} รายการ)',
            trailing: FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _hardware.add(
                    _EditableHwRow(
                      code: '',
                      name: 'อุปกรณ์ประกอบ',
                      qtyText: '1 ชุด',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่มอุปกรณ์'),
            ),
            children: [
              if (_hardware.isEmpty)
                const Text(
                  'ไม่มีรายการอุปกรณ์ประกอบ',
                  style: TextStyle(
                      fontSize: 12.5, color: ToolkitColors.slateMuted),
                ),
              for (int i = 0; i < _hardware.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                _buildHwEditorItem(i, _hardware[i]),
              ],
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ToolkitColors.royalBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saveSystem,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'บันทึกชุดโปรไฟล์ใหม่เข้าสู่ระบบคำนวณ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutEditorItem(
    int idx,
    _EditableCutRow row,
    Map<String, double> vars,
  ) {
    final evalRes = FormulaEvaluator.evaluate(row.formulaCtrl.text, vars);
    final rawFormula = row.formulaCtrl.text.trim();
    final isExplicitSite = rawFormula.contains('วัดตามจริง');
    final previewText = isExplicitSite
        ? 'วัดตัดหน้างาน'
        : (!evalRes.isSiteMeasured && evalRes.valueMm != null
            ? 'ระยะตัดสด = ${FormulaEvaluator.formatMm(evalRes.valueMm!)} มม.'
            : 'ตรวจสอบตัวแปรในสูตร');
    final previewOk =
        isExplicitSite || (!evalRes.isSiteMeasured && evalRes.valueMm != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ToolkitColors.softBlueBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'เส้นที่ #${idx + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ToolkitColors.royalBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                previewText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: previewOk
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'ลบรายการนี้',
              onPressed: _cuts.length <= 1
                  ? null
                  : () {
                      setState(() {
                        final removed = _cuts.removeAt(idx);
                        removed.dispose();
                      });
                    },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'รหัสหน้าตัด *',
                  hintText: 'เช่น SS-X110',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อชิ้นส่วน *',
                  hintText: 'เช่น เฟรมบน',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: row.formulaCtrl,
          decoration: const InputDecoration(
            labelText: 'สูตรคำนวณระยะตัด (มม.) *',
            hintText: 'เช่น W - 76 หรือ (W / 2) + 12 หรือ วัดตามจริง',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tok in [
                'W',
                'H',
                if (_dimMode == 'WH_H1') 'H1',
                if (_dimMode == 'CORNER_W1W2') ...['W1', 'W2'],
                '+',
                '-',
                '/ 2',
                '/ 3',
                '/ 4',
                '(',
                ')',
                'วัดตามจริง',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(
                      tok,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => _appendFormulaToken(row.formulaCtrl, tok),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวน/ชุด',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.stockMmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เส้นยาว (มม.)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('ang_${idx}_${row.angle}'),
                initialValue: const [
                  '90° / 90°',
                  '45° / 45°',
                  '45° / 90°',
                ].contains(row.angle)
                    ? row.angle
                    : '90° / 90°',
                decoration: const InputDecoration(
                  labelText: 'มุมตัด',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '90° / 90°',
                    child: Text('90°/90°',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: '45° / 45°',
                    child: Text('45°/45°',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: '45° / 90°',
                    child: Text('45°/90°',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => row.angle = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('sec_${idx}_${row.section}'),
                initialValue: const [
                  'วงกบ / เฟรม',
                  'กรอบบาน',
                  'คิ้ว / อุปกรณ์เส้น',
                ].contains(row.section)
                    ? row.section
                    : 'วงกบ / เฟรม',
                decoration: const InputDecoration(
                  labelText: 'กลุ่มชิ้นส่วน',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'วงกบ / เฟรม',
                    child: Text('วงกบ / เฟรม',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5)),
                  ),
                  DropdownMenuItem(
                    value: 'กรอบบาน',
                    child: Text('กรอบบาน',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5)),
                  ),
                  DropdownMenuItem(
                    value: 'คิ้ว / อุปกรณ์เส้น',
                    child: Text('คิ้ว / เสริม',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => row.section = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.initPriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ราคาเส้น (฿)',
                  hintText: '1650',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onPressed: () async {
                final p = await _pickAndSaveImage('prof_$idx');
                if (p != null && mounted) {
                  setState(() => row.imagePath = p);
                }
              },
              icon: Icon(
                row.imagePath != null
                    ? Icons.check_circle_rounded
                    : Icons.add_photo_alternate_outlined,
                size: 16,
              ),
              label: Text(
                row.imagePath != null ? 'มีรูป' : 'รูปตัด',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassEditorItem(
    int idx,
    _EditableGlassRow row,
    Map<String, double> vars,
  ) {
    final gw = FormulaEvaluator.evaluateNumber(row.wFormulaCtrl.text, vars);
    final gh = FormulaEvaluator.evaluateNumber(row.hFormulaCtrl.text, vars);
    final preview = row.siteCut
        ? 'วัดตัดหน้างาน'
        : '${FormulaEvaluator.formatMm(gw)} × ${FormulaEvaluator.formatMm(gh)} มม.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'กระจกรายการที่ #${idx + 1} · $preview',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.royalBlue,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  final r = _glasses.removeAt(idx);
                  r.dispose();
                });
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อรายการกระจก',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: row.qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวนแผ่น',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'วัดตัดกระจกตามหน้างานจริง',
            style: TextStyle(fontSize: 13),
          ),
          value: row.siteCut,
          onChanged: (v) => setState(() => row.siteCut = v),
        ),
        if (!row.siteCut)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.wFormulaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'สูตรกว้างกระจก (มม.)',
                    hintText: '(W / 2) - 68',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.hFormulaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'สูตรสูงกระจก (มม.)',
                    hintText: 'H - 140',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHwEditorItem(int idx, _EditableHwRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'รหัสอุปกรณ์',
                  hintText: 'เช่น HD-929',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่ออุปกรณ์ *',
                  hintText: 'เช่น ล้อบานเลื่อนคู่',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  final r = _hardware.removeAt(idx);
                  r.dispose();
                });
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.qtyTextCtrl,
                decoration: const InputDecoration(
                  labelText: 'จำนวนต่อชุด',
                  hintText: 'เช่น 2 คู่, 1 ชุด',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.unitPriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ราคาต่อหน่วย (฿)',
                  hintText: 'เช่น 135',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: ToolkitColors.slateDark,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }
}
