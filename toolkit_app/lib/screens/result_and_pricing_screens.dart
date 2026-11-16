import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../data/app_database.dart';
import '../data/seed_repository.dart';
import '../engine/clipboard_formatter.dart';
import '../engine/formula_evaluator.dart';
import '../engine/pricing_engine.dart';
import '../models/app_models.dart';
import '../pdf/single_cut_pdf.dart';
import 'projects_and_quotation_screens.dart';
import 'theme_tokens.dart';

final NumberFormat _bahtFmt = NumberFormat('#,##0.00', 'en_US');

class ResultScreen extends StatefulWidget {
  final CalculationOutput output;
  final List<SizeRowInput> sizeRows;
  final int? targetProjectId;

  const ResultScreen({
    super.key,
    required this.output,
    required this.sizeRows,
    this.targetProjectId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _checkedNotice = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 3) {
        _maybeShowPricingBetaDialog();
      }
    });
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
    final bytes = await SingleCutPdfGenerator.generate(widget.output);
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
    final out = widget.output;
    return Scaffold(
      appBar: AppBar(
        title: Text('${out.brandTitle} | ${out.patternTitle}'),
        bottom: TabBar(
          controller: _tabController,
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
                PricingWorkspaceWidget(barGroups: out.barGroups),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: ToolkitColors.deepNavy,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => SaveToProjectDialog(
                            output: out,
                            sizeRows: widget.sizeRows,
                            preselectedProjectId: widget.targetProjectId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                      label: const Text(
                        'บันทึกงาน',
                        style: TextStyle(
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
      padding: const EdgeInsets.all(14),
      children: [
        ...out.sets.map((s) {
          final wStr = FormulaEvaluator.formatMm(s.sizeRow.widthMm);
          final hStr = FormulaEvaluator.formatMm(s.sizeRow.heightMm);
          final grouped = <String, List<EvaluatedCutItem>>{};
          for (final c in s.cuts) {
            grouped.putIfAbsent(c.section, () => []).add(c);
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
              children: grouped.entries.map((entry) {
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
                      ...entry.value.map((c) {
                        final cutVal = c.isSiteMeasured
                            ? 'วัดตามจริง'
                            : 'ตัด ${FormulaEvaluator.formatMm(c.lengthMm ?? 0)} มม.';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.code,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: ToolkitColors.royalBlue,
                                      ),
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
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
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
                child: allGlasses.isEmpty
                    ? const Text(
                        'ไม่มีรายการกระจก',
                        style: TextStyle(color: ToolkitColors.slateMuted),
                      )
                    : Column(
                        children: allGlasses.map((g) {
                          final dimTxt = g.siteCut
                              ? 'วัดตัดหน้างาน · ${g.totalPanels} แผ่น'
                              : 'ขนาดสั่งตัดกระจก: ${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม. · ${g.totalPanels} แผ่น';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    g.name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  dimTxt,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ToolkitColors.royalBlue,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _summarySectionCard(
          title: 'อลูมิเนียมที่ต้องสั่งซื้อ',
          children: out.barGroups
              .map(
                (g) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${g.code} · ${g.combinedNames}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'เส้นโรงงาน ${g.stockLengthMm} มม.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${g.totalBars} เส้น',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.royalBlue,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        _summarySectionCard(
          title: 'กระจกที่ต้องสั่ง',
          children: allGlasses.isEmpty
              ? [const Text('ไม่มีรายการกระจก')]
              : allGlasses
                  .map(
                    (g) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        g.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        g.siteCut
                            ? 'วัดตัดหน้างาน'
                            : '${FormulaEvaluator.formatMm(g.widthMm ?? 0)} × ${FormulaEvaluator.formatMm(g.heightMm ?? 0)} มม.',
                      ),
                      trailing: Text(
                        '${g.totalPanels} แผ่น',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),
        _summarySectionCard(
          title: 'อุปกรณ์ประกอบ',
          children: out.hardware.isEmpty
              ? [const Text('ไม่มีรายการอุปกรณ์ประกอบ')]
              : out.hardware
                  .map(
                    (h) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        h.code.isNotEmpty ? '${h.code} · ${h.name}' : h.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        h.displayQty,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildTab3BarPacking(CalculationOutput out) {
    return ListView(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'สรุปการจัดเส้นสั่งซื้อ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ToolkitColors.slateDark,
            ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
  final ValueChanged<PricingSummary>? onSummaryChanged;

  const PricingWorkspaceWidget({
    super.key,
    required this.barGroups,
    this.onSummaryChanged,
  });

  @override
  State<PricingWorkspaceWidget> createState() => _PricingWorkspaceWidgetState();
}

class _PricingWorkspaceWidgetState extends State<PricingWorkspaceWidget> {
  PricingMode _mode = PricingMode.actualLength;
  double _wastePct = 20.0;
  late final TextEditingController _wasteCtrl;
  String _selectedThickness = '1.2 มม.';
  String _selectedColor = 'ตัวดิบ MILL';
  Map<String, CustomPriceOverride> _overrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _wasteCtrl = TextEditingController(text: '20');
    _reloadOverrides();
  }

  Future<void> _reloadOverrides() async {
    final ov = await AppDatabase.instance.getAllCustomPrices();
    if (!mounted) return;
    setState(() {
      _overrides = ov;
      _loading = false;
    });
    _notifyParent();
  }

  void _notifyParent() {
    if (widget.onSummaryChanged != null) {
      widget.onSummaryChanged!(_computeSummary());
    }
  }

  PricingSummary _computeSummary() {
    return PricingEngine.evaluate(
      barGroups: widget.barGroups,
      mode: _mode,
      wastePercent: _wastePct,
      selectedThickness: _selectedThickness,
      selectedColor: _selectedColor,
      ormCatalog: SeedRepository.instance.ormPrices,
      customOverrides: _overrides,
    );
  }

  @override
  void dispose() {
    _wasteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _computeSummary();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Quick Action Pills (กำหนดราคาเอง / ข้อมูลร้าน / ตัวแทนจำหน่าย ORM)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.price_change_outlined,
                  size: 17, color: ToolkitColors.royalBlue),
              label: const Text('กำหนด/แก้ไขราคาเส้นเอง'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomPriceScreen()),
                );
                _reloadOverrides();
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.storefront_outlined,
                  size: 17, color: ToolkitColors.royalBlue),
              label: const Text('ข้อมูลร้านของฉัน'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopInfoScreen()),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.handshake_outlined,
                  size: 17, color: ToolkitColors.royalBlue),
              label: const Text('ตัวแทนจำหน่าย ORM'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrmDealersScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Controls Card
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
                'วิธีคิดต้นทุนอลูมิเนียม',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PricingMode>(
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    flex: 4,
                    child: Text(
                      'เผื่อเสีย / เศษวัสดุ (%)',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _wasteCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
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
                ],
              ),
              Slider(
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedThickness,
                      decoration: const InputDecoration(
                        labelText: 'ความหนา',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: PricingEngine.standardThicknesses
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
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
                      initialValue: _selectedColor,
                      decoration: const InputDecoration(
                        labelText: 'สี / ผิวโปรไฟล์',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: PricingEngine.standardColors
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedColor = v);
                          _notifyParent();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Total Cost Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ToolkitColors.slateDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ต้นทุนเส้นอลูมิเนียมรวม',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'จับคู่ราคาได้ ${summary.matchedCount}/${summary.totalCount} รายการ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
              Text(
                '฿${_bahtFmt.format(summary.totalCost)}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Breakdown Table
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
              const Text(
                'รายละเอียดต้นทุนแยกรหัสหน้าตัด',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              const Divider(),
              ...summary.lines.map((ln) {
                final g = ln.group;
                final usedM = (g.exactCutSumMm / 1000.0).toStringAsFixed(2);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                    ? ToolkitColors.slateMuted
                                    : const Color(0xFFDC2626),
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
                            ln.isMatched
                                ? '฿${_bahtFmt.format(ln.lineCost!)}'
                                : 'รอตั้งราคา',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ln.isMatched
                                  ? ToolkitColors.royalBlue
                                  : ToolkitColors.slateMuted,
                            ),
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
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
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
// Custom Price Screen (กำหนด/แก้ไขราคาเส้นเอง — 1,139 ORM SKUs + 4 Filters)
// =============================================================================
class CustomPriceScreen extends StatefulWidget {
  const CustomPriceScreen({super.key});

  @override
  State<CustomPriceScreen> createState() => _CustomPriceScreenState();
}

class _CustomPriceScreenState extends State<CustomPriceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _brandFilter = 'ทั้งหมด';
  String _thickFilter = 'ทั้งหมด';
  String _colorFilter = 'ทั้งหมด';
  String _stockFilter = 'ทั้งหมด';
  Map<String, CustomPriceOverride> _overrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ov = await AppDatabase.instance.getAllCustomPrices();
    if (!mounted) return;
    setState(() {
      _overrides = ov;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OrmPriceSku> _mergedList() {
    final map = <String, OrmPriceSku>{};
    for (final s in SeedRepository.instance.ormPrices) {
      final ov = _overrides[s.skuKey];
      map[s.skuKey] = ov != null
          ? s.withOverride(ov.pricePerBar, stock: ov.inStock)
          : s;
    }
    for (final ov in _overrides.values) {
      if (!map.containsKey(ov.skuKey)) {
        map[ov.skuKey] = OrmPriceSku(
          brand: ov.brand,
          code: ov.code,
          name: ov.name,
          thickness: ov.thickness,
          color: ov.color,
          stockM: ov.stockM,
          factoryPrice: ov.pricePerBar,
          customPrice: ov.pricePerBar,
          inStock: ov.inStock,
        );
      }
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    return map.values.where((s) {
      if (_brandFilter != 'ทั้งหมด' && s.brand != _brandFilter) return false;
      if (_thickFilter != 'ทั้งหมด' && s.thickness != _thickFilter) return false;
      if (_colorFilter != 'ทั้งหมด' && s.color != _colorFilter) return false;
      if (_stockFilter == 'มีสต็อก' && !s.inStock) return false;
      if (_stockFilter == 'หมดสต็อก' && s.inStock) return false;
      if (q.isNotEmpty) {
        return s.code.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q);
      }
      return true;
    }).toList();
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
                child: const Text('คืนค่าราคาโรงงาน'),
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

  Future<void> _addCustomSkuDialog() async {
    String brand = 'ORM';
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String thick = '1.2 มม.';
    String color = 'ตัวดิบ MILL';
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('เพิ่มราคาเส้นเอง'),
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
                  items: const [
                    'ORM',
                    'SCHIMMER',
                    'ALUMET',
                    'SMART_PLUS',
                    'UAI',
                    'FUJI',
                    'ALUFRAME',
                    'MARKET',
                  ]
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setModal(() => brand = v ?? 'ORM'),
                ),
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
                  initialValue: color,
                  decoration: const InputDecoration(
                    labelText: 'สี / ผิว',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: PricingEngine.standardColors
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModal(() => color = v ?? 'ตัวดิบ MILL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ราคาต่อเส้น (บาท) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                final cd = codeCtrl.text.trim();
                final pr = double.tryParse(priceCtrl.text.trim());
                if (cd.isEmpty || pr == null) return;
                final skuKey = '$brand|$cd|$thick|$color';
                await AppDatabase.instance.upsertCustomPrice(
                  CustomPriceOverride(
                    skuKey: skuKey,
                    brand: brand,
                    code: cd,
                    name: nameCtrl.text.trim().isEmpty
                        ? cd
                        : nameCtrl.text.trim(),
                    thickness: thick,
                    color: color,
                    stockM: 6.4,
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

  @override
  Widget build(BuildContext context) {
    final items = _loading ? <OrmPriceSku>[] : _mergedList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('กำหนด/แก้ไขราคาเส้นเอง'),
        actions: [
          IconButton(
            tooltip: 'เพิ่มรหัสราคาเอง',
            onPressed: _addCustomSkuDialog,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'ค้นหารหัสหน้าตัด หรือชื่อโปรไฟล์...',
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
                              value: _brandFilter,
                              options: const [
                                'ทั้งหมด',
                                'ORM',
                                'SCHIMMER',
                                'ALUMET',
                                'SMART_PLUS',
                                'UAI',
                                'FUJI',
                                'ALUFRAME',
                                'MARKET',
                              ],
                              onChanged: (v) =>
                                  setState(() => _brandFilter = v),
                            ),
                            const SizedBox(width: 8),
                            _miniFilterDropdown(
                              label: 'ความหนา',
                              value: _thickFilter,
                              options: [
                                'ทั้งหมด',
                                ...PricingEngine.standardThicknesses,
                              ],
                              onChanged: (v) =>
                                  setState(() => _thickFilter = v),
                            ),
                            const SizedBox(width: 8),
                            _miniFilterDropdown(
                              label: 'สี/ผิว',
                              value: _colorFilter,
                              options: [
                                'ทั้งหมด',
                                ...PricingEngine.standardColors,
                              ],
                              onChanged: (v) =>
                                  setState(() => _colorFilter = v),
                            ),
                            const SizedBox(width: 8),
                            _miniFilterDropdown(
                              label: 'สต็อก',
                              value: _stockFilter,
                              options: const ['ทั้งหมด', 'มีสต็อก', 'หมดสต็อก'],
                              onChanged: (v) =>
                                  setState(() => _stockFilter = v),
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
                                    s.customPrice != null
                                        ? 'ราคาที่แก้เอง (Toolkit ฿${_bahtFmt.format(s.factoryPrice)})'
                                        : 'Toolkit ฿${_bahtFmt.format(s.factoryPrice)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: s.customPrice != null
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
            ),
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
