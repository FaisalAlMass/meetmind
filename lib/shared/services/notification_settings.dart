import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';

/// إعدادات الإشعارات: مُفعّلة أم لا + كم دقيقة قبل الموعد.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.minutesBefore = 15,
  });

  final bool enabled;
  final int minutesBefore;

  NotificationSettings copyWith({bool? enabled, int? minutesBefore}) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _enabledKey = 'meetmind_notif_enabled';
  static const _minutesKey = 'meetmind_notif_minutes';

  @override
  NotificationSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return NotificationSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      minutesBefore: prefs.getInt(_minutesKey) ?? 15,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setMinutesBefore(int value) async {
    state = state.copyWith(minutesBefore: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_minutesKey, value);
  }
}