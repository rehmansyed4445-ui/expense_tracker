import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/expense_store.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return Row(
      children: [
        IconButton(
          onPressed: () => store.changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                DateFormat('MMMM yyyy').format(store.month),
                key: ValueKey(store.month),
                style: titleStyle,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => store.changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
