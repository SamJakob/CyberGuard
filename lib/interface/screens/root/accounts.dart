import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/partials/account_tile.dart';
import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:cyberguard/interface/pages/add_account.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:cyberguard/interface/utility/levenshtein.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final ScrollController _scrollController = ScrollController();
  TextEditingController? _searchController;

  @override
  void initState() {
    _searchController = TextEditingController();
    _searchController?.addListener(_updateSearchFilter);
    super.initState();
  }

  @override
  void dispose() {
    _searchController?.removeListener(_updateSearchFilter);
    _searchController?.dispose();
    super.dispose();
  }

  void _updateSearchFilter() {
    setState(() {
      // For now, just setState to trigger a rebuild.
    });
  }

  @override
  Widget build(final BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).allAccounts.where((final accountRef) {
      // If there is no search query, don't filter anything.
      if (_searchController!.text.isEmpty) return true;

      // Otherwise, filter by the levenshtein distance.
      return accountRef.account.name
              .hasSearchSimilarity(_searchController!.text) ||
          accountRef.account.accountIdentifier
              .hasSearchSimilarity(_searchController!.text);
    }).toList();

    return Stack(
      children: [
        Scrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              RootAppBar(
                title: "Accounts",
                autoPadBottomWidget: true,
                bottomWidgetSize: 80,
                bottomWidget: Center(
                  child: SizedBox(
                    height: 50,
                    child: TextField(
                      controller: _searchController!,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(1000),
                          gapPadding: 4,
                        ),
                        hintText: "Search",
                        prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass),
                      ),
                    ),
                  ),
                ),
              ),
              ..._renderAccounts(context, accounts),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (final BuildContext context) => const AddAccountPage(),
              );
            },
            label: const Text("Add Account"),
            icon: const HeroIcon(HeroIcons.userPlus),
          ),
        )
      ],
    );
  }

  List<Widget> _renderAccounts(
    final BuildContext context,
    final List<AccountRef> accounts,
  ) {
    if (accounts.isEmpty) {
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
                          child:
                              HeroIcon(HeroIcons.questionMarkCircle, size: 24),
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
                  "You can add accounts by tapping 'Add Account' in the bottom right corner.",
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: accounts.length,
            (final context, final index) {
              return AccountTile(
                accountRef: accounts[index],
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
                  "${accounts.length} Account${accounts.length == 1 ? "" : "s"}",
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
