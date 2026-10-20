import 'package:edutranslate_ai/data/repositories/learning_repository.dart';
import 'package:edutranslate_ai/features/translator/models/translation.dart';
import 'package:edutranslate_ai/features/translator/services/translator_service.dart';
import 'package:edutranslate_ai/features/vocabulary/models/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider result is saved to translation history', () async {
    final repository = _MemoryRepository();
    final result = _translation;
    final service = TranslatorService(
      provider: _FakeProvider(result),
      repository: repository,
    );

    final translated = await service.translate(
      text: '  hello  ',
      from: 'English',
      to: 'Bahasa Melayu',
      yearLevel: 2,
    );

    expect(translated.originalText, 'hello');
    expect(translated.translatedText, 'hai');
    expect(repository.history, [result]);
  });

  test('empty input is rejected before calling the provider', () async {
    final repository = _MemoryRepository();
    final provider = _FakeProvider(_translation);
    final service = TranslatorService(
      provider: provider,
      repository: repository,
    );

    await expectLater(
      service.translate(text: '  ', from: 'English', to: 'Bahasa Melayu'),
      throwsA(isA<TranslationUnavailableException>()),
    );
    expect(provider.calls, 0);
    expect(repository.history, isEmpty);
  });
}

const _translation = Translation(
  originalText: 'hello',
  translatedText: 'hai',
  sourceLanguage: 'en',
  targetLanguage: 'ms',
  studentExplanation: 'A friendly greeting.',
  definition: 'A greeting used when meeting someone.',
  exampleSentence: 'Hai, apa khabar?',
  isAiGenerated: true,
);

class _FakeProvider implements TranslationProvider {
  _FakeProvider(this.result);

  final Translation result;
  int calls = 0;

  @override
  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
    int? yearLevel,
  }) async {
    calls++;
    return result;
  }
}

class _MemoryRepository implements LearningRepository {
  final history = <Translation>[];

  @override
  Future<void> saveTranslation(Translation translation) async =>
      history.add(translation);

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
