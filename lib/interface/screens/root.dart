import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

const tabs = [
  _RootScreenTab(target: '/', icon: HeroIcon(HeroIcons.home), label: "Home"),
  _RootScreenTab(target: '/accounts', icon: HeroIcon(HeroIcons.key), label: "Accounts"),
  _RootScreenTab(target: '/connections', icon: HeroIcon(HeroIcons.lightBulb), label: "Connections"),
  _RootScreenTab(target: '/multi-factor', icon: HeroIcon(HeroIcons.qrCode), label: "Multi-Factor"),
];

class RootScreen extends StatelessWidget {
  final Widget child;
  const RootScreen({final Key? key, required this.child}) : super(key: key);

  /// Creates a [CustomTransitionPage] for a RootScreen tab.
  static Page<void> createTabPageBuilder(final BuildContext context, final GoRouterState state, final Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (final context, final animation, final secondaryAnimation, final child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
          child: child,
        );
      },
    );
  }

  /// Returns the currently selected index (or 0 if an index couldn't be
  /// found).
  int getCurrentIndex(final BuildContext context) {
    final currentLocation = GoRouter.of(context).location;
    final index = tabs.indexWhere((final tab) => tab.target.startsWith(currentLocation));
    return index < 0 ? 0 : index;
  }

  /// Navigates to selected tab; [tabIndex].
  void activateSelectedIndex(final BuildContext context, final int tabIndex) {
    if (tabIndex != getCurrentIndex(context)) {
      context.go(tabs[tabIndex].target);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (final index) => activateSelectedIndex(context, index),
        currentIndex: getCurrentIndex(context),
        useLegacyColorScheme: false,
        type: BottomNavigationBarType.fixed,
        items: tabs,
      ),
    );
  }
}

class _RootScreenTab extends BottomNavigationBarItem {
  /// The page to navigate to when this tab is selected.
  final String target;

  const _RootScreenTab({
    required this.target,
    required super.icon,
    super.label,
  });
}
