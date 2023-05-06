/// A response code from the platform secure storage service.
enum PlatformEnhancedSecurityStatus {
  /// The platform supports enhanced storage security.
  available(0),

  /// The platform partially supports enhanced storage security, but it may be
  /// reduced in some way.
  warning(1),

  /// Enhanced storage security is not available on this platform.
  unavailable(2);

  /// The raw code that represents this status.
  final int code;

  /// Creates a new [PlatformEnhancedSecurityStatus] with the given code.
  const PlatformEnhancedSecurityStatus(this.code);

  /// Obtain a [PlatformEnhancedSecurityStatus] from its code.
  static PlatformEnhancedSecurityStatus fromCode(final int code) {
    return PlatformEnhancedSecurityStatus.values
        .firstWhere((final element) => element.code == code);
  }
}

/// A response to a request for enhanced security status.
class PlatformEnhancedSecurityResponse {
  final PlatformEnhancedSecurityStatus status;
  final String? error;

  PlatformEnhancedSecurityResponse(this.status, {this.error});

  /// If platform security is available (even with warnings).
  bool get isAvailable =>
      status.code <= PlatformEnhancedSecurityStatus.warning.code;

  /// If there is a warning message (or error message) about platform security.
  bool get hasWarning =>
      status.code >= PlatformEnhancedSecurityStatus.warning.code;

  /// Creates a new [PlatformEnhancedSecurityResponse] from the given map
  /// representation.
  PlatformEnhancedSecurityResponse.fromMap(final Map<String, dynamic> map)
      : status =
            PlatformEnhancedSecurityStatus.fromCode(map['status'] as int? ?? 2),
        error = map['error'] as String?;
}
