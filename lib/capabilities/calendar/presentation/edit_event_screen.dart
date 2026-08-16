import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key, required this.event});

  final CalendarEvent event;

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _location = TextEditingController(text: widget.event.location ?? '');
    _start = widget.event.start;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(
            picked.year, picked.month, picked.day, _start.hour, _start.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(_start.year, _start.month, _start.day,
            picked.hour, picked.minute);
      });
    }
  }

  Future<void> _save(AppStrings s) async {
    final duration = widget.event.end.difference(widget.event.start);
    final location = _location.text.trim();
    final updated = CalendarEvent(
      id: widget.event.id,
      title:
          _title.text.trim().isEmpty ? widget.event.title : _title.text.trim(),
      start: _start,
      end: _start.add(duration),
      location: location.isEmpty ? null : location,
      participants: widget.event.participants,
      isFocus: widget.event.isFocus,
    );

    await ref.read(agendaProvider.notifier).edit(updated);

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.eventUpdated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.editEventTitle),
        actions: [
          TextButton(onPressed: () => _save(s), child: Text(s.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: s.eventTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(s.dateLabel),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hijriDateString(_start, lang)),
                  Text(
                      DateFormat(s.weekdayDateYearPattern, lang).format(_start),
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(s.timeLabel),
              subtitle: Text(DateFormat.jm(lang).format(_start)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _location,
            decoration: InputDecoration(
              labelText: s.locationLabel,
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _save(s),
            child: Text(s.saveChanges),
          ),
        ],
      ),
    );
  }
}