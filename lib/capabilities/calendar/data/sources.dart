import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:meetmind/capabilities/calendar/domain/calendar_domain.dart';
import 'package:meetmind/core/assistant/contracts.dart';
import 'package:meetmind/core/models.dart' as models;
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/hijri_date.dart'
    show hijriMonthsAr, hijriMonthsEn;
import 'package:shared_preferences/shared_preferences.dart';

/// يخزّن المواعيد على القرص بشكل دائم عبر shared_preferences.
class LocalEventRepository implements EventRepository {
  LocalEventRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'meetmind_events';

  List<CalendarEvent> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return _seed();
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _write(List<CalendarEvent> events) async {
    final encoded = jsonEncode(events.map(_toMap).toList());
    await _prefs.setString(_key, encoded);
  }

  @override
  Future<List<CalendarEvent>> all() async {
    final list = _read()..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  @override
  Future<List<CalendarEvent>> eventsFor(DateTime day) async {
    return _read()
        .where((e) =>
            e.start.year == day.year &&
            e.start.month == day.month &&
            e.start.day == day.day)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<void> add(CalendarEvent event) async {
    final events = _read()..add(event);
    await _write(events);
  }

  @override
  Future<void> remove(String id) async {
    final events = _read()..removeWhere((e) => e.id == id);
    await _write(events);
  }

  Map<String, dynamic> _toMap(CalendarEvent e) => {
        'id': e.id,
        'title': e.title,
        'start': e.start.toIso8601String(),
        'end': e.end.toIso8601String(),
        'location': e.location,
        'participants': e.participants,
        'isFocus': e.isFocus,
      };

  CalendarEvent _fromMap(Map<String, dynamic> m) => CalendarEvent(
        id: m['id'] as String,
        title: m['title'] as String,
        start: DateTime.parse(m['start'] as String),
        end: DateTime.parse(m['end'] as String),
        location: m['location'] as String?,
        participants: (m['participants'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        isFocus: m['isFocus'] as bool,
      );

  static List<CalendarEvent> _seed() {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return [
      CalendarEvent(
        id: 'seed-1',
        title: 'Focus block — deck prep',
        start: at(9, 0),
        end: at(10, 30),
        isFocus: true,
      ),
      CalendarEvent(
        id: 'seed-2',
        title: 'Board sync — Q3 review',
        start: at(11, 0),
        end: at(12, 0),
        location: 'KAFD',
        participants: const ['Sara', 'Omar'],
      ),
    ];
  }
}

/// Fixed placeholder prayer times (~Riyadh). يُستخدم كاحتياط.
class StubPrayerTimeProvider implements PrayerTimeProvider {
  static const Map<models.Prayer, List<int>> _clock = {
    models.Prayer.fajr: [4, 10],
    models.Prayer.dhuhr: [12, 31],
    models.Prayer.asr: [15, 54],
    models.Prayer.maghrib: [18, 58],
    models.Prayer.isha: [20, 28],
  };

  @override
  DateTime timeFor(models.Prayer prayer, DateTime day) {
    final t = _clock[prayer] ?? const [12, 0];
    return DateTime(day.year, day.month, day.day, t[0], t[1]);
  }
}

/// يحسب أوقات الصلاة الحقيقية فلكيًا (إحداثيات الرياض).
class AdhanPrayerTimeProvider implements PrayerTimeProvider {
  // إحداثيات الرياض
  static final Coordinates _riyadh = Coordinates(24.7136, 46.6753);

  @override
  DateTime timeFor(models.Prayer prayer, DateTime day) {
    final params = CalculationMethod.umm_al_qura.getParameters();
    final dateComponents = DateComponents(day.year, day.month, day.day);
    final times = PrayerTimes(_riyadh, dateComponents, params);

    final result = switch (prayer) {
      models.Prayer.fajr => times.fajr,
      models.Prayer.dhuhr => times.dhuhr,
      models.Prayer.asr => times.asr,
      models.Prayer.maghrib => times.maghrib,
      models.Prayer.isha => times.isha,
    };

    // نعيده بالتوقيت المحلي على نفس اليوم المطلوب.
    return DateTime(day.year, day.month, day.day, result.hour, result.minute);
  }
}

/// Deterministic on-device parser (Arabic + English).
class NaturalLanguageEventParser implements EventParser {
  NaturalLanguageEventParser(this.prayerTimes);

  final PrayerTimeProvider prayerTimes;
  static const Duration _defaultDuration = Duration(hours: 1);

  static const Map<String, int> _weekdayNames = {
    'sunday': 7, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
    'thursday': 4, 'friday': 5, 'saturday': 6,
    'الأحد': 7, 'الاثنين': 1, 'الإثنين': 1, 'الثلاثاء': 2,
    'الأربعاء': 3, 'الخميس': 4, 'الجمعة': 5, 'السبت': 6,
  };

  static const Map<String, models.Prayer> _prayerNames = {
    'fajr': models.Prayer.fajr, 'الفجر': models.Prayer.fajr,
    'dhuhr': models.Prayer.dhuhr, 'zuhr': models.Prayer.dhuhr,
    'الظهر': models.Prayer.dhuhr,
    'asr': models.Prayer.asr, 'العصر': models.Prayer.asr,
    'maghrib': models.Prayer.maghrib, 'المغرب': models.Prayer.maghrib,
    'isha': models.Prayer.isha, 'العشاء': models.Prayer.isha,
  };

  // كلمات تقطع عبارة "مع/with" — تمنع التقاطها كأسماء مشاركين.
  static const List<String> _clauseBoundaryWords = [
    'at', 'on', 'after', 'tomorrow', 'today', 'tonight',
    'غدا', 'بكرة', 'اليوم', 'الليلة', 'يوم', 'بعد', 'الساعة', 'الساعه',
  ];

  // كلمات شائعة بعد with/مع مالها علاقة بأسماء أشخاص فعلية.
  static const Set<String> _participantStopWords = {
    'the', 'a', 'an', 'no', 'some', 'our', 'my', 'their', 'his', 'her',
    'everyone', 'everybody', 'anyone', 'anybody', 'team', 'و',
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

  @override
  Future<CaptureDraft?> parse(String text, {DateTime? now}) async {
    final base = now ?? DateTime.now();
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final low = raw.toLowerCase();
    final flags = <EventField>{};

    final participants = _participants(raw);
    final day = _day(low, base, flags);
    final start = _start(low, day, flags);
    final end = start.add(_defaultDuration);
    final title = _title(raw, participants, flags);

    return CaptureDraft(
      title: title,
      start: start,
      end: end,
      participants: participants,
      sourceText: raw,
      lowConfidence: flags,
    );
  }

  List<String> _participants(String raw) {
    final boundary = {
      ..._clauseBoundaryWords,
      ..._weekdayNames.keys,
      ..._prayerNames.keys,
    }.map(RegExp.escape).join('|');

    // ملاحظة: \b غير موثوق مع الحروف العربية في Dart RegExp (يعتمد على
    // \w اللي يغطي فقط a-z0-9_)، فنتحقق يدويًا إن الكلمة انتهت بمسافة/نهاية.
    final match = RegExp(
      '(?:with|مع)\\s+(.+?)(?=\\s+(?:$boundary)(?:\\s|\$|[.,،])|[.,،]|\$)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return const [];
    final clause = match.group(1)!.trim();
    if (clause.isEmpty) return const [];

    return clause
        .split(RegExp(r'\s*,\s*|\s*،\s*|\s+and\s+|\s+', caseSensitive: false))
        .map(_stripArabicConjunction)
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .where((n) => !_participantStopWords.contains(n.toLowerCase()))
        .toList();
  }

  String _stripArabicConjunction(String word) {
    // "وعمر" = "و" (and) ملتصقة بالاسم "عمر" — نفصلها.
    if (word.length > 1 && word.startsWith('و')) {
      return word.substring(1);
    }
    return word;
  }

  DateTime _day(String low, DateTime base, Set<EventField> flags) {
    final today = DateTime(base.year, base.month, base.day);
    if (RegExp(r'tomorrow|غدا|بكرة').hasMatch(low)) {
      return today.add(const Duration(days: 1));
    }
    if (RegExp(r'today|tonight|اليوم|الليلة').hasMatch(low)) {
      return today;
    }
    final weekday = _weekday(low);
    if (weekday != null) return _nextWeekday(today, weekday);

    final gregorian = _monthNameDate(low, today, _gregorianMonthNames);
    if (gregorian != null) {
      return _resolveYear(today, (year) => DateTime(year, gregorian.$1, gregorian.$2));
    }

    final hijri = _monthNameDate(low, today, _hijriMonthNames);
    if (hijri != null) {
      final baseYear = HijriCalendar.fromDate(today).hYear;
      return _resolveYear(
          today, (year) => HijriCalendar().hijriToGregorian(year, hijri.$1, hijri.$2),
          startYear: baseYear);
    }

    final numeric = _numericDate(low);
    if (numeric != null) {
      return _resolveYear(today, (year) => DateTime(year, numeric.$1, numeric.$2));
    }

    flags.add(EventField.date);
    return today;
  }

  int? _weekday(String low) {
    for (final entry in _weekdayNames.entries) {
      if (low.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// يفتش عن "يوم شهر" أو "شهر يوم" (بأي من قوائم الأشهر المُمرّرة —
  /// ميلادية أو هجرية) ويرجع (شهر، يوم). ما يفترض السنة، تُحسم لاحقًا.
  (int, int)? _monthNameDate(
      String low, DateTime today, Map<String, int> monthNames) {
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
  (int, int)? _numericDate(String low) {
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
  DateTime _resolveYear(DateTime today, DateTime Function(int year) build,
      {int? startYear}) {
    final year = startYear ?? today.year;
    var candidate = build(year);
    if (candidate.isBefore(today)) {
      candidate = build(year + 1);
    }
    return candidate;
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var d = from.add(const Duration(days: 1));
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  DateTime _start(String low, DateTime day, Set<EventField> flags) {
    final prayer = _prayer(low);
    if (prayer != null) return prayerTimes.timeFor(prayer, day);

    final clock = _clock(low);
    if (clock != null) {
      return DateTime(day.year, day.month, day.day, clock[0], clock[1]);
    }

    flags.add(EventField.time);
    return DateTime(day.year, day.month, day.day, 9, 0);
  }

  models.Prayer? _prayer(String low) {
    for (final entry in _prayerNames.entries) {
      if (low.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<int>? _clock(String low) {
    final match = RegExp(r'(?:at|الساعة|الساعه)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?')
        .firstMatch(low);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
    final ampm = match.group(3) ?? _arabicPeriod(low);
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return [hour, minute];
  }

  /// يفهم "مساءً/مساء" و"صباحًا/صباح" كمعادل عربي لـ pm/am.
  String? _arabicPeriod(String low) {
    if (RegExp(r'مساء').hasMatch(low)) return 'pm';
    if (RegExp(r'صباح').hasMatch(low)) return 'am';
    return null;
  }

  String _title(String raw, List<String> people, Set<EventField> flags) {
    if (people.isNotEmpty) {
      return raw.contains('مع')
          ? 'اجتماع مع ${people.join('، ')}'
          : 'Meeting with ${people.join(', ')}';
    }
    flags.add(EventField.title);
    return raw[0].toUpperCase() + raw.substring(1);
  }
}