import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة الإشعارات — تدير الأذونات وجدولة تنبيهات المواعيد.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// تُستدعى مرة واحدة عند تشغيل التطبيق. تطلب الإذن تلقائيًا على iOS.
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(
      iOS: iosSettings,
      macOS: iosSettings,
      android: androidSettings,
    );

    await _plugin.initialize(settings);
    _ready = true;
  }

  /// يجدول تنبيهًا لموعد قبله بـ [minutesBefore] دقيقة.
  Future<void> scheduleForEvent({
    required int id,
    required String title,
    required DateTime start,
    int minutesBefore = 15,
    String reminderTitle = 'تذكير بموعد',
    String channelName = 'تذكيرات المواعيد',
    String channelDescription = 'تنبيهات قبل مواعيدك',
    String Function(String title, int minutes)? body,
  }) async {
    await init();
    final when = start.subtract(Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now())) return;

    final details = NotificationDetails(
      iOS: const DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'meetmind_reminders',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      reminderTitle,
      body != null ? body(title, minutesBefore) : '$title بعد $minutesBefore دقيقة',
      tz.TZDateTime.from(when, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// يلغي تنبيه موعد محذوف.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}