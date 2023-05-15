import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cyberguard/domain/services/vibration.dart';
import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:cyberguard/interface/partials/app_word_mark.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:cyberguard/interface/utility/ui_scaling_service.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messagepack/messagepack.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum TotpDigest {
  /// The default digest for TOTP.
  sha1,
  sha256,
  sha512;

  static const defaultDigest = TotpDigest.sha1;

  static TotpDigest? fromName(final String name) {
    return TotpDigest.values
        .where((final digest) =>
            digest.name == name.toLowerCase().replaceAll("-", ""))
        .singleOrNull;
  }

  crypto.Hash get algorithm {
    switch (this) {
      case TotpDigest.sha1:
        return crypto.sha1;
      case TotpDigest.sha256:
        return crypto.sha256;
      case TotpDigest.sha512:
        return crypto.sha512;
    }
  }
}

enum TotpDigits {
  /// The default number of digits for TOTP.
  six(6),
  eight(8);

  final int value;
  const TotpDigits(this.value);

  static const defaultDigits = TotpDigits.six;

  static TotpDigits? fromValue(final int value) {
    return TotpDigits.values
        .where((final digits) => digits.value == value)
        .singleOrNull;
  }
}

class TotpUrl {
  final String rawUrl;

  final String secret;
  final String label;
  final String? issuer;

  final TotpDigest digest;
  final TotpDigits digits;

  final int validityPeriod;

  TotpUrl(
    this.rawUrl, {
    required this.secret,
    required this.label,
    this.issuer,
    this.digest = TotpDigest.defaultDigest,
    this.digits = TotpDigits.defaultDigits,
    this.validityPeriod = 30,
  });

  static TotpUrl? parse(final String totpUrl) {
    if (!totpUrl.startsWith("otpauth://totp/")) {
      return null;
    }

    Uri parsedUri = Uri.parse(totpUrl);
    if (parsedUri.pathSegments.length > 1) return null;

    String label = parsedUri.pathSegments.length == 1
        ? parsedUri.pathSegments.last
        : "Unknown";
    final parameters = parsedUri.queryParameters;

    if (!parameters.containsKey('secret')) return null;

    return TotpUrl(
      totpUrl,
      secret: parameters['secret']!,
      label: label,
      issuer: parameters['issuer'],
      // Check if the digest is a recognized format, otherwise revert to the
      // default.
      digest: parameters['algorithm'] != null
          ? (TotpDigest.fromName(parameters['algorithm']!) ??
              TotpDigest.defaultDigest)
          : TotpDigest.sha1,
      // Check if the digit count is a recognized format, otherwise revert
      // to the default.
      digits: parameters['digits'] != null
          ? (TotpDigits.fromValue(int.parse(parameters['digits']!)) ??
              TotpDigits.defaultDigits)
          : TotpDigits.six,
      // Check if the validity period is a recognized format, otherwise revert
      // to the default.
      validityPeriod:
          // Clamp the validity period between 1 and 86400 seconds (1 day).
          // Seriously, if anyone's using a TOTP > 1 hour, stop!
          (parameters['period'] != null ? int.parse(parameters['period']!) : 30)
              .clamp(1, 86400),
    );
  }

  /// Serialize the TOTP URL into a base-64 encoded representation of a binary
  /// MessagePack serialization. This can then be used with
  /// [KnowledgeAccessMethod] to create a new TOTP access method.
  String serialize() {
    final messagePacker = Packer();

    messagePacker
      ..packString(rawUrl)
      ..packString(secret)
      ..packString(label)
      ..packString(issuer)
      ..packString(digest.name)
      ..packInt(digits.value)
      ..packInt(validityPeriod);

    return const Base64Encoder().convert(messagePacker.takeBytes());
  }

  /// Deserializes the TOTP URL, effectively doing the opposite of [serialize].
  static TotpUrl? deserialize(final String serialized) {
    if (serialized.isEmpty) return null;
    try {
      final unpacker = Unpacker(const Base64Decoder().convert(serialized));

      return TotpUrl(
        unpacker.unpackString()!,
        secret: unpacker.unpackString()!,
        label: unpacker.unpackString()!,
        issuer: unpacker.unpackString(),
        digest: TotpDigest.fromName(unpacker.unpackString()!)!,
        digits: TotpDigits.fromValue(unpacker.unpackInt()!)!,
        validityPeriod: unpacker.unpackInt()!,
      );
    } catch (e) {
      if (kDebugMode) print(e);
      return null;
    }
  }

