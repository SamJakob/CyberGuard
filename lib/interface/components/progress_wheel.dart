import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

class ProgressWheel extends StatelessWidget {
  final List<Widget>? children;
  final double size;
  final double value;

  const ProgressWheel({
    final Key? key,
    required this.size,
    required this.value,
    this.children,
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        fit: StackFit.loose,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ProgressWheelIndicator(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
              color: Theme.of(context).colorScheme.onPrimary,
              value: value,
            ),
          ),
          if (children != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children!,
              ),
            )
        ],
      ),
    );
  }
}

class _ProgressWheelIndicator extends CustomPainter {
  final Color backgroundColor, color;
  final double value;

  _ProgressWheelIndicator({
    required this.backgroundColor,
    required this.color,
    required this.value,
  });

  @override
  void paint(final Canvas canvas, final Size paintSize) {
    // Determine the size of the shape to render. As the progress wheel is
    // always a square, we'll just take the minimum of either width or height.
    final size = min(paintSize.width, paintSize.height);

    final strokeWidth = size * 0.085;

    // Create a 'paintbrush' for the background.
    final backgroundPaint = Paint()
      ..strokeWidth = strokeWidth
      ..color = backgroundColor
      ..style = PaintingStyle.stroke;

    // Create a 'paintbrush' for the foreground.
    final foregroundPaint = Paint()
      ..strokeWidth = strokeWidth
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Now, compute the render box to draw everything inside of.
    final renderBox = Rect.fromCenter(center: Offset(size / 2, size / 2), width: size, height: size);

    // Draw the background, starting at 0deg and continuing for 360deg (i.e.,
    // the entire circle).
    canvas.drawArc(renderBox, vector_math.radians(0), vector_math.radians(360), false, backgroundPaint);

    // Then, draw the foreground from the top (i.e., 270 deg), and continue for
    // the fraction - value - multiplied by 360deg (i.e., a full rotation). So,
    // if value is 0.5, this will continue for 0.5 * 360deg, or 180deg.
    canvas.drawArc(renderBox, vector_math.radians(270), vector_math.radians(360) * value, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
}
