import 'package:flutter/material.dart';

const List<Color> accentColors = [
  Color(0xFFFAE194),
  Color(0xFFF9DDC4),
  Color(0xFFD3EE92),
  Color(0xFFF9D9E3),
  Color(0xFFF9D9E3),
  Color(0xFFE6DEF6),
  Color(0xFFE8DDFC),
];

extension InterfaceUtilities on BuildContext {
  Color getAccentColorFor(final String value) =>
      accentColors[identityHashCode(value) % accentColors.length];

  String getInitialsFor(final String value) {
    return RegExp(r'(^[A-Za-z]|(?<=\s)[A-Za-z])')
        .allMatches(value)
        .take(2)
        .map((final match) => match.group(1))
        .join('');
  }

  String shortenValue(final String name, {final int length = 10}) =>
      name.length >= length && name.length > 3
          ? "${name.substring(0, length - 3)}..."
          : name;
}

extension ThemeContextExtensions on BuildContext {
  ColorScheme get colorScheme {
    return Theme.of(this).colorScheme;
  }
}
