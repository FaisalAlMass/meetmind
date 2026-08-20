import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
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

  Future<void> _addEventForSelectedDay(AppStrings s) async {
    final day = _selectedDay ?? DateTime.now();
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    TimeOfDay pickedTime = const TimeOfDay(hour: 9, minute: 0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.newEvent),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: s.eventTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: s.locationLabel,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(s.timeLabel),
                  subtitle: Text(pickedTime.format(ctx)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: pickedTime,
                    );
                    if (t != null) setDialogState(() => pickedTime = t);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.addAction),
            ),
          ],
        ),
      ),
    );

    if (saved == true && titleController.text.trim().isNotEmpty) {
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      final location = locationController.text.trim();
      final event = CalendarEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: titleController.text.trim(),
        start: start,
        end: start.add(const Duration(hours: 1)),
        location: location.isEmpty ? null : location,
      );
      await ref.read(agendaProvider.notifier).add(event);
    }
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
