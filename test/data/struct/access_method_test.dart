import 'package:clock/clock.dart';
import 'package:cyberguard/data/struct/access_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// DateTime.now() the instant execution has started.
  /// Used to track values that should be created (relative to)
  /// the current date/time.
  final executionInstant = DateTime.now();

  group("test access method", () {
    test("access method sub classes instantiate correctly", () {
      withClock(Clock.fixed(executionInstant), () {
        var method = KnowledgeAccessMethod('mypassword', label: 'Password');
        expect(method.priority, equals(-1));
        expect(method.label, equals('Password'));
        expect(method.added, equals(executionInstant));
        expect(method.data, equals('mypassword'));

        // This is an access method, it has no nested access methods
        // and therefore
        expect(method.hasAccessMethods, equals(false));
        expect(method.methods, equals(null));

        var methodWithSubMethods = PhysicalAccessMethod(
          label: 'Mobile Phone',
          methods: {
            KnowledgeAccessMethod('1234', label: 'Mobile Phone PIN'),
          },
        );
      });
    });
  });

  group("test access method tree structure", () {});
}
