import 'package:flutter/material.dart';

import '../../../core/languages.dart';
import '../../translator/models/translation.dart';
import '../../translator/widgets/translation_meanings_panel.dart';

class TranslationHistoryDetailScreen extends StatefulWidget {
  const TranslationHistoryDetailScreen({required this.translation, super.key});

  final Translation translation;

  @override
  State<TranslationHistoryDetailScreen> createState() =>
      _TranslationHistoryDetailScreenState();
}

class _TranslationHistoryDetailScreenState
    extends State<TranslationHistoryDetailScreen> {
  int _selectedMeaningIndex = 0;

  @override
  Widget build(BuildContext context) {
    final translation = widget.translation;
    return Scaffold(
      appBar: AppBar(title: const Text('Word details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            translation.originalText,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppLanguage.fromCode(translation.sourceLanguage).name} → '
            '${AppLanguage.fromCode(translation.targetLanguage).name}',
          ),
          if (translation.isAiGenerated) ...[
            const SizedBox(height: 8),
            const Chip(
              avatar: Icon(Icons.auto_awesome, size: 16),
              label: Text('AI-generated · Check the meaning'),
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (translation.pronunciation?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text('Pronunciation: ${translation.pronunciation}'),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: TranslationMeaningsPanel(
                translation: translation,
                selectedIndex: _selectedMeaningIndex,
                onSelected: (index) =>
                    setState(() => _selectedMeaningIndex = index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
