import 'package:cyberguard/data/struct/platform_message.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

abstract class StorageService {
  /// The storage service name. This is used to determine the base key, under which
  /// stored data is saved.
  final String name;

  bool _isInitialized = false;

  /// Checks whether the storage service has been initialized. Returns true if it was,
  /// otherwise false.
  bool get isInitialized => _isInitialized;

  StorageService({required this.name});

  /// May be used to communicate with lower-level abstraction layers to allocate
  /// storage space, etc., or otherwise ensure the data is accessible.
  ///
  /// A [StorageService] must be [initialize]d before it may be used. This will
  /// include loading existing data from rest.
  @mustCallSuper
  Future<void> initialize() async {
    _isInitialized = true;
  }

  T _ensureInitialized<T>(final T Function() beforeDoing) {
    if (!_isInitialized) {
      throw StateError(
          "Tried to use $runtimeType (Storage Service) but it wasn't initialized.");
    }

    return beforeDoing();
  }

  /// May be used to communicate with lower-level abstraction layers to deallocate
  /// storage space, etc., or otherwise render the data inaccessible.
  ///
  /// Once a call to [uninitialize] has been made, there are no guarantees any of
  /// the data held by the service will be accessible. Therefore, to access the data
  /// again, [initialize] must be called.
  @mustCallSuper
  Future<void> uninitialize() async {
    _isInitialized = false;
  }

  /// Fetches the stored data from at rest, performs any necessary steps to parse the data.
  Future<void> load();

  /// Stores the data to rest. Performs any necessary steps to serialize the data.
  Future<void> save();
}

abstract class EncryptedFileStorageService extends StorageService {
  /// The reference to the Flutter Platform Channel for CyberGuard Secure Storage services.
  static const _platformEncryption =
      MethodChannel("com.samjakob.cyberguard/secure_storage");

  /// The version of the platform channel implementation this service is expecting.
  /// Bump only for breaking changes.
  static const _platformEncryptionVersion = 1;

  /// The identifier for the encryption key this storage service should use. Leave as
  /// null to use the default encryption key.
  final String? encryptionKeyIdentifier;

  /// If set to true, an exception will be thrown if enhanced security cannot be used.
  /// **For now, this must be true unless the device is an emulator/simulator to encourage better security
  /// practice.**
  final bool requiresEnhancedSecurity;

  late PlatformEnhancedSecurityResponse _enhancedSecurityResponse;
  PlatformEnhancedSecurityResponse get hasEnhancedSecurity =>
      super._ensureInitialized(() => _enhancedSecurityResponse);

  /// Whether the current device is a simulator.
  late bool _isSimulator;

  EncryptedFileStorageService({
    required super.name,
    final String? encryptionKeyIdentifier,
  })  : requiresEnhancedSecurity = true,
        encryptionKeyIdentifier =
            encryptionKeyIdentifier ?? "CGA_KEY_${name.toUpperCase()}";

  @override
  @mustCallSuper
  Future<void> initialize() async {
    if (!await _platformChannelPing()) {
      throw CGCompatibilityError();
    }

    // Check if "enhanced security" may be used, and if it must be used.
    _enhancedSecurityResponse = await _checkEnhancedSecurityStatus();
    if (requiresEnhancedSecurity && !_isSimulator) {
      if (!_enhancedSecurityResponse.isAvailable) {
        throw CGSecurityCompatibilityError(
          reason: _enhancedSecurityResponse.error,
        );
      }
    }

    // Generate the encryption keys, if they have not already been generated.
    await _generateEncryptionKey(name: encryptionKeyIdentifier);

    // Load data from disk, if it has not already been loaded. This step will be
    // skipped if no data exists.
    await load();

    super.initialize();
  }

  @override
  @mustCallSuper
  Future<void> uninitialize() async {
    await save();

    // TODO: evict data from memory.

    super.uninitialize();
  }

  /// Loads the encrypted data from disk, then performs decryption of the data.
  @override
  Future<void> load() async {}

  /// Encrypts the data resident in memory, evicts the resident clear-text data
  /// and writes the encrypted payload to disk for a subsequent [load] call.
  @override
  Future<void> save() async {}

  //region Platform Channel Code

  /// Pings the platform channel interface to determine whether there is a compliant
  /// implementation on the current platform. Returns true if there is, otherwise
  /// false.
  Future<bool> _platformChannelPing() async {
    try {
      final Map<dynamic, dynamic> pingResponse = (await _platformEncryption
              .invokeMethod('ping')
              .timeout(const Duration(milliseconds: 1000)))
          as Map<dynamic, dynamic>;

      if (pingResponse.containsKey('is_simulator') &&
          pingResponse['is_simulator'] as bool) {
        _isSimulator = true;
        debugPrint(
            "Device Simulator detected. Enhanced security features will be disabled.");
      } else {
        _isSimulator = false;
      }

      return pingResponse['ping'] == 'pong' &&
          (pingResponse['version'] as int) >= _platformEncryptionVersion;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getStorageLocation() async {
    return (await _platformEncryption.invokeMethod('getStorageLocation'))
        as String;
  }

  Future<PlatformEnhancedSecurityResponse>
      _checkEnhancedSecurityStatus() async {
    Map<dynamic, dynamic> response =
        await _platformEncryption.invokeMethod('enhancedSecurityStatus') as Map;

    return PlatformEnhancedSecurityResponse.fromMap(
      response.cast<String, dynamic>(),
    );
  }

  Future<void> _generateEncryptionKey(
      {final String? name, final bool? overwriteIfExists}) async {
    (await _platformEncryption.invokeMethod(
        'generateKey', {"name": name, "overwriteIfExists": overwriteIfExists}));
  }

  Future<Uint8List> _encrypt(
      {final String? keyName, required final Uint8List data}) async {
    return (await _platformEncryption
        .invokeMethod('encrypt', {"name": keyName, "data": data})) as Uint8List;
  }

  Future<Uint8List> _decrypt(
      {final String? keyName, required final Uint8List data}) async {
    return (await _platformEncryption
        .invokeMethod('decrypt', {"name": keyName, "data": data})) as Uint8List;
  }

  //endregion

  Future<void> test() async {
    const data = "Howdy pardner!";

    var encrypted = await _encrypt(
      keyName: encryptionKeyIdentifier,
      data: Uint8List.fromList(data.codeUnits),
    );

    var decrypted = await _decrypt(
      keyName: encryptionKeyIdentifier,
      data: encrypted,
    );

    print(String.fromCharCodes(decrypted));
  }
}
