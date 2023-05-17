import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/data/struct/platform_message.dart';
import 'package:cyberguard/domain/providers/inference.dart';
import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:cyberguard/domain/services/settings_info.dart';
import 'package:cyberguard/interface/components/typography.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:cyberguard/interface/utility/url_launcher.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  final SettingsInfoService settingsInfo = locator.get<SettingsInfoService>();

  SettingsScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Scrollbar(
          child: Column(
            children: [
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text(
                  "Scan Account Setup",
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  settings.enableAnalysis
                      ? "$kAppName will automatically scan your account setup "
                          "to try and identify potential issues. All scanning "
                          "is performed locally on your device and your data "
                          "is NEVER sent from your device."
                      : "$kAppName will not perform any scans on your account "
                          "setup.",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                onChanged: (final bool value) {
                  ref.read(settingsProvider.notifier).setEnableAnalysis(value);
                  _triggerScan(context, ref);
                },
                value: settings.enableAnalysis,
              ),
              if (settings.enableAnalysis)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20)
                        .copyWith(top: 10),
                    child: ElevatedButton(
                      onPressed: () {
                        _triggerScan(context, ref);
                      },
                      child: const Text("Manually Start Scan"),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const ListTile(
                title: TitleText("Privacy Settings"),
              ),
              SwitchListTile(
                title: const Text(
                  "Automatic Service Discovery",
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  settings.enableServiceLookups
                      ? "$kAppName will attempt to automatically discover information about "
                          "authentication services such as its name, icon or password "
                          "reset page. This is done with an anonymous request to the "
                          "service to retrieve this information. You may, however, wish "
                          "to disable this for privacy reasons."
                      : "$kAppName will not attempt to automatically discover information "
                          "about authentication services.",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                onChanged: (final bool value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setEnableServiceLookups(value);
                },
                value: settings.enableServiceLookups,
              ),
              const SizedBox(height: 20),
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
                            " adapts its security capabilities to the platform it is running on. "
                            "Your detected platform is ",
                      ),
                      TextSpan(
                          text:
                              "${settingsInfo.secureStorageInfo.platform} ${settingsInfo.secureStorageInfo.platformVersion}",
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
                    if (settingsInfo.secureStorageInfo.isSimulator ||
                        settingsInfo
                            .secureStorageInfo.hasEnhancedSecurityWarning) ...[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: settingsInfo.secureStorageInfo.isSimulator
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
                                  settingsInfo.secureStorageInfo.isSimulator
                                      ? "You are running $kAppName on a simulator or emulator. Security features have been disabled."
                                      : settingsInfo.secureStorageInfo
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
                      value: settingsInfo.secureStorageInfo.hasEnhancedSecurity,
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
                    if (settingsInfo
                        .secureStorageInfo.hasSecureStorageDelegateInfo) ...[
                      PlatformInfoEntryTile(
                        title: "Secure Storage Delegate",
                        value: settingsInfo
                            .secureStorageInfo.secureStorageDelegate,
                        subtitle: (final value) {
                          return "(For advanced users).\n${value ?? "Unknown"}";
                        },
                      ),
                      PlatformInfoEntryTile(
                        title: "Encryption Scheme",
                        value: settingsInfo
                            .secureStorageInfo.secureStorageDelegateScheme,
                        subtitle: (final value) {
                          return "(For advanced users).\n${value ?? "Unknown"}";
                        },
                      ),
                      ..._metadataTiles(),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AboutListTile(
                applicationVersion:
                    "${settingsInfo.packageInfo.version} (Build ${settingsInfo.packageInfo.buildNumber})",
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
                        await context.launch(kAppSourceUrl!);
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
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Tap for more information  \u2022  Version ${settingsInfo.packageInfo.version} (Build ${settingsInfo.packageInfo.buildNumber})",
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _metadataTiles() {
    final List<Widget> tiles = [];

    final metadata =
        settingsInfo.secureStorageInfo.secureStorageDelegateMetadata;

    if (metadata != null) {
      for (final entry in metadata.entries) {
        // If the entry ends with "_label", it's a label for another entry,
        // so don't render it.
        if (entry.key.endsWith("_label")) continue;

        tiles.add(
          PlatformInfoEntryTile(
              title: metadata.containsKey("${entry.key}_label")
                  ? metadata["${entry.key}_label"].toString()
                  : entry.key,
              value: entry.value.toString(),
              subtitle: (final value) {
                return "(For advanced users).\n$value";
              }),
        );
      }
    }

    return tiles;
  }

  void _triggerScan(final BuildContext context, final WidgetRef ref) {
    if (!ref.read(settingsProvider).enableAnalysis) {
      ref.read(inferenceProvider.notifier).setData(null);
      return;
    }

    try {
      // For now just run the inference service immediately.
      // Later, the data could be snapshotted and passed to the
      // inference service to run in an isolate.
      final InferenceService inferenceService = locator.get<InferenceService>();
      final graph = inferenceService.run();
      final result = inferenceService.interpret(graph);

      ref.read(inferenceProvider.notifier).setData(InferenceProviderData(
            graph: graph,
            advice: result,
          ));

      context.showInfoSnackbar(
        message: "Scan complete. You can see the results on the home page.",
      );
    } catch (_) {}
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
