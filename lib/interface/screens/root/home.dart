import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/providers/inference.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/partials/advice_card.dart';
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
    final settings = ref.watch(settingsProvider);
    final inferenceData = ref.watch(inferenceProvider);

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          CGHomeAppBar(
            key: UniqueKey(),
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
                    child: () {
                      Widget icon = ApolloLoadingSpinner(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      );
                      String emphasis = "Running some checks...";
                      String advice =
                          "$kAppName is analyzing your account setup. This may take a few seconds...";

                      if (!settings.enableAnalysis) {
                        icon = HeroIcon(
                          HeroIcons.shieldExclamation,
                          size: 48,
                          color: context.colorScheme.onPrimaryContainer,
                        );
                        emphasis = "Analysis is disabled.";
                        advice =
                            "You can enable it in settings to get advice on how to improve your account setup.";
                      } else {
                        if (accounts.isEmpty ||
                            AccessMethodStore().allAccessMethods.isEmpty) {
                          icon = HeroIcon(
                            HeroIcons.exclamationTriangle,
                            size: 48,
                            color: context.colorScheme.onPrimaryContainer,
                          );
                          emphasis =
                              "You haven't added any accounts with access methods!";
                          advice =
                              "Adding information will improve your score and allow $kAppName to provide you with tips for improving your security.";
                        } else if (inferenceData != null) {
                          if (inferenceData.advice.isEmpty) {
                            icon = HeroIcon(
                              HeroIcons.shieldCheck,
                              size: 48,
                              color: context.colorScheme.onPrimaryContainer,
                            );
                            emphasis = "Your accounts are in good standing!";
                            advice = "No issues have been identified.";
                          } else {
                            icon = HeroIcon(
                              HeroIcons.shieldExclamation,
                              size: 48,
                              color: context.colorScheme.onPrimaryContainer,
                            );
                            emphasis = "You have potential security issues!";
                            advice =
                                "$kAppName has identified ${inferenceData.advice.length} potential security issue${inferenceData.advice.length != 1 ? 's' : ''} with your account setup.";
                          }
                        }
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          icon,
                          const SizedBox(width: kSpaceUnitPx),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: emphasis,
                                    style: TextStyle(
                                        color: context
                                            .colorScheme.onPrimaryContainer
                                            .withOpacity(0.8)),
                                  ),
                                  const TextSpan(text: " "),
                                  TextSpan(
                                    text: advice,
                                    style: TextStyle(
                                        color: context
                                            .colorScheme.onPrimaryContainer),
                                  ),
                                ],
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                              ),
                            ),
                          )
                        ],
                      );
                    }.call(),
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
                mainAxisAlignment: inferenceData?.advice.isNotEmpty ?? false
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ..._renderAdvice(context, inferenceData, settings),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _renderAdvice(
    final BuildContext context,
    final InferenceProviderData? inferenceData,
    final CGSettings settings,
  ) {
    // If the inference service is disabled, show a warning.
    if (!settings.enableAnalysis) {
      return [
        HeroIcon(
          HeroIcons.shieldCheck,
          size: 48,
          color: context.colorScheme.secondary,
        ),
        Text(
          "Analysis disabled!",
          style: TextStyle(
            color: context.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        Text(
          "You've turned off 'Scan Account Setup' which means $kAppName will not automatically scan your accounts for potential security issues.",
          style: TextStyle(color: context.colorScheme.onBackground),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () {
            context.go("/settings");
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Go to Settings"),
              SizedBox(width: kSpaceUnitPx * 0.25),
              HeroIcon(HeroIcons.arrowLongRight),
            ],
          ),
        ),
      ];
    }

    // If inferenceData is null, it's still loading.
    if (inferenceData == null) {
      return [
        ApolloLoadingSpinner(
          color: Theme.of(context).colorScheme.primary,
        ),
      ];
    }

    if (inferenceData.advice.isNotEmpty) {
      return [
        const SizedBox(height: 40),
        ...inferenceData.advice
            .map((final advice) => AdviceCard(advice: advice))
            .toList()
      ];
    }

    // If there's no advice, there's no issues.
    return [
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
      ),
    ];
  }
}
