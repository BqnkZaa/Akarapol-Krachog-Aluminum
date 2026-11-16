import 'package:flutter/material.dart';

class ToolkitColors {
  ToolkitColors._();

  static const Color royalBlue = Color(0xFF1D4ED8);
  static const Color royalBlueDark = Color(0xFF1E40AF);
  static const Color deepNavy = Color(0xFF3E5481);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateBody = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgScaffold = Color(0xFFF5F7FA);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color softBlueBg = Color(0xFFEFF6FF);
  static const Color vipGoldBg = Color(0xFFFEF3C7);
  static const Color vipGoldBorder = Color(0xFFF59E0B);
  static const Color vipGoldText = Color(0xFFB45309);
  static const Color disabledBg = Color(0xFFF8FAFC);
  static const Color disabledPillBg = Color(0xFFF1F5F9);
  static const Color successGreen = Color(0xFF15803D);
}

void showToolkitSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Sarabun', fontSize: 14),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ToolkitColors.slateDark,
        duration: const Duration(seconds: 2),
      ),
    );
}

Widget buildStatusBadge(String text, {bool isWarning = false}) {
  final bg = isWarning ? const Color(0xFFFFFBEB) : ToolkitColors.disabledPillBg;
  final fg = isWarning ? const Color(0xFFB45309) : ToolkitColors.slateMuted;
  final bd = isWarning ? const Color(0xFFFDE68A) : ToolkitColors.cardBorder;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: bd),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    ),
  );
}
