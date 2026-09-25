import 'package:flutter/material.dart';
import '../constants/color_constants.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: ColorConstants.primaryColor,
    scaffoldBackgroundColor: ColorConstants.darkBackground,
    canvasColor: ColorConstants.darkBackground,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColorConstants.primaryColor,
      contentTextStyle: const TextStyle(color: Colors.black),
    ),
    cardColor: ColorConstants.darkCard,
    colorScheme: const ColorScheme.dark(
      primary: ColorConstants.primaryColor,
      secondary: ColorConstants.primaryOrange,
      surface: ColorConstants.darkSurface,
      onSurface: ColorConstants.darkTextPrimary,
      error: ColorConstants.errorColor,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: ColorConstants.primaryColor,
      selectionColor: ColorConstants.lightGold.withAlpha(128),
      selectionHandleColor: ColorConstants.primaryColor,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: ColorConstants.forestGreen,
    scaffoldBackgroundColor: ColorConstants.cream,
    canvasColor: ColorConstants.cream,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ColorConstants.forestGreen,
      contentTextStyle: TextStyle(color: ColorConstants.cream),
      behavior: SnackBarBehavior.floating,
    ),
    cardColor: ColorConstants.cardSurface,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: ColorConstants.forestGreen,
      secondary: ColorConstants.secondaryGreen,
      surface: ColorConstants.veryPaleGreen,
      onSurface: ColorConstants.primaryText,
      onSecondary: ColorConstants.cream,
      error: ColorConstants.errorColor,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: ColorConstants.primaryText,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: ColorConstants.primaryText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ColorConstants.primaryText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ColorConstants.secondaryText,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: ColorConstants.mutedText,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ColorConstants.forestGreen,
      selectionColor: Color(0x66315C43),
      selectionHandleColor: ColorConstants.forestGreen,
    ),
  );
}
