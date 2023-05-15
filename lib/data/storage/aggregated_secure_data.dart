import 'dart:typed_data';

import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/storage/abstract/storage.dart';
import 'package:cyberguard/data/storage/aggregated_secure_data/access_methods.dart';
import 'package:cyberguard/data/storage/aggregated_secure_data/accounts.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/domain/services/abstract/serialization.dart';
import 'package:messagepack/messagepack.dart';

class CGAggregatedSecureData {
  /// The version of the data structure. This is used to ensure that the data
  /// structure is compatible with the current version of the application.
  static const storageDataVersion = 1;

  Map<String, AccessMethod>? accessMethods;
  bool get hasAccessMethods =>
      accessMethods != null && accessMethods!.isNotEmpty;

  Map<String, Account>? accounts;
  bool get hasAccounts => accounts != null && accounts!.isNotEmpty;

  bool get isEmpty => !hasAccessMethods && !hasAccounts;

  CGAggregatedSecureData({
    final Map<String, AccessMethod>? accessMethods,
    final Map<String, Account>? accounts,
  })  : accessMethods = accessMethods ?? {},
        accounts = accounts ?? {};
}

class AggregatedSecureDataSerializationService
    extends SerializationService<CGAggregatedSecureData, Uint8List> {
  final AccountSerializationService _accountSerializationService =
      AccountSerializationService();
  final AccessMethodSerializationService _accessMethodSerializationService =
      AccessMethodSerializationService();

  @override
  CGAggregatedSecureData instantiate() {
    return CGAggregatedSecureData();
  }

  @override
  CGAggregatedSecureData? deserialize(final Uint8List? data) {
    if (data == null) return null;

    final messageUnpacker = Unpacker(data);

    String headerAppName = messageUnpacker.unpackString()!;
    int headerAppVersion = messageUnpacker.unpackInt()!;

    if (headerAppName != kAppName) {
      throw CGError(
        'Invalid data format. Expected $kAppName, got $headerAppName.',
      );
    }

    if (headerAppVersion > CGAggregatedSecureData.storageDataVersion) {
      throw CGError(
        'Invalid data version. Expected at most ${CGAggregatedSecureData.storageDataVersion}, got $headerAppVersion.',
      );
    }

    final accounts = messageUnpacker.unpackBool()!
        ? _accountSerializationService.deserialize(
            Uint8List.fromList(messageUnpacker.unpackBinary()),
          )
        : null;
    final accessMethods = messageUnpacker.unpackBool()!
        ? _accessMethodSerializationService.deserialize(
            Uint8List.fromList(messageUnpacker.unpackBinary()),
          )
        : null;

    return CGAggregatedSecureData(
      accounts: accounts,
      accessMethods: accessMethods,
    );
  }

  @override
  Uint8List? serialize(final CGAggregatedSecureData? data) {
    // Don't bother encrypting/serializing if there's no data.
    if (data == null || data.isEmpty) return null;

    final messagePacker = Packer();
    messagePacker
      ..packString(kAppName)
      ..packInt(CGAggregatedSecureData.storageDataVersion)
      ..packBool(data.accounts != null && data.accounts!.isNotEmpty)
      ..packBinary(
        _accountSerializationService.serialize(data.accounts),
      )
      ..packBool(data.accessMethods != null && data.accessMethods!.isNotEmpty)
      ..packBinary(
        _accessMethodSerializationService.serialize(data.accessMethods),
      );
    return messagePacker.takeBytes();
  }
}

/// A storage service that aggregates [Account]s and [AccessMethod]s using
/// their respective serialization services. A cache is maintained to avoid
/// unnecessary decryption operations to re-merge the distinct repositories
/// back together.
///
/// The cache is automatically updated on calls to [save] and [load], either
/// with individual members of the repository, or with the collective
/// [CGAggregatedSecureData].
///
/// The security justification in caching the data in-memory is that the data
/// would be already accessible in memory were an attacker to gain access to
/// the memory of the application. The data is encrypted at rest, and the
/// encryption/decryption keys are not stored in memory.
///
/// This could be refactored to be more efficient and to not use a cache if
/// necessary, by making aggregation first class in
/// [EncryptedFileStorageService] and - for example - interleaving requests
/// to encrypt and decrypt data from multiple repositories if they are issued
/// at the same time, or in quick succession. However, this changes the
/// security model and a large amount of platform architecture, so this was
/// omitted for time constraints.
class AggregatedSecureDataStorageService
    extends EncryptedFileStorageService<CGAggregatedSecureData> {
  AggregatedSecureDataStorageService()
      : super(
          name: "AggregatedSecureData",
          serializationService: AggregatedSecureDataSerializationService(),
        );

  CGAggregatedSecureData? _cache;

  @override
  Future<CGAggregatedSecureData> load() async {
    CGAggregatedSecureData data = await super.load();
    return _cache = data;
  }

  @override
  Future<void> save(final CGAggregatedSecureData data) async {
    final accessMethods = data.hasAccessMethods
        ? data.accessMethods
        : (AccessMethodStore.isInitialized
            ? AccessMethodStore().snapshot()
            : null);
    final accounts = data.accounts;

    // If neither access methods, nor accounts are specified, do nothing.
    if (accessMethods == null && accounts == null) return;

    // If both accessMethods and accounts are specified, create a new set of
    // data from the both of them and write that directly.
    if (accessMethods != null && accounts != null) {
      _cache = CGAggregatedSecureData(
        accessMethods: accessMethods,
        accounts: accounts,
      );
    }

    // Ensure that the cache is initialized before permitting a save that
    // augments the cache.
    if (_cache == null) {
      throw CGRuntimeError("The data was saved before it was loaded.");
    }

    // Otherwise, if only one of them is specified, update the cache with the
    // the value that changed to merge it with existing data.
    _cache = CGAggregatedSecureData(
      accessMethods: accessMethods ?? _cache!.accessMethods,
      accounts: accounts ?? _cache!.accounts,
    );

    super.save(_cache!);
  }
}
