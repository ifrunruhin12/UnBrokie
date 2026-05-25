// Feature: flutter-finance-app
// Property 1: Auth flow stores token
// Property 4: API error surfaces inline without navigation
// Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6

import 'dart:convert';

import 'package:finance_app/core/error/app_exception.dart';
import 'package:finance_app/core/state/session_state.dart';
import 'package:finance_app/domain/models/token.dart';
import 'package:finance_app/domain/repositories/i_auth_repository.dart';
import 'package:finance_app/presentation/providers/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers — JWT construction
// ---------------------------------------------------------------------------

/// Builds a minimal JWT string with the given [sub] and [exp] (Unix seconds).
String _buildJwt({required String sub, required int exp}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': sub, 'exp': exp})));
  return '$header.$payload.fakesig';
}

/// Returns a Unix timestamp [secondsFromNow] seconds in the future.
int _futureExp([int secondsFromNow = 3600]) =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + secondsFromNow;

/// Returns a Unix timestamp in the past (expired).
int _pastExp() =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 3600;

// ---------------------------------------------------------------------------
// Fake IAuthRepository
// ---------------------------------------------------------------------------

/// Configurable fake for [IAuthRepository].
class _FakeAuthRepository implements IAuthRepository {
  _FakeAuthRepository({
    this.storedToken,
    this.loginResult,
    this.loginError,
  });

  /// Token returned by [getStoredToken].
  Token? storedToken;

  /// Token returned by [login] on success.
  Token? loginResult;

  /// Exception thrown by [login] on failure.
  Exception? loginError;

  bool logoutCalled = false;

  @override
  Future<Token> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    if (loginResult != null) return loginResult!;
    throw StateError('No loginResult configured');
  }

  @override
  Future<Token> register(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<Token?> getStoredToken() async => storedToken;
}

