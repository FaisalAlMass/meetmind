import 'package:hijri/hijri_calendar.dart';
import 'package:meetmind/shared/localization/hijri_date.dart'
    show hijriMonthsAr, hijriMonthsEn;

/// يفتش عن مرجع تاريخ داخل نص حر — نسبي (بكرة/اليوم/اسم يوم) أو مطلق
/// (ميلادي أو هجري، بالاسم أو بالأرقام). يرجع null لو ما لقى شي.
///
/// يستخدمه كل من parser الالتقاط اللغوي (data/sources.dart) وشاشة البحث،
/// حتى ما تنكرر نفس منطق فهم التاريخ بمكانين.
class DateReferenceParser {
  const DateReferenceParser._();

  static const Map<String, int> _weekdayNames = {
    'sunday': 7, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
    'thursday': 4, 'friday': 5, 'saturday': 6,
    'الأحد': 7, 'الاثنين': 1, 'الإثنين': 1, 'الثلاثاء': 2,
    'الأربعاء': 3, 'الخميس': 4, 'الجمعة': 5, 'السبت': 6,
  };

  static const Map<String, int> _gregorianMonthNames = {
    'jan': 1, 'january': 1, 'يناير': 1,
    'feb': 2, 'february': 2, 'فبراير': 2,
    'mar': 3, 'march': 3, 'مارس': 3,
    'apr': 4, 'april': 4, 'ابريل': 4, 'أبريل': 4,
    'may': 5, 'مايو': 5,
    'jun': 6, 'june': 6, 'يونيو': 6,
    'jul': 7, 'july': 7, 'يوليو': 7,
    'aug': 8, 'august': 8, 'اغسطس': 8, 'أغسطس': 8,
    'sep': 9, 'sept': 9, 'september': 9, 'سبتمبر': 9,
    'oct': 10, 'october': 10, 'اكتوبر': 10, 'أكتوبر': 10,
    'nov': 11, 'november': 11, 'نوفمبر': 11,
    'dec': 12, 'december': 12, 'ديسمبر': 12,
  };

  // مبنية من نفس أسماء الأشهر الهجرية المستخدمة في عرض التاريخ، حتى ما
  // تنحفظ قائمتين منفصلتين ممكن يختلفوا مع بعض بالمستقبل.
  static final Map<String, int> _hijriMonthNames = {
    for (var i = 0; i < hijriMonthsAr.length; i++) hijriMonthsAr[i]: i + 1,
    for (var i = 0; i < hijriMonthsEn.length; i++)
      hijriMonthsEn[i].toLowerCase(): i + 1,
  };

  /// يحاول يفهم مرجع تاريخ داخل [rawText] بالنسبة لـ [today]. يرجع null
  /// لو ما لقى أي مرجع تاريخ صريح.
  static DateTime? tryParse(String rawText, DateTime today) {
    final low = rawText.toLowerCase();

    // لازم نفحصها قبل "غدا/بكرة" المجردة — وإلا "بعد بكرة" تنقرأ غلط
    // كـ"بكرة" العادية بسبب المطابقة الجزئية (substring) بالأسفل.
    if (RegExp(r'day after tomorrow|بعد بكرة|بعد غدا').hasMatch(low)) {
      return today.add(const Duration(days: 2));
    }
    if (RegExp(r'tomorrow|غدا|بكرة').hasMatch(low)) {
      return today.add(const Duration(days: 1));
    }
    if (RegExp(r'today|tonight|اليوم|الليلة').hasMatch(low)) {
      return today;
    }
    final weekday = _weekday(low);
    if (weekday != null) return _nextWeekday(today, weekday);

    final gregorian = _monthNameDate(low, _gregorianMonthNames);
    if (gregorian != null) {
      return _resolveYear(
          today, (year) => DateTime(year, gregorian.$1, gregorian.$2));
    }

    final hijri = _monthNameDate(low, _hijriMonthNames);
    if (hijri != null) {
      final baseYear = HijriCalendar.fromDate(today).hYear;
      return _resolveYear(
          today, (year) => HijriCalendar().hijriToGregorian(year, hijri.$1, hijri.$2),
          startYear: baseYear);
    }

    final numeric = _numericDate(low);
    if (numeric != null) {
      return _resolveYear(
          today, (year) => DateTime(year, numeric.$1, numeric.$2));
    }

    return null;
  }

  static int? _weekday(String low) {
    for (final entry in _weekdayNames.entries) {
      if (low.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static DateTime _nextWeekday(DateTime from, int weekday) {
    var d = from.add(const Duration(days: 1));
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// يفتش عن "يوم شهر" أو "شهر يوم" (بأي من قوائم الأشهر المُمرّرة —
  /// ميلادية أو هجرية) ويرجع (شهر، يوم). ما يفترض السنة، تُحسم لاحقًا.
  static (int, int)? _monthNameDate(String low, Map<String, int> monthNames) {
    final names = monthNames.keys.map(RegExp.escape).join('|');
    // بدون \b (غير موثوق مع العربي) — الفاصل \s+ نفسه كافٍ كحد فاصل.
    final match = RegExp(
      '(?:(\\d{1,2})\\s+($names)|($names)\\s+(\\d{1,2}))(?!\\d)',
      caseSensitive: false,
    ).firstMatch(low);
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? match.group(4) ?? '');
    final monthKey = (match.group(2) ?? match.group(3))?.toLowerCase();
    final month = monthKey == null ? null : monthNames[monthKey];
    if (day == null || month == null || day < 1 || day > 30) return null;
    return (month, day);
  }

  /// صيغة رقمية "يوم/شهر" أو "يوم-شهر" — نفترض ميلادي (الأشيع بدون قرينة).
  static (int, int)? _numericDate(String low) {
    final match = RegExp(r'(\d{1,2})[/-](\d{1,2})(?!\d)').firstMatch(low);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (day == null || month == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    return (month, day);
  }

  /// يبني تاريخ من (سنة, شهر, يوم) — يبدأ من سنة اليوم الحالي، ولو طلعت
  /// النتيجة بالماضي يزيد سنة (المستخدم غالبًا يقصد التاريخ الجاي).
  static DateTime _resolveYear(DateTime today, DateTime Function(int year) build,
      {int? startYear}) {
    final year = startYear ?? today.year;
    var candidate = build(year);
    if (candidate.isBefore(today)) {
      candidate = build(year + 1);
    }
    return candidate;
  }
}
