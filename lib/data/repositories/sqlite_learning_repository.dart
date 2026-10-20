import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/translator/models/translation.dart';
import '../../features/vocabulary/models/vocabulary_item.dart';
import 'learning_repository.dart';

class SqliteLearningRepository implements LearningRepository {
  SqliteLearningRepository(this.database);

  final Database database;

  @override
  Future<void> saveTranslation(Translation translation) async {
    await database.insert('translation_history', {
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'payload': jsonEncode(translation.toJson()),
    });
  }

  @override
  Future<List<Translation>> getTranslationHistory() async {
    final rows = await database.query(
      'translation_history',
      orderBy: 'id DESC',
    );
    return rows
        .map(
          (row) => Translation.fromJson(
            jsonDecode(row['payload']! as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveVocabulary(Translation translation) async {
    final id =
        translation.dictionaryEntryId ??
        '${translation.sourceLanguage}-${translation.originalText.trim().toLowerCase()}';
    await database.insert('vocabulary', {
      'id': id,
      'word': translation.originalText,
      'language': translation.sourceLanguage,
      'meaning': translation.translatedText,
      'explanation': translation.studentExplanation,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'payload': jsonEncode(translation.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<VocabularyItem>> getVocabulary() async {
    final rows = await database.query(
      'vocabulary',
      orderBy: 'isFavorite DESC, createdAt DESC',
    );
    return rows
        .map(
          (row) => VocabularyItem(
            id: row['id']! as String,
            word: row['word']! as String,
            language: row['language']! as String,
            meaning: row['meaning']! as String,
            explanation: row['explanation']! as String,
            createdAt: DateTime.parse(row['createdAt']! as String),
            isFavorite: row['isFavorite']! == 1,
            reviewCount: row['reviewCount']! as int,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> toggleFavorite(String id) async {
    await database.rawUpdate(
      'UPDATE vocabulary SET isFavorite = CASE isFavorite WHEN 1 THEN 0 ELSE 1 END WHERE id = ?',
      [id],
    );
  }

  @override
  Future<void> recordReview(String id) async {
    await database.rawUpdate(
      'UPDATE vocabulary SET reviewCount = reviewCount + 1 WHERE id = ?',
      [id],
    );
  }

  @override
  Future<String?> getSetting(String key) async {
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

}
