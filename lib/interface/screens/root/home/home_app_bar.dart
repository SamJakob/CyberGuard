import 'dart:math';
import 'dart:ui';

import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/interface/partials/app_word_mark.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';

class CGHomeAppBar extends StatelessWidget {
  final double expandedHeight;
  final List<Widget>? actions;
  final Widget? Function(double scrollPercentage)? childBuilder;

  const CGHomeAppBar({
    super.key,
    this.expandedHeight = 500,
    this.actions,
    this.childBuilder,
  });

  @override
  Widget build(final BuildContext context) {
    return SliverPersistentHeader(
      delegate: _CGHomeSliverAppBar(
        context,
        actions: actions,
        childBuilder: childBuilder,
        expandedHeight: expandedHeight,
        collapsedHeight: 90,
      ),
      pinned: true,
    );
  }
}

class _CGHomeSliverAppBar extends SliverPersistentHeaderDelegate {
  final double expandedHeight, collapsedHeight;
  final EdgeInsets padding;

  final List<Widget>? actions;
  final Widget? Function(double scrollPercentage)? childBuilder;

  _CGHomeSliverAppBar(
    final BuildContext context, {
    this.actions,
    this.childBuilder,
    required this.expandedHeight,
    required this.collapsedHeight,
  }) : padding = MediaQuery.of(context).padding;

  @override
  double get maxExtent => max(expandedHeight, minExtent);

  @override
  double get minExtent => padding.top + collapsedHeight;

  double get maxShrinkOffset => maxExtent - minExtent;

  @override
  bool shouldRebuild(
          covariant final SliverPersistentHeaderDelegate oldDelegate) =>
      oldDelegate.maxExtent != maxExtent || oldDelegate.minExtent != minExtent;

  @override
  Widget build(final BuildContext context, final double shrinkOffset,
      final bool overlapsContent) {
    const double curveStartFraction = 0.9;
    const double hideChildrenFraction = 0.6;

    final double scrollPercentage =
        (shrinkOffset / maxShrinkOffset).clamp(0, 1);

    final Widget? child =
        (childBuilder != null) ? childBuilder!(scrollPercentage) : null;

    return SizedBox(
      height:
          (((maxExtent - minExtent) * (1 - scrollPercentage)) + minExtent) + 1,
      child: ClipPath(
        clipper: scrollPercentage == 1
            ? null
            : _CGHomeSliverAppBarClipper(
                curveStartFraction: curveStartFraction,
                scrollPercentage: scrollPercentage,
              ),
        child: Container(
          padding: EdgeInsets.only(
              bottom: (maxExtent * (1 - curveStartFraction)) *
                  (1 - scrollPercentage)),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: SafeArea(
            top: true,
            left: true,
            right: true,
            bottom: false,
            child: Stack(
              children: [
                SizedBox(
                  height: collapsedHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpaceUnitPx * 1.5),
                    child: IconTheme(
                      data: Theme.of(context).iconTheme.copyWith(
                            color: context.colorScheme.onPrimaryContainer,
                          ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const CGAppWordmark(),
                          if (actions != null) ...[
                            const Spacer(),
                            ...actions!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: scrollPercentage <= hideChildrenFraction,
                  child: AnimatedOpacity(
                    opacity: 1 -
                        (scrollPercentage * (1 / hideChildrenFraction))
                            .clamp(0, 1),
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: collapsedHeight * 0.5),
                        if (child != null) child,
                      ],
                    ),
                  ),
                ),
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
    final curveStart =
        size.height * lerpDouble(curveStartFraction, 1.0, scrollPercentage)!;

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
  bool shouldReclip(covariant final CustomClipper<Path> oldClipper) =>
      oldClipper != this;
}
