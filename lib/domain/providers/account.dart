import 'package:cyberguard/data/storage/aggregated_secure_data.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

/// A wrapper around an [Account] object and its [id].
class AccountRef {
  final String id;
  final Account account;

  const AccountRef(this.id, this.account);

  @override
  String toString() {
    return "${account.name} Account ($id) - ${account.accountIdentifier}";
  }
}

class AccountsProvider extends ChangeNotifier {
  final Map<String, Account> _accounts;

  /// Returns a copy of the entire [accounts] map.
  Map<String, Account> get accounts => Map.unmodifiable(_accounts);

  /// Get the values of the [accounts] map as a list.
  List<Account> get accountsAsList => List.unmodifiable(_accounts.values);

  /// Maps each of the [accounts] to an [AccountRef] object (which is a
  /// wrapper around the [Account] object and its `id`) and returns the
  /// resulting list.
  List<AccountRef> get allAccounts => _accounts.entries
      .map((final MapEntry<String, Account> entry) =>
          AccountRef(entry.key, entry.value))
      .toList();

  AccountsProvider({final Map<String, Account>? initialAccounts})
      : _accounts = initialAccounts ?? <String, Account>{};

  /// Generate a unique ID for the account.
  String _uniqueId() {
    String id = const Uuid().v4();
    if (_accounts.containsKey(id)) {
      id = _uniqueId();
    }
    return id;
  }

  /// Get an account by its [id].
  Account? get(final String id) => _accounts[id];

  /// Get an [AccountRef] by its [id].
  AccountRef? getRef(final String id) => AccountRef(id, _accounts[id]!);

  bool hasWithName(final String name) => getByName(name).isNotEmpty;
  bool hasWithId(final String id) => get(id) != null;

  /// Checks whether an account with the given name and account identifier
  /// combination exists.
  /// Optionally, [exclude] may be specified to ignore a specific account
  /// (which might be useful when editing an account).
  bool hasNameAndAccountIdentifier({
    required final String name,
    required final String accountIdentifier,
    final Account? exclude,
  }) {
    // Get a stream of all the account entries.
    var stream = _accounts.entries.cast<MapEntry<String, Account>>();

    // If exclude is specified, filter out the account with the same name and
    // account identifier as the account to exclude.
    if (exclude != null) {
      stream = stream.where(
        (final element) =>
            element.value.name != exclude.name &&
            element.value.accountIdentifier != exclude.accountIdentifier,
      );
    }

    // Finally, check whether any of the accounts in the stream have the same
    // name and account identifier as the account to check for.
    return stream.any(
      (final MapEntry<String, Account> entry) =>
          entry.value.name == name &&
          entry.value.accountIdentifier == accountIdentifier,
    );
  }

  List<AccountRef> getByName(final String name) {
    return _accounts.entries
        .map((final entry) => AccountRef(entry.key, entry.value))
        .where((final accountRef) => accountRef.account.name == name)
        .toList();
  }

  /// Get the `id` for a given [account].
  String? getIdFor(final Account account) {
    return _accounts.entries
        .cast<MapEntry<String, Account>?>()
        .firstWhere(
          (final MapEntry<String, Account>? entry) => entry!.value == account,
          orElse: () => null,
        )
        ?.key;
  }

  /// Add an account to the list of accounts.
  Future<String> add(final Account account) async {
    final String id = _uniqueId();
    _accounts[id] = account;
    await save();
    notifyListeners();
    return id;
  }

  /// Delete an account by its [id].
  Future<void> deleteById(final String id) async {
    _accounts.remove(id);
    await save();
    notifyListeners();
  }

  /// Delete an account (by value).
  Future<void> delete(final Account account) async {
    _accounts.removeWhere(
        (final String key, final Account value) => value == account);
    await save();
    notifyListeners();
  }

  /// Write the accounts data to storage.
  Future<void> save() async {
    await locator
        .get<AggregatedSecureDataStorageService>()
        .save(CGAggregatedSecureData(
          accounts: _accounts,
        ));
  }
}

final accountsProvider =
    ChangeNotifierProvider<AccountsProvider>((final ref) => throw TypeError());
