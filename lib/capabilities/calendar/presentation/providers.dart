import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/capabilities/calendar/data/cloud_event_repository.dart';
import 'package:meetmind/capabilities/calendar/data/sources.dart';
import 'package:meetmind/capabilities/calendar/domain/calendar_domain.dart';
import 'package:meetmind/core/assistant/contracts.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/services/cloud_auth_service.dart';
import 'package:meetmind/shared/services/notification_service.dart';
import 'package:meetmind/shared/services/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Composition (dependency injection via Riverpod) ---

/// Overridden in main() with the app's registry.
final capabilityRegistryProvider = Provider<CapabilityRegistry>(
  (ref) => throw UnimplementedError('Override capabilityRegistryProvider in main()'),
);

/// Overridden in main() with the initialized SharedPreferences.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

final prayerTimeProvider =
    Provider<PrayerTimeProvider>((ref) => AdhanPrayerTimeProvider());

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => FirestoreEventRepository(CloudAuthService.instance),
);

/// المستودع القديم (SharedPreferences) — يبقى موجود بس عشان النقل لمرة
/// وحدة للمواعيد اللي كانت محفوظة قبل تفعيل المزامنة السحابية.
final _legacyEventRepositoryProvider = Provider<LocalEventRepository>(
  (ref) => LocalEventRepository(ref.read(sharedPreferencesProvider)),
);

final eventParserProvider = Provider<EventParser>(
  (ref) => NaturalLanguageEventParser(ref.read(prayerTimeProvider)),
);

final conflictDetectorProvider =
    Provider<ConflictDetector>((ref) => ConflictDetector());

final captureUseCaseProvider = Provider<CaptureEventUseCase>(
  (ref) => CaptureEventUseCase(
    parser: ref.read(eventParserProvider),
    repository: ref.read(eventRepositoryProvider),
    detector: ref.read(conflictDetectorProvider),
  ),
);

// --- Agenda state ---

final agendaProvider =
    StreamNotifierProvider<AgendaNotifier, List<CalendarEvent>>(
  AgendaNotifier.new,
);

class AgendaNotifier extends StreamNotifier<List<CalendarEvent>> {
  static const _migratedKey = 'meetmind_cloud_migrated';

  @override
  Stream<List<CalendarEvent>> build() async* {
    await _migrateLegacyEventsIfNeeded();
    yield* ref.read(eventRepositoryProvider).watchAll();
  }

  /// ينقل مواعيد كانت محفوظة محليًا (قبل تفعيل المزامنة السحابية) لمرة
  /// وحدة فقط — بعدين يعلّم النقل كخلاص عشان ما يتكرر كل تشغيل. لو ما فيه
  /// مواعيد محفوظة فعليًا (تركيب جديد)، ما نسوي شي — بعكس all() اللي يرجع
  /// بيانات عرض افتراضية (seed) حتى لو ما فيه شي محفوظ أصلًا.
  Future<void> _migrateLegacyEventsIfNeeded() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_migratedKey) ?? false) return;

    final legacyRepository = ref.read(_legacyEventRepositoryProvider);
    if (legacyRepository.hasSavedEvents) {
      final legacyEvents = await legacyRepository.all();
      final cloudRepository = ref.read(eventRepositoryProvider);
      for (final event in legacyEvents) {
        await cloudRepository.add(event);
      }
    }
    await prefs.setBool(_migratedKey, true);
  }

  Future<ReminderScheduleResult?> add(CalendarEvent event) async {
    final repository = ref.read(eventRepositoryProvider);
    await repository.add(event);

    ReminderScheduleResult? result;
    final settings = ref.read(notificationSettingsProvider);
    if (settings.enabled) {
      final s = ref.read(appStringsProvider);
      result = await NotificationService.instance.scheduleForEvent(
        id: event.id.hashCode,
        title: event.title,
        start: event.start,
        minutesBefore: settings.minutesBefore,
        reminderTitle: s.notifReminderTitle,
        channelName: s.notifChannelName,
        channelDescription: s.notifChannelDesc,
        body: s.notifBody,
      );
    }

    return result;
  }

  Future<ReminderScheduleResult?> edit(CalendarEvent event) async {
    final repository = ref.read(eventRepositoryProvider);
    await repository.remove(event.id);
    await repository.add(event);

    await NotificationService.instance.cancel(event.id.hashCode);
    ReminderScheduleResult? result;
    final settings = ref.read(notificationSettingsProvider);
    if (settings.enabled) {
      final s = ref.read(appStringsProvider);
      result = await NotificationService.instance.scheduleForEvent(
        id: event.id.hashCode,
        title: event.title,
        start: event.start,
        minutesBefore: settings.minutesBefore,
        reminderTitle: s.notifReminderTitle,
        channelName: s.notifChannelName,
        channelDescription: s.notifChannelDesc,
        body: s.notifBody,
      );
    }

    return result;
  }

  Future<void> remove(String id) async {
    final repository = ref.read(eventRepositoryProvider);
    await repository.remove(id);

    await NotificationService.instance.cancel(id.hashCode);
  }

  int get conflictCount {
    final events = state.value ?? const [];
    var count = 0;
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        if (events[i].start.isBefore(events[j].end) &&
            events[j].start.isBefore(events[i].end)) {
          count++;
        }
      }
    }
    return count;
  }
}

