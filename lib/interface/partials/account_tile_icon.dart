import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';

/// A widget that displays an account's icon. If the account has an icon URL,
/// it will be displayed. Otherwise, the account's initials will be displayed.
/// If no account is provided, the label will be used instead, this is to allow
/// for a fallback to rendered.
class AccountTileIcon extends StatelessWidget {
  final Account? account;
  final String? label;

  const AccountTileIcon({
    super.key,
    this.account,
    this.label,
  }) : assert(account != null || label != null,
            "Either account or label must be provided.");

  @override
  Widget build(final BuildContext context) {
    if (account != null && account!.hasIconUrl) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          image: DecorationImage(
            image: NetworkImage(account!.iconUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color:
            context.getAccentColorFor(account != null ? account!.name : label!),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Center(
        child: Text(
          context.getInitialsFor(account != null ? account!.name : label!),
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
