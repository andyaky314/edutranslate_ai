import 'package:flutter/material.dart';

import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../translator/models/translation.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.repository, super.key});

  final LearningRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Translation>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.repository.getTranslationHistory();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Translation>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Could not load translation history: ${snapshot.error}');
          return Center(
            child: const Text('Could not load your history. Please try again later.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Your translations will appear here and stay available offline.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = history[index];
            return Card(
              child: ListTile(
                title: Text(
                  item.originalText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${AppLanguage.fromCode(item.sourceLanguage).name} → '
                  '${AppLanguage.fromCode(item.targetLanguage).name}\n'
                  '${item.translatedText}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
