import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:cyberguard/interface/utility/context.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

class AccountsScreen extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  AccountsScreen({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Scrollbar(
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
            delegate: SliverChildBuilderDelegate((final context, final index) {
              return Center(
                child: Text("item $index"),
              );
            }),
          )
        ],
      ),
    );
  }
}
