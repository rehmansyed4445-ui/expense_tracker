import 'package:flutter/material.dart';

class AccountStyle {
  const AccountStyle(this.key, this.icon, this.color);

  final String key;
  final IconData icon;
  final Color color;
}

const accountStyles = [
  AccountStyle('bank', Icons.account_balance_rounded, Color(0xFF3949AB)),
  AccountStyle(
    'wallet',
    Icons.account_balance_wallet_rounded,
    Color(0xFF00897B),
  ),
  AccountStyle('card', Icons.credit_card_rounded, Color(0xFF8E24AA)),
  AccountStyle('cash', Icons.payments_rounded, Color(0xFF2E7D32)),
  AccountStyle('savings', Icons.savings_rounded, Color(0xFFEF6C00)),
  AccountStyle('phone', Icons.smartphone_rounded, Color(0xFF0277BD)),
];

AccountStyle styleFor(String key) => accountStyles.firstWhere(
  (s) => s.key == key,
  orElse: () => accountStyles.first,
);
