/// A user-defined label for grouping transactions.
///
/// JSON parsing is handled in `data/json/category_json.dart`.
class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}
