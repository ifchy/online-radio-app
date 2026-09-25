import 'package:flutter/material.dart';

import 'home_screen.dart';

/// The app root. Plan 01-03 adds the localisation delegates (D-08).
class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eRadioto',
      theme: ThemeData(),
      home: const HomeScreen(),
    );
  }
}
