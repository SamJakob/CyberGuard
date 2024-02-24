import 'package:cyberguard/data/struct/access_method/access_method.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/interface/partials/access_method.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:flutter/material.dart';

class AddAccessMethodPage extends StatefulWidget {
  final AccessMethodInterfaceKey interfaceKey;
  final Account account;
  final String? existingData;

  const AddAccessMethodPage({
    super.key,
    required this.interfaceKey,
    required this.account,
    this.existingData,
  });

  @override
  State<AddAccessMethodPage> createState() => _AddAccessMethodPageState();
}

class _AddAccessMethodPageState extends State<AddAccessMethodPage> {
  /// Whether the form is currently loading.
  bool __isLoading = false;
  bool get _isLoading => __isLoading;
  set _isLoading(final bool value) {
    setState(() {
      __isLoading = value;
    });
  }

  final AccessMethodRendererController _accessMethodRendererController =
      AccessMethodRendererController();

  @override
  Widget build(final BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  "Add Access Method",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.start,
                ),
              ),
              Text(widget.interfaceKey.label),
              const SizedBox(height: 40),
              AccessMethodRenderer(
                account: widget.account,
                controller: _accessMethodRendererController,
                isEditing: true,
                interfaceKey: widget.interfaceKey,
                existingData: widget.existingData,
                onCreate: (final methodRef) {
                  context.showInfoSnackbar(message: "Access method added.");
                  Navigator.of(context).pop();
                  widget.account.accessMethods.add(methodRef);
                },
              ),
              const SizedBox(height: 40),
              Text(
                "The access method will be added immediately as you press 'Add'.",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("Cancel")),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: () {
                      _isLoading = true;
                      _accessMethodRendererController.triggerSave();
                    },
                    child: const Text("Add"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
