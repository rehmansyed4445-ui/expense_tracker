import 'transaction.dart';

class Upcoming {
  const Upcoming({
    required this.id,
    required this.title,
    required this.amountPaise,
    required this.dueDate,
    required this.accountId,
    required this.category,
  });

  final String id;
  final String title;
  final int amountPaise;
  final DateTime dueDate;
  final String accountId;
  final Category category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amountPaise': amountPaise,
    'dueDate': dueDate.toIso8601String(),
    'accountId': accountId,
    'category': category.name,
  };

  factory Upcoming.fromJson(Map<String, dynamic> json) => Upcoming(
    id: json['id'] as String,
    title: json['title'] as String,
    amountPaise: json['amountPaise'] as int,
    dueDate: DateTime.parse(json['dueDate'] as String),
    accountId: json['accountId'] as String,
    category: Category.values.byName(json['category'] as String),
  );
}
