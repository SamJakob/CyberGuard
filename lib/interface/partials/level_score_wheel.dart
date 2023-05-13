import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cyberguard/interface/components/progress_wheel.dart';
import 'package:cyberguard/interface/utility/context.dart';
import 'package:flutter/material.dart';

class LevelScoreWheel extends StatefulWidget {
  final LevelInfo level;

  final double size;
  const LevelScoreWheel({
    final Key? key,
    this.size = 100,
    required this.level,
  }) : super(key: key);

  @override
  State<LevelScoreWheel> createState() => _LevelScoreWheelState();

  static LevelInfo generateLevelInfo({required final int numberOfAccounts}) {
    // Compute the raw XP value of the user.
    final rawXp = numberOfAccounts * 25;

    // Clone the raw XP value so we can use it to compute the user's level.
    int xp = rawXp;

    // Then use the levelling system to compute the user's level and XP
    // for that level.
    for (int level = 0; level < 9; level++) {
      // Compute the XP required to 'satisfy' this level
      final requiredXpForLevel = (100 * pow(1.5, level)).floor();

      if (requiredXpForLevel > xp) {
        return LevelInfo(
          xp: xp,
          level: level + 1,
          xpPerLevel: requiredXpForLevel,
        );
      } else if (requiredXpForLevel == xp && level < 8) {
        return LevelInfo(
          xp: 0,
          level: level + 2,
          xpPerLevel: requiredXpForLevel,
        );
      }

      xp -= requiredXpForLevel;
    }

    // Otherwise return 'Max Level'.
    return const LevelInfo.max();
  }
}

class _LevelScoreWheelState extends State<LevelScoreWheel>
    with SingleTickerProviderStateMixin {
  AnimationController? animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )
      ..forward(from: 0)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final isMaxLevel = widget.level == const LevelInfo.max();

    return ProgressWheel(
      animation: animationController != null
          ? CurvedAnimation(
              parent: animationController!,
              curve: Curves.easeInOutCubic,
            )
          : null,
      size: widget.size,
      value: widget.level.xp / widget.level.xpPerLevel,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutoSizeText(
              !isMaxLevel ? "${widget.level.xp} XP" : "🤠",
              minFontSize: (widget.size * 0.15).roundToDouble(),
              style: TextStyle(
                fontSize: (widget.size * 0.2).roundToDouble(),
                fontWeight: FontWeight.w900,
                color: context.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutoSizeText(
              !isMaxLevel ? "Level ${widget.level.level}" : "Max Level",
              minFontSize: (widget.size * 0.085).roundToDouble(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class LevelInfo {
  final int xp;
  final int level;
  final int xpPerLevel;

  const LevelInfo({
    required this.xp,
    required this.level,
    required this.xpPerLevel,
  });

  const LevelInfo.max() : this(xp: -1, level: -1, xpPerLevel: -1);
}
