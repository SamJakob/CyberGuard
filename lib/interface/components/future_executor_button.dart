import 'package:cyberguard/interface/components/apollo_loading_spinner.dart';
import 'package:flutter/material.dart';

class FutureExecutorButton extends StatefulWidget {
  final Widget icon;
  final Widget label;
  final Color color;
  final Color? foregroundColor;
  final Future<void> Function() onPressed;

  const FutureExecutorButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.foregroundColor,
  });

  @override
  State<FutureExecutorButton> createState() => _FutureExecutorButtonState();
}

class _FutureExecutorButtonState extends State<FutureExecutorButton> {
  bool _isLoading = false;
  set isLoading(final bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    if (_isLoading) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: widget.color.withOpacity(0.6),
          disabledForegroundColor: Colors.white,
        ),
        onPressed: null,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ApolloLoadingSpinner(
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 12),
            Text("Loading..."),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.black,
      ),
      onPressed: () async {
        isLoading = true;
        await widget.onPressed();
        isLoading = false;
      },
      icon: widget.icon,
      label: widget.label,
    );
  }
}
