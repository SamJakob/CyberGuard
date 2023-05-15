import 'dart:ui';

import 'package:cyberguard/const/interface.dart';
import 'package:cyberguard/interface/partials/app_word_mark.dart';
import 'package:cyberguard/interface/utility/interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

class RootAppBar extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double collapsedHeight;
  final double expandedHeight;
  final Widget? bottomWidget;
  final double bottomWidgetSize;
  final bool autoPadBottomWidget;
  final bool forceShrink;
  final bool hideAppBadge;

  RootAppBar({
    final Key? key,
    required this.title,
    this.subtitle,
    this.collapsedHeight = 64,
    final double expandedHeight = 200,
    this.bottomWidget,
    final double? bottomWidgetSize,
    this.autoPadBottomWidget = false,
    this.forceShrink = false,
    this.hideAppBadge = false,
  })  : assert(bottomWidget != null ? bottomWidgetSize != null : true,
            "If the bottomWidget is present, its size must be set."),
        bottomWidgetSize = bottomWidget != null ? bottomWidgetSize! : 0,
        expandedHeight = forceShrink
            ? collapsedHeight
            : expandedHeight +
                (bottomWidget != null ? bottomWidgetSize ?? 0 : 0),
        super(key: key);

  @override
  State<RootAppBar> createState() => _RootAppBarState();
}

class _RootAppBarState extends State<RootAppBar> {
  final shrinkController =
      _RootAppBarShrinkController(initialScrollProgress: 1.0);

  @override
  void initState() {
    shrinkController.addListener(() {
      if (mounted) setState(() {});
    });

    super.initState();
  }

  @override
  Widget build(final BuildContext context) {
    final titleStyle = TextStyle(
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 24,
    );

    return SliverAppBar.large(
      pinned: true,
      centerTitle: false,
      elevation: 3,
      foregroundColor: context.colorScheme.onPrimaryContainer,
      collapsedHeight: widget.collapsedHeight,
      expandedHeight: widget.expandedHeight,
      flexibleSpace: Container(
        color: context.colorScheme.primaryContainer,
        child: SafeArea(
          top: true,
          child: LayoutBuilder(
            builder: (final context, final constraints) {
              final double scrollProgress = (() {
                // Special case: if we want to force a shrink, we should return a value indicating the scroll progress
                // is 1.0 (e.g., for a search query).
                if (widget.forceShrink) return 0.0;

                // Otherwise, render scroll percentage as a function of the difference between collapsed and expanded
                // heights.
                return ((constraints.maxHeight -
                            widget.collapsedHeight -
                            (widget.bottomWidgetSize)) /
                        (widget.expandedHeight -
                            widget.collapsedHeight -
                            (widget.bottomWidgetSize)))
                    .clamp(0.0, 1.0);
              })();

              SchedulerBinding.instance.addPostFrameCallback((final _) {
                shrinkController.scrollProgress = scrollProgress;
              });

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!widget.hideAppBadge)
                    Positioned(
                      top: (kSpaceUnitPx * 1.5) + 1,
                      left: kSpaceUnitPx * 1.5,
                      child: FadeTransition(
                        opacity: AlwaysStoppedAnimation<double>(
                          const Interval(0.7, 1.0).transform(scrollProgress),
                        ),
                        child: const CGAppWordmark(),
                      ),
                    ),
                  FadeTransition(
                    opacity: AlwaysStoppedAnimation<double>(
                      const Interval(0.0, 0.8).transform(scrollProgress),
                    ),
                    child: Transform.scale(
                      alignment: Alignment.bottomLeft,
                      scale: shrinkController.scaleFactor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: AnimatedContainer(
                                curve: Curves.easeInOut,
                                duration: const Duration(milliseconds: 10),
                                padding: const EdgeInsets.symmetric(
                                        horizontal: kSpaceUnitPx * 1.5)
                                    .copyWith(
                                  bottom: (kSpaceUnitPx +
                                          widget.bottomWidgetSize *
                                              1 /
                                              shrinkController.scaleFactor) *
                                      0.85,
                                ),
                                child: widget.subtitle != null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.title,
                                            style: titleStyle.copyWith(
                                              fontSize: 24,
                                            ),
                                          ),
                                          Text(
                                            widget.subtitle!,
                                            style: titleStyle.copyWith(
                                              height: 1,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        widget.title,
                                        style:
                                            titleStyle.copyWith(fontSize: 24),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: AlwaysStoppedAnimation<double>(
                        const Interval(0.8, 1.0).transform(1 - scrollProgress)),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        height: widget.collapsedHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: kSpaceUnitPx * 1.5),
                            child: Text(widget.title, style: titleStyle),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            context.push('/settings');
          },
          icon: const HeroIcon(HeroIcons.cog, size: 32),
        ),
        const SizedBox(width: kSpaceUnitPx * 1.5)
      ],
      bottom: widget.bottomWidget != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(widget.bottomWidgetSize),
              child: SizedBox(
                height: widget.bottomWidgetSize,
                width: double.infinity,
                child: AnimatedContainer(
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 10),
                  padding: (widget.autoPadBottomWidget
                          ? EdgeInsets.symmetric(
                              horizontal: kSpaceUnitPx *
                                  1.5 *
                                  shrinkController.scaleFactor)
                          : EdgeInsets.zero)
                      .copyWith(
                          bottom:
                              kSpaceUnitPx * (shrinkController.scrollProgress)),
                  child: widget.bottomWidget!,
                ),
              ),
            )
          : null,
    );
  }
}

class _RootAppBarShrinkController extends ValueNotifier<double> {
  _RootAppBarShrinkController({
    required final double initialScrollProgress,
  }) : super(initialScrollProgress);

  double get scrollProgress => value;
  double get scaleFactor => lerpDouble(1.0, 1.5, scrollProgress) ?? 1.0;

  set scrollProgress(final double scrollProgress) {
    if (value == scrollProgress) return;
    value = scrollProgress;
    notifyListeners();
  }
}
