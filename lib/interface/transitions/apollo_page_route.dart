import 'package:flutter/material.dart';

///
/// This route transition currently mirrors that of Android Q's
/// 'Material Design 2' page transition. (An expand-fade effect)
///
class ApolloPageRoute<T> extends PageRouteBuilder<T> {
  bool? isFullscreenDialog;

  @override
  bool get fullscreenDialog => isFullscreenDialog ?? false;

  bool isOpaque;

  @override
  bool get opaque => isOpaque;

  Curve get animationCurve => Curves.easeInOut;

  ApolloPageRoute({
    required final WidgetBuilder builder,
    final RouteSettings? settings,
    this.isFullscreenDialog,
    this.isOpaque = true,
  }) : super(
          pageBuilder: (final BuildContext context,
                  final Animation<double> animation,
                  final Animation<double> secondaryAnimation) =>
              builder(context),
          settings: settings,
          transitionDuration: const Duration(milliseconds: 200),
          opaque: isOpaque,
        );

  @override
  Widget buildTransitions(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.90, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: animationCurve,
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Interval(
            0.2,
            0.9,
            curve: animationCurve,
          ),
        ),
        child: buildSecondaryTransitions(
            context, animation, secondaryAnimation, child),
      ),
    );
  }

  Widget buildSecondaryTransitions(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.04).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: animationCurve,
      )),
      child: child,
    );
  }
}
