import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/partials/level_score_wheel.dart';
import 'package:cyberguard/interface/screens/root/home/home_app_bar.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  final ScrollController _scrollController = ScrollController();

  HomeScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).accounts;

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          CGHomeAppBar(
            expandedHeight: 500,
            actions: [
              IconButton(
                onPressed: () {
                  context.push('/settings');
                },
                icon: const HeroIcon(HeroIcons.cog, size: 32),
              ),
            ],
            childBuilder: (final double scrollPercentage) => Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Container()),
                  Center(
                    child: LevelScoreWheel(
                      level: LevelScoreWheel.generateLevelInfo(
                        accounts: accounts,
                      ),
                      size: (1 - scrollPercentage) * 175,
                    ),
                  ),
                  Expanded(child: Container()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                            horizontal: kSpaceUnitPx * 1.5,
                            vertical: kSpaceUnitPx)
                        .copyWith(top: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HeroIcon(HeroIcons.exclamationTriangle,
                            size: 48,
                            color: context.colorScheme.onPrimaryContainer),
                        const SizedBox(width: kSpaceUnitPx),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                    text:
                                        "You still have sections to complete!",
                                    style: TextStyle(
                                        color: context
                                            .colorScheme.onPrimaryContainer
                                            .withOpacity(0.8))),
                                const TextSpan(text: " "),
                                TextSpan(
                                    text:
                                        "Completing them will improve your score.",
                                    style: TextStyle(
                                        color: context
                                            .colorScheme.onPrimaryContainer)),
                              ],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HeroIcon(
                    HeroIcons.shieldCheck,
                    size: 48,
                    color: context.colorScheme.secondary,
                  ),
                  Text(
                    "No issues!",
                    style: TextStyle(
                      color: context.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    "There are no security issues that need your attention.",
                    style: TextStyle(color: context.colorScheme.onBackground),
                  ),
                  TextButton(
                    onPressed: () {
                      context.go("/accounts");
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Go to Accounts"),
                        SizedBox(width: kSpaceUnitPx * 0.25),
                        HeroIcon(HeroIcons.arrowLongRight),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
