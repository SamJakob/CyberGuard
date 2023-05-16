import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/data/struct/inference/graph.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/utility/string.dart';

enum InferenceGraphNodeType { accountRef, accessMethodRef }

class InferenceGraphNode extends Vertex {
  final AccountRef? _accountRef;
  final AccessMethodRef? _accessMethodRef;

  /// Convenience getter to get dependencies of this [InferenceGraphNode] with
  /// comments and a type matching (or extending) the [InferenceGraphNode]
  /// type.
  @override
  Set<CommentedEdge<InferenceGraphNode>> get commentedDependencies =>
      getCommentedDependencies<InferenceGraphNode>();

  InferenceGraphNodeType get type {
    if (_accountRef != null) {
      return InferenceGraphNodeType.accountRef;
    } else if (_accessMethodRef != null) {
      return InferenceGraphNodeType.accessMethodRef;
    } else {
      throw Exception(
        'InferenceGraphNode has an unrecognized type.',
      );
    }
  }

  bool get isAccount => type == InferenceGraphNodeType.accountRef;
  bool get isAccessMethod => type == InferenceGraphNodeType.accessMethodRef;

  /// Returns the [AccountRef] for this node. If the node is an
  /// [InferenceGraphNodeType.accountRef], then the [AccountRef] is inferred
  /// from the [AccountRef] property. You are expected to check the [type] of
  AccountRef get accountRef => _accountRef!;

  /// Fetches the [accountRef] and unwraps it.
  Account get account => _accountRef!.account;

  /// Returns the [AccessMethodRef] for this node. If the node is an
  /// [InferenceGraphNodeType.accessMethodRef], then the internal
  /// [AccessMethodRef] is provided. You are expected to check the [type] of
  /// the node before calling this method. (You can also use the [isAccount]
  /// and [isAccessMethod] convenience properties.)
  AccessMethodRef get accessMethodRef => _accessMethodRef!;

  /// Fetches the [accessMethodRef] and unwraps it.
  AccessMethod get accessMethod => _accessMethodRef!.read;

  /// A convenience method to cast the [accessMethod] to a specific type.
  /// This assumes that the [accessMethod] is of the type [T]. You can check
  /// this with the [accessMethodIsA] or [accessMethodIsAn] methods.
  T accessMethodAs<T extends AccessMethod>() => accessMethod as T;

  /// A convenience method to check if the [accessMethod] is of a specific
  /// type.
  bool accessMethodIsA<T extends AccessMethod>() => accessMethodRef.isA<T>();

  /// See [accessMethodIsA].
  bool accessMethodIsAn<T extends AccessMethod>() => accessMethodIsA<T>();

  /// Convenience constructor for creating a [InferenceGraphNode] for an
  /// [AccountRef].
  InferenceGraphNode.forAccount(
    final AccountRef accountRef, {
    required final InferenceGraph owner,
  })  : _accountRef = accountRef,
        _accessMethodRef = null,
        super(owner);

  /// Convenience constructor for creating a [InferenceGraphNode] for an
  /// [AccessMethodRef].
  InferenceGraphNode.forAccessMethod(
    final AccessMethodRef accessMethodRef, {
    required final InferenceGraph owner,
  })  : _accessMethodRef = accessMethodRef,
        _accountRef = null,
        super(owner);

  /// Convenience method to wrap a list of [AccountRef]s into a set of
  /// [InferenceGraphNode]s.
  static Set<InferenceGraphNode> wrap(
    final Iterable<AccountRef> accountRefs, {
    required final InferenceGraph owner,
  }) =>
      accountRefs
          .map((final AccountRef accountRef) =>
              InferenceGraphNode.forAccount(accountRef, owner: owner))
          .toSet();

  @override
  bool operator ==(final Object other) {
    if (other is InferenceGraphNode) {
      if (other.type == type) {
        if (isAccount) {
          return other.accountRef.id == accountRef.id;
        } else if (isAccessMethod) {
          return other.accessMethodRef.id == accessMethodRef.id;
        }
      }
    }

    return super == other;
  }

  @override
  int get hashCode => Object.hash(type, _accountRef?.id, _accessMethodRef?.id);

  @override
  String toString() {
    if (isAccount) {
      return 'InferenceGraphNode(accountRef: $accountRef)';
    } else if (isAccessMethod) {
      return 'InferenceGraphNode(accessMethodRef: $accessMethodRef)';
    } else {
      return 'InferenceGraphNode(type: $type)';
    }
  }
}

/// A graph of [InferenceGraphNode]s.
/// This is used by the [InferenceService] to store the inferred relationships
/// between accounts and access methods.
class InferenceGraph extends Graph<InferenceGraphNode> {
  InferenceGraph() : super();
}

