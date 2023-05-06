import 'dart:ui';

import 'package:cyberguard/const/branding.dart';
import 'package:cyberguard/interface/components/cyberguard_loading_icon.dart';
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
  final BuildContext _context;

  InterfaceProtectorMessenger.of(final BuildContext context)
      : _context = context;

  _InterfaceProtectorState? _locateInterfaceProtectorState() {
    return _context.findAncestorStateOfType<_InterfaceProtectorState>();
  }

  /// Checks if the [InterfaceProtectorMessenger] is able to contact a mounted
  /// [InterfaceProtector]. Returns true if there is one in the widget tree,
  /// otherwise false.
  bool isMounted() {
    return _locateInterfaceProtectorState() != null;
  }

  /// Attempts to insert the specified overlay into the [InterfaceProtector], if it
  /// is mounted. Otherwise, does nothing. Specify [shouldThrowOnFailure] if this
  /// call should throw an error on failure to locate an [InterfaceProtector]
  /// ancestor.
  ///
  /// Specify [blockChanges] if the [InterfaceProtector] should stop watching for
  /// status changes (e.g., to display a single screen and prevent interaction).
  void insertBlurOverlay(
    final BlurOverlay overlay, {
    final bool blockChanges = false,
    final bool shouldThrowOnFailure = false,
    final bool overrideLoading = false,
  }) {
    final state = _locateInterfaceProtectorState();
    if (state == null && shouldThrowOnFailure) {
      throw StateError("Failed to locate InterfaceProtector.");
    }

    if (overrideLoading) state?.setLoading(false);
    state?.addOverlay(overlay.toOverlayEntry());
    if (blockChanges) state?._changesBlocked = true;
  }
}

class InterfaceProtector extends StatefulWidget {
  /// A builder that renders the application's interface.
  final WidgetBuilder interfaceBuilder;

  final Future<void> Function(BuildContext)? initializeApp;

  const InterfaceProtector({
    final Key? key,
    required this.interfaceBuilder,
    this.initializeApp,
  }) : super(key: key);

  @override
  State<InterfaceProtector> createState() => _InterfaceProtectorState();
}

class _InterfaceProtectorState extends State<InterfaceProtector>
    with WidgetsBindingObserver {
  final GlobalKey<OverlayState> overlayKey = GlobalKey<OverlayState>();

  bool _changesBlocked = false;
  bool _initialized = false;

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
    // Insert a custom overlay, used to blur the child (i.e., the application interface).
    return Overlay(
      key: overlayKey,
      initialEntries: [
        OverlayEntry(
          maintainState: true,
          builder: (final BuildContext context) {
            if (!_initialized) {
              _initialized = true;

              WidgetsBinding.instance.addPostFrameCallback((final _) async {
                if (widget.initializeApp != null) {
                  setLoading(true);
                  try {
                    await widget.initializeApp!(context);
                    setLoading(false);
                  } catch (ex) {
                    setLoading(false);

                    BlurOverlay failOverlay =
                        InterfaceProtectorOverlays.decryptionFail;

                    if (ex is PlatformException) {
                      if (ex.details != null) {
                        failOverlay = failOverlay.copyWith(
                          additionalInformation: ex.details!.toString(),
                        );
                      }
                    }

                    addOverlay(
                      failOverlay.toOverlayEntry(),
                    );
                  }
                }
              });
            }

            return widget.interfaceBuilder(context);
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
