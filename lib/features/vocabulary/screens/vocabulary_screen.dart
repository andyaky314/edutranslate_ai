import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../models/vocabulary_item.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({required this.repository, super.key});

  final LearningRepository repository;

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  late Future<List<VocabularyItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.repository.getVocabulary();
  }

  void _refresh() {
    setState(() => _items = widget.repository.getVocabulary());
  }

  Future<void> _toggleFavorite(String id) async {
    try {
      await widget.repository.toggleFavorite(id);
      _refresh();
    } catch (error) {
      debugPrint('Could not update vocabulary favourite: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('favoriteError'))),
        );
      }
    }
  }

  Future<void> _removeWord(VocabularyItem item) async {
    final strings = AppStrings.of(context);
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.removeWordTitle(item.word)),
        content: Text(strings.text('removeWordExplanation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('remove')),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;

    try {
      await widget.repository.deleteVocabulary(item.id);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.wordRemoved(item.word))));
    } catch (error) {
      debugPrint('Could not remove vocabulary item: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this word. Please try again.'),
          ),
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
          debugPrint('Could not load vocabulary: ${snapshot.error}');
          return _StateMessage(
            icon: Icons.error_outline,
            message: strings.text('wordsError'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _StateMessage(
            icon: Icons.menu_book_outlined,
            message: strings.text('yourWordsEmpty'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                title: Text(
                  item.word,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${AppLanguage.fromCode(item.language).name} · ${item.meaning}\n${item.explanation}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: item.isFavorite
                          ? strings.text('removeFavorite')
                          : strings.text('addFavorite'),
                      icon: Icon(
                        item.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: item.isFavorite ? Colors.pink : null,
                      ),
                      onPressed: () => _toggleFavorite(item.id),
                    ),
                    IconButton(
                      tooltip: strings.text('removeFromWordsCards'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeWord(item),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
