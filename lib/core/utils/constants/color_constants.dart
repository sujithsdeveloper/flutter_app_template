import 'package:flutter/material.dart';

class ColorConstants {
  // Primary Colors
  static const Color primaryColor = Color(0xFFD4A636);
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

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightBackgroundSecondary = Color(0xFFF8F7F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurfaceDark = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF666666);

  // Status Colors (Theme Independent)
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color infoColor = Color(0xFF42A5F5);

  // Gradient Colors
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

  // Legacy Support (Deprecated - use theme-specific colors)
  @Deprecated('Use darkBackground or lightBackground based on theme')
  static const Color backgroundColor = Color(0xFF1A1A1A);
  @Deprecated('Use darkCard or lightCard based on theme')
  static const Color cardColor = Color(0xFF2A2A2A);
  @Deprecated('Use darkSurface or lightSurface based on theme')
  static const Color surfaceColor = Color(0xFF333333);
  @Deprecated('Use darkSurfaceLight or lightSurfaceDark based on theme')
  static const Color surfaceLight = Color(0xFF3D3D3D);
}
