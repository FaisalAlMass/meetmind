// Core models — storage-agnostic value types shared across the app.

/// A confirmed event that lives in the user's calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.participants = const [],
    this.isFocus = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final List<String> participants;
  final bool isFocus;

  Duration get duration => end.difference(start);
}

/// Which fields a parser was unsure about. The UI flags these instead of
/// silently trusting a guess — the "confirm before save" rule.
enum EventField { title, date, time, participants, location }

/// An *unconfirmed* event proposed by a parser (natural language, OCR, voice).
/// Nothing is written to the calendar until a draft is confirmed.
class CaptureDraft {
  const CaptureDraft({
    required this.title,
    required this.start,
    required this.end,
    required this.sourceText,
    this.location,
    this.participants = const [],
    this.lowConfidence = const {},
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String sourceText;
  final String? location;
  final List<String> participants;
  final Set<EventField> lowConfidence;

  CaptureDraft copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? location,
    List<String>? participants,
    Set<EventField>? lowConfidence,
  }) {
    return CaptureDraft(
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      sourceText: sourceText,
      location: location ?? this.location,
      participants: participants ?? this.participants,
      lowConfidence: lowConfidence ?? this.lowConfidence,
    );
  }

  CalendarEvent toEvent() => CalendarEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        start: start,
        end: end,
        location: location,
        participants: participants,
      );
}

/// Result of running a capture through parsing + conflict detection.
class CaptureResult {
  const CaptureResult({
    required this.draft,
    this.conflicts = const [],
    this.suggestions = const [],
  });

  final CaptureDraft draft;
  final List<CalendarEvent> conflicts;
  final List<DateTime> suggestions;
}

/// The five daily prayers, used for prayer-relative scheduling ("after Asr").
enum Prayer { fajr, dhuhr, asr, maghrib, isha }
