import 'dart:typed_data';

import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:flutter/cupertino.dart';
import 'package:messagepack/messagepack.dart';

/// Used to represent an account, as a unit of authentication to a service.
class Account with ChangeNotifier {
  /// The name of the service that the account belongs to.
  String _name;
  String get name => _name;
  set name(final String name) {
    _name = name;
    notifyListeners();
  }

  /// The identifier (usually, a username or email address) required to access
  /// an account.
  String _accountIdentifier;
  String get accountIdentifier => _accountIdentifier;
  set accountIdentifier(final String accountIdentifier) {
    _accountIdentifier = accountIdentifier;
    notifyListeners();
  }

  bool get hasServiceUrl => _serviceUrl != null && _serviceUrl!.isNotEmpty;

  String? _serviceUrl;
  String? get serviceUrl => _serviceUrl;
  set serviceUrl(final String? serviceUrl) {
    _serviceUrl = serviceUrl;
    notifyListeners();
  }

  /// The disjunction (OR) of access methods required to access the account.
  final AccessMethodTree accessMethods;

  /// Creates a generic account.
  Account({
    required final String name,
    required final String accountIdentifier,
    final AccessMethodTree? accessMethodTree,
    final String? serviceUrl,
  })  : _name = name,
        _accountIdentifier = accountIdentifier,
        accessMethods = accessMethodTree ?? AccessMethodTree.empty(),
        _serviceUrl = serviceUrl {
    // Proxy change notifications from the access method tree to the
    // account.
    accessMethods.addListener(notifyListeners);
  }

  /// Creates an account with a password as the only access method.
  Account.withPassword(
    final String accountIdentifier,
    final String password, {
    required final String name,
    final String? serviceUrl,
  })  : _name = name,
        _serviceUrl = serviceUrl,
        _accountIdentifier = accountIdentifier,
        accessMethods = AccessMethodTree({
          AccessMethodStore().register(KnowledgeAccessMethod(
            password,
            userInterfaceKey: UserInterfaceKey.password,
            label: 'Password',
          )),
        });

  /// Packs an account into binary data for storage.
  Uint8List pack() {
    final messagePacker = Packer();
    messagePacker
      ..packString(_name)
      ..packString(_accountIdentifier)
      ..packString(serviceUrl)
      ..packBinary(accessMethods.pack());
    return messagePacker.takeBytes();
  }

  /// Unpacks an account from binary data.
  static Account unpack(final Uint8List data) {
    final messageUnpacker = Unpacker(data);

    String name = messageUnpacker.unpackString()!;
    String accountIdentifier = messageUnpacker.unpackString()!;
    String? serviceUrl = messageUnpacker.unpackString();
    AccessMethodTree accessMethods = AccessMethodTree.unpack(
      Uint8List.fromList(messageUnpacker.unpackBinary()),
    )!;

    return Account(
      name: name,
      accountIdentifier: accountIdentifier,
      accessMethodTree: accessMethods,
      serviceUrl: serviceUrl,
    );
  }
}
