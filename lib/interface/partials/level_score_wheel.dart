import 'package:auto_size_text/auto_size_text.dart';
import 'package:cyberguard/interface/components/progress_wheel.dart';
import 'package:cyberguard/interface/utility/context.dart';
import 'package:flutter/material.dart';

class LevelScoreWheel extends StatelessWidget {
  final int xp, level;
  final int xpPerLevel;

  final double size;
  const LevelScoreWheel({
    final Key? key,
    this.size = 100,
    required this.xp,
    required this.level,
    required this.xpPerLevel,
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return ProgressWheel(
      size: size,
      value: xp / xpPerLevel,
      children: [
        AutoSizeText(
          "$xp XP",
          minFontSize: (size * 0.2).roundToDouble(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
        AutoSizeText(
          "Level $level",
          minFontSize: (size * 0.085).roundToDouble(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}
