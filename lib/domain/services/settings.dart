import 'package:cyberguard/const/channels.dart';
import 'package:cyberguard/data/struct/platform_message.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsService {
  /// The reference to the Flutter Platform Channel for CyberGuard Secure Storage services.
  static const _platformEncryption = MethodChannel(kSecureStorageChannel);

  final PackageInfo packageInfo;
  final SecureStorageInfo secureStorageInfo;

  SettingsService._({
    required this.packageInfo,
    required this.secureStorageInfo,
  });

  static Future<SettingsService> initialize() async {
    return SettingsService._(
      packageInfo: await PackageInfo.fromPlatform(),
      secureStorageInfo: await _getSecureStorageInfo(),
    );
  }

  /// Fetches the information about the Secure Storage services.
  static Future<SecureStorageInfo> _getSecureStorageInfo() async {
    return SecureStorageInfo.fromMap(
        (await _platformEncryption.invokeMethod('ping')) as Map);
  }
}

class SecureStorageInfo {
  bool isSimulator;
  PlatformEnhancedSecurityStatus hasEnhancedSecurity;
  String platform;
  String platformVersion;
  int secureStorageVersion;
  String? secureStorageDelegate;
  String? secureStorageDelegateScheme;
  String? enhancedSecurityWarning;

  bool get hasEnhancedSecurityWarning => enhancedSecurityWarning != null;
  bool get hasSecureStorageDelegateInfo => secureStorageDelegate != null;

  SecureStorageInfo({
    required this.isSimulator,
    required this.hasEnhancedSecurity,
    required this.platform,
    required this.platformVersion,
    required this.secureStorageVersion,
    this.secureStorageDelegate,
    this.secureStorageDelegateScheme,
    this.enhancedSecurityWarning,
  });

  SecureStorageInfo.fromMap(final Map<dynamic, dynamic> data)
      : this(
          isSimulator: data['is_simulator'] as bool,
          hasEnhancedSecurity: PlatformEnhancedSecurityStatus.fromCode(
            data['has_enhanced_security'] as int,
          ),
          platform: data['platform'] as String,
          platformVersion: data['platform_version'] as String,
          secureStorageVersion: data['version'] as int,
          secureStorageDelegate: data['storage_encryption_delegate'] as String?,
          secureStorageDelegateScheme:
              data['storage_encryption_delegate_scheme'] as String?,
          enhancedSecurityWarning: data['enhanced_security_warning'] as String?,
        );
}
