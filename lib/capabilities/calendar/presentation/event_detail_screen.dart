import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/edit_event_screen.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;
    String fmtTime(DateTime d) => DateFormat.jm(lang).format(d);
    String fmtGregorian(DateTime d) =>
        DateFormat(s.weekdayDateYearPattern, lang).format(d);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.eventDetailsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.editTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditEventScreen(event: event),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(event.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          _row(theme, Icons.event, s.dateLabel,
              hijriDateString(event.start, lang),
              caption: fmtGregorian(event.start)),
          const Divider(height: 24),
          _row(theme, Icons.access_time, s.timeLabel,
              '${fmtTime(event.start)} — ${fmtTime(event.end)}'),
          if (event.participants.isNotEmpty) ...[
            const Divider(height: 24),
            _row(theme, Icons.group, s.participantsLabel,
                event.participants.join(s.listSeparator)),
          ],
          if (event.location != null) ...[
            const Divider(height: 24),
            _row(theme, Icons.location_on, s.locationLabel, event.location!),
          ],
          if (event.isFocus) ...[
            const Divider(height: 24),
            _row(theme, Icons.center_focus_strong, s.typeLabel, s.focusTime),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, String value,
      {String? caption}) {
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: cs.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
              if (caption != null)
                Text(caption,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}