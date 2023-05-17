import 'package:cyberguard/domain/providers/settings.dart';
import 'package:cyberguard/domain/services/inference.dart';
import 'package:cyberguard/interface/utility/snackbars.dart';
import 'package:cyberguard/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@immutable
class InferenceProviderData {
  final List<InferredAdvice> advice;
  final InferenceGraph graph;

  const InferenceProviderData({
    required this.advice,
    required this.graph,
  });
}

class InferenceProvider extends StateNotifier<InferenceProviderData?> {
  InferenceProvider() : super(null);

  bool get hasData => state != null;
  bool get hasAdvice => hasData && state!.advice.isNotEmpty;

  void setData(final InferenceProviderData? data) {
    state = data;
  }

  /// Triggers an inference scan of the account setup. If [context] is
  /// specified, a Snackbar will be shown with the results.
  void triggerScan(
    final WidgetRef ref, {
    final BuildContext? context,
  }) {
    if (!ref.read(settingsProvider).enableAnalysis) {
      state = null;
      return;
    }

    try {
      // For now just run the inference service immediately.
      // Later, the data could be snapshotted and passed to the
      // inference service to run in an isolate.
      final InferenceService inferenceService = locator.get<InferenceService>();
      final graph = inferenceService.run();
      final result = inferenceService.interpret(graph);

      state = InferenceProviderData(
        graph: graph,
        advice: result,
      );

      if (context != null) {
        context.showInfoSnackbar(
          message: "Scan complete. You can see the results on the home page.",
        );
      }
    } catch (_) {}
  }
}

final inferenceProvider =
    StateNotifierProvider<InferenceProvider, InferenceProviderData?>(
  (final ref) => throw TypeError(),
);
