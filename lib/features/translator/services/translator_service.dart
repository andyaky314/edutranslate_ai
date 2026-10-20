import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../models/dictionary_entry.dart';
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

class OfflineDictionaryProvider implements TranslationProvider {
  OfflineDictionaryProvider(this.repository);

  final LearningRepository repository;

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

    final entry = await repository.findPublishedEntry(
      text,
      source.code,
      yearLevel: yearLevel,
    );
    if (entry == null) {
      throw TranslationUnavailableException(
        yearLevel == null
            ? 'This word is not in the offline dictionary yet. Check the spelling or import a reviewed dictionary.'
            : 'This word is not in the offline dictionary for Year $yearLevel yet. Check the spelling or import a reviewed dictionary.',
      );
    }
    final translated = entry.translations[target.code];
    if (translated == null || translated.trim().isEmpty) {
      throw TranslationUnavailableException(
        'No ${target.name} translation is available for this dictionary entry.',
      );
    }
    return Translation(
      originalText: text.trim(),
      translatedText: translated,
      sourceLanguage: source.code,
      targetLanguage: target.code,
      studentExplanation: entry.studentExplanation,
      dictionaryEntryId: entry.id,
      pronunciation: entry.pronunciation.isEmpty ? null : entry.pronunciation,
      partOfSpeech: entry.partOfSpeech,
      definition: entry.definition,
      exampleSentence: _exampleFor(entry, source.code),
    );
  }

  String? _exampleFor(DictionaryEntry entry, String language) {
    for (final example in entry.examples) {
      if (example.language == language) return example.text;
    }
    return null;
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
        'Enter a word before translating.',
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
