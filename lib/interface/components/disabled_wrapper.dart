import 'package:flutter/cupertino.dart';

class DisabledWrapper extends StatelessWidget {
  /// Whether this wrapper should cause the wrapped widget to be disabled.
  final bool disabled;

  /// The child (wrapped) widget.
  final Widget child;

  const DisabledWrapper({
    super.key,
    required this.disabled,
    required this.child,
  });

  @override
  Widget build(final BuildContext context) {
    return IgnorePointer(
      ignoring: disabled,
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }
}
