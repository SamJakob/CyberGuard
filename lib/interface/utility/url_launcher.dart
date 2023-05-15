import 'package:cyberguard/domain/error.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

extension ContextUrlLauncher on BuildContext {
  Future<void> launch(final String url,
      {final bool inExternalBrowser = false}) async {
    try {
      if (!await UrlLauncher.launchUrl(
        Uri.parse(url),
        mode: inExternalBrowser
            ? UrlLauncher.LaunchMode.externalApplication
            : UrlLauncher.LaunchMode.platformDefault,
      )) {
        throw CGRuntimeError("Failed to open page.");
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted) {
        showErrorSnackbar(message: "Failed to open page.");
      }
    }
  }
}
