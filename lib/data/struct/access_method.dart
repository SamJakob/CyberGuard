import 'dart:collection';

import 'package:clock/clock.dart';
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
class AccessMethodTree extends SplayTreeSet<AccessMethod> {
  /// Simply uses [AccessMethod.compareTo] to compare values.
  static int defaultSort(final AccessMethod a, final AccessMethod b) => a.compareTo(b);

  /// The sorting method currently being used for this tree. Setting this
  /// explicitly (or to something other than [defaultSort] may reduce
  /// performance due to additional sorts being required).
  final AccessMethodTreeSort? currentSortingMethod;

  /// Returns true if either [defaultSort] is used, or if a sorting function
  /// has not been supplied at all (meaning the default was used). Otherwise,
  /// returns false.
  bool get isUsingDefaultSortingMethod => currentSortingMethod == null || currentSortingMethod == defaultSort;

  AccessMethodTree._(final Set<AccessMethod> methods, {final AccessMethodTreeSort? sort})
      : currentSortingMethod = sort,
        super(sort) {
    addAll(methods);
  }

  /// Initializes the tree with an initial set of [AccessMethod]s.
  /// Optionally takes a sorting method, otherwise uses the [Comparable]
  /// functionality in [AccessMethod].
  AccessMethodTree(final Set<AccessMethod> methods) : this._(methods);

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
  AccessMethodTree restructure(final AccessMethodTreeSort sort) => clone(keepPriorities: true, sort: sort);

  /// Normalizes the priority values of entries in the tree,
  void _normalize() {
    // Start with priority 0 for the highest priority element.
    int currentPriority = 0;
    // Then, loop over each element and assign priority in order of current
    // priority. This requires some 'gymnastics' as we need to first sort them
    // by priority, then restore the user's preferred sorting method.
    // Although we can slightly optimize this by checking if the default
    // sorting method is being used.
    forEach((final element) => element.priority = currentPriority++);
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
        map((final method) => method.priority)
            .reduce((final value, final element) => element > value ? element : value);
  }

  /// Used to augment the add event. Specifically, to inject the _owner
  /// property, and then return the result of the whole operation.
  bool _proxyAdd(final AccessMethod element) {
    if (element._owner != null) {
      throw StateError("An AccessMethod may only belong to one AccessMethodTree but an AccessMethod "
          "already belonging to a tree was just added to another tree. It must either be "
          "removed from the initial tree first, or cloned before being added to the new one.");
    }

    if (super.add(element)) {
      element._owner = this;
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
    // If the element is already in the tree, do not add it again. This would
    // be an error, as it has invalid or nonsensical semantic meaning (in a
    // disjunction or conjunction).
    if (contains(element)) return false;

    // If the element's priority is negative, give it the highest score to make
    // it the lowest priority.
    if (element._priority < 0) {
      element._priority = _nextHighestPriority();
      return _proxyAdd(element);
    }

    // Otherwise, increment the priority of any other elements in the set that
    // are above this one, to 'insert' this one at the specified priority.
    where((final method) => method._priority >= element._priority).forEach((final element) => element._priority++);

    // Then permit this element to be added.
    return _proxyAdd(element);
  }

  /// Used to augment the remove event. Specifically, to inject the _owner
  /// property, and then return the result of the whole operation.
  bool _proxyRemove(final AccessMethod element) {
    if (super.remove(element)) {
      element._owner = null;
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

    // Normalize the tree.
    _normalize();

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
}

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
        added = clock.now(),
        methods = methods != null ? AccessMethodTree(methods) : null;

  /// Used to implement subclasses that may include additional data.
  String _toString([final String? typeName, final String? additionalData]) {
    // Add priority if this is part of a tree.
    String priorityStr = _owner != null || true ? "priority = $priority, " : "";
    String childStr = "";

    if (hasAccessMethods) {
      childStr = "\n";

      for (var method in methods!) {
        childStr += "\t${method.toString().replaceAll("\n", "\n\t")}${method != methods!.last ? '\n' : ''}";
      }
    }

    String attributesStr =
        "${priorityStr}label = $label${additionalData?.isNotEmpty ?? false ? ', $additionalData' : ''}";
    attributesStr = "\n\t${attributesStr.replaceAll(RegExp(r",(\s*)"), ",\n\t")}\n";

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
}

/// An access method implementation that represents 'something you know'.
/// Includes: password, PIN, etc.,
class KnowledgeAccessMethod<T> extends AccessMethod {
  /// A representation of the data exposed by this access method.
  T data;

  KnowledgeAccessMethod(
    this.data, {
    super.priority,
    required super.label,
    super.methods,
  });

  @override
  KnowledgeAccessMethod<T> clone({final bool keepPriority = false}) {
    return KnowledgeAccessMethod(
      data,
      priority: keepPriority ? _priority : null,
      label: label,
      methods: methods?.clone(keepPriorities: true),
    );
  }

  @override
  String toString() => _toString('KnowledgeAccessMethod', 'data = $data');
}

/// An access method implementation that represents 'something you have'.
/// Includes: hardware authentication device, mobile device, etc.,
class PhysicalAccessMethod extends AccessMethod {
  PhysicalAccessMethod({
    super.priority,
    required super.label,
    super.methods,
  });

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
  BiometricAccessMethod({
    super.priority,
    required super.label,
    super.methods,
  });

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
  TemporalAccessMethod({
    super.priority,
    required super.label,
    super.methods,
  });

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
  @override
  AccessMethodTree get methods => super.methods!;

  AccessMethodConjunction(
    final Set<AccessMethod> methods, {
    super.priority,
  }) : super(
          methods: methods,
          label: methods.map((final method) => method.label).join(" & "),
        );

  @override
  AccessMethodConjunction clone({final bool keepPriority = false}) {
    return AccessMethodConjunction(
      methods.clone(keepPriorities: true),
      priority: keepPriority ? _priority : null,
    );
  }

  @override
  String toString() => _toString('AccessMethodConjunction (requires ALL factors)');
}
