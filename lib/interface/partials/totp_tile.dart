import 'dart:math';
import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/services/vibration.dart';
import 'package:cyberguard/interface/components/progress_wheel.dart';
import 'package:cyberguard/interface/pages/totp_scan.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:cyberguard/interface/utility/clipboard.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:heroicons/heroicons.dart';

class TotpTile extends HookWidget {
  final TotpUrl totp;
  final Account? account;

  const TotpTile({
    super.key,
    required this.totp,
    this.account,
  });

  String _computeValue() {
    // Generate TOTP (time-based) counter. Number of seconds since epoch
    // divided by validity period.
    final int counter =
        ((DateTime.now().millisecondsSinceEpoch / 1000) / totp.validityPeriod)
            .floor();

    // Generate HMAC-digest of the counter using the secret key.
    final counterByteData = ByteData(8)..setUint64(0, counter);
    final List<int> counterBytes = counterByteData.buffer.asUint8List(0, 8);

    // Compute the digest using HMAC.
    final digest = Hmac(totp.digest.algorithm, base32.decode(totp.secret))
        .convert(counterBytes);

    // Fetch the 4 least-significant bits of the digest.
    final digestBytes = digest.bytes;

    // Then, use those 4 bits to compute the offset of the 4-byte code.
    final offset =
        digestBytes[digestBytes.length - 1] & 0xf; // 0xf = 15 = 0b1111 = 4 bits
    final truncatedDigest = digestBytes.sublist(offset, offset + 4);

    // Convert the 4 bytes to a 32-bit unsigned integer (big-endian), and
    // technically this is a 31-bit integer to ensure no ambiguity with
    // unsigned vs. signed behaviors, so mask off the MSB.
    final truncatedDigestByteData = ByteData(4)
      ..setUint8(0, truncatedDigest[0])
      ..setUint8(1, truncatedDigest[1])
      ..setUint8(2, truncatedDigest[2])
      ..setUint8(3, truncatedDigest[3]);
    final truncatedDigestBytes = truncatedDigestByteData.getUint32(0) &
        0x7FFFFFFF; // Ensure MSB is masked off.

    // Convert to a string by converting the number to decimal and padding it.
    final String code = (truncatedDigestBytes % pow(10, totp.digits.value))
        .toString()
        .padLeft(totp.digits.value, '0');

    switch (code.length) {
      case 6:
        return "${code.substring(0, 3)} ${code.substring(3, 6)}";
      case 8:
        return "${code.substring(0, 3)} ${code.substring(3, 6)} ${code.substring(6, 8)}";
      default:
        return code;
    }
  }

  double _computeTimeRemaining() {
    final normalizedValue =
        (((DateTime.now().toUtc().second % totp.validityPeriod) /
                        (totp.validityPeriod)) *
                    totp.validityPeriod)
                .floor() /
            totp.validityPeriod;
    return normalizedValue;
  }

  @override
  Widget build(final BuildContext context) {
    // Create an animation controller for the progress wheel and listen to it.
    final animationController = useListenable(useAnimationController(
      duration: const Duration(milliseconds: 1000),
    ));

    useEffect(() {
      animationController.repeat();
      return null;
    }, []);

    final currentCode = _computeValue();

    return InkWell(
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      onTap: () {
        context.copyText(
          // Copy without spaces.
          currentCode.replaceAll(" ", ""),
          snackbarText: "Copied TOTP code.",
        );
        locator.get<VibrationService>().vibrateSuccess();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AccountTileIcon(
              account: account,
              label: totp.label,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: AutoSizeText(
                                totp.label,
                                maxLines: 1,
                                style: const TextStyle(
                                  height: 1,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.start,
                              ),
                            ),
                            if (totp.issuer != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 5, right: 20),
                                child: AutoSizeText(
                                  totp.issuer!,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const HeroIcon(
                        HeroIcons.clipboard,
                        style: HeroIconStyle.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: AutoSizeText(
                            currentCode,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFamily: "monospace",
                            ),
                          ),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ProgressWheel(
                            animation: CurvedAnimation(
                              parent: animationController,
                              curve: Curves.easeInOutCubic,
                            ),
                            animateFrom: ProgressWheelAnimateFrom.previousValue,
                            valueComputer: () => _computeTimeRemaining(),
                            size: 32,
                          ),
                          Text(
                            (totp.validityPeriod -
                                    (_computeTimeRemaining() *
                                        totp.validityPeriod))
                                .round()
                                .toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (account != null)
                    Text(
                      "${account!.name} \u2022 ${account!.accountIdentifier}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
