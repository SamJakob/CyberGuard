import 'package:flutter/material.dart';

class NewAccountPage extends StatelessWidget {
  final BuildContext? parentContext;

  const NewAccountPage({
    final Key? key,
    this.parentContext,
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                "Add Account",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.start,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
