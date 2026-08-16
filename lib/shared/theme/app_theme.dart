import 'package:flutter/material.dart';

/// Material 3 theme seeded from the MeetMind purple. Expands into a full
/// token set as the design-system deliverable lands.
class MeetMindTheme {
  static const _seed = Color(0xFF534AB7);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
