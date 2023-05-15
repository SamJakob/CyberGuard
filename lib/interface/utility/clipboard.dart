import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension ClipboardUtilities on BuildContext {
  /// Copies the specified [value] to the user's clipboard and displays a
  /// Snackbar message to indicate that the copy was successful (unless
  /// [showSnackbar] is set to false).
  /// If the [value] is null, nothing will happen.
  ///
  /// Optionally, [snackbarText] can be used to override the text of the
  /// Snackbar message. If [snackbarText] is not specified, a default message
  /// will be displayed.
  void copyText(
    final String? value, {
    final bool showSnackbar = true,
    final String? snackbarText,
  }) {
    if (value == null) return;

    Clipboard.setData(ClipboardData(text: value));
    if (showSnackbar) {
      showInfoSnackbar(message: snackbarText ?? "Copied!");
    }
  }
}
