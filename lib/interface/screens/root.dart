import 'package:cyberguard/interface/utility/context.dart';
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
    return NoTransitionPage<void>(
      key: state.pageKey,
      child: child,
    );
  }

  /// Returns the currently selected index (or null if an index couldn't be found).
  int? getCurrentIndex(final BuildContext context) {
    final currentLocation = GoRouter.of(context).location;
    final index = tabs.indexWhere((final tab) => tab.target.startsWith(currentLocation));
    return index < 0 ? null : index;
  }

  /// Navigates to selected tab; [tabIndex].
  void activateSelectedIndex(final BuildContext context, final int tabIndex) {
    if (tabIndex != getCurrentIndex(context)) {
      context.go(tabs[tabIndex].target);
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: child,
        bottomNavigationBar: _renderBottomNavigationBar(context),
      );

  Widget _renderBottomNavigationBar(final BuildContext context) {
    // Attempt to retrieve the currently selected tab index.
    final currentIndex = getCurrentIndex(context);

    // Check if there is, in fact, a current index (i.e., whether currentIndex != null).
    // If it's null, simply replace the bottom app bar with a placeholder.
    if (currentIndex == null) {
      return Container(
        color: ElevationOverlay.applySurfaceTint(
          NavigationBarTheme.of(context).backgroundColor ?? context.colorScheme.surface,
          NavigationBarTheme.of(context).surfaceTintColor ?? context.colorScheme.surfaceTint,
          NavigationBarTheme.of(context).elevation ?? 3.0,
        ),
        child: SafeArea(
          child: SizedBox(
            height: NavigationBarTheme.of(context).height ?? 80,
            width: double.infinity,
          ),
        ),
      );
    } else {
      return NavigationBar(
        onDestinationSelected: (final index) => activateSelectedIndex(context, index),
        selectedIndex: currentIndex,
        destinations: tabs,
      );
    }
  }
}

class _RootScreenTab extends NavigationDestination {
  /// The page to navigate to when this tab is selected.
  final String target;

  const _RootScreenTab({
    required this.target,
    required super.icon,
    required super.label,
  });
}
