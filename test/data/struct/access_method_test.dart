import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cyberguard/data/struct/access_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// DateTime.now() the instant execution has started.
  /// Used to track values that should be created (relative to)
  /// the current date/time.
  final executionInstant = DateTime.now();
  final previousExecutionInstant = DateTime.now().subtract(const Duration(seconds: 3));

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
        expect(methodWithSubMethods.methods!.first.added, equals(previousExecutionInstant));
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
          smsCode = TemporalAccessMethod(label: 'SMS Two-Factor Authentication Code', methods: {
            cellPhone = PhysicalAccessMethod(label: 'Cell Phone', methods: {
              cellPhonePin = KnowledgeAccessMethod("1234", label: 'Cell Phone PIN'),
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
  });
}
