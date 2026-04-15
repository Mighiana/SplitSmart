import 'package:flutter/material.dart';
import '../main.dart';

/// Theme-aware colour helpers — use instead of raw AppColors constants
/// when text/card/border colours must flip between dark and light mode.
class TC {
  static bool _isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color text(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.text : const Color(0xFF1A1A2E);

  static Color text2(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.text2 : const Color(0xFF6B7280);

  static Color text3(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.text3 : const Color(0xFFADB5BD);

  static Color card(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.card : const Color(0xFFFFFFFF);

  static Color card2(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.card2 : const Color(0xFFF0F2F8);

  static Color surface(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.surface : const Color(0xFFFFFFFF);

  static Color border(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.border : const Color(0xFFE0E4EE);

  static Color bg(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.bg : const Color(0xFFF4F7F5);

  static Color shadow(BuildContext ctx) =>
      _isDark(ctx) ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06);

  static Color greenDark(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.green : const Color(0xFF0D9E3E);

  static Color blueDark(BuildContext ctx) =>
      _isDark(ctx) ? AppColors.blue : const Color(0xFF1A73E8);
}
