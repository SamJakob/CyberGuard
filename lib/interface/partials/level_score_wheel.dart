import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/interface/components/progress_wheel.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LevelScoreWheel extends HookWidget {
  final LevelInfo level;

  final double size;
  const LevelScoreWheel({
    super.key,
    this.size = 100,
    required this.level,
  });

  static LevelInfo generateLevelInfo(
      {required final Map<String, Account> accounts}) {
    // Compute the raw XP value of the user. For now this is just calculated
    // based on the amount of information provided to the app.
    final perAccountScores = accounts.values
        .map((final entry) =>
            entry.accessMethods.isNotEmpty ? entry.accessMethods.length * 5 : 0)
        .fold(
            0, (final previousValue, final element) => previousValue + element);
    final rawXp = (accounts.length * 20) + perAccountScores;

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

  @override
  Widget build(final BuildContext context) {
    final isMaxLevel = level == const LevelInfo.max();

    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 600),
    )..forward(from: 0);

    return ProgressWheel(
      animation: CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOutCubic,
      ),
      size: size,
      value: level.xp / level.xpPerLevel,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutoSizeText(
              !isMaxLevel ? "${level.xp} XP" : "🤠",
              minFontSize: (size * 0.15).roundToDouble(),
              style: TextStyle(
                fontSize: (size * 0.2).roundToDouble(),
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
              !isMaxLevel ? "Level ${level.level}" : "Max Level",
              minFontSize: (size * 0.085).roundToDouble(),
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
