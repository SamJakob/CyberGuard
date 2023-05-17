import 'dart:async';

import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/providers/user_presence.dart';
import 'package:cyberguard/interface/pages/add_access_method.dart';
import 'package:cyberguard/interface/pages/totp_scan.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:cyberguard/interface/partials/totp_tile.dart';
import 'package:cyberguard/interface/transitions/apollo_page_route.dart';
import 'package:cyberguard/interface/utility/clipboard.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AddAccessMethodButton extends StatelessWidget {
  final Account account;

  const AddAccessMethodButton({
    final Key? key,
    required this.account,
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        RenderBox button = context.findRenderObject()! as RenderBox;
        final RenderBox overlay = Navigator.of(context)
            .overlay!
            .context
            .findRenderObject()! as RenderBox;

        final Offset offset = Offset(0.0, button.size.height - 4);

        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(offset, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero) + offset,
                ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );

        final item = await showMenu(
          context: context,
          position: position,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          items: [
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.password,
              child: Text(
                "Password, Passphrase or PIN",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.biometric,
              child: Text(
                "Biometric",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.securityQuestion,
              child: Text(
                "Security Question",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.totp,
              child: Text(
                "TOTP Code (Time-Based 2FA Code)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuItem(
              enabled: !account.accessMethods.hasMethodWhere(
                  (final methodRef) =>
                      methodRef.read.userInterfaceKey ==
                      AccessMethodInterfaceKey.sms),
              value: AccessMethodInterfaceKey.sms,
              child: const Text(
                "SMS Code (Text Message 2FA Code)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.recoveryEmail,
              child: Text(
                "Recovery Email Address",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: AccessMethodInterfaceKey.otherAccount,
              child: Text(
                "Another Account",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

        if (item != null) {
          // If the item type is SMS code, instantly add the method.
          if (item == AccessMethodInterfaceKey.sms) {
            account.accessMethods.add(
              AccessMethodStore().register(
                PhysicalAccessMethod(
                  label: "SMS Two-Factor Authentication",
                  userInterfaceKey: AccessMethodInterfaceKey.sms,
                ),
              ),
            );

            if (context.mounted) {
              context.showInfoSnackbar(message: "Access method added.");
            }
            return;
          }

          // If the item type is TOTP, first open the scanner.
          TotpUrl? existingData;
          if (item == AccessMethodInterfaceKey.totp) {
            if (context.mounted) {
              existingData = await Navigator.of(context).push(
                ApolloPageRoute<TotpUrl>(
                  isFullscreenDialog: true,
                  builder: (final BuildContext context) {
                    return const TotpScanner();
                  },
                ),
              );
            }

            if (existingData == null) {
              if (context.mounted) {
                context.showErrorSnackbar(message: "No TOTP code was scanned.");
              }
              return;
            }

            // Otherwise, ensure the TOTP code has not already been added to
            // this account.
            if (account.accessMethods.hasMethodWhere(
              (final AccessMethodRef methodRef) =>
                  methodRef.read.userInterfaceKey ==
                      AccessMethodInterfaceKey.totp &&
                  (TotpUrl.deserialize(
                        methodRef.readAs<KnowledgeAccessMethod>().data,
                      ) ==
                      existingData!),
            )) {
              if (context.mounted) {
                context.showErrorSnackbar(
                    message: "This TOTP code has already been added.");
              }
              return;
            }
          }

          if (context.mounted) {
            await showModalBottomSheet<void>(
              context: context,
              builder: (final BuildContext context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AddAccessMethodPage(
                      interfaceKey: item,
                      account: account,
                      existingData: existingData?.serialize(),
                    ),
                  ],
                );
              },
              useSafeArea: true,
              isScrollControlled: true,
            );
          }
        }
      },
      icon: const HeroIcon(HeroIcons.plus),
      label: const Text("Add Access Method"),
    );
  }
}

enum AccessMethodRendererEvent { save }

typedef AccessMethodRendererCallback = Future<void> Function(
  AccessMethodRendererEvent event,
);

class AccessMethodRendererController {
  final Set<AccessMethodRendererCallback> _listeners =
      <AccessMethodRendererCallback>{};

  void addListener(final AccessMethodRendererCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(final AccessMethodRendererCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of an event.
  Future<void> notifyListeners(final AccessMethodRendererEvent event) async {
    await Future.wait<void>(
      _listeners.map((final listener) async => await listener(event)),
    );
  }

  /// Trigger any access methods listening to this controller to save any
  /// changes.
  Future<void> triggerSave() async {
    await notifyListeners(AccessMethodRendererEvent.save);
  }
}

/// Renderer widget for an access method. This widget is used to render the
/// access method in the account screen.
class AccessMethodRenderer extends StatefulHookConsumerWidget {
  final bool isEditing;
  final Account account;

  final AccessMethodRendererController? controller;
  final AccessMethodInterfaceKey? interfaceKey;
  final AccessMethodRef? method;
  final void Function(AccessMethodRef methodRef)? onCreate;

  /// Can optionally be used to pass data to the renderer. This is useful for
  /// TOTP codes, where on creation, the code is passed to the renderer so that
  /// it can be parsed and useful information can be displayed.
  final String? existingData;

  const AccessMethodRenderer({
    final Key? key,
    required this.account,
    required this.isEditing,
    this.controller,
    this.existingData,
    // Option 1 (existing method).
    this.method,
    // Option 2 (new method).
    this.interfaceKey,
    this.onCreate,
  })  : assert(method != null || interfaceKey != null,
            "Either a method or an interface key must be provided."),
        assert(interfaceKey == null || onCreate != null,
            "If an interfaceKey is specified, onCreate must be specified as this is used to create a new method."),
        super(key: key);

  @override
  ConsumerState<AccessMethodRenderer> createState() =>
      _AccessMethodRendererState();
}

class _AccessMethodRendererState extends ConsumerState<AccessMethodRenderer> {
  final TextEditingController _labelEditingController = TextEditingController();
  final TextEditingController _dataEditingController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get alreadyExists => widget.method != null;
  AccessMethodInterfaceKey? get interfaceKey =>
      widget.method?.read.userInterfaceKey ?? widget.interfaceKey;

  /// Whether it has been requested that the password is shown.
  /// The password will only be shown if this is true AND if the user is
  /// present.
  bool _requestShowValue = false;
  bool _deleteConfirm = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(handleControllerEvent);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(handleControllerEvent);
    super.dispose();
  }

  Future<void> handleControllerEvent(
      final AccessMethodRendererEvent event) async {
    switch (event) {
      case AccessMethodRendererEvent.save:
        await save();
        break;
    }
  }

  Future<void> save() async {
    // Don't do anything if validation fails.
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    // If the access method already exists, update the existing one.
    if (alreadyExists) {
      // Create an editor to make changes to the method.
      final editor = widget.method!.editor;

      // Update the label if it has changed from the original label.
      if (_labelEditingController.text != widget.method!.read.label) {
        editor.method.label = _labelEditingController.text;
      }

      // Update method-specific data.
      switch (widget.method!.read.userInterfaceKey) {
        case AccessMethodInterfaceKey.password:
          if (editor.method is KnowledgeAccessMethod) {
            (editor.method as KnowledgeAccessMethod).data =
                _dataEditingController.text;
          }
          break;
        default:
          break;
      }

      // Write the changes back to the method.
      editor.commit();
      return;
    }

    // Otherwise, the method is to be created.
    final label = _labelEditingController.text.trim().isNotEmpty
        ? _labelEditingController.text
        : null;

    switch (interfaceKey) {
      case AccessMethodInterfaceKey.password:
      case AccessMethodInterfaceKey.securityQuestion:
        widget.onCreate?.call(AccessMethodStore().register(
          KnowledgeAccessMethod(
            _dataEditingController.text,
            userInterfaceKey: interfaceKey,
            label: label,
          ),
        ));
        break;
      case AccessMethodInterfaceKey.biometric:
        widget.onCreate?.call(AccessMethodStore().register(
          BiometricAccessMethod(
            userInterfaceKey: AccessMethodInterfaceKey.biometric,
            label: label,
          ),
        ));
        break;
      case AccessMethodInterfaceKey.totp:
        widget.onCreate?.call(AccessMethodStore().register(
          KnowledgeAccessMethod(
            widget.existingData!,
            userInterfaceKey: AccessMethodInterfaceKey.totp,
            label: "TOTP",
          ),
        ));
        break;
      case AccessMethodInterfaceKey.recoveryEmail:
      case AccessMethodInterfaceKey.otherAccount:
        final accountId = _dataEditingController.text;
        setState(() {
          _dataEditingController.text = "";
        });

        if (!ref.read(accountsProvider).hasWithId(accountId)) {
          context.showErrorSnackbar(
            message: "There was a problem adding the access method.",
          );
          return;
        }
        widget.onCreate?.call(AccessMethodStore().register(
          interfaceKey == AccessMethodInterfaceKey.recoveryEmail
              ? RecoveryEmailAccessMethod(accountId,
                  userInterfaceKey: AccessMethodInterfaceKey.recoveryEmail,
                  label: label)
              : ExistingAccountAccessMethod(
                  accountId,
                  userInterfaceKey: AccessMethodInterfaceKey.otherAccount,
                  label: label,
                ),
        ));
      default:
        break;
    }
  }

  void _syncEditingController() {
    // Don't bother doing anything if the method doesn't exist, because there
    // is nowhere to sync from.
    if (widget.method == null) return;

    // Sync the label.
    _labelEditingController.text = widget.method!.read.label ?? "";

    // Sync method-specific data.
    if (widget.method!.read is KnowledgeAccessMethod) {
      _dataEditingController.text =
          (widget.method!.read as KnowledgeAccessMethod).data;
    }
  }

  @override
  Widget build(final BuildContext context) {
    ref.watch(accessMethodProvider);
    final isUserPresent = ref.watch(userPresenceProvider);
    final showPassword = _requestShowValue && ref.read(userPresenceProvider);

    ref.listen(userPresenceProvider, (final previous, final next) {
      // If the user presence status has changed to false, reset the
      // _requestShowPassword flag.
      if (!next) {
        _requestShowValue = false;
        if (mounted) {
          setState(() {});
        }
      }
    });

    // If the method already exists, fetch its current value as the initial
    // value for the editing controller. Then, ensure that it remains
    // synchronized if editing is interrupted (and after editing is complete).
    // (e.g., overwriting the user's inputted value if editing is interrupted).
    if (widget.method != null) {
      useEffect(() {
        _syncEditingController();
        return null;
      }, []);

      useEffect(() {
        WidgetsBinding.instance.addPostFrameCallback((final _) {
          _syncEditingController();
        });
        return null;
      }, [widget.isEditing]);
    }

    final specificMethodWidget = Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: renderWidgetForInterfaceKey(
        context,
        label: alreadyExists ? widget.method!.read.label : null,
        isUserPresent: isUserPresent,
        showValue: showPassword,
        account: widget.account,
      ),
    );

    return Column(
      children: [
        if ((!alreadyExists ||
                interfaceKey == AccessMethodInterfaceKey.securityQuestion) &&
            ![
              AccessMethodInterfaceKey.totp,
              AccessMethodInterfaceKey.otherAccount,
              AccessMethodInterfaceKey.recoveryEmail
            ].contains(interfaceKey))
          TextFormField(
            controller: _labelEditingController,
            readOnly: !widget.isEditing,
            decoration: InputDecoration(
              labelText:
                  interfaceKey != AccessMethodInterfaceKey.securityQuestion
                      ? 'Label'
                      : 'Security Question',
              border: const UnderlineInputBorder(),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: specificMethodWidget),
            if (alreadyExists) ...[
              if (![
                AccessMethodInterfaceKey.totp,
                AccessMethodInterfaceKey.otherAccount,
              ].contains(widget.method!.read.userInterfaceKey))
                IconButton(
                  onPressed: () async {
                    bool wasUserPresent = isUserPresent;

                    await ref
                        .read(userPresenceProvider.notifier)
                        .checkPresence();
                    if (mounted) {
                      final String valueToCopy;
                      if (widget.method!.read is KnowledgeAccessMethod) {
                        valueToCopy = _dataEditingController.text;
                      } else if (widget.method!.read
                          is RecoveryEmailAccessMethod) {
                        valueToCopy = ref
                                .read(accountsProvider)
                                .get(widget.method!
                                    .readAs<RecoveryEmailAccessMethod>()
                                    .accountId)
                                ?.accountIdentifier ??
                            "";
                      } else {
                        valueToCopy = _labelEditingController.text;
                      }

                      if (valueToCopy.isNotEmpty) {
                        context.copyText(valueToCopy);
                      } else {
                        context.showInfoSnackbar(
                          message: 'Nothing to copy.',
                        );
                      }
                    }

                    if (!wasUserPresent) {
                      ref
                          .read(userPresenceProvider.notifier)
                          .clearPresenceStatus();
                    }
                  },
                  icon: const HeroIcon(
                    HeroIcons.clipboard,
                    style: HeroIconStyle.outline,
                  ),
                ),
              IconButton(
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  bool wasUserPresent = ref.read(userPresenceProvider);

                  await ref.read(userPresenceProvider.notifier).checkPresence();

                  if (!ref.read(userPresenceProvider)) return;

                  // If deleteConfirm is false, set it to true and return.
                  if (!_deleteConfirm) {
                    setState(() {
                      _deleteConfirm = true;
                    });
                    // Set a timer to reset the deleteConfirm state after 5
                    // seconds.
                    Timer(const Duration(seconds: 5), () {
                      if (mounted) {
                        setState(() {
                          _deleteConfirm = false;
                        });
                      }
                    });
                    return;
                  }

                  // Otherwise, delete the method. If we're here, it means
                  // the user has confirmed the deletion.
                  widget.method!.editor.deleteMethod();
                  if (mounted) {
                    context.showInfoSnackbar(
                      message: "Access method deleted.",
                    );
                  }

                  if (!wasUserPresent) {
                    ref
                        .read(userPresenceProvider.notifier)
                        .clearPresenceStatus();
                  }

                  setState(() {});
                },
                icon: HeroIcon(
                  _deleteConfirm ? HeroIcons.check : HeroIcons.trash,
                  color: const Color(0xFFFC5757),
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }

  Widget renderWidgetForInterfaceKey(
    final BuildContext context, {
    required final String? label,
    required final bool isUserPresent,
    required final bool showValue,
    required final Account account,
  }) {
    switch (interfaceKey) {
      case AccessMethodInterfaceKey.securityQuestion:
      case AccessMethodInterfaceKey.password:
        final String valueLabel;
        if (interfaceKey == AccessMethodInterfaceKey.securityQuestion) {
          valueLabel = "Security Answer";
        } else {
          valueLabel = (label != null && label.isNotEmpty
              ? "$label (Password, Passphrase or PIN)"
              : 'Password, Passphrase or PIN');
        }

        return TextFormField(
          controller: _dataEditingController,
          readOnly: !widget.isEditing,
          style: const TextStyle(
            fontFamily: "monospace",
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: valueLabel,
            border: const UnderlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    if (!isUserPresent) {
                      await ref
                          .read(userPresenceProvider.notifier)
                          .checkPresence();
                    }

                    setState(() {
                      if (!showValue) {
                        // If we're about to display the password, ensure that
                        // the user is present.
                        _requestShowValue = true;
                      } else {
                        _requestShowValue = false;
                      }
                    });
                  },
                  icon: HeroIcon(
                    showValue ? HeroIcons.eyeSlash : HeroIcons.eye,
                    style: HeroIconStyle.outline,
                  ),
                ),
              ],
            ),
          ),
          obscureText: !showValue,
        );
      case AccessMethodInterfaceKey.biometric:
        if (!alreadyExists) return Container();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const HeroIcon(HeroIcons.fingerPrint),
              const SizedBox(width: 10),
              const Text(
                'Biometric',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.start,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TextFormField(
                  controller: _labelEditingController,
                  readOnly: !widget.isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      case AccessMethodInterfaceKey.totp:
        {
          final totpData = TotpUrl.deserialize(
            widget.existingData != null
                ? widget.existingData!
                : (widget.method!.read as KnowledgeAccessMethod).data,
          );

          if (totpData == null) {
            return Text(
              'Invalid TOTP Data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            );
          }

          return TotpTile(
            totp: totpData,
            account: account,
          );
        }
      case AccessMethodInterfaceKey.sms:
        return Row(
          children: [
            const HeroIcon(HeroIcons.chatBubbleLeftEllipsis),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label != null && label.isNotEmpty
                    ? label
                    : "SMS Two-Factor Authentication",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        );
      case AccessMethodInterfaceKey.recoveryEmail:
      case AccessMethodInterfaceKey.otherAccount:
        if (alreadyExists) {
          final account = ref.read(accountsProvider).get(
              (widget.method!.read as ExistingAccountAccessMethod).accountId);

          return Row(
            children: [
              account?.hasIconUrl ?? false
                  ? AccountTileIcon(account: account)
                  : HeroIcon(
                      interfaceKey == AccessMethodInterfaceKey.recoveryEmail
                          ? HeroIcons.envelope
                          : HeroIcons.link),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interfaceKey == AccessMethodInterfaceKey.recoveryEmail
                          ? "Recovery Email"
                          : "Linked Account",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      account!.name,
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                    ),
                    Text(account.accountIdentifier),
                  ],
                ),
              )
            ],
          );
        }

        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
          ),
          items: ref
              .read(accountsProvider)
              .allAccounts
              .where((final accountRef) => accountRef.account != account)
              .where((final accountRef) => !account.accessMethods
                      .hasMethodWhere((final AccessMethodRef methodRef) {
                    // Filter out any accounts that are already linked.
                    bool filter = [
                          AccessMethodInterfaceKey.otherAccount,
                          AccessMethodInterfaceKey.recoveryEmail
                        ].contains(methodRef.read.userInterfaceKey) &&
                        methodRef
                                .readAs<ExistingAccountAccessMethod>()
                                .accountId ==
                            accountRef.id;

                    // If we're editing a recovery email method, filter out
                    // any accounts that aren't an email.
                    if (interfaceKey ==
                        AccessMethodInterfaceKey.recoveryEmail) {
                      filter |= !accountRef.account.isEmailAccount;
                    }

                    return filter;
                  }))
              .map(
                (final accountRef) => DropdownMenuItem<String>(
                  value: accountRef.id,
                  child: Text(interfaceKey ==
                          AccessMethodInterfaceKey.recoveryEmail
                      ? "${accountRef.account.accountIdentifier} (${accountRef.account.name})"
                      : accountRef.account.name),
                ),
              )
              .toList(),
          value: _dataEditingController.text.isNotEmpty
              ? _dataEditingController.text
              : null,
          validator: (final value) {
            if (value == null || value.isEmpty) {
              return "Please select an account.";
            }

            final hasAccount = account.accessMethods.hasMethodWhere(
                (final AccessMethodRef methodRef) =>
                    methodRef.read.userInterfaceKey ==
                        AccessMethodInterfaceKey.otherAccount &&
                    methodRef.readAs<ExistingAccountAccessMethod>().accountId ==
                        value);
            if (hasAccount) {
              return "This account is already linked.";
            }

            return null;
          },
          onChanged: (final accountId) {
            setState(() {
              _dataEditingController.text = accountId ?? "";
            });
          },
        );
      default:
        return const Text(
          'Unsupported Method',
          style: TextStyle(color: Colors.white),
        );
    }
  }
}
