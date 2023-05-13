import 'dart:ui';

import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/interface/components/cyberguard_loading_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';

class InterfaceProtectorOverlays {
  /// Blur overlay to conceal information for security reasons when the app
  /// leaves the foreground.
  static const BlurOverlay securityConceal = BlurOverlay(
    icon: HeroIcons.eyeSlash,
    title: "Your information is protected.",
    message:
        "For your security, potentially sensitive information is being hidden. "
        "Please return to the app to view your information.",
  );

  /// Blur overlay to prevent app usage when a compatibility test fails.
  static const BlurOverlay compatibilityFail = BlurOverlay(
    icon: HeroIcons.boltSlash,
    title: "Incompatible Device",
    headline: "$kAppName isn't compatible with your device.",
    message:
        "If you're running an older software version, or using an older device, "
        "you may want to consider updating or upgrading to make use of modern and "
        "up-to-date security features!",
  );

  /// Blur overlay to prevent app usage when decryption fails.
  static const BlurOverlay decryptionFail = BlurOverlay(
    icon: HeroIcons.shieldExclamation,
    title: "Failed to Decrypt Data",
    headline: "We couldn't decrypt your data.",
    message:
        "Please try closing the app and opening it again. You might see this "
        "message if you didn't scan your biometrics successfully.",
  );

  static const LoaderOverlay loader = LoaderOverlay(
    message: "Securing your device...",
  );
}

class InterfaceProtectorMessenger {
  final _InterfaceState<dynamic>? _state;

  InterfaceProtectorMessenger.of(final BuildContext context)
      : _state = context.findAncestorStateOfType<_InterfaceState<dynamic>>();

  InterfaceProtectorMessenger._withState(final _InterfaceState<dynamic> state)
      : _state = state;

  /// Attempts to insert the specified overlay into the [Interface], if it
  /// is mounted. Otherwise, does nothing. Specify [shouldThrowOnFailure] if this
  /// call should throw an error on failure to locate an [Interface]
  /// ancestor.
  ///
  /// Specify [blockChanges] if the [Interface] should stop watching for
  /// status changes (e.g., to display a single screen and prevent interaction).
  void insertBlurOverlay(
    final BlurOverlay overlay, {
    final bool blockChanges = false,
    final bool shouldThrowOnFailure = false,
    final bool overrideLoading = false,
  }) {
    if (_state == null && shouldThrowOnFailure) {
      throw StateError("Failed to locate InterfaceProtector.");
    }

    if (overrideLoading) _state?.setLoading(false);
    _state?.addOverlay(overlay.toOverlayEntry());
    if (blockChanges) _state?._changesBlocked = true;
  }
}

typedef InterfaceBuilder<InterfaceInitData> = Widget Function(
    BuildContext context, InterfaceInitData? initializationData);

class Interface<InterfaceInitData> extends StatefulWidget {
  /// A builder that renders the application's interface.
  final InterfaceBuilder<InterfaceInitData> interfaceBuilder;

  final Future<InterfaceInitData?> Function(
      BuildContext, InterfaceProtectorMessenger)? initializeApp;

  const Interface({
    final Key? key,
    required this.interfaceBuilder,
    this.initializeApp,
  }) : super(key: key);

  @override
  State<Interface<InterfaceInitData>> createState() =>
      _InterfaceState<InterfaceInitData>();
}

enum _InterfaceInitState { uninitialized, initializing, initialized, error }

