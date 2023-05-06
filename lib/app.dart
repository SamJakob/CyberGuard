import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/storage/accounts.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/interface/screens/root.dart';
import 'package:cyberguard/interface/screens/root/accounts.dart';
import 'package:cyberguard/interface/screens/root/connections.dart';
import 'package:cyberguard/interface/screens/root/home.dart';
import 'package:cyberguard/interface/screens/root/multi_factor.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:cyberguard/interface/utility/interface_protector.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
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
      builder: (final context, final state, final child) =>
          RootScreen(child: child),
      routes: [
        GoRoute(
          path: '/',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(context, state, HomeScreen()),
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
              RootScreen.createTabPageBuilder(
            context,
            state,
            AccountsScreen(),
          ),
        ),
        GoRoute(
          path: '/connections',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(
            context,
            state,
            const ConnectionsScreen(),
          ),
        ),
        GoRoute(
          path: '/multi-factor',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(
            context,
            state,
            const MultiFactorScreen(),
          ),
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
        theme: FlexThemeData.light(
          useMaterial3: true,
          fontFamily: "Source Sans Pro",
          colors: kAppColorScheme.light,
        ),
        darkTheme: FlexThemeData.dark(
          useMaterial3: true,
          fontFamily: "Source Sans Pro",
          colors: kAppColorScheme.dark,
        ),
        themeMode: ThemeMode.system,
        themeAnimationCurve: Curves.easeInOutCubic,
        themeAnimationDuration: const Duration(milliseconds: 250),
        routerConfig: _router,
        builder: (final BuildContext context, final Widget? child) {
          return InterfaceProtector(
            interfaceBuilder: (final BuildContext context) => child!,
            initializeApp: (final BuildContext context) async {
              final accountStorage = AccountStorageService();
              await accountStorage.initialize().catchError((final dynamic e) {
                String? message;
                if (e is CGSecurityCompatibilityError) {
                  message = e.reason;
                } else {
                  message =
                      "Your device's operating system does not appear to be compatible with CyberGuard.";
                }

                InterfaceProtectorMessenger.of(context).insertBlurOverlay(
                  InterfaceProtectorOverlays.compatibilityFail.copyWith(
                    additionalInformation: message,
                  ),
                  blockChanges: true,
                  shouldThrowOnFailure: true,
                  overrideLoading: true,
                );
              });

              await accountStorage.test();
            },
          );
        },
      ),
    );
  }
}
