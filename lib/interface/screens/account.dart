import 'package:cyberguard/domain/providers/inference.dart';
import 'package:cyberguard/interface/utility/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/providers/user_presence.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/components/future_executor_button.dart';
import 'package:cyberguard/interface/components/typography.dart';
import 'package:cyberguard/interface/partials/access_method.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:cyberguard/interface/partials/extra_information_tile.dart';
import 'package:cyberguard/interface/utility/clipboard.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:cyberguard/interface/utility/validate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef AccountScreenSaveModifications = void Function(Account account);

class AccountScreen extends StatefulHookConsumerWidget {
  /// The [id] of the account to display.
  final String id;

  const AccountScreen({
    final Key? key,
    required this.id,
  }) : super(key: key);

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AccessMethodRendererController _accessMethodRendererController =
      AccessMethodRendererController();

  late TextEditingController _accountIdentifierController;
  late TextEditingController _serviceUrlController;

  bool _disableValidation = false;
  set disableValidation(final bool disableValidation) {
    setState(() {
      _disableValidation = disableValidation;
    });
  }

  bool get disableValidation => _disableValidation;

  void preventFocusIfNotEditing() {
    if (!_isEditing) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((final _) {
      FocusScope.of(context).addListener(preventFocusIfNotEditing);
    });
  }

  @override
  void dispose() {
    _serviceUrlController.dispose();
    _accountIdentifierController.dispose();
    super.dispose();
  }

  String? _normalizeUrl(final String url) {
    if (Uri.tryParse(url)?.host.isNotEmpty ?? false) {
      return url;
    }

    // If there's no protocol, try specifying one.
    if (!url.contains("://")) {
      // If someone's not using https that's pretty much just natural
      // selection.
      if (Uri.tryParse("https://$url")?.host.isNotEmpty ?? false) {
        return "https://$url";
      }
    }

    // If we're here, we didn't get anywhere, so just return null.
    return null;
  }

  /// Returns the favicon URL for the given [uri].
  Future<String?> _getFavicon(final Uri uri) async {
    // TODO: support redirects?

    try {
      // Make a request to the service URL.
      final response = await http.get(uri);

      // Attempt to find a shortcut icon by scraping the HTML for a link tag.
      final shortcutIconString = html_parser
          .parse(response.body)
          .querySelector(
              'link[rel="shortcut icon"],link[rel="icon"],link[rel="apple-touch-icon"]')
          ?.attributes["href"];
      if (shortcutIconString != null) {
        try {
          final response = await http.get(Uri.parse(shortcutIconString));
          if (response.statusCode == 200) return shortcutIconString;
        } catch (_) {}
      }
    } catch (_) {
      // If we can't make a request to the service URL, just return null.
      return null;
    }

    // Otherwise, naively attempt to resolve a favicon by checking /favicon.ico
    // relative to the service URL.
    final testFaviconUrl = uri.resolve("/favicon.ico");
    try {
      final response = await http.get(testFaviconUrl);
      if (response.statusCode == 200) return testFaviconUrl.toString();
    } catch (_) {}

    return null;
  }

  /// Returns the service change-password URL and icon for the given [account].
  /// [oldServiceUrl] is to be used if the service URL has changed. This
  /// function does nothing if the service URL is missing or invalid, or
  /// hasn't changed.
  Future<(String?, String?)> _doServiceLookup({
    required final Account account,
    required final String? oldServiceUrl,
  }) async {
    // If the service URL hasn't changed, return the old values.
    if (account.serviceUrl == oldServiceUrl) {
      return (account.serviceChangePasswordUrl, account.iconUrl);
    }

    // If the URL is missing or invalid, return null.
    if (!account.hasServiceUrl) return (null, null);
    final String? url = _normalizeUrl(account.serviceUrl!);
    if (url == null) return (null, null);

    // Otherwise parse the URL into a Uri and obtain the host from it.
    final uri = Uri.parse(url);

    final [changePasswordUri, favicon] = await Future.wait([
      // Resolve .well-known/change-password URL (just test for existence and
      // if it exists, use .well-known/change-password).
      Future<String?>(() async {
        try {
          Uri changePasswordUri = uri.resolve("/.well-known/change-password");

          final redirectResponse = await http.head(changePasswordUri);

          // If the response is success, or a redirect, consider the request
          // successful.
          return ([200, 301, 302].contains(redirectResponse.statusCode))
              ? changePasswordUri.toString()
              : null;
        } catch (_) {
          return null;
        }
      }),

      // Attempt to resolve a favicon.
      _getFavicon(uri),
    ]);

    return (changePasswordUri, favicon);
  }

