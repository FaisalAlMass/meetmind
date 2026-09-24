import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/domain/date_reference_parser.dart';
import 'package:meetmind/capabilities/calendar/presentation/event_detail_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/widgets/empty_state.dart';

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

  /// لو النص فيه مرجع تاريخ مفهوم (نسبي أو مطلق، هجري أو ميلادي) — نعرض
  /// كل مواعيد ذاك اليوم. غير كذا نبحث بالعنوان/المشاركين/الموقع كنص عادي.
  List<CalendarEvent> _search(List<CalendarEvent> events, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final today = DateTime.now();
    final date = DateReferenceParser.tryParse(
        trimmed, DateTime(today.year, today.month, today.day));
    if (date != null) {
      return events.where((e) =>
          e.start.year == date.year &&
          e.start.month == date.month &&
          e.start.day == date.day).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    }

    final low = trimmed.toLowerCase();
    return events.where((e) =>
        e.title.toLowerCase().contains(low) ||
        e.participants.any((p) => p.toLowerCase().contains(low)) ||
        (e.location?.toLowerCase().contains(low) ?? false)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final agenda = ref.watch(agendaProvider);
    final allEvents = agenda.value ?? const <CalendarEvent>[];
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;

    final results = _search(allEvents, _query);

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
      return EmptyState(message: s.searchEmptyPrompt);
    }

    if (results.isEmpty) {
      return EmptyState(message: s.noResultsFor(_query));
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