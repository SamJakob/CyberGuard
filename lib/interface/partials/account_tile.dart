import 'package:auto_size_text/auto_size_text.dart';
import 'package:cyberguard/data/struct/account.dart';
import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/interface/partials/account_tile_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

class AccountTile extends StatelessWidget {
  final AccountRef accountRef;

  String get id => accountRef.id;
  Account get account => accountRef.account;

  const AccountTile({
    super.key,
    required this.accountRef,
  });

  @override
  Widget build(final BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        clipBehavior: Clip.antiAlias,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(9),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Theme.of(context).colorScheme.surfaceVariant,
        child: InkWell(
          onTap: () {
            context.go('/accounts/$id');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                AccountTileIcon(account: account),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        minFontSize: 16,
                        style: const TextStyle(
                          height: 1.1,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        account.accountIdentifier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.1,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const HeroIcon(HeroIcons.arrowRight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
