import 'package:uuid/uuid.dart';

import 'access_method.dart';

/// A reference to an [AccessMethod] that can be used to retrieve the
/// [AccessMethod] from a [UserAccount]. This is used to allow
/// [AccessMethod]s to be stored in a centralized location (i.e., the
/// [AccessMethodRegistry]) and then referenced by multiple [UserAccount]s.
///
/// An [AccessMethodRef] will typically just hold an [id] that can be used to
/// retrieve the [AccessMethod] from the [AccessMethodRegistry].
class AccessMethodRef {
  final String id;
  final AccessMethod? _method;

  AccessMethodRef._(this.id, final AccessMethod method) : _method = method;

  bool get isInitialized => _method != null;
}

class AccessMethodRegistry {
  static AccessMethodRegistry? _instance;

  factory AccessMethodRegistry() {
    return _instance!;
  }

  final Map<String, AccessMethod> _accessMethods;

  AccessMethodRegistry._initialize({
    final Map<String, AccessMethod>? accessMethods,
  }) : _accessMethods = accessMethods ?? {};

  /// Registers an [AccessMethod] with the registry, and returns a reference to
  /// it.
  AccessMethodRef register(final AccessMethod method) {
    final id = _uniqueId();
    _accessMethods[id] = method;
    return AccessMethodRef._(id, method);
  }

  AccessMethodRef? lookup(final String id) {
    if (_accessMethods.containsKey(id)) {
      return AccessMethodRef._(id, _accessMethods[id]!);
    } else {
      return null;
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
}
