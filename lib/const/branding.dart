// BRANDING CONSTANTS.

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// The name of the application.
const String kAppName = "CyberGuard";

/// A link to the source code of the application.
/// Set to null to hide the link.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kAppSourceUrl = "https://github.com/SamJakob/CyberGuard";

/// The marketing URL of the application.
const String kAppUrl = "https://github.com/SamJakob/CyberGuard";

/// The legal information/disclaimer (displayed in Settings).
const String kAppLegalese = """
CyberGuard is an account manager that stores and provides insight into your account setup.

Copyright (c) 2023 - Sam Jakob M.

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"""
    """IMPLIED. WE PROVIDE NO WARRANTY IN RESPECT OF THE SECURITY OR FUNCTIONALITY OF"""
    """THIS SOFTWARE. YOU BEAR THE SOLE RISK OF USING THIS SOFTWARE. IN NO EVENT SHALL"""
    """WE BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY ARISING FROM, OUT OF OR"""
    """IN CONNECTION WITH THIS SOFTWARE.""";

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
