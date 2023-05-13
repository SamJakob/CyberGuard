import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension ClipboardUtilities on BuildContext {
  /// Copies the specified [value] to the user's clipboard and displays a
  /// Snackbar message to indicate that the copy was successful (unless
  /// [showSnackbar] is set to false).
  /// If the [value] is null, nothing will happen.
  ///
  /// Optionally, [snackbarText] can be used to override the text of the
  /// Snackbar message. If [snackbarText] is not specified, [name]
  /// will be inserted into the default message if it is specified (e.g.
  /// "Copied [name]!").
  void copyText(
    final String? value, {
    final bool showSnackbar = true,
    final String? snackbarText,
  }) {
    if (value == null) return;

    Clipboard.setData(ClipboardData(text: value));
    if (showSnackbar) {
      ScaffoldMessenger.of(this).showSnackBar(SnackBar(
        showCloseIcon: true,
        closeIconColor: Theme.of(this).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(this).colorScheme.surfaceVariant,
        behavior: SnackBarBehavior.floating,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        content: Text(
          snackbarText ?? "Copied!",
          style: TextStyle(
            color: Theme.of(this).colorScheme.onSurfaceVariant,
          ),
        ),
      ));
    }
  }
}
