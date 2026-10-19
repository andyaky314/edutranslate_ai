class Translation {
  final String originalText;
  final String translatedText;

  final String sourceLanguage;
  final String targetLanguage;

  final String? pronunciation;
  final String? partOfSpeech;

  final String? englishMeaning;
  final String? studentExplanation;

  final String? malayMeaning;
  final String? chineseMeaning;

  final String? exampleSentence;

  const Translation({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,

    this.pronunciation,
    this.partOfSpeech,

    this.englishMeaning,
    this.studentExplanation,

    this.malayMeaning,
    this.chineseMeaning,

    this.exampleSentence,
  });
}