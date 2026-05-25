import '../models/token.dart';

/// Domain interface for authentication operations.
///
/// Implementations live in `data/repositories/auth_repository_impl.dart`.
abstract interface class IAuthRepository {
  /// Authenticates with [email] and [password] via `POST /auth/login`.
  ///
  /// Stores the returned [Token] in secure local storage.
  /// Throws [AuthException] on 401, [ServerException] on 5xx.
  Future<Token> login(String email, String password);

  /// Registers a new account via `POST /auth/register`.
  ///
  /// Stores the returned [Token] in secure local storage.
  /// Throws [ServerException] on 5xx.
  Future<Token> register(String email, String password);

  /// Clears the stored token from secure local storage.
  Future<void> logout();

  /// Reads the stored token from secure local storage.
  ///
  /// Returns `null` if no token is present.
  Future<Token?> getStoredToken();
}
