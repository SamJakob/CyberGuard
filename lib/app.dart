import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/interface/screens/home.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The route configuration for the application.
final _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomeScreen(), routes: [
      GoRoute(path: 'settings', builder: (context, state) => const SettingsScreen()),
    ]),
  ],
);

/// The top-level
class CGApp extends StatelessWidget {
  const CGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard',
      theme: ThemeData(
        primarySwatch: kAppThemeColor,
        fontFamily: "Source Sans Pro",
      ),
      routerConfig: _router,
    );
  }
}
