import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../engine/bin_packer.dart';
import '../engine/formula_evaluator.dart';
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
                                    'ขนาด: ${it.sizeSummaryText} · รวม ${it.totalUnits} ชุด',
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
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'meta') {
                                  await _editItemMetaDialog(it);
                                } else if (action == 'del') {
                                  await AppDatabase.instance
                                      .deleteProjectItem(it.id!, proj.id!);
                                  _reload();
                                }
                              },
                              itemBuilder: (_) => const [
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
  PricingSummary? _latestSummary;
  late final List<ProfileBarGroup> _packedGroups;
  late final List<EvaluatedGlassItem> _projectGlasses;
  late final List<AggregatedHardwareItem> _projectHardware;
  late final double _projectOpeningAreaSqM;

  @override
  void initState() {
    super.initState();
    _packedGroups = BinPacker.packProjectItems(widget.project.items);
    _projectGlasses = widget.project.items
        .expand((it) => it.evaluatedSets.expand((s) => s.glasses))
        .toList();
    _projectHardware = _mergeProjectHardware(widget.project.items);
    _projectOpeningAreaSqM = widget.project.totalOpeningAreaSqM;
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationBuilderScreen(
          project: widget.project,
          shopInfo: shop,
          estimatedAluminumCost: s?.totalCost ?? 0.0,
          initialAluminumThickness: s?.selectedThickness,
          initialAluminumColor: s?.selectedColor,
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
    return Scaffold(
      appBar: AppBar(title: Text('ทำราคาโปรเจกต์ · ${widget.project.name}')),
      body: Column(
        children: [
          Expanded(
            child: PricingWorkspaceWidget(
              barGroups: _packedGroups,
              glasses: _projectGlasses,
              openingAreaSqM: _projectOpeningAreaSqM,
              fallbackOpeningAreaSqM: _projectOpeningAreaSqM * 0.88,
              hardware: _projectHardware,
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
                    prev.selectedColor != s.selectedColor;
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
  final SavedProjectItem sourceItem;
  final TextEditingController labelCtrl;
  final TextEditingController subtitleCtrl;
  final String sizeText;
  final int qty;
  final TextEditingController unitPriceCtrl;
  bool confirmed;
  bool editingSpec;
  bool userCustomizedSubtitle;
  bool userEditedPrice;

  _EditableQtLine({
    required this.sourceItem,
    required String label,
    required String subtitle,
    required this.sizeText,
    required this.qty,
    required double suggestedUnitPrice,
  })  : labelCtrl = TextEditingController(text: label),
        subtitleCtrl = TextEditingController(text: subtitle),
        unitPriceCtrl = TextEditingController(
            text: suggestedUnitPrice.toStringAsFixed(2)),
        confirmed = false,
        editingSpec = false,
        userCustomizedSubtitle = false,
        userEditedPrice = false;

  String get label => labelCtrl.text.trim();
  String get subtitle => subtitleCtrl.text.trim();
  double get unitPrice => double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
  double get lineTotal => unitPrice * qty;

  void dispose() {
    labelCtrl.dispose();
    subtitleCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

class QuotationBuilderScreen extends StatefulWidget {
  final SavedProject project;
  final ShopInfo shopInfo;
  final double estimatedAluminumCost;
  final String? initialAluminumThickness;
  final String? initialAluminumColor;
  final double? openingAreaSqM;
  final double? initialProfitPercent;
  final ProfitBaseMode? initialProfitBaseMode;
  final LaborCostMode? initialLaborMode;
  final double? initialLaborRate;

  const QuotationBuilderScreen({
    super.key,
    required this.project,
    required this.shopInfo,
    required this.estimatedAluminumCost,
    this.initialAluminumThickness,
    this.initialAluminumColor,
    this.openingAreaSqM,
    this.initialProfitPercent,
    this.initialProfitBaseMode,
    this.initialLaborMode,
    this.initialLaborRate,
  });

  @override
  State<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends State<QuotationBuilderScreen> {
  String? _mode; // Starts unselected! ('ITEMIZED' | 'LUMP_SUM')
  late final TextEditingController _docTitleCtrl;
  late final TextEditingController _qtNumCtrl;
  late final TextEditingController _issueDateCtrl;
  late final TextEditingController _validUntilCtrl;
  late final TextEditingController _custNameCtrl;
  final TextEditingController _custAddrCtrl = TextEditingController();
  final TextEditingController _custContactCtrl = TextEditingController();
  late final TextEditingController _projNameCtrl;
  final TextEditingController _projLocCtrl = TextEditingController();
  late final TextEditingController _lumpSumCtrl;
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  bool _discountIsPercent = false;
  bool _vatEnabled = false;
  final TextEditingController _payTermsCtrl = TextEditingController();
  final TextEditingController _leadTimeCtrl = TextEditingController();
  final TextEditingController _warrantyCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  // Live Profit % & Labor Cost Controls
  late final double _openingAreaSqM;
  late double _profitPct;
  late ProfitBaseMode _profitBaseMode;
  late LaborCostMode _laborMode;
  late double _laborRate;
  late final TextEditingController _profitCtrl;
  late final TextEditingController _laborCtrl;
  bool _lumpSumManuallyEdited = false;

  // Global Quotation Material Spec Controls
  late String _globalAluThick;
  late String _globalAluColor;
  String _globalGlassType = 'ไม่ระบุ';
  String _globalGlassThick = 'ไม่ระบุ';
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
    final now = DateTime.now();
    final rand6 = (100000 + Random().nextInt(900000)).toString();
    _docTitleCtrl = TextEditingController(
      text: widget.shopInfo.defaultDocTitle.isEmpty
          ? 'ใบเสนอราคา'
          : widget.shopInfo.defaultDocTitle,
    );
    _qtNumCtrl = TextEditingController(
      text: 'QT-${DateFormat('yyyyMMdd').format(now)}-$rand6',
    );
    _issueDateCtrl =
        TextEditingController(text: DateFormat('dd/MM/yyyy').format(now));
    _validUntilCtrl = TextEditingController(
      text: DateFormat('dd/MM/yyyy')
          .format(now.add(const Duration(days: 30))),
    );
    _custNameCtrl = TextEditingController(text: widget.project.name);
    _projNameCtrl = TextEditingController(text: widget.project.name);

    _openingAreaSqM =
        widget.openingAreaSqM ?? widget.project.totalOpeningAreaSqM;
    _profitPct = (widget.initialProfitPercent ?? 20.0).clamp(0.0, 200.0);
    _profitBaseMode =
        widget.initialProfitBaseMode ?? ProfitBaseMode.materialOnly;
    _laborMode = widget.initialLaborMode ?? LaborCostMode.perSqM;
    _laborRate = (widget.initialLaborRate ?? 0.0).clamp(0.0, 10000000.0);
    _profitCtrl = TextEditingController(text: _fmtNumInput(_profitPct));
    _laborCtrl = TextEditingController(text: _fmtNumInput(_laborRate));

    final initThick = widget.initialAluminumThickness?.trim() ?? '';
    _globalAluThick =
        QuotationSpecFormatter.aluminumThicknessChoices.contains(initThick)
            ? initThick
            : 'ตามรายการ';
    _globalAluColor = QuotationSpecFormatter.normalizePricingColorForQuotation(
      widget.initialAluminumColor,
    );

    final initBreakdown = _breakdown;
    final hasCost = widget.estimatedAluminumCost > 0;
    final unitPrices = hasCost
        ? PricingEngine.allocateUnitSellingPrices(
            items: widget.project.items
                .map((it) => (areaSqM: it.totalOpeningAreaSqM, qty: it.totalUnits))
                .toList(),
            targetTotal: initBreakdown.suggestedSellingPrice,
          )
        : List<double>.filled(widget.project.items.length, 3500.0);

    double sumInit = 0.0;
    for (int i = 0; i < widget.project.items.length; i++) {
      final it = widget.project.items[i];
      final line = _EditableQtLine(
        sourceItem: it,
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
      );
      sumInit += line.lineTotal;
      _lines.add(line);
    }
    final initLump =
        hasCost ? initBreakdown.suggestedSellingPrice : PricingEngine.round2(sumInit);
    _lumpSumCtrl = TextEditingController(text: initLump.toStringAsFixed(2));
  }

  void _applyMarkupToSellingPrices({bool forceAll = false}) {
    if (widget.estimatedAluminumCost <= 0) return;
    final target = _breakdown.suggestedSellingPrice;
    final unitPrices = PricingEngine.allocateUnitSellingPrices(
      items: _lines
          .map((l) => (areaSqM: l.sourceItem.totalOpeningAreaSqM, qty: l.qty))
          .toList(),
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
      if (forceResetAll) {
        ln.userCustomizedSubtitle = false;
      }
      if (!ln.userCustomizedSubtitle) {
        ln.subtitleCtrl.text = QuotationSpecFormatter.buildItemSpecSubtitle(
          item: ln.sourceItem,
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

    // Validation #5: Duplicate quotation number check!
    final used = await AppDatabase.instance.isQuotationNumberUsed(qtNo);
    if (!mounted) return;
    if (used) {
      showToolkitSnackBar(
        context,
        'เลขที่ใบเสนอราคานี้ถูกใช้งานแล้ว กรุณาใช้เลขที่ใหม่',
      );
      return;
    }

    final draft = SavedQuotation(
      projectId: widget.project.id!,
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewScreen(
          quotation: draft,
          shopInfo: widget.shopInfo,
          isAlreadySaved: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างใบเสนอราคา')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
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
                              _buildLineSpecPreviewAndEditor(ln),
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
                          child: _buildLineSpecPreviewAndEditor(ln),
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
          Row(
            children: [
              const Text(
                'ค่าแรง',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label:
                    const Text('บ./ตร.ม.', style: TextStyle(fontSize: 11.5)),
                selected: _laborMode == LaborCostMode.perSqM,
                selectedColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _laborMode = LaborCostMode.perSqM;
                    _applyMarkupToSellingPrices();
                  });
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: const ValueKey('qt_labor_rate_field'),
                  controller: _laborCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    suffixText:
                        _laborMode == LaborCostMode.perSqM ? ' บ./ตร.ม.' : ' ฿',
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
                      _laborRate =
                          (parsed != null && parsed >= 0) ? parsed : 0.0;
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
                  label: Text(ch),
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
          title: 'สีอลูมิเนียม',
          choices: QuotationSpecFormatter.aluminumColorChoices,
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
      ],
    );
  }

  Widget _buildLineSpecPreviewAndEditor(_EditableQtLine ln) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    'ขนาด: ${ln.sizeText.replaceAll('\n', ', ')} · จำนวน ${ln.qty} ชุด',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ToolkitColors.slateMuted,
                    ),
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

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.shopInfo,
    required this.isAlreadySaved,
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

  Future<void> _saveQuotationNow() async {
    if (_isSaved) return;
    final existing = await AppDatabase.instance
        .listQuotationsForProject(_qt.projectId);
    final revTag =
        'R${existing.length + 1}-${DateTime.now().millisecondsSinceEpoch}';

    final toSave = SavedQuotation(
      projectId: _qt.projectId,
      qtNumber: _qt.qtNumber,
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

    await AppDatabase.instance.saveQuotation(toSave);
    final bytes = await QuotationPdfGenerator.generate(
      quotation: toSave,
      shopInfo: widget.shopInfo,
    );
    if (!mounted) return;
    setState(() {
      _qt = toSave;
      _isSaved = true;
      _pdfBytes = bytes;
    });
    showToolkitSnackBar(context, 'บันทึกใบเสนอราคา ${_qt.qtNumber} แล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final fileName = '${_qt.qtNumber}.pdf';
    return Scaffold(
      appBar: AppBar(
        title: Text(_qt.qtNumber),
        actions: [
          if (!_isSaved)
            IconButton(
              tooltip: 'บันทึกใบเสนอราคา',
              onPressed: _saveQuotationNow,
              icon: const Icon(
                Icons.check_circle_rounded,
                color: ToolkitColors.successGreen,
              ),
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
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: ToolkitColors.vipGoldText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'กำลังดูตัวอย่าง กรุณาตรวจเอกสารแล้วกดบันทึกก่อนแชร์ บันทึก PDF หรือพิมพ์',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ToolkitColors.vipGoldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ToolkitColors.successGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _saveQuotationNow,
                    child: const Text('บันทึกใบเสนอราคา'),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
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
                        label: const Text('แชร์ใบเสนอราคา PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
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
// Quotation History Screen (ประวัติใบเสนอราคา — R1-... Cards)
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuotationPreviewScreen(
                          quotation: q,
                          shopInfo: _shop,
                          isAlreadySaved: true,
                        ),
                      ),
                    );
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
                        Text(
                          '฿${_moneyFmt.format(q.netTotal)}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: ToolkitColors.slateDark,
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
