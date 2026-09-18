import 'package:flutter_test/flutter_test.dart';
import 'package:meetmind/capabilities/calendar/data/sources.dart';
import 'package:meetmind/core/models.dart';

void main() {
  final parser = NaturalLanguageEventParser(StubPrayerTimeProvider());
  final now = DateTime(2026, 8, 20, 10, 0); // Thursday

  Future<DateTime> startOf(String text) async {
    final draft = await parser.parse(text, now: now);
    return draft!.start;
  }

  Future<bool> timeIsConfident(String text) async {
    final draft = await parser.parse(text, now: now);
    return !draft!.lowConfidence.contains(EventField.time);
  }

  Future<List<String>> participantsOf(String text) async {
    final draft = await parser.parse(text, now: now);
    return draft!.participants;
  }

  Future<String?> locationOf(String text) async {
    final draft = await parser.parse(text, now: now);
    return draft!.location;
  }

  group('digits and markers', () {
    test('Western digits with مساء', () async {
      expect(await startOf('اجتماع مع سارة بكرة الساعة 3 مساءً'),
          DateTime(2026, 8, 21, 15));
    });

    test('عصرا is recognized as pm', () async {
      expect(await startOf('موعد الساعة 5 عصرا'), DateTime(2026, 8, 20, 17));
    });

    test('بالليل is recognized as pm', () async {
      expect(await startOf('موعد الساعة 11 بالليل'), DateTime(2026, 8, 20, 23));
    });
  });

  group('Eastern Arabic-Indic digits (common on Arabic keyboards)', () {
    test('single digit with مساء', () async {
      expect(await startOf('اجتماع مع سارة بكرة الساعة ٣ مساءً'),
          DateTime(2026, 8, 21, 15));
    });

    test('double digit with صباحا', () async {
      expect(await startOf('موعد الساعة ١٠ صباحا'), DateTime(2026, 8, 20, 10));
    });

    test('is not flagged low-confidence', () async {
      expect(await timeIsConfident('موعد الساعة ٥ عصرا'), isTrue);
    });
  });

  group('spelled-out Arabic hour words', () {
    test('plain hour word', () async {
      expect(await startOf('اجتماع مع عمر الساعة الثالثة مساء'),
          DateTime(2026, 8, 20, 15));
    });

    test('with والنصف (:30)', () async {
      expect(await startOf('موعد الساعة السادسة والنصف مساء'),
          DateTime(2026, 8, 20, 18, 30));
    });

    test('with وربع (:15)', () async {
      expect(await startOf('اجتماع الساعة الثالثة وربع مساء'),
          DateTime(2026, 8, 20, 15, 15));
    });

    test('with إلا ربع (quarter to)', () async {
      expect(await startOf('اجتماع الساعة الثالثة إلا ربع مساء'),
          DateTime(2026, 8, 20, 14, 45));
    });

    test('eleven/twelve o\'clock long forms', () async {
      expect(await startOf('اجتماع الساعة الثانية عشرة ظهرا'),
          DateTime(2026, 8, 20, 12));
    });

    test('is not flagged low-confidence', () async {
      expect(await timeIsConfident('اجتماع الساعة العاشرة صباحا'), isTrue);
    });
  });

  group('English control group (unaffected by Arabic-only fixes)', () {
    test('at 3pm', () async {
      expect(await startOf('Meeting with Sara tomorrow at 3pm'),
          DateTime(2026, 8, 21, 15));
    });

    test('24h clock', () async {
      expect(
          await startOf('Coffee with Omar at 15:00'), DateTime(2026, 8, 20, 15));
    });
  });

  group('titled participant names stay one name, not split into two', () {
    test('الأستاذ + name', () async {
      expect(await participantsOf('اجتماع مع الأستاذ محمد في جدة الساعة 9'),
          ['الأستاذ محمد']);
    });

    test('الدكتور + name', () async {
      expect(
          await participantsOf('اجتماع مع الدكتور أحمد الساعة 11 صباحا'),
          ['الدكتور أحمد']);
    });

    test('أبو + name (kunya)', () async {
      expect(await participantsOf('اجتماع مع أبو محمد الساعة 2 ظهرا'),
          ['أبو محمد']);
    });

    test('فريق + multi-word group name', () async {
      expect(
          await participantsOf(
              'اجتماع مع فريق الذكاء الاصطناعي الساعة 9 بالليل'),
          ['فريق الذكاء الاصطناعي']);
    });

    test('trailing Arabic question mark is stripped from the name', () async {
      expect(await participantsOf('ترتب لي اجتماع مع المهندس خالد؟ الساعة 4'),
          ['المهندس خالد']);
    });
  });

  group('topic phrases (لمناقشة/بخصوص/موضوع) don\'t leak into other fields',
      () {
    test('excluded from location', () async {
      expect(
          await locationOf(
              'اجتماع مع خالد في الرياض بخصوص خطة العمل الجديدة الساعة 10'),
          'الرياض');
    });

    test('excluded from participants', () async {
      expect(
          await participantsOf(
              'اجتماع مع فريق المشروع لمناقشة مراحل التنفيذ الساعة 3'),
          ['فريق المشروع']);
    });
  });

  group('explicit clock time outranks a same-sentence prayer name', () {
    test('"الساعة 3 العصر" means 3pm, not the actual Asr prayer time',
        () async {
      expect(await startOf('اجتماع الساعة 3 العصر في جدة'),
          DateTime(2026, 8, 20, 15));
    });

    test('with no explicit clock, the prayer name still resolves the time',
        () async {
      // StubPrayerTimeProvider fixes Asr at 15:54 — distinct from a plain
      // "3pm" guess, so this proves the prayer branch still runs when
      // there's genuinely no explicit time to prioritize.
      expect(await startOf('قهوة مع عمر بعد صلاة العصر'),
          DateTime(2026, 8, 20, 15, 54));
    });
  });

  group('ظهرا/العصر recognized as pm period words', () {
    test('2 ظهرا means 2pm, not 2am', () async {
      expect(await startOf('اجتماع الساعة 2 ظهرا'), DateTime(2026, 8, 20, 14));
    });

    test('4 عصرًا with tashkeel still means 4pm', () async {
      expect(await startOf('اجتماع الساعة 4 عصرًا'), DateTime(2026, 8, 20, 16));
    });
  });

  group('comma-separated participant lists', () {
    test('all three names are kept, not just the first', () async {
      expect(
          await participantsOf(
              'غدا اجتماع مع منى، فهد، وريم الساعة 11 صباحا في مكتب الشركة'),
          ['منى', 'فهد', 'ريم']);
    });
  });

  group('titled name joined with و ("والمهندس سعد")', () {
    test('title + name after و stays merged, not split', () async {
      expect(
          await participantsOf(
              'اجتماع مع الدكتورة منى والمهندس سعد الساعة 9 صباحا في جدة'),
          ['الدكتورة منى', 'المهندس سعد']);
    });
  });

  group('بـ + definite article location ("بالخبر")', () {
    test('recognized as a location', () async {
      expect(await locationOf('اجتماع مع أبو سلطان بالخبر الساعة 5 عصرا'),
          'الخبر');
    });

    test('excluded from the participant name', () async {
      expect(await participantsOf('اجتماع مع أبو سلطان بالخبر الساعة 5 عصرا'),
          ['أبو سلطان']);
    });
  });

  group('English quarter/half hour with an article before the quantity', () {
    test('"for a quarter hour" is recognized (not just "for quarter hour")',
        () async {
      final draft = await parser.parse(
          'Quick call with Ahmed for a quarter hour tomorrow at 9am',
          now: now);
      expect(draft!.end.difference(draft.start), const Duration(minutes: 15));
    });
  });
}
