import 'package:flutter/material.dart';

/// Notebook-paper backdrop. Rules are a subtle texture (not a baseline grid),
/// so text and cards stay readable at any size and in both themes.
class RuledPaperBackground extends StatelessWidget {
  const RuledPaperBackground({
    super.key,
    required this.child,
    this.lineSpacing = 28,
    this.showMargin = true,
    this.marginX = 44,
    this.topInset = 0,
  });

  final Widget child;
  final double lineSpacing;
  final bool showMargin;
  final double marginX;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF14181A) : const Color(0xFFFFFDF5);
    final rule = dark ? const Color(0xFF3A4A52) : const Color(0xFF9FC3D0);
    final margin = dark ? const Color(0xFF7A4A4A) : const Color(0xFFE8A0A0);

    return ColoredBox(
      color: paper,
      child: CustomPaint(
        painter: _PaperPainter(
          spacing: lineSpacing,
          topInset: topInset,
          ruleColor: rule.withValues(alpha: dark ? 0.30 : 0.40),
          marginColor: margin.withValues(alpha: dark ? 0.30 : 0.45),
          showMargin: showMargin,
          marginX: marginX,
        ),
        child: child,
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({
    required this.spacing,
    required this.topInset,
    required this.ruleColor,
    required this.marginColor,
    required this.showMargin,
    required this.marginX,
  });

  final double spacing;
  final double topInset;
  final Color ruleColor;
  final Color marginColor;
  final bool showMargin;
  final double marginX;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = ruleColor
      ..strokeWidth = 0.8;

    for (double y = topInset + spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    if (showMargin) {
      final m = Paint()
        ..color = marginColor
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(marginX, 0), Offset(marginX, size.height), m);
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.spacing != spacing ||
      old.topInset != topInset ||
      old.ruleColor != ruleColor ||
      old.marginColor != marginColor ||
      old.showMargin != showMargin ||
      old.marginX != marginX;
}
