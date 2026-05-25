import 'dart:developer' as dev;

import '../../domain/models/category.dart';

/// JSON serialization extension for [Category].
extension CategoryJson on Category {
  static Category fromJsonObject(Map<String, dynamic> json) {
    dev.log('[CategoryJson] parsing: $json');
    return Category(
      id: (json['id'] ?? json['ID'] ?? '') as String,
      name: (json['name'] ?? json['Name'] ?? '') as String,
    );
  }

  static List<Category> fromJson(Map<String, dynamic> json) {
    final rawList = (json['categories'] as List<dynamic>?) ?? [];
    return rawList
        .map((e) => fromJsonObject(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}
