import 'dart:async';

import 'package:mess_app/core/constants/string_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static String? accessToken;
  static String? refreshToken;

  static Future<String?> getAccessToken({bool isRefreshToken = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      isRefreshToken
          ? StringConstants.refreshToken
          : StringConstants.accessToken,
    );
  }

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(StringConstants.accessToken, access),
      prefs.setString(StringConstants.refreshToken, refresh),
    ]);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(StringConstants.accessToken),
      prefs.remove(StringConstants.refreshToken),
    ]);
  }
}


class TokenRefreshManager {
  static final TokenRefreshManager _instance =
      TokenRefreshManager._internal();

  factory TokenRefreshManager() => _instance;

  TokenRefreshManager._internal();

  bool isRefreshing = false;

  Completer<void>? completer;
}