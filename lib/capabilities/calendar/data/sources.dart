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

  /// true لو فيه مواعيد محفوظة فعليًا من قبل — بعكس all()، ما يرجع true
  /// لبيانات العرض الافتراضية (seed) لو ما فيه شي محفوظ أصلًا.
  bool get hasSavedEvents => _prefs.containsKey(_key);

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

  // كلمات تقطع عبارة "مع/with" أو "في/in" — تمنع التقاطها كأسماء
  // مشاركين أو جزء من اسم مكان. أضفنا كلمات "الموضوع" (لمناقشة/بخصوص/
  // موضوع/about/regarding) بعد ما لاحظنا إنها كانت تُبتلع كاملة داخل اسم
  // المكان أو المشاركين لما تجي بدون فاصلة قبلها، و"قبل" (بالتناظر مع
  // "بعد" الموجودة) بعد ملاحظة نفس المشكلة مع "قبل صلاة الجمعة".
  static const List<String> _clauseBoundaryWords = [
    'at', 'on', 'after', 'before', 'for', 'in', 'tomorrow', 'today',
    'tonight', 'yesterday', 'about', 'regarding', 'concerning',
    'غدا', 'بكرة', 'اليوم', 'الليلة', 'يوم', 'بعد', 'قبل', 'الساعة',
    'الساعه', 'لمدة', 'مدة', 'في', 'مع',
    'لمناقشة', 'بخصوص', 'موضوعه', 'موضوعها', 'موضوع', 'حول',
  ];

  // كلمات شائعة بعد with/مع مالها علاقة بأسماء أشخاص فعلية. أضفنا "and"
  // (تسرّب أحيانًا كمشارك وهمي مع قوائم فيها فاصلة أكسفورد: "A, B, and C")
  // وكلمات تعديل التاريخ ("this"/"next"/"القادم"/"الجاي") وكلمات التكرار
  // ("every"/"weekly") اللي كانت تُبتلع لو جت مباشرة قبل اسم يوم الأسبوع
  // بلا فاصل، و"around" (وقت تقريبي عامي: "around 3ish").
  static const Set<String> _participantStopWords = {
    'the', 'a', 'an', 'no', 'some', 'our', 'my', 'their', 'his', 'her',
    'everyone', 'everybody', 'anyone', 'anybody', 'team', 'and', 'this',
    'next', 'coming', 'day', 'days', 'every', 'weekly', 'daily', 'monthly',
    'yearly', 'around', 'و', 'القادم', 'القادمة', 'الجاي', 'الجايه',
  };

  // ألقاب/بادئات تلتصق باسم الشخص أو الجهة — لو فصلناها بالمسافة العادية
  // بنطلع بـ"مشاركين" وهميين (زي "الأستاذ" و"محمد" منفصلين بدل شخص وحد).
  // المطابقة غير حساسة لحالة الأحرف (يشمل الألقاب الإنجليزية المختصرة).
  static const Set<String> _nameTitlePrefixes = {
    'الأستاذ', 'الأستاذة', 'أستاذ', 'أستاذة',
    'الدكتور', 'الدكتورة', 'دكتور', 'دكتورة',
    'المهندس', 'المهندسة', 'مهندس', 'مهندسة',
    'الشيخ', 'الشيخة', 'شيخ', 'شيخة',
    'الرئيس', 'الرئيسة', 'المدير', 'المديرة', 'الوزير', 'الوزيرة',
    'أبو', 'ابو', 'أم', 'ام', 'أخي', 'أختي', 'ابني', 'ابنتي',
    'فريق', 'إدارة', 'ادارة', 'قسم', 'لجنة', 'شركة',
    'dr', 'mr', 'mrs', 'ms', 'prof', 'eng',
    // نسخ بلا نقطة من اختصارات _stripTitleAbbreviationPeriods ("أ."،
    // "د."، "م.") — تنحذف نقطتها قبل الوصول هنا، فلازم تُعرف بشكلها المجرد.
    'أ', 'د', 'م',
  };

  bool _isTitlePrefix(String token) =>
      _nameTitlePrefixes.contains(token) ||
      _nameTitlePrefixes.contains(token.toLowerCase());

  // لوحة المفاتيح العربية بالعادة تكتب أرقام هندية (٠-٩) مو غربية (0-9)،
  // و\d بالـ RegExp ما يتعرف إلا على الغربية — فنحوّلها قبل أي مطابقة.
  static const String _easternArabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String _normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final eastern = _easternArabicDigits.indexOf(ch);
      if (eastern != -1) {
        buffer.write(eastern);
        continue;
      }
      final persian = _persianDigits.indexOf(ch);
      if (persian != -1) {
        buffer.write(persian);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  // تشكيل عربي (فتحة/ضمة/كسرة/تنوين/شدّة/سكون: U+064B-U+0652، ألف خنجرية:
  // U+0670، تطويل: U+0640) — يفصل حروف كلمة زي "عصرًا" لـ ع-ص-ر-[تنوين]-ا
  // فيمنع مطابقة "عصرا" كسلسلة متصلة. نحذفه قبل أي مطابقة نمطية.
  static final RegExp _diacritics = RegExp(
    '[ـًٌٍَُِّْٰ]',
  );

  static String _stripDiacritics(String input) =>
      input.replaceAll(_diacritics, '');

  // اختصارات ألقاب بنقطة (Dr.، Mr.، أ.، د.، م.) — النقطة نفسها توقف
  // استخراج المشاركين عندها (بما إنها نفس علامة نهاية الجملة)، فتقطع
  // الاسم بعدها. نشيل النقطة الملتصقة بالاختصار قبل أي استخراج.
  // "و" ملحقة بالحرف المختصر ("ود." = "و" + "د.") من نفس صيغة "والمهندس"
  // المدعومة بمكان ثاني — نسمح بها هنا كمان (بجانب بداية النص/مسافة)،
  // وإلا نقطة "ود." الملتصقة توقف استخراج المشاركين قبل الاسم اللي بعدها.
  static final RegExp _titleAbbreviationPeriod = RegExp(
    r'\b(Dr|Mr|Mrs|Ms|Prof|Eng)\.|(^|\s|و)(أ|د|م)\.',
    caseSensitive: false,
  );

  static String _stripTitleAbbreviationPeriods(String input) =>
      input.replaceAllMapped(_titleAbbreviationPeriod, (m) {
        final en = m.group(1);
        if (en != null) return en;
        return '${m.group(2)}${m.group(3)}';
      });

  @override
  Future<CaptureDraft?> parse(String text, {DateTime? now}) async {
    final base = now ?? DateTime.now();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final raw = _stripTitleAbbreviationPeriods(_stripDiacritics(trimmed));
    final low = _normalizeDigits(raw.toLowerCase());
    final flags = <EventField>{};

    final participants = _participants(raw);
    final location = _location(raw);
    final day = _day(low, base, flags);
    final start = _start(low, day, flags);
    final end = start.add(_duration(low) ?? _defaultDuration);
    final title = _title(raw, participants, flags);

    return CaptureDraft(
      title: title,
      start: start,
      end: end,
      participants: participants,
      location: location,
      sourceText: raw,
      lowConfidence: flags,
    );
  }

  /// يفتش عن مكان بعد "في"/"in" — نفس منطق استخراج المشاركين بالضبط
  /// (يوقف عند أول كلمة تاريخ/وقت/مدة/مشارك). لو ما لقى "في"، يجرب صيغة
  /// "بـ" الملتصقة بالتعريف ("بالخبر"، "بالرياض") — شائعة جدًا بالعامية
  /// ومالها نفس صيغة "في" (كلمة منفصلة بمسافة).
  String? _location(String raw) {
    final boundary = {
      ..._clauseBoundaryWords,
      ..._weekdayNames.keys,
      ..._prayerNames.keys,
    }.map(RegExp.escape).join('|');

    final match = RegExp(
      '(?:في|in)\\s+(.+?)(?=\\s+(?:$boundary)(?:\\s|\$|[.,،؟!])|[.,،؟!]|\$)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      final place = match.group(1)!.trim();
      return place.isEmpty ? null : place;
    }

    final prefixed = RegExp(r'(?:^|\s)بال([^\s.,،؟!]+)').firstMatch(raw);
    if (prefixed != null) {
      final word = 'ال${prefixed.group(1)}';
      // "بالضبط"/"بالتحديد"... ظروف شائعة بنفس صيغة "بـ+تعريف" مالها
      // علاقة بمكان — نستثنيها حتى ما تنقرأ كموقع غلط.
      if (_commonNonLocationBaPhrases.contains(word)) return null;
      return word;
    }
    return null;
  }

  // كلمات شائعة بصيغة "بال..." مالها علاقة بمكان — استثناء لـ heuristic
  // موقع "بـ + تعريف" (بالخبر، بالرياض...). قائمة غير شاملة بالضرورة.
  static const Set<String> _commonNonLocationBaPhrases = {
    'الضبط', 'التحديد', 'الطبع', 'التالي', 'الإضافة', 'الاضافة',
    'النسبة', 'الفعل', 'المناسبة', 'الخصوص', 'الكامل', 'النهاية',
  };

  List<String> _participants(String raw) {
    final boundary = {
      ..._clauseBoundaryWords,
      ..._weekdayNames.keys,
      ..._prayerNames.keys,
    }.map(RegExp.escape).join('|');

    // ملاحظة: \b غير موثوق مع الحروف العربية في Dart RegExp (يعتمد على
    // \w اللي يغطي فقط a-z0-9_)، فنتحقق يدويًا إن الكلمة انتهت بمسافة/نهاية.
    // الفاصلة نفسها ما توقف القطعة هنا (بعكس المكان) — لأنها بالعادة تفصل
    // بين أسماء بنفس قائمة المشاركين ("مع منى، فهد، وريم")، مو بداية جملة
    // ثانية؛ الفاصل الحقيقي هو كلمة حدّية أو نهاية الجملة (نقطة/علامة سؤال)
    // أو بداية مكان بصيغة "بـ" الملتصقة بالتعريف ("بالخبر") — نفس الصيغة
    // اللي يتعرف عليها _location.
    final matches = RegExp(
      '(?:with|مع)\\s+(.+?)(?=\\s+بال[^\\s.,،؟!]+|\\s+(?:$boundary)(?:\\s|\$|[.,،؟!])|[.؟!]|\$)',
      caseSensitive: false,
    ).allMatches(raw);

    // جملة ممكن فيها أكثر من عبارة "مع" (زي "اجتماع مع سارة مع فريق
    // التسويق") — كل واحدة تحتوي أشخاص مختلفين، فنجمعهم كلهم بدل الاكتفاء
    // بأول عبارة بس.
    final people = <String>[];
    for (final match in matches) {
      final clause = match.group(1)!.trim();
      if (clause.isEmpty) continue;
      people.addAll(_peopleFromClause(clause));
    }
    return people;
  }

  /// يحوّل عبارة مشاركين وحدة (بعد "مع"/"with") لقائمة أسماء — يلحق لقب
  /// زي "الأستاذ"/"فريق" بالكلمة (الكلمات) اللي بعده كاسم واحد، بدل ما
  /// ينفصلون كـ"مشاركين" وهميين. نفحص اللقب على الكلمة بعد تجريدها من "و"
  /// حتى لو كانت ملتصقة فيها ("والمهندس سعد")، ونوقف الإلحاق عند أول كلمة
  /// معلّمة بـ"و" بالأول (شخص جديد) أو نهاية القائمة.
  List<String> _peopleFromClause(String clause) {
    final tokens =
        clause.split(RegExp(r'\s*,\s*|\s*،\s*|\s+and\s+|\s+', caseSensitive: false));

    final people = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final token = _stripArabicConjunction(tokens[i]).trim();
      if (token.isEmpty ||
          _participantStopWords.contains(token.toLowerCase()) ||
          _looksLikeBareTime(token)) {
        i++;
        continue;
      }
      if (_isTitlePrefix(token)) {
        final parts = [token];
        var j = i + 1;
        // نوقف الإلحاق عند أول كلمة معلّمة بـ"و" (صيغة عربية: "والدكتور
        // خالد") أو كلمة هي نفسها لقب معروف (صيغة إنجليزية بلا "و" ملتصقة:
        // "Dr Ahmed and Mrs Sara" — "and" تُستهلك كفاصل عادي، فـ"Mrs" هو
        // أول إشارة إن شخص جديد بدأ).
        while (j < tokens.length &&
            !(tokens[j].length > 1 && tokens[j].startsWith('و')) &&
            !_isTitlePrefix(tokens[j])) {
          final next = tokens[j].trim();
          if (next.isNotEmpty &&
              !_participantStopWords.contains(next.toLowerCase()) &&
              !_looksLikeBareTime(next)) {
            parts.add(next);
          }
          j++;
        }
        people.add(parts.join(' '));
        i = j;
      } else {
        people.add(token);
        i++;
      }
    }
    return people;
  }

  // كلمة وقت بلا مؤشر ("الساعة"/"at") قبلها مباشرة ما تُقرأ كوقت أصلًا
  // (_clock يتطلب المؤشر)، فتبقى عالقة بعبارة المشاركين كنص عادي —
  // "3pm"، "3ish"، "٥:٣٠" ونحوها مالها علاقة باسم شخص.
  static final RegExp _bareTimePattern =
      RegExp(r'^\d{1,2}(:\d{2})?(am|pm|ish)?$', caseSensitive: false);

  bool _looksLikeBareTime(String token) => _bareTimePattern.hasMatch(token);

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

  /// يفتش عن مدة صريحة بعد كلمة دالّة ("for"/"لمدة"/"مدة") — لازم الكلمة
  /// الدالّة عشان ما نلخبط "الساعة 3" (وقت) مع "لمدة 3 ساعات" (مدة).
  Duration? _duration(String low) {
    const marker = r'(?:for|لمدة|مدة)\s+';

    // "an?\s+" اختيارية بعد الماركر — تسمح بـ"for a quarter hour"/"for a
    // half hour" (أداة نكرة بين "for" والكمية)، مو بس "for half an hour".
    if (RegExp('$marker(?:an?\\s+)?(?:نص|نصف)\\s*ساعة').hasMatch(low) ||
        RegExp('$marker(?:an?\\s+)?half\\s*(?:an?\\s*)?hour').hasMatch(low)) {
      return const Duration(minutes: 30);
    }
    if (RegExp('$marker(?:an?\\s+)?ربع\\s*ساعة').hasMatch(low) ||
        RegExp('$marker(?:an?\\s+)?quarter\\s*(?:of an?\\s*)?hour').hasMatch(low)) {
      return const Duration(minutes: 15);
    }
    if (RegExp('$markerساعتين').hasMatch(low)) {
      return const Duration(hours: 2);
    }

    // ملاحظة: بدون \b — غير موثوق مع الحروف العربية بـ Dart RegExp (يعتمد
    // على \w اللي يغطي بس a-z0-9_)، وبالذات بنهاية النص.
    final hours =
        RegExp('$marker(\\d+(?:\\.\\d+)?)\\s*(?:ساعة|ساعات|hours?|hrs?)(?!\\w)')
            .firstMatch(low);
    if (hours != null) {
      final n = double.tryParse(hours.group(1)!);
      if (n != null) return Duration(minutes: (n * 60).round());
    }

    final minutes =
        RegExp('$marker(\\d+)\\s*(?:دقيقة|دقايق|minutes?|mins?)(?!\\w)')
            .firstMatch(low);
    if (minutes != null) {
      final n = int.tryParse(minutes.group(1)!);
      if (n != null) return Duration(minutes: n);
    }

    if (RegExp('$markerساعة(?!\\w)').hasMatch(low) ||
        RegExp('$marker(?:an?|one)\\s*hour(?!\\w)').hasMatch(low)) {
      return const Duration(hours: 1);
    }

    return null;
  }

  DateTime _start(String low, DateTime day, Set<EventField> flags) {
    // وقت صريح ("الساعة 3") له أولوية على اسم الصلاة — لو قال "الساعة 3
    // العصر" يقصد 3 بعد الظهر، مو وقت صلاة العصر الفعلي (اللي يختلف كل
    // يوم). اسم الصلاة يُستخدم فقط لما ما فيه وقت صريح ("بعد صلاة العصر").
    final clock = _clock(low) ?? _wordClock(low) ?? _namedTime(low);
    if (clock != null) {
      return DateTime(day.year, day.month, day.day, clock[0], clock[1]);
    }

    final prayer = _prayer(low);
    if (prayer != null) return prayerTimes.timeFor(prayer, day);

    flags.add(EventField.time);
    return DateTime(day.year, day.month, day.day, 9, 0);
  }

  /// كلمات وقت إنجليزية ثابتة مالها رقم — "noon"/"midnight".
  List<int>? _namedTime(String low) {
    if (RegExp(r'\bnoon\b').hasMatch(low)) return [12, 0];
    if (RegExp(r'\bmidnight\b').hasMatch(low)) return [0, 0];
    if (RegExp(r'نصف الليل|منتصف الليل').hasMatch(low)) return [0, 0];
    return null;
  }

  // "الساعة الثالثة مساء" — صيغة شائعة جدًا بالعربي (اسم الساعة بالحروف
  // بدل الأرقام). مرتّبة الأطول أولًا حتى "الثانية عشرة" (12) ما تنقرأ
  // غلط كـ"الثانية" (2).
  static const Map<String, int> _arabicHourWords = {
    // آمنة رغم تشابهها مع شهر "صفر" الهجري — هذا الجدول ما يُستشار إلا
    // بعد مطابقة "الساعة/الساعه" مباشرة قبل الكلمة، وصيغة التاريخ الهجري
    // ("5 صفر") مختلفة بنيويًا (رقم يوم قبلها، مو "الساعة").
    'صفر': 0,
    'الحادية عشرة': 11, 'حادية عشرة': 11, 'إحدى عشرة': 11, 'احدى عشرة': 11,
    'الثانية عشرة': 12, 'ثانية عشرة': 12, 'اثنتا عشرة': 12, 'اثنا عشر': 12,
    'الواحدة': 1, 'واحدة': 1,
    'الثانية': 2, 'ثانية': 2, 'اثنتين': 2,
    'الثالثة': 3, 'ثالثة': 3, 'ثلاثة': 3,
    'الرابعة': 4, 'رابعة': 4, 'اربعة': 4, 'أربعة': 4,
    'الخامسة': 5, 'خامسة': 5, 'خمسة': 5,
    'السادسة': 6, 'سادسة': 6, 'ستة': 6,
    'السابعة': 7, 'سابعة': 7, 'سبعة': 7,
    'الثامنة': 8, 'ثامنة': 8, 'ثمانية': 8,
    'التاسعة': 9, 'تاسعة': 9, 'تسعة': 9,
    'العاشرة': 10, 'عاشرة': 10, 'عشرة': 10,
  };

  static final List<String> _sortedArabicHourWords = _arabicHourWords.keys
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  List<int>? _wordClock(String low) {
    final pattern = _sortedArabicHourWords.map(RegExp.escape).join('|');
    final match =
        RegExp('(?:الساعة|الساعه)\\s+($pattern)').firstMatch(low);
    if (match == null) return null;
    var hour = _arabicHourWords[match.group(1)]!;

    var minute = 0;
    final rest = low.substring(match.end);
    if (RegExp(r'^\s*(?:إلا|الا)\s*ربع').hasMatch(rest)) {
      minute = 45;
      hour = hour == 1 ? 12 : hour - 1;
    } else if (RegExp(r'^\s*و\s*ربع').hasMatch(rest)) {
      minute = 15;
    } else if (RegExp(r'^\s*و\s*(?:النصف|نصف|النص|نص)').hasMatch(rest)) {
      minute = 30;
    }

    final ampm = _arabicPeriod(low);
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    return [hour, minute];
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

  /// يفهم "مساءً/مساء"، "عصرًا/العصر"، "ظهرًا/الظهر"، و"بالليل/الليل" كـ
  /// pm، و"صباحًا/صباح" كـ am. ملاحظة: هذا يُستدعى فقط من _clock/_wordClock
  /// بعد ما يكون فيه وقت صريح (رقم أو اسم ساعة بالحروف) — يعني "العصر"/
  /// "الظهر" هنا تُفهم كوصف فترة يوم مع وقت محدد ("الساعة 3 العصر" = 3
  /// بعد الظهر)، مو كطلب صريح لوقت الصلاة نفسه (هذا تتكفل فيه _prayer
  /// لما ما يكون فيه وقت صريح أصلًا).
  String? _arabicPeriod(String low) {
    if (RegExp(r'مساء|عصرا|العصر|ظهرا|الظهر|ليلا|الليل').hasMatch(low)) {
      return 'pm';
    }
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