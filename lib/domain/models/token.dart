import 'dart:convert';

/// JWT-based authentication token.
///
/// The JWT `sub` claim contains the user's UUID (not email).
/// JSON parsing is handled in `data/json/token_json.dart`.
class Token {
  const Token({required this.value});

  final String value;

  /// Decodes the JWT `exp` claim and returns the expiry as a UTC [DateTime].
  ///
  /// Throws [FormatException] if [value] is not a valid three-part JWT.
  DateTime get expiresAt {
    final parts = value.split('.');
    if (parts.length != 3) throw const FormatException('Invalid JWT');
    final payload = base64Url.normalize(parts[1]);
    final decoded =
        jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
    final exp = decoded['exp'] as int;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  /// Returns `true` if the token's `exp` claim is in the past.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}
