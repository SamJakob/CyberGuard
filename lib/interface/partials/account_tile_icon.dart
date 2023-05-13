import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';

class AccountTileIcon extends StatelessWidget {
  final Account account;

  const AccountTileIcon({
    super.key,
    required this.account,
  });

  @override
  Widget build(final BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: context.getAccentColorFor(account),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Center(
        child: Text(
          context.getInitialsFor(account),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}
