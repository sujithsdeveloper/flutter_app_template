/// The authenticated user's role in the system.
enum UserRole {
  /// Volunteer (admin) — manages plots, field volunteers, and tasks.
  volunteer,

  /// Field volunteer — sees only tasks assigned to them.
  worker;

  static UserRole fromValue(String v) =>
      v == 'worker' ? UserRole.worker : UserRole.volunteer;

  String get value => name;

  bool get isVolunteer => this == volunteer;
  bool get isWorker => this == worker;
  bool get isAdminVolunteer => this == volunteer;
  bool get isFieldVolunteer => this == worker;
}

/// Represents the currently authenticated session stored on-device.
class UserSession {
  const UserSession({
    required this.role,
    required this.userId,
    required this.userName,
    this.accessCode,
  });

  final UserRole role;
  final String userId;
  final String userName;

  /// Volunteer admin code shared with field workers. Null for workers.
  final String? accessCode;

  @override
  String toString() => 'UserSession(role:${role.name}, id:$userId)';
}

/// Result object returned by [AuthService] login methods.
class AuthResult {
  const AuthResult._({
    required this.success,
    this.session,
    this.errorMessage,
  });

  factory AuthResult.ok(UserSession session) =>
      AuthResult._(success: true, session: session);

  factory AuthResult.fail(String message) =>
      AuthResult._(success: false, errorMessage: message);

  final bool success;
  final UserSession? session;
  final String? errorMessage;
}
