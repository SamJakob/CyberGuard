import 'package:flutter/material.dart';

class TitleText extends StatelessWidget {
  final String text;
  const TitleText(this.text, {final Key? key}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        // letterSpacing: 1.1,
      ),
    );
  }
}
