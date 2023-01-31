import 'package:cyberguard/app.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  runApp(
    // Top-level widget to store the state of each of the providers.
    // The entire application (CGApp) is wrapped to allow any widget to access this state.
    const ProviderScope(child: CGApp()),
  );
}
