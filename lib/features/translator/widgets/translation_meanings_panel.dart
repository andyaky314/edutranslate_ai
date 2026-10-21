import 'package:flutter/material.dart';

import '../models/translation.dart';

class TranslationMeaningsPanel extends StatelessWidget {
  const TranslationMeaningsPanel({
    required this.translation,
    required this.selectedIndex,
    required this.onSelected,
    this.onSpeakExample,
    super.key,
  });

  final Translation translation;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<String>? onSpeakExample;

  @override
  Widget build(BuildContext context) {
    final meanings = translation.possibleMeanings;
    final activeIndex = selectedIndex.clamp(0, meanings.length - 1);
    final meaning = meanings[activeIndex];
    final hasDetails =
        meaning.definition != null ||
        meaning.studentExplanation != null ||
        meaning.exampleSentence != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meanings.length > 1) ...[
          Text(
            'Possible meanings',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < meanings.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: index == activeIndex,
              leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
              title: Text(
                meanings[index].translatedText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: index == activeIndex
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: index == activeIndex
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => onSelected(index),
            ),
          const Divider(height: 24),
        ] else ...[
          Text(
            meaning.translatedText,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (meaning.partOfSpeech?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(meaning.partOfSpeech!),
          ],
          const Divider(height: 28),
        ],
        if (hasDetails) ...[
          Text(
            'What it means',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(meaning.definition ?? 'No definition is available.'),
          const SizedBox(height: 12),
          Text(
            'In simple words',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(meaning.studentExplanation ?? 'No explanation is available.'),
          if (meaning.exampleSentence?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              'Example',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(meaning.exampleSentence!),
            if (onSpeakExample != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onSpeakExample!(meaning.exampleSentence!),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Read example aloud'),
                ),
              ),
          ],
        ] else
          const Text(
            'This saved meaning has no explanation or example. Translate it again to get details for this meaning.',
          ),
      ],
    );
  }
}
