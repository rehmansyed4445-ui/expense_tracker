import 'package:flutter/material.dart';

enum TxType { expense, income, transfer }

enum Category {
  food('Food', Icons.restaurant_rounded, Color(0xFFFF8A65)),
  travel('Travel', Icons.directions_car_rounded, Color(0xFF4FC3F7)),
  bills('Bills', Icons.receipt_long_rounded, Color(0xFFBA68C8)),
  shopping('Shopping', Icons.shopping_bag_rounded, Color(0xFFF06292)),
  health('Health', Icons.favorite_rounded, Color(0xFF81C784)),
  salary('Salary', Icons.payments_rounded, Color(0xFF4DB6AC)),
  other('Other', Icons.category_rounded, Color(0xFF90A4AE));

  const Category(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amountPaise,
    required this.type,
    required this.category,
    required this.date,
    this.accountId = '',
    this.toAccountId,
    this.customLabel,
  });

  final String id;
  final String title;

  /// Stored in paise (1/100 rupee) to avoid floating-point rounding errors.
  final int amountPaise;
  final TxType type;
  final Category category;
  final DateTime date;

  /// Account the money leaves (spent, transfer source) or arrives in (received).
  final String accountId;

  /// Transfers only: the account receiving the money.
  final String? toAccountId;

  /// Custom name when the category is Other.
  final String? customLabel;

  bool get isTransfer => type == TxType.transfer;

  /// Name used for grouping in reports. "Other" uses the custom name when given.
  String get groupLabel {
    final custom = customLabel?.trim();
    if (category == Category.other && custom != null && custom.isNotEmpty) {
      return custom;
    }
    return category.label;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amountPaise': amountPaise,
    'type': type.name,
    'category': category.name,
    'date': date.toIso8601String(),
    'accountId': accountId,
    if (toAccountId != null) 'toAccountId': toAccountId,
    if (customLabel != null) 'customLabel': customLabel,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    title: json['title'] as String,
    amountPaise: json['amountPaise'] as int,
    type: TxType.values.byName(json['type'] as String),
    category: Category.values.byName(json['category'] as String),
    date: DateTime.parse(json['date'] as String),
    accountId: (json['accountId'] as String?) ?? '',
    toAccountId: json['toAccountId'] as String?,
    customLabel: json['customLabel'] as String?,
  );
}
