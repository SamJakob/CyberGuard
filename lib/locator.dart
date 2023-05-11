import 'package:cyberguard/domain/services/settings.dart';
import 'package:cyberguard/interface/utility/ui_scaling_service.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  // Register UI utility services.
  locator.registerSingleton(UiScalingService.register());
  locator.registerSingleton(await SettingsService.initialize());
}
