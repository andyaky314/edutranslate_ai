import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/gemini_config.dart';
import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../models/translation.dart';

class TranslationUnavailableException implements Exception {
  const TranslationUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class TranslationProvider {
  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
    int? yearLevel,
  });
}

class GeminiTranslationProvider implements TranslationProvider {
  GeminiTranslationProvider({
    http.Client? client,
    String? apiKey,
    String? model,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? GeminiConfig.apiKey,
       _model = model ?? GeminiConfig.model;

  final http.Client _client;
  final String _apiKey;
  final String _model;

  @override
  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
    int? yearLevel,
  }) async {
    final source = AppLanguage.fromName(from);
    final target = AppLanguage.fromName(to);
    if (source == target) {
      throw const TranslationUnavailableException(
        'Choose two different languages to translate.',
      );
    }
    final apiKey = _apiKey.trim();
    if (apiKey.isEmpty) {
      throw const TranslationUnavailableException(
        'Gemini is not configured for this build. Launch the app with --dart-define=GEMINI_API_KEY=your-key, then rebuild it.',
      );
    }

    final sourceApiCode = _apiLanguageCode(source.code);
    final targetApiCode = _apiLanguageCode(target.code);
    final prompt =
        '''
You are EduTranslate, an AI language tutor for Malaysian primary school students.
Translate the complete input from ${source.name} ($sourceApiCode) to ${target.name} ($targetApiCode).
If the input is a sentence or phrase, translate its full meaning naturally. If it is one word, give its most common meaning in this context.
Use ${(target.code == 'zh') ? 'Simplified Chinese characters' : target.name} for all target-language text.
${yearLevel == null ? 'Use simple language suitable for primary school students.' : 'Explain it at a Year $yearLevel primary school level.'}
Give a short definition in the source language, a child-friendly explanation in the target language, and one short example sentence in the target language.
For partOfSpeech, return one simple English label such as noun, verb, adjective, adverb, phrase, or other.
For pronunciation, return a brief pronunciation guide for the source text when useful; otherwise use an empty string.
Do not claim a dictionary or official source. Do not invent etymology. Keep the explanation accurate and concise.

Return a JSON object with exactly these string fields:
{"translation":"...","partOfSpeech":"...","definition":"...","studentExplanation":"...","exampleSentence":"...","pronunciation":"..."}

Input: $text
''';

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': 0.2,
                'maxOutputTokens': 512,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const TranslationUnavailableException(
        'Gemini took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const TranslationUnavailableException(
        'Could not connect to Gemini. Check your internet connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        throw const TranslationUnavailableException(
          'Gemini is busy or the request limit was reached. Please try again later.',
        );
      }
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw const TranslationUnavailableException(
          'Gemini rejected the request. Check the API key, model access, and AI Studio project settings.',
        );
      }
      if (response.statusCode == 401) {
        throw const TranslationUnavailableException(
          'Gemini authentication failed. Check that the API key is valid and the Gemini API is enabled for its Google Cloud project.',
        );
      }
      if (response.statusCode == 404) {
        throw TranslationUnavailableException(
          'Gemini model "$_model" was not found. Check the configured model name.',
        );
      }
      throw TranslationUnavailableException(
        'Gemini is temporarily unavailable (HTTP ${response.statusCode}). Please try again.',
      );
    }

    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = payload['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Gemini returned no translation.');
      }
      final content = candidates.first as Map<String, dynamic>;
      final parts = content['content']?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const FormatException('Gemini returned no translation text.');
      }
      final generatedText =
          (parts.first as Map<String, dynamic>)['text'] as String;
      final result = jsonDecode(generatedText) as Map<String, dynamic>;
      final translatedText = _requiredString(result, 'translation');
      final definition = _requiredString(result, 'definition');
      final explanation = _requiredString(result, 'studentExplanation');

      return Translation(
        originalText: text.trim(),
        translatedText: translatedText,
        sourceLanguage: source.code,
        targetLanguage: target.code,
        studentExplanation: explanation,
        pronunciation: _optionalString(result, 'pronunciation'),
        partOfSpeech: _optionalString(result, 'partOfSpeech'),
        definition: definition,
        exampleSentence: _optionalString(result, 'exampleSentence'),
        isAiGenerated: true,
      );
    } on FormatException {
      throw const TranslationUnavailableException(
        'Gemini returned an unreadable response. Please try again.',
      );
    } on TypeError {
      throw const TranslationUnavailableException(
        'Gemini returned an incomplete response. Please try again.',
      );
    }
  }

  String _apiLanguageCode(String code) => code == 'zh' ? 'zh-CN' : code;

  String _requiredString(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! String || result.trim().isEmpty) {
      throw FormatException('Gemini omitted $key.');
    }
    return result.trim();
  }

  String? _optionalString(Map<String, dynamic> value, String key) {
    final result = value[key];
    return result is String && result.trim().isNotEmpty ? result.trim() : null;
  }
}

class TranslatorService {
  TranslatorService({required this.provider, required this.repository});

  final TranslationProvider provider;
  final LearningRepository repository;

  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
    int? yearLevel,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const TranslationUnavailableException(
        'Enter a word or sentence before translating.',
      );
    }
    final result = await provider.translate(
      text: normalizedText,
      from: from,
      to: to,
      yearLevel: yearLevel,
    );
    await repository.saveTranslation(result);
    return result;
  }
}
