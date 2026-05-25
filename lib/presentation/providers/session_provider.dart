import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/cache/response_cache.dart';
import '../../core/error/app_exception.dart';
import '../../core/state/session_state.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/token.dart';
import '../../domain/repositories/i_auth_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// Shared [FlutterSecureStorage] instance.
final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Shared [http.Client] instance.
final _httpClientProvider = Provider<http.Client>(
  (_) => http.Client(),
);

/// Shared [ResponseCache] instance — the single dumb TTL store for the app.
final responseCacheProvider = Provider<ResponseCache>(
  (_) => ResponseCache(),
);

/// [ApiClient] wired with the shared HTTP client and secure storage.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    client: ref.read(_httpClientProvider),
    storage: ref.read(_secureStorageProvider),
  ),
);

/// [IAuthRepository] implementation.
final authRepositoryProvider = Provider<IAuthRepository>(
  (ref) => AuthRepositoryImpl(
    client: ref.read(apiClientProvider),
    storage: ref.read(_secureStorageProvider),
  ),
);

// ---------------------------------------------------------------------------
// Session provider
// ---------------------------------------------------------------------------

/// The global session provider — source of truth for authentication state.
///
/// Use `ref.watch(sessionProvider)` to observe the current [SessionState].
/// Use `ref.read(sessionProvider.notifier)` to call [login] / [logout].
final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Manages the authentication session lifecycle.
///
/// Responsibilities:
/// - On startup: reads the stored token and restores the session if valid.
/// - [login]: authenticates, stores the token, and decodes the user UUID.
/// - [logout]: clears the token, wipes the cache, and resets to unauthenticated.
/// - [handleAuthException]: called by other providers when they catch an
///   [AuthException]; triggers [logout] so go_router can redirect to `/login`.
class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    // While build() is running, Riverpod automatically shows AsyncLoading.
    // We do NOT set state manually here — the return value becomes the final state.
    final repo = ref.read(authRepositoryProvider);
    final storedToken = await repo.getStoredToken();

    if (storedToken == null || storedToken.isExpired) {
      // No valid token — unauthenticated.
      return SessionState.unauthenticated;
    }

    // Valid token found — decode the sub claim for the userId.
    final userId = _decodeSubClaim(storedToken);

    return SessionState(
      token: storedToken,
      userId: userId,
      // userEmail is not in the JWT and not persisted separately at startup;
      // it will be populated on the next explicit login call.
      userEmail: null,
      isInitializing: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Authenticates with [email] and [password].
  ///
  /// On success, stores the token and updates state to authenticated.
  /// On [AuthException] or [ServerException], rethrows so the UI can display
  /// an inline error without navigating away.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final token = await repo.login(email, password);
      final userId = _decodeSubClaim(token);

      return SessionState(
        token: token,
        userId: userId,
        userEmail: email, // stored from form input — not in JWT
        isInitializing: false,
      );
    });
  }

  /// Registers a new account with [email] and [password].
  ///
  /// On success, stores the token and updates state to authenticated.
  Future<void> register(String email, String password) async {
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final token = await repo.register(email, password);
      final userId = _decodeSubClaim(token);

      return SessionState(
        token: token,
        userId: userId,
        userEmail: email,
        isInitializing: false,
      );
    });
  }

  /// Clears the session and all cached data.
  ///
  /// After this call, state is [SessionState.unauthenticated].
  /// go_router's redirect guard will navigate to `/login`.
  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    final cache = ref.read(responseCacheProvider);

    // Best-effort: clear token from secure storage.
    try {
      await repo.logout();
    } catch (_) {
      // Ignore errors — we still want to clear local state.
    }

    // Wipe all cached API responses.
    cache.clear();

    state = const AsyncData(SessionState.unauthenticated);
  }

  /// Called by other providers when they catch an [AuthException].
  ///
  /// Triggers [logout] so the router redirect guard can send the user to
  /// `/login`. The caller does not need to handle navigation itself.
  Future<void> handleAuthException() async {
    await logout();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Decodes the `sub` claim from [token]'s JWT payload.
  ///
  /// Returns the UUID string, or `null` if decoding fails.
  String? _decodeSubClaim(Token token) {
    try {
      final parts = token.value.split('.');
      if (parts.length != 3) return null;

      final payload = base64Url.normalize(parts[1]);
      final decoded =
          jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;

      return decoded['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
