import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

class AppConfigs {
  static Future<void> setOrentation() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  static Future<void> setHighestRefreshRate() async {
    try {
      // Set the highest available mode
      await FlutterDisplayMode.setHighRefreshRate();
      log("High refresh rate mode set.");
    } catch (e) {
      log(
        "Failed to set refresh rate: $e",
        name: 'Refresh Rate Display Mode Error',
      );
    }
  }
}
