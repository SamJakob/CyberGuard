import 'package:cyberguard/const/branding.dart';

class CGCompatibilityError extends Error {
  @override
  String toString() {
    return "$kAppName is currently not supported on your device.";
  }
}

class CGSecurityCompatibilityError extends CGCompatibilityError {
  final String? reason;

  CGSecurityCompatibilityError({this.reason});

  @override
  String toString() {
    return "$kAppName is currently not supported on your device because it does not meet security requirements.";
  }
}
