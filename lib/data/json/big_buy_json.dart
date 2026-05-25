import '../../domain/models/big_buy.dart';

/// JSON serialization extension for [BigBuy], [CreateBigBuyInput],
/// and [UpdateBigBuyInput].
///
/// List API response shape (after envelope unwrap):
/// ```json
/// { "big_buys": [{ ... }, ...] }
/// ```
///
/// Single-item response shape (POST/PATCH):
/// ```json
/// { "big_buy": { ... } }
/// ```
///
/// BigBuy object shape:
/// ```json
/// {
///   "id": "uuid",
///   "title": "string",
///   "amount": 1234,
///   "category_id": "uuid",
///   "date": "RFC3339",
///   "note": "string | null"
/// }
/// ```
extension BigBuyJson on BigBuy {
  /// Deserializes a single [BigBuy] from a JSON object.
  static BigBuy fromJsonObject(Map<String, dynamic> json) {
    return BigBuy(
      id: (json['id'] ?? json['ID'] ?? '') as String,
      title: (json['title'] ?? json['Title'] ?? '') as String,
      amount: (json['amount'] ?? json['Amount'] ?? 0) as int,
      categoryId: (json['category_id'] ?? json['CategoryID'] ?? '') as String,
      date: DateTime.parse((json['date'] ?? json['Date'] ?? json['CreatedAt']) as String),
      note: (json['note'] ?? json['Note']) as String?,
    );
  }

  /// Deserializes a list of [BigBuy] objects from the list API response JSON.
  ///
  /// Reads the array from the `big_buys` key.
  static List<BigBuy> fromJson(Map<String, dynamic> json) {
    final rawList = (json['big_buys'] as List<dynamic>?) ?? [];
    return rawList
        .map((e) => fromJsonObject(e as Map<String, dynamic>))
        .toList();
  }

  /// Deserializes a single [BigBuy] from a single-item API response JSON.
  ///
  /// Reads the object from the `big_buy` key (used for POST/PATCH responses).
  static BigBuy fromSingleJson(Map<String, dynamic> json) {
    return fromJsonObject(json['big_buy'] as Map<String, dynamic>);
  }

  /// Serializes this [BigBuy] to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'date': date.toUtc().toIso8601String(),
        'note': note,
      };
}

/// JSON serialization extension for [CreateBigBuyInput].
extension CreateBigBuyInputJson on CreateBigBuyInput {
  /// Serializes this input to the request body JSON for `POST /big-buys`.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = {
      'title': title,
      'amount': amount,
      'category_id': categoryId,
      'date': date.toUtc().toIso8601String(),
    };
    if (note != null) body['note'] = note;
    return body;
  }
}

/// JSON serialization extension for [UpdateBigBuyInput].
extension UpdateBigBuyInputJson on UpdateBigBuyInput {
  /// Serializes this input to the request body JSON for `PATCH /big-buys/:id`.
  ///
  /// Only non-null fields are included in the request body.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (amount != null) body['amount'] = amount;
    if (categoryId != null) body['category_id'] = categoryId;
    if (date != null) body['date'] = date!.toUtc().toIso8601String();
    if (note != null) body['note'] = note;
    return body;
  }
}
