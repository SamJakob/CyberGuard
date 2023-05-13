import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/providers/user_presence.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/components/future_executor_button.dart';
import 'package:cyberguard/interface/components/typography.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:cyberguard/interface/utility/clipboard.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AccountScreen extends ConsumerStatefulWidget {
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

  @override
  Widget build(final BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final account = ref.watch(accountsProvider).get(widget.id);
    final isUserPresent = ref.watch(userPresenceProvider);

    if (account == null) {
      return const Center(
        child: ApolloLoadingSpinner(),
      );
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Renders the account information header and button row.
                _renderHeader(account),
                TextFormField(
                  controller: TextEditingController(text: account.serviceUrl),
                  decoration: InputDecoration(
                    labelText: "Service URL",
                    helperText: settings.enableServiceLookups &&
                            !account.hasServiceUrl
                        ? "TIP: Fill out the service URL to allow $kAppName to "
                            "attempt to automatically fetch useful information "
                            "about ${account.name}!"
                        : null,
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      icon: const HeroIcon(
                        HeroIcons.clipboard,
                        style: HeroIconStyle.outline,
                      ),
                      onPressed: () {
                        context.copyText(account.serviceUrl);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller:
                      TextEditingController(text: account.accountIdentifier),
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: "Username, Email or ID",
                    suffixIcon: IconButton(
                      icon: const HeroIcon(
                        HeroIcons.clipboard,
                        style: HeroIconStyle.outline,
                      ),
                      onPressed: () {
                        context.copyText(account.accountIdentifier);
                      },
                    ),
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
                const SizedBox(height: 40),
                const TitleText("Extra Information"),
                const Text(
                  "Add extra information to help $kAppName analyze your "
                  "account setup and provide you with useful information.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isEditing)
              FutureExecutorButton(
                icon: const HeroIcon(HeroIcons.check),
                label: const Text("Save Changes"),
                color: const Color(0xFFC6F68D),
                onPressed: () async {
                  await Future<void>.delayed(const Duration(seconds: 3));
                  setState(() {
                    _isEditing = false;
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
                    _isEditing = true;
                  });
                },
              ),
            const SizedBox(width: 20),
            FutureExecutorButton(
              icon: const HeroIcon(HeroIcons.trash),
              label: const Text("Delete"),
              color: const Color(0xFFFF7C5D),
              onPressed: () async {
                await ref.read(accountsProvider).deleteById(widget.id);

                if (mounted) {
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    ]);
  }
}