  @override
  bool operator ==(final Object other) {
    if (other is TotpUrl) {
      return secret == other.secret &&
          digest == other.digest &&
          digits == other.digits &&
          validityPeriod == other.validityPeriod;
    }

    return super == other;
  }

  @override
  int get hashCode => Object.hash(secret, digest, digits, validityPeriod);
}

/// A page that allows the user to scan a QR code to add a TOTP access method.
///
/// Pages used to test:
/// - https://totp.danhersam.com/ (generate TOTP secret with parameters and
/// show code live)
/// - https://stefansundin.github.io/2fa-qr/ (render QR code from TOTP)
class TotpScanner extends StatefulHookWidget {
  const TotpScanner({final Key? key}) : super(key: key);

  @override
  State<TotpScanner> createState() => _TotpScannerState();
}

class _TotpScannerState extends State<TotpScanner> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  String animatedEllipsis = "";
  Timer? _animatorTimer;

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _animatorTimer =
        Timer.periodic(const Duration(milliseconds: 500), (final timer) {
      setState(() {
        animatedEllipsis =
            animatedEllipsis.length < 3 ? "$animatedEllipsis." : "";
      });
    });
  }

  @override
  void dispose() {
    _animatorTimer?.cancel();
    _animatorTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {});
  }

  @override
  Widget build(final BuildContext context) {
    final bool hasFlashlight =
        useValueListenable(_controller.hasTorchState) ?? false;
    final TorchState flashlightState =
        useValueListenable(_controller.torchState) ?? TorchState.off;

    final bool flashlightOn = flashlightState == TorchState.on;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (final capture) {
              for (final barcode in capture.barcodes) {
                // Skip unrecognized barcodes.
                if (![BarcodeType.text, BarcodeType.url, BarcodeType.unknown]
                    .contains(barcode.type)) {
                  continue;
                }

                // Attempt to obtain the barcode value.
                String? value = barcode.rawValue;
                if (value == null) continue;

                // Attempt to parse the URL as a TOTP. If it fails, continue.
                // Otherwise, pop with the TOTP URL.
                final totp = TotpUrl.parse(value);
                if (totp != null) {
                  locator.get<VibrationService>().vibrateEmphasis();
                  return context.pop(totp);
                }
              }
            },
          ),
          if (_processing)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ApolloLoadingSpinner(),
                    SizedBox(height: 20),
                    Text(
                      "Processing image...",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20)
                      .copyWith(top: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (locator.get<UiScalingService>().metrics.width >=
                              400)
                            const CGAppWordmark(),
                          const Spacer(),
                          if (hasFlashlight && !_processing)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                _controller.toggleTorch();
                              },
                              icon: HeroIcon(
                                flashlightOn
                                    ? HeroIcons.bolt
                                    : HeroIcons.boltSlash,
                                style: flashlightOn
                                    ? HeroIconStyle.solid
                                    : HeroIconStyle.outline,
                              ),
                              label: Text(
                                locator.get<UiScalingService>().metrics.width <
                                        400
                                    ? (flashlightOn ? "On" : "Off")
                                    : flashlightOn
                                        ? "Flashlight On"
                                        : "Flashlight Off",
                              ),
                            ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const HeroIcon(HeroIcons.xMark),
                            label: const Text("Cancel"),
                          ),
                        ],
                      ),
                      if (!_processing) ...[
                        const SizedBox(height: 20),
                        Text(
                          "Searching for QR code$animatedEllipsis",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          child: const Text(
                              "...or tap here to import from Camera Roll..."),
                          onPressed: () async {
                            _controller.stop();
                            setState(() {
                              _processing = true;
                            });

                            try {
                              final ImagePicker picker = ImagePicker();
                              final image = await picker.pickImage(
                                source: ImageSource.gallery,
                                requestFullMetadata: false,
                              );

                              if (image != null) {
                                if (!(await _controller
                                    .analyzeImage(image.path))) {
                                  if (mounted) {
                                    context.showErrorSnackbar(
                                        message: "No QR code found in image.");
                                  }
                                } else {
                                  return;
                                }
                              }
                            } catch (e) {
                              if (kDebugMode) print(e);
                            }

                            setState(() {
                              _processing = false;
                            });
                            _controller.start();
                            return;
                          },
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
