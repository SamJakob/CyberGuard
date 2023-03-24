import 'package:cyberguard/data/struct/access_method.dart';

/// Used to represent an account, as a unit of authentication to a service.
class Account {
  /// The identifier (usually, a username or email address) required to access
  /// an account.
  String accountIdentifier;

  /// The disjunction (OR) of access methods required to access the account.
  final AccessMethodTree accessMethods;

  Account({
    required this.accountIdentifier,
    required this.accessMethods,
  });

  Account.withPassword(this.accountIdentifier, final String password)
      : accessMethods = AccessMethodTree({
          KnowledgeAccessMethod(password, label: 'Password'),
        });
}
