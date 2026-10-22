import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
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
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('wordDetails'))),
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
            Chip(
              avatar: Icon(Icons.auto_awesome, size: 16),
              label: Text(strings.text('aiCheck')),
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (translation.pronunciation?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              '${strings.text('pronunciation')}: ${translation.pronunciation}',
            ),
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
