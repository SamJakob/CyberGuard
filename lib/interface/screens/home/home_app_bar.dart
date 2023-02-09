import 'dart:math';

import 'package:flutter/material.dart';

class CGHomeAppBar extends StatelessWidget {
  @override
  Widget build(final BuildContext context) {
    return SliverPersistentHeader(
      delegate: _CGHomeSliverAppBar(
        expandedHeight: 400,
        collapsedHeight: MediaQuery.of(context).padding.top,
      ),
      pinned: true,
    );
  }
}

class _CGHomeSliverAppBar extends SliverPersistentHeaderDelegate {
  final double expandedHeight, collapsedHeight;

  const _CGHomeSliverAppBar({
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  @override
  double get maxExtent => max(expandedHeight, minExtent);

  @override
  double get minExtent => collapsedHeight + 90;

  double get maxShrinkOffset => maxExtent - minExtent;

  @override
  bool shouldRebuild(covariant final SliverPersistentHeaderDelegate oldDelegate) => true;

  @override
  Widget build(final BuildContext context, final double shrinkOffset, final bool overlapsContent) {
    double shrinkPercentage = (1 - (shrinkOffset / maxShrinkOffset)).clamp(0, 1);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          color: Theme.of(context).colorScheme.primary,
        )
      ],
    );
  }
}
