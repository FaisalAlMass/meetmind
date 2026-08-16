import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/services/notification_settings.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _options = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.notificationsLabel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(s.enableNotifications),
              subtitle: Text(settings.enabled
                  ? s.notifEnabledSubtitle
                  : s.notifDisabledSubtitle),
              value: settings.enabled,
              onChanged: (v) => notifier.setEnabled(v),
            ),
          ),
          const SizedBox(height: 16),
          if (settings.enabled) ...[
            Text(s.reminderTimeLabel,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<int>(
                groupValue: settings.minutesBefore,
                onChanged: (v) {
                  if (v != null) notifier.setMinutesBefore(v);
                },
                child: Column(
                  children: [
                    for (final m in _options) ...[
                      RadioListTile<int>(
                        value: m,
                        title: Text(s.reminderBefore(m)),
                      ),
                      if (m != _options.last) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.reminderInfoNote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}