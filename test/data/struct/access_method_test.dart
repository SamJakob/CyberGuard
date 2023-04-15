import 'package:clock/clock.dart';
import 'package:cyberguard/data/struct/access_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// DateTime.now() the instant execution has started.
  /// Used to track values that should be created (relative to)
  /// the current date/time.
  final executionInstant = DateTime.now();
  final previousExecutionInstant =
      DateTime.now().subtract(const Duration(seconds: 3));

  group("test access method", () {
    test("access method sub classes instantiate correctly", () {
      withClock(Clock.fixed(executionInstant), () {
        var method = KnowledgeAccessMethod('mypassword', label: 'Password');
        expect(method.priority, equals(-1));
        expect(method.label, equals('Password'));
        expect(method.added, equals(executionInstant));
        expect(method.data, equals('mypassword'));

        var method2 = KnowledgeAccessMethod('mypassword', label: 'Password 2');
        expect(method2.priority, equals(-1));
        expect(method2.label, equals('Password 2'));
        expect(method2.added, equals(executionInstant));
        expect(method2.data, equals('mypassword'));

        expect(method != method2, equals(true));

        // This is an access method, it has no nested access methods
        // and therefore
        expect(method.hasAccessMethods, equals(false));
        expect(method.methods, equals(null));

        late KnowledgeAccessMethod<String> subMethod;
        withClock(Clock.fixed(previousExecutionInstant), () {
          subMethod = KnowledgeAccessMethod('1234', label: 'Cell Phone PIN');
        });

        var methodWithSubMethods = PhysicalAccessMethod(
          label: 'Cell Phone',
          methods: {
            subMethod,
          },
        );

        // Check the parent.
        expect(methodWithSubMethods.label, equals('Cell Phone'));
        expect(methodWithSubMethods.methods!.first, equals(subMethod));

        // Check the child.
        // Check that both have correct added date.
        expect(method.added, equals(executionInstant));
        expect(methodWithSubMethods.methods!.first.added,
            equals(previousExecutionInstant));
      });
    });
  });

  group("test access method tree structure", () {
    test('access method nesting works correctly', () {
      // Define a hypothetical 'Google Account' structure.

      AccessMethodConjunction conjunction;
      KnowledgeAccessMethod<String> password;
      TemporalAccessMethod smsCode;
      PhysicalAccessMethod cellPhone;
      KnowledgeAccessMethod<String> cellPhonePin;

      var googleAccountRequirements = AccessMethodTree({
        conjunction = AccessMethodConjunction({
          password = KnowledgeAccessMethod('mypassword', label: 'Password'),
          smsCode = TemporalAccessMethod(
              label: 'SMS Two-Factor Authentication Code',
              methods: {
                cellPhone = PhysicalAccessMethod(label: 'Cell Phone', methods: {
                  cellPhonePin =
                      KnowledgeAccessMethod("1234", label: 'Cell Phone PIN'),
                }),
              }),
        }),
      });

      // Now assert that the structure was created correctly.
      expect(googleAccountRequirements.first, equals(conjunction));
      expect(conjunction.methods.first, equals(password));
      expect(conjunction.methods.last, equals(smsCode));

      expect(smsCode.methods!.first, equals(cellPhone));
      expect(cellPhone.methods!.first, equals(cellPhonePin));

      // Now define a new access method, add it to the existing
      // structure, and ensure everything is still valid.
      KnowledgeAccessMethod<String> securityKeyPin;
      PhysicalAccessMethod securityKey = PhysicalAccessMethod(
        label: 'Security Key',
        methods: {
          securityKeyPin = KnowledgeAccessMethod(
            '123456',
            label: 'Security Key PIN',
          ),
        },
      );

      expect(securityKey.methods!.first, equals(securityKeyPin));

      conjunction.methods.add(securityKey);
      expect(conjunction.methods.last, equals(securityKey));

      // Ensure the existing structure remains in place.
      expect(googleAccountRequirements.first, equals(conjunction));
      expect(conjunction.methods.first, equals(password));
      expect(conjunction.methods.elementAt(1), equals(smsCode));

      expect(smsCode.methods!.first, equals(cellPhone));
      expect(cellPhone.methods!.first, equals(cellPhonePin));
    });

    test('priority (when adding, deleting and re-adding) works correctly', () {
      AccessMethodConjunction conjunction;
      KnowledgeAccessMethod<String> password;
      TemporalAccessMethod smsCode;

      // Partial snippet of the above example.
      AccessMethodTree({
        conjunction = AccessMethodConjunction({
          password = KnowledgeAccessMethod('mypassword', label: 'Password'),
          smsCode = TemporalAccessMethod(
            label: 'SMS Two-Factor Authentication Code',
          ),
        }),
      });

      expect(conjunction.methods.first, equals(password));
      expect(conjunction.methods.last, equals(smsCode));

      conjunction.methods.remove(password);

      expect(conjunction.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(0));

      // Recall that priority is ascending (0 is highest priority, 1 is
      // lower priority, and that -1 is substituted for lowest priority).
      final passwordWithHighestPriority = password.clone()..priority = 0;

      // -1 defaults to maximum value.
      final passwordWithLowestPriority = password.clone()..priority = -1;

      // Test that adding and removing works with highest priority.
      conjunction.methods.add(passwordWithHighestPriority);

      expect(conjunction.methods.first, equals(passwordWithHighestPriority));
      expect(conjunction.methods.last, equals(smsCode));

      expect(conjunction.methods.first, equals(passwordWithHighestPriority));
      expect(passwordWithHighestPriority.priority, equals(0));
      expect(conjunction.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(1));

      conjunction.methods.remove(passwordWithHighestPriority);

      expect(conjunction.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(0));

      // Test that adding and removing works with lowest priority.
      conjunction.methods.add(passwordWithLowestPriority);

      expect(conjunction.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.methods.last, equals(passwordWithLowestPriority));
      expect(passwordWithLowestPriority.priority, equals(1));
    });
  });

  group("test exceptions", () {
    test('re-adding element already in tree should throw error', () {
      AccessMethodConjunction conjunction;
      KnowledgeAccessMethod<String> password;
      TemporalAccessMethod smsCode;

      // Partial snippet of the above example.
      AccessMethodTree({
        conjunction = AccessMethodConjunction({
          password = KnowledgeAccessMethod('mypassword', label: 'Password'),
          smsCode = TemporalAccessMethod(
            label: 'SMS Two-Factor Authentication Code',
          ),
        }),
      });

      // Re-adding password.
      expect(
        () => conjunction.methods.add(password),
        throwsA(isA<StateError>()),
      );

      // Re-adding smsCode.
      expect(
        () => conjunction.methods.add(smsCode),
        throwsA(isA<StateError>()),
      );

      // Re-adding smsCode with different priority.
      expect(
        () => conjunction.methods.add(smsCode..priority = 3),
        throwsA(isA<StateError>()),
      );

      // But, re-adding with a clone should work,
      // because the clone is a different object.
      expect(
        () => conjunction.methods.add(smsCode.clone()),
        returnsNormally,
      );
    });
  });
}
