import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:meetmind/capabilities/calendar/domain/calendar_domain.dart';
import 'package:meetmind/capabilities/calendar/domain/date_reference_parser.dart';
import 'package:meetmind/core/assistant/contracts.dart';
import 'package:meetmind/core/models.dart' as models;
import 'package:meetmind/core/models.dart';
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
    final found = DateReferenceParser.tryParse(low, today);
    if (found != null) return found;

    flags.add(EventField.date);
    return today;
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