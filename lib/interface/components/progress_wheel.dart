import 'dart:math';

import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

enum ProgressWheelAnimateFrom { previousValue, start }

typedef ProgressWheelValueComputer = double Function();

class ProgressWheel extends StatefulHookWidget {
  final List<Widget>? children;
  final double size;
  final double? value;
  final ProgressWheelValueComputer? valueComputer;
  final Animation<double>? animation;
  final ProgressWheelAnimateFrom animateFrom;

  const ProgressWheel({
    super.key,
    required this.size,
    this.value,
    this.valueComputer,
    this.children,
    this.animation,
    this.animateFrom = ProgressWheelAnimateFrom.start,
  }) : assert(value != null || valueComputer != null);

  @override
  State<ProgressWheel> createState() => _ProgressWheelState();
}

class _ProgressWheelState extends State<ProgressWheel> {
  double get value => widget.value ?? widget.valueComputer!();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(final BuildContext context) {
    if (widget.animation != null) {
      useListenable(widget.animation);
    }

    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        fit: StackFit.loose,
        children: [
          CustomPaint(
            size: Size.square(widget.size),
            painter: _ProgressWheelIndicator(
              backgroundColor:
                  Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
              color: context.colorScheme.onPrimaryContainer,
              value: Tween(
                      begin:
                          widget.animateFrom == ProgressWheelAnimateFrom.start
                              ? 0.0
                              : usePrevious(value) ?? value,
                      end: value)
                  .evaluate(
                widget.animation ?? const AlwaysStoppedAnimation(1),
              ),
            ),
          ),
          if (widget.children != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: widget.children!,
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
    final renderBox = Rect.fromCenter(
        center: Offset(size / 2, size / 2), width: size, height: size);

    // Draw the background, starting at 0deg and continuing for 360deg (i.e.,
    // the entire circle).
    canvas
      ..drawArc(renderBox, vector_math.radians(0), vector_math.radians(360),
          false, backgroundPaint)

      // Then, draw the foreground from the top (i.e., 270 deg), and continue for
      // the fraction - value - multiplied by 360deg (i.e., a full rotation). So,
      // if value is 0.5, this will continue for 0.5 * 360deg, or 180deg.
      ..drawArc(renderBox, vector_math.radians(270),
          vector_math.radians(360) * value, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant final _ProgressWheelIndicator oldDelegate) =>
      oldDelegate.value != value;
}
