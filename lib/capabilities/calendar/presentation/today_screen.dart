import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/calendar_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/profile_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/capabilities/calendar/presentation/search_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/widgets/capture_confirmation_card.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/services/speech_service.dart';
import 'package:meetmind/shared/services/user_service.dart';
import 'package:meetmind/shared/widgets/empty_state.dart';
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
              label: s.navHome),
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

class _TodayScreenState extends ConsumerState<TodayScreen>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _listening = false;

  // نبضة بصرية لأيقونة المايك وقت الاستماع — بديل عن مجرد تلوينها أحمر.
  late final AnimationController _micPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _micScale =
      Tween(begin: 1.0, end: 1.15).animate(
    CurvedAnimation(parent: _micPulse, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    if (_listening) SpeechService.instance.cancel();
    _micPulse.dispose();
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
      _micPulse.stop();
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
    _micPulse.repeat(reverse: true);
  }

  String _fmtTime(DateTime d, String lang) => DateFormat.jm(lang).format(d);

  /// يستثني المواعيد اللي تاريخها قبل اليوم — يبقي مواعيد اليوم (حتى لو
  /// وقتها فات) وكل الجايّة بعدها، بدل عرض كل السجل التاريخي.
  List<CalendarEvent> _upcoming(List<CalendarEvent> events) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return events.where((e) => !e.start.isBefore(startOfToday)).toList();
  }

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: capture.pending != null
                ? Padding(
                    key: const ValueKey('pending'),
                    padding: const EdgeInsets.only(top: 12),
                    child: CaptureConfirmationCard(
                      result: capture.pending!,
                      onResolved: () => _input.clear(),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.upcomingEvents, style: theme.textTheme.titleMedium),
              agenda.maybeWhen(
                data: (events) => Text(s.eventsCount(_upcoming(events).length),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          agenda.when(
            data: (events) {
              final upcoming = _upcoming(events);
              return upcoming.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(message: s.noEventsYet),
                    )
                  : Column(
                      children: upcoming
                          .map((e) => _agendaTile(theme, e, s, lang))
                          .toList());
            },
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
            ScaleTransition(
              scale: _listening
                  ? _micScale
                  : const AlwaysStoppedAnimation(1.0),
              child: IconButton(
                tooltip: s.voiceInputTooltip,
                onPressed: () => _toggleListening(s, lang),
                icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                    color: _listening ? cs.error : cs.onSurfaceVariant),
              ),
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