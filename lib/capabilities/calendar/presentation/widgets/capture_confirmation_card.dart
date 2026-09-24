import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/hijri_date.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/services/notification_service.dart';

/// بطاقة مراجعة الموعد المُلتقط قبل الحفظ — مشتركة بين شاشة اليوم وشاشة
/// التقويم عشان ما نكرر نفس منطق العرض/التأكيد بمكانين. لو ما فيه وقت
/// مذكور بالنص أصلًا، تعرض طلب صريح لتحديده بدل حفظ وقت مُخترَع.
class CaptureConfirmationCard extends ConsumerWidget {
  const CaptureConfirmationCard({
    super.key,
    required this.result,
    required this.onResolved,
  });

  final CaptureResult result;

  /// يُستدعى بعد تأكيد الحفظ أو التجاهل — كل شاشة تستخدمه عشان تفضّي
  /// حقل الإدخال المحلي عندها.
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final notifier = ref.read(captureControllerProvider.notifier);
    final draft = result.draft;
    bool low(EventField f) => draft.lowConfidence.contains(f);
    final needsTime = low(EventField.time);

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
            if (needsTime)
              _timePrompt(context, theme, cs, s, notifier)
            else
              _dateField(theme, draft.start, draft.end, s, lang,
                  low(EventField.date)),
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
                          label: Text(DateFormat.jm(lang).format(slot)),
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
                    onPressed: needsTime
                        ? null
                        : () async {
                            final scheduleResult = await notifier.confirm();
                            onResolved();
                            HapticFeedback.lightImpact();
                            if (!context.mounted) return;
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
                  onPressed: () {
                    notifier.discard();
                    onResolved();
                  },
                  child: Text(s.discard),
                ),
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

  Widget _timePrompt(BuildContext context, ThemeData theme, ColorScheme cs,
      AppStrings s, CaptureController notifier) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: cs.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(s.noTimeStatedPrompt, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (picked != null) notifier.setTime(picked);
            },
            child: Text(s.pickTimeAction),
          ),
        ],
      ),
    );
  }
}
