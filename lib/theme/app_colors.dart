import 'package:flutter/material.dart';

/// GetLead design system — strictly aligned with mastui/design.md.
/// Inspired by ChatGPT, Apple HIG, Linear, and Notion.
abstract final class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color secondaryBackground = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF7F7F8);

  // Dividers & Borders
  static const Color divider = Color(0xFFECECEC);
  static const Color border = Color(0xFFECECEC);

  // Text
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF8A8A8A);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textHint = Color(0xFF8A8A8A);

  // Primary CTA & Actions (ChatGPT Pure Black #000000)
  static const Color primaryCta = Color(0xFF000000);
  static const Color onPrimaryCta = Color(0xFFFFFFFF);
  static const Color primaryCtaHover = Color(0xFF222222);

  // Primary Theme Color (Pure Black for signature monochrome ChatGPT look)
  static const Color primary = Color(0xFF000000);
  static const Color primaryHover = Color(0xFF222222);

  // Secondary Accents (ChatGPT OpenAI Green & Apple/ChatGPT Blue)
  static const Color secondaryGreen = Color(0xFF10A37F);
  static const Color secondaryGreenHover = Color(0xFF0D8C6B);
  static const Color secondaryGreenSubtle = Color(0x1410A37F); // 8% soft fill

  static const Color secondaryBlue = Color(0xFF0066FF);
  static const Color secondaryBlueHover = Color(0xFF0052CC);
  static const Color secondaryBlueSubtle = Color(0x140066FF); // 8% soft fill

  // States
  static const Color success = Color(0xFF10A37F);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE5484D);

  // Subtle fills
  static const Color surfaceSubtle = Color(0xFFF7F7F8);
}

/// Corner radii from mastui/design.md.
abstract final class AppRadius {
  static const double button = 14.0;
  static const double input = 14.0;
  static const double card = 18.0;
  static const double dialog = 20.0;
  static const double bottomSheet = 28.0;
  static const double image = 16.0;
}

/// Soft, minimal elevation from mastui/design.md.
abstract final class AppShadows {
  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x0A000000), // rgba(0,0,0,0.04)
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> floatingBar = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
}

/// Motion: smooth, 200–300ms easeInOut from mastui/design.md.
abstract final class AppMotion {
  static const Duration duration = Duration(milliseconds: 250);
  static const Curve curve = Curves.easeInOut;
}
