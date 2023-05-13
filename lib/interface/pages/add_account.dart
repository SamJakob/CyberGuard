import 'dart:math';

import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/components/disabled_wrapper.dart';
import 'package:cyberguard/interface/forms/add_account.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  final BuildContext? parentContext;

  const AddAccountPage({
    final Key? key,
    this.parentContext,
  }) : super(key: key);

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AddAccountFormState> _addAccountFormState = GlobalKey();
  AddAccountFormState get addAccountForm => _addAccountFormState.currentState!;

  bool get hasScrollSpace => _scrollController.hasClients
      ? (_scrollController.position.extentBefore <
          _scrollController.position.maxScrollExtent)
      : true;

  /// Whether the form is currently loading.
  bool __isLoading = false;
  bool get _isLoading => __isLoading;
  set _isLoading(final bool value) {
    setState(() {
      __isLoading = value;
    });
  }

  void scrollUp() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  bool scrollDown() {
    // If the scrollController has no clients, it means that the widget has not
    // been built yet. In this case, do nothing to wait for the widget to be
    // built.
    if (!_scrollController.hasClients) return true;

    // Otherwise, if there is no scroll space, return false to indicate that
    // no scrolling was done because the form was already at the bottom.
    // Thus, we can allow the user to submit the form.
    if (!hasScrollSpace) return false;

    // Otherwise, scroll down by 30 pixels or to the bottom of the form,
    // whichever is closer.
    _scrollController.animateTo(
      max(
        _scrollController.position.extentBefore + 30,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );

    // ...and return true to indicate that the form was scrolled.
    return true;
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(final BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) return false;
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                "Add Account",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: _scrollController,
                shrinkWrap: true,
                children: [
                  DisabledWrapper(
                    disabled: _isLoading,
                    child: AddAccountForm(
                      key: _addAccountFormState,
                      // Disable validation whilst processing the form to
                      // prevent errors incorrectly being shown (such as the
                      // account being added and thus a conflict error being
                      // shown).
                      disableValidation: _isLoading,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DisabledWrapper(
                    disabled: _isLoading,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ButtonStyle(
                        foregroundColor: MaterialStatePropertyAll(
                            Theme.of(context).colorScheme.onSurface),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading) ...[
                    Text(
                      "Creating account...",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const ApolloLoadingSpinner(size: 24),
                  ] else ...[
                    DisabledWrapper(
                      disabled: _isLoading,
                      child: TextButton(
                        onPressed: () async {
                          // If the user wants to visit the account page for further
                          // options, we can assume they do not have the fields they
                          // need on the current page, so we won't bother scrolling
                          // to the bottom of the form.

                          if (addAccountForm.validate()) {
                            _isLoading = true;
                            final formData = addAccountForm.getData();

                            String id = await ref
                                .read(accountsProvider)
                                .add(Account(
                                  accountIdentifier: formData.accountIdentifier,
                                  name: formData.name,
                                ));

                            context.pop();
                            context.push("/accounts/$id");
                          } else {
                            // Otherwise, scroll to the start of the form.
                            scrollUp();
                          }
                        },
                        child: const Text(
                          "More Options",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DisabledWrapper(
                      disabled: _isLoading,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () async {
                          if (scrollDown()) return;

                          // Validate the form, add the account, and navigate to the
                          // newly created account's page.
                          if (addAccountForm.validate()) {
                            _isLoading = true;
                            final formData = addAccountForm.getData();

                            String id;
                            if (addAccountForm.hasPassword) {
                              id = await ref.read(accountsProvider).add(
                                    Account.withPassword(
                                      formData.accountIdentifier,
                                      formData.password,
                                      name: formData.name,
                                    ),
                                  );
                            } else {
                              id = await ref.read(accountsProvider).add(
                                    Account(
                                      accountIdentifier:
                                          formData.accountIdentifier,
                                      name: formData.name,
                                    ),
                                  );
                            }

                            context.pop();
                            context.push("/accounts/$id");
                          } else {
                            // Otherwise, scroll to the start of the form.
                            scrollUp();
                          }
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 85),
                          child: hasScrollSpace
                              ? const HeroIcon(HeroIcons.arrowDown)
                              : const Text(
                                  "Add Account",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                        // child: ,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
