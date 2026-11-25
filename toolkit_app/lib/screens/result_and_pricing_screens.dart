import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../data/seed_repository.dart';
import '../engine/clipboard_formatter.dart';
import '../engine/formula_evaluator.dart';
import '../engine/material_mutation_helper.dart';
import '../engine/pricing_engine.dart';
import '../models/app_models.dart';
import '../pdf/single_cut_pdf.dart';
import 'alupro_thumbnail_widgets.dart';
import 'custom_system_studio_screens.dart';
import 'material_editor_sheets.dart';
import 'projects_and_quotation_screens.dart';
import 'theme_tokens.dart';

final NumberFormat _bahtFmt = NumberFormat('#,##0.00', 'en_US');

class ResultScreen extends StatefulWidget {
  final CalculationOutput output;
  final List<SizeRowInput> sizeRows;
  final int? targetProjectId;
  final SavedProjectItem? editingProjectItem;

  const ResultScreen({
    super.key,
    required this.output,
    required this.sizeRows,
    this.targetProjectId,
    this.editingProjectItem,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late CalculationOutput _workingOut;
  bool _hasMaterialEdits = false;
  bool _checkedNotice = false;

  @override
  void initState() {
    super.initState();
    _workingOut = widget.output;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 3) {
        _maybeShowPricingBetaDialog();
      }
    });
  }

  void _applyMutation(CalculationOutput next, {String? snackMessage}) {
    setState(() {
      _workingOut = next;
      _hasMaterialEdits = true;
    });
    if (snackMessage != null && mounted) {
      showToolkitSnackBar(context, snackMessage);
    }
  }

  void _resetToOriginalFormula() {
    setState(() {
      _workingOut = widget.output;
      _hasMaterialEdits = false;
    });
    showToolkitSnackBar(context, 'คืนค่าชิ้นส่วนวัสดุตามสูตรเดิมแล้ว');
  }

  Future<void> _openAddAluminumCut({int setListIndex = 0}) async {
    final overrides = await AppDatabase.instance.getAllCustomPrices();
    if (!mounted) return;
    final res = await showAluminumCutEditorSheet(
      context: context,
      defaultBrandKey: _workingOut.priceBrandKey,
      customPriceOverrides: overrides,
    );
    if (res == null || res.type != MaterialEditActionType.save || res.cut == null) {
      return;
    }
    _applyMutation(
      MaterialMutationHelper.addCutItem(
        _workingOut,
        setListIndex: setListIndex,
        cut: res.cut!,
      ),
      snackMessage: 'เพิ่มเส้น ${res.cut!.code} และจัดเส้น + คำนวณราคาใหม่แล้ว',
    );
  }

  Future<void> _openEditAluminumCut({
    required int setListIndex,
    required int cutIndex,
    required EvaluatedCutItem cut,
  }) async {
    final overrides = await AppDatabase.instance.getAllCustomPrices();
    if (!mounted) return;
    final res = await showAluminumCutEditorSheet(
      context: context,
      defaultBrandKey: _workingOut.priceBrandKey,
      existingCut: cut,
      customPriceOverrides: overrides,
    );
    if (res == null) return;
    if (res.type == MaterialEditActionType.delete) {
      _applyMutation(
        MaterialMutationHelper.deleteCutItem(
          _workingOut,
          setListIndex: setListIndex,
          cutIndex: cutIndex,
        ),
        snackMessage: 'ลบรายการ ${cut.code} ออกแล้ว',
      );
    } else if (res.cut != null) {
      _applyMutation(
        MaterialMutationHelper.updateCutItem(
          _workingOut,
          setListIndex: setListIndex,
          cutIndex: cutIndex,
          cut: res.cut!,
        ),
        snackMessage: 'อัปเดตชิ้นส่วน ${res.cut!.code} และคำนวณใหม่แล้ว',
      );
    }
  }

  Future<void> _openSwapOrDeleteProfileGroup(ProfileBarGroup grp) async {
    final overrides = await AppDatabase.instance.getAllCustomPrices();
    if (!mounted) return;
    final res = await showAluminumCutEditorSheet(
      context: context,
      defaultBrandKey: _workingOut.priceBrandKey,
      existingGroup: grp,
      customPriceOverrides: overrides,
    );
    if (res == null) return;
    if (res.type == MaterialEditActionType.delete) {
      _applyMutation(
        MaterialMutationHelper.deleteProfileGroup(
          _workingOut,
          brand: grp.brand,
          code: grp.code,
          stockMm: grp.stockLengthMm,
        ),
        snackMessage: 'ลบหน้าตัด ${grp.code} ออกแล้ว',
      );
    } else if (res.newCode != null) {
      _applyMutation(
        MaterialMutationHelper.swapProfileGroup(
          _workingOut,
          oldBrand: grp.brand,
          oldCode: grp.code,
          oldStockMm: grp.stockLengthMm,
          newBrand: res.newBrand ?? grp.brand,
          newCode: res.newCode!,
          newName: res.newName ?? grp.combinedNames,
          newStockMm: res.newStockMm ?? grp.stockLengthMm,
          overrideDirectBars: res.overrideDirectBars,
        ),
        snackMessage: 'เปลี่ยนหน้าตัดเป็น ${res.newCode!} และจับคู่ราคาใหม่แล้ว',
      );
    }
  }

  Future<void> _openAddGlass({int setListIndex = 0}) async {
    final res = await showGlassItemEditorSheet(context: context);
    if (res == null ||
        res.type != MaterialEditActionType.save ||
        res.glass == null) {
      return;
    }
    _applyMutation(
      MaterialMutationHelper.addGlassItem(
        _workingOut,
        setListIndex: setListIndex,
        glass: res.glass!,
      ),
      snackMessage: 'เพิ่มรายการกระจก ${res.glass!.name} แล้ว',
    );
  }

  Future<void> _openEditGlass(int flatIndex, EvaluatedGlassItem glass) async {
    final res = await showGlassItemEditorSheet(
      context: context,
      existingGlass: glass,
    );
    if (res == null) return;
    if (res.type == MaterialEditActionType.delete) {
      _applyMutation(
        MaterialMutationHelper.deleteGlassByFlatIndex(
          _workingOut,
          flatIndex: flatIndex,
        ),
        snackMessage: 'ลบรายการกระจก ${glass.name} แล้ว',
      );
    } else if (res.glass != null) {
      _applyMutation(
        MaterialMutationHelper.updateGlassByFlatIndex(
          _workingOut,
          flatIndex: flatIndex,
          glass: res.glass!,
        ),
        snackMessage: 'อัปเดตรายการกระจก ${res.glass!.name} แล้ว',
      );
    }
  }

  Future<void> _openAddHardware() async {
    final matOv = await AppDatabase.instance.getAllCustomMaterialRates();
    if (!mounted) return;
    final res = await showHardwareItemEditorSheet(
      context: context,
      materialOverrides: matOv,
    );
    if (res == null ||
        res.type != MaterialEditActionType.save ||
        res.hardware == null) {
      return;
    }
    _applyMutation(
      MaterialMutationHelper.addHardwareItem(_workingOut, res.hardware!),
      snackMessage: 'เพิ่มอุปกรณ์ ${res.hardware!.name} แล้ว',
    );
  }

  Future<void> _openEditHardware(int index, AggregatedHardwareItem hw) async {
    final matOv = await AppDatabase.instance.getAllCustomMaterialRates();
    if (!mounted) return;
    final res = await showHardwareItemEditorSheet(
      context: context,
      existingHardware: hw,
      materialOverrides: matOv,
    );
    if (res == null) return;
    if (res.type == MaterialEditActionType.delete) {
      _applyMutation(
        MaterialMutationHelper.deleteHardwareItem(_workingOut, index),
        snackMessage: 'ลบอุปกรณ์ ${hw.name} แล้ว',
      );
    } else if (res.hardware != null) {
      _applyMutation(
        MaterialMutationHelper.updateHardwareItem(
            _workingOut, index, res.hardware!),
        snackMessage: 'อัปเดตอุปกรณ์ ${res.hardware!.name} แล้ว',
      );
    }
  }

  Future<void> _saveEditedProjectItem() async {
    final it = widget.editingProjectItem;
    if (it == null || it.id == null) return;
    await AppDatabase.instance.updateProjectItemFull(
      it.copyWith(
        brandTitle: _workingOut.brandTitle,
        priceBrandKey: _workingOut.priceBrandKey,
        systemTitle: _workingOut.systemTitle,
        patternId: _workingOut.patternId,
        patternTitle: _workingOut.patternTitle,
        selectedOptions: _workingOut.selectedOptions,
        sizeRows: widget.sizeRows,
        evaluatedSets: _workingOut.sets,
        hardware: _workingOut.hardware,
      ),
    );
    if (!mounted) return;
    showToolkitSnackBar(context, 'บันทึกการแก้ไขงานลงโปรเจกต์แล้ว');
    Navigator.pop(context, true);
  }

  Future<void> _maybeShowPricingBetaDialog() async {
    if (_checkedNotice) return;
    _checkedNotice = true;
    final seen = await AppDatabase.instance.hasSeenPricingNotice();
    if (!seen && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('คำแนะนำระบบทำราคาเบื้องต้น'),
          content: const Text(
            'ระบบทำราคาช่วยประเมินต้นทุนเส้นอลูมิเนียมจากฐานข้อมูลราคาอ้างอิงและราคาที่คุณตั้งค่าเอง '
            'กรุณาตรวจสอบความหนา สี/ผิว เปอร์เซ็นต์เผื่อเสีย และราคาขายจริงอีกครั้งก่อนเสนอราคาลูกค้า',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await AppDatabase.instance.markPricingNoticeSeen();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('รับทราบ'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _shareSingleCutPdf() async {
    final bytes = await SingleCutPdfGenerator.generate(_workingOut);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewAndShareScreen(
          title: 'Toolkit - ใบสั่งตัด',
          fileName: SingleCutPdfGenerator.suggestedFileName(),
          pdfBytes: bytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final out = _workingOut;
    final isEditingSaved = widget.editingProjectItem != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${out.brandTitle} | ${out.patternTitle}'),
        actions: [
          if (_hasMaterialEdits)
            TextButton.icon(
              key: const ValueKey('btn_reset_materials'),
              onPressed: _resetToOriginalFormula,
              icon: const Icon(Icons.restore_rounded, size: 17),
              label: const Text(
                'คืนค่าเดิม',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          labelColor: ToolkitColors.royalBlue,
          unselectedLabelColor: ToolkitColors.slateMuted,
          indicatorColor: ToolkitColors.royalBlue,
          labelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'ระยะตัด'),
            Tab(text: 'ถอดรายการ'),
            Tab(text: 'จัดเส้น'),
            Tab(text: 'ทำราคา'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTab1CutLengths(out),
                _buildTab2BomSummary(out),
                _buildTab3BarPacking(out),
                PricingWorkspaceWidget(
                  barGroups: out.barGroups,
                  glasses: out.sets.expand((s) => s.glasses).toList(),
                  openingAreaSqM: out.sets.fold<double>(
                    0.0,
                    (sum, s) =>
                        sum +
                        ((s.sizeRow.widthMm * s.sizeRow.heightMm) / 1000000.0) *
                            s.sizeRow.qty,
                  ),
                  fallbackOpeningAreaSqM: out.sets.fold(
                    0.0,
                    (sum, s) =>
                        sum +
                        ((s.sizeRow.widthMm * s.sizeRow.heightMm) / 1000000.0) *
                            s.sizeRow.qty *
                            0.88,
                  ),
                  hardware: out.hardware,
                  onAddAluminum: () => _openAddAluminumCut(),
                  onEditProfileGroup: _openSwapOrDeleteProfileGroup,
                  onAddGlass: () => _openAddGlass(),
                  onEditGlass: _openEditGlass,
                  onAddHardware: _openAddHardware,
                  onEditHardware: _openEditHardware,
                ),
              ],
            ),
          ),

          // Persistent 3-Button Bottom Bar across ALL 4 tabs!
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ToolkitColors.deepNavy,
                        side: const BorderSide(color: ToolkitColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () {
                        final txt = ClipboardFormatter.formatCalculation(out);
                        Clipboard.setData(ClipboardData(text: txt));
                        showToolkitSnackBar(
                            context, 'คัดลอกรายการลงคลิปบอร์ดแล้ว');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text(
                        'คัดลอกรายการ',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('btn_save_result_middle'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isEditingSaved
                            ? ToolkitColors.successGreen
                            : ToolkitColors.deepNavy,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: isEditingSaved
                          ? _saveEditedProjectItem
                          : () {
                              showDialog(
                                context: context,
                                builder: (_) => SaveToProjectDialog(
                                  output: out,
                                  sizeRows: widget.sizeRows,
                                  preselectedProjectId: widget.targetProjectId,
                                ),
                              );
                            },
                      icon: Icon(
                        isEditingSaved
                            ? Icons.save_outlined
                            : Icons.bookmark_add_outlined,
                        size: 17,
                      ),
                      label: Text(
                        isEditingSaved ? 'บันทึกการแก้ไข' : 'บันทึกงาน',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ToolkitColors.royalBlue,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: _shareSingleCutPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                      label: const Text(
                        'แชร์ PDF',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
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

  Widget _buildTab1CutLengths(CalculationOutput out) {
    final allGlasses = out.sets.expand((s) => s.glasses).toList();
    return ListView(
      cacheExtent: 600,
      padding: const EdgeInsets.all(14),
      children: [
        ...List.generate(out.sets.length, (setListIdx) {
          final s = out.sets[setListIdx];
          final wStr = FormulaEvaluator.formatMm(s.sizeRow.widthMm);
          final hStr = FormulaEvaluator.formatMm(s.sizeRow.heightMm);
          final grouped = <String, List<({int cutIdx, EvaluatedCutItem cut})>>{};
          for (int ci = 0; ci < s.cuts.length; ci++) {
            final c = s.cuts[ci];
            grouped.putIfAbsent(c.section, () => []).add((cutIdx: ci, cut: c));
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: ExpansionTile(
              initiallyExpanded: s.setIndex == 1,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              title: Text(
                'ชุดที่ ${s.setIndex} — $wStr × $hStr มม. | จำนวน ${s.sizeRow.qty} ชุด',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.slateDark,
                ),
              ),
              subtitle: const Text(
                'แตะชิ้นส่วนใดก็ได้เพื่อเปลี่ยนรหัส / แก้ระยะตัด / ลบ',
                style: TextStyle(fontSize: 11.5, color: ToolkitColors.royalBlue),
              ),
              children: [
                ...grouped.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: ToolkitColors.softBlueBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ToolkitColors.royalBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...entry.value.map((rec) {
                          final c = rec.cut;
                          final effBrand = MaterialMutationHelper.effectiveBrandOf(
                            c,
                            out.priceBrandKey,
                          );
                          final cutVal = c.isSiteMeasured
                              ? (c.angle == 'สั่งเต็มเส้น'
                                  ? 'สั่งเต็มเส้น ${c.totalQty} เส้น'
                                  : 'วัดตามจริง')
                              : 'ตัด ${FormulaEvaluator.formatMm(c.lengthMm ?? 0)} มม.';
                          final profImg = AluproImageRegistry.instance
                              .resolveProfileAsset(
                            code: c.code,
                            name: c.name,
                            brandKey: effBrand,
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openEditAluminumCut(
                              setListIndex: setListIdx,
                              cutIndex: rec.cutIdx,
                              cut: c,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (profImg != null) ...[
                                    AluproThumbnail(
                                      assetPath: profImg,
                                      width: 50,
                                      height: 38,
                                      showZoomBadge: true,
                                      zoomTitle: '${c.code} · ${c.name}',
                                      zoomSubtitle:
                                          '$effBrand · $cutVal (${c.totalQty} ชิ้น)',
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                c.code,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      ToolkitColors.royalBlue,
                                                ),
                                              ),
                                            ),
                                            if (c.brandOverride != null &&
                                                c.brandOverride!
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  c.brandOverride!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF92400E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: ToolkitColors.slateDark,
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
                                        cutVal,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: ToolkitColors.slateDark,
                                        ),
                                      ),
                                      Text(
                                        '${c.totalQty} ชิ้น · ${c.angle}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ToolkitColors.slateMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: ToolkitColors.slateMuted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: ValueKey('tab1_add_cut_$setListIdx'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ToolkitColors.royalBlue,
                        side: BorderSide(
                          color: ToolkitColors.royalBlue.withValues(alpha: 0.35),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          _openAddAluminumCut(setListIndex: setListIdx),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'เพิ่มเส้นอลูมิเนียมนอกสูตร',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Extra / Glass Accordion
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ToolkitColors.cardBorder),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
            title: const Text(
              'รายการเพิ่มเติม | กระจกและรายการเตรียมเพิ่มเติม',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ToolkitColors.slateDark,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
                child: Column(
                  children: [
                    if (allGlasses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'ไม่มีรายการกระจก',
                          style: TextStyle(color: ToolkitColors.slateMuted),
                        ),
                      )
                    else
                      ...List.generate(allGlasses.length, (gi) {
                        final g = allGlasses[gi];
                        final dimTxt = g.siteCut
                            ? 'วัดตัดหน้างาน · ${g.totalPanels} แผ่น'
                            : 'ขนาดสั่งตัดกระจก: ${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม. · ${g.totalPanels} แผ่น';
                        final glassImg =
                            AluproImageRegistry.instance.glassAsset;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openEditGlass(gi, g),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 2),
                            child: Row(
                              children: [
                                if (glassImg != null) ...[
                                  AluproThumbnail(
                                    assetPath: glassImg,
                                    width: 46,
                                    height: 34,
                                    zoomTitle: g.name,
                                    zoomSubtitle: dimTxt,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    g.name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    dimTxt,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ToolkitColors.royalBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: ToolkitColors.slateMuted,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('tab1_add_glass'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ToolkitColors.royalBlue,
                          side: BorderSide(
                            color:
                                ToolkitColors.royalBlue.withValues(alpha: 0.35),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _openAddGlass(),
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text(
                          'เพิ่มกระจกนอกสูตร',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab2BomSummary(CalculationOutput out) {
    final allGlasses = out.sets.expand((s) => s.glasses).toList();
    final glassImg = AluproImageRegistry.instance.glassAsset;
    return ListView(
      cacheExtent: 600,
      padding: const EdgeInsets.all(14),
      children: [
        _summarySectionCard(
          title: 'อลูมิเนียมที่ต้องสั่งซื้อ',
          trailing: TextButton.icon(
            key: const ValueKey('tab2_add_alu'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openAddAluminumCut(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'เพิ่มเส้น',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          children: out.barGroups.isEmpty
              ? [const Text('ไม่มีรายการอลูมิเนียม')]
              : out.barGroups.map((g) {
                  final profImg =
                      AluproImageRegistry.instance.resolveProfileAsset(
                    code: g.code,
                    name: g.combinedNames,
                    brandKey: g.brand,
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _openSwapOrDeleteProfileGroup(g),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 2),
                      child: Row(
                        children: [
                          if (profImg != null) ...[
                            AluproThumbnail(
                              assetPath: profImg,
                              width: 50,
                              height: 38,
                              showZoomBadge: true,
                              zoomTitle: '${g.code} · ${g.combinedNames}',
                              zoomSubtitle:
                                  '${g.brand} · เส้นโรงงาน ${g.stockLengthMm} มม. · ${g.totalBars} เส้น',
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${g.code} · ${g.combinedNames}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${g.brand} · เส้นโรงงาน ${g.stockLengthMm} มม.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ToolkitColors.slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${g.totalBars} เส้น',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ToolkitColors.royalBlue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.swap_horiz_rounded,
                            size: 16,
                            color: ToolkitColors.slateMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
        ),
        const SizedBox(height: 12),
        _summarySectionCard(
          title: 'กระจกที่ต้องสั่ง',
          trailing: TextButton.icon(
            key: const ValueKey('tab2_add_glass'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openAddGlass(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'เพิ่มกระจก',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          children: allGlasses.isEmpty
              ? [const Text('ไม่มีรายการกระจก')]
              : List.generate(allGlasses.length, (gi) {
                  final g = allGlasses[gi];
                  final subTxt = g.siteCut
                      ? 'วัดตัดหน้างาน'
                      : '${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม.';
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _openEditGlass(gi, g),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 2),
                      child: Row(
                        children: [
                          if (glassImg != null) ...[
                            AluproThumbnail(
                              assetPath: glassImg,
                              width: 48,
                              height: 36,
                              zoomTitle: g.name,
                              zoomSubtitle: '$subTxt · ${g.totalPanels} แผ่น',
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  subTxt,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ToolkitColors.slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${g.totalPanels} แผ่น',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: ToolkitColors.slateMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
        ),
        const SizedBox(height: 12),
        _summarySectionCard(
          title: 'อุปกรณ์ประกอบ',
          trailing: TextButton.icon(
            key: const ValueKey('tab2_add_hw'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openAddHardware,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'เพิ่มอุปกรณ์',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          children: out.hardware.isEmpty
              ? [const Text('ไม่มีรายการอุปกรณ์ประกอบ')]
              : List.generate(out.hardware.length, (hi) {
                  final h = out.hardware[hi];
                  final hwImg = AluproImageRegistry.instance
                      .resolveHardwareAsset(code: h.code, name: h.name);
                  final hwLabel =
                      h.code.isNotEmpty ? '${h.code} · ${h.name}' : h.name;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _openEditHardware(hi, h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 2),
                      child: Row(
                        children: [
                          if (hwImg != null) ...[
                            AluproThumbnail(
                              assetPath: hwImg,
                              width: 48,
                              height: 36,
                              showZoomBadge: true,
                              zoomTitle: hwLabel,
                              zoomSubtitle: h.displayQty,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              hwLabel,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 118),
                            child: Text(
                              h.displayQty,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.swap_horiz_rounded,
                            size: 16,
                            color: ToolkitColors.slateMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
        ),
      ],
    );
  }

  Widget _buildTab3BarPacking(CalculationOutput out) {
    return ListView(
      cacheExtent: 600,
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ToolkitColors.royalBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'สรุปการจัดเส้นสั่งซื้อ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'รวม ${out.totalStockBars} เส้น',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'กันระยะปลายเส้น 100 mm ตามระบบจัดท่อน · ใบเลื่อย 4 mm · เศษคงเหลือรวม ${FormulaEvaluator.formatMm(out.totalRemnantMm)} mm',
                style: const TextStyle(fontSize: 12, color: Color(0xFFDBEAFE)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...out.barGroups.map((grp) => ProfileBarGroupCard(group: grp)),
      ],
    );
  }

  Widget _summarySectionCard({
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
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
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.slateDark,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}

// =============================================================================
// Visual Proportional Bar Diagram Card (Shared by Result Tab 3 & Project Detail)
// =============================================================================
class ProfileBarGroupCard extends StatelessWidget {
  final ProfileBarGroup group;

  const ProfileBarGroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final profImg = AluproImageRegistry.instance.resolveProfileAsset(
      code: group.code,
      name: group.combinedNames,
      brandKey: group.brand,
    );
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
            children: [
              if (profImg != null) ...[
                AluproThumbnail(
                  assetPath: profImg,
                  width: 50,
                  height: 38,
                  showZoomBadge: true,
                  zoomTitle: '${group.code} — ${group.combinedNames}',
                  zoomSubtitle:
                      '${group.totalBars} เส้น (${group.stockLengthMm} mm)',
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  '${group.code} — ${group.combinedNames}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.slateDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: ToolkitColors.softBlueBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${group.totalBars} เส้น (${group.stockLengthMm} mm)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.royalBlue,
                  ),
                ),
              ),
            ],
          ),
          if (group.estimatedBars > 0 && group.confirmedBars.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'รายการวัดตัดหน้างาน · ประมาณการ ${group.estimatedBars} เส้น',
              style: const TextStyle(
                  fontSize: 12.5, color: ToolkitColors.slateMuted),
            ),
          ],
          const SizedBox(height: 10),
          ...group.confirmedBars.map((bar) {
            final usable = bar.usableLengthMm.toDouble();
            final rem = bar.remnantMm < 0 ? 0.0 : bar.remnantMm;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        border: Border.all(color: ToolkitColors.cardBorder),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final maxW = constraints.maxWidth;
                          return Row(
                            children: [
                              ...bar.cuts.map((c) {
                                final w = ((c.lengthMm / usable) * maxW)
                                    .clamp(22.0, maxW);
                                final lbl = c.itemTag != null
                                    ? '${c.itemTag} ${FormulaEvaluator.formatMm(c.lengthMm)}'
                                    : FormulaEvaluator.formatMm(c.lengthMm);
                                return Container(
                                  width: w,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2563EB),
                                    border: Border(
                                      right: BorderSide(
                                          color: Colors.white, width: 1.2),
                                    ),
                                  ),
                                  child: Text(
                                    w >= 38 ? lbl : '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }),
                              if (rem > 1)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      rem >= 450
                                          ? 'เหลือ ${FormulaEvaluator.formatMm(rem)}'
                                          : '',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: ToolkitColors.slateBody,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'เส้นที่ #${bar.barIndex}: ใช้ ${FormulaEvaluator.formatMm(bar.usedLengthMm)} mm · เหลือ ${FormulaEvaluator.formatMm(rem)} mm · ใบเลื่อย 4 mm',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ToolkitColors.slateMuted,
                    ),
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
// Reusable Tab 4 Pricing Workspace (Shared by Result Tab 4 & ProjectPricingScreen)
// =============================================================================
class PricingWorkspaceWidget extends StatefulWidget {
  final List<ProfileBarGroup> barGroups;
  final List<EvaluatedGlassItem> glasses;
  final double? openingAreaSqM;
  final double fallbackOpeningAreaSqM;
  final List<AggregatedHardwareItem> hardware;
  final ValueChanged<PricingSummary>? onSummaryChanged;
  final VoidCallback? onAddAluminum;
  final ValueChanged<ProfileBarGroup>? onEditProfileGroup;
  final VoidCallback? onAddGlass;
  final void Function(int index, EvaluatedGlassItem glass)? onEditGlass;
  final VoidCallback? onAddHardware;
  final void Function(int index, AggregatedHardwareItem hw)? onEditHardware;

  const PricingWorkspaceWidget({
    super.key,
    required this.barGroups,
    this.glasses = const [],
    this.openingAreaSqM,
    this.fallbackOpeningAreaSqM = 0.0,
    this.hardware = const [],
    this.onSummaryChanged,
    this.onAddAluminum,
    this.onEditProfileGroup,
    this.onAddGlass,
    this.onEditGlass,
    this.onAddHardware,
    this.onEditHardware,
  });

  @override
  State<PricingWorkspaceWidget> createState() => _PricingWorkspaceWidgetState();
}

class _PricingWorkspaceWidgetState extends State<PricingWorkspaceWidget> {
  PricingMode _mode = PricingMode.actualLength;
  double _wastePct = 20.0;
  late final TextEditingController _wasteCtrl;
  String _selectedThickness = '';
  String _selectedColor = '';
  bool _includeGlass = false;
  String _selectedGlassKey = 'GLASS|กระจกใส 6 มม.';
  bool _includeHardware = false;

  // Profit % & Labor Cost Controls
  double _profitPct = 20.0;
  ProfitBaseMode _profitBaseMode = ProfitBaseMode.materialOnly;
  LaborCostMode _laborMode = LaborCostMode.perSqM;
  double _laborRate = 0.0;
  bool _markupLoaded = false;
  late final TextEditingController _profitCtrl;
  late final TextEditingController _laborCtrl;

  Map<String, CustomPriceOverride> _overrides = {};
  Map<String, CustomMaterialRateOverride> _materialOverrides = {};
  bool _loading = true;

  static String _fmtNumInput(double v) {
    if ((v - v.roundToDouble()).abs() < 0.005) {
      return v.round().toString();
    }
    return v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _wasteCtrl = TextEditingController(text: '20');
    _profitCtrl = TextEditingController(text: '20');
    _laborCtrl = TextEditingController(text: '0');
    _includeGlass = widget.glasses.isNotEmpty &&
        (widget.glasses.any((g) => !g.siteCut && (g.widthMm ?? 0) > 0) ||
            widget.fallbackOpeningAreaSqM > 0);
    _includeHardware = widget.hardware.any((h) => (h.effectiveQty ?? 0) > 0);
    _reloadOverrides();
  }

  @override
  void didUpdateWidget(covariant PricingWorkspaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barGroups != widget.barGroups ||
        oldWidget.glasses != widget.glasses ||
        oldWidget.hardware != widget.hardware ||
        oldWidget.openingAreaSqM != widget.openingAreaSqM) {
      if (oldWidget.glasses.isEmpty && widget.glasses.isNotEmpty) {
        _includeGlass = true;
      }
      if (oldWidget.hardware.isEmpty &&
          widget.hardware.any((h) => (h.effectiveQty ?? 0) > 0)) {
        _includeHardware = true;
      }
      if (!_loading) {
        _syncValidSelection(_overrides);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyParent();
        });
      }
    }
  }

  List<MaterialRateItem> _mergedGlassRates() {
    return PricingEngine.mergeMaterialRates(
      SeedRepository.instance.glassRates,
      _materialOverrides,
      category: 'GLASS',
    );
  }

  void _syncValidSelection(Map<String, CustomPriceOverride> ov) {
    final avail = PricingEngine.computeAvailability(
      barGroups: widget.barGroups,
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: ov,
      preferredColor: _selectedColor.isNotEmpty ? _selectedColor : null,
    );
    if (avail.availableColors.isEmpty) {
      _selectedColor = 'ตัวดิบ MILL';
    } else if (!avail.availableColors.contains(_selectedColor)) {
      _selectedColor = avail.availableColors.contains('อบดำ (8816)')
          ? 'อบดำ (8816)'
          : (avail.availableColors.contains('ตัวดิบ MILL')
              ? 'ตัวดิบ MILL'
              : avail.availableColors.first);
    }

    final availForColor = PricingEngine.computeAvailability(
      barGroups: widget.barGroups,
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: ov,
      preferredColor: _selectedColor,
    );
    if (availForColor.availableThicknesses.isEmpty) {
      _selectedThickness = '1.2 มม.';
    } else if (!availForColor.availableThicknesses
        .contains(_selectedThickness)) {
      _selectedThickness =
          availForColor.availableThicknesses.contains('1.2 มม.')
              ? '1.2 มม.'
              : availForColor.availableThicknesses.first;
    }

    final gRates = _mergedGlassRates();
    if (gRates.isNotEmpty &&
        !gRates.any((r) => r.rateKey == _selectedGlassKey)) {
      _selectedGlassKey = gRates.first.rateKey;
    }
  }

  Future<void> _reloadOverrides() async {
    final ov = await AppDatabase.instance.getAllCustomPrices();
    final matOv = await AppDatabase.instance.getAllCustomMaterialRates();
    final markupDefaults = _markupLoaded
        ? null
        : await AppDatabase.instance.getPricingMarkupDefaults();
    if (!mounted) return;
    setState(() {
      _overrides = ov;
      _materialOverrides = matOv;
      if (markupDefaults != null && !_markupLoaded) {
        _profitPct = markupDefaults.profitPercent;
        _profitBaseMode = markupDefaults.profitBaseMode;
        _laborMode = markupDefaults.laborMode;
        _laborRate = markupDefaults.laborRate;
        _profitCtrl.text = _fmtNumInput(_profitPct);
        _laborCtrl.text = _fmtNumInput(_laborRate);
        _markupLoaded = true;
      }
      _syncValidSelection(ov);
      _loading = false;
    });
    _notifyParent();
  }

  Future<void> _saveMarkupAsShopDefault() async {
    await AppDatabase.instance.savePricingMarkupDefaults(
      PricingMarkupDefaults(
        profitPercent: _profitPct,
        profitBaseMode: _profitBaseMode,
        laborMode: _laborMode,
        laborRate: _laborRate,
      ),
    );
    if (!mounted) return;
    showToolkitSnackBar(
      context,
      'บันทึกกำไร ${_fmtNumInput(_profitPct)}% และค่าแรงเป็นค่าตั้งต้นของร้านแล้ว',
    );
  }

  void _notifyParent() {
    if (widget.onSummaryChanged != null) {
      widget.onSummaryChanged!(_computeSummary());
    }
  }

  PricingSummary _computeSummary() {
    final gRates = _mergedGlassRates();
    final activeGlass = gRates.where((r) => r.rateKey == _selectedGlassKey);
    final glassRate = activeGlass.isNotEmpty
        ? activeGlass.first.effectivePrice
        : (gRates.isNotEmpty ? gRates.first.effectivePrice : 205.0);

    return PricingEngine.evaluate(
      barGroups: widget.barGroups,
      mode: _mode,
      wastePercent: _wastePct,
      selectedThickness: _selectedThickness,
      selectedColor: _selectedColor,
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: _overrides,
      glasses: widget.glasses,
      openingAreaSqM: widget.openingAreaSqM,
      fallbackOpeningAreaSqM: widget.fallbackOpeningAreaSqM,
      hardware: widget.hardware,
      includeGlass: _includeGlass,
      selectedGlassKey: _selectedGlassKey,
      glassRatePerSqM: glassRate,
      includeHardware: _includeHardware,
      hardwareCatalog: SeedRepository.instance.hardwareRates,
      materialOverrides: _materialOverrides,
      laborMode: _laborMode,
      laborRate: _laborRate,
      profitPercent: _profitPct,
      profitBaseMode: _profitBaseMode,
    );
  }

  Future<void> _openInlineProfilePriceDialog(ProfileCostLine ln) async {
    final grp = ln.group;
    final sku = ln.matchedSku;
    final targetCode = sku?.code ??
        PricingEngine.expandCandidateCodes(grp.code).firstOrNull ??
        grp.code.trim();
    final targetThick = sku?.thickness ??
        (_selectedThickness.isNotEmpty ? _selectedThickness : '1.2 มม.');
    final targetColor = sku?.color ??
        (_selectedColor.isNotEmpty ? _selectedColor : 'อบดำ (8816)');
    final stockM = sku?.stockM ?? (grp.stockLengthMm / 1000.0);

    final priceCtrl = TextEditingController(
      text: ln.unitPricePerBar != null
          ? ln.unitPricePerBar!.toStringAsFixed(2)
          : '',
    );
    bool applyToUnpricedColors = !ln.isMatched;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('${grp.brand} · ${grp.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grp.combinedNames,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ToolkitColors.slateDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'สเปกที่กำลังคำนวณ: $targetThick · $targetColor · ยาว ${stockM.toStringAsFixed(1)} ม./เส้น',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ToolkitColors.slateMuted,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ราคาต่อเส้น (บาท) *',
                    hintText: 'เช่น 1680',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: applyToUnpricedColors,
                  title: const Text(
                    'ใช้ราคานี้เป็นฐานให้สีอื่นของรหัสนี้ที่ยังไม่มีราคาด้วย',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  onChanged: (v) =>
                      setModal(() => applyToUnpricedColors = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            if (sku?.customPrice != null)
              TextButton(
                onPressed: () async {
                  await AppDatabase.instance.deleteCustomPrice(sku!.skuKey);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _reloadOverrides();
                },
                child: const Text('คืนค่าราคาตั้งต้น'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final val = double.tryParse(priceCtrl.text.trim());
                if (val == null || val < 0) return;

                final batch = <CustomPriceOverride>[
                  CustomPriceOverride(
                    skuKey: '${grp.brand}|$targetCode|$targetThick|$targetColor',
                    brand: grp.brand,
                    code: targetCode,
                    name: grp.combinedNames,
                    thickness: targetThick,
                    color: targetColor,
                    stockM: stockM,
                    pricePerBar: val,
                  ),
                ];

                if (applyToUnpricedColors) {
                  final merged = PricingEngine.mergeProfileCatalog(
                    SeedRepository.instance.allCatalogPrices,
                    _overrides,
                  );
                  for (final col in PricingEngine.fallbackDefaultColors) {
                    if (col == targetColor) continue;
                    final exists = merged.values.any(
                      (s) =>
                          s.brand.toUpperCase() == grp.brand.toUpperCase() &&
                          s.code == targetCode &&
                          s.color == col,
                    );
                    if (!exists) {
                      batch.add(
                        CustomPriceOverride(
                          skuKey: '${grp.brand}|$targetCode|$targetThick|$col',
                          brand: grp.brand,
                          code: targetCode,
                          name: grp.combinedNames,
                          thickness: targetThick,
                          color: col,
                          stockM: stockM,
                          pricePerBar: val,
                        ),
                      );
                    }
                  }
                }

                await AppDatabase.instance.upsertCustomPricesBatch(batch);
                if (ctx.mounted) Navigator.pop(ctx);
                await _reloadOverrides();
              },
              child: const Text('บันทึกราคา'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInlineGlassRateDialog(MaterialRateItem rate) async {
    final ctrl = TextEditingController(
      text: rate.effectivePrice.toStringAsFixed(2),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขราคากระจกต่อ ตร.ม.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rate.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ราคาต่อตารางเมตร (บาท / ตร.ม.)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (rate.customPrice != null)
            TextButton(
              onPressed: () async {
                await AppDatabase.instance
                    .deleteCustomMaterialRate(rate.rateKey);
                if (ctx.mounted) Navigator.pop(ctx);
                await _reloadOverrides();
              },
              child: const Text('คืนค่าเริ่มต้น'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v < 0) return;
              await AppDatabase.instance.upsertCustomMaterialRate(
                CustomMaterialRateOverride(
                  rateKey: rate.rateKey,
                  category: 'GLASS',
                  code: rate.code,
                  name: rate.name,
                  unit: 'ตร.ม.',
                  price: v,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _reloadOverrides();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInlineHardwareRateDialog(HardwareCostLine ln) async {
    final h = ln.item;
    final rate = ln.matchedRate;
    final unit = rate?.unit ??
        (h.unitOrNote.trim().isNotEmpty ? h.unitOrNote.trim() : 'ชิ้น');
    final rKey = rate?.rateKey ??
        (h.code.trim().isNotEmpty
            ? 'HW|${h.code.trim()}|${h.name.trim()}'
            : 'HW||${h.name.trim()}');
    final ctrl = TextEditingController(
      text: ln.unitPrice != null ? ln.unitPrice!.toStringAsFixed(2) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(h.code.isNotEmpty ? '${h.code} · ${h.name}' : h.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จำนวนที่ใช้ในงานนี้: ${h.displayQty}',
              style: const TextStyle(
                fontSize: 12.5,
                color: ToolkitColors.slateMuted,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'ราคาต่อหน่วย (บาท / $unit)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (rate?.customPrice != null)
            TextButton(
              onPressed: () async {
                await AppDatabase.instance.deleteCustomMaterialRate(rKey);
                if (ctx.mounted) Navigator.pop(ctx);
                await _reloadOverrides();
              },
              child: const Text('คืนค่าเริ่มต้น'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v < 0) return;
              await AppDatabase.instance.upsertCustomMaterialRate(
                CustomMaterialRateOverride(
                  rateKey: rKey,
                  category: 'HARDWARE',
                  code: h.code.trim(),
                  name: h.name.trim(),
                  unit: unit,
                  price: v,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _reloadOverrides();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _wasteCtrl.dispose();
    _profitCtrl.dispose();
    _laborCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final avail = PricingEngine.computeAvailability(
      barGroups: widget.barGroups,
      ormCatalog: SeedRepository.instance.allCatalogPrices,
      customOverrides: _overrides,
      preferredColor: _selectedColor.isNotEmpty ? _selectedColor : null,
    );
    final summary = _computeSummary();
    final glassRates = _mergedGlassRates();
    final activeGlassItem =
        glassRates.where((r) => r.rateKey == _selectedGlassKey).firstOrNull ??
            (glassRates.isNotEmpty ? glassRates.first : null);
    final hasAnyEstimated = summary.lines.any((l) => l.isEstimatedPrice);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        // Quick Action Pills (Compact single-row horizontal bar on phone screens)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: const Icon(Icons.price_change_outlined,
                    size: 16, color: ToolkitColors.royalBlue),
                label: const Text('ศูนย์จัดการ/อัปเดตราคา',
                    style: TextStyle(fontSize: 12.5)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomPriceScreen()),
                  );
                  _reloadOverrides();
                },
              ),
              const SizedBox(width: 6),
              ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: const Icon(Icons.architecture_rounded,
                    size: 16, color: ToolkitColors.royalBlue),
                label: const Text('เพิ่มชุดโปรไฟล์ใหม่',
                    style: TextStyle(fontSize: 12.5)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomSystemListScreen(),
                    ),
                  );
                  _reloadOverrides();
                },
              ),
              const SizedBox(width: 6),
              ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: const Icon(Icons.storefront_outlined,
                    size: 16, color: ToolkitColors.royalBlue),
                label: const Text('ข้อมูลร้านของฉัน',
                    style: TextStyle(fontSize: 12.5)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopInfoScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Controls Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ToolkitColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'วิธีคิดต้นทุนอลูมิเนียม',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SegmentedButton<PricingMode>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: PricingMode.actualLength,
                    label: Text('ตามระยะใช้จริง'),
                  ),
                  ButtonSegment(
                    value: PricingMode.fullBars,
                    label: Text('ซื้อเต็มเส้น'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (sel) {
                  final next = sel.first;
                  setState(() {
                    _mode = next;
                    if (next == PricingMode.fullBars) {
                      _wastePct = 0.0;
                      _wasteCtrl.text = '0';
                    } else {
                      _wastePct = 20.0;
                      _wasteCtrl.text = '20';
                    }
                  });
                  _notifyParent();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'เผื่อเสีย (%)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 68,
                    child: TextField(
                      controller: _wasteCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setState(() => _wastePct = parsed.clamp(0.0, 100.0));
                          _notifyParent();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _wastePct.clamp(0.0, 50.0),
                        min: 0,
                        max: 50,
                        divisions: 50,
                        label: '${_wastePct.round()}%',
                        onChanged: (v) {
                          setState(() {
                            _wastePct = v.roundToDouble();
                            _wasteCtrl.text = _wastePct.round().toString();
                          });
                          _notifyParent();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(
                          'thick_${_selectedThickness}_${avail.availableThicknesses.join(",")}'),
                      initialValue: avail.availableThicknesses
                              .contains(_selectedThickness)
                          ? _selectedThickness
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'ความหนาอลูมิเนียม',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: avail.availableThicknesses
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: avail.availableThicknesses.isEmpty
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _selectedThickness = v);
                                _notifyParent();
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(
                          'color_${_selectedColor}_${avail.availableColors.join(",")}'),
                      initialValue:
                          avail.availableColors.contains(_selectedColor)
                              ? _selectedColor
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'สีอลูมิเนียม',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: avail.availableColors
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: avail.availableColors.isEmpty
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedColor = v;
                                  _syncValidSelection(_overrides);
                                });
                                _notifyParent();
                              }
                            },
                    ),
                  ),
                ],
              ),
              if (summary.matchedCount < summary.totalCount) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'มีบางรหัสที่รอตั้งราคา: แตะที่แถวรายการด้านล่างเพื่อกรอกราคาต่อเส้นได้ทันที ระบบจะคำนวณรวมให้สดทันที',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ] else if (hasAnyEstimated) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ToolkitColors.softBlueBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ToolkitColors.royalBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'หมายเหตุ: บางรหัสใช้ราคาอ้างอิงประมาณการ คุณสามารถแตะที่แถวหน้าตัดใดก็ได้เพื่อปรับเป็นราคาซื้อจริงของร้านคุณทันที',
                    style: TextStyle(
                      fontSize: 12,
                      color: ToolkitColors.deepNavy,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Grand Total Cost & Suggested Selling Price Banner (Immediately visible on screen!)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ToolkitColors.slateDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_includeGlass || _includeHardware)
                              ? 'ต้นทุนวัสดุรวมสุทธิ'
                              : 'ต้นทุนเส้นอลูมิเนียมรวม',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        Text(
                          'จับคู่ราคาเส้นได้ ${summary.matchedCount}/${summary.totalCount} รายการ',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF93C5FD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '฿${_bahtFmt.format(summary.totalCost)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_includeGlass || _includeHardware) ...[
                const Divider(color: Color(0xFF334155), height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text(
                      'อลูมิเนียม: ฿${_bahtFmt.format(summary.aluminumCost)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFE2E8F0)),
                    ),
                    if (_includeGlass)
                      Text(
                        'กระจก (${summary.totalGlassAreaSqM.toStringAsFixed(2)} ตร.ม.): ฿${_bahtFmt.format(summary.glassCost)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFBAE6FD)),
                      ),
                    if (_includeHardware)
                      Text(
                        'อุปกรณ์: ฿${_bahtFmt.format(summary.hardwareCost)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFFDE68A)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary.laborCost > 0 || summary.profitAmount > 0) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          if (summary.laborCost > 0)
                            Text(
                              '+ ค่าแรง: ฿${_bahtFmt.format(summary.laborCost)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFCD34D),
                              ),
                            ),
                          if (summary.profitAmount > 0)
                            Text(
                              '+ กำไร (${_fmtNumInput(summary.profitPercent)}%): ฿${_bahtFmt.format(summary.profitAmount)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF86EFAC),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ราคาเสนอขายแนะนำสุทธิ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                summary.profitBaseMode ==
                                        ProfitBaseMode.materialAndLabor
                                    ? 'รวมต้นทุน + ค่าแรง + กำไรจากยอดรวม'
                                    : 'รวมต้นทุน + กำไรจากวัสดุ + ค่าแรง',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '฿${_bahtFmt.format(summary.suggestedSellingPrice)}',
                          key: const ValueKey('pricing_suggested_selling_price'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Compact Profit % & Labor Cost Controls Card (Right underneath Summary Banner!)
        Container(
          padding: const EdgeInsets.all(11),
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
                      'ปรับเปอร์เซ็นต์กำไร (%) และค่าแรงติดตั้ง',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _saveMarkupAsShopDefault,
                    icon: const Icon(Icons.bookmark_added_outlined, size: 14),
                    label: const Text(
                      'จำค่าตั้งต้นร้าน',
                      style:
                          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Profit % inline TextField + Slider
              Row(
                children: [
                  const Text(
                    'กำไร',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 68,
                    child: TextField(
                      key: const ValueKey('pricing_profit_pct_field'),
                      controller: _profitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed != null) {
                          setState(
                              () => _profitPct = parsed.clamp(0.0, 200.0));
                          _notifyParent();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        key: const ValueKey('pricing_profit_pct_slider'),
                        value: _profitPct.clamp(0.0, 100.0),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '${_profitPct.round()}%',
                        onChanged: (v) {
                          setState(() {
                            _profitPct = v.roundToDouble();
                            _profitCtrl.text = _profitPct.round().toString();
                          });
                          _notifyParent();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...[15.0, 20.0, 25.0, 30.0, 40.0, 50.0].map((pct) {
                      final selected = (_profitPct - pct).abs() < 0.01;
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          label: Text('${pct.round()}%',
                              style: const TextStyle(fontSize: 11.5)),
                          selected: selected,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) {
                            setState(() {
                              _profitPct = pct;
                              _profitCtrl.text = pct.round().toString();
                            });
                            _notifyParent();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: const Text(
                        'คิดกำไรจากต้นทุนวัสดุ',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      selected: _profitBaseMode == ProfitBaseMode.materialOnly,
                      selectedColor: ToolkitColors.softBlueBg,
                      onSelected: (_) {
                        setState(() =>
                            _profitBaseMode = ProfitBaseMode.materialOnly);
                        _notifyParent();
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: const Text(
                        'คิดกำไรรวมค่าแรงด้วย',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      selected:
                          _profitBaseMode == ProfitBaseMode.materialAndLabor,
                      selectedColor: ToolkitColors.softBlueBg,
                      onSelected: (_) {
                        setState(() =>
                            _profitBaseMode = ProfitBaseMode.materialAndLabor);
                        _notifyParent();
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 12),

              // Labor Cost Mode: Row 1 = all 3 modes 100% visible on phone; Row 2 = input + quick presets
              Row(
                children: [
                  const Text(
                    'ค่าแรง',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          label: const Text('บาท/ตร.ม.',
                              style: TextStyle(fontSize: 11.5)),
                          selected: _laborMode == LaborCostMode.perSqM,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) {
                            setState(() => _laborMode = LaborCostMode.perSqM);
                            _notifyParent();
                          },
                        ),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          label: const Text('เหมาทั้งงาน (บาท)',
                              style: TextStyle(fontSize: 11.5)),
                          selected: _laborMode == LaborCostMode.flatBaht,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) {
                            setState(() => _laborMode = LaborCostMode.flatBaht);
                            _notifyParent();
                          },
                        ),
                        ChoiceChip(
                          key: const ValueKey('pricing_labor_pct_chip'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          label: const Text('% ค่าของ',
                              style: TextStyle(fontSize: 11.5)),
                          selected:
                              _laborMode == LaborCostMode.percentOfMaterial,
                          selectedColor: ToolkitColors.softBlueBg,
                          onSelected: (_) {
                            setState(() {
                              _laborMode = LaborCostMode.percentOfMaterial;
                              if (_laborRate > 200.0) {
                                _laborRate = 20.0;
                                _laborCtrl.text = '20';
                              }
                            });
                            _notifyParent();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: TextField(
                      key: const ValueKey('pricing_labor_rate_field'),
                      controller: _laborCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed != null && parsed >= 0) {
                          setState(() {
                            _laborRate =
                                _laborMode == LaborCostMode.percentOfMaterial
                                    ? parsed.clamp(0.0, 200.0)
                                    : parsed;
                          });
                          _notifyParent();
                        } else if (v.trim().isEmpty) {
                          setState(() => _laborRate = 0.0);
                          _notifyParent();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (_laborMode == LaborCostMode.perSqM
                                ? const [0.0, 300.0, 400.0, 500.0, 600.0]
                                : (_laborMode == LaborCostMode.percentOfMaterial
                                    ? const [0.0, 10.0, 15.0, 20.0, 25.0, 30.0]
                                    : const [
                                        0.0,
                                        1000.0,
                                        2000.0,
                                        3000.0,
                                        5000.0,
                                      ]))
                            .map((rate) {
                          final selected = (_laborRate - rate).abs() < 0.01;
                          final lbl = rate == 0
                              ? 'ไม่คิด'
                              : (_laborMode == LaborCostMode.percentOfMaterial
                                  ? '${rate.round()}%'
                                  : '฿${NumberFormat('#,##0', 'en_US').format(rate)}');
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(lbl,
                                  style: const TextStyle(fontSize: 11.5)),
                              selected: selected,
                              selectedColor: ToolkitColors.softBlueBg,
                              onSelected: (_) {
                                setState(() {
                                  _laborRate = rate;
                                  _laborCtrl.text = _fmtNumInput(rate);
                                });
                                _notifyParent();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _laborMode == LaborCostMode.perSqM
                    ? (summary.laborCost > 0
                        ? 'พื้นที่ช่องเปิดรวม ${summary.openingAreaSqM.toStringAsFixed(2)} ตร.ม. × ฿${_fmtNumInput(_laborRate)} = ค่าแรงรวม ฿${_bahtFmt.format(summary.laborCost)}'
                        : 'พื้นที่ช่องเปิดรวม ${summary.openingAreaSqM.toStringAsFixed(2)} ตร.ม. · ยังไม่รวมค่าแรง')
                    : (_laborMode == LaborCostMode.percentOfMaterial
                        ? (summary.laborCost > 0
                            ? 'ต้นทุนวัสดุ ฿${_bahtFmt.format(summary.totalCost)} × ${_fmtNumInput(_laborRate)}% = ค่าแรงรวม ฿${_bahtFmt.format(summary.laborCost)}'
                            : 'คิดค่าแรงเป็น % ของต้นทุนวัสดุ · ยังไม่รวมค่าแรง')
                        : (summary.laborCost > 0
                            ? 'ค่าแรงเหมาทั้งงานรวม ฿${_bahtFmt.format(summary.laborCost)}'
                            : 'ยังไม่รวมค่าแรงเหมาทั้งงาน')),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ToolkitColors.slateMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 1. Aluminum Breakdown Table (1-Tap Price Edit + Swap/Add Part!)
        Container(
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
                  const Expanded(
                    child: Text(
                      '1. รายละเอียดต้นทุนเส้นอลูมิเนียม',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onAddAluminum != null)
                    TextButton.icon(
                      key: const ValueKey('tab4_add_alu'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: widget.onAddAluminum,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text(
                        'เพิ่มเส้น',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Text(
                      'แตะแถวเพื่อแก้ราคา',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ToolkitColors.royalBlue,
                      ),
                    ),
                ],
              ),
              const Divider(),
              ...summary.lines.map((ln) {
                final g = ln.group;
                final usedM = (g.exactCutSumMm / 1000.0).toStringAsFixed(2);
                final profImg =
                    AluproImageRegistry.instance.resolveProfileAsset(
                  code: g.code,
                  name: g.combinedNames,
                  brandKey: g.brand,
                );
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openInlineProfilePriceDialog(ln),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (profImg != null) ...[
                          AluproThumbnail(
                            assetPath: profImg,
                            width: 48,
                            height: 36,
                            showZoomBadge: true,
                            zoomTitle: '${g.code} · ${g.combinedNames}',
                            zoomSubtitle:
                                '${ln.matchNote} · ใช้รวม $usedM ม. (${g.totalBars} เส้น)',
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${g.code} · ${g.combinedNames}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${ln.matchNote} · ใช้รวม $usedM ม. (${g.totalBars} เส้น)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ln.isMatched
                                      ? (ln.isCustomPrice
                                          ? ToolkitColors.vipGoldText
                                          : ToolkitColors.slateMuted)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ln.isMatched
                                      ? '฿${_bahtFmt.format(ln.lineCost!)}'
                                      : 'แตะตั้งราคา',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ln.isMatched
                                        ? ToolkitColors.royalBlue
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: ToolkitColors.slateMuted,
                                ),
                              ],
                            ),
                            if (ln.unitPricePerBar != null)
                              Text(
                                '฿${_bahtFmt.format(ln.unitPricePerBar!)} / เส้น',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ToolkitColors.slateMuted,
                                ),
                              ),
                          ],
                        ),
                        if (widget.onEditProfileGroup != null) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: 'เปลี่ยน / ลบหน้าตัดนี้',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30),
                            onPressed: () => widget.onEditProfileGroup!(g),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: ToolkitColors.royalBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // 2. Glass Costing Card
        if (widget.glasses.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
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
                    const Expanded(
                      child: Text(
                        '2. ต้นทุนกระจกสั่งตัด',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _includeGlass
                          ? '฿${_bahtFmt.format(summary.glassCost)}'
                          : 'ไม่รวม',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _includeGlass
                            ? ToolkitColors.royalBlue
                            : ToolkitColors.slateMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: _includeGlass,
                      onChanged: (v) {
                        setState(() => _includeGlass = v);
                        _notifyParent();
                      },
                    ),
                  ],
                ),
                if (_includeGlass && glassRates.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey('gls_$_selectedGlassKey'),
                          initialValue: glassRates
                                  .any((r) => r.rateKey == _selectedGlassKey)
                              ? _selectedGlassKey
                              : glassRates.first.rateKey,
                          decoration: const InputDecoration(
                            labelText: 'เลือกชนิดและความหนากระจก',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: glassRates
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.rateKey,
                                  child: Text(
                                    '${r.name} · ฿${r.effectivePrice.toStringAsFixed(0)}/ตร.ม.',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedGlassKey = v);
                              _notifyParent();
                            }
                          },
                        ),
                      ),
                      if (activeGlassItem != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openInlineGlassRateDialog(activeGlassItem),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('แก้ราคา'),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 18),
                  ...List.generate(summary.glassLines.length, (gi) {
                    final gl = summary.glassLines[gi];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onEditGlass != null
                          ? () => widget.onEditGlass!(gi, gl.item)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gl.item.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    gl.note,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: ToolkitColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              gl.lineCost != null
                                  ? '฿${_bahtFmt.format(gl.lineCost!)}'
                                  : 'วัดหน้างาน',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: ToolkitColors.slateDark,
                              ),
                            ),
                            if (widget.onEditGlass != null) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: ToolkitColors.royalBlue,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  if (widget.onAddGlass != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('tab4_add_glass'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: widget.onAddGlass,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text(
                          'เพิ่มกระจกนอกสูตร',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],

        // 3. Hardware Costing Card (1-Tap Price Edit + Swap/Add Part!)
        if (widget.hardware.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
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
                    const Expanded(
                      child: Text(
                        '3. ต้นทุนอุปกรณ์ประกอบ',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _includeHardware
                          ? '฿${_bahtFmt.format(summary.hardwareCost)}'
                          : 'ไม่รวม',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _includeHardware
                            ? ToolkitColors.royalBlue
                            : ToolkitColors.slateMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: _includeHardware,
                      onChanged: (v) {
                        setState(() => _includeHardware = v);
                        _notifyParent();
                      },
                    ),
                  ],
                ),
                if (_includeHardware) ...[
                  const Divider(height: 14),
                  ...List.generate(summary.hardwareLines.length, (hi) {
                    final hl = summary.hardwareLines[hi];
                    final h = hl.item;
                    final title =
                        h.code.isNotEmpty ? '${h.code} · ${h.name}' : h.name;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _openInlineHardwareRateDialog(hl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    hl.note,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: ToolkitColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hl.lineCost != null
                                      ? '฿${_bahtFmt.format(hl.lineCost!)}'
                                      : 'ตามหน้างาน',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: hl.lineCost != null
                                        ? ToolkitColors.slateDark
                                        : ToolkitColors.slateMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: ToolkitColors.slateMuted,
                                ),
                              ],
                            ),
                            if (widget.onEditHardware != null) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'เปลี่ยน / ลบอุปกรณ์นี้',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                onPressed: () =>
                                    widget.onEditHardware!(hi, h),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 17,
                                  color: ToolkitColors.royalBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  if (widget.onAddHardware != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('tab4_add_hw'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: widget.onAddHardware,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text(
                          'เพิ่มอุปกรณ์นอกสูตร',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],

        // Quick Add Buttons if Glass or Hardware card is currently empty
        if ((widget.glasses.isEmpty && widget.onAddGlass != null) ||
            (widget.hardware.isEmpty && widget.onAddHardware != null)) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (widget.glasses.isEmpty && widget.onAddGlass != null)
                OutlinedButton.icon(
                  onPressed: widget.onAddGlass,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('เพิ่มกระจกนอกสูตร'),
                ),
              if (widget.hardware.isEmpty && widget.onAddHardware != null)
                OutlinedButton.icon(
                  onPressed: widget.onAddHardware,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('เพิ่มอุปกรณ์นอกสูตร'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// PDF Preview & Share Screen (Single Cut & Project PDF)
// =============================================================================
class PdfPreviewAndShareScreen extends StatelessWidget {
  final String title;
  final String fileName;
  final Uint8List pdfBytes;

  const PdfPreviewAndShareScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'แชร์ PDF',
            onPressed: () {
              Printing.sharePdf(bytes: pdfBytes, filename: fileName);
            },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'พิมพ์ / บันทึก PDF',
            onPressed: () {
              Printing.layoutPdf(
                name: fileName,
                onLayout: (_) async => pdfBytes,
              );
            },
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        pdfFileName: fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}

// =============================================================================
// 3-Tab Price Management & Bulk Update Center (ศูนย์จัดการและอัปเดตราคา)
// =============================================================================
class CustomPriceScreen extends StatefulWidget {
  final int initialTabIndex;

  const CustomPriceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CustomPriceScreen> createState() => _CustomPriceScreenState();
}

class _CustomPriceScreenState extends State<CustomPriceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _matSearchCtrl = TextEditingController();

  String _brandFilter = 'ทั้งหมด';
  String _thickFilter = 'ทั้งหมด';
  String _colorFilter = 'ทั้งหมด';
  String _stockFilter = 'ทั้งหมด';
  String _matCategoryFilter = 'ทั้งหมด'; // 'ทั้งหมด' | 'GLASS' | 'HARDWARE'

  // Bulk Update Controls
  String _bulkBrand = 'ทั้งหมด';
  String _bulkColor = 'ทั้งหมด';
  final TextEditingController _bulkPctCtrl = TextEditingController(text: '5');
  final TextEditingController _bulkFlatCtrl = TextEditingController(text: '0');

  Map<String, CustomPriceOverride> _overrides = {};
  Map<String, CustomMaterialRateOverride> _matOverrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _load();
  }

  Future<void> _load() async {
    final ov = await AppDatabase.instance.getAllCustomPrices();
    final matOv = await AppDatabase.instance.getAllCustomMaterialRates();
    if (!mounted) return;
    setState(() {
      _overrides = ov;
      _matOverrides = matOv;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _matSearchCtrl.dispose();
    _bulkPctCtrl.dispose();
    _bulkFlatCtrl.dispose();
    super.dispose();
  }

  List<OrmPriceSku> _allMergedProfiles() {
    return PricingEngine.mergeProfileCatalog(
      SeedRepository.instance.allCatalogPrices,
      _overrides,
    ).values.toList();
  }

  List<String> _availableBrands(List<OrmPriceSku> all) {
    final base = <String>[
      'ALUMET',
      'ORM',
      'MARKET',
      'SCHIMMER',
      'SMART_PLUS',
      'FUJI',
      'UAI',
      'ALUFRAME',
    ];
    for (final s in all) {
      if (!base.contains(s.brand)) {
        base.add(s.brand);
      }
    }
    return ['ทั้งหมด', ...base];
  }

  List<String> _availableColors(List<OrmPriceSku> all) {
    final cols = <String>{...PricingEngine.standardColors};
    for (final s in all) {
      cols.add(s.color);
    }
    return ['ทั้งหมด', ...cols];
  }

  List<OrmPriceSku> _filteredProfiles(List<OrmPriceSku> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((s) {
      if (_brandFilter != 'ทั้งหมด' && s.brand != _brandFilter) return false;
      if (_thickFilter != 'ทั้งหมด' && s.thickness != _thickFilter) {
        return false;
      }
      if (_colorFilter != 'ทั้งหมด' && s.color != _colorFilter) return false;
      if (_stockFilter == 'มีสต็อก' && !s.inStock) return false;
      if (_stockFilter == 'หมดสต็อก' && s.inStock) return false;
      if (q.isNotEmpty) {
        return s.code.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.brand.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<MaterialRateItem> _filteredMaterials() {
    final glasses = PricingEngine.mergeMaterialRates(
      SeedRepository.instance.glassRates,
      _matOverrides,
      category: 'GLASS',
    );
    final hws = PricingEngine.mergeMaterialRates(
      SeedRepository.instance.hardwareRates,
      _matOverrides,
      category: 'HARDWARE',
    );
    final combined = <MaterialRateItem>[
      if (_matCategoryFilter == 'ทั้งหมด' || _matCategoryFilter == 'GLASS')
        ...glasses,
      if (_matCategoryFilter == 'ทั้งหมด' || _matCategoryFilter == 'HARDWARE')
        ...hws,
    ];
    final q = _matSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return combined;
    return combined
        .where(
          (m) =>
              m.code.toLowerCase().contains(q) ||
              m.name.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _editSkuDialog(OrmPriceSku sku) async {
    final priceCtrl =
        TextEditingController(text: sku.effectivePrice.toStringAsFixed(2));
    bool inStock = sku.inStock;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('${sku.brand} · ${sku.code}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sku.name}\n${sku.thickness} · ${sku.color} · ${sku.stockM} ม.',
                style: const TextStyle(
                    fontSize: 13, color: ToolkitColors.slateMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ราคาต่อเส้น (บาท)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('มีของในสต็อก'),
                value: inStock,
                onChanged: (v) => setModalState(() => inStock = v),
              ),
            ],
          ),
          actions: [
            if (sku.customPrice != null)
              TextButton(
                onPressed: () async {
                  await AppDatabase.instance.deleteCustomPrice(sku.skuKey);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('คืนค่าราคาตั้งต้น'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final pVal = double.tryParse(priceCtrl.text.trim());
                if (pVal == null || pVal < 0) return;
                await AppDatabase.instance.upsertCustomPrice(
                  CustomPriceOverride(
                    skuKey: sku.skuKey,
                    brand: sku.brand,
                    code: sku.code,
                    name: sku.name,
                    thickness: sku.thickness,
                    color: sku.color,
                    stockM: sku.stockM,
                    pricePerBar: pVal,
                    inStock: inStock,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomSkuDialog(List<String> brandOptions) async {
    final cleanBrands = brandOptions.where((b) => b != 'ทั้งหมด').toList();
    String brand = cleanBrands.contains('ALUMET') ? 'ALUMET' : cleanBrands.first;
    final customBrandCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String thick = '1.2 มม.';
    String color = 'อบดำ (8816)';
    final stockCtrl = TextEditingController(text: '6.4');
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('เพิ่มรหัสราคาเส้นอลูมิเนียม'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: brand,
                  decoration: const InputDecoration(
                    labelText: 'ผู้ผลิต / แบรนด์',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    ...cleanBrands
                        .map((b) => DropdownMenuItem(value: b, child: Text(b))),
                    const DropdownMenuItem(
                      value: '__CUSTOM__',
                      child: Text('+ พิมพ์ชื่อแบรนด์ใหม่'),
                    ),
                  ],
                  onChanged: (v) => setModal(() => brand = v ?? 'ALUMET'),
                ),
                if (brand == '__CUSTOM__') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customBrandCtrl,
                    decoration: const InputDecoration(
                      labelText: 'รหัสแบรนด์ใหม่ (ภาษาอังกฤษ/ไทย) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'รหัสหน้าตัด *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อหน้าตัด',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: thick,
                  decoration: const InputDecoration(
                    labelText: 'ความหนา',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: PricingEngine.standardThicknesses
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setModal(() => thick = v ?? '1.2 มม.'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: PricingEngine.standardColors.contains(color)
                      ? color
                      : PricingEngine.standardColors.first,
                  decoration: const InputDecoration(
                    labelText: 'สี / ผิว',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: PricingEngine.standardColors
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setModal(() => color = v ?? 'ตัวดิบ MILL'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ยาว (ม./เส้น)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ราคา/เส้น (฿) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final effBrand = brand == '__CUSTOM__'
                    ? customBrandCtrl.text.trim().toUpperCase()
                    : brand;
                final cd = codeCtrl.text.trim();
                final pr = double.tryParse(priceCtrl.text.trim());
                final stM = double.tryParse(stockCtrl.text.trim()) ?? 6.4;
                if (effBrand.isEmpty || cd.isEmpty || pr == null) return;
                final skuKey = '$effBrand|$cd|$thick|$color';
                await AppDatabase.instance.upsertCustomPrice(
                  CustomPriceOverride(
                    skuKey: skuKey,
                    brand: effBrand,
                    code: cd,
                    name: nameCtrl.text.trim().isEmpty
                        ? cd
                        : nameCtrl.text.trim(),
                    thickness: thick,
                    color: color,
                    stockM: stM,
                    pricePerBar: pr,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMaterialRateDialog(MaterialRateItem item) async {
    final priceCtrl =
        TextEditingController(text: item.effectivePrice.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.code.isNotEmpty ? '${item.code} · ${item.name}' : item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'หมวด: ${item.category == 'GLASS' ? 'กระจก' : 'อุปกรณ์ประกอบ'} · หน่วย: ${item.unit}',
              style: const TextStyle(
                fontSize: 12.5,
                color: ToolkitColors.slateMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'ราคาต่อ ${item.unit} (บาท)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (item.customPrice != null)
            TextButton(
              onPressed: () async {
                await AppDatabase.instance
                    .deleteCustomMaterialRate(item.rateKey);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('คืนค่าเริ่มต้น'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(priceCtrl.text.trim());
              if (v == null || v < 0) return;
              await AppDatabase.instance.upsertCustomMaterialRate(
                CustomMaterialRateOverride(
                  rateKey: item.rateKey,
                  category: item.category,
                  code: item.code,
                  name: item.name,
                  unit: item.unit,
                  price: v,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomMaterialDialog() async {
    String cat = 'GLASS';
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'ตร.ม.');
    final priceCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('เพิ่มราคากระจก / อุปกรณ์ใหม่'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: const InputDecoration(
                    labelText: 'หมวดวัสดุ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'GLASS', child: Text('กระจก')),
                    DropdownMenuItem(
                        value: 'HARDWARE', child: Text('อุปกรณ์ฮาร์ดแวร์')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setModal(() {
                        cat = v;
                        unitCtrl.text = v == 'GLASS' ? 'ตร.ม.' : 'ชิ้น';
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'รหัสวัสดุ (ถ้ามี)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกระจก หรือ ชื่ออุปกรณ์ *',
                    hintText: 'เช่น กระจกเขียวตัดแสง 10 มม.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'หน่วยนับ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ราคาต่อหน่วย (฿) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final nm = nameCtrl.text.trim();
                final pr = double.tryParse(priceCtrl.text.trim());
                if (nm.isEmpty || pr == null) return;
                final cd = codeCtrl.text.trim();
                final un = unitCtrl.text.trim().isEmpty
                    ? 'ชิ้น'
                    : unitCtrl.text.trim();
                final rKey = cat == 'GLASS'
                    ? 'GLASS|$nm'
                    : (cd.isNotEmpty ? 'HW|$cd|$nm' : 'HW||$nm');
                await AppDatabase.instance.upsertCustomMaterialRate(
                  CustomMaterialRateOverride(
                    rateKey: rKey,
                    category: cat,
                    code: cd,
                    name: nm,
                    unit: un,
                    price: pr,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importBackupDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('นำเข้าข้อมูลตารางราคา (.json)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'วางข้อมูลสำรองตารางราคา (.json) ที่คัดลอกไว้ ระบบจะอัปเดตราคาเส้นอลูมิเนียม กระจก และอุปกรณ์ทั้งหมดให้ทันที',
              style: TextStyle(fontSize: 12.5, color: ToolkitColors.slateMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{ "type": "akkaraphon_price_backup", ... }',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final clip = await Clipboard.getData('text/plain');
              if (clip?.text != null) ctrl.text = clip!.text!;
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
                final res = await AppDatabase.instance
                    .importPricesBackupJson(ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (mounted) {
                  showToolkitSnackBar(
                    context,
                    'นำเข้าสำเร็จ: อลูมิเนียม ${res.profilesImported} รายการ, กระจก/อุปกรณ์ ${res.materialsImported} รายการ',
                  );
                }
              } catch (_) {
                if (mounted) {
                  showToolkitSnackBar(context, 'รูปแบบไฟล์ JSON ไม่ถูกต้อง');
                }
              }
            },
            child: const Text('นำเข้าราคา'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMerged = _loading ? <OrmPriceSku>[] : _allMergedProfiles();
    final brandOptions = _availableBrands(allMerged);
    final colorOptions = _availableColors(allMerged);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์จัดการและอัปเดตราคา'),
        actions: [
          IconButton(
            tooltip: 'เพิ่มรายการราคาใหม่',
            onPressed: () {
              if (_tabCtrl.index == 1) {
                _addCustomMaterialDialog();
              } else {
                _addCustomSkuDialog(brandOptions);
              }
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: ToolkitColors.royalBlue,
          unselectedLabelColor: ToolkitColors.slateMuted,
          indicatorColor: ToolkitColors.royalBlue,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'เส้นอลูมิเนียม'),
            Tab(text: 'กระจก & อุปกรณ์'),
            Tab(text: 'ปรับราคาทั้งชุด'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTab1Aluminum(allMerged, brandOptions, colorOptions),
                _buildTab2GlassAndHardware(),
                _buildTab3BulkAndBackup(allMerged, brandOptions, colorOptions),
              ],
            ),
    );
  }

  Widget _buildTab1Aluminum(
    List<OrmPriceSku> allMerged,
    List<String> brandOptions,
    List<String> colorOptions,
  ) {
    final items = _filteredProfiles(allMerged);
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText:
                      'ค้นหารหัสหน้าตัด หรือชื่อโปรไฟล์ (เช่น SS-X110, 801-01)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _miniFilterDropdown(
                      label: 'ผู้ผลิต',
                      value: brandOptions.contains(_brandFilter)
                          ? _brandFilter
                          : 'ทั้งหมด',
                      options: brandOptions,
                      onChanged: (v) => setState(() => _brandFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _miniFilterDropdown(
                      label: 'ความหนา',
                      value: _thickFilter,
                      options: [
                        'ทั้งหมด',
                        ...PricingEngine.standardThicknesses,
                      ],
                      onChanged: (v) => setState(() => _thickFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _miniFilterDropdown(
                      label: 'สี/ผิว',
                      value: colorOptions.contains(_colorFilter)
                          ? _colorFilter
                          : 'ทั้งหมด',
                      options: colorOptions,
                      onChanged: (v) => setState(() => _colorFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _miniFilterDropdown(
                      label: 'สต็อก',
                      value: _stockFilter,
                      options: const ['ทั้งหมด', 'มีสต็อก', 'หมดสต็อก'],
                      onChanged: (v) => setState(() => _stockFilter = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final s = items[i];
              final skuImg = AluproImageRegistry.instance.resolveProfileAsset(
                code: s.code,
                name: s.name,
                brandKey: s.brand,
              );
              final statusLabel = s.customPrice != null
                  ? 'ราคาที่แก้เอง (ตั้งต้น ฿${_bahtFmt.format(s.factoryPrice)})'
                  : (s.isEstimated
                      ? 'ราคาประมาณการ — แตะเพื่อแก้ราคาจริง'
                      : 'ราคาอ้างอิงโรงงาน');
              final statusColor = s.customPrice != null
                  ? ToolkitColors.vipGoldText
                  : (s.isEstimated
                      ? const Color(0xFFB45309)
                      : ToolkitColors.slateMuted);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editSkuDialog(s),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ToolkitColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      if (skuImg != null) ...[
                        AluproThumbnail(
                          assetPath: skuImg,
                          width: 48,
                          height: 36,
                          showZoomBadge: true,
                          zoomTitle: '${s.brand} · ${s.code}',
                          zoomSubtitle:
                              '${s.name} (${s.thickness} · ${s.color})',
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.brand} · ${s.code}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: ToolkitColors.royalBlue,
                              ),
                            ),
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${s.thickness} · ${s.color} · ${s.stockM} ม.',
                              style: const TextStyle(
                                fontSize: 12,
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
                            '฿${_bahtFmt.format(s.effectivePrice)} / เส้น',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ToolkitColors.slateDark,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
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
    );
  }

  Widget _buildTab2GlassAndHardware() {
    final items = _filteredMaterials();
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              TextField(
                controller: _matSearchCtrl,
                decoration: InputDecoration(
                  hintText:
                      'ค้นหากระจก หรือ อุปกรณ์ประกอบ (เช่น กระจกเขียว, ล้อ, มือจับ)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in const [
                    ('ทั้งหมด', 'ทั้งหมด'),
                    ('GLASS', 'กระจก (บาท/ตร.ม.)'),
                    ('HARDWARE', 'อุปกรณ์ประกอบ'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.$2),
                        selected: _matCategoryFilter == entry.$1,
                        selectedColor: ToolkitColors.softBlueBg,
                        onSelected: (_) =>
                            setState(() => _matCategoryFilter = entry.$1),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = items[i];
              final isGlass = m.category == 'GLASS';
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editMaterialRateDialog(m),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ToolkitColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isGlass
                              ? const Color(0xFFE0F2FE)
                              : ToolkitColors.softBlueBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          isGlass
                              ? Icons.crop_portrait_rounded
                              : Icons.handyman_outlined,
                          size: 20,
                          color: ToolkitColors.royalBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.code.isNotEmpty
                                  ? '${m.code} · ${m.name}'
                                  : m.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isGlass
                                  ? 'หมวดกระจกสั่งตัด · คิดตามพื้นที่จริง'
                                  : 'หมวดอุปกรณ์ฮาร์ดแวร์ · หน่วย ${m.unit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ToolkitColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '฿${_bahtFmt.format(m.effectivePrice)} / ${m.unit}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ToolkitColors.slateDark,
                            ),
                          ),
                          Text(
                            m.customPrice != null
                                ? 'ราคาที่แก้เอง'
                                : (m.isEstimated
                                    ? 'ราคาประมาณการ'
                                    : 'ราคามาตรฐาน'),
                            style: TextStyle(
                              fontSize: 11,
                              color: m.customPrice != null
                                  ? ToolkitColors.vipGoldText
                                  : ToolkitColors.slateMuted,
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
    );
  }

  Widget _buildTab3BulkAndBackup(
    List<OrmPriceSku> allMerged,
    List<String> brandOptions,
    List<String> colorOptions,
  ) {
    final matchCount = allMerged.where((s) {
      if (_bulkBrand != 'ทั้งหมด' && s.brand != _bulkBrand) return false;
      if (_bulkColor != 'ทั้งหมด' && s.color != _bulkColor) return false;
      return true;
    }).length;

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        // Card 1: Bulk % / Flat Baht Adjustment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: ToolkitColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded,
                      color: ToolkitColors.royalBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ปรับราคาเส้นอลูมิเนียมขึ้น / ลง ทั้งชุด',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ToolkitColors.slateDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'ใช้กรณีโรงงานประกาศปรับราคาอลูมิเนียมขึ้นหรือลงทั้งแบรนด์หรือเฉพาะสี ระบบจะคำนวณราคาใหม่ให้ครบทุกรหัสในคลิกเดียว',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: ToolkitColors.slateMuted,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('bb_$_bulkBrand'),
                initialValue:
                    brandOptions.contains(_bulkBrand) ? _bulkBrand : 'ทั้งหมด',
                decoration: const InputDecoration(
                  labelText: 'เลือกแบรนด์ที่ต้องการปรับราคา',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: brandOptions
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _bulkBrand = v);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('bc_$_bulkColor'),
                initialValue:
                    colorOptions.contains(_bulkColor) ? _bulkColor : 'ทั้งหมด',
                decoration: const InputDecoration(
                  labelText: 'เลือกสี / ผิว',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: colorOptions
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _bulkColor = v);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in const [
                    ('+3%', '3'),
                    ('+5%', '5'),
                    ('+10%', '10'),
                    ('-3%', '-3'),
                    ('-5%', '-5'),
                  ])
                    ActionChip(
                      label: Text(preset.$1),
                      onPressed: () =>
                          setState(() => _bulkPctCtrl.text = preset.$2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bulkPctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ปรับเป็นเปอร์เซ็นต์ (%)',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bulkFlatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'บวก/ลบเพิ่ม (บาท/เส้น)',
                        suffixText: '฿',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ToolkitColors.softBlueBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'รายการที่จะถูกปรับราคา: $matchCount รายการ (${_bulkBrand == 'ทั้งหมด' ? 'ทุกแบรนด์' : _bulkBrand})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.deepNavy,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ToolkitColors.royalBlue,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: matchCount == 0
                      ? null
                      : () async {
                          final pct =
                              double.tryParse(_bulkPctCtrl.text.trim()) ?? 0.0;
                          final flat =
                              double.tryParse(_bulkFlatCtrl.text.trim()) ?? 0.0;
                          final updated = await AppDatabase.instance
                              .applyBulkPriceAdjustment(
                            currentMergedSkus: allMerged,
                            brandFilter: _bulkBrand,
                            colorFilter: _bulkColor,
                            percentDelta: pct,
                            flatBahtDelta: flat,
                          );
                          await _load();
                          if (mounted) {
                            showToolkitSnackBar(
                              context,
                              'อัปเดตราคาสำเร็จ $updated รายการ',
                            );
                          }
                        },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text(
                    'ยืนยันอัปเดตราคาทั้งชุด',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final removed = await AppDatabase.instance
                        .resetBrandCustomPrices(brandFilter: _bulkBrand);
                    await _load();
                    if (mounted) {
                      showToolkitSnackBar(
                        context,
                        'คืนค่าราคาตั้งต้นแล้ว ($removed รายการ)',
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(
                    _bulkBrand == 'ทั้งหมด'
                        ? 'คืนค่าราคาตั้งต้นทุกแบรนด์'
                        : 'คืนค่าราคาตั้งต้นเฉพาะ $_bulkBrand',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: Export / Import Backup JSON
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: ToolkitColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_alt_rounded, color: ToolkitColors.royalBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'สำรองและส่งต่อตารางราคาข้ามเครื่อง (.json)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ToolkitColors.slateDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'คัดลอกตารางราคาที่แก้ไขไว้ส่งทาง LINE หรือบันทึกเก็บไว้ แล้วกดนำเข้าที่มือถือ/แท็บเล็ตอีกเครื่องในร้านได้ทันที',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: ToolkitColors.slateMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final jsonStr = await AppDatabase.instance
                            .exportPricesBackupJson();
                        await Clipboard.setData(ClipboardData(text: jsonStr));
                        if (mounted) {
                          showToolkitSnackBar(
                            context,
                            'คัดลอกข้อมูลสำรองราคา (.json) ลงคลิปบอร์ดแล้ว',
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('ส่งออก (.json)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _importBackupDialog,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('นำเข้า (.json)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ToolkitColors.bgScaffold,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text('$label: $o',
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Shop Info Screen (ข้อมูลร้านของฉัน — 7 Fields + Logo <= 2 MB)
// =============================================================================
class ShopInfoScreen extends StatefulWidget {
  const ShopInfoScreen({super.key});

  @override
  State<ShopInfoScreen> createState() => _ShopInfoScreenState();
}

class _ShopInfoScreenState extends State<ShopInfoScreen> {
  final _shopNameCtrl = TextEditingController();
  final _docTitleCtrl = TextEditingController(text: 'ใบเสนอราคา');
  final _proposerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  String? _logoPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await AppDatabase.instance.getShopInfo();
    if (!mounted) return;
    setState(() {
      _shopNameCtrl.text = info.shopName;
      _docTitleCtrl.text =
          info.defaultDocTitle.isEmpty ? 'ใบเสนอราคา' : info.defaultDocTitle;
      _proposerCtrl.text = info.proposerName;
      _addressCtrl.text = info.address;
      _phoneCtrl.text = info.phone;
      _emailCtrl.text = info.email;
      _taxIdCtrl.text = info.taxId;
      _logoPath = info.logoPath;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _docTitleCtrl.dispose();
    _proposerCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      if (mounted) {
        showToolkitSnackBar(context, 'ไฟล์โลโก้ต้องมีขนาดไม่เกิน 2 MB');
      }
      return;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(xfile.path).isEmpty ? '.png' : p.extension(xfile.path);
    final dest = File(p.join(appDir.path, 'shop_logo$ext'));
    await dest.writeAsBytes(bytes);
    if (!mounted) return;
    setState(() => _logoPath = dest.path);
  }

  Future<void> _save() async {
    if (_shopNameCtrl.text.trim().isEmpty) {
      // Exact Verbatim SnackBar #2 from Toolkit v0.1.7!
      showToolkitSnackBar(context, 'กรุณากรอกชื่อร้านหรือบริษัท');
      return;
    }
    final info = ShopInfo(
      shopName: _shopNameCtrl.text.trim(),
      defaultDocTitle: _docTitleCtrl.text.trim().isEmpty
          ? 'ใบเสนอราคา'
          : _docTitleCtrl.text.trim(),
      proposerName: _proposerCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      taxId: _taxIdCtrl.text.trim(),
      logoPath: _logoPath,
    );
    await AppDatabase.instance.saveShopInfo(info);
    if (!mounted) return;
    showToolkitSnackBar(context, 'บันทึกข้อมูลร้านเรียบร้อยแล้ว');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลร้านของฉัน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Logo Picker Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ToolkitColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: ToolkitColors.bgScaffold,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ToolkitColors.cardBorder),
                        ),
                        child: (_logoPath != null &&
                                File(_logoPath!).existsSync())
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(
                                  File(_logoPath!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Icon(
                                Icons.store_mall_directory_outlined,
                                color: ToolkitColors.slateMuted,
                                size: 30,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'โลโก้ร้าน / บริษัท (ไม่เกิน 2 MB)',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload_file_rounded,
                                      size: 17),
                                  label: const Text('เลือกรูปโลโก้'),
                                ),
                                if (_logoPath != null)
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _logoPath = null),
                                    child: const Text('ลบโลโก้'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 7 Form Fields
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ToolkitColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      _field(_shopNameCtrl, 'ชื่อร้านหรือบริษัท *'),
                      _field(_docTitleCtrl, 'หัวเอกสารเริ่มต้น'),
                      _field(_proposerCtrl, 'ชื่อผู้เสนอราคา'),
                      _field(_addressCtrl, 'ที่อยู่ร้าน / บริษัท', maxLines: 2),
                      _field(_phoneCtrl, 'เบอร์โทรศัพท์'),
                      _field(_emailCtrl, 'อีเมล'),
                      _field(_taxIdCtrl, 'เลขประจำตัวผู้เสียภาษี'),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ToolkitColors.royalBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _save,
                          child: const Text(
                            'บันทึกข้อมูลร้าน',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

// =============================================================================
// ORM Dealers Screen (ตัวแทนจำหน่าย ORM — 4 Province Filters + @kcinterframe)
// =============================================================================
class OrmDealersScreen extends StatefulWidget {
  const OrmDealersScreen({super.key});

  @override
  State<OrmDealersScreen> createState() => _OrmDealersScreenState();
}

class _OrmDealersScreenState extends State<OrmDealersScreen> {
  String _selectedProv = 'ทุกจังหวัด';

  @override
  Widget build(BuildContext context) {
    final content = SeedRepository.instance.staticContent;
    final filters =
        (content['dealerProvinceFilters'] as List<dynamic>? ??
                ['ทุกจังหวัด', 'กรุงเทพมหานคร', 'ฉะเชิงเทรา', 'ปทุมธานี'])
            .cast<String>();
    final dealers =
        (content['ormDealers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final filtered = dealers.where((d) {
      if (_selectedProv == 'ทุกจังหวัด') return true;
      final provs = (d['provinces'] as List<dynamic>? ?? []).cast<String>();
      return provs.contains(_selectedProv);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ตัวแทนจำหน่าย ORM')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.map((f) {
                final sel = _selectedProv == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: sel,
                  selectedColor: ToolkitColors.softBlueBg,
                  onSelected: (_) => setState(() => _selectedProv = f),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final d = filtered[i];
                final name = d['name'] as String? ?? '';
                final lineId = d['lineId'] as String? ?? '';
                final provs =
                    (d['provinces'] as List<dynamic>? ?? []).cast<String>();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'พื้นที่บริการ: ${provs.join(", ")}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ToolkitColors.slateMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LINE Official: $lineId',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: lineId));
                              showToolkitSnackBar(
                                  context, 'คัดลอก LINE ID: $lineId แล้ว');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('คัดลอก LINE'),
                          ),
                        ],
                      ),
                    ],
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
