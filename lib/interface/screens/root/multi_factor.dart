import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:flutter/material.dart';

class MultiFactorScreen extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  MultiFactorScreen({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          RootAppBar(
            title: "Multi-Factor",
            subtitle: "Your multi-factor authentication codes.",
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 1000,
            ),
          ),
        ],
      ),
    );
  }
}
