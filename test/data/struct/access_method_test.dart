// ignore_for_file: unused_local_variable

import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// DateTime.now() the instant execution has started.
  /// Used to track values that should be created (relative to)
  /// the current date/time.
  final executionInstant = DateTime.now().toUtc();
  final previousExecutionInstant =
      DateTime.now().toUtc().subtract(const Duration(seconds: 3));

  setUp(() {
    AccessMethodStore.initialize();
  });

  group("test access method", () {
    tearDown(() {
      AccessMethodStore().destroy();
    });

    test("access method sub classes instantiate correctly", () {
      withClock(Clock.fixed(executionInstant), () {
        var methodRef = AccessMethodStore().register(
          KnowledgeAccessMethod('mypassword', label: 'Password'),
        );

        expect(methodRef.priority, equals(-1));
        expect(methodRef.read.label, equals('Password'));
        expect(methodRef.read.added, equals(executionInstant));
        expect(methodRef.read.data, equals('mypassword'));

        var methodRef2 = AccessMethodStore()
            .register(KnowledgeAccessMethod('mypassword', label: 'Password 2'));
        expect(methodRef2.priority, equals(-1));
        expect(methodRef2.read.label, equals('Password 2'));
        expect(methodRef2.read.added, equals(executionInstant));
        expect(methodRef2.read.data, equals('mypassword'));

        expect(methodRef != methodRef2, equals(true));

        // This is an access method, it has no nested access methods
        // and therefore [hasAccessMethods] should be false and [methods]
        // should be null.
        expect(methodRef.read.hasAccessMethods, equals(false));
        expect(methodRef.read.methods, equals(null));

        late AccessMethodRef<KnowledgeAccessMethod> subMethod;
        withClock(Clock.fixed(previousExecutionInstant), () {
          subMethod = AccessMethodStore().register(
            KnowledgeAccessMethod('1234', label: 'Cell Phone PIN'),
          );
        });

        var methodWithSubMethods = AccessMethodStore().register(
          PhysicalAccessMethod(
            label: 'Cell Phone',
            methods: {
              subMethod,
            },
          ),
        );

        // Check the parent.
        expect(methodWithSubMethods.read.label, equals('Cell Phone'));
        expect(methodWithSubMethods.read.methods!.first, equals(subMethod));

        // Check the child.
        // Check that both have correct added date.
        expect(methodRef.read.added, equals(executionInstant));
        expect(methodWithSubMethods.read.methods!.first.read.added,
            equals(previousExecutionInstant));
      });
    });
  });

  group("test access method tree structure", () {
    test('access method nesting works correctly', () {
      // Define a hypothetical 'Google Account' structure.

      AccessMethodRef<AccessMethodConjunction> conjunction;
      AccessMethodRef<KnowledgeAccessMethod> password;
      AccessMethodRef<TemporalAccessMethod> smsCode;
      AccessMethodRef<PhysicalAccessMethod> cellPhone;
      AccessMethodRef<KnowledgeAccessMethod> cellPhonePin;

      var googleAccountRequirements = AccessMethodTree({
        conjunction = AccessMethodStore().register(AccessMethodConjunction({
          password = AccessMethodStore().register(
            KnowledgeAccessMethod('mypassword', label: 'Password'),
          ),
          smsCode = AccessMethodStore().register(
            TemporalAccessMethod(
                label: 'SMS Two-Factor Authentication Code',
                methods: {
                  cellPhone = AccessMethodStore().register(
                    PhysicalAccessMethod(label: 'Cell Phone', methods: {
                      cellPhonePin = AccessMethodStore().register(
                        KnowledgeAccessMethod("1234", label: 'Cell Phone PIN'),
                      ),
                    }),
                  ),
                }),
          ),
        })),
      });

      // Now assert that the structure was created correctly.
      expect(googleAccountRequirements.first, equals(conjunction));
      expect(conjunction.read.methods.first, equals(password));
      expect(conjunction.read.methods.last, equals(smsCode));

      expect(smsCode.read.methods!.first, equals(cellPhone));
      expect(cellPhone.read.methods!.first, equals(cellPhonePin));

      // Now define a new access method, add it to the existing
      // structure, and ensure everything is still valid.
      AccessMethodRef<KnowledgeAccessMethod> securityKeyPin;
      AccessMethodRef<PhysicalAccessMethod> securityKey =
          AccessMethodStore().register(
        PhysicalAccessMethod(
          label: 'Security Key',
          methods: {
            securityKeyPin = AccessMethodStore().register(
              KnowledgeAccessMethod(
                '123456',
                label: 'Security Key PIN',
              ),
            ),
          },
        ),
      );

      expect(securityKey.read.methods!.first, equals(securityKeyPin));

      conjunction.editor
          .update((final method) => method.methods.add(securityKey))
          .commit();
      expect(conjunction.read.methods.last, equals(securityKey));

      // Ensure the existing structure remains in place.
      expect(googleAccountRequirements.first, equals(conjunction));
      expect(conjunction.read.methods.first, equals(password));
      expect(conjunction.read.methods.elementAt(1), equals(smsCode));

      expect(smsCode.read.methods!.first, equals(cellPhone));
      expect(cellPhone.read.methods!.first, equals(cellPhonePin));
    });

    test('priority (when adding, deleting and re-adding) works correctly', () {
      AccessMethodRef<AccessMethodConjunction> conjunction;
      AccessMethodRef<KnowledgeAccessMethod> password;
      AccessMethodRef<TemporalAccessMethod> smsCode;

      // Partial snippet of the above example.
      AccessMethodTree({
        conjunction = AccessMethodStore().register(
          AccessMethodConjunction({
            password = AccessMethodStore().register(
              KnowledgeAccessMethod('mypassword', label: 'Password'),
            ),
            smsCode = AccessMethodStore().register(
              TemporalAccessMethod(
                label: 'SMS Two-Factor Authentication Code',
              ),
            ),
          }),
        ),
      });

      expect(conjunction.read.methods.first, equals(password));
      expect(conjunction.read.methods.last, equals(smsCode));

      conjunction.editor
          .update((final method) => method.methods.remove(password))
          .commit();

      expect(conjunction.read.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.read.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(0));

      // Recall that priority is ascending (0 is highest priority, 1 is
      // lower priority, and that -1 is substituted for lowest priority).
      final passwordWithHighestPriority = password.clone()..priority = 0;

      // -1 defaults to maximum value.
      final passwordWithLowestPriority = password.clone()..priority = -1;

      // Test that adding and removing works with highest priority.
      conjunction.editor
          .update(
              (final method) => method.methods.add(passwordWithHighestPriority))
          .commit();

      expect(
          conjunction.read.methods.first, equals(passwordWithHighestPriority));
      expect(conjunction.read.methods.last, equals(smsCode));

      expect(
          conjunction.read.methods.first, equals(passwordWithHighestPriority));
      expect(passwordWithHighestPriority.priority, equals(0));
      expect(conjunction.read.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(1));

      conjunction.editor
          .update((final method) =>
              method.methods.remove(passwordWithHighestPriority))
          .commit();

      expect(conjunction.read.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.read.methods.last, equals(smsCode));
      expect(smsCode.priority, equals(0));

      // Test that adding and removing works with lowest priority.
      conjunction.editor
          .update(
              (final method) => method.methods.add(passwordWithLowestPriority))
          .commit();

      expect(conjunction.read.methods.first, equals(smsCode));
      expect(smsCode.priority, equals(0));
      expect(conjunction.read.methods.last, equals(passwordWithLowestPriority));
      expect(passwordWithLowestPriority.priority, equals(1));
    });

    test('recursiveWhere works on nested structure', () {
      AccessMethodRef<AccessMethodConjunction> conjunction;
      AccessMethodRef<KnowledgeAccessMethod> password;
      AccessMethodRef<TemporalAccessMethod> smsCode;

      // Partial snippet of the above example.
      final AccessMethodTree tree = AccessMethodTree({
        conjunction = AccessMethodStore().register(
          AccessMethodConjunction({
            password = AccessMethodStore().register(
              KnowledgeAccessMethod('mypassword', label: 'Password'),
            ),
            smsCode = AccessMethodStore().register(
              TemporalAccessMethod(
                label: 'SMS Two-Factor Authentication Code',
              ),
            ),
          }),
        ),
      });

      // Test that recursiveWhere works on nested structure by checking if it
      // contains a TemporalAccessMethod.
      expect(
        tree
            .recursiveWhere(
              (final methodRef) => methodRef.read is TemporalAccessMethod,
            )
            .isNotEmpty,
        equals(true),
      );

      // ...and that it doesn't contain a PhysicalAccessMethod.
      expect(
        tree
            .recursiveWhere(
              (final methodRef) => methodRef.read is PhysicalAccessMethod,
            )
            .isEmpty,
        equals(true),
      );

      // ...and finally, to check that the AccessMethodRef itself is totally
      // valid, check the priority and label of the first
      // KnowledgeAccessMethod.
      expect(
        tree
            .recursiveWhere(
                (final methodRef) => methodRef.read is KnowledgeAccessMethod)
            .first
            .priority,
        equals(password.priority),
      );
      expect(
        tree
            .recursiveWhere(
                (final methodRef) => methodRef.read is KnowledgeAccessMethod)
            .first
            .read
            .label,
        equals(password.read.label),
      );
    });
  });

  group("test exceptions", () {
    test('re-adding element already in tree should throw error', () {
      AccessMethodRef<AccessMethodConjunction> conjunction;
      AccessMethodRef<KnowledgeAccessMethod> password;
      AccessMethodRef<TemporalAccessMethod> smsCode;

      // Partial snippet of the above example.
      AccessMethodTree({
        conjunction = AccessMethodStore().register(
          AccessMethodConjunction({
            password = AccessMethodStore().register(
              KnowledgeAccessMethod('mypassword', label: 'Password'),
            ),
            smsCode = AccessMethodStore().register(
              TemporalAccessMethod(
                label: 'SMS Two-Factor Authentication Code',
              ),
            ),
          }),
        ),
      });

      // Re-adding password.
      expect(
        () => conjunction.editor
            .update((final method) => method.methods.add(password))
            .commit(),
        throwsA(isA<StateError>()),
      );

      // Re-adding smsCode.
      expect(
        () => conjunction.editor
            .update((final method) => method.methods.add(smsCode))
            .commit(),
        throwsA(isA<StateError>()),
      );

      // Re-adding smsCode with different priority.
      expect(
        () => conjunction.editor
            .update((final method) => method.methods.add(smsCode..priority = 3))
            .commit(),
        throwsA(isA<StateError>()),
      );

      // But, re-adding with a clone should work,
      // because the clone is a different object.
      expect(
        () => conjunction.editor
            .update((final method) => method.methods.add(smsCode.clone()))
            .commit(),
        returnsNormally,
      );
    });
  });

  group('test serialization and deserialization', () {
    late AccessMethodTree googleAccountRequirements;

    setUp(() {
      googleAccountRequirements = AccessMethodTree({
        AccessMethodStore().register(
          AccessMethodConjunction({
            AccessMethodStore().register(
              KnowledgeAccessMethod('mypassword', label: 'Password'),
            ),
            AccessMethodStore().register(
              TemporalAccessMethod(
                  label: 'SMS Two-Factor Authentication Code',
                  methods: {
                    AccessMethodStore().register(
                      PhysicalAccessMethod(label: 'Cell Phone', methods: {
                        AccessMethodStore().register(
                          KnowledgeAccessMethod("1234",
                              label: 'Cell Phone PIN'),
                        )
                      }),
                    ),
                  }),
            ),
          }),
        ),
      });
    });

    test('test serializes without error', () {
      // Define a hypothetical 'Google Account' structure.
      googleAccountRequirements.pack();
    });

    test('test deserializes without error', () {
      Uint8List data = googleAccountRequirements.pack();
      expect(AccessMethodTree.unpack(data)!, isA<AccessMethodTree>());
    });

    test('representation matches before and after re-serialization', () {
      Uint8List data = googleAccountRequirements.pack();
      AccessMethodTree deserialized = AccessMethodTree.unpack(data)!;

      // toString provides an adequate summary of the structure, so
      // simply comparing these ensures that all of the pertinent
      // information is being serialized and deserialized correctly.
      expect(
        googleAccountRequirements.toString(),
        equals(deserialized.toString()),
      );
    });
  });
}
