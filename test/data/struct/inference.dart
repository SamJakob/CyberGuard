// ignore_for_file: unused_local_variable

import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // MOCK ACCOUNT DATA

  /// A commonly used service. It shares a password with
  /// [apolloSoftwareHoustonAccount], though.
  final googleAccount = Account(
    name: 'Google',
    accountIdentifier: 'example@gmail.com',
  );

  /// Similar to [googleAccount]. It uses [googleAccount] as its recovery
  /// method, but has its own (more secure) password.
  final microsoftAccount = Account(
    name: 'Microsoft',
    accountIdentifier: 'example@live.com',
  );

  /// A service that provides authentication, but which shares a password with
  /// [googleAccount].
  final apolloSoftwareHoustonAccount = Account(
    name: 'Apollo Software Houston',
    accountIdentifier: 'example@houston.apollosoftware.xyz',
    serviceUrl: 'https://apollosoftware.xyz',
    accountPriority: 5,
  );

  /// A service that uses [apolloSoftwareHoustonAccount] as an authentication
  /// method.
  final apolloSoftwareGeminiAccount = Account(
    name: 'Apollo Software Gemini',
    accountIdentifier: 'example@gemini.apollosoftware.xyz',
    serviceUrl: 'https://gemini.apollosoftware.xyz',
    accountPriority: 3,
  );

  /// 'Unconnected' account (i.e., a throwaway). This should not have any
  /// links.
  final redditAccount = Account(
    name: 'Reddit',
    accountIdentifier: 'example@10minutemail.com',
  );

  /// Two more accounts that share security questions, and one is very high
  /// priority. They should be linked.
  final amazonAccount = Account(
    name: 'Amazon',
    accountIdentifier: 'example@example.com',
    // (e.g., because of credit card details).
    accountPriority: 10,
  );

  final facebookAccount = Account(
    name: 'Facebook',
    accountIdentifier: 'example@example.com',
  );

  AccountsProvider accountsProvider = AccountsProvider(initialAccounts: {
    'test_google': googleAccount,
    'test_microsoft': microsoftAccount,
    'test_apollo_houston': apolloSoftwareHoustonAccount,
    'test_apollo_gemini': apolloSoftwareGeminiAccount,
    'test_reddit': redditAccount,
    'test_amazon': amazonAccount,
    'test_facebook': facebookAccount,
  });

  // Load the IDs for each account from the accounts provider. (They're
  // hardcoded using initialAccounts, but this should tell us if they've loaded
  // correctly into the provider.)
  final googleId =
      accountsProvider.getIdFor(googleAccount)!; // should be test_google
  final microsoftId =
      accountsProvider.getIdFor(microsoftAccount)!; // should be test_microsoft
  final houstonId = accountsProvider
      .getIdFor(apolloSoftwareHoustonAccount)!; // should be test_apollo_houston
  final geminiId = accountsProvider
      .getIdFor(apolloSoftwareGeminiAccount)!; // should be test_apollo_gemini
  final redditId =
      accountsProvider.getIdFor(redditAccount)!; // should be test_reddit
  final amazonId =
      accountsProvider.getIdFor(amazonAccount)!; // should be test_amazon
  final facebookId =
      accountsProvider.getIdFor(facebookAccount)!; // should be test_facebook

  // MOCK ACCESS METHOD DATA

  // Use human-readable IDs if you want human-readable debugging output!
  const loginToGooglePasswordId = 'login_to_google_password';
  const loginToMicrosoftPasswordId = 'login_to_microsoft_password';
  const loginToHoustonPasswordId = 'login_to_houston_password';
  const loginToRedditPasswordId = 'login_to_reddit_password';
  const loginToRedditSMSTFAId = 'login_to_reddit_sms_tfa';

  const loginWithHoustonId = 'login_with_houston';

  const recoveryWithGoogleId = 'recovery_with_google';

  const loginToAmazonPasswordId = 'login_to_amazon_password';
  const loginToAmazonSecurityQuestionId = 'login_to_amazon_security_question';
  const loginToFacebookPasswordId = 'login_to_facebook_password';
  const loginToFacebookSecurityQuestionId =
      'login_to_facebook_security_question';

  final AccessMethodStore accessMethodStore = AccessMethodStore.initialize(
    accessMethods: {
      loginWithHoustonId: ExistingAccountAccessMethod(
        houstonId,
        label: 'Login with Houston',
      ),
      // Password reuse. (Oh no! How could they?!?!)
      loginToGooglePasswordId: KnowledgeAccessMethod(
        'password123',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      loginToHoustonPasswordId: KnowledgeAccessMethod(
        'password123',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      // Good password!
      loginToMicrosoftPasswordId: KnowledgeAccessMethod(
        // https://xkcd.com/936/
        // (although, ironically, this is probably a bad password now thanks to
        // its popularity)
        'correct horse battery staple',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      // Throwaway password (should be unique).
      loginToRedditPasswordId: KnowledgeAccessMethod(
        'completely_unique_password_for_reddit',
        label: 'Reddit Password',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      loginToRedditSMSTFAId: PhysicalAccessMethod(
        label: "SMS Two-Factor Authentication",
        userInterfaceKey: AccessMethodInterfaceKey.sms,
      ),
      // Two other accounts (linked by security questions)
      loginToAmazonPasswordId: KnowledgeAccessMethod(
        'unique_password_for_amazon',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      loginToAmazonSecurityQuestionId: KnowledgeAccessMethod(
        'security_answer_for_facebook_amazon',
        label: "What is your mother's maiden name?",
        userInterfaceKey: AccessMethodInterfaceKey.securityQuestion,
      ),
      loginToFacebookPasswordId: KnowledgeAccessMethod(
        'unique_password_for_facebook',
        userInterfaceKey: AccessMethodInterfaceKey.password,
      ),
      loginToFacebookSecurityQuestionId: KnowledgeAccessMethod(
        'security_answer_for_facebook_amazon',
        label: "What is your mother's maiden name?",
        userInterfaceKey: AccessMethodInterfaceKey.securityQuestion,
      ),

      // RECOVERY METHODS

      recoveryWithGoogleId: RecoveryEmailAccessMethod(
        googleId,
        label: 'Recovery with Google',
      ),
    },
  );

  final loginWithHouston =
      accessMethodStore.newReferenceFromId(loginWithHoustonId)!;

  // Assign mock access methods to the accounts.
  apolloSoftwareGeminiAccount.accessMethods.add(loginWithHouston);
  apolloSoftwareHoustonAccount.accessMethods.add(
    accessMethodStore.newReferenceFromId(loginToHoustonPasswordId)!,
  );

  googleAccount.accessMethods.add(
    accessMethodStore.newReferenceFromId(loginToGooglePasswordId)!,
  );

  redditAccount.accessMethods.addAll([
    accessMethodStore.newReferenceFromId(loginToRedditPasswordId)!,
    accessMethodStore.newReferenceFromId(loginToRedditSMSTFAId)!,
  ]);

  microsoftAccount.accessMethods.addAll([
    accessMethodStore.newReferenceFromId(loginToMicrosoftPasswordId)!,
    accessMethodStore.newReferenceFromId(recoveryWithGoogleId)!,
  ]);

  amazonAccount.accessMethods.addAll([
    accessMethodStore.newReferenceFromId(loginToAmazonPasswordId)!,
    accessMethodStore.newReferenceFromId(loginToAmazonSecurityQuestionId)!,
  ]);

  facebookAccount.accessMethods.addAll([
    accessMethodStore.newReferenceFromId(loginToFacebookPasswordId)!,
    accessMethodStore.newReferenceFromId(loginToFacebookSecurityQuestionId)!,
  ]);

  // BEGIN TESTS

  test('does not error when an empty graph is inferred', () {
    final InferenceService inferenceService = InferenceService(
      accountsProvider: AccountsProvider(),
      accountRefs: [],
    );

    final graph = inferenceService.run();
    inferenceService.interpret(graph);
  });

  // Initialize the inference service.
  InferenceService inferenceService = InferenceService(
    accountsProvider: accountsProvider,
    accountRefs: accountsProvider.allAccounts,
  );

  // Run the inference service to compute a graph of the user's account
  // data.
  InferenceGraph graph = inferenceService.run();

  group('graph inference', () {
    // This test is no longer accurate since the graph inference algorithm
    // has been changed to preprocess the graph before running the inference
    // algorithm, so additional vertices may be created.
    test(
        "should have at most one vertex per account + each account's access methods + one for conjunctions",
        () {
      // Expect that the graph contains a vertex for each account (and not
      // more).
      // (Essentially this is just to test that redundant vertices aren't
      // being created.)
      expect(
        graph.vertices.length,
        lessThanOrEqualTo(
          accountsProvider.allAccounts.length +
              // Add one for each account access method.
              accountsProvider.allAccounts
                  .map((final ref) => ref.account.accessMethods.length)
                  .reduce((final value, final element) => value + element) +
              // Add one for each method that generates a conjunction.
              AccessMethodStore()
                  .listAccessMethods
                  .where((final element) => [
                        AccessMethodInterfaceKey.totp,
                        AccessMethodInterfaceKey.sms,
                      ].contains(element.userInterfaceKey))
                  .length,
        ),
      );
    });

    test('should contain, at least, the Apollo Gemini account', () {
      // Expect that the graph contains the Apollo Gemini account.
      expect(
          graph
              .vertexWhere((final vertex) =>
                  vertex.isAccount &&
                  vertex.account == apolloSoftwareGeminiAccount)!
              .account,
          equals(apolloSoftwareGeminiAccount));
    });

    test('should identify explicitly linked accounts', () {
      // Expect that the vertex for the Apollo Gemini account has an edge to
      // the vertex for the Houston account.
      // That is, Gemini depends on Houston.
      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount &&
                vertex.account == apolloSoftwareGeminiAccount)!
            .dependencies
            .contains(
              graph.vertexWhere((final vertex) =>
                  vertex.isAccount &&
                  vertex.account == apolloSoftwareHoustonAccount),
            ),
        equals(true),
      );

      // Expect that the Microsoft account has an edge to the Google account.
      // That is, Microsoft depends on Google.
      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount && vertex.account == microsoftAccount)!
            .dependencies
            .contains(
              graph.vertexWhere((final vertex) =>
                  vertex.isAccount && vertex.account == googleAccount),
            ),
        equals(true),
      );
    });

    test('should have a comment for explicitly linked accounts', () {
      // Expect that the comment for the edge between the Apollo Gemini account
      // and the Houston account is "This account is directly linked as an
      // access method.".
      expect(
          graph
              .vertexWhere((final vertex) =>
                  vertex.isAccount &&
                  vertex.account == apolloSoftwareGeminiAccount)!
              .commentedDependencies
              .first
              .comment,
          equals(
              "Apollo Software Houston is directly linked to Apollo Software Gemini as an access method"));

      expect(
          graph
              .vertexWhere((final vertex) =>
                  vertex.isAccount && vertex.account == microsoftAccount)!
              .commentedDependencies
              .first
              .comment,
          equals("Google is a recovery email address for Microsoft"));
    });

    test('should identify implicit links with shared values', () {
      // Expect that the vertex for the Apollo Houston account has an edge to
      // the vertex for the Google account (because of the password re-use),
      // and vice versa.
      // That is, the security of Houston depends on the security of Google,
      // and vice versa.
      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount &&
                vertex.account == apolloSoftwareHoustonAccount)!
            .dependencies
            .contains(
              graph.vertexWhere((final vertex) =>
                  vertex.isAccount && vertex.account == googleAccount),
            ),
        equals(true),
      );

      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount && vertex.account == googleAccount)!
            .dependencies
            .contains(
              graph.vertexWhere((final vertex) =>
                  vertex.isAccount &&
                  vertex.account == apolloSoftwareHoustonAccount),
            ),
        equals(true),
      );
    });

    test('should provide appropriate comments for implicit links', () {
      // Expect that the comment for the edge between the Apollo Houston
      // account and the Google account is "
      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount &&
                vertex.account == apolloSoftwareHoustonAccount)!
            .commentedDependencies
            .where((final edge) =>
                edge.from.account == googleAccount &&
                edge.to.account == apolloSoftwareHoustonAccount)
            .first
            .comment,
        equals("Apollo Software Houston shares a password with Google"),
      );

      expect(
        graph
            .vertexWhere((final vertex) =>
                vertex.isAccount && vertex.account == googleAccount)!
            .commentedDependencies
            .where((final edge) =>
                edge.from.account == apolloSoftwareHoustonAccount &&
                edge.to.account == googleAccount)
            .first
            .comment,
        equals("Google shares a password with Apollo Software Houston"),
      );
    });
  });

  group('graph interpretation', () {
    final inferredAdvice = inferenceService.interpret(graph);

    test('should detect only two things with this setup', () {
      expect(inferredAdvice.length, equals(2));
    });

    test('detects the backdoor to Houston via Google', () {
      expect(
          inferredAdvice
              .where((final element) =>
                  element.type == InferredAdviceType.potentialBackdoor &&
                  element.from.account == googleAccount &&
                  element.to.account == apolloSoftwareHoustonAccount)
              .firstOrNull
              ?.advice,
          equals(
            "The account Google (less important) could allow an attacker to access Apollo Software Houston (more important) because Google shares a password with Apollo Software Houston.",
          ));
    });

    test('detects the backdoor to Amazon via Facebook', () {
      expect(
          inferredAdvice
              .where((final element) =>
                  element.type == InferredAdviceType.potentialBackdoor &&
                  element.from.account == facebookAccount &&
                  element.to.account == amazonAccount)
              .firstOrNull
              ?.advice,
          equals(
            "The account Facebook (less important) could allow an attacker to access Amazon (more important) because Facebook shares an answer to a security question (\"What is your mother's maiden name?\") with Amazon.",
          ));
    });
  });
}
