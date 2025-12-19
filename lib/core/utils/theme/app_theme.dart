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
    primaryColor: ColorConstants.primaryColor,
    scaffoldBackgroundColor: ColorConstants.lightBackground,
    canvasColor: ColorConstants.lightBackground,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColorConstants.primaryColor,
      contentTextStyle: const TextStyle(color: Colors.black),
    ),
    cardColor: ColorConstants.lightCard,
    colorScheme: const ColorScheme.light(
      primary: ColorConstants.primaryColor,
      secondary: ColorConstants.primaryOrange,
      surface: ColorConstants.lightSurface,
      onSurface: ColorConstants.lightTextPrimary,
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
}
