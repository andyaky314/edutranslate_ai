class AppLanguage {
  const AppLanguage({required this.code, required this.name});

  final String code;
  final String name;

  static const english = AppLanguage(code: 'en', name: 'English');
  static const malay = AppLanguage(code: 'ms', name: 'Bahasa Melayu');
  static const chinese = AppLanguage(code: 'zh', name: '中文');

  static const all = [english, malay, chinese];

  static AppLanguage fromCode(String code) {
    return all.firstWhere(
      (language) => language.code == code,
      orElse: () => throw FormatException('Unsupported language code: $code'),
    );
  }

  static AppLanguage fromName(String name) {
    return all.firstWhere(
      (language) => language.name == name,
      orElse: () => throw FormatException('Unsupported language: $name'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
