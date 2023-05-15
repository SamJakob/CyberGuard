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

  /// The URL of the service that the account belongs to.
  String? _serviceUrl;
  String? get serviceUrl => _serviceUrl;
  set serviceUrl(final String? serviceUrl) {
    _serviceUrl = serviceUrl;
    notifyListeners();
  }

  bool get hasServiceChangePasswordUrl =>
      _serviceChangePasswordUrl != null &&
      _serviceChangePasswordUrl!.isNotEmpty;

  /// The change-password URL of the service that the account belongs to.
  String? _serviceChangePasswordUrl;
  String? get serviceChangePasswordUrl => _serviceChangePasswordUrl;
  set serviceChangePasswordUrl(final String? serviceChangePasswordUrl) {
    _serviceChangePasswordUrl = serviceChangePasswordUrl;
    notifyListeners();
  }

  bool get hasIconUrl => _iconUrl != null && _iconUrl!.isNotEmpty;

  /// The URL of the icon of the service that the account belongs to.
  String? _iconUrl;
  String? get iconUrl => _iconUrl;
  set iconUrl(final String? icon) {
    _iconUrl = icon;
    notifyListeners();
  }

  /// Whether the device provides access to the account.
  bool _deviceProvidesAccess;
  bool get deviceProvidesAccess => _deviceProvidesAccess;
  set deviceProvidesAccess(final bool deviceProvidesAccess) {
    _deviceProvidesAccess = deviceProvidesAccess;
    notifyListeners();
  }

  /// Whether the account is shared with other people.
  bool _accountIsShared;
  bool get accountIsShared => _accountIsShared;
  set accountIsShared(final bool accountIsShared) {
    _accountIsShared = accountIsShared;
    notifyListeners();
  }

  int _accountPriority;
  int get accountPriority => _accountPriority;
  set accountPriority(final int accountPriority) {
    _accountPriority = accountPriority;
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
    final String? serviceChangePasswordUrl,
    final String? iconUrl,
    final bool? deviceProvidesAccess,
    final bool? accountIsShared,
    final int? accountPriority,
  })  : _name = name,
        _accountIdentifier = accountIdentifier,
        accessMethods = accessMethodTree ?? AccessMethodTree.empty(),
        _serviceUrl = serviceUrl,
        _serviceChangePasswordUrl = serviceChangePasswordUrl,
        _iconUrl = iconUrl,
        _deviceProvidesAccess = deviceProvidesAccess ?? false,
        _accountIsShared = accountIsShared ?? false,
        _accountPriority = accountPriority ?? 1 {
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
  }) : this(
          name: name,
          serviceUrl: serviceUrl,
          accountIdentifier: accountIdentifier,
          accessMethodTree: AccessMethodTree({
            AccessMethodStore().register(KnowledgeAccessMethod(
              password,
              userInterfaceKey: AccessMethodInterfaceKey.password,
            )),
          }),
        );

  /// Packs an account into binary data for storage.
  Uint8List pack() {
    final messagePacker = Packer();
    messagePacker
      ..packString(_name)
      ..packString(_accountIdentifier)
      ..packString(_serviceUrl)
      ..packString(_serviceChangePasswordUrl)
      ..packString(_iconUrl)
      ..packBool(_deviceProvidesAccess)
      ..packBool(_accountIsShared)
      ..packInt(_accountPriority)
      ..packBinary(accessMethods.pack());
    return messagePacker.takeBytes();
  }

  /// Unpacks an account from binary data.
  static Account unpack(final Uint8List data) {
    final messageUnpacker = Unpacker(data);

    String name = messageUnpacker.unpackString()!;
    String accountIdentifier = messageUnpacker.unpackString()!;
    String? serviceUrl = messageUnpacker.unpackString();
    String? serviceChangePasswordUrl = messageUnpacker.unpackString();
    String? iconUrl = messageUnpacker.unpackString();
    bool? deviceProvidesAccess = messageUnpacker.unpackBool();
    bool? accountIsShared = messageUnpacker.unpackBool();
    int? accountPriority = messageUnpacker.unpackInt() ?? 1;
    AccessMethodTree accessMethods = AccessMethodTree.unpack(
      Uint8List.fromList(messageUnpacker.unpackBinary()),
    )!;

    return Account(
      name: name,
      accountIdentifier: accountIdentifier,
      accessMethodTree: accessMethods,
      serviceUrl: serviceUrl,
      serviceChangePasswordUrl: serviceChangePasswordUrl,
      iconUrl: iconUrl,
      deviceProvidesAccess: deviceProvidesAccess,
      accountIsShared: accountIsShared,
      accountPriority: accountPriority,
    );
  }
}
