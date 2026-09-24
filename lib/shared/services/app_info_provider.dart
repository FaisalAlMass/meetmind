import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// نسخة التطبيق الفعلية من pubspec.yaml وقت البناء — بدل رقم ثابت
/// بالكود يحتاج تحديث يدوي منفصل كل مرة يترفع فيها الإصدار.
final packageInfoProvider =
    FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
