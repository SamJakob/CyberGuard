import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/storage/accounts.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/screens/account.dart';
import 'package:cyberguard/interface/screens/root.dart';
import 'package:cyberguard/interface/screens/root/accounts.dart';
import 'package:cyberguard/interface/screens/root/connections.dart';
import 'package:cyberguard/interface/screens/root/home.dart';
import 'package:cyberguard/interface/screens/root/multi_factor.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:cyberguard/interface/utility/interface_protector.dart';
import 'package:cyberguard/locator.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
              builder: (final context, final state) => SettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/accounts',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (final context, final state) =>
              RootScreen.createTabPageBuilder(context, state, AccountsScreen()),
          routes: [
            GoRoute(
              path: ':account',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (final context, final state) => AccountScreen(
                id: state.pathParameters['account']!,
              ),
            ),
          ],
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
            initializeApp: (final BuildContext context,
                final InterfaceProtectorMessenger interfaceProtector) async {
              final accountStorage = AccountStorageService();
              await accountStorage.initialize().catchError((final dynamic e) {
                if (kDebugMode) print(e);

                String? message;
                if (e is CGSecurityCompatibilityError) {
                  message = e.reason;
                } else {
                  message =
                      "Your device's operating system does not appear to be compatible with CyberGuard.";
                }

                interfaceProtector.insertBlurOverlay(
                  InterfaceProtectorOverlays.compatibilityFail.copyWith(
                    additionalInformation: message,
                  ),
                  blockChanges: true,
                  shouldThrowOnFailure: true,
                  overrideLoading: true,
                );
              });

              locator.registerSingleton<AccountStorageService>(accountStorage);
              return await accountStorage.load();
            },
            interfaceBuilder: (final BuildContext context, final dynamic data) {
              return ProviderScope(
                overrides: [
                  accountProvider.overrideWith(
                    (final ref) => AccountsNotifier(
                      initialAccounts: data as Map<String, Account>?,
                    ),
                  )
                ],
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
