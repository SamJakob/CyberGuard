import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cyberguard/const/channels.dart';
import 'package:cyberguard/const/debugging.dart';
import 'package:cyberguard/data/struct/platform_message.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/domain/services/abstract/serialization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A storage service that stores [DataType] data in [SerializedDataType] format.
abstract class StorageService<DataType, SerializedDataType> {
  /// The storage service name. This is used to determine the base key, under which
  /// stored data is saved.
  final String name;

  final SerializationService<DataType, SerializedDataType> serializationService;

  bool _isInitialized = false;

  /// Checks whether the storage service has been initialized. Returns true if it was,
  /// otherwise false.
  bool get isInitialized => _isInitialized;

  StorageService({
    required this.name,
    required this.serializationService,
  });

  /// May be used to communicate with lower-level abstraction layers to allocate
  /// storage space, etc., or otherwise ensure the data is accessible.
  ///
  /// A [StorageService] must be [initialize]d before it may be used. This will
  /// include loading existing data from rest.
  @mustCallSuper
  Future<void> initialize() async {
    _isInitialized = true;
  }

  ValueType _ensureInitialized<ValueType>(
    final ValueType Function() beforeDoing,
  ) {
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

  /// Checks whether there is currently data stored at rest. Returns true if
  /// there is, otherwise false.
  /// To definitively check if there is any data, check if the storage service
  /// has a backup of existing data (that may be recovered from).
  Future<bool> hasData();

  /// Fetches the stored data from at rest, performs any necessary steps to
  /// parse the data.
  /// Otherwise, returns a new instance of [DataType] if there is no data
  /// available.
  Future<DataType> load();

  /// Stores the data to rest. Performs any necessary steps to serialize the data.
  Future<void> save(final DataType data);

  /// Deletes the data currently at rest.
  /// If there is no data stored at rest, this does nothing.
  Future<void> delete();
}

/// A storage service that stores [DataType] data as encrypted binary data, in a file.
/// This service uses the CyberGuard Secure Storage platform channel to encrypt
/// and decrypt the data with the device's Trusted Execution Environment (TEE).
abstract class EncryptedFileStorageService<DataType>
    extends StorageService<DataType, Uint8List> {
  /// A reference to the Flutter Platform Channel for CyberGuard Secure Storage services.
  static const _secureStoragePlatform = MethodChannel(kSecureStorageChannel);

  /// The version of the platform channel implementation this service is expecting.
  /// Bump only for breaking changes.
  static const _secureStoragePlatformVersion = 1;

  /// The identifier for the encryption key this storage service should use. Leave as
  /// null to use the default encryption key.
  final String? encryptionKeyIdentifier;

  /// The identifier for the service. This is used for file paths.
  final String? _serviceIdentifier;

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
    required super.serializationService,
    final String? encryptionKeyIdentifier,
  })  : requiresEnhancedSecurity = true,
        encryptionKeyIdentifier =
            encryptionKeyIdentifier ?? "CGA_KEY_${name.toUpperCase()}",
        _serviceIdentifier = sha256
            .convert("CGA_SERVICE_${name.toUpperCase()}".codeUnits)
            .toString();

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
    super.initialize();
  }

  @override
  @mustCallSuper
  Future<void> uninitialize() async {
    super.uninitialize();
  }

  /// Fetches the storage path from the platform channel.
  /// This path is intended for the storage of ALREADY ENCRYPTED data, as such
  /// it is not encrypted itself, nor is it intended to be. It may not be
  /// inherently secure, but it should be inaccessible to other apps.
  Future<Directory> _getPlatformStorageLocation() async {
    final platformPath = (await _secureStoragePlatform
        .invokeMethod('getStorageLocation')) as String;

    // Normalize the platformPath by adding a trailing path seperator if there
    // isn't one.
    return Directory(platformPath.endsWith(Platform.pathSeparator)
        ? platformPath
        : '$platformPath${Platform.pathSeparator}');
  }

  Future<File> _getServiceStorageFile() async {
    return File(
        "${(await _getPlatformStorageLocation()).path}$_serviceIdentifier");
  }

  Future<File> _getServiceStorageBackupFile() async {
    return File(
        "${(await _getPlatformStorageLocation()).path}$_serviceIdentifier.backup");
  }

  /// Checks whether there is currently data stored at rest. Returns true if
  /// there is, otherwise false.
  /// To definitively check if there is any data in the event this returns
  /// false, also check [hasBackup] to see if there is a backup of existing
  /// data (that may be recovered from).
  @override
  Future<bool> hasData() async {
    final storageFile = await _getServiceStorageFile();
    return await storageFile.exists();
  }

  /// Checks if there is a backup, for which data may be recovered from and
  /// where data recovery may be attempted.
  Future<bool> hasBackup() async {
    final backupFile = await _getServiceStorageBackupFile();
    return await backupFile.exists();
  }

  /// Loads the encrypted data from disk, then performs decryption of the data.
  /// This step will immediately return the result of
  /// [SerializationService.instantiate] if there is no data to load
  /// (i.e., if the file does not exist).
  @override
  Future<DataType> load() async {
    final storageFile = await _getServiceStorageFile();

    // If the data does not exist, check if there is a backup.
    if (!(await hasData())) {
      // For now, silently recover backups if they exist and the main file does
      // not.
      if (await hasBackup()) {
        await (await _getServiceStorageBackupFile()).rename(storageFile.path);
      } else {
        // Otherwise instantiate with new data.
        return serializationService.instantiate();
      }
    }

    // Read the data from disk.
    final encryptedData = await storageFile.readAsBytes();

    // Decrypt and deserialize the data.
    final decryptedData = await _decrypt(data: encryptedData);
    return serializationService.deserialize(decryptedData) ??
        serializationService.instantiate();
  }

  /// Encrypts the specified data, and writes the encrypted payload to disk for
  /// a subsequent [load] call.
  @override
  Future<void> save(final DataType data) async {
    final storageFile = await _getServiceStorageFile();
    final backupFile = await _getServiceStorageBackupFile();

    // Take a backup of the existing stored data.
    if (await hasData()) {
      // If the backup file already exists, delete it.
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      await (await _getServiceStorageFile()).rename(backupFile.path);
    }

    // Serialize the data, so it can be encrypted.
    final serializedData = serializationService.serialize(data);
    if (serializedData == null) {
      // If there's no data, delete the storage file and backup file, if they
      // exist.
      if (await storageFile.exists()) await storageFile.delete();
      if (await backupFile.exists()) await backupFile.delete();
      return;
    }

    // Encrypt the data.
    final encryptedData = await _encrypt(data: serializedData);

    // Write the encrypted data to disk.
    await storageFile.writeAsBytes(encryptedData);
  }

  /// Deletes the encrypted data from disk.
  /// If there is no data stored on disk, this does nothing.
  @override
  Future<void> delete() async {
    if (await hasData()) {
      await (await _getServiceStorageFile()).delete();
    }
  }

  //region Platform Channel Code

  Future<Map<dynamic, dynamic>> _getPlatformChannelInfo() async {
    return (await _secureStoragePlatform
        .invokeMethod('ping')
        .timeout(const Duration(milliseconds: 1000))) as Map<dynamic, dynamic>;
  }

  /// Pings the platform channel interface to determine whether there is a compliant
  /// implementation on the current platform. Returns true if there is, otherwise
  /// false.
  Future<bool> _platformChannelPing() async {
    try {
      final Map<dynamic, dynamic> pingResponse =
          await _getPlatformChannelInfo();

      if (pingResponse.containsKey('is_simulator') &&
          pingResponse['is_simulator'] as bool) {
        _isSimulator = true;
        debugPrint(
            "Device Simulator detected. Enhanced security features will be disabled.");
      } else {
        _isSimulator = false;
      }

      return pingResponse['ping'] == 'pong' &&
          (pingResponse['version'] as int) >= _secureStoragePlatformVersion;
    } catch (_) {
      return false;
    }
  }

  Future<PlatformEnhancedSecurityResponse>
      _checkEnhancedSecurityStatus() async {
    Map<dynamic, dynamic> response = await _secureStoragePlatform
        .invokeMethod('enhancedSecurityStatus') as Map;

    return PlatformEnhancedSecurityResponse.fromMap(
      response.cast<String, dynamic>(),
    );
  }

  Future<void> _generateEncryptionKey(
      {final String? name, final bool? overwriteIfExists}) async {
    // If (and only if) the device is a simulator, don't run this method.
    if (_isSimulator) return await simulateWait(SimulatedWaitDuration.medium);

    (await _secureStoragePlatform.invokeMethod(
        'generateKey', {"name": name, "overwriteIfExists": overwriteIfExists}));
  }

  Future<Uint8List> _encrypt({required final Uint8List data}) async {
    // If (and only if) the device is a simulator, simply return the data that
    // was provided to it.
    if (_isSimulator) {
      return simulateWaitForData(SimulatedWaitDuration.medium, data: data);
    }

    // Gzip compress the data before encrypting it. This is done to reduce the
    // size of the data that is encrypted, which reduces the amount of time
    // required to encrypt and decrypt the data.
    final compressedData = gzip.encode(data);

    final result = (await _secureStoragePlatform.invokeMethod('encrypt', {
      "name": encryptionKeyIdentifier,
      "data": compressedData,
    })) as Uint8List;

    return result;
  }

  Future<Uint8List> _decrypt({required final Uint8List data}) async {
    // If (and only if) the device is a simulator, simply return the data that
    // was provided to it.
    if (_isSimulator) {
      return simulateWaitForData(SimulatedWaitDuration.medium, data: data);
    }

    // Decrypt the data.
    final decryptedData =
        (await _secureStoragePlatform.invokeMethod('decrypt', {
      "name": encryptionKeyIdentifier,
      "data": data,
    })) as Uint8List;

    return Uint8List.fromList(gzip.decode(decryptedData));
  }

  //endregion
}
