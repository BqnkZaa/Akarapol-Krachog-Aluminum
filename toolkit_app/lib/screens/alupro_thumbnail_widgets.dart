import 'dart:io';
import 'package:flutter/material.dart';
import '../data/alupro_image_registry.dart';
import '../engine/quotation_spec_formatter.dart';
import 'theme_tokens.dart';

Widget buildAssetOrFileImage(
  String path, {
  BoxFit fit = BoxFit.contain,
  FilterQuality filterQuality = FilterQuality.medium,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  if (path.startsWith('assets/')) {
    return Image.asset(
      path,
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(
    File(path),
    fit: fit,
    filterQuality: filterQuality,
    errorBuilder: errorBuilder,
  );
}

void showAluproImageZoomDialog(
  BuildContext context, {
  required String assetPath,
  required String title,
  String? subtitle,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ToolkitColors.slateDark,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: ToolkitColors.slateMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 210, maxHeight: 340),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ToolkitColors.cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: buildAssetOrFileImage(
                        assetPath,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pinch_outlined,
                  size: 15,
                  color: ToolkitColors.slateMuted,
                ),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'ถ่างสองนิ้วเพื่อซูมขยายดูรายละเอียดรูปและหน้าตัด',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: ToolkitColors.slateMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AluproThumbnail extends StatelessWidget {
  final String? assetPath;
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final String? zoomTitle;
  final String? zoomSubtitle;
  final bool enableTapToZoom;
  final bool showZoomBadge;
  final double opacity;

  const AluproThumbnail({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.borderRadius = 9,
    this.padding = const EdgeInsets.all(3),
    this.zoomTitle,
    this.zoomSubtitle,
    this.enableTapToZoom = true,
    this.showZoomBadge = false,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget box = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: ToolkitColors.cardBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: opacity,
            child: buildAssetOrFileImage(
              path,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_not_supported_outlined,
                size: 18,
                color: ToolkitColors.slateMuted,
              ),
            ),
          ),
          if (showZoomBadge)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: ToolkitColors.deepNavy.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );

    if (!enableTapToZoom) {
      return box;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showAluproImageZoomDialog(
        context,
        assetPath: path,
        title: zoomTitle ?? 'รายละเอียดรูปภาพ',
        subtitle: zoomSubtitle,
      ),
      child: box,
    );
  }
}

class BrandLogoPlate extends StatelessWidget {
  final String? assetPath;
  final double width;
  final double height;
  final bool enabled;

  const BrandLogoPlate({
    super.key,
    required this.assetPath,
    this.width = 104,
    this.height = 54,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null || path.isEmpty) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ToolkitColors.softBlueBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ToolkitColors.cardBorder),
        ),
        child: const Icon(
          Icons.precision_manufacturing_outlined,
          size: 26,
          color: ToolkitColors.royalBlue,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.48,
        child: buildAssetOrFileImage(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const Icon(
            Icons.business_rounded,
            size: 26,
            color: ToolkitColors.slateMuted,
          ),
        ),
      ),
    );
  }
}

/// Photographed metallic/sahara/woodgrain color swatch thumbnail — rendered
/// strictly for official ALUMET 2026 color codes (returns empty for all other brands).
class AlumetColorSwatchBox extends StatelessWidget {
  final String colorName;
  final double width;
  final double height;
  final double borderRadius;

  const AlumetColorSwatchBox({
    super.key,
    required this.colorName,
    this.width = 22,
    this.height = 15,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final asset = AluproImageRegistry.resolveAlumetColorSwatch(colorName);
    if (asset == null) return const SizedBox.shrink();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Inline Row pairing an ALUMET swatch thumbnail (when [showSwatch] is true
/// and [colorName] matches one of the 27 ALUMET color codes) with its text label.
class AlumetColorLabelRow extends StatelessWidget {
  final String colorName;
  final bool showSwatch;
  final TextStyle? style;

  const AlumetColorLabelRow({
    super.key,
    required this.colorName,
    required this.showSwatch,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final asset = showSwatch
        ? AluproImageRegistry.resolveAlumetColorSwatch(colorName)
        : null;
    if (asset == null) {
      return Text(
        colorName,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AlumetColorSwatchBox(colorName: colorName),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            colorName,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Full visual 27-color ALUMET 2026 swatch chart dialog with 1-tap selection.
Future<void> showAlumetColorChartDialog(
  BuildContext context, {
  required String selectedColor,
  required ValueChanged<String> onPick,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตารางสี ALUMET 2026 (27 รหัสสี)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ToolkitColors.slateDark,
                          ),
                        ),
                        Text(
                          'แตะสีที่ต้องการเพื่อเลือกใช้งานทันที',
                          style: TextStyle(
                            fontSize: 12,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.35,
                  ),
                  itemCount: QuotationSpecFormatter.alumetColorChoices.length,
                  itemBuilder: (_, idx) {
                    final col = QuotationSpecFormatter.alumetColorChoices[idx];
                    final isSel = col == selectedColor;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        onPick(col);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSel ? ToolkitColors.softBlueBg : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel
                                ? ToolkitColors.royalBlue
                                : ToolkitColors.cardBorder,
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            AlumetColorSwatchBox(
                              colorName: col,
                              width: 44,
                              height: 36,
                              borderRadius: 6,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                col,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight:
                                      isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: isSel
                                      ? ToolkitColors.royalBlue
                                      : ToolkitColors.slateDark,
                                ),
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
        ),
      ),
    ),
  );
}
