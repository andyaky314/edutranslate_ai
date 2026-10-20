import 'dart:convert';

import '../../../data/repositories/learning_repository.dart';
import '../../translator/models/dictionary_entry.dart';

class DictionaryImportException implements Exception {
  const DictionaryImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DictionaryImporter {
  DictionaryImporter(this.repository);

  static const schemaVersion = 1;

  final LearningRepository repository;

  Future<int> importJson(String content) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (error) {
      throw DictionaryImportException('Invalid JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DictionaryImportException(
        'The dictionary file must contain a JSON object.',
      );
    }
    if (decoded['schemaVersion'] != schemaVersion) {
      throw DictionaryImportException(
        'Unsupported dictionary schema version. Expected $schemaVersion.',
      );
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List || rawEntries.isEmpty) {
      throw const DictionaryImportException(
        'The dictionary must contain at least one entry.',
      );
    }

    final entries = <DictionaryEntry>[];
    final ids = <String>{};
    try {
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) {
          throw const FormatException('Each entry must be an object.');
        }
        final entry = DictionaryEntry.fromJson(
          rawEntry.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (!ids.add(entry.id)) {
          throw FormatException('Duplicate entry ID "${entry.id}".');
        }
        entries.add(entry);
      }
    } on FormatException catch (error) {
      throw DictionaryImportException(
        'Dictionary validation failed: ${error.message}',
      );
    }

    await repository.importDictionaryEntries(entries);
    return entries.length;
  }
}
