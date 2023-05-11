import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:cyberguard/interface/pages/add_account.dart';
import 'package:cyberguard/interface/utility/context.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AccountsScreen extends ConsumerWidget {
  final ScrollController _scrollController = ScrollController();

  AccountsScreen({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final List<AccountRef> accounts = ref.watch(accountProvider).allAccounts;

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
              SliverFixedExtentList(
                itemExtent: 50.0,
                delegate: SliverChildBuilderDelegate(
                  childCount: accounts.length,
                  (final context, final index) {
                    return ListTile(
                      title: Text("${accounts[index]}"),
                      onTap: () {
                        context.go("/accounts/${accounts[index].id}");
                      },
                    );
                  },
                ),
              )
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
}
