import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/services/notification_service.dart';
import 'package:meetmind/shared/services/notification_settings.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  static const _options = [5, 10, 15, 30, 60];

  bool? _hasPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // لو المستخدم راح لإعدادات النظام وفعّل/عطّل الإذن ورجع للتطبيق،
    // نحدّث الحالة تلقائيًا بدون ما يحتاج يعمل شي.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await NotificationService.instance.hasPermission();
    if (mounted) setState(() => _hasPermission = granted);
  }

  Future<void> _tryTone(AppStrings s) async {
    final result = await NotificationService.instance.sendTestNotification();
    if (!mounted) return;
    final message = result == ReminderScheduleResult.permissionDenied
        ? s.notifPermissionDeniedSnack
        : s.testNotificationSent;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    _refreshPermission();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final s = ref.watch(appStringsProvider);
    final granted = _hasPermission;

    return Scaffold(
      appBar: AppBar(title: Text(s.notificationsLabel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (granted != null)
            Card(
              color: granted
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.errorContainer.withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      granted
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: granted ? cs.primary : cs.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            granted
                                ? s.notifPermissionGrantedTitle
                                : s.notifPermissionDeniedTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            granted
                                ? s.notifPermissionGrantedBody
                                : s.notifPermissionDeniedBody,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          if (!granted) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () => AppSettings.openAppSettings(
                                  type: AppSettingsType.notification),
                              child: Text(s.openSystemSettings),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
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
            OutlinedButton.icon(
              onPressed: () => _tryTone(s),
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(s.tryToneNow),
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
