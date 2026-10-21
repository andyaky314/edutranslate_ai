class GeminiConfig {
  static const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const models = <String>[
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];
}
