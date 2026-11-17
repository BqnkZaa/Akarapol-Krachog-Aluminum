import 'package:flutter/material.dart';
import 'theme_tokens.dart';

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
                      child: Image.asset(
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
                Text(
                  'ถ่างสองนิ้วเพื่อซูมขยายดูรายละเอียดรูปและหน้าตัด',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ToolkitColors.slateMuted,
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
            child: Image.asset(
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
      return SizedBox(width: width, height: height);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.48,
        child: Image.asset(
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
