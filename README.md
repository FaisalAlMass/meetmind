# MeetMind (موعد / Maw'id)

A bilingual (Arabic/English) smart calendar assistant for Flutter. Type or
speak an event in plain language — in Arabic or English, relative or
absolute, Hijri or Gregorian — and MeetMind understands it, flags anything
it's unsure about, and asks you to confirm before it saves anything.

`meetmind` is the Dart package/repo name; the app itself is branded
**موعد** ("Maw'id" — Arabic for "appointment") on-device, in both the app
icon and every in-app string.

## Features

- **Onboarding** — a first-launch welcome screen captures the user's name
  (stored locally); every screen after that goes straight to the app.
- **Natural-language event capture** — "اجتماع مع سارة بكرة الساعة 3 مساءً"
  or "Meeting with Sara tomorrow at 3pm" both work. Understands relative
  dates (today/tomorrow/weekday names), absolute dates by name or number,
  and both the Gregorian and Hijri calendars.
- **Voice input** — speak an event instead of typing it; transcription
  happens live and follows the app's current language.
- **Confirm-before-save** — every captured event goes through a review
  card before it's written to the calendar; low-confidence fields (date,
  time, title) are flagged instead of silently guessed.
- **Conflict detection** — new events are checked against your existing
  schedule, with alternative time slots suggested on overlap.
- **Bilingual UI (Arabic/English)** — a single toggle switches the entire
  interface, including layout direction (RTL/LTR).
- **Hijri + Gregorian dates** — the Hijri date is shown as the primary
  date everywhere, with the Gregorian date alongside it.
- **Prayer-time-aware scheduling** — events can be scheduled relative to
  prayer times (e.g. "بعد العصر" / "after Asr"), calculated astronomically
  via the Umm al-Qura method.
- **Robust Arabic time parsing** — understands Eastern Arabic-Indic digits
  (٣، ٥، ١٠…) as well as Western digits, spelled-out hour words ("الساعة
  الثالثة مساء", "السادسة والنصف", "إلا ربع"), and period words (مساء،
  عصرًا، صباحًا، بالليل) — not just the digit+"pm" pattern.
