import 'dart:typed_data';

import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/domain/services/abstract/serialization.dart';
import 'package:messagepack/messagepack.dart';

class AccessMethodSerializationService
    extends SerializationService<Map<String, AccessMethod>, Uint8List> {
  @override
  Map<String, AccessMethod> instantiate() {
    return <String, AccessMethod>{};
  }

  @override
  Map<String, AccessMethod>? deserialize(final Uint8List? data) {
    if (data == null) return null;

    final messageUnpacker = Unpacker(data);
    int length = messageUnpacker.unpackMapLength();

    final result = instantiate();
    for (int i = 0; i < length; i++) {
      result[messageUnpacker.unpackString()!] = AccessMethod.unpack(
        Uint8List.fromList(messageUnpacker.unpackBinary()),
      );
    }

    return result;
  }

  @override
  Uint8List? serialize(final Map<String, AccessMethod>? data) {
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
