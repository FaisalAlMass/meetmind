import 'package:meetmind/core/assistant/contracts.dart';
import 'package:meetmind/core/models.dart';

/// Persistence boundary for the calendar capability. The app talks to this,
/// never to Google Calendar or a database directly. Swap the in-memory
/// implementation for a `GoogleEventRepository` and nothing above changes.
abstract class EventRepository {
  Future<List<CalendarEvent>> all();
  Future<List<CalendarEvent>> eventsFor(DateTime day);
  Future<void> add(CalendarEvent event);
  Future<void> remove(String id);

  /// Live view of the full event list — pushes an update whenever the
  /// underlying store changes, instead of requiring a manual re-fetch.
  Stream<List<CalendarEvent>> watchAll();
}

/// Events from the start of today onward, sorted ascending — the single
/// source of truth for "upcoming", shared between the Today screen and the
/// home-widget data sync so both never disagree.
List<CalendarEvent> upcomingEvents(List<CalendarEvent> events, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final startOfToday = DateTime(n.year, n.month, n.day);
  return events.where((e) => !e.start.isBefore(startOfToday)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// Pure, dependency-free overlap logic. Treats back-to-back events (shared
/// boundary) as non-conflicting.
class ConflictDetector {
  bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
      aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

  List<CalendarEvent> conflicts(
    DateTime start,
    DateTime end,
    List<CalendarEvent> events,
  ) =>
      events.where((e) => _overlaps(start, end, e.start, e.end)).toList();

  /// Next free slots of [duration], searched forward in 30-minute steps.
  List<DateTime> freeSlots(
    DateTime start,
    Duration duration,
    List<CalendarEvent> events,
    int count,
  ) {
    final slots = <DateTime>[];
    var cursor = start;
    var iterations = 0;
    while (slots.length < count && iterations < 48) {
      iterations++;
      final candidateEnd = cursor.add(duration);
      final clash =
          events.any((e) => _overlaps(cursor, candidateEnd, e.start, e.end));
      if (clash) {
        cursor = cursor.add(const Duration(minutes: 30));
      } else {
        slots.add(cursor);
        cursor = candidateEnd;
      }
    }
    return slots;
  }
}

/// Orchestrates the flagship flow: text in → draft + conflicts out, then a
/// separate explicit confirm step. The two-step shape enforces
/// "nothing saves without confirmation" at the architecture level.
class CaptureEventUseCase {
  CaptureEventUseCase({
    required this.parser,
    required this.repository,
    required this.detector,
  });

  final EventParser parser;
  final EventRepository repository;
  final ConflictDetector detector;

  Future<CaptureResult?> capture(String text, {DateTime? now}) async {
    final draft = await parser.parse(text, now: now);
    if (draft == null) return null;

    final existing = await repository.all();
    final conflicts = detector.conflicts(draft.start, draft.end, existing);
    final suggestions = conflicts.isEmpty
        ? const <DateTime>[]
        : detector.freeSlots(
            draft.start,
            draft.end.difference(draft.start),
            existing,
            3,
          );

    return CaptureResult(
      draft: draft,
      conflicts: conflicts,
      suggestions: suggestions,
    );
  }

  Future<void> confirm(CaptureDraft draft) async =>
      repository.add(draft.toEvent());
}
