import 'dart:convert';
import 'dart:typed_data';

import 'package:cyberguard/app.dart';
import 'package:cyberguard/data/storage/accounts.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() async {
  runApp(
    // Top-level widget to store the state of each of the providers.
    // The entire application (CGApp) is wrapped to allow any widget to access this state.
    const ProviderScope(child: CGApp()),
  );

  final accountStorage = AccountStorageService();
  await accountStorage.initialize();
  print(await accountStorage.generateEncryptionKey());

  Uint8List encryptedPayload = await accountStorage.encrypt(data: Uint8List.fromList(utf8.encode("Hello, world!")));
  print(encryptedPayload);

  Uint8List decryptedPayload = await accountStorage.decrypt(data: encryptedPayload);
  print(utf8.decode(decryptedPayload));
}
