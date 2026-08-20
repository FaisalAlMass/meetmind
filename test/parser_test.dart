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
}
