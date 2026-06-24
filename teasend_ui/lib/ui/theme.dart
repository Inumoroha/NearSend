import 'package:flutter/material.dart';

/// App-wide light/dark mode.
enum AppThemeMode { light, dark }

/// Accent color used outside the themed palette (warnings, stars, etc.).
const warning = Color(0xFFCB9A4B);

/// Selectable accent colors shown on the theme page.
const themeColorOptions = [
  Color(0xFF2563EB),
  Color(0xFF3D8F73),
  Color(0xFF0F172A),
  Color(0xFF8B6FD1),
  Color(0xFFD08B38),
  Color(0xFFE0527A),
];

/// The active color palette. Held in a single mutable object (instead of a
/// dozen top-level color globals) so widgets in any file can read `appColors.x`
/// without colliding with common local names like `text` or `line`, and so a
/// theme switch is one assignment.
class AppColors {
  const AppColors({
    required this.sidebar,
    required this.sidebarMuted,
    required this.panel,
    required this.surface,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.bubbleMe,
    required this.chatBg,
  });

  final Color sidebar;
  final Color sidebarMuted;
  final Color panel;
  final Color surface;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color bubbleMe;
  final Color chatBg;
}

AppColors buildColors(AppThemeMode mode, Color accent) {
  if (mode == AppThemeMode.dark) {
    return AppColors(
      sidebar: const Color(0xFF020617),
      sidebarMuted: const Color(0xFF94A3B8),
      panel: const Color(0xFF0F172A),
      surface: const Color(0xFF111827),
      line: const Color(0xFF1E293B),
      text: const Color(0xFFF8FAFC),
      muted: const Color(0xFFCBD5E1),
      accent: accent,
      accentSoft: Color.alphaBlend(
        accent.withValues(alpha: 0.18),
        const Color(0xFF111827),
      ),
      bubbleMe: Color.alphaBlend(
        accent.withValues(alpha: 0.20),
        const Color(0xFF111827),
      ),
      chatBg: const Color(0xFF020617),
    );
  }

  return AppColors(
    sidebar: const Color(0xFFFFFFFF),
    sidebarMuted: const Color(0xFF64748B),
    panel: const Color(0xFFF4F6FA),
    surface: const Color(0xFFFFFFFF),
    line: const Color(0xFFE2E8F0),
    text: const Color(0xFF0F172A),
    muted: const Color(0xFF64748B),
    accent: accent,
    accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.10), Colors.white),
    bubbleMe: Color.alphaBlend(accent.withValues(alpha: 0.18), Colors.white),
    chatBg: const Color(0xFFF8FAFC),
  );
}

/// The active palette, read throughout the UI as `appColors.<role>`.
AppColors appColors = buildColors(AppThemeMode.light, themeColorOptions.first);

/// Swaps the active palette. The caller is responsible for triggering a rebuild
/// (the root state calls this inside setState).
void applyPalette(AppThemeMode mode, Color accent) {
  appColors = buildColors(mode, accent);
}

String formatBytes(int size) {
  if (size <= 0) return '未知大小';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = size.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final digits = index == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[index]}';
}
