import 'package:edutranslate_ai/data/repositories/learning_repository.dart';
import 'package:edutranslate_ai/features/dictionary/services/dictionary_importer.dart';
import 'package:edutranslate_ai/features/translator/models/dictionary_entry.dart';
import 'package:edutranslate_ai/features/translator/models/translation.dart';
import 'package:edutranslate_ai/features/vocabulary/models/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionaryImporter', () {
    test('validates and imports a complete version 1 file', () async {
      final repository = _RecordingRepository();
      final importer = DictionaryImporter(repository);

      final count = await importer.importJson(_validDocument);

      expect(count, 1);
      expect(repository.imported, hasLength(1));
      expect(repository.imported.single.id, 'en:gentle:001');
      expect(repository.imported.single.yearLevels, [3, 4]);
    });

    test('rejects the entire file before writing duplicate IDs', () async {
      final repository = _RecordingRepository();
      final importer = DictionaryImporter(repository);
      final document = _validDocument.replaceFirst(
        '"entries": [',
        '"entries": [\n$_entryJson,',
      );

      await expectLater(
        importer.importJson(document),
        throwsA(isA<DictionaryImportException>()),
      );
      expect(repository.imported, isEmpty);
    });

    test('rejects unsupported schema versions without importing', () async {
      final repository = _RecordingRepository();
      final importer = DictionaryImporter(repository);

      await expectLater(
        importer.importJson(
          _validDocument.replaceFirst(
            '"schemaVersion": 1',
            '"schemaVersion": 2',
          ),
        ),
        throwsA(isA<DictionaryImportException>()),
      );
      expect(repository.imported, isEmpty);
    });

    test('rejects invalid language tags before importing', () async {
      final repository = _RecordingRepository();
      final importer = DictionaryImporter(repository);

      await expectLater(
        importer.importJson(
          _validDocument.replaceFirst('"language": "en"', '"language": "fr"'),
        ),
        throwsA(isA<DictionaryImportException>()),
      );
      expect(repository.imported, isEmpty);
    });
  });
}

const _entryJson = '''
{
  "id": "en:gentle:001",
  "word": "gentle",
  "language": "en",
  "pronunciation": "jen-təl",
  "partOfSpeech": "adjective",
  "definition": "Kind and careful.",
  "studentExplanation": "Kind and careful with others.",
  "examples": [{"language": "en", "text": "Use a gentle voice."}],
  "synonyms": ["kind"],
  "antonyms": [],
  "translations": {"ms": "lembut", "zh": "温柔"},
  "yearLevels": [3, 4],
  "category": "character",
  "source": "Original contributor",
  "reviewer": "Teacher",
  "reviewStatus": "published"
}
''';

const _validDocument = '{"schemaVersion": 1, "entries": [$_entryJson]}';

class _RecordingRepository implements LearningRepository {
  final imported = <DictionaryEntry>[];

  @override
  Future<void> importDictionaryEntries(List<DictionaryEntry> entries) async {
    imported.addAll(entries);
  }

  @override
  Future<DictionaryEntry?> findPublishedEntry(
    String word,
    String language, {
    int? yearLevel,
  }) async => null;

  @override
  Future<List<Translation>> getTranslationHistory() async => [];

  @override
  Future<List<VocabularyItem>> getVocabulary() async => [];

  @override
  Future<String?> getSetting(String key) async => null;

  @override
  Future<void> recordReview(String id) async {}

  @override
  Future<void> saveTranslation(Translation translation) async {}

  @override
  Future<void> saveVocabulary(Translation translation) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<void> toggleFavorite(String id) async {}
}
