import 'package:shared_preferences/shared_preferences.dart';

class AppUtils {
 static Future<void> saveToken(String token) async {
    final preff = await SharedPreferences.getInstance();
    await preff.setString('auth_token', token);
  }

 static Future<String?> getToken() async {
    final preff = await SharedPreferences.getInstance();

    String? token = preff.getString('auth_token');
    return token;
  }

  static Future<void> clearToken() async {
    final preff = await SharedPreferences.getInstance();
    await preff.remove('auth_token');
  }
}
