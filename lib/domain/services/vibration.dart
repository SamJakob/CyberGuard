import 'package:flutter/services.dart';

class VibrationService {
  final bool _enabled;

  VibrationService._(this._enabled);

  static Future<VibrationService> initialize() async {
    return VibrationService._(true);
  }

  void vibrateEmphasis() async {
    if (_enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void vibrateSuccess() async {
    if (_enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void vibrateError() async {
    if (_enabled) {
      HapticFeedback.heavyImpact();
    }
  }
}
