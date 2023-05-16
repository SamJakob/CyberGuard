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
      return 'InferenceGraphNode(account: ${accountRef.id})';
    } else if (isAccessMethod) {
      return 'InferenceGraphNode(accessMethod: ${accessMethodRef.isA<AccessMethodConjunction>() ? accessMethod.label : accessMethodRef.id})';
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

  /// Convenience method to get all [InferenceGraphNode]s that are of type
  /// [InferenceGraphNodeType.accountRef].
  Set<InferenceGraphNode> get accounts =>
      verticesWhere((final InferenceGraphNode node) => node.isAccount).toSet();

  /// Convenience method to get all [InferenceGraphNode]s that are of type
  /// [InferenceGraphNodeType.accessMethodRef].
  Set<InferenceGraphNode> get accessMethods =>
      verticesWhere((final InferenceGraphNode node) => node.isAccessMethod)
          .toSet();
}

/// Wrapper for an [AccountRef] that is used by the [InferenceService], to
/// store preprocessed versions of the access methods.
class InferenceAccountRef<T extends AccessMethod> {
  final AccountRef accountRef;
  AccessMethodTree? preprocessedTree;

  InferenceAccountRef(this.accountRef, [this.preprocessedTree]);

  static Set<InferenceAccountRef> wrap(final Iterable<AccountRef> accountRefs) {
    return accountRefs.map((final ref) => InferenceAccountRef(ref)).toSet();
  }
}

/// The type of [InferredAdvice]. This is used to categorize the advice that
/// is inferred from the [InferenceGraph] and to store a human-readable name
/// for the type.
enum InferredAdviceType {
  potentialBackdoor(
    "Potential Backdoor",
    "A backdoor is when a more secure, or more important, account can be accessed by a less secure, or less important, account.",
  );

  final String name;
  final String description;
  const InferredAdviceType(this.name, this.description);
}

/// Encapsulates an inference message identified from [interpret]ing an
/// [InferenceGraph].
class InferredAdvice {
  final InferredAdviceType type;
  final String advice;
  final AccountRef from;
  final AccountRef to;

  InferredAdvice(
    this.type, {
    required this.advice,
    required this.from,
    required this.to,
  });

  @override
  String toString() {
    return "InferredAdvice(type: $type, advice: $advice, from: ${from.id}, to: ${to.id})";
  }
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

    // Add the explicitly linked accounts to the graph.
    for (final entry
        in _getMethodsOfType<ExistingAccountAccessMethod, AccountRef>(
      where: (final ref) => ref.isNotA<RecoveryEmailAccessMethod>(),
      transformAccessMethods: (final ref) =>
          _accountsProvider.getRef(ref.accountId)!,
    )) {
      // Add an edge from
      graph.addEdges(
        from: InferenceGraphNode.wrap(entry.$2, owner: graph),
        to: InferenceGraphNode.forAccount(entry.$1, owner: graph),
        commentGenerator: (final from, final to) =>
            "${from.account.name} is directly linked to ${to.account.name} as an access method",
      );
    }

