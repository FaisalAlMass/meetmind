import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// نتيجة محاولة جدولة تذكير — يستخدمها المستدعي عشان يعرض تحذير مناسب
/// للمستخدم بدل ما التذكير يفشل بصمت بدون أي ملاحظة.
enum ReminderScheduleResult {
  /// انجدول بنجاح — بيوصل حتى لو الجوال مقفول أو التطبيق مسكّر تمامًا،
  /// طالما الإذن ممنوح (نظام التشغيل هو اللي يوصّله، مو التطبيق).
  scheduled,

  /// وقت التذكير (الموعد ناقص مدة التنبيه) صار بالماضي وقت الحفظ.
  reminderAlreadyPassed,

  /// المستخدم ما منح إذن الإشعارات.
  permissionDenied,
}

/// خدمة الإشعارات — تدير الأذونات وجدولة تنبيهات المواعيد بنغمة مخصصة،
/// وتشتغل سواء التطبيق مفتوح بالمقدمة أو مقفول بالخلفية.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // قناة أندرويد v2 — قنوات أندرويد ثابتة بعد إنشائها (النغمة/الأهمية ما
  // تتغيّر بتحديث الكود)، فأي تعديل عليها يحتاج معرّف قناة جديد.
  static const _androidChannelId = 'mawid_reminders_v2';
  static const _iosSoundFile = 'mawid_chime.aiff';
  static const _androidSoundFile = 'mawid_chime';
  static const _testNotificationId = 999999999;

  /// تُستدعى مرة واحدة عند تشغيل التطبيق. تطلب الإذن تلقائيًا على iOS
  /// وتنشئ قناة أندرويد بالنغمة المخصصة.
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

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        'تذكيرات المواعيد',
        description: 'تنبيهات قبل مواعيدك',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_androidSoundFile),
        enableVibration: true,
      ),
    );
    await android?.requestNotificationsPermission();

    _ready = true;
  }

  /// يطلب إذن الإشعارات صراحة — نافع لو المستخدم رفضه أول مرة ويبي يعيد
  /// المحاولة من شاشة الإعدادات.
  Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      return await macos.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  /// يتحقق من حالة الإذن الحالية بدون ما يطلبه من جديد — نافع لعرض حالة
  /// واضحة بشاشة الإعدادات ("مفعّلة" / "معطّلة، فعّلها من إعدادات الجوال").
  Future<bool> hasPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      return (await macos.checkPermissions())?.isEnabled ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  NotificationDetails _details({
    required String channelName,
    required String channelDescription,
  }) =>
      NotificationDetails(
        iOS: const DarwinNotificationDetails(
          // presentAlert/Badge/Sound = true يخلي البانر والنغمة يظهرون
          // حتى لو التطبيق مفتوح بالمقدمة وقت وصول التنبيه.
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _iosSoundFile,
          interruptionLevel: InterruptionLevel.active,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _iosSoundFile,
        ),
        android: AndroidNotificationDetails(
          _androidChannelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(_androidSoundFile),
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  /// يجدول تنبيهًا لموعد قبله بـ [minutesBefore] دقيقة. يشتغل التنبيه عبر
  /// نظام التشغيل مباشرة — يوصل حتى لو التطبيق مقفول أو الجوال بالخلفية،
  /// طالما الإذن ممنوح.
  Future<ReminderScheduleResult> scheduleForEvent({
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

    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return ReminderScheduleResult.permissionDenied;
    }

    final when = start.subtract(Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now())) {
      return ReminderScheduleResult.reminderAlreadyPassed;
    }

    await _plugin.zonedSchedule(
      id,
      reminderTitle,
      body != null
          ? body(title, minutesBefore)
          : '$title بعد $minutesBefore دقيقة',
      tz.TZDateTime.from(when, tz.local),
      _details(channelName: channelName, channelDescription: channelDescription),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return ReminderScheduleResult.scheduled;
  }

  /// يرسل إشعار فوري تجريبي — نافع لشاشة الإعدادات عشان تتأكد النغمة
  /// والإذن شغّالين بدون ما تنتظر موعد حقيقي.
  Future<ReminderScheduleResult> sendTestNotification() async {
    await init();
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return ReminderScheduleResult.permissionDenied;
    }
    await _plugin.show(
      _testNotificationId,
      'تذكير تجريبي 🔔',
      'هذا شكل التنبيه اللي بيوصلك قبل مواعيدك — بالنغمة والتصميم نفسه.',
      _details(
        channelName: 'تذكيرات المواعيد',
        channelDescription: 'تنبيهات قبل مواعيدك',
      ),
    );
    return ReminderScheduleResult.scheduled;
  }

  /// يلغي تنبيه موعد محذوف.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
