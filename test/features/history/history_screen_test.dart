import 'package:edutranslate_ai/data/repositories/learning_repository.dart';
import 'package:edutranslate_ai/features/history/screens/history_screen.dart';
import 'package:edutranslate_ai/features/translator/models/translation.dart';
import 'package:edutranslate_ai/features/vocabulary/models/vocabulary_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('history words can be saved to the vocabulary list', (
    tester,
  ) async {
    final translation = Translation(
      originalText: 'invoice',
      translatedText: 'invois',
      sourceLanguage: 'en',
      targetLanguage: 'ms',
      studentExplanation: 'A bill for goods or services.',
    );
    final repository = _HistoryRepository(translation);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save word'));
    await tester.pumpAndSettle();

    expect(repository.savedVocabulary, [translation]);
    expect(find.byTooltip('Saved word'), findsOneWidget);
  });

  testWidgets('history opens a word and selecting a meaning updates details', (
    tester,
  ) async {
    final translation = Translation(
      originalText: 'bank',
      translatedText: 'tebing',
      sourceLanguage: 'en',
      targetLanguage: 'ms',
      studentExplanation: 'A raised side beside water.',
      definition: 'The land beside a river.',
      exampleSentence: 'We sat on the river bank.',
      meanings: const [
        TranslationMeaning(
          translatedText: 'tebing',
          definition: 'The land beside a river.',
          studentExplanation: 'A raised side beside water.',
          exampleSentence: 'We sat on the river bank.',
          partOfSpeech: 'noun',
        ),
        TranslationMeaning(
          translatedText: 'bank (financial institution)',
          definition: 'A company that keeps and lends money.',
          studentExplanation: 'A place where people keep or borrow money.',
          exampleSentence: 'Mina saved her money in the bank.',
          partOfSpeech: 'noun',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(repository: _HistoryRepository(translation)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('bank').first);
    await tester.pumpAndSettle();
    expect(find.text('A raised side beside water.'), findsOneWidget);
    expect(find.text('We sat on the river bank.'), findsOneWidget);

    await tester.tap(find.text('bank (financial institution)'));
    await tester.pumpAndSettle();
    expect(
      find.text('A place where people keep or borrow money.'),
      findsOneWidget,
    );
    expect(find.text('Mina saved her money in the bank.'), findsOneWidget);
    expect(find.text('A raised side beside water.'), findsNothing);
  });
}

class _HistoryRepository implements LearningRepository {
  _HistoryRepository(this.translation);

  final Translation translation;
  final List<Translation> savedVocabulary = [];

  @override
  Future<void> saveTranslation(Translation translation) async {}

  @override
  Future<List<Translation>> getTranslationHistory() async => [translation];

  @override
  Future<void> saveVocabulary(Translation translation) async {
    savedVocabulary.add(translation);
  }

  @override
  Future<List<VocabularyItem>> getVocabulary() async => [];

  @override
  Future<void> deleteVocabulary(String id) async {}

  @override
  Future<void> toggleFavorite(String id) async {}

  @override
  Future<void> recordReview(String id) async {}

  @override
  Future<String?> getSetting(String key) async => null;

  @override
  Future<void> setSetting(String key, String value) async {}
}