class InferenceService {
  /// The accounts provider to use for looking up accounts.
  final AccountsProvider _accountsProvider;

  /// The distinct set of accounts to perform inference on.
  final Set<AccountRef> _accountRefs;

  InferenceService({
    required final AccountsProvider accountsProvider,
    required final Iterable<AccountRef> accountRefs,
  })  : _accountsProvider = accountsProvider,
        _accountRefs = accountRefs.toSet();

  /// Performs inference on the specified accounts by fetching their data from
  /// the [AccountsProvider] and inferring relationships between accounts and
  /// access methods. This method returns an [InferenceGraph] of the inferred
  /// relationships between accounts. You can subsequently run [interpret] on
  /// the graph to interpret the relationships between accounts and access
  /// methods and return a set of feedback.
  InferenceGraph run() {
    final InferenceGraph graph = InferenceGraph();

    // First find any accounts that are actually linked with an
    // ExistingAccountAccessMethod. These are the accounts that we can
    // immediately infer a relation between. These can then be added to the
    // InferenceGraph.

    // Add the explicitly linked accounts to the graph.
    for (final entry in _getExplicitlyLinkedAccounts(
        where: (final ref) => ref.isNotA<RecoveryEmailAccessMethod>())) {
      // Add an edge from
      graph.addEdges(
        from: InferenceGraphNode.wrap(entry.$2, owner: graph),
        to: InferenceGraphNode.forAccount(entry.$1, owner: graph),
        comment: "This account is directly linked as an access method.",
      );
    }

    // Add recovery email accounts to the graph.
    for (final entry in _getExplicitlyLinkedAccounts(
        where: (final ref) => ref.isA<RecoveryEmailAccessMethod>())) {
      // Add an edge from
      graph.addEdges(
        from: InferenceGraphNode.wrap(entry.$2, owner: graph),
        to: InferenceGraphNode.forAccount(entry.$1, owner: graph),
        comment: "This account is a recovery method.",
      );
    }

    // Now, we need to find any accounts that are linked via an access method
    // implicitly. The user interface does not presently support explicit
    // linking of access methods (only accounts), but this is arguably better
    // from a UI/UX perspective, as it means that the user does not need to
    // explicitly link each access method to each account. Instead, we can
    // infer relationships by analyzing the access methods and looking for
    // patterns that indicate access methods might be shared between accounts.

    // One such example, is if multiple accounts use the same password,
    // security questions or TOTP (somehow?).
    // This can be inferred by scanning KnowledgeAccessMethods for duplicate
    // values.
    // Note that this is a reflexive relationship. If account A has the same
    // password as account B, then account B also has the same password as
    // account A. This means that we can infer a relationship between both
    // accounts. This is therefore added to the graph as two nodes (one for
    // each direction).
    final List<(AccountRef, AccountRef, String?)> duplicateKnowledgeMethods =
        _accountRefs
            // Map each accountRef into a tuple of the account and the set of
            // access methods where the method is a KnowledgeAccessMethod.
            .map((final AccountRef accountRef) => (
                  // Account Reference
                  accountRef,
                  // Access Methods of type KnowledgeAccessMethod
                  accountRef.account.accessMethods
                      .recursiveWhere(
                          // Filter access methods by condition that the access method
                          // is a KnowledgeAccessMethod.
                          (final AccessMethodRef accessMethodRef) =>
                              accessMethodRef.isAn<KnowledgeAccessMethod>())
                      .map((final AccessMethodRef accessMethodRef) =>
                          accessMethodRef.readAs<KnowledgeAccessMethod>())
                ))
            // Filter the list to only include accounts that have at least one
            // KnowledgeAccessMethod.
            .where((final entry) => entry.$2.isNotEmpty)
            // Then filter the KnowledgeAccessMethods to only include those that
            // have a value that is shared by a KnowledgeAccessMethod from another
            // account by mapping the record to a new record that also has an
            // optional message containing a comment describing the link.
            .map((final entry) {
              // Get the set of values from the KnowledgeAccessMethods.
              final dataValues =
                  entry.$2.map((final accessMethod) => accessMethod.data);

              // Get the set of accounts that have a KnowledgeAccessMethod with a
              // matching value and a list of messages describing the link.
              List<(AccountRef, List<String>)> accountsWithMatchingValue = [];
              for (final accountRef in _accountRefs) {
                // Naturally, skip the current account.
                if (accountRef == entry.$1) continue;

                // Produce a potentially empty list of messages describing the
                // link between the accounts.
                // NOTE: IF THE LIST IS EMPTY, IT MEANS THERE IS NO MATCHING
                // VALUE. This is potentially confusing, but is done this way
                // for conciseness.
                final matchingValueRecord = (
                  accountRef,
                  accountRef.account.accessMethods
                      // Get the set of KnowledgeAccessMethods from the account.
                      .recursiveWhere((final accessMethodRef) =>
                          accessMethodRef.isAn<KnowledgeAccessMethod>())
                      // Filter the set of KnowledgeAccessMethods to only include those
                      // that have a value that matches one of the values from the
                      .where((final accessMethodRef) => dataValues.contains(
                          accessMethodRef.readAs<KnowledgeAccessMethod>().data))
                      // Then map each entry to a message describing the link.
                      .map((final accessMethodRef) => "a "
                          "${accessMethodRef.read.label ?? accessMethodRef.read.userInterfaceKey?.name ?? 'value'}")
                      .toList()
                );

                // If there are any matching values, then add the record to the
                // list of accounts with matching values.
                if (matchingValueRecord.$2.isNotEmpty) {
                  accountsWithMatchingValue.add(matchingValueRecord);
                }
              }

              // If there are no other accounts with a matching value, then return null
              // to skip this record.
              if (accountsWithMatchingValue.isEmpty) {
                return null;
              }

              // Otherwise generate the list of duplicates.
              return accountsWithMatchingValue.map(
                (final matchEntry) => (
                  entry.$1,
                  matchEntry.$1,
                  "This account shares ${matchEntry.$2.humanReadableJoin} with "
                      "${matchEntry.$1.account.name}."
                ),
              );
            })
            .where((final element) => element != null)
            .expand((final element) => element!)
            .toList();

    // Add the inferred duplicate knowledge methods to the graph.
    for (var entry in duplicateKnowledgeMethods) {
      // Add an edge from the first account to the second account.
      graph.addEdge(
        from: InferenceGraphNode.forAccount(entry.$2, owner: graph),
        to: InferenceGraphNode.forAccount(entry.$1, owner: graph),
        comment: entry.$3,
      );
    }

    // All access methods that have been assigned to an account by a user need
    // to be added to the graph.
    final Map<AccountRef, Iterable<AccessMethodRef>> manuallyAddedMethods = {
      for (var entry in _accountRefs
          .map((final ref) => MapEntry(ref, ref.account.accessMethods)))
        entry.key: entry.value
    };

    for (final accountRef in manuallyAddedMethods.keys) {
      for (final accessMethodRef in manuallyAddedMethods[accountRef]!) {
        graph.addEdge(
          from: InferenceGraphNode.forAccessMethod(
            accessMethodRef,
            owner: graph,
          ),
          to: InferenceGraphNode.forAccount(
            accountRef,
            owner: graph,
          ),
        );
      }
    }

    // Finally, return the inferred data.
    return graph;
  }

