import 'package:cyberguard/interface/partials/root_app_bar.dart';
import 'package:flutter/material.dart';

class ConnectionsScreen extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  ConnectionsScreen({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          RootAppBar(
            title: "Connections",
            subtitle: "An overview of your account setup.",
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
