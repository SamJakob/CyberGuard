import 'dart:collection';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:messagepack/messagepack.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

part 'access_method_store.dart';

/// A sorting function for specifying the relative order of [AccessMethod]s
/// within a tree.
typedef AccessMethodTreeSort = int Function(
  AccessMethodRef a,
  AccessMethodRef b,
);

/// Uses the [SplayTreeSet] to implement a self-balancing binary tree of
/// [AccessMethod]s. Also contains implementations of useful sorting methods
/// for balancing the tree.
///
/// Duplicate [AccessMethod]s are not allowed in the tree, hence a [Set]
/// derivative is used.
///
/// This is used instead of a [LinkedHashSet] to allow for more flexibility in
/// changing the 'index' of the set. Presently this is a 'priority', however
/// this is largely going to be a heuristic, determined primarily by the order
/// in which the user inputs the access methods to an account. At a later date,
/// this data structure could be better optimized to fit the specific use case
/// with greater performance.
///
/// ## OPTIMIZATION NOTES:
/// Presently, the use of flexible sorting methods prevents functions that
/// iterate from m to n indexes where 0 <= m < n and n is the number of
/// elements in the set to compute priority with the efficiency that would be
/// afforded to them by the tree structure. This is because we cannot rely on
/// the tree structure to be ordered by priority.
///
/// A possible solution is to introduce an `AccessMethodTreeView` class (where
/// a 'View' class is a recognized pattern in Dart to expose a different
/// representation of a given data structure) which supports sorting, but
/// leaves the original source data intact. See also: [UnmodifiableSetView].
///
/// Another option is to check if
/// [AccessMethodTree.isUsingDefaultSortingMethod] and, if so, apply the
/// relevant optimizations.
///
/// This has not presently been fully explored in the interests of time.
///
/// UPDATE: With the update to Dart 3.0 which prevents final classes from being
/// extended outside of the library in which they are defined, this class no
/// longer directly extends [SplayTreeSet]. Instead, it uses a [SplayTreeSet]
/// as an internal data structure, and exposes the relevant methods.
///
/// As such, it might be possible to implement the above optimizations by
/// converting this to an immutable data structure and exposing a view class
/// which supports sorting.
class AccessMethodTree with ChangeNotifier, Iterable<AccessMethodRef> {
  /// Simply uses [AccessMethod.compareTo] to compare values.
  static int defaultSort(final AccessMethodRef a, final AccessMethodRef b) =>
      a.compareTo(b);

  /// The sorting method currently being used for this tree. Setting this
  /// explicitly (or to something other than [defaultSort] may reduce
  /// performance due to additional sorts being required).
  final AccessMethodTreeSort? currentSortingMethod;

  /// Returns true if either [defaultSort] is used, or if a sorting function
  /// has not been supplied at all (meaning the default was used). Otherwise,
  /// returns false.
  bool get isUsingDefaultSortingMethod =>
      currentSortingMethod == null || currentSortingMethod == defaultSort;

  AccessMethodTree._(final Set<AccessMethodRef> methods,
      {final AccessMethodTreeSort? sort})
      : currentSortingMethod = sort,
        __underlingSet = SplayTreeSet(sort) {
    addAll(methods);
  }

  /// Initializes the tree with an initial set of [AccessMethod]s.
  AccessMethodTree(final Set<AccessMethodRef> methods) : this._(methods);

  /// Initializes an empty access method tree.
  AccessMethodTree.empty() : this._({});

  /// Creates a clone of the tree. Can also be used to [restructure] the tree
  /// to sort based on a different property. If [sort] is not specified, then
  /// the existing sorting method is used for the new tree. If that is also
  /// not specified, or if [defaultSort] is specified, the default will be
  /// used.
  ///
  /// Note that using a [sort] other than the default might cause performance
  /// issues due to additional sorting.
  AccessMethodTree clone({
    final bool keepPriorities = true,
    final AccessMethodTreeSort? sort,
  }) {
    return AccessMethodTree._(
      map((final method) => method.clone(keepPriority: keepPriorities)).toSet(),
      sort: sort == defaultSort ? null : sort ?? currentSortingMethod,
    );
  }

