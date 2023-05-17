part of 'access_method.dart';

typedef AccessMethodRefEditorChange<T> = dynamic Function(T method);

class AccessMethodRefEditor<T extends AccessMethod> {
  final AccessMethodRef _owner;
  T method;

  AccessMethodRefEditor._(this._owner) : method = _owner.read as T;

  /// Performs [changes] to the [AccessMethod] in this editor.
  AccessMethodRefEditor<T> update(
    final AccessMethodRefEditorChange<T> changes,
  ) {
    changes(method);
    return this;
  }

  /// Commits the changes made to the [AccessMethod] in this editor.
  /// This will propagate the changes back to the original [AccessMethodRef]
  /// that this editor was created from.
  void commit() {
    AccessMethodStore().update(_owner, method);
  }

  /// Deletes the [AccessMethod] from the [AccessMethodTree] that it is in.
  /// This will propagate the changes back to the original [AccessMethodRef]
  /// that this editor was created from.
  ///
  /// **A [commit] call is not necessary for this change to be propagated, it
  /// will be propagated immediately.**
  void deleteMethod() {
    _owner._owner?.remove(_owner);
    AccessMethodStore().delete(_owner);
  }
}

/// A reference to an [AccessMethod] that can be used to retrieve the
/// [AccessMethod] from a [UserAccount]. This is used to allow
/// [AccessMethod]s to be stored in a centralized location (i.e., the
/// [AccessMethodRegistry]) and then referenced by multiple [UserAccount]s.
///
/// An [AccessMethodRef] will typically just hold an [id] that can be used to
/// retrieve the [AccessMethod] from the [AccessMethodRegistry].
class AccessMethodRef<T extends AccessMethod>
    implements Comparable<AccessMethodRef> {
  final String id;

  /// Returns a clone of the [AccessMethod] that this [AccessMethodRef] is a
  /// reference to. This is useful for reading the [AccessMethod] without
  /// modifying the original. If you want to modify the [AccessMethod], use
  /// [edit] instead, which will propagate changes back to the original and
  /// issue a notification to state management that the [AccessMethod] has
  /// changed.
  ///
  /// **CHANGES MADE TO THE RETURNED [AccessMethod] WILL NOT BE REFLECTED IN
  /// THE ORIGINAL [AccessMethod]! AS NOTED, YOU MUST USE [edit] TO ALTER THE
  /// UNDERLYING [AccessMethod]**.
  T get read =>
      AccessMethodStore()._accessMethods[id]!.clone(keepPriority: true) as T;

  U readAs<U extends AccessMethod>() => read as U;

  bool isA<U extends AccessMethod>() => isAn<U>();
  bool isAn<U extends AccessMethod>() => T is U || read is U;

  bool isNotA<U extends AccessMethod>() => isNotAn<U>();
  bool isNotAn<U extends AccessMethod>() => !isA<U>();

  int _priority;

  /// The same [AccessMethod] may not exist in multiple trees, and should
  /// instead be cloned. This is used to ensure that does not happen.
  AccessMethodTree? _owner;

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

  AccessMethodRefEditor<T> get editor => AccessMethodRefEditor<T>._(this);

  AccessMethodRef._(
    this.id, {
    final int? priority,
  }) : _priority = priority ?? -1;

  Uint8List pack() {
    final messagePacker = Packer();
    messagePacker
      ..packString(id)
      ..packInt(priority);
    return messagePacker.takeBytes();
  }

  factory AccessMethodRef.unpack(final Uint8List data) {
    final Unpacker messageUnpacker = Unpacker(data);
    return AccessMethodRef._(
      messageUnpacker.unpackString()!,
      priority: messageUnpacker.unpackInt(),
    );
  }

  @override
  int compareTo(final AccessMethodRef other) {
    return priority.compareTo(other.priority);
  }

  bool isEquivalentTo(final AccessMethodRef other) {
    return id == other.id;
  }

  @override
  String toString() {
    // Add priority if this is part of a tree.
    String priorityStr = _owner != null ? ", priority = $priority" : "";

    return 'AccessMethodRef(id: $id$priorityStr)';
  }

  AccessMethodRef<T> clone({final bool keepPriority = false}) {
    return AccessMethodRef._(
      id,
      priority: keepPriority ? priority : null,
    );
  }

  @override
  int get hashCode => Object.hash(id, _priority);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is AccessMethodRef &&
          id == other.id &&
          _priority == other._priority);
}

