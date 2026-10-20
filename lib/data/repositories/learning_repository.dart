import '../../features/translator/models/dictionary_entry.dart';
import '../../features/translator/models/translation.dart';
import '../../features/vocabulary/models/vocabulary_item.dart';

abstract interface class LearningRepository {
  Future<DictionaryEntry?> findPublishedEntry(
    String word,
    String language, {
    int? yearLevel,
  });

  Future<void> saveTranslation(Translation translation);

  Future<List<Translation>> getTranslationHistory();

  Future<void> saveVocabulary(Translation translation);

  Future<List<VocabularyItem>> getVocabulary();

  Future<void> toggleFavorite(String id);

  Future<void> recordReview(String id);

  Future<void> importDictionaryEntries(List<DictionaryEntry> entries);

  Future<String?> getSetting(String key);

  Future<void> setSetting(String key, String value);
}
