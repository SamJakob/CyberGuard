import 'package:cyberguard/data/storage/base/storage.dart';

class AccountStorageService extends EncryptedFileStorageService {
  AccountStorageService()
      : super(name: "Account", encryptionKeyIdentifier: null);
}