    // Add recovery email accounts to the graph.
    for (final entry
        in _getMethodsOfType<RecoveryEmailAccessMethod, AccountRef>(
      where: (final ref) => ref.isA<RecoveryEmailAccessMethod>(),
      transformAccessMethods: (final ref) =>
          _accountsProvider.getRef(ref.accountId)!,
    )) {
      // Add an edge from
      graph.addEdges(
        from: InferenceGraphNode.wrap(entry.$2, owner: graph),
        to: InferenceGraphNode.forAccount(entry.$1, owner: graph),
        commentGenerator: (final from, final to) =>
            "${from.account.name} is a recovery email address for ${to.account.name}",
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
                              accessMethodRef.isA<KnowledgeAccessMethod>())
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
                          accessMethodRef.isA<KnowledgeAccessMethod>())
                      // Filter the set of KnowledgeAccessMethods to only include those
                      // that have a value that matches one of the values from the
                      .where((final accessMethodRef) => dataValues.contains(
                          accessMethodRef.readAs<KnowledgeAccessMethod>().data))
                      // Then map each entry to a message describing the link.
                      .map((final accessMethodRef) {
                    final interfaceKey = accessMethodRef.read.userInterfaceKey;

                    if (interfaceKey != null &&
                        interfaceKey ==
                            AccessMethodInterfaceKey.securityQuestion) {
                      return "an answer to a security question (\"${accessMethodRef.read.label}\")";
                    }

                    final String name = accessMethodRef.read.label != null &&
                            accessMethodRef.read.label!.isNotEmpty
                        ? accessMethodRef.read.label!
                        : interfaceKey?.name ?? 'value';

                    return "a $name";
                  }).toList()
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
                  "${entry.$1.account.name} shares ${matchEntry.$2.humanReadableJoin} with "
                      "${matchEntry.$1.account.name}"
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
    final Map<InferenceAccountRef, Iterable<AccessMethodRef>>
        manuallyAddedMethods = {
      // For each accountRef, map the accountRef to the set of access methods
      // that have been assigned to the account.
      for (var entry in _preprocess().map(
        (final inferenceRef) => MapEntry(
          inferenceRef,
          inferenceRef.preprocessedTree ??
              inferenceRef.accountRef.account.accessMethods,
        ),
      ))
        entry.key: entry.value
    };

    // Loop over the access methods, adding them to the graph as AccessMethod
    // nodes that point into the account that they are assigned to.
    for (final inferenceRef in manuallyAddedMethods.keys) {
      for (final accessMethodRef in manuallyAddedMethods[inferenceRef]!) {
        graph.addEdge(
          from: InferenceGraphNode.forAccessMethod(
            accessMethodRef,
            owner: graph,
          ),
          to: InferenceGraphNode.forAccount(
            inferenceRef.accountRef,
            owner: graph,
          ),
        );

        // Now, walk each access method recursively to map children into the
        // access node on the graph (if it has any).
        _walkAccessMethod(accessMethodRef, graph: graph, depth: 0);
      }
    }

