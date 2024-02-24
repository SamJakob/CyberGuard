import 'package:flutter/services.dart';

class VibrationService {
  final bool _enabled;

  VibrationService._(this._enabled);

  static Future<VibrationService> initialize() async {
    return VibrationService._(true);
  }

  Future<void> vibrateEmphasis() async {
    if (_enabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> vibrateSuccess() async {
    if (_enabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> vibrateError() async {
    if (_enabled) {
      await HapticFeedback.heavyImpact();
    }
  }
}
