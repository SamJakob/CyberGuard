import 'package:cyberguard/domain/services/inference.dart';
import 'package:flutter/foundation.dart';
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
}

final inferenceProvider =
    StateNotifierProvider<InferenceProvider, InferenceProviderData?>(
  (final ref) => throw TypeError(),
);
