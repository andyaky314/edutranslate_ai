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
  static const modelTimeout = Duration(seconds: 12);

  GeminiTranslationProvider({
    http.Client? client,
    String? apiKey,
    String? model,
    List<String>? models,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? GeminiConfig.apiKey,
       _models = models ?? (model == null ? GeminiConfig.models : [model]),
       _timeout = timeout ?? modelTimeout;

  final http.Client _client;
  final String _apiKey;
  final List<String> _models;
  final Duration _timeout;

  @override
  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
    int? yearLevel,
  }) async {
    final source = from == 'Auto detect' ? null : AppLanguage.fromName(from);
    final target = AppLanguage.fromName(to);
    if (source != null && source == target) {
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

    final targetApiCode = _apiLanguageCode(target.code);
    final learningInstruction = yearLevel == null
        ? 'Use clear, standard language and explanations for a general audience.'
        : yearLevel <= 3
        ? 'Use language and explanations suitable for lower primary students (Years 1–3).'
        : 'Use language and explanations suitable for upper primary students (Years 4–6).';
    final prompt =
        '''
You are EduTranslate, an AI language tutor. Adapt your explanation to the selected learning level.
Translate the complete input ${source == null ? 'from the language detected in the input' : 'from ${source.name} (${_apiLanguageCode(source.code)})'} to ${target.name} ($targetApiCode).
The detected input language must be one of English (en), Bahasa Melayu (ms), or Chinese (zh). Return that code in detectedSourceLanguage.
If the input is a sentence or phrase, provide one natural translation and one meaning entry. If it is a single word, provide up to 5 common distinct meanings, ordered by how common they are. For every meaning, provide its own target translation, a short definition in the source language, an explanation suitable for the selected learning level in the target language, and one short example sentence in the target language. Put brief sense labels in parentheses in the target translation when useful. The top-level translation, definition, studentExplanation, exampleSentence, and partOfSpeech must repeat the first meaning's values for compatibility.
Use ${(target.code == 'zh') ? 'Simplified Chinese characters' : target.name} for all target-language text.
$learningInstruction
Give a short definition in the source language, an explanation appropriate to the selected learning level in the target language, and one short example sentence in the target language.
For partOfSpeech, return one simple English label such as noun, verb, adjective, adverb, phrase, or other.
For pronunciation, return a brief pronunciation guide for the source text when useful; otherwise use an empty string.
Do not claim a dictionary or official source. Do not invent etymology. Keep the explanation accurate and concise.

Return a JSON object with exactly these fields. meanings is an array of objects with their own details:
{"translation":"...","meanings":[{"translatedText":"...","definition":"...","studentExplanation":"...","exampleSentence":"...","partOfSpeech":"..."}],"partOfSpeech":"...","definition":"...","studentExplanation":"...","exampleSentence":"...","pronunciation":"...","detectedSourceLanguage":"en|ms|zh"}

Input: $text
''';

    String? lastIssue;
    for (var index = 0; index < _models.length; index++) {
      final model = _models[index];
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
      );
      try {
        final response = await _client
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
                  'maxOutputTokens': 1536,
                },
              }),
            )
            .timeout(_timeout);

        if (response.statusCode != 200) {
          if (response.statusCode == 400 ||
              response.statusCode == 401 ||
              response.statusCode == 403) {
            throw TranslationUnavailableException(
              response.statusCode == 400
                  ? 'Gemini rejected the request. Check the request and model access.'
                  : 'Gemini authentication failed. Check the API key and Gemini API access.',
            );
          }
          lastIssue = response.statusCode == 429
              ? 'Gemini request limit reached (HTTP 429).'
              : 'Gemini model $model unavailable (HTTP ${response.statusCode}).';
          continue;
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
          final detectedCode =
              source?.code ?? _requiredString(result, 'detectedSourceLanguage');
          final detectedSource = AppLanguage.fromCode(detectedCode);
          if (detectedSource == target) {
            throw const TranslationUnavailableException(
              'The detected text is already in the selected target language. Choose a different To language.',
            );
          }
          final meanings = _meaningList(result, 'meanings');
          final firstMeaning = meanings.isEmpty ? null : meanings.first;
          return Translation(
            originalText: text.trim(),
            translatedText:
                firstMeaning?.translatedText ??
                _requiredString(result, 'translation'),
            sourceLanguage: detectedSource.code,
            targetLanguage: target.code,
            studentExplanation:
                firstMeaning?.studentExplanation ??
                _requiredString(result, 'studentExplanation'),
            pronunciation: _optionalString(result, 'pronunciation'),
            partOfSpeech:
                firstMeaning?.partOfSpeech ??
                _optionalString(result, 'partOfSpeech'),
            definition:
                firstMeaning?.definition ??
                _requiredString(result, 'definition'),
            exampleSentence:
                firstMeaning?.exampleSentence ??
                _optionalString(result, 'exampleSentence'),
            alternateMeanings: _stringList(result, 'alternateMeanings'),
            meanings: meanings,
            isAiGenerated: true,
          );
        } on FormatException {
          lastIssue = 'Gemini model $model returned unreadable content.';
        } on TypeError {
          lastIssue = 'Gemini model $model returned incomplete content.';
        }
      } on TimeoutException {
        lastIssue = 'Gemini model $model timed out.';
      } on http.ClientException {
        throw const TranslationUnavailableException(
          'Could not connect to Gemini. Check your internet connection and try again.',
        );
      }
    }
    throw TranslationUnavailableException(
      'All Gemini models failed. ${lastIssue ?? 'Please check your connection and try again.'}',
    );
  }

  String _apiLanguageCode(String code) => code == 'zh' ? 'zh-CN' : code;

  String _requiredString(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! String || result.trim().isEmpty) {
      throw FormatException('Gemini omitted $key.');
    }
    return result.trim();
  }

  List<String> _stringList(Map<String, dynamic> value, String key) {
    final result = value[key];
    if (result is! List) return const [];
    return result
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
  }

  List<TranslationMeaning> _meaningList(
    Map<String, dynamic> value,
    String key,
  ) {
    final result = value[key];
    if (result is! List) return const [];
    return result
        .whereType<Map<String, dynamic>>()
        .where(
          (item) =>
              item['translatedText'] is String &&
              (item['translatedText'] as String).trim().isNotEmpty,
        )
        .map(TranslationMeaning.fromJson)
        .take(5)
        .toList();
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
