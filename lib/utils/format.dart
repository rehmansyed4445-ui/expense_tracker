import 'package:intl/intl.dart';

final _whole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _exact = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _dayFormat = DateFormat('d MMM yyyy');

/// Formats rupees, e.g. 25050 paise -> "₹250" (or "₹250.50" when [exact]).
String formatRupees(num rupees, {bool exact = false}) =>
    (exact ? _exact : _whole).format(rupees);

String formatDay(DateTime date) => _dayFormat.format(date);
