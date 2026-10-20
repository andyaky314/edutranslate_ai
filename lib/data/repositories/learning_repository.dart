import '../../features/translator/models/translation.dart';
import '../../features/vocabulary/models/vocabulary_item.dart';

abstract interface class LearningRepository {
  Future<void> saveTranslation(Translation translation);

  Future<List<Translation>> getTranslationHistory();

  Future<void> saveVocabulary(Translation translation);

  Future<List<VocabularyItem>> getVocabulary();

  Future<void> toggleFavorite(String id);

  Future<void> recordReview(String id);

  Future<String?> getSetting(String key);

  Future<void> setSetting(String key, String value);
}
