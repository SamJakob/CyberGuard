import 'dart:collection';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:messagepack/messagepack.dart';
import 'package:meta/meta.dart';

/// A sorting function for specifying the relative order of [AccessMethod]s
/// within a tree.
typedef AccessMethodTreeSort = int Function(AccessMethod a, AccessMethod b);

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
class AccessMethodTree extends SplayTreeSet<AccessMethod> with ChangeNotifier {
  /// Simply uses [AccessMethod.compareTo] to compare values.
  static int defaultSort(final AccessMethod a, final AccessMethod b) =>
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

  AccessMethodTree._(final Set<AccessMethod> methods,
      {final AccessMethodTreeSort? sort})
      : currentSortingMethod = sort,
        super(sort) {
    addAll(methods);
  }

  /// Initializes the tree with an initial set of [AccessMethod]s.
  AccessMethodTree(final Set<AccessMethod> methods) : this._(methods);

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
  bool _proxyAdd(final AccessMethod element) {
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
  void addAll(final Iterable<AccessMethod> elements) {
    for (AccessMethod element in elements) {
      add(element);
    }
  }

  @override
  bool add(final AccessMethod element) {
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
  bool _proxyRemove(final AccessMethod element) {
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
    if (object == null || object is! AccessMethod) return false;

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
  void removeWhere(final bool Function(AccessMethod element) test) {
    List<Object?> toRemove = [];

    for (AccessMethod element in this) {
      if (test(element)) toRemove.add(element);
    }

    removeAll(toRemove);
  }

  @override
  String toString() {
    String childStr = "(empty)";
    if (isNotEmpty) {
      childStr = "\t";

      for (AccessMethod method in this) {
        childStr += "$method${method != last ? '\n' : ''}";
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

    Set<AccessMethod> methods = {};
    for (int i = 0; i < length; i++) {
      final methodData = messageUnpacker.unpackBinary();
      methods.add(AccessMethod.unpack(Uint8List.fromList(methodData)));
    }

    // addAll assigns the owner of each entry, so we don't need to do that
    // above.
    tree.addAll(methods);
    return tree;
  }
}

typedef AccessMethodAdditionalFieldsPacker = void Function(Packer packer);
typedef AccessMethodInstantiator<T extends AccessMethod> = T Function(
    Unpacker unpacker);

/// Used to represent a means of accessing an [Account].
@sealed
abstract class AccessMethod implements Comparable<AccessMethod> {
  /// The priority of the access method (relative to others on the same level
  /// in an [AccessMethodTree]).
  ///
  /// 0 is the highest priority, with priority in descending order (e.g.,
  /// 1 is next highest, 2 is after, etc., until the lowest priority item is
  /// reached).
  ///
  /// If a higher priority method needs to be added, simply add one to the
  /// priority of all other access methods to allow a new priority 0 to be
  /// added.
  ///
  /// Negative integers aren't allowed for priority, but a placeholder of -1
  /// is used to signal lowest priority. This will cause the [AccessMethodTree]
  /// the [AccessMethod] is added to, to place this new access method at a
  /// priority of priorityLowest + 1 (where priorityLowest is the priority
  /// score of the current lowest priority access method).
  ///
  /// This priority only makes sense for an [AccessMethodTree] - and only one
  /// tree at that. The same [AccessMethod] may not exist in multiple trees,
  /// and should instead be cloned.
  int get priority => _priority;

  set priority(final int newPriority) {
    _priority = newPriority;
    _owner?._normalize();
  }

  int _priority;

  /// The same [AccessMethod] may not exist in multiple trees, and should
  /// instead be cloned. This is used to ensure that does not happen.
  AccessMethodTree? _owner;

  /// The user-defined label of the access method.
  String label;

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
    final int? priority,
    final Set<AccessMethod>? methods,
  })  : _priority = priority ?? -1,
        added = clock.now().toUtc(),
        methods = methods != null ? AccessMethodTree(methods) : null;

  /// Used to implement subclasses that may include additional data.
  String _toString([final String? typeName, final String? additionalData]) {
    // Add priority if this is part of a tree.
    String priorityStr = _owner != null ? "priority = $priority, " : "";
    String childStr = "";

    if (hasAccessMethods) {
      childStr = "\n";

      for (var method in methods!) {
        childStr +=
            "\t${method.toString().replaceAll("\n", "\n\t")}${method != methods!.last ? '\n' : ''}";
      }
    }

    String attributesStr =
        "${priorityStr}label = $label${additionalData?.isNotEmpty ?? false ? ', $additionalData' : ''}";
    attributesStr =
        "\n\t${attributesStr.replaceAll(RegExp(r",(\s*)"), ",\n\t")}\n";

    return "${typeName ?? 'AccessMethod ($runtimeType)'}${hasAccessMethods ? ' (requires at least one child factor)' : ''} {$attributesStr}\n$childStr";
  }

  @override
  String toString() => _toString();

  @override
  int compareTo(final AccessMethod other) {
    return priority.compareTo(other.priority);
  }

  /// Creates a new object with the same properties. However, if [keepPriority]
  /// is not explicitly set to true the priority value will be restored to
  /// lowest with the expectation that this is desired when adding this access
  /// method to a new tree.
  /// Nested methods (i.e., sub methods)
  AccessMethod clone({final bool keepPriority = false});

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
      ..packInt(_priority)
      ..packString(label)
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
  })  : _priority = messageUnpacker.unpackInt()!,
        label = messageUnpacker.unpackString()!,
        added = DateTime.parse(messageUnpacker.unpackString()!),
        methods = messageUnpacker.unpackBool()!
            ? AccessMethodTree.unpack(
                Uint8List.fromList(messageUnpacker.unpackBinary()),
              )
            : null,
        // Load the owner as specified (avoids cyclic dependency when
        // [un]packing).
        _owner = owner;

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
    super.priority,
    required super.label,
    super.methods,
  });

  KnowledgeAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  })  : data = messageUnpacker.unpackString()!,
        super.byUnpacking(messageUnpacker, owner: owner);

  @override
  KnowledgeAccessMethod clone({final bool keepPriority = false}) {
    return KnowledgeAccessMethod(
      data,
      priority: keepPriority ? _priority : null,
      label: label,
      methods: methods?.clone(keepPriorities: true),
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
    super.priority,
    required super.label,
    super.methods,
  });

  PhysicalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  @override
  PhysicalAccessMethod clone({final bool keepPriority = false}) {
    return PhysicalAccessMethod(
      priority: keepPriority ? _priority : null,
      label: label,
      methods: methods?.clone(keepPriorities: true),
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
    super.priority,
    required super.label,
    super.methods,
  });

  BiometricAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  @override
  BiometricAccessMethod clone({final bool keepPriority = false}) {
    return BiometricAccessMethod(
      priority: keepPriority ? _priority : null,
      label: label,
      methods: methods?.clone(keepPriorities: true),
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
    super.priority,
    required super.label,
    super.methods,
  });

  TemporalAccessMethod.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  @override
  TemporalAccessMethod clone({final bool keepPriority = false}) {
    return TemporalAccessMethod(
      priority: keepPriority ? _priority : null,
      label: label,
      methods: methods?.clone(keepPriorities: true),
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
    final Set<AccessMethod> methods, {
    super.priority,
  }) : super(
          methods: methods,
          label: methods.map((final method) => method.label).join(" & "),
        );

  AccessMethodConjunction.byUnpacking(
    final Unpacker messageUnpacker, {
    final AccessMethodTree? owner,
  }) : super.byUnpacking(messageUnpacker, owner: owner);

  @override
  AccessMethodConjunction clone({final bool keepPriority = false}) {
    return AccessMethodConjunction(
      methods.clone(keepPriorities: true),
      priority: keepPriority ? _priority : null,
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
