import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meetmind/capabilities/calendar/calendar_capability.dart';
import 'package:meetmind/capabilities/calendar/presentation/providers.dart';
import 'package:meetmind/capabilities/calendar/presentation/today_screen.dart';
import 'package:meetmind/capabilities/calendar/presentation/welcome_screen.dart';
import 'package:meetmind/core/assistant/contracts.dart';
import 'package:meetmind/firebase_options.dart';
import 'package:meetmind/shared/localization/app_strings.dart';
import 'package:meetmind/shared/localization/locale_provider.dart';
import 'package:meetmind/shared/services/cloud_auth_service.dart';
import 'package:meetmind/shared/services/notification_service.dart';
import 'package:meetmind/shared/services/user_service.dart';
import 'package:meetmind/shared/theme/app_theme.dart';
import 'package:meetmind/shared/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);

  // تجهيز Firebase + تسجيل دخول مجهول تلقائي (يحمي المواعيد من الضياع لو
  // انحذف التطبيق أو انثبّت من جديد بنفس الجهاز).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CloudAuthService.instance.ensureSignedIn();

  // تجهيز خدمة الإشعارات وطلب الإذن عند التشغيل.
  await NotificationService.instance.init();

  // تجهيز التخزين المحلي (يبقى بعد إغلاق التطبيق).
  final prefs = await SharedPreferences.getInstance();

  // Capability modules register with the core here. Adding a future assistant
  // (Meeting, Email, Travel…) is one more `..register(...)` line — no redesign.
  final registry = CapabilityRegistry()..register(CalendarCapability());

  runApp(
    ProviderScope(
      overrides: [
        capabilityRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MeetMindApp(),
    ),
  );
}

class MeetMindApp extends ConsumerWidget {
  const MeetMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userName = ref.watch(userNameProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(appStringsProvider);

    return MaterialApp(
      title: s.appName,
      debugShowCheckedModeBanner: false,
      theme: MeetMindTheme.light(),
      darkTheme: MeetMindTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection:
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        // لو ما فيه اسم محفوظ → شاشة الترحيب. لو فيه اسم → التطبيق.
        child: userName == null ? const WelcomeScreen() : const HomeShell(),
      ),
    );
  }
}