import 'package:cyberguard/interface/utility/context.dart';
import 'package:flutter/material.dart';

class AppWordMark extends StatelessWidget {
  const AppWordMark({final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          "assets/images/cg-icon-fg.png",
          height: 28,
        ),
        const SizedBox(width: 8),
        Text(
          "CyberGuard",
          style: TextStyle(
            height: 1.0,
            color: context.colorScheme.onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        )
      ],
    );
  }
}
