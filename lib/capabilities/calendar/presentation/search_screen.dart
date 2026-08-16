import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final agenda = ref.watch(agendaProvider);
    final allEvents = agenda.value ?? const <CalendarEvent>[];
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;

    final results = _query.trim().isEmpty
        ? <CalendarEvent>[]
        : (allEvents
            .where((e) =>
                e.title.toLowerCase().contains(_query.toLowerCase()) ||
                e.participants
                    .any((p) => p.toLowerCase().contains(_query.toLowerCase())))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)));

    return Scaffold(
      appBar: AppBar(title: Text(s.navSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(theme, cs, results, s, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs,
      List<CalendarEvent> results, AppStrings s, String lang) {
    if (_query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(s.searchEmptyPrompt,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Text(s.noResultsFor(_query),
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final event = results[i];
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
                  event.isFocus ? Icons.center_focus_strong : Icons.groups,
                  color: color),
            ),
            title: Text(event.title),
            subtitle: Text(
                '${hijriShortDateString(event.start, lang)} · ${DateFormat.jm(lang).format(event.start)}'),
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
    );
  }
}