// BRANDING CONSTANTS.

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

const String kAppName = "CyberGuard";

const Color kAppThemeColor = Color(0xFF8E61F0);
const Color kAppSecondaryColor = Color(0xFF8A6ECE);

// Pre-generated color scheme based on the above.

const FlexSchemeData kAppColorScheme = FlexSchemeData(
  name: kAppName,
  description: 'The default theme for $kAppName.',
  light: FlexSchemeColor(
    primary: kAppThemeColor,
    secondary: kAppSecondaryColor,
  ),
  dark: FlexSchemeColor(
    primary: kAppThemeColor,
    secondary: kAppSecondaryColor,
  ),
);
