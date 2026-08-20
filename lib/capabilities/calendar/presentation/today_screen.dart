import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/calendar_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/profile_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/capabilities/calendar/presentation/search_screen.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/services/notification_service.dart';
import 'package:meetmind/shared/services/speech_service.dart';
import 'package:meetmind/shared/services/user_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// الهيكل الرئيسي — يدير التبويبات السفلية.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    CalendarScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.navToday),
          NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today),
              label: s.navCalendar),
          NavigationDestination(
              icon: const Icon(Icons.search), label: s.navSearch),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), label: s.navProfile),
        ],
      ),
    );
  }
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) SpeechService.instance.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(captureControllerProvider.notifier)
      ..setInput(_input.text)
      ..submit();
  }

  Future<void> _toggleListening(AppStrings s, String lang) async {
    if (_listening) {
      await SpeechService.instance.stop();
      return;
    }

    // علم خاص بهالجلسة بالذات — يمنع أي رد متأخر (stray callback) يوصل
    // بعد ما الجلسة خلصت من إنه يرجع يعبّي حقل الكتابة بنص قديم.
    var sessionDone = false;
    void finish() {
      if (sessionDone) return;
      sessionDone = true;
      if (mounted) setState(() => _listening = false);
    }

    final started = await SpeechService.instance.listen(
      lang: lang,
      onResult: (text, isFinal) {
        if (!mounted || sessionDone) return;
        _input.text = text;
        _input.selection =
            TextSelection.collapsed(offset: _input.text.length);
        ref.read(captureControllerProvider.notifier).setInput(text);
        if (isFinal) {
          finish();
          if (text.trim().isNotEmpty) _submit();
        }
      },
      onError: (permanent) {
        if (!mounted) return;
        finish();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.voiceUnavailable)),
        );
      },
      onStatus: (status) {
        // شبكة أمان: لو الجلسة خلصت (notListening/done) بدون خطأ صريح
        // ولا نتيجة نهائية، ما نخلي المايك يعلق أحمر للأبد.
        if (!mounted) return;
        if (status == stt.SpeechToText.notListeningStatus ||
            status == stt.SpeechToText.doneStatus) {
          finish();
        }
      },
    );

    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.voiceUnavailable)),
      );
      return;
    }
    setState(() => _listening = true);
  }

  String _fmtTime(DateTime d, String lang) => DateFormat.jm(lang).format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final capture = ref.watch(captureControllerProvider);
    final agenda = ref.watch(agendaProvider);
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final userName = ref.watch(userNameProvider) ?? s.defaultUserName;
    final initial = userName.isNotEmpty ? userName.characters.first : s.defaultInitial;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 15,
                backgroundColor: cs.primaryContainer,
                child: Text(initial,
                    style: TextStyle(color: cs.onPrimaryContainer)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(s.greeting(userName),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          Text(hijriDateString(DateTime.now(), lang),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          Text(DateFormat(s.weekdayDatePattern, lang).format(DateTime.now()),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.outline.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          _captureBar(theme, capture, s, lang),
          if (capture.notUnderstood)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.notUnderstood, style: theme.textTheme.bodySmall),
            ),
          if (capture.pending != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _confirmationCard(theme, capture.pending!, s, lang),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.navToday, style: theme.textTheme.titleMedium),
              agenda.maybeWhen(
                data: (events) => Text(s.eventsCount(events.length),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          agenda.when(
            data: (events) => events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.noEventsYet,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  )
                : Column(
                    children: events
                        .map((e) => _agendaTile(theme, e, s, lang))
                        .toList()),
            loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
            error: (_, _) => Text(s.loadFailed),
          ),
        ],
      ),
    );
  }

  Widget _captureBar(
      ThemeData theme, CaptureState capture, AppStrings s, String lang) {
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                textInputAction: TextInputAction.go,
                onChanged: (v) =>
                    ref.read(captureControllerProvider.notifier).setInput(v),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _listening ? s.listeningHint : s.captureHint,
                ),
              ),
            ),
            IconButton(
              tooltip: s.voiceInputTooltip,
              onPressed: () => _toggleListening(s, lang),
              icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                  color: _listening ? cs.error : cs.onSurfaceVariant),
            ),
            if (capture.processing)
              const SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton.filled(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirmationCard(
      ThemeData theme, CaptureResult result, AppStrings s, String lang) {
    final cs = theme.colorScheme;
    final draft = result.draft;
    final notifier = ref.read(captureControllerProvider.notifier);
    bool low(EventField f) => draft.lowConfidence.contains(f);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.confirmBeforeSave,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            _field(theme, Icons.title, draft.title, low(EventField.title)),
            const SizedBox(height: 8),
            _dateField(theme, draft.start, draft.end, s, lang,
                low(EventField.date) || low(EventField.time)),
            if (draft.participants.isNotEmpty) ...[
              const SizedBox(height: 8),
              _field(theme, Icons.group,
                  draft.participants.join(s.listSeparator), false),
            ],
            if (draft.location != null) ...[
              const SizedBox(height: 8),
              _field(theme, Icons.location_on_outlined, draft.location!, false),
            ],
            if (result.conflicts.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Text(s.conflictsWith(result.conflicts.length),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.tertiary)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: result.suggestions
                    .map((slot) => ActionChip(
                          label: Text(_fmtTime(slot, lang)),
                          onPressed: () => notifier.pickSlot(slot),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final scheduleResult = await notifier.confirm();
                      _input.clear();
                      if (!mounted) return;
                      final warning = switch (scheduleResult) {
                        ReminderScheduleResult.reminderAlreadyPassed =>
                          s.reminderTimePassed,
                        ReminderScheduleResult.permissionDenied =>
                          s.notifPermissionDeniedSnack,
                        _ => null,
                      };
                      if (warning != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(warning)),
                        );
                      }
                    },
                    child: Text(s.saveEvent),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: notifier.discard, child: Text(s.discard)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(ThemeData theme, IconData icon, String value, bool uncertain) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
        if (uncertain) Icon(Icons.warning_amber, size: 16, color: cs.tertiary),
      ],
    );
  }

  Widget _dateField(ThemeData theme, DateTime start, DateTime end,
      AppStrings s, String lang, bool uncertain) {
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${hijriDateString(start, lang, withWeekday: false)} · '
                  '${DateFormat.jm(lang).format(start)} — '
                  '${DateFormat.jm(lang).format(end)}'),
              Text(DateFormat(s.weekdayDatePattern, lang).format(start),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        if (uncertain) Icon(Icons.warning_amber, size: 16, color: cs.tertiary),
      ],
    );
  }

  Widget _agendaTile(
      ThemeData theme, CalendarEvent event, AppStrings s, String lang) {
    final cs = theme.colorScheme;
    final color = event.isFocus ? cs.primary : cs.tertiary;
    final sub = event.participants.isNotEmpty
        ? s.withParticipants(event.participants.join(s.listSeparator))
        : (event.isFocus ? s.focusTime : (event.location ?? ''));

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsetsDirectional.only(end: 20),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.deleteEventTitle),
            content: Text(s.confirmDeleteBody(event.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.delete),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (_) {
        ref.read(agendaProvider.notifier).remove(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.deletedSnack(event.title))),
        );
      },
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            );
          },
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  event.isFocus ? Icons.center_focus_strong : Icons.groups,
                  color: color),
            ),
            title: Text(event.title),
            subtitle: Text(
                '${_fmtTime(event.start, lang)}${sub.isNotEmpty ? ' · $sub' : ''}'),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        ),
      ),
    );
  }
}