import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class CyberGuardLoadingIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const CyberGuardLoadingIcon({
    super.key,
    this.color,
    this.size = 48,
  });

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: const RiveAnimation.asset(
        "res/rive/cyberguard-loader.riv",
        alignment: Alignment.center,
        fit: BoxFit.fitHeight,
      ),
    );
  }
}
