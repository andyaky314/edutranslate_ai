import 'package:flutter/material.dart';

import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../translator/models/translation.dart';
import 'translation_history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.repository, super.key});

  final LearningRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Translation>> _history;
  final Set<String> _savedWordIds = {};
  final Set<String> _savingWordIds = {};

  @override
  void initState() {
    super.initState();
    _history = widget.repository.getTranslationHistory();
    _loadSavedWords();
  }

  Future<void> _loadSavedWords() async {
    try {
      final savedWords = await widget.repository.getVocabulary();
      if (!mounted) return;
      setState(() {
        _savedWordIds.addAll(savedWords.map((word) => word.id));
      });
    } catch (error) {
      debugPrint('Could not load saved words from history: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check which history words are saved.'),
          ),
        );
      }
    }
  }

  String _vocabularyId(Translation translation) =>
      translation.dictionaryEntryId ??
      '${translation.sourceLanguage}-${translation.originalText.trim().toLowerCase()}';

  Future<void> _saveWord(Translation translation) async {
    final id = _vocabularyId(translation);
    if (_savedWordIds.contains(id) || _savingWordIds.contains(id)) return;
    setState(() => _savingWordIds.add(id));
    try {
      await widget.repository.saveVocabulary(translation);
      if (!mounted) return;
      setState(() => _savedWordIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '“${translation.originalText}” saved to Words and Cards.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Could not save vocabulary from history: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this word. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingWordIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Translation>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Could not load translation history: ${snapshot.error}');
          return Center(
            child: const Text(
              'Could not load your history. Please try again later.',
            ),
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _savedWordIds.contains(_vocabularyId(item))
                          ? 'Saved word'
                          : 'Save word',
                      icon: Icon(
                        _savedWordIds.contains(_vocabularyId(item))
                            ? Icons.bookmark_added_outlined
                            : Icons.bookmark_add_outlined,
                      ),
                      onPressed:
                          _savedWordIds.contains(_vocabularyId(item)) ||
                              _savingWordIds.contains(_vocabularyId(item))
                          ? null
                          : () => _saveWord(item),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TranslationHistoryDetailScreen(translation: item),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
