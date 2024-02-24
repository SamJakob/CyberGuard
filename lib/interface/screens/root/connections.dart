import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/domain/providers/inference.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionsScreen extends HookConsumerWidget {
  final ScrollController _scrollController = ScrollController();

  ConnectionsScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          RootAppBar(
            title: "Connections",
            subtitle: "An overview of your account setup.",
          ),
          _renderConnections(context, ref),
        ],
      ),
    );
  }

  Widget _renderConnections(final BuildContext context, final WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final inferenceData = ref.watch(inferenceProvider);

    if (settings.enableAnalysis) {
      if (inferenceData?.graph != null) {
        if (inferenceData!.graph.accounts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const HeroIcon(
                        HeroIcons.key,
                        size: 48,
                      ),
                      Positioned(
                        right: -8,
                        bottom: -8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: HeroIcon(HeroIcons.questionMarkCircle,
                                size: 24),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No accounts.",
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.8),
                    ),
                  ),
                  Text(
                    "You can add accounts in the 'Accounts' tab.",
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      context.go("/accounts");
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HeroIcon(HeroIcons.arrowLongLeft),
                        SizedBox(width: kSpaceUnitPx * 0.25),
                        Text("Go to Accounts"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              const SizedBox(height: 40),
              ...inferenceData.graph.accounts
                  .where((final node) => node.dependents.isNotEmpty)
                  .map((final node) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20)
                      .copyWith(bottom: 20),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              AccountTileIcon(account: node.account, size: 32),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      node.account.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      node.account.accountIdentifier,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 10),
                          for (final dependency in node.commentedDependencies
                              .where((final dependency) =>
                                  dependency.from.type ==
                                      InferenceGraphNodeType.accessMethodRef &&
                                  dependency.from.accessMethodRef
                                      .isNotAn<ExistingAccountAccessMethod>() &&
                                  dependency
                                          .from.accessMethod.userInterfaceKey !=
                                      null))
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      dependency.from.accessMethod
                                          .userInterfaceKey!.icon,
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                            children: [
                                              TextSpan(
                                                text: dependency
                                                                .from
                                                                .accessMethod
                                                                .label !=
                                                            null &&
                                                        dependency
                                                            .from
                                                            .accessMethod
                                                            .label!
                                                            .isNotEmpty
                                                    ? dependency.from
                                                        .accessMethod.label!
                                                    : dependency
                                                        .from
                                                        .accessMethod
                                                        .userInterfaceKey!
                                                        .label,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const WidgetSpan(
                                                  child: SizedBox(width: 5)),
                                              const WidgetSpan(
                                                child: HeroIcon(
                                                  HeroIcons.arrowLongRight,
                                                  size: 14,
                                                ),
                                              ),
                                              const WidgetSpan(
                                                  child: SizedBox(width: 5)),
                                              TextSpan(
                                                text:
                                                    "${node.account.name} (this account)",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  if (dependency.hasComment)
                                    Text(
                                      "${dependency.comment!}.",
                                      textAlign: TextAlign.start,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 10),
                          for (final dependency in node.commentedDependencies
                              .where((final dependency) =>
                                  dependency.from.type ==
                                  InferenceGraphNodeType.accountRef))
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      AccountTileIcon(
                                        account: dependency.from.account,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                            children: [
                                              TextSpan(
                                                text: dependency
                                                    .from.account.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const WidgetSpan(
                                                  child: SizedBox(width: 5)),
                                              const WidgetSpan(
                                                child: HeroIcon(
                                                  HeroIcons.arrowLongRight,
                                                  size: 14,
                                                ),
                                              ),
                                              const WidgetSpan(
                                                  child: SizedBox(width: 5)),
                                              TextSpan(
                                                text:
                                                    "${node.account.name} (this account)",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  if (dependency.hasComment)
                                    Text(
                                      "${dependency.comment!}.",
                                      textAlign: TextAlign.start,
                                    ),
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        );
      }

      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: ApolloLoadingSpinner(),
        ),
      );
    }

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const HeroIcon(
                  HeroIcons.lightBulb,
                  size: 48,
                ),
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: HeroIcon(HeroIcons.pauseCircle, size: 24),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Analysis is disabled.",
              style: TextStyle(
                fontSize: 24,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
              ),
            ),
            Text(
              "You must enable 'Scan Account Setup' to view connections.",
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                context.push("/settings");
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
          ],
        ),
      ),
    );
  }
}
