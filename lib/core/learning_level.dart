enum LearningLevel {
  lowerPrimary('lowerPrimary'),
  upperPrimary('upperPrimary'),
  standard('standard');

  const LearningLevel(this.code);

  final String code;

  static LearningLevel fromCode(String code) =>
      LearningLevel.values.firstWhere((level) => level.code == code);

  /// Keeps compatibility with existing translation providers.
  int? get promptYearLevel => switch (this) {
    LearningLevel.lowerPrimary => 3,
    LearningLevel.upperPrimary => 6,
    LearningLevel.standard => null,
  };
}
