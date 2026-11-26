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

  /// Never throws: unknown or missing values fall back to safe defaults.
  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? 'Account').toString(),
    startingPaise: _toInt(json['startingPaise']),
    styleKey: (json['styleKey'] ?? 'bank').toString(),
  );

  static int _toInt(Object? v) =>
      v is num ? v.round() : int.tryParse('$v') ?? 0;
}
