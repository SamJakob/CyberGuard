import 'dart:collection';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:messagepack/messagepack.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

part 'access_method_store.dart';

/// A sorting function for specifying the relative order of [AccessMethod]s
/// within a tree.
typedef AccessMethodTreeSort = int Function(
    AccessMethodRef a, AccessMethodRef b);

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
class AccessMethodTree extends SplayTreeSet<AccessMethodRef>
    with ChangeNotifier {
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
        super(sort) {
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

    if (super.add(element)) {
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

  @override
  void addAll(final Iterable<AccessMethodRef> elements) {
    for (final element in elements) {
      add(element);
    }
  }

  @override
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
    if (super.remove(element)) {
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

  @override
  bool remove(final Object? object) {
    // If the object is not a valid possible entry in the set, just return
    // false.
    if (object == null || object is! AccessMethodRef) return false;

    // If the element is not in the tree, simply return false.
    if (!contains(object)) return false;

    return _proxyRemove(object);
  }

  @override
  void removeAll(final Iterable<Object?> elements) {
    for (Object? element in elements) {
      remove(element);
    }
  }

  @override
  void removeWhere(final bool Function(AccessMethodRef element) test) {
    List<Object?> toRemove = [];

    for (AccessMethodRef element in this) {
      if (test(element)) toRemove.add(element);
    }

    removeAll(toRemove);
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
}

enum UserInterfaceKey {
  /// The user interface key for a password access method.
  password,

  /// The user interface key for a TOTP access method.
  totp,

  /// The user interface key for a biometric access method.
  biometric,

  /// The user interface key for a security question and answer pair
  /// access method.
  securityQuestion;

  static UserInterfaceKey fromName(final String name) {
    return UserInterfaceKey.values
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
  UserInterfaceKey? userInterfaceKey;

  /// The user-defined label of the access method.
  String label;

  /// A prompt, such as a security question, or other associated data (in clear
  /// text) that is used to identify the data associated with this access
  /// method (such as the answer to the security question).
  String? prompt;

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
    this.prompt,
    final Set<AccessMethodRef>? methods,
  })  : added = clock.now().toUtc(),
        methods = methods != null
            ? (methods is AccessMethodTree
                ? methods
                : AccessMethodTree(methods))
            : null;

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
    this.prompt,
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
      ..packString(userInterfaceKey?.name)
      ..packString(prompt)
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
  })  : label = messageUnpacker.unpackString()!,
        userInterfaceKey = messageUnpacker.unpackString() != null
            ? UserInterfaceKey.fromName(messageUnpacker.unpackString()!)
            : null,
        prompt = messageUnpacker.unpackString(),
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
    required super.label,
    super.userInterfaceKey,
    super.prompt,
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
    required final String label,
    final UserInterfaceKey? userInterfaceKey,
    final String? prompt,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          prompt: prompt,
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
      prompt: prompt,
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
    required super.label,
    super.userInterfaceKey,
    super.prompt,
    super.methods,
  });

  PhysicalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  PhysicalAccessMethod._forClone({
    // Superclass parameters.
    required final String label,
    final UserInterfaceKey? userInterfaceKey,
    final String? prompt,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          prompt: prompt,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  PhysicalAccessMethod clone({final bool keepPriority = false}) {
    return PhysicalAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      prompt: prompt,
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
    required super.label,
    super.userInterfaceKey,
    super.prompt,
    super.methods,
  });

  BiometricAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  BiometricAccessMethod._forClone({
    // Superclass parameters.
    required final String label,
    final UserInterfaceKey? userInterfaceKey,
    final String? prompt,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          prompt: prompt,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  BiometricAccessMethod clone({final bool keepPriority = false}) {
    return BiometricAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      prompt: prompt,
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
    required super.label,
    super.userInterfaceKey,
    super.prompt,
    super.methods,
  });

  TemporalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  TemporalAccessMethod._forClone({
    // Superclass parameters.
    required final String label,
    final UserInterfaceKey? userInterfaceKey,
    final String? prompt,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          prompt: prompt,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  TemporalAccessMethod clone({final bool keepPriority = false}) {
    return TemporalAccessMethod._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      prompt: prompt,
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
    super.prompt,
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
    required final String label,
    final UserInterfaceKey? userInterfaceKey,
    final String? prompt,
    final String? extra,
    required final DateTime added,
    final AccessMethodTree? methods,
  }) : super._forClone(
          label: label,
          userInterfaceKey: userInterfaceKey,
          prompt: prompt,
          extra: extra,
          added: added,
          methods: methods,
        );

  @override
  AccessMethodConjunction clone({final bool keepPriority = false}) {
    return AccessMethodConjunction._forClone(
      label: label,
      userInterfaceKey: userInterfaceKey,
      prompt: prompt,
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
