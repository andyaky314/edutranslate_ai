class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.language,
    required this.meaning,
    required this.explanation,
    required this.createdAt,
    required this.isFavorite,
    required this.reviewCount,
  });

  final String id;
  final String word;
  final String language;
  final String meaning;
  final String explanation;
  final DateTime createdAt;
  final bool isFavorite;
  final int reviewCount;
}
