import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/interface/screens/home/home.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The route configuration for the application.
final _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (final context, final state) => HomeScreen(), routes: [
      GoRoute(path: 'settings', builder: (final context, final state) => const SettingsScreen()),
    ]),
  ],
);

/// The top-level
class CGApp extends StatelessWidget {
  const CGApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kAppThemeColor,
        fontFamily: "Source Sans Pro",
        highlightColor: Colors.transparent,
      ),
      themeAnimationCurve: Curves.easeInOutCubic,
      themeAnimationDuration: const Duration(milliseconds: 250),
      routerConfig: _router,
    );
  }
}