  /// Returns a [clone], structured based on the specified
  /// [AccessMethodTreeSort] method. This serves as a semantic alias for
  /// [clone] that requires a sorting method to be specified.
  ///
  /// Note that using a [sort] other than the default might cause performance
  /// issues due to additional sorting. It is recommended that the tree not be
  /// modified after [restructure] or [clone] is called. You should manipulate
  /// the tree using the default [sort], then run one of these methods and not
  /// modify it after.
  AccessMethodTree restructure(final AccessMethodTreeSort sort) =>
      clone(keepPriorities: true, sort: sort);

  /// Normalizes the priority values of entries in the tree,
  void _normalize() {
    // Start with priority 0 for the highest priority element.
    int currentPriority = 0;
    // Then, loop over each element and assign priority in order of current
    // priority. This requires some 'gymnastics' as we need to first sort them
    // by priority, then restore the user's preferred sorting method.
    // Although we can slightly optimize this by checking if the default
    // sorting method is being used.
    forEach((final element) => element._priority = currentPriority++);
  }

  /// Computes the next highest (unoccupied) priority that will be used when
  /// inserting an entry into the tree.
  ///
  /// For now, this just computes the max priority in the tree and adds one.
  /// Alternative implementations could normalize the tree and then use the
  /// size of the tree, or could search from the size of the tree upwards to
  /// find the next highest unoccupied priority.
  int _nextHighestPriority() {
    if (isEmpty) return 0;

    return 1 +
        map((final method) => method.priority).reduce(
            (final value, final element) => element > value ? element : value);
  }

  /// Used to augment the add event. Specifically, to inject the _owner
  /// property, and then return the result of the whole operation.
  bool _proxyAdd(final AccessMethodRef element) {
    if (element._owner != null) {
      throw DuplicateAccessMethodEntryStateError();
    }

    if (__underlingSet.add(element)) {
      // Associate the element with the current tree.
      element._owner = this;

      // Normalize the tree.
      _normalize();
      notifyListeners();

      return true;
    } else {
      return false;
    }
  }

  void addAll(final Iterable<AccessMethodRef> elements) {
    for (final element in elements) {
      add(element);
    }
  }

  bool add(final AccessMethodRef element) {
    // If the element's priority is negative, give it the highest score to make
    // it the lowest priority.
    if (element._priority < 0) {
      element._priority = _nextHighestPriority();
      return _proxyAdd(element);
    }

    // Otherwise, increment the priority of any other elements in the set that
    // are above this one, to 'insert' this one at the specified priority.
    where((final method) => method._priority >= element._priority)
        .forEach((final method) => method._priority++);

    // Then permit this element to be added.
    return _proxyAdd(element);
  }

  /// Used to augment the remove event. Specifically, to inject the _owner
  /// property, and then return the result of the whole operation.
  bool _proxyRemove(final AccessMethodRef element) {
    if (__underlingSet.remove(element)) {
      // Disassociate the element with the current tree.
      element._owner = null;

      // Normalize the tree.
      _normalize();
      notifyListeners();

      return true;
    } else {
      return false;
    }
  }

  bool remove(final Object? object) {
    // If the object is not a valid possible entry in the set, just return
    // false.
    if (object == null || object is! AccessMethodRef) return false;

    // If the element is not in the tree, simply return false.
    if (!contains(object)) return false;

    return _proxyRemove(object);
  }

  void removeAll(final Iterable<Object?> elements) {
    for (Object? element in elements) {
      remove(element);
    }
  }

  void removeWhere(final bool Function(AccessMethodRef element) test) {
    List<Object?> toRemove = [];

    for (AccessMethodRef element in this) {
      if (test(element)) toRemove.add(element);
    }

    removeAll(toRemove);
  }

