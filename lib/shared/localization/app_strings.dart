import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';

/// كل نصوص واجهة المستخدم بالعربي والإنجليزي في مكان واحد.
class AppStrings {
  factory AppStrings.of(String languageCode) =>
      languageCode == 'en' ? AppStrings._en() : AppStrings._ar();

  AppStrings._ar()
      : languageCode = 'ar',
        appName = 'موعد',
        navToday = 'اليوم',
        navCalendar = 'التقويم',
        navSearch = 'بحث',
        navProfile = 'أنت',
        captureHint = 'اكتب موعدًا…',
        notUnderstood = 'ما قدرت أفهمها كموعد — جرّب تذكر يوم ووقت.',
        noEventsYet = 'لا مواعيد بعد. أضِف موعدًا من الأعلى.',
        loadFailed = 'تعذّر التحميل',
        confirmBeforeSave = 'تأكيد قبل الحفظ',
        saveEvent = 'حفظ الموعد',
        discard = 'تجاهل',
        noTimeStatedPrompt = 'لم يُذكر وقت الاجتماع — حدده قبل الحفظ',
        pickTimeAction = 'تحديد الوقت',
        deleteEventTitle = 'حذف الموعد',
        cancel = 'إلغاء',
        delete = 'حذف',
        focusTime = 'وقت تركيز',
        defaultUserName = 'المستخدم',
        defaultInitial = '؟',
        newEvent = 'موعد جديد',
        eventTitleLabel = 'عنوان الموعد',
        timeLabel = 'الوقت',
        addAction = 'إضافة',
        noEventsThisDay = 'لا مواعيد في هذا اليوم',
        editEventTitle = 'تعديل الموعد',
        save = 'حفظ',
        dateLabel = 'التاريخ',
        saveChanges = 'حفظ التعديلات',
        eventUpdated = 'تم تحديث الموعد',
        eventDetailsTitle = 'تفاصيل الموعد',
        editTooltip = 'تعديل',
        participantsLabel = 'المشاركون',
        locationLabel = 'المكان',
        typeLabel = 'النوع',
        searchHint = 'ابحث بالاسم أو التاريخ (بكرة، الأحد، 5 صفر)…',
        searchEmptyPrompt =
            'ابحث بالاسم، المشارك، الموقع — أو تاريخ زي "بكرة" أو "5 صفر"',
        welcomeTitle = 'أهلًا بك في موعد',
        welcomeSubtitle = 'مساعدك الذكي للمواعيد. وش نناديك؟',
        yourNameLabel = 'اسمك',
        yourNameHint = 'مثال: فيصل',
        letsStart = 'يلا نبدأ',
        editNameTooltip = 'تعديل الاسم',
        meetmindUser = 'مستخدم موعد',
        logoutLabel = 'تسجيل خروج',
        logoutConfirmTitle = 'تسجيل الخروج',
        logoutConfirmBody =
            'مواعيدك المحفوظة تبقى بأمان — بس لازم تدخل اسمك من جديد.',
        settingsSection = 'الإعدادات',
        darkMode = 'الوضع الداكن',
        onLabel = 'مُفعّل',
        offLabel = 'مُطفأ',
        languageLabel = 'اللغة',
        arabicName = 'العربية',
        englishName = 'English',
        notificationsLabel = 'الإشعارات',
        aboutSection = 'عن التطبيق',
        appTagline = 'مساعدك الذكي للمواعيد',
        versionLabel = 'الإصدار',
        enableNotifications = 'تفعيل التنبيهات',
        notifEnabledSubtitle = 'ستصلك تذكيرات قبل مواعيدك',
        notifDisabledSubtitle = 'التنبيهات موقوفة',
        reminderTimeLabel = 'وقت التذكير',
        reminderInfoNote = 'يُطبّق وقت التذكير على المواعيد الجديدة التي تضيفها.',
        notifReminderTitle = 'تذكير بموعد',
        notifChannelName = 'تذكيرات المواعيد',
        notifChannelDesc = 'تنبيهات قبل مواعيدك',
        notifPermissionGrantedTitle = 'الإشعارات مفعّلة',
        notifPermissionGrantedBody =
            'بتوصلك التذكيرات حتى لو التطبيق مقفول أو الجوال بالخلفية.',
        notifPermissionDeniedTitle = 'إذن الإشعارات معطّل',
        notifPermissionDeniedBody =
            'فعّله من إعدادات النظام عشان توصلك تذكيرات مواعيدك.',
        openSystemSettings = 'افتح إعدادات النظام',
        tryToneNow = 'جرّب النغمة الآن',
        testNotificationSent = 'تم إرسال تنبيه تجريبي',
        reminderTimePassed =
            'وقت التذكير قريب جدًا من الآن — ما قدرنا نجدوله لهذا الموعد.',
        notifPermissionDeniedSnack =
            'إذن الإشعارات مرفوض — فعّله من إعدادات النظام عشان توصلك التذكيرات.',
        cloudBackupTitle = 'أمّن نسختك الاحتياطية',
        cloudBackupBody =
            'مواعيدك محفوظة تلقائيًا وتنجو من حذف التطبيق على هذا الجهاز. '
            'لكن لو ضاع جوالك أو غيّرته، ما تقدر تسترجعها بدون بريد مرتبط.',
        cloudBackupSecuredTitle = '✓ نسختك الاحتياطية مؤمّنة',
        cloudBackupSecuredBody =
            ((email) => 'مرتبطة بـ $email — تقدر تسترجع مواعيدك من أي جهاز.'),
        linkEmailAction = 'أمّن بالبريد الإلكتروني',
        emailLabel = 'البريد الإلكتروني',
        passwordLabel = 'كلمة المرور',
        linkEmailSuccess = 'تم تأمين نسختك الاحتياطية بنجاح',
        linkEmailError =
            'تعذّر الربط — تأكد من صحة البريد وإن كلمة المرور 6 أحرف على الأقل',
        listSeparator = '، ',
        weekdayDatePattern = 'EEEE، d MMMM',
        weekdayDateYearPattern = 'EEEE، d MMMM y',
        voiceInputTooltip = 'تحدث الآن',
        listeningHint = 'أستمع… تكلم الآن',
        voiceUnavailable = 'التعرف الصوتي غير متاح على هذا الجهاز',
        greeting = ((name) => 'صباح الخير، $name'),
        eventsCount = ((n) => '$n مواعيد'),
        conflictsWith = ((n) => 'يتعارض مع $n موعد'),
        confirmDeleteBody = ((title) => 'هل تريد حذف "$title"؟'),
        deletedSnack = ((title) => 'تم حذف "$title"'),
        withParticipants = ((list) => 'مع $list'),
        noResultsFor = ((query) => 'لا نتائج لـ "$query"'),
        reminderBefore = ((m) => 'قبل $m دقيقة'),
        reminderSummary = ((m) => 'التذكير قبل $m دقيقة'),
        notifBody = ((title, m) => '$title بعد $m دقيقة');

