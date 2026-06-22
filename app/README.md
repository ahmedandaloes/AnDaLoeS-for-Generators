# AnDaLoeS — Flutter app

The mobile app (Android + iOS) for renting generators. Feature-first
architecture; see `../docs/ARCHITECTURE.md`.

## Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.4+)
- Android Studio (for the Android emulator)
- A Mac with Xcode — only needed for iOS (you can develop on Android first)

## First-time setup
This repo contains the Dart source (`lib/`) and config. Generate the native
platform folders and dependencies on your machine:

```bash
cd app

# 1. Create the android/ios/etc. platform folders (keeps existing lib/).
flutter create . --org com.andaloes --project-name andaloes \
  --platforms=android,ios

# 2. Install dependencies.
flutter pub get

# 3. Generate the Arabic/English localizations (creates lib/l10n/app_localizations.dart).
flutter gen-l10n

# 4. Run it.
flutter run
```

> `flutter run` also triggers `gen-l10n` automatically, so step 3 is mainly so
> `flutter analyze` passes before the first run.

## Configuration
Supabase URL + publishable key live in `lib/core/config/env.dart` (safe to ship
— protected by RLS). To override without editing code:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

## Structure
```
lib/
├── core/            # config (Supabase, env), theme, routing, localization
├── features/
│   ├── auth/        # phone + OTP login
│   ├── generators/  # browse generators (home)
│   └── profile/     # profile, language switch, sign out
├── l10n/            # app_en.arb, app_ar.arb (+ generated localizations)
└── main.dart
```

## Notes
- Login needs the **Phone** auth provider + an SMS gateway enabled in Supabase.
- The home screen reads from the `generators` table; RLS only returns units
  whose company is approved, so it will be empty until you add data.
