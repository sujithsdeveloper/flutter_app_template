import 'package:mess_app/core/constants/app_logger.dart';
import 'package:mess_app/core/constants/token_manager.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';

import 'session_manager.dart';
import 'user_session.dart';

/// Authenticates volunteer/worker against the backend when online, with a
/// local SQLite/meta fallback so the app still works offline.
class AuthService {
  AuthService({
    required SyncRepository syncRepository,
    required WorkerRepository workerRepository,
    required SessionManager sessionManager,
    required FieldApiService fieldApi,
    required FieldSyncService fieldSync,
  })  : _syncRepo = syncRepository,
        _workerRepo = workerRepository,
        _session = sessionManager,
        _api = fieldApi,
        _fieldSync = fieldSync;

  final SyncRepository _syncRepo;
  final WorkerRepository _workerRepo;
  final SessionManager _session;
  final FieldApiService _api;
  final FieldSyncService _fieldSync;

  Future<AuthResult> loginVolunteer(String email, String password) async {
    AppLogger.request('[AuthService] volunteer login attempt for $email');

    try {
      final data = await _api.volunteerLogin(email: email, password: password);
      final token = data['token'] as String?;
      final volunteer = Map<String, dynamic>.from(data['volunteer'] as Map? ?? {});
      if (token == null || token.isEmpty) {
        return AuthResult.fail('Login succeeded but no token was returned.');
      }

      await TokenManager.saveTokens(access: token, refresh: token);
      await _cacheVolunteerCredentials(
        email: email,
        password: password,
        volunteer: volunteer,
      );

      final accessCode = _accessCodeOf(volunteer);
      final session = UserSession(
        role: UserRole.volunteer,
        userId: (volunteer['id'] ?? 'VOL-001').toString(),
        userName: (volunteer['name'] ?? 'Volunteer').toString(),
        accessCode: accessCode,
      );
      await _session.saveSession(session);

      try {
        await _fieldSync.pullAndApply();
      } catch (e) {
        AppLogger.error('[AuthService] post-login sync skipped: $e');
      }

      AppLogger.response('[AuthService] volunteer login success (api)');
      return AuthResult.ok(session);
    } catch (e) {
      if (!FieldApiService.isOfflineError(e)) {
        return AuthResult.fail(FieldApiService.messageOf(e));
      }
      AppLogger.error('[AuthService] api unreachable — offline volunteer login');
      return _loginVolunteerOffline(email, password);
    }
  }

  Future<AuthResult> loginWorker(String phone, String code) async {
    AppLogger.request('[AuthService] worker login attempt for phone $phone');

    try {
      final data = await _api.workerLogin(phone: phone, code: code);
      final token = data['token'] as String?;
      final worker = Map<String, dynamic>.from(data['worker'] as Map? ?? {});
      if (token == null || token.isEmpty) {
        return AuthResult.fail('Login succeeded but no token was returned.');
      }

      await TokenManager.saveTokens(access: token, refresh: token);
      await _syncRepo.setMetaValue(
        DbConstants.metaKeyAuthVolCode,
        code.trim().toUpperCase(),
      );

      final session = UserSession(
        role: UserRole.worker,
        userId: (worker['id'] ?? '').toString(),
        userName: (worker['name'] ?? 'Worker').toString(),
      );
      await _session.saveSession(session);

      try {
        await _fieldSync.pullAndApply();
      } catch (e) {
        AppLogger.error('[AuthService] post-login sync skipped: $e');
      }

      AppLogger.response('[AuthService] worker login success (api)');
      return AuthResult.ok(session);
    } catch (e) {
      if (!FieldApiService.isOfflineError(e)) {
        return AuthResult.fail(FieldApiService.messageOf(e));
      }
      AppLogger.error('[AuthService] api unreachable — offline worker login');
      return _loginWorkerOffline(phone, code);
    }
  }

  Future<void> logout() async {
    await _session.clearSession();
    await TokenManager.clear();
    AppLogger.request('[AuthService] session cleared');
  }