  void interpret(final InferenceGraph graph) {}

  // PRIVATE HELPER METHODS

  /// Gets a list of tuples of accounts and the set of access methods where the
  /// method is an ExistingAccountAccessMethod. Optionally, a [where] function
  /// can provide additional filtering of the access methods.
  List<(AccountRef, Set<AccountRef>)> _getExplicitlyLinkedAccounts({
    final bool Function(AccessMethodRef ref)? where,
  }) {
    return _accountRefs
        // Map each accountRef into a tuple of the account and the set of
        // access methods where the method is an ExistingAccountAccessMethod.
        .map((final AccountRef accountRef) => (
              // Account Reference
              accountRef,
              // Access Methods of type ExistingAccountAccessMethod
              accountRef.account.accessMethods
                  .recursiveWhere(
                    // Filter access methods by condition that the access
                    // method is an ExistingAccountAccessMethod.
                    (final AccessMethodRef accessMethodRef) =>
                        accessMethodRef.isAn<ExistingAccountAccessMethod>() &&
                        (where?.call(accessMethodRef) ?? true),
                  )
                  .map((final AccessMethodRef accessMethodRef) =>
                      accessMethodRef.readAs<ExistingAccountAccessMethod>())
            ))
        // Filter the list to only include accounts that have at least one
        // ExistingAccountAccessMethod.
        .where((final entry) => entry.$2.isNotEmpty)
        // Then expand the list of access methods into a set of dependency
        // accounts.
        .map((final entry) => (
              // Identity-map the dependent account reference.
              entry.$1,
              // Map the dependencies from access method references to the
              // account IDs. Then, filter out any account IDs that are not
              // present in the set of account IDs from the account provider.
              entry.$2
                  .map((final accessMethod) =>
                      _accountsProvider.getRef(accessMethod.accountId))
                  .map((final account) => account!)
                  .toSet(),
            ))
        .toList();
  }
}
