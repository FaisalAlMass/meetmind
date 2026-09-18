import 'package:flutter/material.dart';

/// ثيم Material 3 مبني على ألوان الهوية المعتمدة (أخضر أساسي، ذهبي
/// وزمردي ثانويين)، وخط Tajawal العربي.
///
/// الأخضر يُستخدم كـ seed — يشتق منه Material تلقائيًا درجات الأساسي/
/// السطح/الخطأ المتناسقة والمضمونة التباين. الذهبي والزمردي (وحاوياتهما)
/// محقونة مباشرة بقيمها المعتمدة بالضبط، مع ألوان نص مُتحقق من تباينها
/// (WCAG AA) يدويًا عشان تبقى مقروءة فوقها.
class MeetMindTheme {
  static const _seed = Color(0xFF28924F); // أخضر الهوية
  static const _fontFamily = 'Tajawal';

  // الألوان الرئيسية والثانوية المعتمدة
  static const _charcoal = Color(0xFF373435);
  static const _gold = Color(0xFFCCA53B);
  static const _beige = Color(0xFFEBDBB1);
  static const _emerald = Color(0xFF00B48C);
  static const _darkTeal = Color(0xFF00624D);

  // مشتقّات محسوبة (تدرّج نحو الأبيض/الأسود) للحاويات اللي ما عندها
  // مقابل مباشر بلوحة الهوية — تباينها محقّق يدويًا.
  static const _tertiaryContainerLight = Color(0xFFC7EEE6);
  static const _secondaryContainerDark = Color(0xFF473A15);
  static const _tertiaryContainerDark = Color(0xFF003F31);
  static const _onTertiaryContainerDark = Color(0xFFBFECE2);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          secondary: _gold,
          onSecondary: _charcoal,
          secondaryContainer: _beige,
          onSecondaryContainer: _charcoal,
          tertiary: _emerald,
          onTertiary: _charcoal,
          tertiaryContainer: _tertiaryContainerLight,
          onTertiaryContainer: _darkTeal,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
          secondary: _gold,
          onSecondary: _charcoal,
          secondaryContainer: _secondaryContainerDark,
          onSecondaryContainer: _beige,
          tertiary: _emerald,
          onTertiary: _charcoal,
          tertiaryContainer: _tertiaryContainerDark,
          onTertiaryContainer: _onTertiaryContainerDark,
        ),
      );
}
