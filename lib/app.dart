import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/interface/screens/root.dart';
import 'package:cyberguard/interface/screens/root/accounts.dart';
import 'package:cyberguard/interface/screens/root/connections.dart';
import 'package:cyberguard/interface/screens/root/home.dart';
import 'package:cyberguard/interface/screens/root/multi_factor.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

// The navigator keys and router configuration
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// The route configuration for the application.
final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: <RouteBase>[
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (final context, final state, final child) => RootScreen(child: child),
      routes: [
        GoRoute(
          path: '/',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) => RootScreen.createTabPageBuilder(context, state, HomeScreen()),
          routes: [
            GoRoute(
              path: 'settings',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (final context, final state) => const SettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/accounts',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(context, state, AccountsScreen()),
        ),
        GoRoute(
          path: '/connections',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(context, state, const ConnectionsScreen()),
        ),
        GoRoute(
          path: '/multi-factor',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(context, state, const MultiFactorScreen()),
        )
      ],
    ),
  ],
);

// CGApp
/// The top-level application widget.
class CGApp extends StatelessWidget {
  const CGApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return HeroIconTheme(
      style: HeroIconStyle.solid,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'CyberGuard',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: kAppThemeColor,
          fontFamily: "Source Sans Pro",
          highlightColor: Colors.transparent,
        ),
        themeAnimationCurve: Curves.easeInOutCubic,
        themeAnimationDuration: const Duration(milliseconds: 250),
        routerConfig: _router,
      ),
    );
  }
}
