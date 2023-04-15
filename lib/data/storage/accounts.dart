import 'package:cyberguard/data/storage/base/storage.dart';

class AccountStorageService extends EncryptedStorageService {
  AccountStorageService() : super(name: "Account", encryptionKeyIdentifier: null);
}