// ---------------------------------------------------------------------------
// ProviderContainer factory
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] with [authRepositoryProvider] overridden
/// by [fakeRepo].
ProviderContainer _makeContainer(_FakeAuthRepository fakeRepo) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SessionNotifier — startup token check', () {
    test('isInitializing is false after build completes (no stored token)', () async {
      final repo = _FakeAuthRepository(storedToken: null);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Wait for the async notifier to finish building.
      final state = await container.read(sessionProvider.future);

      expect(state.isInitializing, isFalse);
    });

    test('unauthenticated when no stored token', () async {
      final repo = _FakeAuthRepository(storedToken: null);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isAuthenticated, isFalse);
      expect(state.token, isNull);
      expect(state.userId, isNull);
    });

    test('unauthenticated when stored token is expired', () async {
      final expiredJwt = _buildJwt(sub: 'user-uuid-1', exp: _pastExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: expiredJwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isAuthenticated, isFalse);
      expect(state.token, isNull);
    });

    test('authenticated when stored token is valid and not expired', () async {
      final jwt = _buildJwt(sub: 'user-uuid-42', exp: _futureExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: jwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isAuthenticated, isTrue);
      expect(state.token, isNotNull);
      expect(state.userId, equals('user-uuid-42'));
      expect(state.isInitializing, isFalse);
    });

    test('userId is decoded from JWT sub claim on startup', () async {
      const expectedUserId = 'abc-123-def-456';
      final jwt = _buildJwt(sub: expectedUserId, exp: _futureExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: jwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.userId, equals(expectedUserId));
    });

    test('userEmail is null on startup (not stored in JWT)', () async {
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: jwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      // userEmail is not in the JWT — it's only populated after an explicit login call.
      expect(state.userEmail, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Property 1: Auth flow stores token
  // Validates: Requirements 1.2, 1.3
  // ---------------------------------------------------------------------------
  group('SessionNotifier.login — Property 1: Auth flow stores token', () {
    test('login transitions loading → data on success', () async {
      final jwt = _buildJwt(sub: 'user-uuid-99', exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Wait for initial build.
      await container.read(sessionProvider.future);

      // Trigger login.
      await container.read(sessionProvider.notifier).login('user@example.com', 'secret');

      final state = container.read(sessionProvider);
      expect(state, isA<AsyncData<SessionState>>());
      expect(state.value!.isAuthenticated, isTrue);
    });

    test('login stores userEmail from form input (not from JWT)', () async {
      const email = 'alice@example.com';
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login(email, 'password');

      final state = container.read(sessionProvider).value!;
      expect(state.userEmail, equals(email));
    });

    test('login decodes userId from JWT sub claim', () async {
      const expectedUserId = 'uuid-from-sub-claim';
      final jwt = _buildJwt(sub: expectedUserId, exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('user@example.com', 'pass');

      final state = container.read(sessionProvider).value!;
      expect(state.userId, equals(expectedUserId));
    });

    test('login sets token in session state', () async {
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('user@example.com', 'pass');

      final state = container.read(sessionProvider).value!;
      expect(state.token, isNotNull);
      expect(state.token!.value, equals(jwt));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 4: API error surfaces inline without navigation
  // Validates: Requirements 1.4
  // ---------------------------------------------------------------------------
  group('SessionNotifier.login — Property 4: Error surfaces inline', () {
    test('login transitions loading → error on AuthException (4xx)', () async {
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginError: const AuthException('Invalid credentials'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);

      // login should complete without throwing — error is in state.
      await container.read(sessionProvider.notifier).login('bad@example.com', 'wrong');

      final state = container.read(sessionProvider);
      expect(state, isA<AsyncError<SessionState>>());
      expect(state.error, isA<AuthException>());
    });

    test('login transitions loading → error on ServerException (5xx)', () async {
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginError: const ServerException('Internal server error'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('user@example.com', 'pass');

      final state = container.read(sessionProvider);
      expect(state, isA<AsyncError<SessionState>>());
      expect(state.error, isA<ServerException>());
    });

    test('login transitions loading → error on ValidationException', () async {
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginError: const ValidationException('Email is required'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('', 'pass');

      final state = container.read(sessionProvider);
      expect(state, isA<AsyncError<SessionState>>());
      expect(state.error, isA<ValidationException>());
    });

    test('session remains unauthenticated after failed login', () async {
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginError: const AuthException('Invalid credentials'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('bad@example.com', 'wrong');

      // State is AsyncError — no authenticated session.
      final state = container.read(sessionProvider);
      expect(state.value?.isAuthenticated, isNot(isTrue));
    });
  });

  // ---------------------------------------------------------------------------
  // Logout
  // Validates: Requirements 1.6, 10.4
  // ---------------------------------------------------------------------------
  group('SessionNotifier.logout', () {
    test('logout clears session state to unauthenticated', () async {
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('user@example.com', 'pass');

      // Verify authenticated first.
      expect(container.read(sessionProvider).value!.isAuthenticated, isTrue);

      // Now logout.
      await container.read(sessionProvider.notifier).logout();

      final state = container.read(sessionProvider).value!;
      expect(state.isAuthenticated, isFalse);
      expect(state.token, isNull);
      expect(state.userId, isNull);
      expect(state.userEmail, isNull);
    });

    test('logout calls IAuthRepository.logout()', () async {
      final repo = _FakeAuthRepository(storedToken: null);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).logout();

      expect(repo.logoutCalled, isTrue);
    });

    test('handleAuthException triggers logout', () async {
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(
        storedToken: null,
        loginResult: Token(value: jwt),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).login('user@example.com', 'pass');

      // Simulate an AuthException from another provider.
      await container.read(sessionProvider.notifier).handleAuthException();

      final state = container.read(sessionProvider).value!;
      expect(state.isAuthenticated, isFalse);
      expect(repo.logoutCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isInitializing flag
  // Validates: Requirements 1.5
  // ---------------------------------------------------------------------------
  group('SessionNotifier — isInitializing flag', () {
    test('isInitializing is false after successful startup with valid token', () async {
      final jwt = _buildJwt(sub: 'user-uuid-1', exp: _futureExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: jwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isInitializing, isFalse);
    });

    test('isInitializing is false after startup with no token', () async {
      final repo = _FakeAuthRepository(storedToken: null);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isInitializing, isFalse);
    });

    test('isInitializing is false after startup with expired token', () async {
      final expiredJwt = _buildJwt(sub: 'user-uuid-1', exp: _pastExp());
      final repo = _FakeAuthRepository(storedToken: Token(value: expiredJwt));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = await container.read(sessionProvider.future);

      expect(state.isInitializing, isFalse);
    });
  });
}
