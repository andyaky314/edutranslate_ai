class Translation {
  const Translation({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.studentExplanation,
    this.dictionaryEntryId,
    this.pronunciation,
    this.partOfSpeech,
    this.definition,
    this.exampleSentence,
    this.alternateMeanings = const [],
    this.meanings = const [],
    this.isAiGenerated = false,
  });

  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String studentExplanation;
  final String? dictionaryEntryId;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? definition;
  final String? exampleSentence;
  final List<String> alternateMeanings;
  final List<TranslationMeaning> meanings;
  final bool isAiGenerated;

  List<TranslationMeaning> get possibleMeanings {
    if (meanings.isNotEmpty) return meanings;
    final alternatives = alternateMeanings.isEmpty
        ? [translatedText]
        : alternateMeanings;
    return alternatives
        .map(
          (text) => TranslationMeaning(
            translatedText: text,
            definition: text == translatedText ? definition : null,
            studentExplanation: text == translatedText
                ? studentExplanation
                : null,
            exampleSentence: text == translatedText ? exampleSentence : null,
            partOfSpeech: text == translatedText ? partOfSpeech : null,
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> toJson() => {
    'originalText': originalText,
    'translatedText': translatedText,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'studentExplanation': studentExplanation,
    'dictionaryEntryId': dictionaryEntryId,
    'pronunciation': pronunciation,
    'partOfSpeech': partOfSpeech,
    'definition': definition,
    'exampleSentence': exampleSentence,
    'alternateMeanings': alternateMeanings,
    'meanings': meanings.map((meaning) => meaning.toJson()).toList(),
    'isAiGenerated': isAiGenerated,
  };

  factory Translation.fromJson(Map<String, dynamic> json) => Translation(
    originalText: json['originalText'] as String,
    translatedText: json['translatedText'] as String,
    sourceLanguage: json['sourceLanguage'] as String,
    targetLanguage: json['targetLanguage'] as String,
    studentExplanation: json['studentExplanation'] as String,
    dictionaryEntryId: json['dictionaryEntryId'] as String?,
    pronunciation: json['pronunciation'] as String?,
    partOfSpeech: json['partOfSpeech'] as String?,
    definition: json['definition'] as String?,
    exampleSentence: json['exampleSentence'] as String?,
    alternateMeanings:
        (json['alternateMeanings'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const [],
    meanings:
        (json['meanings'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(TranslationMeaning.fromJson)
            .toList() ??
        const [],
    isAiGenerated: json['isAiGenerated'] as bool? ?? false,
  );
}

class TranslationMeaning {
  const TranslationMeaning({
    required this.translatedText,
    this.definition,
    this.studentExplanation,
    this.exampleSentence,
    this.partOfSpeech,
  });

  final String translatedText;
  final String? definition;
  final String? studentExplanation;
  final String? exampleSentence;
  final String? partOfSpeech;

  Map<String, Object?> toJson() => {
    'translatedText': translatedText,
    'definition': definition,
    'studentExplanation': studentExplanation,
    'exampleSentence': exampleSentence,
    'partOfSpeech': partOfSpeech,
  };

  factory TranslationMeaning.fromJson(Map<String, dynamic> json) =>
      TranslationMeaning(
        translatedText: json['translatedText'] as String,
        definition: json['definition'] as String?,
        studentExplanation: json['studentExplanation'] as String?,
        exampleSentence: json['exampleSentence'] as String?,
        partOfSpeech: json['partOfSpeech'] as String?,
      );
}
