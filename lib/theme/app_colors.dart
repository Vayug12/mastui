import 'package:flutter/material.dart';

/// MastUI design system — "ChatGPT + Apple + Linear".
///
/// Typography relies on opacity levels of near-black (#111111)
/// instead of different colors. Single blue accent. No gradients.
abstract final class AppColors {
  static const Color background = Color(0xFFFFFFFF);

  /// Primary text — #111111.
  static const Color textPrimary = Color(0xFF111111);

  /// Secondary text — rgba(17,17,17,0.72).
  static const Color textSecondary = Color(0xB8111111);

  /// Hint text — rgba(17,17,17,0.45).
  static const Color textHint = Color(0x73111111);

  /// Muted text — #8A8A8A.
  static const Color textMuted = Color(0xFF8A8A8A);

  /// Divider — rgba(17,17,17,0.08).
  static const Color divider = Color(0x14111111);

  /// Border — rgba(17,17,17,0.10).
  static const Color border = Color(0x1A111111);

  /// Primary accent — pure dark black, same as text (#111111).
  static const Color primary = Color(0xFF111111);

  /// Subtle fill for image placeholders and chips.
  static const Color surfaceSubtle = Color(0x08111111);
}

/// Corner radii from the design spec.
abstract final class AppRadius {
  static const double card = 16;
  static const double button = 20;
  static const double searchBar = 28;
}

/// Motion: smooth, 200ms ease-out everywhere.
abstract final class AppMotion {
  static const Duration duration = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOut;
}
