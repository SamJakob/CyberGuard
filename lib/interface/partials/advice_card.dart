import 'package:cyberguard/domain/providers/account.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

class AdviceCard extends StatelessWidget {
  final InferredAdvice advice;

  const AdviceCard({
    super.key,
    required this.advice,
  });

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              const HeroIcon(HeroIcons.exclamationTriangle),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      advice.type.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      advice.type.description,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      advice.advice,
                    ),
                    const SizedBox(height: 10),
                    _renderAccountRow(
                      context,
                      title: "Problem Account",
                      accountRef: advice.from,
                    ),
                    _renderAccountRow(
                      context,
                      title: "Affected Account",
                      accountRef: advice.to,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderAccountRow(
    final BuildContext context, {
    required final String title,
    required final AccountRef accountRef,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton(
          child: Row(
            children: [
              Text(
                context.shortenValue(accountRef.account.name),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const HeroIcon(HeroIcons.arrowLongRight, size: 16),
            ],
          ),
          onPressed: () {
            context.push("/accounts/${accountRef.id}");
          },
        ),
      ],
    );
  }
}
