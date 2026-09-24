import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/capabilities/calendar/presentation/widgets/capture_confirmation_card.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// نفس تجربة الالتقاط الذكي اللي بشاشة اليوم — نص حر يتفهّم منه التاريخ
  /// والوقت والموقع والمشاركين، بدل حقول يدوية منفصلة. لو النص ما ذكر
  /// تاريخ، يفترض اليوم المحدد بالتقويم (referenceDay) بدل اليوم الحالي
  /// دايمًا.
  void _addEventForSelectedDay(AppStrings s) {
    final day = _selectedDay ?? DateTime.now();
    final input = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Consumer(
          builder: (ctx, ref, _) {
            final capture = ref.watch(captureControllerProvider);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.newEvent, style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          autofocus: true,
                          onChanged: (v) => ref
                              .read(captureControllerProvider.notifier)
                              .setInput(v),
                          onSubmitted: (_) => ref
                              .read(captureControllerProvider.notifier)
                              .submit(referenceDay: day),
                          decoration: InputDecoration(
                            hintText: s.captureHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (capture.processing)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton.filled(
                          onPressed: () => ref
                              .read(captureControllerProvider.notifier)
                              .submit(referenceDay: day),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                    ],
                  ),
                  if (capture.pending != null) ...[
                    const SizedBox(height: 12),
                    CaptureConfirmationCard(
                      result: capture.pending!,
                      onResolved: () {
                        input.clear();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final agenda = ref.watch(agendaProvider);
    final events = agenda.value ?? const <CalendarEvent>[];
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;

    List<CalendarEvent> eventsForDay(DateTime day) =>
        events.where((e) => _sameDay(e.start, day)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final selectedEvents = _selectedDay == null
        ? <CalendarEvent>[]
        : eventsForDay(_selectedDay!);

    final calendarCard = _calendarCard(cs, lang, eventsForDay);
    final dayList = _dayList(theme, cs, s, lang, selectedEvents);

    return Scaffold(
      appBar: AppBar(title: Text(s.navCalendar)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: () => _addEventForSelectedDay(s),
        child: const Icon(Icons.add),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          // بالوضع الأفقي، المساحة الرأسية قليلة — التقويم والقائمة جنب
          // بعض بدل فوق بعض، بدل ما يتزاحمون على ارتفاع قصير.
          if (orientation == Orientation.landscape) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(child: calendarCard),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: dayList),
              ],
            );
          }

          return Column(
            children: [
              calendarCard,
              const Divider(height: 1),
              Expanded(child: dayList),
            ],
          );
        },
      ),
    );
  }

  Widget _calendarCard(
    ColorScheme cs,
    String lang,
    List<CalendarEvent> Function(DateTime) eventsForDay,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: TableCalendar<CalendarEvent>(
        locale: lang,
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            _selectedDay != null && _sameDay(_selectedDay!, day),
        eventLoader: eventsForDay,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: cs.tertiary,
            shape: BoxShape.circle,
          ),
        ),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
      ),
    );
  }

  Widget _dayList(
    ThemeData theme,
    ColorScheme cs,
    AppStrings s,
    String lang,
    List<CalendarEvent> selectedEvents,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              hijriDateString(_selectedDay ?? DateTime.now(), lang),
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: selectedEvents.isEmpty
              ? Center(
                  child: Text(
                    s.noEventsThisDay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, i) {
                    final event = selectedEvents[i];
                    final color = event.isFocus ? cs.primary : cs.tertiary;
                    return Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            event.isFocus
                                ? Icons.center_focus_strong
                                : Icons.groups,
                            color: color,
                          ),
                        ),
                        title: Text(event.title),
                        subtitle: Text(DateFormat.jm(lang).format(event.start)),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