class _InterfaceState<InterfaceInitData>
    extends State<Interface<InterfaceInitData>> with WidgetsBindingObserver {
  final GlobalKey<OverlayState> overlayKey = GlobalKey<OverlayState>();

  bool _changesBlocked = false;
  _InterfaceInitState _initializationState = _InterfaceInitState.uninitialized;

  bool _loading = true;

  final _securityOverlay =
      InterfaceProtectorOverlays.securityConceal.toOverlayEntry();

  final _loaderOverlay = InterfaceProtectorOverlays.loader.toOverlayEntry();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (_changesBlocked) return;

    setState(() {
      try {
        if (state != AppLifecycleState.resumed) {
          addOverlay(_securityOverlay);
        } else {
          removeOverlay(_securityOverlay);
        }
      } catch (_) {}
    });
  }

  void addOverlay(final OverlayEntry entry) {
    if (_loading && entry != _loaderOverlay) return;
    if (!entry.mounted) overlayKey.currentState!.insert(entry);
  }

  void removeOverlay(final OverlayEntry entry) {
    try {
      if (entry.mounted) entry.remove();
    } catch (_) {}
  }

  void setLoading(final bool isLoading) {
    _loading = isLoading;
    setState(() {
      if (isLoading) {
        addOverlay(_loaderOverlay);
      } else {
        removeOverlay(_loaderOverlay);
      }
    });
  }

  @override
  Widget build(final BuildContext context) {
    InterfaceInitData? initializationResult;

    if (_initializationState == _InterfaceInitState.uninitialized) {
      _initializationState = _InterfaceInitState.initializing;

      WidgetsBinding.instance.addPostFrameCallback((final _) async {
        if (widget.initializeApp != null) {
          setLoading(true);
          try {
            initializationResult = await widget.initializeApp!(
              context,
              InterfaceProtectorMessenger._withState(this),
            );
            setState(() {
              _initializationState = _InterfaceInitState.initialized;
            });
            setLoading(false);
          } catch (ex) {
            if (kDebugMode) print(ex);

            setState(() {
              _initializationState = _InterfaceInitState.error;
            });
            setLoading(false);

            BlurOverlay failOverlay = InterfaceProtectorOverlays.decryptionFail;

            if (ex is PlatformException) {
              if (ex.details != null) {
                failOverlay = failOverlay.copyWith(
                  additionalInformation: ex.details!.toString(),
                );
              }
            }

            addOverlay(failOverlay.toOverlayEntry());
          }
        }
      });
    }

    // Insert a custom overlay, used to blur the child (i.e., the application interface).
    return Overlay(
      key: overlayKey,
      initialEntries: [
        OverlayEntry(
          maintainState: true,
          builder: (final BuildContext context) {
            // Show a black screen on the interface entry in the widget tree
            // until the application is initialized.
            // The loader will be overlayed on top of this.
            if ([
              _InterfaceInitState.uninitialized,
              _InterfaceInitState.initializing
            ].contains(_initializationState)) {
              return Container(color: Colors.black);
            } else {
              return widget.interfaceBuilder(context, initializationResult);
            }
          },
        ),
        _loaderOverlay,
      ],
    );
  }
}

class LoaderOverlay {
  final String message;

  const LoaderOverlay({
    required this.message,
  });

  LoaderOverlay copyWith({
    final String? message,
  }) {
    return LoaderOverlay(
      message: message ?? this.message,
    );
  }

  OverlayEntry toOverlayEntry() {
    return OverlayEntry(
      maintainState: true,
      opaque: true,
      builder: (final BuildContext context) {
        return IgnorePointer(
          child: Center(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Source Sans Pro",
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CyberGuardLoadingIcon(),
                  const SizedBox(height: 20),
                  const Text(
                    "CYBERGUARD",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class BlurOverlay {
  final HeroIcons icon;
  final String title;
  final String message;
  final String? headline;
  final String? additionalInformation;

  const BlurOverlay({
    required this.icon,
    required this.title,
    required this.message,
    this.headline,
    this.additionalInformation,
  });

  BlurOverlay copyWith({
    final HeroIcons? icon,
    final String? title,
    final String? message,
    final String? headline,
    final String? additionalInformation,
  }) {
    return BlurOverlay(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      message: message ?? this.message,
      headline: headline ?? this.headline,
      additionalInformation:
          additionalInformation ?? this.additionalInformation,
    );
  }

  /// Create an overlay from an icon, title and message.
  OverlayEntry toOverlayEntry() {
    return OverlayEntry(
      maintainState: true,
      builder: (final BuildContext context) {
        return IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Source Sans Pro",
              ),
              child: Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HeroIcon(
                          icon,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (headline != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            headline!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (additionalInformation != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            additionalInformation!,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
