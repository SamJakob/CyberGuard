import 'package:async/async.dart';

import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/struct/platform_message.dart';
import 'package:cyberguard/domain/services/settings.dart';
import 'package:cyberguard/interface/components/typography.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settings = locator.get<SettingsService>();

  SettingsScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const ListTile(
            title: TitleText("App Information"),
          ),
          ListTile(
            title: const Text(
              "Platform Information",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            subtitle: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                children: [
                  const TextSpan(
                    text: kAppName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        " adapts its capabilities to the platform it is running on. "
                        "Your detected platform is ",
                  ),
                  TextSpan(
                      text:
                          "${settings.secureStorageInfo.platform} ${settings.secureStorageInfo.platformVersion}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: "."),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: Column(
              children: [
                if (settings.secureStorageInfo.isSimulator ||
                    settings.secureStorageInfo.hasEnhancedSecurityWarning) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: settings.secureStorageInfo.isSimulator
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const HeroIcon(
                            HeroIcons.exclamationTriangle,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              settings.secureStorageInfo.isSimulator
                                  ? "You are running $kAppName on a simulator or emulator. Security features have been disabled."
                                  : settings.secureStorageInfo
                                      .enhancedSecurityWarning!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
                PlatformInfoEntryTile(
                  title: "Enhanced Security Status",
                  value: settings.secureStorageInfo.hasEnhancedSecurity,
                  subtitle: (final value) {
                    return "Secure operations on your device ${value.code != PlatformEnhancedSecurityStatus.unavailable.code ? "are" : "ARE NOT"} performed in a secure environment.";
                  },
                  valueBuilder: (final BuildContext context, final value) {
                    switch (value) {
                      case PlatformEnhancedSecurityStatus.unavailable:
                        return const Text(
                          "INACTIVE",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      case PlatformEnhancedSecurityStatus.warning:
                        return const Text(
                          "WARNING",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      case PlatformEnhancedSecurityStatus.available:
                        return const Text(
                          "ACTIVE",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                    }
                  },
                ),
                if (settings
                    .secureStorageInfo.hasSecureStorageDelegateInfo) ...[
                  PlatformInfoEntryTile(
                    title: "Secure Storage Delegate",
                    value: settings.secureStorageInfo.secureStorageDelegate,
                    subtitle: (final value) {
                      return "(For advanced users).\n${value ?? "Unknown"}";
                    },
                  ),
                  PlatformInfoEntryTile(
                    title: "Encryption Scheme",
                    value:
                        settings.secureStorageInfo.secureStorageDelegateScheme,
                    subtitle: (final value) {
                      return "(For advanced users).\n${value ?? "Unknown"}";
                    },
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 8),
          AboutListTile(
            applicationVersion:
                "${settings.packageInfo.version} (Build ${settings.packageInfo.buildNumber})",
            applicationLegalese: kAppLegalese,
            aboutBoxChildren: [
              if (kAppSourceUrl != null) ...[
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  leading: HeroIcon(HeroIcons.link,
                      color: Theme.of(context).primaryColor),
                  title: Text(
                    "Source Code on GitHub",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                  onTap: () async {
                    await launchUrl(Uri.parse(kAppSourceUrl!))
                        .catchError((final _) => false);
                  },
                  onLongPress: () async {
                    await Clipboard.setData(
                        ClipboardData(text: kAppSourceUrl!));
                    if (scaffoldMessenger.mounted) {
                      scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text("Copied URL to clipboard."),
                      ));
                    }
                  },
                )
              ],
            ],
            applicationIcon: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                "assets/images/cg-icon.png",
                height: 48,
                width: 48,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "About $kAppName",
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                Text(
                  "Tap for more information  \u2022  Version ${settings.packageInfo.version} (Build ${settings.packageInfo.buildNumber})",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef ParameterizedWidgetBuilder<T> = Widget Function(
    BuildContext context, T value);
typedef ParameterizedStringBuilder<T> = String Function(T value);

class PlatformInfoEntryTile<T> extends StatelessWidget {
  final String title;
  final ParameterizedStringBuilder<T>? subtitle;
  final T value;
  final ParameterizedWidgetBuilder<T>? valueBuilder;

  const PlatformInfoEntryTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.valueBuilder,
  });

  static ParameterizedWidgetBuilder<bool> booleanValueBuilder({
    final String ifTrue = "Yes",
    final String ifFalse = "No",
    final bool withColor = false,
  }) =>
      (final BuildContext context, final bool value) => Text(
            value ? ifTrue : ifFalse,
            style: TextStyle(
              color: value ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          );

  @override
  Widget build(final BuildContext context) {
    return ListTile(
      // dense: true,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!.call(value),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      trailing: valueBuilder?.call(context, value),
    );
  }
}
