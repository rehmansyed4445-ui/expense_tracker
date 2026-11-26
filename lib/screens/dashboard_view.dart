import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../widgets/home_header.dart';

/// Home page: fixed header on top, scrolling body underneath.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.store,
    required this.onOpenReports,
  });

  final ExpenseStore store;

  /// Reports is reached by swiping. Kept for the drawer callback.
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeHeader(store: store),
        Expanded(child: HomeBody(store: store)),
      ],
    );
  }
}
