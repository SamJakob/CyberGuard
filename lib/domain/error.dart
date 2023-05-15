import 'package:cyberguard/const/branding.dart';

class CGError {
  final String reason;

  CGError(final String? reason)
      : reason = reason ?? "An unknown error occurred.";

  @override
  String toString() {
    return reason;
  }
}

class CGRuntimeError extends CGError {
  CGRuntimeError(final String? reason)
      : super(reason ?? "An unknown error occurred.");
}

class CGCompatibilityError extends CGError {
  CGCompatibilityError({final String? reason})
      : super(reason ?? "$kAppName is currently not supported on your device.");
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
