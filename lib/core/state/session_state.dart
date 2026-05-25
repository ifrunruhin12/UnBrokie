import '../../domain/models/token.dart';

/// Immutable snapshot of the current authentication session.
///
/// - [token] — the stored JWT, or `null` when unauthenticated.
/// - [userId] — UUID decoded from the JWT `sub` claim; `null` when unauthenticated.
/// - [userEmail] — the email the user typed at login/register time.
///   This is NOT present in the JWT and must be stored separately.
/// - [isInitializing] — `true` only during the app-startup token check;
///   `false` once the check completes (regardless of outcome).
class SessionState {
  const SessionState({
    this.token,
    this.userId,
    this.userEmail,
    this.isInitializing = false,
  });

  final Token? token;
  final String? userId;
  final String? userEmail;
  final bool isInitializing;

  /// Returns `true` when a non-expired token is present.
  bool get isAuthenticated =>
      token != null && !(token!.isExpired);

  /// Returns a copy with the given fields replaced.
  SessionState copyWith({
    Token? token,
    String? userId,
    String? userEmail,
    bool? isInitializing,
    bool clearToken = false,
    bool clearUserId = false,
    bool clearUserEmail = false,
  }) {
    return SessionState(
      token: clearToken ? null : (token ?? this.token),
      userId: clearUserId ? null : (userId ?? this.userId),
      userEmail: clearUserEmail ? null : (userEmail ?? this.userEmail),
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }

  /// Unauthenticated state — no token, no user info, not initializing.
  static const unauthenticated = SessionState(
    token: null,
    userId: null,
    userEmail: null,
    isInitializing: false,
  );

  @override
  String toString() =>
      'SessionState(userId: $userId, userEmail: $userEmail, '
      'isAuthenticated: $isAuthenticated, isInitializing: $isInitializing)';
}
