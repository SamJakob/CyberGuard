import 'package:cyberguard/locator.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A class that represents the user-defined settings of the app.
@immutable
class CGSettings {
  /// Initializes a [CGSettings] object with the given settings.
  const CGSettings({
    final bool? enableAnalysis,
    final bool? enableServiceLookups,
  })  : enableAnalysis = enableAnalysis ?? true,
        enableServiceLookups = enableServiceLookups ?? true;

  /// Initializes a [CGSettings] object with default settings for the app.
  const CGSettings.defaultSettings() : this();

  /// Enables the use of heuristic analysis to try to identify issues with a
  /// user's online account setup.
  final bool enableAnalysis;

  /// Enables the use of network requests to try to identify a service by its
  /// URL with .well-known service discovery.
  final bool enableServiceLookups;

  /// Returns a copy of this [CGSettings] object with the given parameters
  /// replaced.
  CGSettings copyWith({
    final bool? enableAnalysis,
    final bool? enableServiceLookups,
  }) =>
      CGSettings(
        enableAnalysis: enableAnalysis ?? this.enableAnalysis,
        enableServiceLookups: enableServiceLookups ?? this.enableServiceLookups,
      );
}

/// A provider that provides the [CGSettings] object for the app, allowing
/// the rest of the app to access and alter the user-defined settings,
/// throughout the app.
class SettingsProvider extends StateNotifier<CGSettings> {
  SettingsProvider()
      : super(CGSettings(
          enableAnalysis:
              locator.get<SharedPreferences>().getBool('enableAnalysis'),
          enableServiceLookups:
              locator.get<SharedPreferences>().getBool('enableServiceLookups'),
        ));

  /// Initializes a [SettingsProvider] with the given [settings], which can
  /// either be null (to use the defaults) or a [CGSettings] object which
  /// could be manually loaded from the platform preferences.
  SettingsProvider.fromSettings(final CGSettings? settings)
      : super(settings ?? const CGSettings.defaultSettings());

  /// Enables or disables the use of heuristic analysis to try to identify
  /// issues with a user's online account setup.
  void setEnableAnalysis(final bool enableAnalysis) {
    locator.get<SharedPreferences>().setBool('enableAnalysis', enableAnalysis);
    state = state.copyWith(enableAnalysis: enableAnalysis);
  }

  /// Toggles the [enableAnalysis] setting.
  void toggleEnableAnalysis() {
    setEnableAnalysis(!state.enableAnalysis);
  }

  /// Enables or disables the use of network requests to try to identify a
  /// service by its URL with .well-known service discovery.
  void setEnableServiceLookups(final bool enableServiceLookups) {
    locator
        .get<SharedPreferences>()
        .setBool('enableServiceLookups', enableServiceLookups);
    state = state.copyWith(enableServiceLookups: enableServiceLookups);
  }

  /// Toggles the [enableServiceLookups] setting.
  void toggleEnableServiceLookups() {
    setEnableServiceLookups(!state.enableServiceLookups);
  }
}

final settingsProvider = StateNotifierProvider<SettingsProvider, CGSettings>(
  (final ref) => throw TypeError(),
);
