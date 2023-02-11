import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/interface/partials/level_score_wheel.dart';
import 'package:cyberguard/interface/screens/home/home_app_bar.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  HomeScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      // body: ElevatedButton(
      //   onPressed: () {
      //     context.go('/settings');
      //   },
      //   child: const Text("Open Settings"),
      // ),
      body: Scrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            CGHomeAppBar(
              expandedHeight: 500,
              childBuilder: (final double scrollPercentage) => Column(
                children: const [
                  SizedBox(height: kSpaceUnitPx),
                  LevelScoreWheel(),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 1000,
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_rounded),
        onPressed: () {},
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.lock_person_rounded), label: "Accounts"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph_rounded), label: "Connections"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: "Multi-Factor"),
        ],
      ),
    );
  }
}
