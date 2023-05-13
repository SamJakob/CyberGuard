import 'package:cyberguard/app.dart';
import 'package:flutter/material.dart';

import 'locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocatorEarly();

  runApp(
    const CGApp(),
  );
}
