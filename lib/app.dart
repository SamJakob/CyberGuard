import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/storage/aggregated_secure_data.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/providers/inference.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/providers/user_presence.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:cyberguard/interface/screens/account.dart';
import 'package:cyberguard/interface/screens/root.dart';
import 'package:cyberguard/interface/screens/root/accounts.dart';
import 'package:cyberguard/interface/screens/root/connections.dart';
import 'package:cyberguard/interface/screens/root/home.dart';
import 'package:cyberguard/interface/screens/root/multi_factor.dart';
import 'package:cyberguard/interface/screens/settings.dart';
import 'package:cyberguard/interface/interface.dart';
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
              RootScreen.createTabPageBuilder(
                  context, state, const AccountsScreen()),
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
            ConnectionsScreen(),
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
        ).copyWith(scaffoldBackgroundColor: const Color(0xFFFBF8FF)),
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
          return Interface<_CGAppInitData>(
            initializeApp: (final BuildContext context,
                final InterfaceProtectorMessenger interfaceProtector) async {
              final secureDataStorage = AggregatedSecureDataStorageService();

              UserPresenceProvider? userPresenceProvider;

              try {
                await Future.wait([
                  // Initialize the secure storage service.
                  secureDataStorage.initialize(),
                  // Initialize the user presence provider.
                  Future(() async {
                    userPresenceProvider =
                        await UserPresenceProvider.initialize();
                  }),
                ]);
              } catch (error) {
                if (kDebugMode) print(error);

                String? message;
                if (error is CGSecurityCompatibilityError) {
                  message = error.reason;
                } else if (error is CGUserPresenceCompatibilityError) {
                  message = error.reason;
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
              }

              if (!secureDataStorage.isInitialized) return null;
              if (userPresenceProvider == null) return null;

              await setupLocator();
              locator.registerSingleton<AggregatedSecureDataStorageService>(
                secureDataStorage,
              );

              final storedData = await secureDataStorage.load();

              AccessMethodStore.initialize(
                accessMethods: storedData.accessMethods,
              );

              return _CGAppInitData(
                initialAccounts: storedData.accounts,
                initialAccessMethods: storedData.accessMethods,
                userPresenceProvider: userPresenceProvider!,
              );
            },
            interfaceBuilder: (final BuildContext context, final data) {
              final initSettingsProvider = SettingsProvider();
              final initAccountsProvider = AccountsProvider(
                initialAccounts: data?.initialAccounts,
              );

              final initInferenceProvider = InferenceProvider();
              final inferenceService = InferenceService(
                accountsProvider: initAccountsProvider,
                accountRefs: initAccountsProvider.allAccounts,
              );

              if (!locator.isRegistered<InferenceService>()) {
                locator.registerSingleton<InferenceService>(inferenceService);
              }

              if (initSettingsProvider.appSettings.enableAnalysis) {
                try {
                  // For now just run the inference service immediately.
                  // Later, the data could be snapshotted and passed to the
                  // inference service to run in an isolate.
                  final graph = inferenceService.run();
                  final result = inferenceService.interpret(graph);
                  initInferenceProvider.setData(InferenceProviderData(
                    graph: graph,
                    advice: result,
                  ));
                } catch (_) {}
              }

              return ProviderScope(
                overrides: [
                  settingsProvider.overrideWith(
                    (final ref) => initSettingsProvider,
                  ),
                  accountsProvider.overrideWith(
                    (final ref) => initAccountsProvider,
                  ),
                  accessMethodProvider.overrideWith(
                    (final ref) => AccessMethodStore(),
                  ),
                  if (data?.userPresenceProvider != null)
                    userPresenceProvider.overrideWith(
                      (final ref) => data!.userPresenceProvider,
                    ),
                  inferenceProvider.overrideWith(
                    (final ref) => initInferenceProvider,
                  ),
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

/// A container for the data that is initialized with the [Interface] widget's
/// [initializeApp] callback and subsequently passed to the [Interface]'s
/// [interfaceBuilder] callback.
///
/// This is, for example, used to initialize services and providers that are
/// used by the application, whilst also allowing the [Interface] to display
/// loading and error states for this.
///
/// This class existing and being passed indicates a successful initialization,
/// and null will be passed if the initialization failed, so none of the fields
/// in this class should be nullable (unless they are actually optional).
class _CGAppInitData {
  const _CGAppInitData({
    this.initialAccounts,
    this.initialAccessMethods,
    required this.userPresenceProvider,
  });

  /// If there are any [initialAccounts] that were loaded from storage, they
  /// will be passed here.
  final Map<String, Account>? initialAccounts;

  /// If there are any [initialAccessMethods] that were loaded from storage,
  /// they will be passed here.
  final Map<String, AccessMethod>? initialAccessMethods;

  /// The user presence provider, once initialized, will be passed here.
  /// The initialization step ensures that there is a compliant implementation
  /// and device capabilities to support the user presence feature.
  final UserPresenceProvider userPresenceProvider;
}
