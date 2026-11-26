import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Change this one line to switch the background.
const kBackdropStyle = BackdropStyle.dots;

enum BackdropStyle { aurora, dots, plain }

/// Animated background behind the home screen. It only paints behind the UI.
class AppBackdrop extends StatefulWidget {
  const AppBackdrop({super.key, this.style = kBackdropStyle});

  final BackdropStyle style;

  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.style == BackdropStyle.plain) {
      return ColoredBox(color: scheme.surface);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _BackdropPainter(
            style: widget.style,
            t: _c.value,
            colors: [scheme.primary, scheme.tertiary, scheme.secondary],
            base: scheme.surface,
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.style,
    required this.t,
    required this.colors,
    required this.base,
  });

  final BackdropStyle style;
  final double t;
  final List<Color> colors;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    if (style == BackdropStyle.aurora) {
      final a = t * 2 * math.pi;
      for (var i = 0; i < colors.length; i++) {
        final phase = a + i * 2.1;
        final center = Offset(
          size.width * (0.5 + 0.38 * math.cos(phase + i)),
          size.height * (0.32 + 0.22 * math.sin(phase * 0.7 + i)),
        );
        final radius = size.width * (0.55 + 0.1 * math.sin(phase));
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              colors[i].withValues(alpha: 0.38),
              colors[i].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, paint);
      }
    } else if (style == BackdropStyle.dots) {
      const gap = 22.0;
      final shift = t * gap;
      final dot = Paint()..color = colors[0].withValues(alpha: 0.18);
      for (var y = -gap; y < size.height + gap; y += gap) {
        for (var x = -gap; x < size.width + gap; x += gap) {
          canvas.drawCircle(Offset(x + shift, y + shift), 1.6, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.t != t || old.style != style || old.base != base;
}