  AppStrings._en()
      : languageCode = 'en',
        appName = "Maw'id",
        navToday = 'Today',
        navCalendar = 'Calendar',
        navSearch = 'Search',
        navProfile = 'You',
        captureHint = 'Type an event…',
        notUnderstood =
            "Couldn't understand that as an event — try mentioning a day and time.",
        noEventsYet = 'No events yet. Add one from above.',
        loadFailed = 'Failed to load',
        confirmBeforeSave = 'Confirm before saving',
        saveEvent = 'Save event',
        discard = 'Discard',
        noTimeStatedPrompt = 'No time was mentioned — set it before saving',
        pickTimeAction = 'Pick time',
        deleteEventTitle = 'Delete event',
        cancel = 'Cancel',
        delete = 'Delete',
        focusTime = 'Focus time',
        defaultUserName = 'User',
        defaultInitial = '?',
        newEvent = 'New event',
        eventTitleLabel = 'Event title',
        timeLabel = 'Time',
        addAction = 'Add',
        noEventsThisDay = 'No events on this day',
        editEventTitle = 'Edit event',
        save = 'Save',
        dateLabel = 'Date',
        saveChanges = 'Save changes',
        eventUpdated = 'Event updated',
        eventDetailsTitle = 'Event details',
        editTooltip = 'Edit',
        participantsLabel = 'Participants',
        locationLabel = 'Location',
        typeLabel = 'Type',
        searchHint = 'Search by name or date (tomorrow, Sunday, 5 Safar)…',
        searchEmptyPrompt =
            'Search by name, participant, location — or a date like '
            '"tomorrow" or "5 Safar"',
        welcomeTitle = "Welcome to Maw'id",
        welcomeSubtitle = 'Your smart scheduling assistant. What should we call you?',
        yourNameLabel = 'Your name',
        yourNameHint = 'e.g. John',
        letsStart = "Let's start",
        editNameTooltip = 'Edit name',
        meetmindUser = "Maw'id user",
        logoutLabel = 'Log out',
        logoutConfirmTitle = 'Log out',
        logoutConfirmBody =
            "Your saved events stay safe — you'll just need to enter your "
            "name again.",
        settingsSection = 'Settings',
        darkMode = 'Dark mode',
        onLabel = 'On',
        offLabel = 'Off',
        languageLabel = 'Language',
        arabicName = 'العربية',
        englishName = 'English',
        notificationsLabel = 'Notifications',
        aboutSection = 'About the app',
        appTagline = 'Your smart scheduling assistant',
        versionLabel = 'Version',
        enableNotifications = 'Enable notifications',
        notifEnabledSubtitle = "You'll get reminders before your events",
        notifDisabledSubtitle = 'Notifications are off',
        reminderTimeLabel = 'Reminder time',
        reminderInfoNote = 'The reminder time applies to new events you add.',
        notifReminderTitle = 'Event reminder',
        notifChannelName = 'Event reminders',
        notifChannelDesc = 'Reminders before your events',
        notifPermissionGrantedTitle = 'Notifications are on',
        notifPermissionGrantedBody =
            "You'll get reminders even if the app is closed or the phone is "
            'locked.',
        notifPermissionDeniedTitle = 'Notifications are off',
        notifPermissionDeniedBody =
            'Turn them on in system settings to get reminders before your '
            'events.',
        openSystemSettings = 'Open system settings',
        tryToneNow = 'Try the tone now',
        testNotificationSent = 'Test notification sent',
        reminderTimePassed =
            "The reminder time is too close to now — couldn't schedule it "
            'for this event.',
        notifPermissionDeniedSnack =
            'Notification permission denied — enable it in system settings '
            'to get reminders.',
        cloudBackupTitle = 'Secure your backup',
        cloudBackupBody =
            'Your events are saved automatically and survive deleting the '
            "app on this device. But if you lose or switch phones, you "
            "can't recover them without a linked email.",
        cloudBackupSecuredTitle = '✓ Your backup is secured',
        cloudBackupSecuredBody = ((email) =>
            'Linked to $email — you can recover your events on any device.'),
        linkEmailAction = 'Secure with email',
        emailLabel = 'Email',
        passwordLabel = 'Password',
        linkEmailSuccess = 'Your backup is now secured',
        linkEmailError =
            'Could not link — check the email and that the password is at '
            'least 6 characters',
        listSeparator = ', ',
        weekdayDatePattern = 'EEEE, d MMMM',
        weekdayDateYearPattern = 'EEEE, d MMMM y',
        voiceInputTooltip = 'Speak now',
        listeningHint = 'Listening… speak now',
        voiceUnavailable = "Voice input isn't available on this device",
        greeting = ((name) => 'Good morning, $name'),
        eventsCount = ((n) => '$n events'),
        conflictsWith = ((n) => 'Conflicts with $n events'),
        confirmDeleteBody = ((title) => 'Delete "$title"?'),
        deletedSnack = ((title) => 'Deleted "$title"'),
        withParticipants = ((list) => 'with $list'),
        noResultsFor = ((query) => 'No results for "$query"'),
        reminderBefore = ((m) => '$m minutes before'),
        reminderSummary = ((m) => 'Reminder $m minutes before'),
        notifBody = ((title, m) => '$title in $m minutes');

