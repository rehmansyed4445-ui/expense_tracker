import 'package:flutter/material.dart';

import '../models/account_style.dart';

/// Row of selectable account looks (icon and color).
class AccountStylePicker extends StatelessWidget {
  const AccountStylePicker({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in accountStyles)
          GestureDetector(
            onTap: () => onChanged(s.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedKey == s.key
                    ? s.color
                    : s.color.withValues(alpha: 0.15),
                border: Border.all(
                  color: selectedKey == s.key ? s.color : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Icon(
                s.icon,
                color: selectedKey == s.key ? Colors.white : s.color,
              ),
            ),
          ),
      ],
    );
  }
}

/// Small round icon for an account, in its chosen look.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.styleKey, this.radius = 20});

  final String styleKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = styleFor(styleKey);
    return CircleAvatar(
      radius: radius,
      backgroundColor: s.color.withValues(alpha: 0.18),
      child: Icon(s.icon, size: radius, color: s.color),
    );
  }
}