// --- Capture state ---

class CaptureState {
  const CaptureState({
    this.input = '',
    this.processing = false,
    this.pending,
    this.notUnderstood = false,
  });

  final String input;
  final bool processing;
  final CaptureResult? pending;
  final bool notUnderstood;

  CaptureState copyWith({
    String? input,
    bool? processing,
    CaptureResult? pending,
    bool clearPending = false,
    bool? notUnderstood,
  }) {
    return CaptureState(
      input: input ?? this.input,
      processing: processing ?? this.processing,
      pending: clearPending ? null : (pending ?? this.pending),
      notUnderstood: notUnderstood ?? this.notUnderstood,
    );
  }
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  void setInput(String value) =>
      state = state.copyWith(input: value, notUnderstood: false);

  /// [referenceDay] — يستخدمه شاشة التقويم عشان لو ما فيه تاريخ مذكور
  /// بالنص، الموعد ينحط باليوم المحدد بالتقويم بدل اليوم الحالي دايمًا.
  Future<void> submit({DateTime? referenceDay}) async {
    final text = state.input.trim();
    if (text.isEmpty) return;

    state = state.copyWith(processing: true, notUnderstood: false);
    final result = await ref.read(captureUseCaseProvider).capture(text);

    if (result == null) {
      state = state.copyWith(
        processing: false,
        notUnderstood: true,
        clearPending: true,
      );
      return;
    }

    var draft = result.draft;
    if (referenceDay != null && draft.lowConfidence.contains(EventField.date)) {
      final shifted = DateTime(referenceDay.year, referenceDay.month,
          referenceDay.day, draft.start.hour, draft.start.minute);
      draft = draft.copyWith(
        start: shifted,
        end: shifted.add(draft.end.difference(draft.start)),
      );
    }

    state = state.copyWith(
      processing: false,
      pending: CaptureResult(
        draft: draft,
        conflicts: result.conflicts,
        suggestions: result.suggestions,
      ),
    );
  }

  void setTime(TimeOfDay time) {
    final current = state.pending;
    if (current == null) return;

    final d = current.draft;
    final start =
        DateTime(d.start.year, d.start.month, d.start.day, time.hour, time.minute);
    final duration = d.end.difference(d.start);
    final flags = {...d.lowConfidence}..remove(EventField.time);
    final draft = d.copyWith(
      start: start,
      end: start.add(duration),
      lowConfidence: flags,
    );

    state = state.copyWith(
      pending: CaptureResult(
        draft: draft,
        conflicts: current.conflicts,
        suggestions: current.suggestions,
      ),
    );
  }

  void pickSlot(DateTime start) {
    final current = state.pending;
    if (current == null) return;

    final duration = current.draft.end.difference(current.draft.start);
    final flags = {...current.draft.lowConfidence}
      ..removeAll({EventField.time, EventField.date});
    final draft = current.draft.copyWith(
      start: start,
      end: start.add(duration),
      lowConfidence: flags,
    );

    state = state.copyWith(
      pending: CaptureResult(draft: draft, conflicts: const [], suggestions: const []),
    );
  }

  Future<ReminderScheduleResult?> confirm() async {
    final draft = state.pending?.draft;
    if (draft == null) return null;
    final result = await ref.read(agendaProvider.notifier).add(draft.toEvent());
    state = const CaptureState();
    return result;
  }

  void discard() => state = state.copyWith(clearPending: true);
}