import 'package:cyberguard/interface/utility/regex.dart';
import 'package:cyberguard/interface/utility/validate.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AddAccountFormData {
  final String name;
  final String accountIdentifier;
  final String password;

  const AddAccountFormData({
    required this.name,
    required this.accountIdentifier,
    required this.password,
  });
}

class AddAccountForm extends ConsumerStatefulWidget {
  final bool disableValidation;

  const AddAccountForm({
    final Key? key,
    this.disableValidation = false,
  }) : super(key: key);

  @override
  ConsumerState<AddAccountForm> createState() => AddAccountFormState();
}

class AddAccountFormState extends ConsumerState<AddAccountForm> {
  bool _showPassword = false;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController(),
      _accountIdentifierController = TextEditingController(),
      _passwordController = TextEditingController();

  bool get accountIdentifierIsEmail => matches(
        _accountIdentifierController.text,
        regex: emailRegex,
      );

  bool get hasPassword => _passwordController.text.trim().isNotEmpty;

  AddAccountFormData getData() {
    return AddAccountFormData(
      name: _nameController.text,
      accountIdentifier: _accountIdentifierController.text,
      password: _passwordController.text,
    );
  }

  /// Validates the form internally, returning true if there are no errors.
  bool validate() {
    return _formKey.currentState!.validate();
  }

  @override
  Widget build(final BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: widget.disableValidation
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            validator: (final String? value) {
              if (value == null || value.trim().isEmpty) {
                return "Please enter a name for this account.";
              }
              String? error;
              if ((error = ref.checkForNameAndAccountIdentifierCombo(
                    accountName: _nameController.text,
                    accountIdentifier: _accountIdentifierController.text,
                  )) !=
                  null) {
                return error;
              }
              return null;
            },
            decoration: const InputDecoration(
              isDense: true,
              labelText: "Service *",
              helperText:
                  "The name of the service or website this account is for (e.g., \"Apple\", \"Google\").",
              helperMaxLines: 2,
              errorMaxLines: 4,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _accountIdentifierController,
            validator: (final String? value) {
              if (value == null || value.trim().isEmpty) {
                return "Please enter your identifier (such as a username, email, or ID) for this account. If you don't have one, or aren't sure, enter something that makes sense to you (such as your name).";
              }
              String? error;
              if ((error = ref.checkForNameAndAccountIdentifierCombo(
                    accountName: _nameController.text,
                    accountIdentifier: _accountIdentifierController.text,
                  )) !=
                  null) {
                return error;
              }
              return null;
            },
            autocorrect: false,
            decoration: const InputDecoration(
              isDense: true,
              labelText: "Username, Email or ID *",
              helperText:
                  "The username, email or other identifier that you use to sign into this account.",
              helperMaxLines: 2,
              errorMaxLines: 4,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            autocorrect: false,
            style: const TextStyle(
              fontFamily: "monospace",
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: "Password",
              helperText:
                  "Leave blank if you don't use a password, or choose 'More Options' below.",
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
                icon: HeroIcon(
                  _showPassword ? HeroIcons.eyeSlash : HeroIcons.eye,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
