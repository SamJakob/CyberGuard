import 'dart:typed_data';

import 'package:cyberguard/data/storage/base/storage.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:messagepack/messagepack.dart';

class AccountSerializationService
    extends SerializationService<Map<String, Account>, Uint8List> {
  @override
  Map<String, Account> instantiate() {
    return <String, Account>{};
  }

  @override
  Map<String, Account>? deserialize(final Uint8List? data) {
    if (data == null) return null;

    final messageUnpacker = Unpacker(data);
    int length = messageUnpacker.unpackMapLength();

    final result = instantiate();
    for (int i = 0; i < length; i++) {
      result[messageUnpacker.unpackString()!] = Account.unpack(
        Uint8List.fromList(messageUnpacker.unpackBinary()),
      );
    }

    return result;
  }

  @override
  Uint8List? serialize(final Map<String, Account>? data) {
    // Don't bother encrypting/serializing if there's no data.
    if (data == null || data.isEmpty) return null;

    final messagePacker = Packer();
    messagePacker.packMapLength(data.length);
    data.forEach((final key, final value) {
      messagePacker.packString(key);
      messagePacker.packBinary(value.pack());
    });
    return messagePacker.takeBytes();
  }
}

class AccountStorageService
    extends EncryptedFileStorageService<Map<String, Account>> {
  AccountStorageService()
      : super(
          name: "Account",
          serializationService: AccountSerializationService(),
        );
}