  Future<void> save({
    final AccountScreenSaveModifications? withChanges,
  }) async {
    disableValidation = true;
    final accountProvider = ref.read(accountsProvider.notifier);
    final account = accountProvider.get(widget.id)!;

    final String? oldServiceUrl = account.serviceUrl;

    account.serviceUrl = _serviceUrlController.text;
    account.accountIdentifier = _accountIdentifierController.text;

    if (ref.read(settingsProvider).enableServiceLookups) {
      final (changePasswordUri, favicon) = await _doServiceLookup(
        account: account,
        oldServiceUrl: oldServiceUrl,
      );

      account.serviceChangePasswordUrl = changePasswordUri;
      account.iconUrl = favicon;
    }

    if (withChanges != null) {
      withChanges(account);
    }
    await accountProvider.save();
    await _accessMethodRendererController.triggerSave();

    // Perform a scan.
    ref.read(inferenceProvider.notifier).triggerScan(ref);

    disableValidation = false;
  }

  @override
  Widget build(final BuildContext context) {
    // Subscribe to events from the settings provider.
    final settings = ref.watch(settingsProvider);
    // Subscribe to events from the user presence provider to refresh the page
    // when the user presence status changes.
    final isUserPresent = ref.watch(userPresenceProvider);
    // Subscribe to events from the accounts provider. This will be used to
    // retrieve the account to display and to observe the account for changes.
    final account = ref.watch(accountsProvider).get(widget.id);

    // Subscribe to events from the account, to refresh the page when the
    // account changes.
    useListenable(account);

    ref.listen(userPresenceProvider, (final previous, final next) {
      // If the user presence status has changed to false, cancel editing.
      if (!next) {
        setState(() {
          _isEditing = false;
        });
      }
    });

    // Subscribe to events from the access method provider.
    ref.watch(accessMethodProvider);

    if (account == null) {
      return const Center(
        child: ApolloLoadingSpinner(),
      );
    }

    useEffect(() {
      _serviceUrlController = TextEditingController(
        text: account.serviceUrl,
      );
      _accountIdentifierController = TextEditingController(
        text: account.accountIdentifier,
      );

      return null;
    }, [account, _isEditing]);

    useValueChanged<bool, void>(_isEditing, (final _, final __) {
      if (!_isEditing) {
        // If the user stops editing, un-focus the text fields.
        FocusScope.of(context).unfocus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(
          "${account.name} (${context.shortenValue(account.accountIdentifier)})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          if (isUserPresent)
            IconButton(
              tooltip: "Tap to hide sensitive information",
              onPressed: () {
                ref.read(userPresenceProvider.notifier).clearPresenceStatus();
              },
              icon: const HeroIcon(HeroIcons.lockOpen),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Scrollbar(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceUnitPx,
              vertical: kSpaceUnitPx * 0.75,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: disableValidation
                  ? AutovalidateMode.disabled
                  : AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Renders the account information header and button row.
                  _renderHeader(account),
                  TextFormField(
                    readOnly: !_isEditing,
                    controller: _serviceUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: "Service URL",
                      helperText: settings.enableServiceLookups &&
                              !account.hasServiceUrl
                          ? "TIP: Fill out the service URL to allow $kAppName to "
                              "attempt to automatically fetch useful information "
                              "about ${account.name}!"
                          : null,
                      helperMaxLines: 3,
                      errorMaxLines: 4,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const HeroIcon(
                              HeroIcons.link,
                              style: HeroIconStyle.outline,
                            ),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const HeroIcon(
                              HeroIcons.clipboard,
                              style: HeroIconStyle.outline,
                            ),
                            onPressed: () {
                              context.copyText(account.serviceUrl);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    readOnly: !_isEditing,
                    controller: _accountIdentifierController,
                    validator: (final String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter your identifier (such as a username, email, or ID) for this account. If you don't have one, or aren't sure, enter something that makes sense to you (such as your name).";
                      }
                      String? error;
                      if ((error = ref.checkForNameAndAccountIdentifierCombo(
                            accountName: account.name,
                            accountIdentifier:
                                _accountIdentifierController.text,
                            exclude: account,
                          )) !=
                          null) {
                        return error;
                      }
                      return null;
                    },
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: account.isEmailAccount
                          ? "Email Address"
                          : "Username, Email or ID",
                      suffixIcon: IconButton(
                        icon: const HeroIcon(
                          HeroIcons.clipboard,
                          style: HeroIconStyle.outline,
                        ),
                        onPressed: () {
                          context.copyText(account.accountIdentifier);
                        },
                      ),
                      helperMaxLines: 2,
                      errorMaxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const TitleText("Access Methods"),
                  Text(
                    _isEditing
                        ? "These are the ways you've stored for accessing your "
                            "${account.name} account."
                        : "These are the ways you've stored for accessing your "
                            "${account.name} account. You can add more at any "
                            "time by tapping 'Edit' above.",
                  ),
                  const SizedBox(height: 10),
                  if (_isEditing) AddAccessMethodButton(account: account),
                  ..._renderAccessMethods(account),
                  const SizedBox(height: 40),
                  const TitleText("Extra Information"),
                  const Text(
                    "Add extra information to help $kAppName analyze your "
                    "account setup and provide you with useful information.",
                  ),
                  const SizedBox(height: 20),
                  ExtraInformationTile(
                    isEditing: _isEditing,
                    title: "Is Email Account",
                    description: "Enable this option if this account is your "
                        "e-mail address.",
                    value: account.isEmailAccount,
                    colorIfTrue: Colors.white,
                    colorIfFalse: Colors.white,
                    onChanged: (final bool value) async {
                      await save(
                        withChanges: (final account) =>
                            account.isEmailAccount = value,
                      );
                    },
                  ),
                  ExtraInformationTile(
                    isEditing: _isEditing,
                    title: "Device provides access",
                    description: "Enable this option if one of your devices "
                        "provides access to this account (e.g., because you're "
                        "signed into an app) AND the app does not have its own "
                        "protection method.",
                    value: account.deviceProvidesAccess,
                    colorIfTrue: Colors.orange,
                    colorIfFalse: Colors.green,
                    onChanged: (final bool value) async {
                      await save(
                        withChanges: (final account) =>
                            account.deviceProvidesAccess = value,
                      );
                    },
                  ),
                  ExtraInformationTile(
                    isEditing: _isEditing,
                    title: "Account is shared",
                    description: "Enable this option if you share this account "
                        "with other people (e.g., a family account).",
                    value: account.accountIsShared,
                    colorIfTrue: Colors.orange,
                    colorIfFalse: Colors.green,
                    onChanged: (final bool value) async {
                      await save(
                        withChanges: (final account) =>
                            account.accountIsShared = value,
                      );
                    },
                  ),
                  ExtraInformationTile(
                    isEditing: _isEditing,
                    title: "Account priority",
                    description: "How important do you consider this account, "
                        "from 1 (least) to 5 (most)?",
                    value: account.accountPriority,
                    min: 1,
                    max: 5,
                    labelIfFalse: "Least",
                    labelIfTrue: "Most",
                    colorIfTrue: Colors.red,
                    colorIfFalse: Colors.green,
                    onChanged: (final int value) async {
                      await save(
                        withChanges: (final account) =>
                            account.accountPriority = value,
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _renderAccessMethods(final Account account) {
    if (account.accessMethods.isEmpty) {
      return [
        const SizedBox(height: 20),
        const Center(
          child: Text(
            "You haven't added any access methods yet!",
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    return account.accessMethods
        .map((final accessMethod) {
          return <Widget>[
            AccessMethodRenderer(
              account: account,
              method: accessMethod,
              isEditing: _isEditing,
              controller: _accessMethodRendererController,
            ),
            const SizedBox(height: 20),
            // const Divider(),
          ];
        })
        .expand((final element) => element)
        .toList();
  }

  /// Renders the account information header and button row.
  Widget _renderHeader(final Account account) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AccountTileIcon(account: account),
            const SizedBox(width: kSpaceUnitPx),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  if (account.hasServiceUrl)
                    Text(
                      account.serviceUrl!,
                      style: TextStyle(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.8),
                        fontSize: 12,
                      ),
                    )
                ],
              ),
            )
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 5,
          children: [
            if (_isEditing || _isSaving)
              FutureExecutorButton(
                icon: const HeroIcon(HeroIcons.check),
                label: const Text("Save Changes"),
                color: const Color(0xFFC6F68D),
                onPressed: () async {
                  setState(() {
                    _isEditing = false;
                    _isSaving = true;
                  });
                  await save();
                  setState(() {
                    _isSaving = false;
                  });
                },
              )
            else
              FutureExecutorButton(
                icon: const HeroIcon(HeroIcons.pencilSquare),
                label: const Text("Edit"),
                color: const Color(0xFFC6F68D),
                onPressed: () async {
                  await ref.read(userPresenceProvider.notifier).checkPresence();
                  setState(() {
                    // Enable editing if the user is present.
                    _isEditing = true && ref.read(userPresenceProvider);
                  });
                },
              ),
            FutureExecutorButton(
              icon: const HeroIcon(HeroIcons.trash),
              label: const Text("Delete"),
              color: const Color(0xFFFF7C5D),
              onPressed: () async {
                bool wasUserPresent = ref.read(userPresenceProvider);

                await ref.read(userPresenceProvider.notifier).checkPresence();

                if (ref.read(userPresenceProvider)) {
                  await ref.read(accountsProvider).deleteById(widget.id);

                  if (mounted) {
                    context.pop();
                  }
                }

                if (!wasUserPresent) {
                  ref.read(userPresenceProvider.notifier).clearPresenceStatus();
                }
              },
            ),
            if (account.hasServiceChangePasswordUrl)
              FutureExecutorButton(
                icon: const HeroIcon(HeroIcons.link),
                label: const Text("Change Password"),
                color: const Color(0xFFE6DEF6),
                onPressed: () async {
                  await context.launch(
                    account.serviceChangePasswordUrl!,
                    inExternalBrowser: true,
                  );
                },
              ),
          ],
        ),
      ),
    ]);
  }
}
