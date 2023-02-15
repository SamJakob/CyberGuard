import 'package:flutter/material.dart';

extension ThemeContextExtensions on BuildContext {
  ColorScheme get colorScheme {
    return Theme.of(this).colorScheme;
  }
}
