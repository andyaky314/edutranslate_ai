import '../../../core/languages.dart';

class DictionaryExample {
  const DictionaryExample({required this.language, required this.text});

  final String language;
  final String text;

  factory DictionaryExample.fromJson(Map<String, dynamic> json) {
    final language = DictionaryEntry._requiredString(json, 'language');
    AppLanguage.fromCode(language);
    return DictionaryExample(
      language: language,
      text: DictionaryEntry._requiredString(json, 'text'),
    );
  }

  Map<String, String> toJson() => {'language': language, 'text': text};
}

class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.word,
    required this.language,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.definition,
    required this.studentExplanation,
    required this.examples,
    required this.synonyms,
    required this.antonyms,
    required this.translations,
    required this.yearLevels,
    required this.category,
    required this.source,
    required this.reviewer,
    required this.reviewStatus,
  });

  final String id;
  final String word;
  final String language;
  final String pronunciation;
  final String partOfSpeech;
  final String definition;
  final String studentExplanation;
  final List<DictionaryExample> examples;
  final List<String> synonyms;
  final List<String> antonyms;
  final Map<String, String> translations;
  final List<int> yearLevels;
  final String category;
  final String source;
  final String reviewer;
  final String reviewStatus;

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final language = _requiredString(json, 'language');
    AppLanguage.fromCode(language);
    final reviewStatus = _requiredString(json, 'reviewStatus');
    if (!const {'draft', 'in_review', 'published'}.contains(reviewStatus)) {
      throw const FormatException(
        'Dictionary entry "reviewStatus" must be draft, in_review, or published.',
      );
    }
    final translations = _stringMap(json, 'translations');
    for (final code in translations.keys) {
      AppLanguage.fromCode(code);
    }
    if (translations.isEmpty ||
        translations.keys.every((code) => code == language) ||
        translations.values.any((value) => value.trim().isEmpty)) {
      throw const FormatException(
        'Dictionary entry "translations" must include a non-empty translation in another supported language.',
      );
    }
    final reviewer = _optionalString(json, 'reviewer');
    if (reviewStatus == 'published' && reviewer.isEmpty) {
      throw const FormatException(
        'Published dictionary entries must include a reviewer.',
      );
    }

    return DictionaryEntry(
      id: _requiredString(json, 'id'),
      word: _requiredString(json, 'word'),
      language: language,
      pronunciation: _optionalString(json, 'pronunciation'),
      partOfSpeech: _requiredString(json, 'partOfSpeech'),
      definition: _requiredString(json, 'definition'),
      studentExplanation: _requiredString(json, 'studentExplanation'),
      examples: _objectList(json, 'examples')
          .map(DictionaryExample.fromJson)
          .toList(growable: false),
      synonyms: _stringList(json, 'synonyms'),
      antonyms: _stringList(json, 'antonyms'),
      translations: translations,
      yearLevels: _yearLevels(json),
      category: _optionalString(json, 'category'),
      source: _requiredString(json, 'source'),
      reviewer: reviewer,
      reviewStatus: reviewStatus,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'word': word,
        'language': language,
        'pronunciation': pronunciation,
        'partOfSpeech': partOfSpeech,
        'definition': definition,
        'studentExplanation': studentExplanation,
        'examples': examples.map((example) => example.toJson()).toList(),
        'synonyms': synonyms,
        'antonyms': antonyms,
        'translations': translations,
        'yearLevels': yearLevels,
        'category': category,
        'source': source,
        'reviewer': reviewer,
        'reviewStatus': reviewStatus,
      };

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Dictionary entry "$key" must be a non-empty string.');
    }
    return value.trim();
  }

  static String _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is! String) {
      throw FormatException('Dictionary entry "$key" must be a string.');
    }
    return value.trim();
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key] ?? const <dynamic>[];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Dictionary entry "$key" must be a list of strings.');
    }
    return value.cast<String>().map((item) => item.trim()).toList();
  }

  static List<Map<String, dynamic>> _objectList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! Map)) {
      throw FormatException('Dictionary entry "$key" must be a list of objects.');
    }
    return value.cast<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  static Map<String, String> _stringMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key] ?? const <String, dynamic>{};
    if (value is! Map ||
        value.entries.any((entry) => entry.key is! String || entry.value is! String)) {
      throw FormatException('Dictionary entry "$key" must map strings to strings.');
    }
    return value.cast<String, String>();
  }

  static List<int> _yearLevels(Map<String, dynamic> json) {
    final value = json['yearLevels'];
    if (value is! List ||
        value.isEmpty ||
        value.any((year) => year is! int || year < 1 || year > 6)) {
      throw const FormatException(
        'Dictionary entry "yearLevels" must contain years from 1 to 6.',
      );
    }
    return value.cast<int>();
  }
}
