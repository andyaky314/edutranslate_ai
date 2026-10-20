# EduTranslate

EduTranslate is an Android-first language-learning companion for Malaysian SJKC
students in Years 1–6. The first vertical slice is a local-first dictionary
translator, saved vocabulary, flashcards, translation history, and dictionary
import for English (`en`), Bahasa Melayu (`ms`), and Chinese (`zh`).

## Current MVP behavior

- SQLite stores dictionary entries, translation history, vocabulary, review
  counts, favourites, and the preferred learning language and SJKC year level.
- The translator looks up one word in the imported dictionary and only uses
  published entries that match the selected year level, or any year when `All
  years` is selected. Unsupported lookups are reported; the app does not return
  demo or invented translations.
- There is no AI provider configured. `TranslationProvider` is the replaceable
  boundary for a future AI or other translation adapter. No student text is
  sent to a remote service.
- OCR, text-to-speech, speech recognition, account sync, and curriculum
  authoring are not part of this MVP.
- SQLite schema version 1 is created on first launch. Future persistent changes
  must increment the schema version and add an `onUpgrade` migration.

## Run and validate

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

The app uses `sqflite` on Android/iOS and `sqflite_common_ffi` on Windows, macOS,
and Linux. Web storage is not configured. The Android minimum SDK remains
Flutter's configured default in `android/app/build.gradle.kts`.

## Dictionary JSON contract

The importer accepts a JSON object with `schemaVersion: 1` and a non-empty
`entries` array. It validates every entry before opening a database transaction;
an invalid entry prevents the whole import. Re-importing an ID replaces that
entry, so IDs must be stable across dictionary releases.

Each entry has this shape:

```json
{
  "id": "en:gentle:001",
  "word": "gentle",
  "language": "en",
  "pronunciation": "jen-təl",
  "partOfSpeech": "adjective",
  "definition": "Kind and careful in the way you treat people or animals.",
  "studentExplanation": "A gentle person is kind and does not hurt others.",
  "examples": [
    {"language": "en", "text": "She used a gentle voice."},
    {"language": "ms", "text": "Dia bercakap dengan suara yang lembut."},
    {"language": "zh", "text": "她用温柔的声音说话。"}
  ],
  "synonyms": ["kind"],
  "antonyms": ["rough"],
  "translations": {"ms": "lembut", "zh": "温柔"},
  "yearLevels": [3, 4],
  "category": "character",
  "source": "Original contributor or reference citation",
  "reviewer": "Reviewer name or organisation",
  "reviewStatus": "published"
}
```

The language values are ISO-style codes `en`, `ms`, and `zh`. `yearLevels` must
contain one or more integers from 1 to 6. `reviewStatus` is `draft`,
`in_review`, or `published`; published entries require a non-empty reviewer and
only published entries can be looked up. Keep source and reviewer details
accurate, and do not copy protected definitions or examples based only on a
reference site's name.

Open **Settings → Import dictionary JSON** in the app and paste the complete
versioned export. The import UI and importer are intended for educator-curated
content; the repository does not bundle dictionary material.

## Architecture

```text
lib/
  app/                         application bootstrap and navigation
  core/                        shared language identifiers
  data/local/                  SQLite database and schema
  data/repositories/            learning repository contract and SQLite adapter
  features/dictionary/          versioned import and validation
  features/translator/          translation models, provider boundary, UI
  features/vocabulary/          saved words
  features/flashcards/          review flow
  features/history/             local translation history
  features/settings/            preferences and dictionary import UI
```

The local repository is the source of truth for saved learning material.
`TranslationProvider` keeps translation implementations replaceable. Before
adding an online provider, make a separate product decision for provider
selection, child privacy and consent, credentials, usage limits, and offline
fallback behavior.
