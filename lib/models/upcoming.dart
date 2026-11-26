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
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? 'Payment').toString(),
    amountPaise: json['amountPaise'] is num
        ? (json['amountPaise'] as num).round()
        : int.tryParse('${json['amountPaise']}') ?? 0,
    dueDate: DateTime.tryParse('${json['dueDate']}') ?? DateTime.now(),
    accountId: (json['accountId'] ?? '').toString(),
    category: Category.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => Category.bills,
    ),
  );
}
