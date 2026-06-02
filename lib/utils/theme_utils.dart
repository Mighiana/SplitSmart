import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─── SplitSmart Design System ──────────────────────────────────────────────
/// Theme-aware colour & typography helpers — use instead of raw AppColors
/// constants when values must flip between dark and light mode.
///
/// Colour palette matches splitsmart-screens.html & planner-screens.jsx:
///   Light: Warm Cream (#F7F5F0) + Deep Teal (#0D7377)
///   Dark:  Deep Ocean (#0A1A1C) + Mint Teal (#14A085)

class TC {
  static bool _isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ─── Primary Teal ─────────────────────────────────────────────────────
  static Color primary(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF14A085) : const Color(0xFF0D7377);

  static Color primaryMd(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF1AB899) : const Color(0xFF149080);

  static Color primaryLt(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF2ED4B0) : const Color(0xFF1CB899);

  static Color primaryPale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFF14A085).withValues(alpha: 0.10)
          : const Color(0xFF0D7377).withValues(alpha: 0.07);

  static Color primaryGlow(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFF14A085).withValues(alpha: 0.22)
          : const Color(0xFF0D7377).withValues(alpha: 0.20);

  // ─── Text ─────────────────────────────────────────────────────────────
  static Color text(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFFE8F4F5) : const Color(0xFF111918);

  static Color text2(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF7FB8C0) : const Color(0xFF4E6560);

  static Color text3(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF4A8090) : const Color(0xFF9BB5B0);

  static Color text4(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF1E3A40) : const Color(0xFFD4E3E1);

  // ─── Backgrounds & Surfaces ───────────────────────────────────────────
  static Color bg(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF0A1A1C) : const Color(0xFFF7F5F0);

  static Color bg2(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF0D2226) : const Color(0xFFEDE9E1);

  static Color surface(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF122228) : const Color(0xFFFDFCFA);

  static Color surface2(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF162B30) : const Color(0xFFF9F7F3);

  // ─── Cards ────────────────────────────────────────────────────────────
  static Color card(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF122228) : const Color(0xFFFDFCFA);

  static Color card2(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF162B30) : const Color(0xFFF9F7F3);

  // ─── Borders ──────────────────────────────────────────────────────────
  static Color border(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFFE8F4F5).withValues(alpha: 0.07)
          : const Color(0xFF111918).withValues(alpha: 0.07);

  static Color border2(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFFE8F4F5).withValues(alpha: 0.03)
          : const Color(0xFF111918).withValues(alpha: 0.04);

  // ─── Shadows ──────────────────────────────────────────────────────────
  static Color shadow(BuildContext ctx) =>
      _isDark(ctx)
          ? Colors.black.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.06);

  static Color shadowDeep(BuildContext ctx) =>
      _isDark(ctx)
          ? Colors.black.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.04);

  // ─── Semantic: Success (ok) ───────────────────────────────────────────
  static Color ok(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF34D399) : const Color(0xFF059669);

  static Color okPale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFF34D399).withValues(alpha: 0.10)
          : const Color(0xFF059669).withValues(alpha: 0.08);

  // ─── Semantic: Error (er) ─────────────────────────────────────────────
  static Color er(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFFF87171) : const Color(0xFFE85A6A);

  static Color erPale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFFF87171).withValues(alpha: 0.10)
          : const Color(0xFFE85A6A).withValues(alpha: 0.08);

  // ─── Semantic: Warning (wn) ───────────────────────────────────────────
  static Color wn(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

  static Color wnPale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFFFBBF24).withValues(alpha: 0.10)
          : const Color(0xFFD97706).withValues(alpha: 0.08);

  // ─── Accent: Blue ─────────────────────────────────────────────────────
  static Color blue(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color bluePale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFF60A5FA).withValues(alpha: 0.10)
          : const Color(0xFF3B82F6).withValues(alpha: 0.08);

  // ─── Accent: Purple ───────────────────────────────────────────────────
  static Color purple(BuildContext ctx) =>
      _isDark(ctx) ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);

  static Color purplePale(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFFA78BFA).withValues(alpha: 0.10)
          : const Color(0xFF8B5CF6).withValues(alpha: 0.08);

  // ─── Navigation ───────────────────────────────────────────────────────
  static Color navBg(BuildContext ctx) =>
      _isDark(ctx)
          ? const Color(0xFF0A1A1C).withValues(alpha: 0.97)
          : const Color(0xFFF7F5F0).withValues(alpha: 0.96);

  // ─── Backward compatibility aliases ───────────────────────────────────
  static Color greenDark(BuildContext ctx) => ok(ctx);
  static Color blueDark(BuildContext ctx) => blue(ctx);

  // ─── Card Gradient (hero balance cards) ───────────────────────────────
  static LinearGradient cardGradient(BuildContext ctx) =>
      _isDark(ctx)
          ? const LinearGradient(
              colors: [Color(0xFF061416), Color(0xFF0D4A50), Color(0xFF0D7377)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFF083A3D), Color(0xFF0D7377), Color(0xFF14A085)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

  // ─── Typography Helpers ───────────────────────────────────────────────

  /// Gloock — serif display font for headlines, big numbers, currency amounts
  static TextStyle gloock(BuildContext ctx, {
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    try {
      return GoogleFonts.gloock(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? text(ctx),
        letterSpacing: letterSpacing,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? text(ctx),
        letterSpacing: letterSpacing,
        height: height,
        fontFamily: 'serif',
      );
    }
  }

  /// Geist — clean sans-serif for body, labels, buttons
  static TextStyle geist(BuildContext ctx, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    try {
      return GoogleFonts.getFont(
        'Geist',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? text(ctx),
        letterSpacing: letterSpacing,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? text(ctx),
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }
}
