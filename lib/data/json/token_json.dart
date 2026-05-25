import '../../domain/models/token.dart';

/// JSON serialization extension for [Token].
///
/// API response shape (after envelope unwrap):
/// ```json
/// { "token": "<jwt_string>" }
/// ```
extension TokenJson on Token {
  /// Deserializes a [Token] from the API response JSON.
  ///
  /// Reads the JWT string from the `token` key.
  static Token fromJson(Map<String, dynamic> json) {
    return Token(value: json['token'] as String);
  }

  /// Serializes this [Token] to a JSON map.
  Map<String, dynamic> toJson() => {'token': value};
}