  List<AccessMethodRef> recursiveWhere(
      final bool Function(AccessMethodRef methodRef) test) {
    Set<AccessMethodRef> results = {};

    for (AccessMethodRef element in this) {
      if (test(element)) results.add(element);

      if (element.read.methods != null && element.read.methods!.isNotEmpty) {
        results.addAll(
            (element.read.methods as AccessMethodTree).recursiveWhere(test));
      }
    }

    return results.toList();
  }

  /// Returns true if any element in the tree matches the specified [test].
  /// This is a recursive search, and will search all children of the tree.
  /// If you want to search only the top level, use the built-in method
  /// [contains].
  bool hasMethodWhere(final bool Function(AccessMethodRef methodRef) test) {
    return recursiveWhere(test).isNotEmpty;
  }

  @override
  String toString() {
    String childStr = "(empty)";
    if (isNotEmpty) {
      childStr = "\t";

      for (AccessMethodRef methodRef in this) {
        final method = methodRef.read;
        childStr += "$method${method != last.read ? '\n' : ''}";
      }
    }

    return 'AccessMethodTree (requires SOME factor)\n${childStr.replaceAll('\n', '\n\t')}';
  }

  /// Pack the tree into binary data.
  Uint8List pack() {
    final messagePacker = Packer();

    messagePacker.packListLength(length);
    for (final method in this) {
      messagePacker.packBinary(method.pack());
    }

    return messagePacker.takeBytes();
  }

  /// Unpack the tree from binary data.
  static AccessMethodTree? unpack(final Uint8List data) {
    final messageUnpacker = Unpacker(data);
    final tree = AccessMethodTree.empty();

    int length = messageUnpacker.unpackListLength();

    Set<AccessMethodRef> methods = {};
    for (int i = 0; i < length; i++) {
      methods.add(AccessMethodRef.unpack(Uint8List.fromList(
        messageUnpacker.unpackBinary(),
      )));
    }

    // addAll assigns the owner of each entry, so we don't need to do that
    // above.
    tree.addAll(methods);
    return tree;
  }

  // -- PRIVATE. DO NOT MODIFY OR REMOVE. --------------------------------------

  /// This should only be used by [_proxyAdd] and [_proxyRemove]. Failure to
  /// adhere to this can cause synchronization problems.
  SplayTreeSet<AccessMethodRef> __underlingSet;

  @override
  Iterator<AccessMethodRef<AccessMethod>> get iterator =>
      __underlingSet.iterator;

  /// Convenience method to 'promote' an iterable into an [AccessMethodTree].
  /// This is a shim to allow the use of [AccessMethodTree] in places where
  /// [Iterable] is expected, which was the case in the original design (as
  /// [AccessMethodTree] was a subclass of [SplayTreeSet]).
  static AccessMethodTree? promote(final Iterable<AccessMethodRef>? methods) {
    return methods != null ? AccessMethodTree(methods.toSet()) : null;
  }
}

enum AccessMethodInterfaceKey {
  /// Another account.
  otherAccount("Other Account"),

  /// The user interface key for a password access method.
  password("Password, Passphrase or PIN"),

  /// The user interface key for a TOTP access method.
  totp("TOTP"),

  /// The user interface key for an SMS-based access method.
  sms("SMS"),

  /// The user interface key for a biometric access method.
  biometric("Biometric"),

  /// The user interface key for a security question and answer pair
  /// access method.
  securityQuestion("Security Question");

  final String label;

  const AccessMethodInterfaceKey(this.label);

  static AccessMethodInterfaceKey fromName(final String name) {
    return AccessMethodInterfaceKey.values
        .singleWhere((final element) => name == element.name);
  }
}

typedef AccessMethodAdditionalFieldsPacker = void Function(Packer packer);
typedef AccessMethodInstantiator<T extends AccessMethod> = T Function(
    Unpacker unpacker);