class EphemeralAccessMethodRef<T extends AccessMethod>
    extends AccessMethodRef<T> {
  final AccessMethod method;

  @override
  T get read => method as T;

  EphemeralAccessMethodRef(this.method, {final int? priority})
      : super._(
          "EPHEMERAL_${DateTime.now().microsecondsSinceEpoch}_${const Uuid().v4()}",
          priority: priority,
        );

  @override
  AccessMethodRef<T> clone({final bool keepPriority = false}) {
    return EphemeralAccessMethodRef(
      method,
      priority: keepPriority ? priority : null,
    );
  }

  /// Deliberately unimplemented. Ephemeral methods mustn't be stored.
  @override
  Uint8List pack() {
    throw UnimplementedError();
  }

  /// See [pack].
  @override
  factory EphemeralAccessMethodRef.unpack(final Uint8List data) {
    throw UnimplementedError();
  }

  /// See [pack].
  @override
  AccessMethodRefEditor<T> get editor => throw UnimplementedError();

  @override
  String toString() {
    return 'EphemeralAccessMethodRef';
  }
}

/// A centralized store for [AccessMethod]s. Returns an [AccessMethodRef] that
/// can be included in [Account]s to reference a single underlying
/// [AccessMethod]. (e.g., where one access method is shared by multiple
/// accounts).
class AccessMethodStore with ChangeNotifier {
  static AccessMethodStore? _instance;

  static bool get isInitialized => _instance != null;

  factory AccessMethodStore() {
    return _instance!;
  }

  final Map<String, AccessMethod> _accessMethods;

  Map<String, AccessMethod> get allAccessMethods =>
      Map.unmodifiable(_accessMethods);

  List<AccessMethod> get listAccessMethods => _accessMethods.values.toList();

  AccessMethodStore._initialize({
    final Map<String, AccessMethod>? accessMethods,
  }) : _accessMethods = accessMethods ?? {};

  static AccessMethodStore initialize({
    final Map<String, AccessMethod>? accessMethods,
  }) {
    return _instance = AccessMethodStore._initialize(
      accessMethods: accessMethods,
    );
  }

  /// Registers an [AccessMethod] with the registry, and returns a reference to
  /// it.
  AccessMethodRef<T> register<T extends AccessMethod>(final T method) {
    final id = _uniqueId();
    _accessMethods[id] = method;
    return AccessMethodRef._(id);
  }

  /// Checks if [id] exists in the registry and returns a reference to it if
  /// it does.
  AccessMethodRef<T>? newReferenceFromId<T extends AccessMethod>(
    final String id,
  ) {
    // If the key exists, simply promote [id] to an [AccessMethodRef].
    if (_accessMethods.containsKey(id)) {
      return AccessMethodRef._(id);
    }

    // Otherwise, return null.
    return null;
  }

  /// Checks if the [AccessMethodStore] has already created a reference to the
  /// [AccessMethod] and returns it if it has. (This would thus imply that the
  /// method is NOT ephemeral, because ephemeral methods are not stored in the
  /// registry).
  bool hasReferenceTo(final AccessMethod method) {
    return _accessMethods.containsValue(method);
  }

  /// Alias to [register] for readability.
  AccessMethodRef<T> createReferenceTo<T extends AccessMethod>(final T method) {
    return register(method);
  }

  /// Like [newReferenceTo] but doesn't create a new reference if one already
  /// exists.
  AccessMethodRef<T> getReferenceTo<T extends AccessMethod>(final T method) {
    if (_accessMethods.containsValue(method)) {
      return AccessMethodRef._(_accessMethods.keys.firstWhere(
        (final String key) => _accessMethods[key] == method,
      ));
    }

    throw StateError(
      "Attempted to obtain a reference to an unregistered access method.",
    );
  }

  T? lookup<T extends AccessMethod>(final AccessMethodRef<T> ref) {
    if (_accessMethods.containsKey(ref.id)) {
      return _accessMethods[ref.id] as T;
    } else {
      return null;
    }
  }

  void delete(final AccessMethodRef ref) {
    if (_accessMethods.containsKey(ref.id)) {
      _accessMethods.remove(ref.id);
      notifyListeners();
    }
  }

  void update(final AccessMethodRef ref, final AccessMethod? method) {
    if (method == null) {
      delete(ref);
      return;
    }

    if (_accessMethods.containsKey(ref.id)) {
      _accessMethods[ref.id] = method;
      notifyListeners();
      return;
    }
  }

  /// Generate a unique ID for the access method.
  String _uniqueId() {
    String id = const Uuid().v4();
    if (_accessMethods.containsKey(id)) {
      id = _uniqueId();
    }
    return id;
  }

  /// Destroys the [AccessMethodStore], this is intended for testing purposes
  /// only.
  void destroy() {
    _instance = null;
  }

  Map<String, AccessMethod> snapshot() {
    return Map<String, AccessMethod>.unmodifiable(_accessMethods);
  }
}

final accessMethodProvider =
    ChangeNotifierProvider<AccessMethodStore>((final ref) => throw TypeError());
