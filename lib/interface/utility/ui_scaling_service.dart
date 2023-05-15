import 'dart:io';
import 'dart:ui';

import 'package:cyberguard/locator.dart';
import 'package:flutter/widgets.dart';

class UiMetrics {
  final double devicePixelRatio;
  final Size physicalSize;
  final Size screenSize;

  double get physicalWidth => physicalSize.width;
  double get physicalHeight => physicalSize.height;

  double get width => screenSize.width;
  double get height => screenSize.height;

  const UiMetrics({
    required this.devicePixelRatio,
    required this.physicalSize,
    required this.screenSize,
  });

  @override
  String toString() {
    return 'UiMetrics { devicePixelRatio: $devicePixelRatio, physicalSize: $physicalSize, screenSize: $screenSize }';
  }
}

/// The [UiScalingService] is designed to facilitate implementing per-device UI scaling.
///
/// This code is, in part, based on
/// https://github.com/ominibyte/flutter_device_type
class UiScalingService {
  static UiScalingService? _service;
  static Function? _onMetricsChange;
  late UiMetrics _metrics;
  bool _initialized = false;

  /// Return the current display metrics of the main screen.
  /// (For mobile applications, there is only the main screen).
  UiMetrics get metrics => _metrics;

  static int get pixelsPerInch => Platform.isAndroid
      // Android uses 160 pixels per inch by default.
      ? 160
      : Platform.isIOS
          // Similarly, iOS uses 150.
          ? 150
          // Otherwise fall-back to 96 as a sensible default.
          : 96;

  UiScalingService._construct() {
    updateMetrics();
  }

  /// Re-fetches the main display metrics from dart:ui.
  void updateMetrics() {
    final devicePixelRatio =
        PlatformDispatcher.instance.implicitView!.devicePixelRatio;
    final physicalSize = PlatformDispatcher.instance.implicitView!.physicalSize;

    _metrics = UiMetrics(
      devicePixelRatio: devicePixelRatio,
      physicalSize: physicalSize,
      screenSize: Size(
        physicalSize.width / devicePixelRatio,
        physicalSize.height / devicePixelRatio,
      ),
    );

    _initialized = true;
  }

  T forScreen<T>({required final T tablet, required final T phone}) =>
      isTablet() ? tablet : phone;

  /// Heuristically detects whether the device is a tablet based on the device
  /// pixel ratio and corresponding screen size.
  bool isTablet() {
    if (Platform.isAndroid) {
      // Android appears to handle this natively, so tablet scaling should be
      // disabled on Android.
      return false;
    }

    if (_metrics.devicePixelRatio < 2 &&
        (_metrics.physicalWidth >= 1000 || _metrics.physicalHeight >= 1000)) {
      return true;
    } else if (_metrics.devicePixelRatio == 2 &&
        (_metrics.physicalWidth >= 1920 || _metrics.physicalHeight >= 1920)) {
      return true;
    }

    return false;
  }

  /// Initialize the [UiScalingService] and call [updateMetrics] to get the initial
  /// display metrics and subsequently listen for updates to the display
  /// metrics.
  factory UiScalingService.register() {
    // Return the existing UiService if there is one, otherwise construct a
    // new one for use.
    if (_service != null) {
      return _service!;
    } else {
      _service = UiScalingService._construct();
    }

    // Register a handler with dart:ui for when the display metrics change.
    if (_onMetricsChange == null) {
      _onMetricsChange = PlatformDispatcher.instance.onMetricsChanged;
      PlatformDispatcher.instance.onMetricsChanged = () {
        _service!.updateMetrics();
        _onMetricsChange!();
      };
    }

    // Ensure that updateMetrics has been called at least once and then return
    // the service.
    if (!_service!._initialized) _service!.updateMetrics();
    return _service!;
  }
}

extension UIMetricsHelpers on BuildContext {
  T forScreen<T>({required final T tablet, required final T phone}) =>
      locator.get<UiScalingService>().isTablet() ? tablet : phone;
}
