import 'package:flutter/material.dart';

/// Material 3 theme seeded من أخضر بأسلوب الخدمات الحكومية السعودية،
/// وخط Tajawal العربي.
class MeetMindTheme {
  static const _seed = Color(0xFF00A651);
  static const _fontFamily = 'Tajawal';

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
