import 'package:cyberguard/locator.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A class that represents the user-defined settings of the app.
@immutable
class CGASettings {
  /// Initializes a [CGASettings] object with the given settings.
  const CGASettings({
    final bool? enableServiceLookups,
  }) : enableServiceLookups = enableServiceLookups ?? true;

  /// Initializes a [CGASettings] object with default settings for the app.
  const CGASettings.defaultSettings() : this();

  /// Enables the use of network requests to try to identify a service by its
  /// URL with .well-known service discovery.
  final bool enableServiceLookups;

  /// Returns a copy of this [CGASettings] object with the given parameters
  /// replaced.
  CGASettings copyWith({
    final bool? enableServiceLookups,
  }) =>
      CGASettings(
        enableServiceLookups: enableServiceLookups ?? this.enableServiceLookups,
      );
}

/// A provider that provides the [CGASettings] object for the app, allowing
/// the rest of the app to access and alter the user-defined settings,
/// throughout the app.
class SettingsProvider extends StateNotifier<CGASettings> {
  SettingsProvider()
      : super(CGASettings(
          enableServiceLookups:
              locator.get<SharedPreferences>().getBool('enableServiceLookups'),
        ));

  /// Initializes a [SettingsProvider] with the given [settings], which can
  /// either be null (to use the defaults) or a [CGASettings] object which
  /// could be manually loaded from the platform preferences.
  SettingsProvider.fromSettings(final CGASettings? settings)
      : super(settings ?? const CGASettings.defaultSettings());

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

final settingsProvider = StateNotifierProvider<SettingsProvider, CGASettings>(
  (final ref) => throw TypeError(),
);
