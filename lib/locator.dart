import 'package:cyberguard/domain/services/settings_info.dart';
import 'package:cyberguard/domain/services/vibration.dart';
import 'package:cyberguard/interface/utility/ui_scaling_service.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt locator = GetIt.instance;

/// Register services and providers before the app starts.
/// These should be services that are used by the entire app (i.e., early on
/// in the app's lifecycle) and services that do not take a long time to
/// initialize.
Future<void> setupLocatorEarly() async {
  // Register shared preferences.
  locator
    ..registerSingleton(await SharedPreferences.getInstance())

    // Register UI utility services.
    ..registerSingleton(UiScalingService.register())

    // Register haptic feedback service.
    ..registerSingleton(await VibrationService.initialize());
}

/// Register services and providers after the app starts, but whilst the app is
/// still loading. These can be services that are used widely throughout the
/// app but take a long time to initialize or are not needed immediately.
Future<void> setupLocator() async {
  locator.registerSingleton(await SettingsInfoService.initialize());
}
