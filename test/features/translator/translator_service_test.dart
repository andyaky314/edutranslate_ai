import 'package:edutranslate_ai/data/repositories/learning_repository.dart';
import 'package:edutranslate_ai/features/translator/models/dictionary_entry.dart';
import 'package:edutranslate_ai/features/translator/models/translation.dart';
import 'package:edutranslate_ai/features/translator/services/translator_service.dart';
import 'package:edutranslate_ai/features/vocabulary/models/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'offline lookup returns a translation and stores it in history',
    () async {
      final repository = _MemoryRepository(_entry);
      final service = TranslatorService(
        provider: OfflineDictionaryProvider(repository),
        repository: repository,
      );

      final result = await service.translate(
        text: ' gentle ',
        from: 'English',
        to: 'Bahasa Melayu',
      );

      expect(result.originalText, 'gentle');
      expect(result.translatedText, 'lembut');
      expect(result.studentExplanation, 'Kind and careful with others.');
      expect(result.exampleSentence, 'Use a gentle voice.');
      expect(repository.history, [result]);
    },
  );

  test(
    'missing published entries fail without creating a history record',
    () async {
      final repository = _MemoryRepository(null);
      final service = TranslatorService(
        provider: OfflineDictionaryProvider(repository),
        repository: repository,
      );

      await expectLater(
        service.translate(
          text: 'unknown',
          from: 'English',
          to: 'Bahasa Melayu',
        ),
        throwsA(isA<TranslationUnavailableException>()),
      );
      expect(repository.history, isEmpty);
    },
  );
}

const _entry = DictionaryEntry(
  id: 'en:gentle:001',
  word: 'gentle',
  language: 'en',
  pronunciation: 'jen-təl',
  partOfSpeech: 'adjective',
  definition: 'Kind and careful.',
  studentExplanation: 'Kind and careful with others.',
  examples: [DictionaryExample(language: 'en', text: 'Use a gentle voice.')],
  synonyms: ['kind'],
  antonyms: [],
  translations: {'ms': 'lembut', 'zh': '温柔'},
  yearLevels: [3],
  category: 'character',
  source: 'Original contributor',
  reviewer: 'Teacher',
  reviewStatus: 'published',
);

class _MemoryRepository implements LearningRepository {
  _MemoryRepository(this.entry);

  final DictionaryEntry? entry;
  final history = <Translation>[];

  @override
  Future<DictionaryEntry?> findPublishedEntry(
    String word,
    String language, {
    int? yearLevel,
  }) async {
    if (entry?.reviewStatus == 'published' &&
        entry?.word.toLowerCase() == word.trim().toLowerCase() &&
        entry?.language == language) {
      return entry;
    }
    return null;
  }

  @override
  Future<void> saveTranslation(Translation translation) async {
    history.add(translation);
  }

  @override
  Future<void> importDictionaryEntries(List<DictionaryEntry> entries) async {}

  @override
  Future<List<Translation>> getTranslationHistory() async => history;

  @override
  Future<void> saveVocabulary(Translation translation) async {}

  @override
  Future<List<VocabularyItem>> getVocabulary() async => [];

  @override
  Future<void> toggleFavorite(String id) async {}

  @override
  Future<void> recordReview(String id) async {}

  @override
  Future<String?> getSetting(String key) async => null;

  @override
  Future<void> setSetting(String key, String value) async {}
}
