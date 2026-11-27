import 'package:flutter/material.dart';

class RuledPaperBackground extends StatelessWidget {
  final Widget child;
  const RuledPaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFDF5), // Cream paper color
      child: CustomPaint(painter: _RuledPaperPainter(), child: child),
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Horizontal blue lines
    paint.color = const Color(0xFFAEC6CF).withOpacity(0.4);
    paint.strokeWidth = 1.0;
    const lineHeight = 32.0;
    for (double y = 100; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 2. Vertical red margin line
    paint.color = const Color(0xFFFF9999).withOpacity(0.6);
    paint.strokeWidth = 2.0;
    canvas.drawLine(const Offset(60, 0), Offset(60, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
