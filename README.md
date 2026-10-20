# EduTranslate

EduTranslate is an Android-first AI language-learning companion for Malaysian primary school students in Years 1–6. Gemini through Google AI Studio translates English, Bahasa Melayu, and Chinese text, and generates a short definition, child-friendly explanation, and example sentence. Saved vocabulary, flashcards, history, favourites, and review counts remain on-device.

## Configure Gemini

Create an API key in Google AI Studio and pass it as a compile-time value for local testing:

```sh
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your-key
```

The current model is Gemini 3.8 Flash (`gemini-3.8-flash`). The key is compiled into the app, so the app must be rebuilt with the `--dart-define` after setting or changing it; hot reload alone does not update it. If the app reports that Gemini is not configured, confirm the launch command includes that define. Chinese requests use Simplified Chinese (`zh-CN`); English and Malay use `en` and `ms`.

**Key and privacy note:** A key compiled into a mobile app can be extracted. Do not distribute a release with a live key; move Gemini requests behind a server endpoint before sharing the app. Translation text is sent to Google. Avoid entering names or other identifying/private student information. Google AI Studio free-tier data handling differs from the paid tier; check Google's current terms for the project before use with students.

## Release readiness

- Android release builds are unsigned unless `android/key.properties` and the referenced upload keystore are configured. The release build never falls back to the debug signing key.
- Create an upload key with `keytool -genkeypair -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`, then create the ignored `android/key.properties` file:

  ```properties
  storeFile=upload-keystore.jks
  storePassword=YOUR_STORE_PASSWORD
  keyAlias=upload
  keyPassword=YOUR_KEY_PASSWORD
  ```

  Keep both files private and backed up. Never commit the keystore or its passwords.
- Replace the Android and iOS `com.example` application identifiers with identifiers registered to your publishing account before submission.
- Build iOS on macOS with Xcode and configure Apple signing; this Windows workspace cannot produce or verify an iOS installer.
- Do not publish a client-embedded Gemini key. A backend proxy, privacy policy, and review of applicable child-data/store policies are required before distributing this app publicly.
- Use `flutter build apk --release --split-per-abi` to produce smaller device-specific APKs, or `flutter build appbundle --release` for Google Play.

## Current behavior

- Gemini generates translations and learning content at request time. Results are labelled AI-generated and may be incorrect.
- The selected SJKC year level is sent as guidance for the explanation. It is not a claim that a word belongs to an official curriculum level.
- Translation requests require an internet connection and a configured API key.
- SQLite stores translation history, saved vocabulary, flashcards/review data, and preferences locally.
- The former local dictionary and JSON import flow have been removed. Existing dictionary rows are dropped by the database v1-to-v2 migration; other learning data is preserved.
- Live camera OCR recognizes English/Malay (Latin script) or Chinese (when Chinese is selected as the source language) on-device. Tap a detected word or line to place it in the translator, review it, then translate. Camera frames are processed on-device and are not saved; only text you submit for translation is sent to Google. Still image capture, speech recognition, and cloud sync are not included.

## Run and validate

```sh
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your-key
flutter test
flutter analyze
```

The app uses `sqflite` on Android/iOS and `sqflite_common_ffi` on Windows, macOS, and Linux. Web storage is not configured.

## Architecture

```text
lib/
  app/                         application bootstrap and navigation
  config/                      Gemini model and API-key configuration
  core/                        shared language identifiers
  data/local/                  SQLite database and schema
  data/repositories/           learning repository and SQLite adapter
  features/translator/         Gemini provider, live camera OCR, result model, UI
  features/vocabulary/         saved words
  features/flashcards/         review flow
  features/history/            local translation history
  features/settings/           language, year, and AI privacy preferences
```
