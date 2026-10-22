import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../vocabulary/models/vocabulary_item.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({required this.repository, super.key});

  final LearningRepository repository;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late Future<List<VocabularyItem>> _items;
  int _index = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _items = widget.repository.getVocabulary();
  }

  Future<void> _next(List<VocabularyItem> items) async {
    final current = items[_index];
    try {
      await widget.repository.recordReview(current.id);
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % items.length;
        _showAnswer = false;
        _items = widget.repository.getVocabulary();
      });
    } catch (error) {
      debugPrint('Could not record vocabulary review: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('reviewError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return FutureBuilder<List<VocabularyItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Could not load flashcards: ${snapshot.error}');
          return Center(child: Text(strings.text('flashcardsError')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                strings.text('saveWordsFirst'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        _index %= items.length;
        final item = items[_index];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(strings.cardCount(_index + 1, items.length)),
              const SizedBox(height: 16),
              Card(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Text(
                          _showAnswer ? item.meaning : item.word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_showAnswer) ...[
                          const SizedBox(height: 16),
                          Text(item.explanation, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!_showAnswer)
                FilledButton(
                  onPressed: () => setState(() => _showAnswer = true),
                  child: Text(strings.text('showAnswer')),
                )
              else
                FilledButton.icon(
                  onPressed: () => _next(items),
                  icon: const Icon(Icons.check),
                  label: Text(strings.text('gotNext')),
                ),
            ],
          ),
        );
      },
    );
  }
}
