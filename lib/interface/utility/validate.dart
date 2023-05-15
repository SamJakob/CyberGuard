import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

extension Validators on WidgetRef {
  /// Checks whether an account with the given name and account identifier
  /// combination exists.
  /// Optionally, [exclude] may be specified to ignore a specific account
  /// (which might be useful when editing an account).
  String? checkForNameAndAccountIdentifierCombo({
    required final String accountName,
    required final String accountIdentifier,
    final Account? exclude,
  }) {
    return read(accountsProvider).hasNameAndAccountIdentifier(
      name: accountName,
      accountIdentifier: accountIdentifier,
      exclude: exclude,
    )
        ? "An account with this name and account identifier combination already exists. Perhaps you meant to edit that account, or you've already added this account?"
        : null;
  }
}
