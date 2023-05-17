import 'dart:async';

import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/pages/totp_scan.dart';
import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:cyberguard/interface/partials/totp_tile.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MultiFactorScreen extends StatefulHookConsumerWidget {
  const MultiFactorScreen({final Key? key}) : super(key: key);

  @override
  ConsumerState<MultiFactorScreen> createState() => _MultiFactorScreenState();
}

class _MultiFactorScreenState extends ConsumerState<MultiFactorScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  final DateTime pageOpenedAt = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (final timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final List<(AccountRef, TotpUrl)> totpMethods = ref
        .watch(accountsProvider)
        .allAccounts
        .map((final accountRef) {
          // Map each account to a list of TOTP access methods.
          return accountRef.account.accessMethods
              .recursiveWhere(
                (final methodRef) =>
                    methodRef.read is KnowledgeAccessMethod &&
                    methodRef.read.userInterfaceKey ==
                        AccessMethodInterfaceKey.totp,
              )
              .map((final entry) => (
                    accountRef,
                    TotpUrl.deserialize(
                        entry.readAs<KnowledgeAccessMethod>().data)
                  ))
              .where((final element) => element.$2 != null)
              .cast<(AccountRef, TotpUrl)>();
        })
        .expand((final element) => element)
        .toList();

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          RootAppBar(
            title: "TOTP Codes",
            subtitle: "Your time-based authentication codes.",
          ),
          ..._renderTotpMethods(context, totpMethods),
        ],
      ),
    );
  }

  List<Widget> _renderTotpMethods(
    final BuildContext context,
    final List<(AccountRef, TotpUrl)> totpMethods,
  ) {
    if (totpMethods.isEmpty) {
      return [
        SliverFillRemaining(
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
                      HeroIcons.qrCode,
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
                          child:
                              HeroIcon(HeroIcons.questionMarkCircle, size: 24),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "No TOTP Codes.",
                  style: TextStyle(
                    fontSize: 24,
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.8),
                  ),
                ),
                Text(
                  "You don't have any TOTP codes set up in your accounts. You can get started with TOTP by going to the 'Accounts' tab and adding TOTP to an account.",
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
        )
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: totpMethods.length,
            (final context, final index) {
              final entry = totpMethods[index];
              final account = entry.$1;
              final totp = entry.$2;

              return TotpTile(
                totp: totp,
                account: account.account,
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 100),
          child: Center(
            child: Column(
              children: [
                Text(
                  "${totpMethods.length} TOTP Code${totpMethods.length == 1 ? "" : "s"}",
                  style: TextStyle(
                    height: 1,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                Text(
                  "You've reached the end!",
                  style: TextStyle(
                    height: 1,
                    color: context.colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
