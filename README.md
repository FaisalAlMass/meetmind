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
  time, title) are flagged instead of silently guessed. If no time was
  stated at all, the app doesn't invent one — Save stays disabled until
  you explicitly pick a time in the same review card.
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
  الثالثة مساء", "السادسة والنصف", "إلا ربع"), period words (مساء، عصرًا،
  ظهرًا، صباحًا، بالليل — with or without tashkeel), and text with
  diacritics stripped before matching — not just the digit+"pm" pattern.
  An explicit time always outranks a same-sentence prayer name ("الساعة 3
  العصر" is 3pm, not the literal Asr prayer time).
- **Multi-participant and titled-name extraction** — "مع منى، فهد، وريم"
  captures all three, not just the first; titles/kunyas stick to the name
  they belong to in both languages ("الدكتورة منى", "أبو سلطان", "Dr.
  Ahmed", "Mrs. Sara", "شركة الاتصالات") instead of splitting into
  phantom extra participants — including two titled people joined by
  "and" with no Arabic "و" cue, and multiple separate "مع"/"with" clauses
  in the same sentence ("اجتماع مع سارة مع فريق التسويق" captures both).
  Filler words ("this"/"next"/"القادم" before a weekday, "yesterday",
  "every"/recurring words, bare time-like tokens with no marker word)
  are filtered instead of showing up as fake participants. Locations are
  recognized via both "في الرياض" and the attached "بـ" prefix
  ("بالخبر", but not common non-location adverbs like "بالضبط"), and
  topic phrases ("لمناقشة…", "بخصوص…", "about…", "regarding…") are
  excluded from both fields instead of being swallowed into them.
  "نصف الليل"/"منتصف الليل"/"midnight"/"noon" are understood as exact
  times, and malformed input (invalid hours, phone numbers, bare year
  numbers) is safely ignored rather than misread.
- **Local notifications** — reminders with a configurable lead time (5,
  10, 15, 30, or 60 minutes before), a custom notification tone, and
  delivery whether the app is open in the foreground or fully closed in
  the background — fully local (no server dependency). The Notifications
  screen surfaces the OS permission status directly (with a one-tap link
  to system settings if it's off) and a "try the tone now" test button.
- **Cloud-synced events (Firebase)** — events are stored in Cloud
  Firestore under an automatic, invisible anonymous account, so they
  survive deleting and reinstalling the app on the same device (not just
  a local cache). The agenda listens to Firestore live (not a one-shot
  fetch), so an add/edit/delete updates the UI from the write itself
  instead of a separate re-fetch afterward. From Profile, a user can
  optionally link an email + password to that account to make events
  recoverable from *any* device, not just the one they were created on.
- **Four-tab home** — Today (agenda + quick capture), Calendar (month
  grid + its own natural-language quick-add, sharing the same capture
  pipeline and review card as Today), Search, and Profile (name,
  language, theme, notifications, cloud backup), all backed by the same
  cloud-synced store.
- **Dark mode** and a **Material 3** interface, themed from the
  organization's approved brand palette (primary green, gold and
  emerald accents) with hand-verified WCAG-AA contrast on every color
  pairing.

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
- [package_info_plus](https://pub.dev/packages/package_info_plus) to
  read the running app's real version for display in Profile

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

**Real iOS device installs with a free Apple ID (no paid Developer
Program) expire after 7 days** — this is an Apple signing policy, not
something the project can work around. When the app stops opening, run
`flutter run --release -d <device>` again to re-sign and reinstall. The
`Runner` Xcode scheme's Run action defaults to the **Release**
configuration specifically so that pressing Run in Xcode (e.g. while
troubleshooting a signing/trust prompt) can't silently reinstall a
Debug build — Debug builds refuse to launch at all unless Xcode's
tooling is attached, which looks like the app crashing to a white
screen when tapped from the home screen.

### Testing

```bash
flutter test
```

`test/parser_test.dart` is a regression suite for the natural-language
parser: digit normalization, spelled-out Arabic hour words, period
words, prayer-name-vs-explicit-time priority, comma-separated and
multi-clause participant lists, titled/kunya name extraction in both
languages (including abbreviated English titles like "Dr." and doubled
Arabic abbreviations like "ود."), "بـ"-prefixed locations, Arabic and
English topic-phrase exclusion, filler/date-modifier words not leaking
into names, "day after tomorrow"/"بعد بكرة", named times ("noon"/
"midnight"/"نصف الليل"), weekday names resolving to the correct next
occurrence regardless of hamza spelling ("الاحد" same as "الأحد"),
robustness against malformed input (phone numbers, invalid hours, bare
years), and English duration phrasing — run it after touching
`NaturalLanguageEventParser` or `DateReferenceParser`. It was built up
by running large batches (110+ sentences so far, in four rounds) of
varied real-world phrasings through the parser and fixing whatever
broke; the same approach is the fastest way to catch the next gap.

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
│           ├── calendar_screen.dart       # Month grid + NL quick-add
│           ├── search_screen.dart
│           ├── profile_screen.dart        # Includes the cloud-backup card
│           ├── notification_settings_screen.dart
│           ├── event_detail_screen.dart
│           ├── edit_event_screen.dart
│           ├── providers.dart
│           └── widgets/
│               └── capture_confirmation_card.dart  # Shared capture review card
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
- Relative dates beyond "tomorrow"/"day after tomorrow" (`"بعد اسبوع"`,
  "next week") aren't understood — correctly flagged low-confidence
  rather than guessed wrong, but the date still defaults to today.
- A time with a bare digit and no am/pm cue (`"الساعة 9"`) defaults to
  AM without flagging low-confidence, even though the period was
  genuinely guessed, not stated.
- Two-word names with no recognized title/kunya and no comma between
  them (`"سارة أحمد"`, `"John Smith"`) still split into two separate
  participants — there's no reliable way to distinguish "one compound
  name" from "two people" without a title cue or a separator.
- Capture requires an explicit "مع"/"with" marker before a name —
  "Call Sarah at 5pm" or "احجز موعد الساعة 5" with no one named falls
  back to using the whole sentence as the title (correctly flagged
  low-confidence) rather than guessing a name from context.
- Explicit time ranges (`"من الساعة 3 إلى 5"`, `"from 3 to 5"`) aren't
  recognized as defining the event's duration — only the start time is
  read, and duration falls back to the default 1 hour unless a separate
  `"لمدة"`/`"for"` phrase is also given.
- Spelled-out Arabic minutes (`"سبعة وعشرين دقيقة"`) aren't recognized —
  only spelled-out *hours*, optionally with `"والنصف"`/`"وربع"`/`"إلا
  ربع"`, are.
- "at" isn't recognized as a location marker (only "في"/"in" and the
  attached "بـ" prefix are) — English locations phrased as "at the
  Ritz" are missed, since "at" is already the English time marker.
- The default anonymous cloud account only reliably survives a
  reinstall on the *same* device (its credential lives in the OS
  keychain). Recovering events on a new or wiped device requires having
  linked an email first, from Profile.

## Versioning

`pubspec.yaml`'s `version:` field (`X.Y.Z+build`) follows semantic
versioning: **patch** (`X.Y.Z+1`) for bug fixes, **minor** (`X.Y+1.0`)
for new or changed features, **major** (`X+1.0.0`) for a breaking or
ground-up change. The build number after `+` increments on every bump
regardless of tier (it's what App Store/Play Store track internally).

Each version bump is tagged in git (`vX.Y.Z`), so reverting to a known
version is one command:
```bash
git checkout vX.Y.Z
```

| Version | Notes |
| --- | --- |
| `1.0.0` | First tagged baseline. |
| `1.1.0` | Motion/brand-identity UI pass; live Firestore sync + parallel app startup; weekday-parsing fix and required-time prompt for the capture flow. |
| `1.2.0` | Home tab (formerly "Today") now shows "Upcoming events" filtered from today's date onward instead of the full event history. |
| `1.2.1` | Profile's version number now reads the real build version (`package_info_plus`) instead of a hardcoded `'1.0.0'` string. |

## Author

By M.Eng Faisal AlMass
