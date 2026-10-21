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
  final bool isAiGenerated;

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
    alternateMeanings: (json['alternateMeanings'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const [],
    isAiGenerated: json['isAiGenerated'] as bool? ?? false,
  );
}