/// Used to represent a means of accessing an [Account].
@sealed
abstract class AccessMethod {
  /// A key used to identify the user interface to use for this access method.
  AccessMethodInterfaceKey? userInterfaceKey;

  /// The user-defined label of the access method.
  String? label;

  /// Any extra data associated with this access method. This is intended to
  /// be used for the [userInterfaceKey] to provide additional data to the
  /// user. This is also specific to the [userInterfaceKey] and is not
  /// interpreted by the [AccessMethod] itself, so it is likely to be an
  /// arbitrarily serialized value.
  String? extra;

  /// The [DateTime] at which this access method was added (to the app).
  final DateTime added;

  /// If the access method, itself, has access methods, they are added here.
  /// This makes the definition recursive.
  final AccessMethodTree? methods;

  /// Whether this [AccessMethod], itself has access methods. If not, this is
  /// a leaf (or source) that permits access to a user's [Account].
  bool get hasAccessMethods => methods?.isNotEmpty ?? false;

  AccessMethod({
    required this.label,
    this.userInterfaceKey,
    final Set<AccessMethodRef>? methods,
  })  : added = clock.now().toUtc(),
        methods = AccessMethodTree.promote(methods);

  /// Used to implement subclasses that may include additional data.
  String _toString([final String? typeName, final String? additionalData]) {
    String childStr = "";

    if (hasAccessMethods) {
      childStr = "\n";

      for (var method in methods!) {
        childStr +=
            "\t${method.toString().replaceAll("\n", "\n\t")}${method != methods!.last ? '\n' : ''}";
      }
    }

    String attributesStr =
        "label = $label${additionalData?.isNotEmpty ?? false ? ', $additionalData' : ''}";
    attributesStr =
        "\n\t${attributesStr.replaceAll(RegExp(r",(\s*)"), ",\n\t")}\n";

    return "${typeName ?? 'AccessMethod ($runtimeType)'}${hasAccessMethods ? ' (requires at least one child factor)' : ''} {$attributesStr}\n$childStr";
  }

  @override
  String toString() => _toString();

  /// Creates a new object with the same properties. However, if [keepPriority]
  /// is not explicitly set to true the priority value will be restored to
  /// lowest with the expectation that this is desired when adding this access
  /// method to a new tree.
  /// Nested methods (i.e., sub methods)
  AccessMethod clone({final bool keepPriority = false});

  /// Full constructor for subclasses that may include additional data, to
  /// allow for cloning.
  AccessMethod._forClone({
    required this.label,
    this.userInterfaceKey,
    this.extra,
    required this.added,
    this.methods,
  });

  String get factoryName;

  /// Pack the access method into binary data.
  /// The optional [additionalFields] parameter can be used by subclasses to
  /// pack additional data.
  @mustCallSuper
  Uint8List pack({final AccessMethodAdditionalFieldsPacker? additionalFields}) {
    final messagePacker = Packer();

    // Write the factory type name.
    // (or if it's a direct instantiation of this class, write AccessMethod)
    messagePacker.packString(factoryName);

    // If there are additional fields, pack them.
    if (additionalFields != null) {
      additionalFields(messagePacker);
    }

    // Then, write the base fields.
    messagePacker
      ..packString(label)
      ..packBool(userInterfaceKey != null)
      ..packString(userInterfaceKey?.name)
      ..packString(added.toIso8601String())
      ..packBool(hasAccessMethods);

    // Write the nested methods if there are any.
    if (hasAccessMethods) {
      messagePacker.packBinary(methods!.pack());
    }

    return messagePacker.takeBytes();
  }

