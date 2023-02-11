import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class CGHomeAppBar extends StatelessWidget {
  final double expandedHeight;
  final Widget? Function(double scrollPercentage)? childBuilder;

  const CGHomeAppBar({
    super.key,
    this.expandedHeight = 500,
    this.childBuilder,
  });

  @override
  Widget build(final BuildContext context) {
    return SliverPersistentHeader(
      delegate: _CGHomeSliverAppBar(
        host: this,
        expandedHeight: expandedHeight,
        collapsedHeight: MediaQuery.of(context).padding.top,
      ),
      pinned: true,
    );
  }
}

class _CGHomeSliverAppBar extends SliverPersistentHeaderDelegate {
  final CGHomeAppBar host;
  final double expandedHeight, collapsedHeight;

  const _CGHomeSliverAppBar({
    required this.host,
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  @override
  double get maxExtent => max(expandedHeight, minExtent);

  @override
  double get minExtent => collapsedHeight + 90;

  double get maxShrinkOffset => maxExtent - minExtent;

  @override
  bool shouldRebuild(covariant final SliverPersistentHeaderDelegate oldDelegate) => oldDelegate.maxExtent != maxExtent || oldDelegate.minExtent != minExtent;

  @override
  Widget build(final BuildContext context, final double shrinkOffset, final bool overlapsContent) {
    const double curveStartFraction = 0.9;
    final double scrollPercentage = (shrinkOffset / maxShrinkOffset).clamp(0, 1);

    final Widget? child = (host.childBuilder != null) ? host.childBuilder!(scrollPercentage) : null;

    return SizedBox(
      height: (((maxExtent - minExtent) * (1 - scrollPercentage)) + minExtent) + 1,
      child: ClipPath(
        clipper: _CGHomeSliverAppBarClipper(curveStartFraction: curveStartFraction, scrollPercentage: scrollPercentage),
        child: Container(
          padding: EdgeInsets.only(bottom: (maxExtent * (1 - curveStartFraction)) * (1 - scrollPercentage)),
          color: Theme.of(context).colorScheme.primary,
          child: SafeArea(
            top: true,
            left: true,
            right: true,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back!",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (child != null) child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CGHomeSliverAppBarClipper extends CustomClipper<Path> {
  /// The fraction that the curved part of the app bar should start at. For
  /// example, if this is set to 90%, the apex of the curve will be between 90%
  /// of the height and 100% of the height - in other words, the curve will
  /// only be rendered from this fraction of the height to the bottom of the
  /// app bar.
  final double curveStartFraction;

  /// The percentage of how 'complete' the scroll is between the initial state
  /// and the state where the AppBarClipper should cause a flat line (i.e., a
  /// 'traditional' app bar).
  final double scrollPercentage;
  _CGHomeSliverAppBarClipper({
    this.curveStartFraction = 0.9,
    required this.scrollPercentage,
  });

  @override
  Path getClip(final Size size) {
    final curveStart = size.height * lerpDouble(curveStartFraction, 1.0, scrollPercentage)!;

    final path = Path();
    path.lineTo(0.0, curveStart);

    final midpoint = Offset(size.width / 2, size.height);
    final endpoint = Offset(size.width, curveStart);

    path.quadraticBezierTo(midpoint.dx, midpoint.dy, endpoint.dx, endpoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant final CustomClipper<Path> oldClipper) => oldClipper != this;
}
