import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../data/catalog_definitions.dart';
import '../data/seed_repository.dart';
import '../engine/bin_packer.dart';
import '../engine/formula_evaluator.dart';
import '../engine/material_mutation_helper.dart';
import '../engine/pricing_engine.dart';
import '../engine/quotation_spec_formatter.dart';
import '../engine/thai_baht_text.dart';
import '../models/app_models.dart';
import '../pdf/project_pdf.dart';
import '../pdf/quotation_pdf.dart';
import 'alupro_thumbnail_widgets.dart';
import 'catalog_and_input_screens.dart';
import 'result_and_pricing_screens.dart';
import 'theme_tokens.dart';

final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'en_US');

// =============================================================================
// Save Calculation Modal (บันทึกงานเข้าโปรเจกต์ — Exact 3 Fields)
// =============================================================================
class SaveToProjectDialog extends StatefulWidget {
  final CalculationOutput output;
  final List<SizeRowInput> sizeRows;
  final int? preselectedProjectId;

  const SaveToProjectDialog({
    super.key,
    required this.output,
    required this.sizeRows,
    this.preselectedProjectId,
  });

  @override
  State<SaveToProjectDialog> createState() => _SaveToProjectDialogState();
}

class _SaveToProjectDialogState extends State<SaveToProjectDialog> {
  List<SavedProject> _projects = [];
  int? _destProjectId; // null == สร้างโปรเจกต์ใหม่
  late final TextEditingController _nameCtrl;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: '${widget.output.patternTitle} (${widget.output.totalSetsCount} ชุด)',
    );
    _destProjectId = widget.preselectedProjectId;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await AppDatabase.instance.listProjects();
    if (!mounted) return;
    setState(() {
      _projects = list;
      if (_destProjectId != null &&
          !_projects.any((p) => p.id == _destProjectId)) {
        _destProjectId = null;
      }
      if (_destProjectId != null) {
        final sel = _projects.firstWhere((p) => p.id == _destProjectId);
        _nameCtrl.text = sel.name;
        _noteCtrl.text = sel.note;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndOpen() async {
    int projectId;
    if (_destProjectId == null) {
      final pName = _nameCtrl.text.trim();
      if (pName.isEmpty) {
        showToolkitSnackBar(context, 'กรุณากรอกชื่อโปรเจกต์ / ลูกค้า');
        return;
      }
      projectId = await AppDatabase.instance.createProject(
        name: pName,
        note: _noteCtrl.text.trim(),
      );
    } else {
      projectId = _destProjectId!;
      if (_noteCtrl.text.trim().isNotEmpty) {
        await AppDatabase.instance.updateProjectMeta(
          projectId,
          name: _nameCtrl.text.trim().isEmpty
              ? 'โปรเจกต์'
              : _nameCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );
      }
    }

    final item = SavedProjectItem(
      projectId: projectId,
      sortIndex: 0,
      brandTitle: widget.output.brandTitle,
      priceBrandKey: widget.output.priceBrandKey,
      systemTitle: widget.output.systemTitle,
      patternId: widget.output.patternId,
      patternTitle: widget.output.patternTitle,
      selectedOptions: widget.output.selectedOptions,
      sizeRows: widget.sizeRows,
      evaluatedSets: widget.output.sets,
      hardware: widget.output.hardware,
    );
    await AppDatabase.instance.addProjectItem(item);

    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop(); // close modal
    nav.push(
      MaterialPageRoute(builder: (_) => const MyProjectsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('บันทึกเข้าแฟ้มงานโปรเจกต์'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _destProjectId,
                    decoration: const InputDecoration(
                      labelText: 'ปลายทาง',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('สร้างโปรเจกต์ใหม่'),
                      ),
                      ..._projects.map(
                        (p) => DropdownMenuItem<int?>(
                          value: p.id,
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _destProjectId = v;
                        if (v == null) {
                          _nameCtrl.text =
                              '${widget.output.patternTitle} (${widget.output.totalSetsCount} ชุด)';
                          _noteCtrl.clear();
                        } else {
                          final sel =
                              _projects.firstWhere((e) => e.id == v);
                          _nameCtrl.text = sel.name;
                          _noteCtrl.text = sel.note;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    enabled: _destProjectId == null,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อโปรเจกต์ / ลูกค้า *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'โน้ตเพิ่มเติม',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ToolkitColors.royalBlue,
          ),
          onPressed: _loading ? null : _saveAndOpen,
          child: const Text('บันทึกและเปิดแฟ้มงาน'),
        ),
      ],
    );
  }
}

// =============================================================================
// My Projects Screen (โปรเจกต์ของฉัน — Immediate Trash Delete 1:1)
// =============================================================================
class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  List<SavedProject> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AppDatabase.instance.listProjects();
    if (!mounted) return;
    setState(() {
      _projects = list;
      _loading = false;
    });
  }

  Future<void> _deleteImmediately(SavedProject p) async {
    if (p.id == null) return;
    await AppDatabase.instance.deleteProject(p.id!);
    if (!mounted) return;
    showToolkitSnackBar(context, 'ลบโปรเจกต์ "${p.name}" แล้ว');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โปรเจกต์ของฉัน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_off_outlined,
                          size: 54, color: ToolkitColors.slateMuted),
                      SizedBox(height: 12),
                      Text(
                        'ยังไม่มีโปรเจกต์ที่บันทึกไว้',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final p = _projects[i];
                    final totalSets =
                        p.items.fold(0, (s, it) => s + it.totalUnits);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(projectId: p.id!),
                          ),
                        );
                        _reload();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ToolkitColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ToolkitColors.softBlueBg,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: ToolkitColors.royalBlue,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: ToolkitColors.slateDark,
                                    ),
                                  ),
                                  if (p.note.trim().isNotEmpty)
                                    Text(
                                      p.note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: ToolkitColors.slateMuted,
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${p.items.length} รายการ (รวม $totalSets ชุด) · อัปเดต ${DateFormat('dd/MM/yyyy HH:mm').format(p.updatedAt)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ToolkitColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'ลบโปรเจกต์',
                              onPressed: () => _deleteImmediately(p),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// =============================================================================
// Project Detail Screen (4 AppBar Icons + 4 Accordions + 4-Option PDF Dialog)
// =============================================================================
class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  SavedProject? _project;
  List<SavedQuotation> _quotations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final proj = await AppDatabase.instance.getProject(widget.projectId);
    final qts =
        await AppDatabase.instance.listQuotationsForProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = proj;
      _quotations = qts;
      _loading = false;
    });
  }

  Future<void> _editProjectDialog() async {
    final proj = _project;
    if (proj == null) return;
    final nameCtrl = TextEditingController(text: proj.name);
    final noteCtrl = TextEditingController(text: proj.note);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขข้อมูลโปรเจกต์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อโปรเจกต์ / ลูกค้า *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'โน้ตเพิ่มเติม',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await AppDatabase.instance.updateProjectMeta(
                proj.id!,
                name: nameCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _editItemMetaDialog(SavedProjectItem item) async {
    final refCtrl = TextEditingController(text: item.refCode);
    final locCtrl = TextEditingController(text: item.installLocation);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลขอ้างอิง & ตำแหน่งติดตั้ง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'รหัสอ้างอิงบาน (เช่น D1, W1)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(
                labelText: 'ตำแหน่งติดตั้ง (เช่น ชั้น 1 ห้องรับแขก)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              await AppDatabase.instance.updateProjectItemMeta(
                item.id!,
                refCode: refCtrl.text.trim(),
                installLocation: locCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditPatternAndSpecs(SavedProjectItem item) async {
    final found = CatalogDefinitions.findPatternById(item.patternId);
    if (found != null) {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SizeAndSpecInputScreen(
            brandTitle: item.brandTitle,
            priceBrandKey: item.priceBrandKey,
            systemTitle: item.systemTitle,
            pattern: found.pattern,
            targetProjectId: item.projectId,
            editingProjectItem: item,
          ),
        ),
      );
      if (updated == true) _reload();
      return;
    }

    // Fallback if pattern came from a deleted custom system: let user pick replacement pattern while keeping sizes
    final picked = await Navigator.push<PickedPatternSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectScreen(pickMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SizeAndSpecInputScreen(
          brandTitle: picked.brandTitle,
          priceBrandKey: picked.priceBrandKey,
          systemTitle: picked.systemTitle,
          pattern: picked.pattern,
          targetProjectId: item.projectId,
          editingProjectItem: item,
        ),
      ),
    );
    if (updated == true) _reload();
  }

  Future<void> _applyItemQuantityUpdate(
    SavedProjectItem item,
    List<int> nextRowQtys,
  ) async {
    if (item.id == null) return;
    final updated =
        MaterialMutationHelper.updateProjectItemQuantities(item, nextRowQtys);
    await AppDatabase.instance.updateProjectItemFull(updated);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openItemQtyDialog(SavedProjectItem item) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ProjectItemQtyDialog(item: item),
    );
    if (result == null || !mounted) return;
    await _applyItemQuantityUpdate(item, result);
  }

  Future<void> _showExportPdfDialog() async {
    final proj = _project;
    if (proj == null) return;
    bool s1 = true, s2 = true, s3 = true, s4 = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('เลือกหมวดเอกสารโครงการ PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: s1,
                title: const Text('1. สรุปโครงการ'),
                onChanged: (v) => setModal(() => s1 = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: s2,
                title: const Text('2. ใบสั่งตัดแยกตามรายการ'),
                onChanged: (v) => setModal(() => s2 = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: s3,
                title: const Text('3. ใบคำนวณบริหารเส้น (A4 แนวนอน)'),
                onChanged: (v) => setModal(() => s3 = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: s4,
                title: const Text('4. รายการวัสดุรวม'),
                onChanged: (v) => setModal(() => s4 = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: (!s1 && !s2 && !s3 && !s4)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final opts = ProjectPdfOptions(
                        includeSummary: s1,
                        includeCutList: s2,
                        includeBarOpt: s3,
                        includeBom: s4,
                      );
                      final bytes =
                          await ProjectPdfGenerator.generate(proj, opts);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewAndShareScreen(
                            title: 'เอกสารโครงการ Toolkit',
                            fileName: ProjectPdfGenerator.suggestedFileName(),
                            pdfBytes: bytes,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('สร้าง PDF'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proj = _project;
    final packedGroups = proj == null
        ? <ProfileBarGroup>[]
        : BinPacker.packProjectItems(proj.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(proj?.name ?? 'รายละเอียดโปรเจกต์'),
        actions: [
          // 1. ทำราคา
          IconButton(
            tooltip: 'ทำราคาและออกใบเสนอราคา',
            onPressed: proj == null
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectPricingScreen(project: proj),
                      ),
                    );
                    _reload();
                  },
            icon: const Icon(Icons.request_quote_outlined),
          ),
          // 2. ประวัติใบเสนอราคา (Enabled ONLY when saved quotations > 0!)
          IconButton(
            tooltip: 'ประวัติใบเสนอราคา',
            onPressed: (_quotations.isEmpty || proj == null)
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            QuotationHistoryScreen(projectId: proj.id!),
                      ),
                    );
                    _reload();
                  },
            icon: const Icon(Icons.history_rounded),
          ),
          // 3. แก้ไขชื่อโปรเจกต์
          IconButton(
            tooltip: 'แก้ไขชื่อโปรเจกต์',
            onPressed: proj == null ? null : _editProjectDialog,
            icon: const Icon(Icons.edit_outlined),
          ),
          // 4. ส่งออก PDF
          IconButton(
            tooltip: 'ส่งออก PDF โครงการ',
            onPressed: proj == null ? null : _showExportPdfDialog,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading || proj == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Accordion 1: รายการบานในโครงการ
                _accordionCard(
                  initiallyExpanded: true,
                  title: '1. รายการบานในโครงการ (${proj.items.length} รายการ)',
                  children: [
                    ...List.generate(proj.items.length, (idx) {
                      final it = proj.items[idx];
                      final tag = it.displayOrderTag(idx + 1);
                      final patImg = AluproImageRegistry.instance
                          .resolvePatternAsset(it.patternId);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ToolkitColors.bgScaffold,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ToolkitColors.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ToolkitColors.royalBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '[$tag]',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (patImg != null) ...[
                                  const SizedBox(height: 6),
                                  AluproThumbnail(
                                    assetPath: patImg,
                                    width: 58,
                                    height: 42,
                                    showZoomBadge: true,
                                    zoomTitle:
                                        '[$tag] ${it.brandTitle} · ${it.patternTitle}',
                                    zoomSubtitle:
                                        'ขนาด: ${it.sizeSummaryText} · รวม ${it.totalUnits} ชุด',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${it.brandTitle} · ${it.patternTitle}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'ขนาด: ${it.sizeSummaryText}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: ToolkitColors.slateBody,
                                    ),
                                  ),
                                  if (it.installLocation.isNotEmpty)
                                    Text(
                                      'ตำแหน่งติดตั้ง: ${it.installLocation}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ToolkitColors.royalBlue,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  // Inline Quantity Stepper (กำหนดจำนวนชุดก่อนทำใบเสนอราคา)
                                  Row(
                                    children: [
                                      const Text(
                                        'จำนวน:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: ToolkitColors.slateMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _CompactQtyStepper(
                                        minusKey: ValueKey(
                                            'proj_qty_minus_${it.id ?? idx}'),
                                        valueKey: ValueKey(
                                            'proj_qty_val_${it.id ?? idx}'),
                                        plusKey: ValueKey(
                                            'proj_qty_plus_${it.id ?? idx}'),
                                        qty: it.totalUnits,
                                        onMinus: it.sizeRows.length == 1 &&
                                                it.totalUnits > 1
                                            ? () => _applyItemQuantityUpdate(
                                                  it,
                                                  [it.sizeRows.first.qty - 1],
                                                )
                                            : (it.sizeRows.length > 1
                                                ? () => _openItemQtyDialog(it)
                                                : null),
                                        onPlus: it.sizeRows.length == 1
                                            ? () => _applyItemQuantityUpdate(
                                                  it,
                                                  [it.sizeRows.first.qty + 1],
                                                )
                                            : () => _openItemQtyDialog(it),
                                        onTapNumber: () =>
                                            _openItemQtyDialog(it),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                            'proj_edit_pattern_${it.id ?? idx}'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor:
                                              ToolkitColors.deepNavy,
                                          side: BorderSide(
                                            color: ToolkitColors.deepNavy
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _openEditPatternAndSpecs(it),
                                        icon: const Icon(
                                          Icons.tune_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'แก้ไขแบบ / ขนาด',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                            'proj_edit_mat_${it.id ?? idx}'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor:
                                              ToolkitColors.royalBlue,
                                          side: BorderSide(
                                            color: ToolkitColors.royalBlue
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final updated =
                                              await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ResultScreen(
                                                output: MaterialMutationHelper
                                                    .fromSavedProjectItem(it),
                                                sizeRows: it.sizeRows,
                                                editingProjectItem: it,
                                              ),
                                            ),
                                          );
                                          if (updated == true) _reload();
                                        },
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'แก้ไข / เปลี่ยนวัสดุ',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'pattern') {
                                  await _openEditPatternAndSpecs(it);
                                } else if (action == 'qty') {
                                  await _openItemQtyDialog(it);
                                } else if (action == 'materials') {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ResultScreen(
                                        output: MaterialMutationHelper
                                            .fromSavedProjectItem(it),
                                        sizeRows: it.sizeRows,
                                        editingProjectItem: it,
                                      ),
                                    ),
                                  );
                                  if (updated == true) _reload();
                                } else if (action == 'meta') {
                                  await _editItemMetaDialog(it);
                                } else if (action == 'del') {
                                  await AppDatabase.instance
                                      .deleteProjectItem(it.id!, proj.id!);
                                  _reload();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'pattern',
                                  child: Text('แก้ไขแบบ / ขนาด / เปลี่ยนโปรไฟล์'),
                                ),
                                PopupMenuItem(
                                  value: 'qty',
                                  child: Text('ปรับจำนวนชุด'),
                                ),
                                PopupMenuItem(
                                  value: 'materials',
                                  child: Text('แก้ไข / เปลี่ยนชิ้นส่วนวัสดุ'),
                                ),
                                PopupMenuItem(
                                  value: 'meta',
                                  child: Text('แก้ไขเลขอ้างอิง / ตำแหน่งติดตั้ง'),
                                ),
                                PopupMenuItem(
                                  value: 'del',
                                  child: Text('ลบรายการนี้'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategorySelectScreen(
                                targetProjectId: proj.id,
                              ),
                            ),
                          );
                          _reload();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('เพิ่มงานคำนวณ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Accordion 2: ใบสั่งตัดแยกตามรายการ
                _accordionCard(
                  title: '2. ใบสั่งตัดแยกตามรายการ',
                  children: List.generate(proj.items.length, (idx) {
                    final it = proj.items[idx];
                    final tag = it.displayOrderTag(idx + 1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[$tag] ${it.brandTitle} — ${it.patternTitle}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: ToolkitColors.royalBlue,
                            ),
                          ),
                          ...it.evaluatedSets.expand((s) => s.cuts).map(
                                (c) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c.code} · ${c.name}',
                                          style:
                                              const TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                      Text(
                                        c.isSiteMeasured
                                            ? 'วัดตามจริง · ${c.totalQty} ชิ้น'
                                            : '${FormulaEvaluator.formatMm(c.lengthMm ?? 0)} มม. × ${c.totalQty} ชิ้น',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          const Divider(),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Accordion 3: การบริหารเส้นรวมทั้งโครงการ (Cross-Item Bin-Packing)
                _accordionCard(
                  title: '3. การบริหารเส้นรวมทั้งโครงการ (${packedGroups.fold(0, (s, g) => s + g.totalBars)} เส้น)',
                  children: packedGroups
                      .map((grp) => ProfileBarGroupCard(group: grp))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // Accordion 4: รายการวัสดุรวม
                _accordionCard(
                  title: '4. รายการวัสดุรวม',
                  children: [
                    ...packedGroups.map(
                      (g) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${g.brand} · ${g.code} (${g.combinedNames})'),
                        trailing: Text(
                          '${g.totalBars} เส้น',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _accordionCard({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: ToolkitColors.slateDark,
          ),
        ),
        children: children,
      ),
    );
  }
}

// =============================================================================
// Project Pricing Screen -> สร้างใบเสนอราคา (Checks Shop Info First!)
// =============================================================================
class ProjectPricingScreen extends StatefulWidget {
  final SavedProject project;

  const ProjectPricingScreen({super.key, required this.project});

  @override
  State<ProjectPricingScreen> createState() => _ProjectPricingScreenState();
}

class _ProjectPricingScreenState extends State<ProjectPricingScreen> {
  late SavedProject _workingProject;
  PricingSummary? _latestSummary;
  List<ProjectItemPricingBreakdown> _latestItemBreakdowns = const [];
  late List<ProfileBarGroup> _packedGroups;
  late List<EvaluatedGlassItem> _projectGlasses;
  late List<AggregatedHardwareItem> _projectHardware;
  late double _projectOpeningAreaSqM;
  bool _showQtyPanel = false;
  bool _useItemOwnSpecs = true;

  @override
  void initState() {
    super.initState();
    _workingProject = widget.project;
    _recomputeProjectAggregates();
  }

  void _recomputeProjectAggregates() {
    _packedGroups = BinPacker.packProjectItems(_workingProject.items);
    _projectGlasses = _workingProject.items
        .expand((it) => it.evaluatedSets.expand((s) => s.glasses))
        .toList();
    _projectHardware = _mergeProjectHardware(_workingProject.items);
    _projectOpeningAreaSqM = _workingProject.totalOpeningAreaSqM;
  }

  Future<void> _updatePricingItemSpec(
    int idx,
    SavedProjectItem updatedItem,
  ) async {
    if (updatedItem.id != null) {
      await AppDatabase.instance.updateProjectItemFull(updatedItem);
    }
    if (!mounted) return;
    final nextItems = List<SavedProjectItem>.from(_workingProject.items);
    nextItems[idx] = updatedItem;
    setState(() {
      _workingProject = SavedProject(
        id: _workingProject.id,
        name: _workingProject.name,
        note: _workingProject.note,
        createdAt: _workingProject.createdAt,
        updatedAt: DateTime.now(),
        items: nextItems,
      );
      _recomputeProjectAggregates();
    });
    showToolkitSnackBar(
      context,
      'อัปเดตสเปกวัสดุเฉพาะรายการ ${updatedItem.displayOrderTag(idx + 1)} แล้ว',
    );
  }

  Future<void> _updatePricingItemQty(int idx, List<int> nextRowQtys) async {
    final oldItem = _workingProject.items[idx];
    final updatedItem = MaterialMutationHelper.updateProjectItemQuantities(
      oldItem,
      nextRowQtys,
    );
    if (updatedItem.id != null) {
      await AppDatabase.instance.updateProjectItemFull(updatedItem);
    }
    if (!mounted) return;
    final nextItems = List<SavedProjectItem>.from(_workingProject.items);
    nextItems[idx] = updatedItem;
    setState(() {
      _workingProject = SavedProject(
        id: _workingProject.id,
        name: _workingProject.name,
        note: _workingProject.note,
        createdAt: _workingProject.createdAt,
        updatedAt: DateTime.now(),
        items: nextItems,
      );
      _recomputeProjectAggregates();
    });
  }

  static List<AggregatedHardwareItem> _mergeProjectHardware(
    List<SavedProjectItem> items,
  ) {
    final map = <String, AggregatedHardwareItem>{};
    for (final it in items) {
      for (final h in it.hardware) {
        final key = '${h.code}|${h.name}|${h.unitOrNote}';
        final ex = map[key];
        if (ex == null) {
          map[key] = h;
        } else if (ex.decimalQty != null && h.decimalQty != null) {
          map[key] = AggregatedHardwareItem(
            code: ex.code,
            name: ex.name,
            decimalQty: PricingEngine.round2(ex.decimalQty! + h.decimalQty!),
            unitOrNote: ex.unitOrNote,
          );
        } else if (ex.numericQty != null && h.numericQty != null) {
          map[key] = AggregatedHardwareItem(
            code: ex.code,
            name: ex.name,
            numericQty: ex.numericQty! + h.numericQty!,
            unitOrNote: ex.unitOrNote,
          );
        }
      }
    }
    return map.values.toList();
  }

  Future<void> _onTapCreateQuotation() async {
    final shop = await AppDatabase.instance.getShopInfo();
    if (!mounted) return;
    if (!shop.isConfigured) {
      // Exact Verbatim SnackBar #1 from Toolkit v0.1.7!
      showToolkitSnackBar(context, 'กรุณาบันทึกข้อมูลร้านก่อนออกใบเสนอราคา');
      return;
    }
    final s = _latestSummary;
    final itemMatCosts =
        _latestItemBreakdowns.length == _workingProject.items.length
            ? _latestItemBreakdowns
                .map((b) => b.allocatedMaterialCost)
                .toList()
            : null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationBuilderScreen(
          project: _workingProject,
          shopInfo: shop,
          estimatedAluminumCost: s?.totalCost ?? 0.0,
          itemMaterialCosts: itemMatCosts,
          initialAluminumThickness: s?.selectedThickness,
          initialAluminumColor: s?.selectedColor,
          initialGlassKey: (s?.includeGlass ?? true) ? s?.selectedGlassKey : null,
          useItemOwnMaterialSpecs: _useItemOwnSpecs,
          openingAreaSqM: _projectOpeningAreaSqM,
          initialProfitPercent: s?.profitPercent,
          initialProfitBaseMode: s?.profitBaseMode,
          initialLaborMode: s?.laborMode,
          initialLaborRate: s?.laborRate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestedPrice = _latestSummary?.suggestedSellingPrice ?? 0.0;
    final totalSets =
        _workingProject.items.fold<int>(0, (s, it) => s + it.totalUnits);
    return Scaffold(
      appBar: AppBar(title: Text('ทำราคาโปรเจกต์ · ${_workingProject.name}')),
      body: Column(
        children: [
          // Quick Quantity Adjuster Bar before Quotation
          if (_workingProject.items.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(bottom: BorderSide(color: ToolkitColors.cardBorder)),
              ),
              child: Column(
                children: [
                  InkWell(
                    key: const ValueKey('proj_pricing_qty_toggle'),
                    onTap: () => setState(() => _showQtyPanel = !_showQtyPanel),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined,
                              size: 17, color: ToolkitColors.royalBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'รายการบาน ${_workingProject.items.length} รายการ · รวม $totalSets ชุด (แตะปรับจำนวนชุดก่อนทำใบเสนอราคา)',
                              style: const TextStyle(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w700,
                                color: ToolkitColors.deepNavy,
                              ),
                            ),
                          ),
                          Icon(
                            _showQtyPanel
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: ToolkitColors.royalBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showQtyPanel)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      color: ToolkitColors.bgScaffold,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                        itemCount: _workingProject.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, idx) {
                          final it = _workingProject.items[idx];
                          final tag = it.displayOrderTag(idx + 1);
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '[$tag] ${it.patternTitle} (${it.brandTitle})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CompactQtyStepper(
                                minusKey: ValueKey('pp_qty_minus_$idx'),
                                valueKey: ValueKey('pp_qty_val_$idx'),
                                plusKey: ValueKey('pp_qty_plus_$idx'),
                                qty: it.totalUnits,
                                onMinus: it.sizeRows.length == 1 &&
                                        it.totalUnits > 1
                                    ? () => _updatePricingItemQty(
                                          idx,
                                          [it.sizeRows.first.qty - 1],
                                        )
                                    : (it.sizeRows.length > 1
                                        ? () async {
                                            final res = await showDialog<
                                                List<int>>(
                                              context: context,
                                              builder: (_) =>
                                                  _ProjectItemQtyDialog(
                                                      item: it),
                                            );
                                            if (res != null) {
                                              await _updatePricingItemQty(
                                                  idx, res);
                                            }
                                          }
                                        : null),
                                onPlus: it.sizeRows.length == 1
                                    ? () => _updatePricingItemQty(
                                          idx,
                                          [it.sizeRows.first.qty + 1],
                                        )
                                    : () async {
                                        final res =
                                            await showDialog<List<int>>(
                                          context: context,
                                          builder: (_) =>
                                              _ProjectItemQtyDialog(item: it),
                                        );
                                        if (res != null) {
                                          await _updatePricingItemQty(idx, res);
                                        }
                                      },
                                onTapNumber: () async {
                                  final res = await showDialog<List<int>>(
                                    context: context,
                                    builder: (_) =>
                                        _ProjectItemQtyDialog(item: it),
                                  );
                                  if (res != null) {
                                    await _updatePricingItemQty(idx, res);
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: PricingWorkspaceWidget(
              barGroups: _packedGroups,
              glasses: _projectGlasses,
              openingAreaSqM: _projectOpeningAreaSqM,
              fallbackOpeningAreaSqM: _projectOpeningAreaSqM * 0.88,
              hardware: _projectHardware,
              projectItems: _workingProject.items,
              projectId: _workingProject.id,
              onUpdateProjectItemSpec: _updatePricingItemSpec,
              onUseItemOwnSpecsChanged: (v) {
                _useItemOwnSpecs = v;
              },
              onProjectItemBreakdownsChanged: (b) {
                _latestItemBreakdowns = b;
              },
              onSummaryChanged: (s) {
                final prev = _latestSummary;
                final changed = prev == null ||
                    (prev.totalCost - s.totalCost).abs() > 0.005 ||
                    (prev.suggestedSellingPrice - s.suggestedSellingPrice)
                            .abs() >
                        0.005 ||
                    (prev.profitPercent - s.profitPercent).abs() > 0.005 ||
                    (prev.laborRate - s.laborRate).abs() > 0.005 ||
                    prev.laborMode != s.laborMode ||
                    prev.profitBaseMode != s.profitBaseMode ||
                    prev.selectedThickness != s.selectedThickness ||
                    prev.selectedColor != s.selectedColor ||
                    prev.selectedGlassKey != s.selectedGlassKey ||
                    prev.includeGlass != s.includeGlass;
                if (changed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _latestSummary = s);
                    }
                  });
                }
              },
            ),
          ),
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
                    backgroundColor: ToolkitColors.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _onTapCreateQuotation,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    suggestedPrice > 0
                        ? 'สร้างใบเสนอราคา · ฿${_moneyFmt.format(suggestedPrice)}'
                        : 'สร้างใบเสนอราคา',
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
}

// =============================================================================
// Quotation Builder Screen (All Verbatim Validations + Itemized & Lump Sum)
// =============================================================================
class _EditableQtLine {
  final SavedProjectItem? sourceItem;
  final String? patternId;
  final String? imageAssetPath;
  final TextEditingController labelCtrl;
  final TextEditingController subtitleCtrl;
  final String sizeText;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final double baseMaterialCost;
  final int initialQty;
  bool confirmed;
  bool editingSpec;
  bool userCustomizedSubtitle;
  bool userEditedPrice;

  _EditableQtLine({
    this.sourceItem,
    this.patternId,
    this.imageAssetPath,
    required String label,
    required String subtitle,
    required this.sizeText,
    required int qty,
    required double suggestedUnitPrice,
    this.baseMaterialCost = 0.0,
    bool initialConfirmed = true,
    bool initialCustomizedSubtitle = false,
    bool initialEditedPrice = false,
  })  : initialQty = qty.clamp(1, 9999),
        labelCtrl = TextEditingController(text: label),
        subtitleCtrl = TextEditingController(text: subtitle),
        qtyCtrl = TextEditingController(text: qty.clamp(1, 9999).toString()),
        unitPriceCtrl = TextEditingController(
            text: suggestedUnitPrice.toStringAsFixed(2)),
        confirmed = initialConfirmed,
        editingSpec = false,
        userCustomizedSubtitle = initialCustomizedSubtitle,
        userEditedPrice = initialEditedPrice;

  String get label => labelCtrl.text.trim();
  String get subtitle => subtitleCtrl.text.trim();
  int get qty => (int.tryParse(qtyCtrl.text.trim()) ?? 1).clamp(1, 9999);
  double get unitPrice => double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
  double get lineTotal => PricingEngine.round2(unitPrice * qty);

  double get effectiveMaterialCost {
    if (baseMaterialCost <= 0) return 0.0;
    final orig = initialQty > 0 ? initialQty : 1;
    return PricingEngine.round2((baseMaterialCost / orig) * qty);
  }

  double get effectiveAreaSqM {
    final srcArea = sourceItem?.totalOpeningAreaSqM ?? 0.0;
    if (srcArea <= 0) return 0.0;
    final orig = initialQty > 0 ? initialQty : 1;
    return (srcArea / orig) * qty;
  }

  void setQty(int next) {
    qtyCtrl.text = next.clamp(1, 9999).toString();
  }

  void dispose() {
    labelCtrl.dispose();
    subtitleCtrl.dispose();
    qtyCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

class QuotationBuilderScreen extends StatefulWidget {
  final SavedProject project;
  final ShopInfo shopInfo;
  final double estimatedAluminumCost;
  final List<double>? itemMaterialCosts;
  final String? initialAluminumThickness;
  final String? initialAluminumColor;
  final String? initialGlassKey;
  final bool useItemOwnMaterialSpecs;
  final double? openingAreaSqM;
  final double? initialProfitPercent;
  final ProfitBaseMode? initialProfitBaseMode;
  final LaborCostMode? initialLaborMode;
  final double? initialLaborRate;
  final SavedQuotation? editingQuotation;

  const QuotationBuilderScreen({
    super.key,
    required this.project,
    required this.shopInfo,
    required this.estimatedAluminumCost,
    this.itemMaterialCosts,
    this.initialAluminumThickness,
    this.initialAluminumColor,
    this.initialGlassKey,
    this.useItemOwnMaterialSpecs = true,
    this.openingAreaSqM,
    this.initialProfitPercent,
    this.initialProfitBaseMode,
    this.initialLaborMode,
    this.initialLaborRate,
    this.editingQuotation,
  });

  @override
  State<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends State<QuotationBuilderScreen> {
  late SavedProject _workingProject;
  String? _mode; // Defaults to ITEMIZED so every selectable control starts ready
  bool _includeImages = true;
  late final TextEditingController _docTitleCtrl;
  late final TextEditingController _qtNumCtrl;
  late final TextEditingController _issueDateCtrl;
  late final TextEditingController _validUntilCtrl;
  late final TextEditingController _custNameCtrl;
  late final TextEditingController _custAddrCtrl;
  late final TextEditingController _custContactCtrl;
  late final TextEditingController _projNameCtrl;
  late final TextEditingController _projLocCtrl;
  late final TextEditingController _lumpSumCtrl;
  late final TextEditingController _discountCtrl;
  bool _discountIsPercent = false;
  bool _vatEnabled = false;
  late final TextEditingController _payTermsCtrl;
  late final TextEditingController _leadTimeCtrl;
  late final TextEditingController _warrantyCtrl;
  late final TextEditingController _remarksCtrl;

  // Live Profit % & Labor Cost Controls
  late double _openingAreaSqM;
  late double _profitPct;
  late ProfitBaseMode _profitBaseMode;
  late LaborCostMode _laborMode;
  late double _laborRate;
  late final TextEditingController _profitCtrl;
  late final TextEditingController _laborCtrl;
  bool _lumpSumManuallyEdited = false;

  // Global Quotation Material Spec Controls (default 'ตามรายการ' when items carry own specs!)
  late String _globalAluThick;
  late String _globalAluColor;
  String _globalGlassType = 'ตามรายการ';
  String _globalGlassThick = 'ตามรายการ';
  final TextEditingController _customGlassNoteCtrl = TextEditingController();

  final List<_EditableQtLine> _lines = [];

  static String _fmtNumInput(double v) {
    if ((v - v.roundToDouble()).abs() < 0.005) {
      return v.round().toString();
    }
    return v.toStringAsFixed(2);
  }

  SellingPriceBreakdown get _breakdown => PricingEngine.computeSellingBreakdown(
        materialCost: widget.estimatedAluminumCost,
        openingAreaSqM: _openingAreaSqM,
        laborMode: _laborMode,
        laborRate: _laborRate,
        profitPercent: _profitPct,
        profitBaseMode: _profitBaseMode,
      );

  @override
  void initState() {
    super.initState();
    _workingProject = widget.project;
    final edit = widget.editingQuotation;
    final now = DateTime.now();
    final rand6 = (100000 + Random().nextInt(900000)).toString();

    _mode = edit?.mode ?? 'ITEMIZED';
    _includeImages = edit != null
        ? edit.lines.any((l) => (l.imageAssetPath ?? '').trim().isNotEmpty)
        : true;
    _docTitleCtrl = TextEditingController(
      text: edit != null
          ? edit.docTitle
          : (widget.shopInfo.defaultDocTitle.isEmpty
              ? 'ใบเสนอราคา'
              : widget.shopInfo.defaultDocTitle),
    );
    _qtNumCtrl = TextEditingController(
      text: edit != null
          ? edit.qtNumber
          : 'QT-${DateFormat('yyyyMMdd').format(now)}-$rand6',
    );
    _issueDateCtrl = TextEditingController(
      text: edit != null
          ? edit.issueDate
          : DateFormat('dd/MM/yyyy').format(now),
    );
    _validUntilCtrl = TextEditingController(
      text: edit != null
          ? edit.validUntil
          : DateFormat('dd/MM/yyyy')
              .format(now.add(const Duration(days: 30))),
    );
    _custNameCtrl =
        TextEditingController(text: edit?.customerName ?? _workingProject.name);
    _custAddrCtrl = TextEditingController(text: edit?.customerAddress ?? '');
    _custContactCtrl = TextEditingController(text: edit?.customerContact ?? '');
    _projNameCtrl =
        TextEditingController(text: edit?.projectName ?? _workingProject.name);
    _projLocCtrl = TextEditingController(text: edit?.projectLocation ?? '');
    _discountCtrl = TextEditingController(
      text: edit != null ? _fmtNumInput(edit.discount) : '0',
    );
    _vatEnabled = edit?.vatEnabled ?? false;
    _payTermsCtrl = TextEditingController(
      text: edit != null
          ? edit.paymentTerms
          : 'มัดจำ 50% ก่อนผลิต ส่วนที่เหลือชำระวันส่งมอบ/ติดตั้งเสร็จ',
    );
    _leadTimeCtrl = TextEditingController(
      text: edit != null
          ? edit.leadTime
          : '15–20 วันทำการ หลังยืนยันแบบและรับมัดจำ',
    );
    _warrantyCtrl = TextEditingController(
      text: edit != null
          ? edit.warranty
          : 'รับประกันงานติดตั้งและอุปกรณ์ 1 ปี',
    );
    _remarksCtrl = TextEditingController(text: edit?.remarks ?? '');

    _openingAreaSqM =
        widget.openingAreaSqM ?? _workingProject.totalOpeningAreaSqM;
    _profitPct = (widget.initialProfitPercent ?? 20.0).clamp(0.0, 200.0);
    _profitBaseMode =
        widget.initialProfitBaseMode ?? ProfitBaseMode.materialOnly;
    _laborMode = widget.initialLaborMode ?? LaborCostMode.perSqM;
    _laborRate = (widget.initialLaborRate ?? 0.0).clamp(0.0, 10000000.0);
    _profitCtrl = TextEditingController(text: _fmtNumInput(_profitPct));
    _laborCtrl = TextEditingController(text: _fmtNumInput(_laborRate));

    // Preserve each item's own saved material specs when present so items never
    // overwrite each other; fall back to project-level initial specs for legacy items.
    final hasAnyItemOwnSpec = _workingProject.items.any((it) {
      final o = it.selectedOptions;
      final c = (o['pricing_alu_color'] ?? o['spec_alu_color'] ?? '').trim();
      final g = (o['pricing_glass_key'] ?? o['spec_glass_type'] ?? '').trim();
      return (c.isNotEmpty && c != 'ไม่ระบุ' && c != 'ตามรายการ') ||
          (g.isNotEmpty && g != 'ไม่ระบุ' && g != 'ตามรายการ');
    });

    if (widget.useItemOwnMaterialSpecs && hasAnyItemOwnSpec) {
      _globalAluThick = 'ตามรายการ';
      _globalAluColor = 'ตามรายการ';
      _globalGlassType = 'ตามรายการ';
      _globalGlassThick = 'ตามรายการ';
    } else {
      final initThick = widget.initialAluminumThickness?.trim() ?? '';
      _globalAluThick =
          QuotationSpecFormatter.aluminumThicknessChoices.contains(initThick)
              ? initThick
              : 'ตามรายการ';
      final firstBrand = _workingProject.items.isNotEmpty
          ? _workingProject.items.first.priceBrandKey
          : null;
      _globalAluColor = QuotationSpecFormatter.normalizePricingColorForQuotation(
        widget.initialAluminumColor,
        brandKey: firstBrand,
      );
      if ((widget.initialGlassKey ?? '').trim().isNotEmpty) {
        final parsedGlass =
            QuotationSpecFormatter.parseGlassRateKey(widget.initialGlassKey);
        if (parsedGlass.glassType != 'ไม่ระบุ') {
          _globalGlassType = parsedGlass.glassType;
        }
        if (parsedGlass.glassThickness != 'ไม่ระบุ') {
          _globalGlassThick = parsedGlass.glassThickness;
        }
      }
    }

    if (edit != null) {
      for (int i = 0; i < edit.lines.length; i++) {
        final e = edit.lines[i];
        final matchedSrc =
            i < _workingProject.items.length ? _workingProject.items[i] : null;
        final patId = e.patternId ?? matchedSrc?.patternId;
        final imgPath = e.imageAssetPath ??
            (patId != null
                ? AluproImageRegistry.instance.resolvePatternAsset(patId)
                : null);
        _lines.add(
          _EditableQtLine(
            sourceItem: matchedSrc,
            patternId: patId,
            imageAssetPath: imgPath,
            label: e.label,
            subtitle: e.subtitle,
            sizeText: e.sizeText,
            qty: e.qty,
            suggestedUnitPrice: e.unitPrice,
            initialConfirmed: true,
            initialCustomizedSubtitle: true,
            initialEditedPrice: true,
          ),
        );
      }
      _lumpSumCtrl =
          TextEditingController(text: edit.lumpSumPrice.toStringAsFixed(2));
      _lumpSumManuallyEdited = true;
      return;
    }

    _populateLinesFromProject(_workingProject, isInit: true);
    _loadShopQuotationDefaults();
  }

  Future<void> _loadShopQuotationDefaults() async {
    if (widget.editingQuotation != null) return;
    final defs = await AppDatabase.instance.getShopSelectionDefaults();
    if (!mounted) return;
    setState(() {
      if (defs.qtMode == 'ITEMIZED' || defs.qtMode == 'LUMP_SUM') {
        _mode = defs.qtMode!;
      }
      if (defs.qtIncludeImages != null) {
        _includeImages = defs.qtIncludeImages!;
      }
      if (defs.qtVatEnabled != null) {
        _vatEnabled = defs.qtVatEnabled!;
      }
      if (defs.qtPaymentTerms != null && defs.qtPaymentTerms!.trim().isNotEmpty) {
        _payTermsCtrl.text = defs.qtPaymentTerms!;
      }
      if (defs.qtLeadTime != null && defs.qtLeadTime!.trim().isNotEmpty) {
        _leadTimeCtrl.text = defs.qtLeadTime!;
      }
      if (defs.qtWarranty != null && defs.qtWarranty!.trim().isNotEmpty) {
        _warrantyCtrl.text = defs.qtWarranty!;
      }
    });
  }

  Future<void> _saveQuotationDefaultsAsShopDefault() async {
    final cur = await AppDatabase.instance.getShopSelectionDefaults();
    await AppDatabase.instance.saveShopSelectionDefaults(
      cur.copyWith(
        qtMode: _mode,
        qtIncludeImages: _includeImages,
        qtVatEnabled: _vatEnabled,
        qtPaymentTerms: _payTermsCtrl.text.trim(),
        qtLeadTime: _leadTimeCtrl.text.trim(),
        qtWarranty: _warrantyCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    showToolkitSnackBar(
      context,
      'บันทึกค่าตั้งต้นใบเสนอราคา (รูปแบบ/รูปภาพ/VAT/เงื่อนไข) เป็นค่าเริ่มต้นร้านแล้ว',
    );
  }

  List<double> _resolveItemMaterialCosts(
    SavedProject proj, {
    required bool isInit,
  }) {
    if (proj.items.isEmpty) return const [];
    final passed = widget.itemMaterialCosts;
    if (isInit &&
        passed != null &&
        passed.length == proj.items.length &&
        passed.every((c) => c > 0)) {
      return passed;
    }
    if (widget.estimatedAluminumCost <= 0) {
      return List<double>.filled(proj.items.length, 0.0);
    }
    // Fallback: estimate relative per-model material cost weights directly from
    // catalog prices so even callers without explicit itemMaterialCosts split
    // prices accurately across different series (e.g. ICONIQ vs Smart X vs NEX).
    final catalog = SeedRepository.instance.allCatalogPrices;
    if (catalog.isEmpty) {
      return List<double>.filled(proj.items.length, 0.0);
    }
    final dummySummary = PricingSummary(
      mode: PricingMode.actualLength,
      wastePercent: 20.0,
      selectedThickness: (widget.initialAluminumThickness ?? '').isNotEmpty
          ? widget.initialAluminumThickness!
          : '1.2 มม.',
      selectedColor: (widget.initialAluminumColor ?? '').isNotEmpty
          ? widget.initialAluminumColor!
          : 'อบดำ (8816)',
      lines: const [],
      matchedCount: 0,
      totalCount: 0,
      aluminumCost: widget.estimatedAluminumCost,
      totalCost: widget.estimatedAluminumCost,
      openingAreaSqM: _openingAreaSqM,
      laborMode: _laborMode,
      laborRate: _laborRate,
      profitPercent: _profitPct,
      profitBaseMode: _profitBaseMode,
      suggestedSellingPrice: _breakdown.suggestedSellingPrice,
    );
    final evaluated = PricingEngine.evaluateProjectItems(
      items: proj.items,
      projectSummary: dummySummary,
      ormCatalog: catalog,
      customOverrides: const {},
      hardwareCatalog: SeedRepository.instance.hardwareRates,
    );
    return evaluated.map((b) => b.allocatedMaterialCost).toList();
  }

  void _populateLinesFromProject(
    SavedProject proj, {
    bool isInit = false,
  }) {
    if (!isInit) {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
    }
    _openingAreaSqM = isInit
        ? (widget.openingAreaSqM ?? proj.totalOpeningAreaSqM)
        : proj.totalOpeningAreaSqM;

    final initBreakdown = _breakdown;
    final hasCost = widget.estimatedAluminumCost > 0;
    final itemMatCosts = _resolveItemMaterialCosts(proj, isInit: isInit);
    final unitPrices = hasCost
        ? PricingEngine.allocateQuotationLineUnitPrices(
            items: List.generate(
              proj.items.length,
              (i) => (
                materialCost: i < itemMatCosts.length ? itemMatCosts[i] : 0.0,
                areaSqM: proj.items[i].totalOpeningAreaSqM,
                qty: proj.items[i].totalUnits,
              ),
            ),
            laborMode: _laborMode,
            laborRate: _laborRate,
            profitPercent: _profitPct,
            profitBaseMode: _profitBaseMode,
            targetTotal: initBreakdown.suggestedSellingPrice,
          )
        : List<double>.filled(proj.items.length, 3500.0);

    double sumInit = 0.0;
    for (int i = 0; i < proj.items.length; i++) {
      final it = proj.items[i];
      final imgPath =
          AluproImageRegistry.instance.resolvePatternAsset(it.patternId);
      final line = _EditableQtLine(
        sourceItem: it,
        patternId: it.patternId,
        imageAssetPath: imgPath,
        label: QuotationSpecFormatter.formatLineTitle(it, i + 1),
        subtitle: QuotationSpecFormatter.buildItemSpecSubtitle(
          item: it,
          globalAluThickness: _globalAluThick,
          globalAluColor: _globalAluColor,
          globalGlassType: _globalGlassType,
          globalGlassThickness: _globalGlassThick,
        ),
        sizeText: QuotationSpecFormatter.formatQuotationSize(it),
        qty: it.totalUnits,
        suggestedUnitPrice: unitPrices[i],
        baseMaterialCost: i < itemMatCosts.length ? itemMatCosts[i] : 0.0,
        initialConfirmed: true,
      );
      sumInit += line.lineTotal;
      _lines.add(line);
    }
    final initLump =
        hasCost ? initBreakdown.suggestedSellingPrice : PricingEngine.round2(sumInit);
    if (isInit) {
      _lumpSumCtrl = TextEditingController(text: initLump.toStringAsFixed(2));
    } else {
      _lumpSumCtrl.text = initLump.toStringAsFixed(2);
      _lumpSumManuallyEdited = false;
    }
  }

  Future<void> _openEditProjectPatterns() async {
    final pid = _workingProject.id;
    if (pid == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: pid)),
    );
    await _syncLatestFromProject(showSnack: true);
  }

  Future<void> _syncLatestFromProject({bool showSnack = true}) async {
    final pid = _workingProject.id;
    if (pid == null) return;
    final latest = await AppDatabase.instance.getProject(pid);
    if (latest == null || !mounted) return;
    setState(() {
      _workingProject = latest;
      _populateLinesFromProject(latest, isInit: false);
    });
    if (showSnack) {
      showToolkitSnackBar(
        context,
        'อัปเดตรายการบานและจำนวนชุดล่าสุดจากโปรเจกต์แล้ว (${latest.items.length} รายการ)',
      );
    }
  }

  void _applyMarkupToSellingPrices({bool forceAll = false}) {
    if (widget.estimatedAluminumCost <= 0) return;
    final target = _breakdown.suggestedSellingPrice;
    final unitPrices = PricingEngine.allocateQuotationLineUnitPrices(
      items: _lines
          .map((l) => (
                materialCost: l.effectiveMaterialCost,
                areaSqM: l.effectiveAreaSqM,
                qty: l.qty,
              ))
          .toList(),
      laborMode: _laborMode,
      laborRate: _laborRate,
      profitPercent: _profitPct,
      profitBaseMode: _profitBaseMode,
      targetTotal: target,
    );
    for (int i = 0; i < _lines.length; i++) {
      final ln = _lines[i];
      if (forceAll || !ln.userEditedPrice) {
        final nextText = unitPrices[i].toStringAsFixed(2);
        if (ln.unitPriceCtrl.text != nextText) {
          ln.unitPriceCtrl.text = nextText;
          ln.confirmed = false;
        }
        if (forceAll) ln.userEditedPrice = false;
      }
    }
    if (forceAll || !_lumpSumManuallyEdited) {
      _lumpSumCtrl.text = target.toStringAsFixed(2);
      if (forceAll) _lumpSumManuallyEdited = false;
    }
  }

  void _syncSubtitlesFromSpec({bool forceResetAll = false}) {
    for (final ln in _lines) {
      if (ln.sourceItem == null) continue;
      if (forceResetAll) {
        ln.userCustomizedSubtitle = false;
      }
      if (!ln.userCustomizedSubtitle) {
        ln.subtitleCtrl.text = QuotationSpecFormatter.buildItemSpecSubtitle(
          item: ln.sourceItem!,
          globalAluThickness: _globalAluThick,
          globalAluColor: _globalAluColor,
          globalGlassType: _globalGlassType,
          globalGlassThickness: _globalGlassThick,
          customGlassNote: _customGlassNoteCtrl.text,
        );
      }
    }
  }

  @override
  void dispose() {
    _docTitleCtrl.dispose();
    _qtNumCtrl.dispose();
    _issueDateCtrl.dispose();
    _validUntilCtrl.dispose();
    _custNameCtrl.dispose();
    _custAddrCtrl.dispose();
    _custContactCtrl.dispose();
    _projNameCtrl.dispose();
    _projLocCtrl.dispose();
    _lumpSumCtrl.dispose();
    _discountCtrl.dispose();
    _payTermsCtrl.dispose();
    _leadTimeCtrl.dispose();
    _warrantyCtrl.dispose();
    _remarksCtrl.dispose();
    _customGlassNoteCtrl.dispose();
    _profitCtrl.dispose();
    _laborCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    if (_mode == 'LUMP_SUM') {
      return double.tryParse(_lumpSumCtrl.text.trim()) ?? 0.0;
    }
    return PricingEngine.round2(
      _lines.fold(0.0, (s, l) => s + l.lineTotal),
    );
  }

  double get _discount {
    final raw = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    if (raw <= 0) return 0.0;
    if (_discountIsPercent) {
      final pct = raw.clamp(0.0, 100.0);
      return PricingEngine.round2(_subtotal * (pct / 100.0));
    }
    return raw.clamp(0.0, _subtotal);
  }

  double get _afterDiscount =>
      PricingEngine.round2((_subtotal - _discount).clamp(0.0, double.infinity));

  double get _vatAmount =>
      _vatEnabled ? PricingEngine.round2(_afterDiscount * 0.07) : 0.0;

  double get _netTotal => PricingEngine.round2(_afterDiscount + _vatAmount);

  Future<void> _onPreviewQuotation() async {
    // Validation #3: Must choose quotation mode first!
    if (_mode == null) {
      showToolkitSnackBar(context, 'กรุณาเลือกประเภทใบเสนอราคา');
      return;
    }

    // Validation #4: In ITEMIZED mode, every line must have confirmation checked!
    if (_mode == 'ITEMIZED' && _lines.any((l) => !l.confirmed)) {
      showToolkitSnackBar(context, 'กรุณาตรวจราคาและยืนยันราคาขายทุกบรรทัด');
      return;
    }

    final qtNo = _qtNumCtrl.text.trim();
    if (qtNo.isEmpty) {
      showToolkitSnackBar(context, 'กรุณากรอกเลขที่ใบเสนอราคา');
      return;
    }

    // Validation #5: Duplicate quotation number check (allows keeping own qt_number when editing!)
    final used = await AppDatabase.instance.isQuotationNumberUsed(
      qtNo,
      excludeQuotationId: widget.editingQuotation?.id,
    );
    if (!mounted) return;
    if (used) {
      showToolkitSnackBar(
        context,
        'เลขที่ใบเสนอราคานี้ถูกใช้งานแล้ว กรุณาใช้เลขที่ใหม่',
      );
      return;
    }

    final draft = SavedQuotation(
      id: widget.editingQuotation?.id,
      projectId: _workingProject.id!,
      qtNumber: qtNo,
      docTitle: _docTitleCtrl.text.trim().isEmpty
          ? 'ใบเสนอราคา'
          : _docTitleCtrl.text.trim(),
      mode: _mode!,
      issueDate: _issueDateCtrl.text.trim(),
      validUntil: _validUntilCtrl.text.trim(),
      customerName: _custNameCtrl.text.trim(),
      customerAddress: _custAddrCtrl.text.trim(),
      customerContact: _custContactCtrl.text.trim(),
      projectName: _projNameCtrl.text.trim(),
      projectLocation: _projLocCtrl.text.trim(),
      lines: _lines
          .map(
            (l) => QuotationLineEntry(
              label: l.label,
              subtitle: l.subtitle,
              sizeText: l.sizeText,
              qty: l.qty,
              unitPrice: l.unitPrice,
              confirmed: l.confirmed,
              patternId: l.patternId,
              imageAssetPath: _includeImages ? l.imageAssetPath : null,
            ),
          )
          .toList(),
      lumpSumPrice: double.tryParse(_lumpSumCtrl.text.trim()) ?? 0.0,
      discount: _discount,
      vatEnabled: _vatEnabled,
      subtotal: _subtotal,
      vatAmount: _vatAmount,
      netTotal: _netTotal,
      paymentTerms: _payTermsCtrl.text.trim(),
      leadTime: _leadTimeCtrl.text.trim(),
      warranty: _warrantyCtrl.text.trim(),
      remarks: _remarksCtrl.text.trim(),
      revisionTag: 'ตัวอย่างก่อนบันทึก',
      createdAt: DateTime.now(),
    );

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewScreen(
          quotation: draft,
          shopInfo: widget.shopInfo,
          isAlreadySaved: false,
          editingQuotationId: widget.editingQuotation?.id,
        ),
      ),
    );
    if (widget.editingQuotation != null && updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditingQt = widget.editingQuotation != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditingQt
              ? 'แก้ไขใบเสนอราคา · ${widget.editingQuotation!.qtNumber}'
              : 'สร้างใบเสนอราคา',
        ),
        actions: [
          if (_workingProject.id != null)
            IconButton(
              tooltip: 'แก้ไขแบบบานในโปรเจกต์',
              onPressed: _openEditProjectPatterns,
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                if (isEditingQt && _workingProject.id != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ToolkitColors.softBlueBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ToolkitColors.royalBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'กำลังแก้ไขใบเสนอราคาเดิม — ปรับจำนวน ราคา สเปก หรือกลับไปแก้แบบบานโดยไม่ต้องลบได้ทันที',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ToolkitColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey(
                                  'qt_btn_edit_project_patterns'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: ToolkitColors.deepNavy,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _openEditProjectPatterns,
                              icon: const Icon(Icons.tune_rounded, size: 15),
                              label: const Text(
                                'แก้ไขแบบ / ขนาดในโปรเจกต์',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('qt_btn_sync_project_items'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: ToolkitColors.royalBlue,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _syncLatestFromProject(showSnack: true),
                              icon: const Icon(Icons.sync_rounded, size: 15),
                              label: const Text(
                                'ดึงรายการบานล่าสุดจากโปรเจกต์',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 1. ประเภทใบเสนอราคา (Unselected initially!)
                _card(
                  title: '1. เลือกประเภทใบเสนอราคา *',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const SizedBox(
                              width: double.infinity,
                              child: Text(
                                'แยกรายการ',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: _mode == 'ITEMIZED',
                            selectedColor: ToolkitColors.softBlueBg,
                            onSelected: (_) =>
                                setState(() => _mode = 'ITEMIZED'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const SizedBox(
                              width: double.infinity,
                              child: Text(
                                'เหมาทั้งโครงการ',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: _mode == 'LUMP_SUM',
                            selectedColor: ToolkitColors.softBlueBg,
                            onSelected: (_) =>
                                setState(() => _mode = 'LUMP_SUM'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. ข้อมูลเอกสาร & ลูกค้า
                _card(
                  title: '2. ข้อมูลเอกสารและลูกค้า',
                  children: [
                    _tf(_docTitleCtrl, 'หัวเอกสาร'),
                    _tf(_qtNumCtrl, 'เลขที่ใบเสนอราคา *'),
                    Row(
                      children: [
                        Expanded(child: _tf(_issueDateCtrl, 'วันที่ออกเอกสาร')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _tf(_validUntilCtrl, 'ยืนราคาถึง (+30 วัน)')),
                      ],
                    ),
                    _tf(_custNameCtrl, 'ชื่อลูกค้า / ผู้ว่าจ้าง'),
                    _tf(_custAddrCtrl, 'ที่อยู่ลูกค้า'),
                    _tf(_custContactCtrl, 'เบอร์โทรศัพท์ / ติดต่อลูกค้า'),
                    _tf(_projNameCtrl, 'ชื่อโครงการ'),
                    _tf(_projLocCtrl, 'สถานที่ติดตั้ง'),
                  ],
                ),
                const SizedBox(height: 12),

                // 2.5 สเปกโปรไฟล์ ความหนา และกระจกสำหรับแสดงในตารางใบเสนอราคา
                _buildGlobalMaterialSpecCard(),
                const SizedBox(height: 12),

                // 3. กำหนดราคาขายตามโหมด
                if (_mode == 'ITEMIZED')
                  _card(
                    title: '3. กำหนดราคาขายแยกรายการ (ยืนยันทุกบรรทัด)',
                    children: [
                      _buildProfitLaborAdjusterPanel(),
                      ...List.generate(_lines.length, (i) {
                        final ln = _lines[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ToolkitColors.bgScaffold,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ln.confirmed
                                  ? ToolkitColors.successGreen
                                  : ToolkitColors.cardBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLineSpecPreviewAndEditor(ln, i),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: ln.unitPriceCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'ราคาขาย / ชุด (บาท)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {
                                        ln.userEditedPrice = true;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'รวม ฿${_moneyFmt.format(ln.lineTotal)}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: ln.confirmed,
                                title: const Text(
                                  'ตรวจสอบและยืนยันราคาบรรทัดนี้แล้ว',
                                  style: TextStyle(fontSize: 13),
                                ),
                                onChanged: (v) => setState(
                                    () => ln.confirmed = v ?? false),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  )
                else if (_mode == 'LUMP_SUM')
                  _card(
                    title: '3. กำหนดราคาเหมารวมทั้งโครงการ',
                    children: [
                      _buildProfitLaborAdjusterPanel(),
                      TextField(
                        controller: _lumpSumCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ราคาเหมารวมทั้งโครงการ (บาท) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {
                          _lumpSumManuallyEdited = true;
                        }),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ตัวอย่างรายการและสเปกที่จะแสดงในตารางใบเสนอราคา:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ToolkitColors.slateBody,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_lines.length, (i) {
                        final ln = _lines[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: ToolkitColors.bgScaffold,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: ToolkitColors.cardBorder),
                          ),
                          child: _buildLineSpecPreviewAndEditor(ln, i),
                        );
                      }),
                    ],
                  ),

                const SizedBox(height: 12),

                // 4. ส่วนลด & VAT 7%
                _card(
                  title: '4. ส่วนลดและภาษีมูลค่าเพิ่ม',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('qt_discount_field'),
                            controller: _discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: _discountIsPercent
                                  ? 'ส่วนลด (%)'
                                  : 'ส่วนลด (บาท)',
                              suffixText: _discountIsPercent ? '%' : 'บาท',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('บาท'),
                          selected: !_discountIsPercent,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) =>
                              setState(() => _discountIsPercent = false),
                        ),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('%'),
                          selected: _discountIsPercent,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) =>
                              setState(() => _discountIsPercent = true),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _vatEnabled,
                      title: const Text('คิดภาษีมูลค่าเพิ่ม 7% (VAT)'),
                      onChanged: (v) => setState(() => _vatEnabled = v),
                    ),
                    const Divider(),
                    _totRow('รวมเป็นเงิน', '฿${_moneyFmt.format(_subtotal)}'),
                    if (_discount > 0)
                      _totRow('ส่วนลด', '-฿${_moneyFmt.format(_discount)}'),
                    if (_vatEnabled)
                      _totRow(
                          'ภาษีมูลค่าเพิ่ม 7%', '฿${_moneyFmt.format(_vatAmount)}'),
                    _totRow(
                      'ยอดสุทธิ',
                      '฿${_moneyFmt.format(_netTotal)}',
                      bold: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ตัวอักษร: (${ThaiBahtText.convert(_netTotal)})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ToolkitColors.slateMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. เงื่อนไขและหมายเหตุ
                _card(
                  title: '5. เงื่อนไขและหมายเหตุ',
                  children: [
                    _tf(_payTermsCtrl, 'เงื่อนไขการชำระเงิน (เช่น มัดจำ 50%)'),
                    _tf(_leadTimeCtrl, 'ระยะเวลาดำเนินงาน / ติดตั้ง'),
                    _tf(_warrantyCtrl, 'การรับประกันงานติดตั้ง'),
                    _tf(_remarksCtrl, 'หมายเหตุเพิ่มเติม', maxLines: 2),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Preview CTA
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
                  onPressed: _onPreviewQuotation,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text(
                    'ดูตัวอย่างใบเสนอราคา',
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

  Widget _card({required String title, required List<Widget> children}) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: ToolkitColors.slateDark,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _totRow(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: bold ? 14.5 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: bold ? 15.5 : 13.5,
              fontWeight: FontWeight.w700,
              color: bold ? ToolkitColors.royalBlue : ToolkitColors.slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLaborAdjusterPanel() {
    final bd = _breakdown;
    final totalCostPlusLabor = bd.totalCostWithLabor;
    final actualNetProfit = PricingEngine.round2(_afterDiscount - totalCostPlusLabor);
    final profitBaseForPct =
        _profitBaseMode == ProfitBaseMode.materialAndLabor
            ? totalCostPlusLabor
            : bd.materialCost;
    final actualProfitPct = profitBaseForPct > 0
        ? PricingEngine.round2((actualNetProfit / profitBaseForPct) * 100.0)
        : 0.0;
    final anyManualEdit =
        _lumpSumManuallyEdited || _lines.any((l) => l.userEditedPrice);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ToolkitColors.softBlueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ToolkitColors.royalBlue.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'ต้นทุนวัสดุ: ฿${_moneyFmt.format(bd.materialCost)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ToolkitColors.slateDark,
                ),
              ),
              if (bd.laborCost > 0)
                Text(
                  'ค่าแรง: ฿${_moneyFmt.format(bd.laborCost)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              Text(
                'ราคาขายรวม: ฿${_moneyFmt.format(_subtotal)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.royalBlue,
                ),
              ),
            ],
          ),
          if (bd.materialCost > 0) ...[
            const SizedBox(height: 3),
            Text(
              actualNetProfit >= 0
                  ? 'กำไรสุทธิจริง (หลังหักส่วนลด): ฿${_moneyFmt.format(actualNetProfit)} (${actualProfitPct.toStringAsFixed(1)}%) · ใช้ภายในร้าน ไม่แสดงบน PDF'
                  : 'คำเตือน: ราคาขายต่ำกว่าต้นทุน+ค่าแรง ฿${_moneyFmt.format(actualNetProfit.abs())}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: actualNetProfit >= 0
                    ? ToolkitColors.successGreen
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'กำไร',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 68,
                child: TextField(
                  key: const ValueKey('qt_profit_pct_field'),
                  controller: _profitCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    suffixText: '%',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed != null) {
                      setState(() {
                        _profitPct = parsed.clamp(0.0, 200.0);
                        _applyMarkupToSellingPrices();
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('qt_profit_pct_slider'),
                  value: _profitPct.clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${_profitPct.round()}%',
                  onChanged: (v) {
                    setState(() {
                      _profitPct = v.roundToDouble();
                      _profitCtrl.text = _profitPct.round().toString();
                      _applyMarkupToSellingPrices();
                    });
                  },
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [15.0, 20.0, 30.0, 40.0, 50.0].map((pct) {
              final sel = (_profitPct - pct).abs() < 0.01;
              return ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text('${pct.round()}%',
                    style: const TextStyle(fontSize: 11.5)),
                selected: sel,
                selectedColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _profitPct = pct;
                    _profitCtrl.text = pct.round().toString();
                    _applyMarkupToSellingPrices();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 6,
            children: [
              const Text(
                'ค่าแรง',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                label: const Text('บ./ตร.ม.', style: TextStyle(fontSize: 11.5)),
                selected: _laborMode == LaborCostMode.perSqM,
                selectedColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _laborMode = LaborCostMode.perSqM;
                    _applyMarkupToSellingPrices();
                  });
                },
              ),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                label: const Text('เหมา', style: TextStyle(fontSize: 11.5)),
                selected: _laborMode == LaborCostMode.flatBaht,
                selectedColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _laborMode = LaborCostMode.flatBaht;
                    _applyMarkupToSellingPrices();
                  });
                },
              ),
              ChoiceChip(
                key: const ValueKey('qt_labor_pct_chip'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                label: const Text('% ค่าของ', style: TextStyle(fontSize: 11.5)),
                selected: _laborMode == LaborCostMode.percentOfMaterial,
                selectedColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _laborMode = LaborCostMode.percentOfMaterial;
                    if (_laborRate > 200.0) {
                      _laborRate = 20.0;
                      _laborCtrl.text = '20';
                    }
                    _applyMarkupToSellingPrices();
                  });
                },
              ),
              SizedBox(
                width: 96,
                child: TextField(
                  key: const ValueKey('qt_labor_rate_field'),
                  controller: _laborCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    suffixText: _laborMode == LaborCostMode.perSqM
                        ? ' /ตร.ม.'
                        : (_laborMode == LaborCostMode.percentOfMaterial
                            ? ' %'
                            : ' ฿'),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    setState(() {
                      final rawVal =
                          (parsed != null && parsed >= 0) ? parsed : 0.0;
                      _laborRate =
                          _laborMode == LaborCostMode.percentOfMaterial
                              ? rawVal.clamp(0.0, 200.0)
                              : rawVal;
                      _applyMarkupToSellingPrices();
                    });
                  },
                ),
              ),
            ],
          ),
          if (anyManualEdit && bd.materialCost > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() => _applyMarkupToSellingPrices(forceAll: true));
                },
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text(
                  'คำนวณราคาทุกรายการใหม่ตามกำไร/ค่าแรง',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlobalMaterialSpecCard() {
    Widget specRow({
      required String title,
      required List<String> choices,
      required String current,
      required ValueChanged<String> onSelected,
      bool showAlumetSwatches = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                color: ToolkitColors.slateBody,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
                    fontSize: 12,
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
                  onSelected: (_) => onSelected(ch),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    final hasAlumetInProject = _workingProject.items
        .any((it) => it.priceBrandKey.toUpperCase() == 'ALUMET');

    return _card(
      title: 'สเปกโปรไฟล์ ความหนา และประเภทกระจก (แสดงในช่องรายการ)',
      children: [
        const Text(
          'ระบบระบุชื่อชุดโปรไฟล์ให้อัตโนมัติ เลือกความหนา สี และกระจกเพื่อให้แสดงครบในใบเสนอราคา (หรือกดแก้ไขแยกแต่ละบานได้)',
          style: TextStyle(
            fontSize: 12,
            color: ToolkitColors.slateMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        specRow(
          title: 'ความหนาอลูมิเนียม',
          choices: QuotationSpecFormatter.aluminumThicknessChoices,
          current: _globalAluThick,
          onSelected: (v) => setState(() {
            _globalAluThick = v;
            _syncSubtitlesFromSpec();
          }),
        ),
        specRow(
          title: hasAlumetInProject
              ? 'สีอลูมิเนียม ALUMET (27 รหัสสี พร้อมตัวอย่างเนื้อสี)'
              : 'สีอลูมิเนียม',
          showAlumetSwatches: hasAlumetInProject,
          choices: () {
            final list = List<String>.from(
              hasAlumetInProject
                  ? QuotationSpecFormatter.aluminumColorChoicesForBrand(
                      'ALUMET',
                      includePerItemOption: true,
                      includeUnspecifiedOption: true,
                    )
                  : QuotationSpecFormatter.aluminumColorChoices,
            );
            if (_globalAluColor.isNotEmpty && !list.contains(_globalAluColor)) {
              list.insert(1, _globalAluColor);
            }
            return list;
          }(),
          current: _globalAluColor,
          onSelected: (v) => setState(() {
            _globalAluColor = v;
            _syncSubtitlesFromSpec();
          }),
        ),
        specRow(
          title: 'ประเภทกระจก',
          choices: QuotationSpecFormatter.glassTypeChoices,
          current: _globalGlassType,
          onSelected: (v) => setState(() {
            _globalGlassType = v;
            _syncSubtitlesFromSpec();
          }),
        ),
        if (_globalGlassType != 'ไม่รวมกระจก')
          specRow(
            title: 'ความหนากระจก',
            choices: QuotationSpecFormatter.glassThicknessChoices,
            current: _globalGlassThick,
            onSelected: (v) => setState(() {
              _globalGlassThick = v;
              _syncSubtitlesFromSpec();
            }),
          ),
        TextField(
          controller: _customGlassNoteCtrl,
          decoration: const InputDecoration(
            labelText: 'ระบุสเปกกระจกเพิ่มเติมเอง (ถ้ามี เช่น ลามิเนตใส 5+5 มม.)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() => _syncSubtitlesFromSpec()),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          key: const ValueKey('qt_include_images_switch'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _includeImages,
          title: const Text(
            'แสดงรูปภาพประกอบแบบบานในใบเสนอราคา (PDF)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'เพิ่มคอลัมน์รูปแบบบานข้างรายการทั้งแบบแยกราคาและแบบเหมา',
            style: TextStyle(fontSize: 11.5),
          ),
          onChanged: (v) => setState(() => _includeImages = v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('btn_qt_save_shop_defaults'),
            onPressed: _saveQuotationDefaultsAsShopDefault,
            icon: const Icon(Icons.bookmark_added_outlined, size: 16),
            label: const Text(
              'จำค่าตั้งต้นร้าน (รูปแบบ · รูปภาพ · VAT · เงื่อนไข)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineSpecPreviewAndEditor(_EditableQtLine ln, int lineIdx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_includeImages && (ln.imageAssetPath ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => showAluproImageZoomDialog(
                    context,
                    assetPath: ln.imageAssetPath!,
                    title: ln.label.isEmpty ? 'รูปแบบบาน' : ln.label,
                    subtitle: ln.sizeText.replaceAll('\n', ', '),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ToolkitColors.cardBorder),
                    ),
                    child: buildAssetOrFileImage(
                      ln.imageAssetPath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.window_outlined,
                        size: 24,
                        color: ToolkitColors.slateMuted,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ln.label.isEmpty ? '-' : ln.label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.slateDark,
                    ),
                  ),
                  if (ln.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ln.subtitle,
                      style: const TextStyle(
                        fontSize: 12.2,
                        color: ToolkitColors.royalBlue,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'ขนาด: ${ln.sizeText.replaceAll('\n', ', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                      _CompactQtyStepper(
                        minusKey: ValueKey('qt_line_qty_minus_$lineIdx'),
                        valueKey: ValueKey('qt_line_qty_val_$lineIdx'),
                        plusKey: ValueKey('qt_line_qty_plus_$lineIdx'),
                        qty: ln.qty,
                        onMinus: ln.qty > 1
                            ? () => setState(() => ln.setQty(ln.qty - 1))
                            : null,
                        onPlus: () => setState(() => ln.setQty(ln.qty + 1)),
                        onTapNumber: () async {
                          final picked = await showDialog<int>(
                            context: context,
                            builder: (_) => _SingleIntQtyDialog(
                              title: ln.label.isEmpty
                                  ? 'กำหนดจำนวนชุด'
                                  : ln.label,
                              initialQty: ln.qty,
                            ),
                          );
                          if (picked != null && mounted) {
                            setState(() => ln.setQty(picked));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () =>
                  setState(() => ln.editingSpec = !ln.editingSpec),
              icon: Icon(
                ln.editingSpec ? Icons.expand_less : Icons.edit_note_rounded,
                size: 17,
              ),
              label: Text(
                ln.editingSpec ? 'พับเก็บ' : 'แก้สเปก',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        if (ln.editingSpec) ...[
          const SizedBox(height: 8),
          TextField(
            controller: ln.labelCtrl,
            decoration: const InputDecoration(
              labelText: 'ชื่อรายการหลัก',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ln.subtitleCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'รายละเอียดโปรไฟล์ / ความหนา / กระจก / ตำแหน่ง',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {
              ln.userCustomizedSubtitle = true;
            }),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 2-State Quotation Preview Screen (Save First -> Unlock Share / Save / Print!)
// =============================================================================
class QuotationPreviewScreen extends StatefulWidget {
  final SavedQuotation quotation;
  final ShopInfo shopInfo;
  final bool isAlreadySaved;
  final int? editingQuotationId;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.shopInfo,
    required this.isAlreadySaved,
    this.editingQuotationId,
  });

  @override
  State<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends State<QuotationPreviewScreen> {
  late SavedQuotation _qt;
  late bool _isSaved;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _qt = widget.quotation;
    _isSaved = widget.isAlreadySaved;
    _buildPdf();
  }

  Future<void> _buildPdf() async {
    final bytes = await QuotationPdfGenerator.generate(
      quotation: _qt,
      shopInfo: widget.shopInfo,
    );
    if (!mounted) return;
    setState(() => _pdfBytes = bytes);
  }

  Future<void> _saveQuotationNow({bool asNewRevision = false}) async {
    if (_isSaved) return;
    final existing = await AppDatabase.instance
        .listQuotationsForProject(_qt.projectId);
    final editId = widget.editingQuotationId;
    final updateExisting = editId != null && !asNewRevision;

    final revTag = updateExisting
        ? 'แก้ไขล่าสุด ${DateFormat('dd/MM HH:mm').format(DateTime.now())}'
        : 'R${existing.length + 1}-${DateTime.now().millisecondsSinceEpoch}';

    String finalQtNumber = _qt.qtNumber;
    if (asNewRevision && editId != null) {
      final baseNo = _qt.qtNumber.replaceAll(RegExp(r'-R\d+$'), '');
      finalQtNumber = '$baseNo-R${existing.length + 1}';
    }

    final toSave = SavedQuotation(
      id: updateExisting ? editId : null,
      projectId: _qt.projectId,
      qtNumber: finalQtNumber,
      docTitle: _qt.docTitle,
      mode: _qt.mode,
      issueDate: _qt.issueDate,
      validUntil: _qt.validUntil,
      customerName: _qt.customerName,
      customerAddress: _qt.customerAddress,
      customerContact: _qt.customerContact,
      projectName: _qt.projectName,
      projectLocation: _qt.projectLocation,
      lines: _qt.lines,
      lumpSumPrice: _qt.lumpSumPrice,
      discount: _qt.discount,
      vatEnabled: _qt.vatEnabled,
      subtotal: _qt.subtotal,
      vatAmount: _qt.vatAmount,
      netTotal: _qt.netTotal,
      paymentTerms: _qt.paymentTerms,
      leadTime: _qt.leadTime,
      warranty: _qt.warranty,
      remarks: _qt.remarks,
      revisionTag: revTag,
      createdAt: DateTime.now(),
    );

    SavedQuotation persisted;
    if (updateExisting) {
      await AppDatabase.instance.updateQuotation(toSave);
      persisted = toSave;
    } else {
      final newId = await AppDatabase.instance.saveQuotation(toSave);
      persisted = SavedQuotation(
        id: newId,
        projectId: toSave.projectId,
        qtNumber: toSave.qtNumber,
        docTitle: toSave.docTitle,
        mode: toSave.mode,
        issueDate: toSave.issueDate,
        validUntil: toSave.validUntil,
        customerName: toSave.customerName,
        customerAddress: toSave.customerAddress,
        customerContact: toSave.customerContact,
        projectName: toSave.projectName,
        projectLocation: toSave.projectLocation,
        lines: toSave.lines,
        lumpSumPrice: toSave.lumpSumPrice,
        discount: toSave.discount,
        vatEnabled: toSave.vatEnabled,
        subtotal: toSave.subtotal,
        vatAmount: toSave.vatAmount,
        netTotal: toSave.netTotal,
        paymentTerms: toSave.paymentTerms,
        leadTime: toSave.leadTime,
        warranty: toSave.warranty,
        remarks: toSave.remarks,
        revisionTag: toSave.revisionTag,
        createdAt: toSave.createdAt,
      );
    }

    final bytes = await QuotationPdfGenerator.generate(
      quotation: persisted,
      shopInfo: widget.shopInfo,
    );
    if (!mounted) return;
    setState(() {
      _qt = persisted;
      _isSaved = true;
      _pdfBytes = bytes;
    });
    showToolkitSnackBar(
      context,
      updateExisting
          ? 'อัปเดตใบเสนอราคา ${_qt.qtNumber} แล้ว'
          : 'บันทึกใบเสนอราคา ${_qt.qtNumber} แล้ว',
    );
  }

  Future<void> _openEditSavedQuotation() async {
    final proj = await AppDatabase.instance.getProject(_qt.projectId);
    if (!mounted) return;
    final targetProj = proj ??
        SavedProject(
          id: _qt.projectId,
          name: _qt.projectName,
          createdAt: _qt.createdAt,
          updatedAt: _qt.createdAt,
        );
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationBuilderScreen(
          project: targetProj,
          shopInfo: widget.shopInfo,
          estimatedAluminumCost: 0.0,
          editingQuotation: _qt,
        ),
      ),
    );
    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = '${_qt.qtNumber}.pdf';
    final isUpdatingExisting = widget.editingQuotationId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_qt.qtNumber),
        actions: [
          if (!_isSaved)
            IconButton(
              tooltip: isUpdatingExisting
                  ? 'บันทึกทับฉบับเดิม'
                  : 'บันทึกใบเสนอราคา',
              onPressed: () => _saveQuotationNow(asNewRevision: false),
              icon: const Icon(
                Icons.check_circle_rounded,
                color: ToolkitColors.successGreen,
              ),
            )
          else
            IconButton(
              key: const ValueKey('qt_preview_edit_btn'),
              tooltip: 'แก้ไขใบเสนอราคา',
              onPressed: _openEditSavedQuotation,
              icon: const Icon(Icons.edit_note_rounded),
            ),
          IconButton(
            tooltip: 'แชร์ PDF',
            onPressed: (_isSaved && _pdfBytes != null)
                ? () => Printing.sharePdf(bytes: _pdfBytes!, filename: fileName)
                : null,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'พิมพ์ / บันทึก PDF',
            onPressed: (_isSaved && _pdfBytes != null)
                ? () => Printing.layoutPdf(
                      name: fileName,
                      onLayout: (_) async => _pdfBytes!,
                    )
                : null,
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // State 1 Warning Banner (Unsaved Preview)
          if (!_isSaved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: const Color(0xFFFEF3C7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: ToolkitColors.vipGoldText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isUpdatingExisting
                              ? 'กำลังดูตัวอย่างฉบับแก้ไข กดบันทึกเพื่ออัปเดตเอกสารก่อนแชร์หรือพิมพ์'
                              : 'กำลังดูตัวอย่าง กรุณาตรวจเอกสารแล้วกดบันทึกก่อนแชร์ บันทึก PDF หรือพิมพ์',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ToolkitColors.vipGoldText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton(
                        key: const ValueKey('qt_preview_save_btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: ToolkitColors.successGreen,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            _saveQuotationNow(asNewRevision: false),
                        child: Text(
                          isUpdatingExisting
                              ? 'บันทึกทับฉบับเดิม'
                              : 'บันทึกใบเสนอราคา',
                        ),
                      ),
                      if (isUpdatingExisting)
                        OutlinedButton(
                          key: const ValueKey('qt_preview_save_rev_btn'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ToolkitColors.deepNavy,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              _saveQuotationNow(asNewRevision: true),
                          child: const Text('บันทึกเป็นฉบับใหม่ (Rev)'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: _pdfBytes == null
                ? const Center(child: CircularProgressIndicator())
                : PdfPreview(
                    build: (_) async => _pdfBytes!,
                    pdfFileName: fileName,
                    allowPrinting: _isSaved,
                    allowSharing: _isSaved,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                  ),
          ),

          // State 2 Unlocked Bottom Navy Bar
          if (_isSaved && _pdfBytes != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ToolkitColors.deepNavy,
                        side: const BorderSide(color: ToolkitColors.cardBorder),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                      ),
                      onPressed: _openEditSavedQuotation,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('แก้ไข'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ToolkitColors.deepNavy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Printing.sharePdf(
                              bytes: _pdfBytes!, filename: fileName);
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('แชร์ PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ToolkitColors.royalBlue,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Printing.layoutPdf(
                            name: fileName,
                            onLayout: (_) async => _pdfBytes!,
                          );
                        },
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('บันทึก / พิมพ์'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Quotation History Screen (ประวัติใบเสนอราคา — R1-... Cards + Edit Button)
// =============================================================================
class QuotationHistoryScreen extends StatefulWidget {
  final int projectId;

  const QuotationHistoryScreen({super.key, required this.projectId});

  @override
  State<QuotationHistoryScreen> createState() => _QuotationHistoryScreenState();
}

class _QuotationHistoryScreenState extends State<QuotationHistoryScreen> {
  List<SavedQuotation> _list = [];
  ShopInfo _shop = const ShopInfo();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final qts =
        await AppDatabase.instance.listQuotationsForProject(widget.projectId);
    final shop = await AppDatabase.instance.getShopInfo();
    if (!mounted) return;
    setState(() {
      _list = qts;
      _shop = shop;
      _loading = false;
    });
  }

  Future<void> _editQuotation(SavedQuotation q) async {
    final proj = await AppDatabase.instance.getProject(widget.projectId);
    if (!mounted) return;
    final targetProj = proj ??
        SavedProject(
          id: widget.projectId,
          name: q.projectName,
          createdAt: q.createdAt,
          updatedAt: q.createdAt,
        );
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationBuilderScreen(
          project: targetProj,
          shopInfo: _shop,
          estimatedAluminumCost: 0.0,
          editingQuotation: q,
        ),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติใบเสนอราคา')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final q = _list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuotationPreviewScreen(
                          quotation: q,
                          shopInfo: _shop,
                          isAlreadySaved: true,
                        ),
                      ),
                    );
                    if (changed == true) _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ToolkitColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.qtNumber,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ToolkitColors.royalBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${q.modeThaiLabel} · ลูกค้า: ${q.customerName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${q.revisionTag} · วันที่ออก ${q.issueDate}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ToolkitColors.slateMuted,
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
                              '฿${_moneyFmt.format(q.netTotal)}',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: ToolkitColors.slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              key: ValueKey('qt_hist_edit_$i'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: ToolkitColors.royalBlue,
                                side: BorderSide(
                                  color: ToolkitColors.royalBlue
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              onPressed: () => _editQuotation(q),
                              icon: const Icon(Icons.edit_note_rounded,
                                  size: 15),
                              label: const Text(
                                'แก้ไข',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
    );
  }
}

// =============================================================================
// Reusable Compact Quantity Stepper & Multi-Row Qty Editor Dialog
// =============================================================================
class _CompactQtyStepper extends StatelessWidget {
  final Key? minusKey;
  final Key? valueKey;
  final Key? plusKey;
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onTapNumber;

  const _CompactQtyStepper({
    this.minusKey,
    this.valueKey,
    this.plusKey,
    required this.qty,
    this.onMinus,
    this.onPlus,
    this.onTapNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: minusKey,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
            onTap: onMinus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                Icons.remove_rounded,
                size: 16,
                color: onMinus != null
                    ? ToolkitColors.deepNavy
                    : ToolkitColors.cardBorder,
              ),
            ),
          ),
          InkWell(
            key: valueKey,
            onTap: onTapNumber,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: ToolkitColors.cardBorder),
                ),
              ),
              child: Text(
                '$qty ชุด',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.royalBlue,
                ),
              ),
            ),
          ),
          InkWell(
            key: plusKey,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(7)),
            onTap: onPlus,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: ToolkitColors.royalBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectItemQtyDialog extends StatefulWidget {
  final SavedProjectItem item;

  const _ProjectItemQtyDialog({required this.item});

  @override
  State<_ProjectItemQtyDialog> createState() => _ProjectItemQtyDialogState();
}

class _ProjectItemQtyDialogState extends State<_ProjectItemQtyDialog> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = widget.item.sizeRows
        .map((r) => TextEditingController(text: r.qty.toString()))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('กำหนดจำนวนชุด · ${widget.item.patternTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ปรับจำนวนชุดได้ทันที ระบบจะคำนวณระยะตัด จัดเส้น และต้นทุนใหม่ให้อัตโนมัติ',
              style: TextStyle(fontSize: 12.5, color: ToolkitColors.slateMuted),
            ),
            const SizedBox(height: 12),
            ...List.generate(widget.item.sizeRows.length, (i) {
              final r = widget.item.sizeRows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ขนาด #${i + 1}: ${FormulaEvaluator.formatMm(r.widthMm)} × ${FormulaEvaluator.formatMm(r.heightMm)} มม.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 82,
                      child: TextField(
                        key: ValueKey('qty_dialog_input_$i'),
                        controller: _ctrls[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'ชุด',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const ValueKey('qty_dialog_save_btn'),
          onPressed: () {
            final qtys = _ctrls
                .map((c) => (int.tryParse(c.text.trim()) ?? 1).clamp(1, 9999))
                .toList();
            Navigator.pop(context, qtys);
          },
          child: const Text('บันทึกจำนวนชุด'),
        ),
      ],
    );
  }
}

class _SingleIntQtyDialog extends StatefulWidget {
  final String title;
  final int initialQty;

  const _SingleIntQtyDialog({
    required this.title,
    required this.initialQty,
  });

  @override
  State<_SingleIntQtyDialog> createState() => _SingleIntQtyDialogState();
}

class _SingleIntQtyDialogState extends State<_SingleIntQtyDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQty.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'จำนวนชุด *',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            final v = (int.tryParse(_ctrl.text.trim()) ?? widget.initialQty)
                .clamp(1, 9999);
            Navigator.pop(context, v);
          },
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
