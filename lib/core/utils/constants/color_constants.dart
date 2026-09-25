import 'package:flutter/material.dart';

class ColorConstants {
  // ── Botanical Premium Palette ─────────────────────────────────────────────

  /// Primary Forest Green — headers, primary buttons, active icons.
  static const Color forestGreen = Color(0xFF315C43);

  /// Primary Action Green — CTAs, interactive accents.
  static const Color actionGreen = Color(0xFF3F7651);

  /// Secondary Green — secondary elements, highlights.
  static const Color secondaryGreen = Color(0xFF5E9368);

  /// Soft Green — card tints, role pills, badges.
  static const Color softGreen = Color(0xFFDDE9D9);

  /// Pale Green — selected nav item bg, subtle highlights.
  static const Color paleGreen = Color(0xFFEAF1E5);

  /// Very Pale Green — avatar backgrounds, chip fills.
  static const Color veryPaleGreen = Color(0xFFF1F5EC);

  /// Role pill background.
  static const Color rolePillBg = Color(0xFFE6F0E2);

  /// Role pill text.
  static const Color rolePillText = Color(0xFF477453);

  /// Nav selected icon/label.
  static const Color navSelected = Color(0xFF347043);

  /// Nav selected background.
  static const Color navSelectedBg = Color(0xFFE5EFE0);

  /// Nav unselected icon/label.
  static const Color navUnselected = Color(0xFF777B75);

  // Backgrounds
  static const Color warmBackground = Color(0xFFF7F5EA);
  static const Color cream = Color(0xFFFBFAF4);
  static const Color cardSurface = Color(0xFFFFFDF7);
  static const Color navBarSurface = Color(0xFFFFFDF8);

  // Gradient stops
  static const Color gradientTop = Color(0xFFF9F7ED);
  static const Color gradientMid = Color(0xFFF5F2E6);
  static const Color gradientBottom = Color(0xFFEEF2E6);
  static const Color radialGlow = Color(0xFFDCE8D5);

  // Text
  static const Color primaryText = Color(0xFF172019);
  static const Color secondaryText = Color(0xFF667068);
  static const Color mutedText = Color(0xFF8C958D);

  // Borders & surfaces
  static const Color border = Color(0xFFE4E8DF);
  static const Color cardBorder = Color(0xFFE6E9E1);
  static const Color inputFill = Color(0xFFF4F7F4);

  // Status
  static const Color successColor = Color(0xFF4A9659);
  static const Color warningColor = Color(0xFFE9A344);
  static const Color errorColor = Color(0xFFD75B4E);
  static const Color infoColor = Color(0xFF6B9CB8);

  // ── Legacy aliases (kept for backward compatibility) ──────────────────────

  static const Color earthGreen = secondaryGreen;
  static const Color leafGreen = secondaryGreen;
  static const Color deepForest = forestGreen;
  static const Color borderGrey = border;

  static const Color primaryColor = forestGreen;
  static const Color primaryOrange = Color(0xFFFF8C1A);
  static const Color lightGold = Color(0xFFE8C55B);
  static const Color darkGold = Color(0xFFB8860B);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkBackgroundSecondary = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkSurface = Color(0xFF333333);
  static const Color darkSurfaceLight = Color(0xFF3D3D3D);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Light Theme Colors (mapped to botanical palette)
  static const Color lightBackground = cream;
  static const Color lightBackgroundSecondary = warmBackground;
  static const Color lightCard = cardSurface;
  static const Color lightSurface = veryPaleGreen;
  static const Color lightSurfaceDark = paleGreen;
  static const Color lightTextPrimary = primaryText;
  static const Color lightTextSecondary = secondaryText;

  // Gradient Colors (legacy)
  static const List<Color> primaryGradient = [
    Color(0xFFE8C55B),
    Color(0xFFD4A636),
    Color(0xFFB8860B),
  ];
  static const List<Color> primaryGradientOrange = [
    Color(0xFFFF8C1A),
    Color(0xFFF2780D),
    Color(0xFFD66A0B),
  ];

  // Botanical background gradient
  static const List<Color> botanicalGradient = [
    gradientTop,
    gradientMid,
    gradientBottom,
  ];

  @Deprecated('Use darkBackground or lightBackground based on theme')
  static const Color backgroundColor = Color(0xFF1A1A1A);
  @Deprecated('Use darkCard or lightCard based on theme')
  static const Color cardColor = Color(0xFF2A2A2A);
  @Deprecated('Use darkSurface or lightSurface based on theme')
  static const Color surfaceColor = Color(0xFF333333);
  @Deprecated('Use darkSurfaceLight or lightSurfaceDark based on theme')
  static const Color surfaceLight = Color(0xFF3D3D3D);
}