  final String languageCode;
  final String appName;
  final String navToday;
  final String navCalendar;
  final String navSearch;
  final String navProfile;
  final String captureHint;
  final String notUnderstood;
  final String noEventsYet;
  final String loadFailed;
  final String confirmBeforeSave;
  final String saveEvent;
  final String discard;
  final String noTimeStatedPrompt;
  final String pickTimeAction;
  final String deleteEventTitle;
  final String cancel;
  final String delete;
  final String focusTime;
  final String defaultUserName;
  final String defaultInitial;
  final String newEvent;
  final String eventTitleLabel;
  final String timeLabel;
  final String addAction;
  final String noEventsThisDay;
  final String editEventTitle;
  final String save;
  final String dateLabel;
  final String saveChanges;
  final String eventUpdated;
  final String eventDetailsTitle;
  final String editTooltip;
  final String participantsLabel;
  final String locationLabel;
  final String typeLabel;
  final String searchHint;
  final String searchEmptyPrompt;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String yourNameLabel;
  final String yourNameHint;
  final String letsStart;
  final String editNameTooltip;
  final String meetmindUser;
  final String logoutLabel;
  final String logoutConfirmTitle;
  final String logoutConfirmBody;
  final String settingsSection;
  final String darkMode;
  final String onLabel;
  final String offLabel;
  final String languageLabel;
  final String arabicName;
  final String englishName;
  final String notificationsLabel;
  final String aboutSection;
  final String appTagline;
  final String versionLabel;
  final String enableNotifications;
  final String notifEnabledSubtitle;
  final String notifDisabledSubtitle;
  final String reminderTimeLabel;
  final String reminderInfoNote;
  final String notifReminderTitle;
  final String notifChannelName;
  final String notifChannelDesc;
  final String notifPermissionGrantedTitle;
  final String notifPermissionGrantedBody;
  final String notifPermissionDeniedTitle;
  final String notifPermissionDeniedBody;
  final String openSystemSettings;
  final String tryToneNow;
  final String testNotificationSent;
  final String reminderTimePassed;
  final String notifPermissionDeniedSnack;
  final String cloudBackupTitle;
  final String cloudBackupBody;
  final String cloudBackupSecuredTitle;
  final String linkEmailAction;
  final String emailLabel;
  final String passwordLabel;
  final String linkEmailSuccess;
  final String linkEmailError;
  final String listSeparator;
  final String weekdayDatePattern;
  final String weekdayDateYearPattern;
  final String voiceInputTooltip;
  final String listeningHint;
  final String voiceUnavailable;

  final String Function(String name) greeting;
  final String Function(int n) eventsCount;
  final String Function(int n) conflictsWith;
  final String Function(String title) confirmDeleteBody;
  final String Function(String title) deletedSnack;
  final String Function(String list) withParticipants;
  final String Function(String query) noResultsFor;
  final String Function(int minutes) reminderBefore;
  final String Function(int minutes) reminderSummary;
  final String Function(String title, int minutes) notifBody;
  final String Function(String email) cloudBackupSecuredBody;
}

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return AppStrings.of(locale.languageCode);
});
