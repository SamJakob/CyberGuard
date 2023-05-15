import 'package:flutter/material.dart';

extension CGSnackbars on BuildContext {
  void showInfoSnackbar({required final String message}) {
    ScaffoldMessenger.of(this)
        .removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
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
        message,
        style: TextStyle(
          color: Theme.of(this).colorScheme.onSurfaceVariant,
        ),
      ),
    ));
  }

  void showErrorSnackbar({required final String message}) {
    ScaffoldMessenger.of(this)
        .removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      showCloseIcon: true,
      closeIconColor: Theme.of(this).colorScheme.onErrorContainer,
      backgroundColor: Theme.of(this).colorScheme.errorContainer,
      behavior: SnackBarBehavior.floating,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(this).colorScheme.onErrorContainer,
        ),
      ),
    ));
  }
}