    // Finally, return the inferred data.
    return graph;
  }

  List<InferredAdvice> interpret(final InferenceGraph graph) {
    // Assign priorities to each account in the graph, based on the number of
    // dependents (i.e., accounts or access methods this one provides access
    // to), then multiply by the user-assigned priority of the account.

    final accountNodes =
        graph.vertices.where((final element) => element.isAccount);

    final Map<InferenceGraphNode, int> priorities = {
      for (final node in accountNodes)
        node: node.recursiveDependents.length * node.account.accountPriority,
    };

    // Check if any higher priority accounts can be accessed by lower priority
    // accounts.
    final potentialBackdoors = accountNodes
        .map((final node) {
          final priority = priorities[node]!;

          // Get the set of accounts that are lower priority than the current
          // account.
          final lowerPriorityAccounts = priorities.keys
              .where((final element) => priorities[element]! < priority);

          // Check if any of the lower priority accounts can access the current
          // account.
          return lowerPriorityAccounts.map((final lowerPriorityAccount) {
            // Check if the lower priority account can access the current account.
            // Return a record as (path, from, to) if it can, otherwise null.
            return (
              graph.journey(
                from: lowerPriorityAccount,
                to: node,
              ),
              lowerPriorityAccount,
              node
            );
          });
        })
        .expand((final element) => element)
        .where((final element) => element.$1 != null);

    // Print the potential backdoors.
    return potentialBackdoors
        .map((final entry) => InferredAdvice(
              InferredAdviceType.potentialBackdoor,
              advice:
                  "The account ${entry.$2.account.name} (less important) could allow an attacker "
                  "to access ${entry.$3.account.name} (more important) because "
                  "${entry.$1!.humanReadableJoin}.",
              from: entry.$2.accountRef,
              to: entry.$3.accountRef,
            ))
        .toList();
  }

  // PRIVATE HELPER METHODS

  /// Gets a list of tuples of accounts and the set of access methods where the
  /// method is of type [T]. Optionally, a [where] function can provide
  /// additional filtering of the access methods.
  /// Additionally, [unwrap] can be used to unwrap the access method reference
  /// into a value of type [U].
  List<(AccountRef, Set<U>)> _getMethodsOfType<T extends AccessMethod, U>({
    final bool Function(AccessMethodRef ref)? where,
    required final U Function(T ref) transformAccessMethods,
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
                        accessMethodRef.isA<T>() &&
                        (where?.call(accessMethodRef) ?? true),
                  )
                  .map((final AccessMethodRef accessMethodRef) =>
                      accessMethodRef.readAs<T>())
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
              entry.$2.map((final ref) => transformAccessMethods(ref)).toSet(),
            ))
        .toList();
  }

  /// Essentially performs a breadth-first walk of the access methods to add
  /// nested methods to the graph.
  void _walkAccessMethod(
    final AccessMethodRef accessMethodRef, {
    required final InferenceGraph graph,
    required final int depth,
  }) {
    // If the method has no access methods, return early.
    if (!accessMethodRef.read.hasAccessMethods) return;

    // For now, we'll abort after 3 levels of nesting. (More than this amount
    // is not anticipated to be possible).
    if (depth > 3) return;

    // Otherwise walk the access method recursively.
    List<AccessMethodRef> pendingRefs = [];
    for (final dependencyAccessMethod in accessMethodRef.read.methods!) {
      graph.addEdge(
        from: InferenceGraphNode.forAccessMethod(
          dependencyAccessMethod,
          owner: graph,
        ),
        to: InferenceGraphNode.forAccessMethod(
          accessMethodRef,
          owner: graph,
        ),
      );

      pendingRefs.add(dependencyAccessMethod);
    }

    // Then walk the dependency access methods themselves.
    for (final ref in pendingRefs) {
      _walkAccessMethod(
        ref,
        graph: graph,
        depth: depth + 1,
      );
    }
  }

  /// Preprocesses the accounts to be inferred. This method, for example, will
  /// convert 2FA accounts into a conjunction of accounts and access methods.
  Set<InferenceAccountRef> _preprocess() {
    Set<InferenceAccountRef> inferenceAccountRefs = {};

    for (final account in _accountRefs) {
      if (account.account.accessMethods.isNotEmpty) {
        inferenceAccountRefs.add(
          InferenceAccountRef(
            account,
            _preprocessAccessMethods(account.account.accessMethods),
          ),
        );
      }
    }

    return inferenceAccountRefs;
  }

  /// Preprocesses the access methods to be inferred. Sub-component of
  /// [_preprocess].
  AccessMethodTree _preprocessAccessMethods(
      final AccessMethodTree originalAccessMethods) {
    final accessMethods = originalAccessMethods.clone();

    // Identify the set of access methods that are multi-factor measures for
    // any of the other measures.
    Set<AccessMethodRef> multiFactorMethods = accessMethods
        .where(
          (final element) => [
            AccessMethodInterfaceKey.totp,
            AccessMethodInterfaceKey.sms,
          ].contains(element.read.userInterfaceKey),
        )
        .toSet();

    // Get the set of access methods that are not the multi-factor method.
    final Set<AccessMethodRef> otherMethods = accessMethods
        .where((final element) => !multiFactorMethods.contains(element))
        .toSet();

    // Now reconstruct the access method tree for these measures to be a
    // conjunction of each other measure and the multi-factor measure.
    for (final multiFactorMethod in multiFactorMethods) {
      // Create a new access method conjunction for each of the other
      // (non-multi-factor) methods and the multi-factor method.
      final conjunctions =
          otherMethods.map((final otherMethod) => EphemeralAccessMethodRef(
                AccessMethodConjunction({
                  multiFactorMethod.clone(),
                  otherMethod.clone(),
                }, accountsProvider: _accountsProvider),
              ));

      // Replace the old methods with the new methods.
      accessMethods.remove(multiFactorMethod);
      accessMethods.removeAll(otherMethods);
      accessMethods.addAll(conjunctions);
    }

    // For now we only process one layer deep.
    // TODO: Process more than one layer deep.
    return accessMethods;
  }
}
