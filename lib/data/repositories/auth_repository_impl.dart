import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/token.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../api/api_client.dart';
import '../json/token_json.dart';

/// Concrete implementation of [IAuthRepository].
///
/// Uses [ApiClient] for HTTP calls and [FlutterSecureStorage] for JWT
/// persistence. Auth calls are never cached — every login/register hits
/// the network directly.
class AuthRepositoryImpl implements IAuthRepository {
  static const _tokenKey = 'auth_token';

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  const AuthRepositoryImpl({
    required ApiClient client,
    required FlutterSecureStorage storage,
  })  : _client = client,
        _storage = storage;

  /// Authenticates via `POST /auth/login`.
  ///
  /// Stores the returned JWT in secure storage under [_tokenKey].
  /// Throws [AuthException] on 401, [ServerException] on 5xx.
  @override
  Future<Token> login(String email, String password) async {
    final json = await _client.postPublic(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final token = TokenJson.fromJson(json);
    await _storage.write(key: _tokenKey, value: token.value);
    return token;
  }

  /// Registers a new account via `POST /auth/register`.
  ///
  /// Stores the returned JWT in secure storage under [_tokenKey].
  /// Throws [ServerException] on 5xx.
  @override
  Future<Token> register(String email, String password) async {
    final json = await _client.postPublic(
      '/auth/register',
      body: {'email': email, 'password': password},
    );
    final token = TokenJson.fromJson(json);
    await _storage.write(key: _tokenKey, value: token.value);
    return token;
  }

  /// Reads the stored JWT from secure storage.
  ///
  /// Returns `null` if no token is present.
  /// Constructs a [Token] from the raw JWT string if present.
  @override
  Future<Token?> getStoredToken() async {
    final value = await _storage.read(key: _tokenKey);
    if (value == null) return null;
    return Token(value: value);
  }

  /// Deletes the stored JWT from secure storage.
  @override
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }
}
