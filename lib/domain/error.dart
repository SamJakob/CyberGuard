import 'package:cyberguard/const/branding.dart';

class CGCompatibilityError extends Error {
  final String reason;

  CGCompatibilityError({final String? reason})
      : reason =
            reason ?? "$kAppName is currently not supported on your device.";

  @override
  String toString() {
    return reason;
  }
}

class CGSecurityCompatibilityError extends CGCompatibilityError {
  CGSecurityCompatibilityError({final String? reason})
      : super(
            reason: reason ??
                "$kAppName is currently not supported on your device because it does not meet security requirements.");
}

class CGUserPresenceCompatibilityError extends CGCompatibilityError {
  CGUserPresenceCompatibilityError({final String? reason})
      : super(
          reason: reason ??
              "$kAppName is currently not supported on your device because it does not support the necessary features.",
        );
}
