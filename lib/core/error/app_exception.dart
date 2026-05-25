/// Sealed exception hierarchy for the finance app.
/// All API and domain errors are represented as subtypes of [AppException].
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a network request fails due to connectivity issues.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection.']);
}

/// Thrown when the server returns a 5xx response.
final class ServerException extends AppException {
  final int? statusCode;

  const ServerException([String message = 'An unexpected server error occurred.'])
      : statusCode = null,
        super(message);

  const ServerException.withStatus(this.statusCode, [String message = 'Server error.'])
      : super(message);
}

/// Thrown when the API returns 401 (token missing, expired, or invalid).
final class AuthException extends AppException {
  const AuthException([super.message = 'Authentication required.']);
}

/// Thrown when the API returns 422 or the client detects invalid input.
final class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException([String message = 'Validation failed.'])
      : fieldErrors = null,
        super(message);

  const ValidationException.withFields(this.fieldErrors, [String message = 'Validation failed.'])
      : super(message);
}

/// Thrown when the API returns 404.
final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found.']);
}