  Future<AuthResult> _loginVolunteerOffline(
    String email,
    String password,
  ) async {
    final storedEmail =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolEmail);
    final storedPass =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolPassword);
    final storedName =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolName);
    final storedId =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolId);

    if (storedEmail == null || storedPass == null) {
      return AuthResult.fail(
        'No credentials found on this device. Please go online once to sync.',
      );
    }

    if (email.trim().toLowerCase() != storedEmail.toLowerCase() ||
        password != storedPass) {
      return AuthResult.fail('Incorrect email or password. Please try again.');
    }

    final storedCode =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolCode);
    final session = UserSession(
      role: UserRole.volunteer,
      userId: storedId ?? 'VOL-001',
      userName: storedName ?? 'Volunteer',
      accessCode: (storedCode != null && storedCode.isNotEmpty)
          ? storedCode
          : null,
    );
    await _session.saveSession(session);
    return AuthResult.ok(session);
  }

  Future<AuthResult> _loginWorkerOffline(String phone, String code) async {
    final storedCode =
        await _syncRepo.getMetaValue(DbConstants.metaKeyAuthVolCode);

    if (storedCode == null) {
      return AuthResult.fail(
        'Volunteer code not found. Please contact your volunteer.',
      );
    }

    if (code.trim().toUpperCase() != storedCode.trim().toUpperCase()) {
      return AuthResult.fail(
        'Invalid volunteer code. Please ask your volunteer for the correct code.',
      );
    }

    final normalizedInput = _normalizePhone(phone);
    final workers = await _workerRepo.getAll();
    final matched = workers.where((w) {
      if (w.phone == null) return false;
      return _normalizePhone(w.phone!) == normalizedInput;
    }).firstOrNull;

    if (matched == null) {
      return AuthResult.fail(
        'Phone number not registered. Please contact your volunteer.',
      );
    }
    if (!matched.isActive) {
      return AuthResult.fail(
        'Your account is inactive. Please contact your volunteer.',
      );
    }

    final session = UserSession(
      role: UserRole.worker,
      userId: matched.id,
      userName: matched.name,
    );
    await _session.saveSession(session);
    return AuthResult.ok(session);
  }

  Future<void> _cacheVolunteerCredentials({
    required String email,
    required String password,
    required Map<String, dynamic> volunteer,
  }) async {
    await _syncRepo.setMetaValue(
      DbConstants.metaKeyAuthVolEmail,
      email.trim().toLowerCase(),
    );
    await _syncRepo.setMetaValue(DbConstants.metaKeyAuthVolPassword, password);
    await _syncRepo.setMetaValue(
      DbConstants.metaKeyAuthVolName,
      (volunteer['name'] ?? 'Volunteer').toString(),
    );
    await _syncRepo.setMetaValue(
      DbConstants.metaKeyAuthVolId,
      (volunteer['id'] ?? '').toString(),
    );
    final code = _accessCodeOf(volunteer);
    if (code != null) {
      await _syncRepo.setMetaValue(DbConstants.metaKeyAuthVolCode, code);
    }
  }

  /// Persists [accessCode] into session + sync_meta when `/auth/me` (or similar)
  /// returns it for the logged-in volunteer.
  Future<void> cacheVolunteerAccessCode(String accessCode) async {
    final code = accessCode.trim();
    if (code.isEmpty) return;
    await _syncRepo.setMetaValue(DbConstants.metaKeyAuthVolCode, code);
    final current = await _session.getSession();
    if (current == null || !current.role.isVolunteer) return;
    await _session.saveSession(
      UserSession(
        role: current.role,
        userId: current.userId,
        userName: current.userName,
        accessCode: code,
      ),
    );
  }

  String? _accessCodeOf(Map<String, dynamic> volunteer) {
    final code = volunteer['accessCode'];
    if (code is String && code.trim().isNotEmpty) return code.trim();
    return null;
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
  }
}
