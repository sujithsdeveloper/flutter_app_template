import 'package:shared_preferences/shared_preferences.dart';
import 'user_session.dart';

/// Persists the current login session to [SharedPreferences].
///
/// Call [getSession] on startup to decide whether to show auth or home.
class SessionManager {
  static const _kRole = 'session_role';
  static const _kUserId = 'session_user_id';
  static const _kUserName = 'session_user_name';
  static const _kAccessCode = 'session_access_code';

  Future<UserSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_kRole);
    if (role == null) return null;
    final code = prefs.getString(_kAccessCode);
    return UserSession(
      role: UserRole.fromValue(role),
      userId: prefs.getString(_kUserId) ?? '',
      userName: prefs.getString(_kUserName) ?? '',
      accessCode: (code != null && code.isNotEmpty) ? code : null,
    );
  }

  Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, session.role.value);
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kUserName, session.userName);
    final code = session.accessCode?.trim();
    if (code != null && code.isNotEmpty) {
      await prefs.setString(_kAccessCode, code);
    } else {
      await prefs.remove(_kAccessCode);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kAccessCode);
  }

  Future<bool> isLoggedIn() async => (await getSession()) != null;
}
