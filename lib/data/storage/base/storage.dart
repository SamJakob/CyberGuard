import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

abstract class StorageService {
  /// The storage service name. This is used to determine the base key, under which
  /// stored data is saved.
  final String name;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  StorageService({required this.name});

  /// May be used to communicate with lower-level abstraction layers to allocate
  /// storage space, etc.,
  /// A [StorageService] must be [initialize]d before it may be used.
  @mustCallSuper
  Future<void> initialize() async {
    _isInitialized = true;
  }

  T _ensureInitialized<T>(final T Function() beforeDoing) {
    if (!_isInitialized) {
      throw StateError("Tried to use $runtimeType (Storage Service) but it wasn't initialized.");
    }

    return beforeDoing();
  }
}

abstract class EncryptedStorageService extends StorageService {
  static const _platformEncryption = MethodChannel("com.samjakob.cyberguard/secure_storage");

  /// The identifier for the encryption key this storage service should use. Leave as
  /// null to use the default encryption key.
  final String? encryptionKeyIdentifier;

  /// If set to true, an exception will be thrown if enhanced security cannot be used.
  /// For now, this must be true as "un-enhanced" security is disabled.
  final bool requiresEnhancedSecurity;

  late bool _hasEnhancedSecurity;
  bool get hasEnhancedSecurity => super._ensureInitialized(() => _hasEnhancedSecurity);

  EncryptedStorageService({
    required super.name,
    required this.encryptionKeyIdentifier,
  }) : requiresEnhancedSecurity = true;

  @override
  @mustCallSuper
  Future<void> initialize() async {
    // Check if "enhanced security" may be used, and if it must be used.
    _hasEnhancedSecurity = await checkEnhancedSecurityStatus();
    if (requiresEnhancedSecurity) {
      if (!_hasEnhancedSecurity) {
        throw StateError("Enhanced Security is not available on this device.");
      }
    }

    // Generate the encryption keys, if they have not already been generated.

    super.initialize();
  }

  Future<bool> checkEnhancedSecurityStatus() async {
    return (await _platformEncryption.invokeMethod('enhancedSecurityStatus')) as bool;
  }

  Future<dynamic> generateEncryptionKey({final String? name}) async {
    return (await _platformEncryption.invokeMethod('generateKey', {"name": name}));
  }

  Future<Uint8List> encrypt({final String? keyName, required final Uint8List data}) async {
    return (await _platformEncryption.invokeMethod('encrypt', {"name": keyName, "data": data})) as Uint8List;
  }

  Future<Uint8List> decrypt({final String? keyName, required final Uint8List data}) async {
    return (await _platformEncryption.invokeMethod('decrypt', {"name": keyName, "data": data})) as Uint8List;
  }
}
