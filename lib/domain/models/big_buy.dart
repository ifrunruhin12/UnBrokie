/// A one-off large purchase record.
///
/// JSON parsing is handled in `data/json/big_buy_json.dart`.
class BigBuy {
  const BigBuy({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
  });

  final String id;
  final String title;

  /// Amount in the smallest currency unit (cents).
  final int amount;

  final String categoryId;
  final DateTime date;
  final String? note;
}

/// Input payload for creating a new big buy via `POST /big-buys`.
class CreateBigBuyInput {
  const CreateBigBuyInput({
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
  });

  final String title;
  final int amount;
  final String categoryId;
  final DateTime date;
  final String? note;
}

/// Input payload for updating an existing big buy via `PATCH /big-buys/:id`.
///
/// All fields are optional — only non-null fields are sent to the API.
class UpdateBigBuyInput {
  const UpdateBigBuyInput({
    this.title,
    this.amount,
    this.categoryId,
    this.date,
    this.note,
  });

  final String? title;
  final int? amount;
  final String? categoryId;
  final DateTime? date;
  final String? note;
}