- **Local notifications** — reminders with a configurable lead time (5,
  10, 15, 30, or 60 minutes before), a custom notification tone, and
  delivery whether the app is open in the foreground or fully closed in
  the background — fully local (no server dependency). The Notifications
  screen surfaces the OS permission status directly (with a one-tap link
  to system settings if it's off) and a "try the tone now" test button.
- **Cloud-synced events (Firebase)** — events are stored in Cloud
  Firestore under an automatic, invisible anonymous account, so they
  survive deleting and reinstalling the app on the same device (not just
  a local cache). From Profile, a user can optionally link an email +
  password to that account to make events recoverable from *any* device,
  not just the one they were created on.
- **Four-tab home** — Today (agenda + quick capture), Calendar (month
  grid), Search, and Profile (name, language, theme, notifications, cloud
  backup), all backed by the same cloud-synced store.
- **Dark mode** and a **Material 3** interface.

## Tech stack

- [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) for state
  management
- [shared_preferences](https://pub.dev/packages/shared_preferences) for
  local persistence
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [app_settings](https://pub.dev/packages/app_settings) to deep-link into
  the OS notification settings screen
- [firebase_core](https://pub.dev/packages/firebase_core),
  [firebase_auth](https://pub.dev/packages/firebase_auth), and
  [cloud_firestore](https://pub.dev/packages/cloud_firestore) for
  cloud-synced events (anonymous auth + optional email link)
- [speech_to_text](https://pub.dev/packages/speech_to_text) for voice input
- [hijri](https://pub.dev/packages/hijri) for Hijri calendar conversion
- [adhan](https://pub.dev/packages/adhan) for astronomical prayer times
- [table_calendar](https://pub.dev/packages/table_calendar) for the month
  view
- [intl](https://pub.dev/packages/intl) for date/number localization

## Getting started

### Prerequisites

- Flutter SDK (stable channel) with Dart `^3.12.2`
- Xcode (for iOS/macOS) and/or Android Studio (for Android), as needed

### Setup

```bash
flutter pub get
flutter run
```

Voice input requires microphone and speech-recognition permissions,
already declared for iOS, macOS, and Android. On iOS Simulator, on-device
speech recognition is unreliable — test on a physical device, or run the
macOS target for a real-microphone test on desktop.

Notifications require their own OS permission (requested automatically on
first launch). If a reminder doesn't arrive, check Profile → Notifications
— it shows whether the permission is actually granted, with a direct link
to the system settings screen if not.

Events sync to a Firebase project (Firestore + Anonymous/Email auth
enabled). `lib/firebase_options.dart` and the platform config files
(`ios/Runner/GoogleService-Info.plist`,
`android/app/google-services.json`) are already wired up for this
project's own Firebase backend (`mawid-8bba0`) — to point the app at a
different Firebase project, replace those three with your own (via the
Firebase console or the `flutterfire` CLI) and re-run `flutter pub get`.

### Testing

```bash
flutter test
```

`test/parser_test.dart` is a regression suite for the natural-language
date/time parser (digit normalization, spelled-out Arabic hour words,
period words, English control cases) — run it after touching
`NaturalLanguageEventParser`.

## Project structure

```
lib/
├── main.dart                          # Entry point: Firebase init, locale/theme
│                                       #   wiring, capability registration, routing
├── firebase_options.dart              # Per-platform Firebase config (this project's backend)
├── core/                              # Framework-agnostic contracts & models
│   ├── models.dart
│   └── assistant/contracts.dart       # EventParser, PrayerTimeProvider, Capability
├── capabilities/
│   └── calendar/                      # The calendar capability (first of many)
│       ├── calendar_capability.dart   # Capability registration (id, title)
│       ├── data/
│       │   ├── sources.dart               # Natural-language parser + legacy local repo
│       │   └── cloud_event_repository.dart  # Firestore-backed EventRepository
│       ├── domain/
│       │   ├── calendar_domain.dart       # EventRepository contract + use cases
│       │   └── date_reference_parser.dart  # Shared relative/absolute date parsing
│       └── presentation/              # Screens & Riverpod providers
│           ├── welcome_screen.dart        # First-launch name capture
│           ├── today_screen.dart          # HomeShell (bottom nav) + agenda
│           ├── calendar_screen.dart       # Month grid
│           ├── search_screen.dart
│           ├── profile_screen.dart        # Includes the cloud-backup card
│           ├── notification_settings_screen.dart
│           ├── event_detail_screen.dart
│           ├── edit_event_screen.dart
│           └── providers.dart
└── shared/
    ├── localization/                  # AppStrings (ar/en), locale, Hijri dates
    ├── services/                      # Notifications, speech, auth, user prefs
    │   ├── cloud_auth_service.dart        # Anonymous auth + optional email link
    │   ├── notification_service.dart
    │   ├── notification_settings.dart
    │   ├── speech_service.dart
    │   └── user_service.dart
    └── theme/                         # Material 3 theme, app mark, theme mode
        ├── app_theme.dart
        ├── mawid_mark.dart
        └── theme_provider.dart

test/
└── parser_test.dart                   # Regression suite for the NL date/time parser
```

The app is built around a pluggable **capability** model — `Calendar` is
the first capability; future ones (Meeting, Email, Travel, …) register
with the same `CapabilityRegistry` without touching existing code.

## Known limitations

- Numeric dates (`20/8`) are parsed as day/month, not month/day.
- Purely numeric Hijri dates (`5/2/1448`) aren't recognized — use the
  month name instead (`5 صفر` / `5 Safar`).
- Recurring events aren't supported yet.
- The default anonymous cloud account only reliably survives a
  reinstall on the *same* device (its credential lives in the OS
  keychain). Recovering events on a new or wiped device requires having
  linked an email first, from Profile.

## Author

By M.Eng Faisal AlMass
