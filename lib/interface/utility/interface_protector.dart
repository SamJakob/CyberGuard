import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

class InterfaceProtector extends StatefulWidget {
  /// A builder that renders the application's interface.
  final WidgetBuilder interfaceBuilder;

  const InterfaceProtector({final Key? key, required this.interfaceBuilder}) : super(key: key);

  @override
  State<InterfaceProtector> createState() => _InterfaceProtectorState();
}

class _InterfaceProtectorState extends State<InterfaceProtector> with WidgetsBindingObserver {
  final GlobalKey<OverlayState> overlayKey = GlobalKey<OverlayState>();

  final OverlayEntry _blurOverlay = OverlayEntry(
    maintainState: true,
    builder: (final BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
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
                  children: const [
                    HeroIcon(
                      HeroIcons.eyeSlash,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Your information is protected.",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "For your security, potentially sensitive information is being hidden. Please return to the app to view your information.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

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
    setState(() {
      if (state != AppLifecycleState.resumed && !_blurOverlay.mounted) {
        overlayKey.currentState!.insert(_blurOverlay);
      } else {
        if (_blurOverlay.mounted) _blurOverlay.remove();
      }
    });
  }

  @override
  Widget build(final BuildContext context) {
    // Insert a custom overlay, used to blur the child (i.e., the application interface).
    return Overlay(
      key: overlayKey,
      initialEntries: [
        OverlayEntry(builder: widget.interfaceBuilder),
      ],
    );
  }
}
