import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  /// The [id] of the account to display.
  final String id;

  const AccountScreen({
    final Key? key,
    required this.id,
  }) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account ${widget.id}"),
      ),
      body: Center(
        child: Text("Account ${widget.id}"),
      ),
    );
  }
}