  /// Used by subclasses to unpack their data.
  AccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  })  : label = messageUnpacker.unpackString(),
        userInterfaceKey = messageUnpacker.unpackBool()!
            ? AccessMethodInterfaceKey.fromName(messageUnpacker.unpackString()!)
            : null,
        added = DateTime.parse(messageUnpacker.unpackString()!),
        methods = messageUnpacker.unpackBool()!
            ? AccessMethodTree.unpack(
                Uint8List.fromList(messageUnpacker.unpackBinary()),
              )
            : null;

  /// Load and unpack the access method from binary data.
  static AccessMethod unpack(
    final Uint8List data, {
    final AccessMethodTree? owner,
  }) {
    final messageUnpacker = Unpacker(data);
    String factoryName = messageUnpacker.unpackString()!;

    return AccessMethodRegistry.getUnpacker(factoryName)(
      messageUnpacker,
      owner: owner,
    );
  }
}

/// An access method implementation that indicates usage of another existing
/// account as an access method.
/// For example: "Sign in with Google", "Sign in with Apple", etc.
class ExistingAccountAccessMethod extends AccessMethod {
  /// The ID of the account that is being used as an access method.
  final String accountId;

  /// The [Account] that is being used as an access method. May be null if the
  /// account is not available.
  Account? getAccount(final WidgetRef ref) {
    return ref.read(accountsProvider).get(accountId);
  }

  static const String typeName = "ExistingAccountAccessMethod";

  @override
  String get factoryName => typeName;

  @override
  AccessMethodInterfaceKey get userInterfaceKey =>
      AccessMethodInterfaceKey.otherAccount;

  ExistingAccountAccessMethod(
    this.accountId, {
    super.label,
    super.methods,
    super.userInterfaceKey,
  });

  ExistingAccountAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  })  : accountId = messageUnpacker.unpackString()!,
        super.byUnpacking(messageUnpacker, owner: owner);

  ExistingAccountAccessMethod._forClone(
    this.accountId, {
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  ExistingAccountAccessMethod clone({final bool keepPriority = false}) {
    return ExistingAccountAccessMethod._forClone(
      accountId,
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() =>
      _toString('ExistingAccountAccessMethod', 'accountId = $accountId');

  @override
  Uint8List pack({final AccessMethodAdditionalFieldsPacker? additionalFields}) {
    return super.pack(additionalFields: (final Packer messagePacker) {
      messagePacker.packString(accountId);
    });
  }
}

/// An access method implementation that represents 'something you know'.
/// Includes: password, PIN, etc.,
class KnowledgeAccessMethod extends AccessMethod {
  /// A representation of the data exposed by this access method.
  String data;

  static const String typeName = "KnowledgeAccessMethod";

  @override
  String get factoryName => typeName;

  KnowledgeAccessMethod(
    this.data, {
    super.label,
    super.userInterfaceKey,
    super.methods,
  });

  KnowledgeAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  })  : data = messageUnpacker.unpackString()!,
        super.byUnpacking(messageUnpacker, owner: owner);

  KnowledgeAccessMethod._forClone(
    this.data, {
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  KnowledgeAccessMethod clone({final bool keepPriority = false}) {
    return KnowledgeAccessMethod._forClone(
      data,
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() => _toString('KnowledgeAccessMethod', 'data = $data');

  @override
  Uint8List pack({final AccessMethodAdditionalFieldsPacker? additionalFields}) {
    return super.pack(additionalFields: (final Packer messagePacker) {
      messagePacker.packString(data);
    });
  }
}

/// An access method implementation that represents 'something you have'.
/// Includes: hardware authentication device, mobile device, etc.,
class PhysicalAccessMethod extends AccessMethod {
  static const String typeName = "PhysicalAccessMethod";

  @override
  String get factoryName => typeName;

  PhysicalAccessMethod({
    super.label,
    super.userInterfaceKey,
    super.methods,
  });

  PhysicalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  PhysicalAccessMethod._forClone({
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  PhysicalAccessMethod clone({final bool keepPriority = false}) {
    return PhysicalAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() => _toString('PhysicalAccessMethod');
}

/// An access method implementation that represents 'something you are'.
/// Includes: fingerprint, facial scan, retinal scan, behavioral analysis,
/// etc.,
class BiometricAccessMethod extends AccessMethod {
  static const String typeName = "BiometricAccessMethod";

  @override
  String get factoryName => typeName;

  BiometricAccessMethod({
    super.label,
    super.userInterfaceKey,
    super.methods,
  });

  BiometricAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  BiometricAccessMethod._forClone({
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  BiometricAccessMethod clone({final bool keepPriority = false}) {
    return BiometricAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() => _toString('BiometricAccessMethod');
}

/// An access method implementation that represents 'something that controls
/// when you have access'.
class TemporalAccessMethod extends AccessMethod {
  static const String typeName = "TemporalAccessMethod";

  @override
  String get factoryName => typeName;

  TemporalAccessMethod({
    super.label,
    super.userInterfaceKey,
    super.methods,
  });

  TemporalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  TemporalAccessMethod._forClone({
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  TemporalAccessMethod clone({final bool keepPriority = false}) {
    return TemporalAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() => _toString('TemporalAccessMethod');
}

/// Represents a conjunction (AND) of access methods.
class AccessMethodConjunction extends AccessMethod {
  static const String typeName = "AccessMethodConjunction";

  @override
  String get factoryName => typeName;

  @override
  AccessMethodTree get methods => super.methods!;

  AccessMethodConjunction(
    final Set<AccessMethodRef> methods, {
    super.userInterfaceKey,
  }) : super(
          methods: methods,
          label: methods.map((final method) => method.read.label).join(" & "),
        );

  AccessMethodConjunction.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  AccessMethodConjunction._forClone({
    // Superclass parameters.
    final String? label,
    final AccessMethodInterfaceKey? userInterfaceKey,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  AccessMethodConjunction clone({final bool keepPriority = false}) {
    return AccessMethodConjunction._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      extra: extra,
      added: added,
      methods: methods,
    );
  }

  @override
  String toString() =>
      _toString('AccessMethodConjunction (requires ALL factors)');
}

//// EXCEPTIONS

/// Thrown when an access method is added twice to the same tree.
class DuplicateAccessMethodEntryStateError extends StateError {
  DuplicateAccessMethodEntryStateError()
      : super(
          "An AccessMethod may only belong to one AccessMethodTree but an AccessMethod "
          "already belonging to a tree was about to be added to another tree.\nIt must either be "
          "removed from the initial tree first, or cloned before being added to the new one.",
        );
}

/// REGISTRY

typedef AccessMethodFactory<T extends AccessMethod> = T Function(
  Unpacker, {
  AccessMethodTree? owner,
});

class AccessMethodRegistry {
  static AccessMethodRegistry? _instance;
  static AccessMethodRegistry get instance {
    if (_instance == null) initialize();
    return _instance!;
  }

  final Map<String, AccessMethodFactory> _factories = {};
  AccessMethodRegistry._();

  /// Can be used to explicitly initialize the access method
  /// registry ahead of time. This is not necessary, as the registry will
  /// be initialized automatically when it is first accessed.
  static void initialize() {
    // If the factory is already initialized, do nothing.
    if (_instance != null) return;

    // Otherwise, initialize it.
    _instance = AccessMethodRegistry._();

    registerMethod(
      KnowledgeAccessMethod.typeName,
      KnowledgeAccessMethod.byUnpacking,
    );
    registerMethod(
      PhysicalAccessMethod.typeName,
      PhysicalAccessMethod.byUnpacking,
    );
    registerMethod(
      BiometricAccessMethod.typeName,
      BiometricAccessMethod.byUnpacking,
    );
    registerMethod(
      TemporalAccessMethod.typeName,
      TemporalAccessMethod.byUnpacking,
    );
    registerMethod(
      AccessMethodConjunction.typeName,
      AccessMethodConjunction.byUnpacking,
    );
  }

  static void registerMethod(
      final String name, final AccessMethodFactory factory) {
    instance._factories[name] = factory;
  }

  static AccessMethodFactory<T> getUnpacker<T extends AccessMethod>(
    final String name,
  ) {
    return instance._factories[name]! as AccessMethodFactory<T>;
  }
}
