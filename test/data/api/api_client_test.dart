// Feature: flutter-finance-app
// Property 3: Auth header on every protected request
// Property 4: API error surfaces inline without navigation
// Validates: Requirements 1.7, 1.4

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finance_app/core/error/app_exception.dart';
import 'package:finance_app/data/api/api_client.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _fakeToken = 'header.eyJzdWIiOiJ1c2VyLTEiLCJleHAiOjk5OTk5OTk5OTl9.sig';

/// Builds an [ApiClient] backed by [mockClient] with a pre-stored token.
ApiClient _buildClient(http.Client mockClient) {
  // Use a real FlutterSecureStorage stub via a custom implementation.
  return ApiClient(
    client: mockClient,
    storage: _FakeSecureStorage(token: _fakeToken),
  );
}

/// Builds an [ApiClient] with NO stored token.
ApiClient _buildClientNoToken(http.Client mockClient) {
  return ApiClient(
    client: mockClient,
    storage: _FakeSecureStorage(token: null),
  );
}

/// Returns a JSON-encoded response body with a `data` envelope.
String _dataBody(Map<String, dynamic> data) =>
    jsonEncode({'data': data});

/// Returns a JSON-encoded error response body.
String _errorBody(String message) =>
    jsonEncode({'message': message});

// ---------------------------------------------------------------------------
// Property 3: Authorization header present on every protected request
// ---------------------------------------------------------------------------

