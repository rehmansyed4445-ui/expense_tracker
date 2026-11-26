class Account {
  const Account({
    required this.id,
    required this.name,
    required this.startingPaise,
    this.styleKey = 'bank',
  });

  final String id;
  final String name;

  /// Balance before any transactions were logged.
  final int startingPaise;
  final String styleKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startingPaise': startingPaise,
    'styleKey': styleKey,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    startingPaise: json['startingPaise'] as int,
    styleKey: (json['styleKey'] as String?) ?? 'bank',
  );
}
