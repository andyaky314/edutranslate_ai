import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edutranslate_ai/data/repositories/learning_repository.dart';
import 'package:edutranslate_ai/features/translator/models/translation.dart';
import 'package:edutranslate_ai/features/translator/services/translator_service.dart';
import 'package:edutranslate_ai/features/vocabulary/models/vocabulary_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each Gemini model timeout is 2.5 seconds', () {
    expect(GeminiTranslationProvider.modelTimeout.inMilliseconds, 2500);
    expect(
      GeminiTranslationProvider.modelTimeout,
      lessThan(const Duration(seconds: 3)),
    );
  });

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

  test('Gemini request sends the trimmed key in the auth header', () async {
    final client = MockClient((request) async {
      expect(
        request.url.path,
        '/v1beta/models/gemini-3.8-flash:generateContent',
      );
      expect(request.url.queryParameters, isEmpty);
      expect(request.headers['x-goog-api-key'], 'test-key');
      expect(jsonDecode(request.body)['generationConfig'], {
        'responseMimeType': 'application/json',
        'maxOutputTokens': 512,
      });
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'translation': 'hai',
                      'partOfSpeech': 'noun',
                      'definition': 'A greeting.',
                      'studentExplanation': 'A friendly greeting.',
                      'exampleSentence': 'Hai!',
                      'pronunciation': '',
                    }),
                  },
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final provider = GeminiTranslationProvider(
      client: client,
      apiKey: ' test-key ',
    );

    final result = await provider.translate(
      text: 'hello',
      from: 'English',
      to: 'Bahasa Melayu',
    );

    expect(result.translatedText, 'hai');
  });

  test(
    'Gemini falls back to the next model when the first is unavailable',
    () async {
      final requestedModels = <String>[];
      final client = MockClient((request) async {
        requestedModels.add(request.url.pathSegments[2].split(':').first);
        if (requestedModels.length == 1) {
          return http.Response('unavailable', 404);
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'translation': 'hai',
                        'definition': 'A greeting.',
                        'studentExplanation': 'A friendly greeting.',
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final provider = GeminiTranslationProvider(
        client: client,
        apiKey: 'test-key',
        models: const ['gemini-primary', 'gemini-fallback'],
      );

      final result = await provider.translate(
        text: 'hello',
        from: 'English',
        to: 'Bahasa Melayu',
      );

      expect(result.translatedText, 'hai');
      expect(requestedModels, ['gemini-primary', 'gemini-fallback']);
    },
  );

  test(
    'Gemini tries the next model when the previous request times out',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'translation': 'hai',
                        'definition': 'A greeting.',
                        'studentExplanation': 'A friendly greeting.',
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final provider = GeminiTranslationProvider(
        client: client,
        apiKey: 'test-key',
        models: const ['gemini-primary', 'gemini-fallback'],
        timeout: const Duration(milliseconds: 10),
      );

      final result = await provider.translate(
        text: 'hello',
        from: 'English',
        to: 'Bahasa Melayu',
      );

      expect(result.translatedText, 'hai');
      expect(calls, 2);
    },
  );

  test('blank Gemini API key is rejected before making a request', () async {
    final provider = GeminiTranslationProvider(
      client: MockClient((_) async => fail('Unexpected request')),
      apiKey: ' ',
    );

    await expectLater(
      provider.translate(text: 'hello', from: 'English', to: 'Bahasa Melayu'),
      throwsA(
        isA<TranslationUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('--dart-define=GEMINI_API_KEY'),
        ),
      ),
    );
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