void main() {
  group('Property 3 — Auth header on every protected request', () {
    test('GET attaches Authorization: Bearer header', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(_dataBody({'ok': true}), 200);
      });

      final client = _buildClient(mock);
      await client.get('/balance');

      expect(captured, isNotNull);
      expect(
        captured!.headers['Authorization'],
        equals('Bearer $_fakeToken'),
      );
    });

    test('POST attaches Authorization: Bearer header', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(_dataBody({'id': '1'}), 200);
      });

      final client = _buildClient(mock);
      await client.post('/transactions', body: {'amount': 100});

      expect(captured!.headers['Authorization'], equals('Bearer $_fakeToken'));
    });

    test('PATCH attaches Authorization: Bearer header', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(_dataBody({'id': '1'}), 200);
      });

      final client = _buildClient(mock);
      await client.patch('/transactions/1/override', body: {'amount': 50});

      expect(captured!.headers['Authorization'], equals('Bearer $_fakeToken'));
    });

    test('DELETE attaches Authorization: Bearer header', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });

      final client = _buildClient(mock);
      await client.delete('/categories/1');

      expect(captured!.headers['Authorization'], equals('Bearer $_fakeToken'));
    });

    test('getOnce attaches Authorization: Bearer header', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(_dataBody({'ok': true}), 200);
      });

      final client = _buildClient(mock);
      await client.getOnce('/balance');

      expect(captured!.headers['Authorization'], equals('Bearer $_fakeToken'));
    });

    test('throws AuthException when no token is stored', () async {
      final mock = MockClient((_) async =>
          http.Response(_dataBody({'ok': true}), 200));

      final client = _buildClientNoToken(mock);

      expect(() => client.get('/balance'), throwsA(isA<AuthException>()));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 3 / 4: 401 → AuthException
  // ---------------------------------------------------------------------------

  group('Property 4 — 401 surfaces as AuthException', () {
    test('GET 401 throws AuthException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Unauthorized'), 401));

      final client = _buildClient(mock);

      expect(() => client.get('/balance'), throwsA(isA<AuthException>()));
    });

    test('POST 401 throws AuthException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Unauthorized'), 401));

      final client = _buildClient(mock);

      expect(
        () => client.post('/transactions', body: {}),
        throwsA(isA<AuthException>()),
      );
    });

    test('PATCH 401 throws AuthException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Unauthorized'), 401));

      final client = _buildClient(mock);

      expect(
        () => client.patch('/transactions/1/override'),
        throwsA(isA<AuthException>()),
      );
    });

    test('DELETE 401 throws AuthException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Unauthorized'), 401));

      final client = _buildClient(mock);

      expect(() => client.delete('/categories/1'), throwsA(isA<AuthException>()));
    });

    test('getOnce 401 throws AuthException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Unauthorized'), 401));

      final client = _buildClient(mock);

      expect(() => client.getOnce('/balance'), throwsA(isA<AuthException>()));
    });
  });

  // ---------------------------------------------------------------------------
  // Status code mapping
  // ---------------------------------------------------------------------------

  group('Status code → exception mapping', () {
    test('404 throws NotFoundException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Not found'), 404));

      final client = _buildClient(mock);

      expect(() => client.get('/transactions/999'), throwsA(isA<NotFoundException>()));
    });

    test('422 throws ValidationException', () async {
      final mock = MockClient((_) async =>
          http.Response(_errorBody('Validation failed'), 422));

      final client = _buildClient(mock);

      expect(
        () => client.post('/transactions', body: {}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('500 throws ServerException after all retries', () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        return http.Response(_errorBody('Internal server error'), 500);
      });

      final client = _buildClient(mock);

      // Use a zero-delay subclass for speed — we override delays via the
      // standard client but accept the real delays in this test.
      // We just verify the exception type and that retries occurred.
      await expectLater(
        () => client.get('/balance'),
        throwsA(isA<ServerException>()),
      );
      // 3 retry attempts total
      expect(callCount, equals(3));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ---------------------------------------------------------------------------
  // Property 3: Retry fires exactly 3 times on 5xx
  // ---------------------------------------------------------------------------

  group('Retry behavior', () {
    test('GET retries exactly 3 times on 5xx then throws ServerException',
        () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        return http.Response(_errorBody('Server error'), 500);
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.get('/balance'),
        throwsA(isA<ServerException>()),
      );
      expect(callCount, equals(3));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('GET succeeds on second attempt after one 5xx', () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(_errorBody('Server error'), 500);
        }
        return http.Response(_dataBody({'balance': 1000}), 200);
      });

      final client = _buildClient(mock);
      final result = await client.get('/balance');

      expect(callCount, equals(2));
      expect(result['balance'], equals(1000));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('GET retries on NetworkException and eventually throws', () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        throw http.ClientException('Connection refused');
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.get('/balance'),
        throwsA(isA<NetworkException>()),
      );
      expect(callCount, equals(3));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('401 is NOT retried — throws AuthException immediately', () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        return http.Response(_errorBody('Unauthorized'), 401);
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.get('/balance'),
        throwsA(isA<AuthException>()),
      );
      // Should only be called once — no retry on 401
      expect(callCount, equals(1));
    });

    test('404 is NOT retried — throws NotFoundException immediately', () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        return http.Response(_errorBody('Not found'), 404);
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.get('/transactions/999'),
        throwsA(isA<NotFoundException>()),
      );
      expect(callCount, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // getOnce — single attempt, no retry
  // ---------------------------------------------------------------------------

  group('getOnce — no retry', () {
    test('getOnce does NOT retry on 5xx — throws ServerException after 1 call',
        () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        return http.Response(_errorBody('Server error'), 500);
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.getOnce('/balance'),
        throwsA(isA<ServerException>()),
      );
      // Exactly 1 call — no retry
      expect(callCount, equals(1));
    });

    test('getOnce does NOT retry on NetworkException — throws after 1 call',
        () async {
      var callCount = 0;
      final mock = MockClient((_) async {
        callCount++;
        throw http.ClientException('Connection refused');
      });

      final client = _buildClient(mock);

      await expectLater(
        () => client.getOnce('/balance'),
        throwsA(isA<NetworkException>()),
      );
      expect(callCount, equals(1));
    });

    test('getOnce returns unwrapped data on success', () async {
      final mock = MockClient((_) async =>
          http.Response(_dataBody({'balance': 500}), 200));

      final client = _buildClient(mock);
      final result = await client.getOnce('/balance');

      expect(result['balance'], equals(500));
    });
  });

  // ---------------------------------------------------------------------------
  // Response unwrapping
  // ---------------------------------------------------------------------------

  group('Response data unwrapping', () {
    test('unwraps response["data"] envelope', () async {
      final mock = MockClient((_) async =>
          http.Response(jsonEncode({'data': {'id': '42', 'name': 'Food'}}), 200));

      final client = _buildClient(mock);
      final result = await client.get('/categories/42');

      expect(result['id'], equals('42'));
      expect(result['name'], equals('Food'));
    });

    test('returns full body when no "data" key present', () async {
      final mock = MockClient((_) async =>
          http.Response(jsonEncode({'id': '42', 'name': 'Food'}), 200));

      final client = _buildClient(mock);
      final result = await client.get('/categories/42');

      expect(result['id'], equals('42'));
      expect(result['name'], equals('Food'));
    });

    test('returns empty map for empty response body', () async {
      final mock = MockClient((_) async => http.Response('', 204));

      final client = _buildClient(mock);
      // DELETE returns void, but we can test via a 204 on get
      // (edge case: empty body on success)
      final result = await client.get('/noop');

      expect(result, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// In-memory [FlutterSecureStorage] stub for tests.
///
/// Delegates everything to [noSuchMethod] except [read], which returns the
/// pre-configured token value.
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  _FakeSecureStorage({required String? token}) : _token = token;

  final String? _token;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      key == 'auth_token' ? _token : null;
}
