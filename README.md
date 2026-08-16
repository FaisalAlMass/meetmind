# MeetMind

A bilingual (Arabic/English) smart calendar assistant for Flutter. Type or
speak an event in plain language — in Arabic or English, relative or
absolute, Hijri or Gregorian — and MeetMind understands it, flags anything
it's unsure about, and asks you to confirm before it saves anything.

## Features

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
- **Local notifications** — configurable reminder lead time (5–60
  minutes), fully local (no server dependency).
- **Calendar, agenda, and search views** — a month grid, a daily agenda,
  and a search screen, all backed by the same local store.
- **Dark mode** and a **Material 3** interface.
- **Fully offline** — all data is stored locally on-device; no backend or
  account required.

## Tech stack

- [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) for state
  management
- [shared_preferences](https://pub.dev/packages/shared_preferences) for
  local persistence
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
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

## Project structure

```
lib/
├── main.dart                        # App entry point, locale & theme wiring
├── core/                            # Framework-agnostic contracts & models
│   ├── models.dart
│   └── assistant/contracts.dart     # EventParser, PrayerTimeProvider, Capability
├── capabilities/
│   └── calendar/                    # The calendar capability (first of many)
│       ├── data/sources.dart        # Repositories + natural-language parser
│       ├── domain/calendar_domain.dart
│       └── presentation/            # Screens & Riverpod providers
└── shared/
    ├── localization/                # AppStrings (ar/en), locale, Hijri dates
    ├── services/                    # Notifications, speech, user prefs
    └── theme/                       # Material 3 theme
```

The app is built around a pluggable **capability** model — `Calendar` is
the first capability; future ones (Meeting, Email, Travel, …) register
with the same `CapabilityRegistry` without touching existing code.

## Known limitations

- Numeric dates (`20/8`) are parsed as day/month, not month/day.
- Purely numeric Hijri dates (`5/2/1448`) aren't recognized — use the
  month name instead (`5 صفر` / `5 Safar`).
- Recurring events aren't supported yet.

## Author

By M.Eng Faisal AlMass
