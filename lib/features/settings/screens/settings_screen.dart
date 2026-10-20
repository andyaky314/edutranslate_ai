import 'package:flutter/material.dart';

import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../dictionary/services/dictionary_importer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.repository,
    required this.importer,
    required this.preferredLanguage,
    required this.preferredYearLevel,
    required this.onLanguageChanged,
    required this.onYearLevelChanged,
    super.key,
  });

  final LearningRepository repository;
  final DictionaryImporter importer;
  final AppLanguage preferredLanguage;
  final int? preferredYearLevel;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<int?> onYearLevelChanged;

  Future<void> _saveLanguage(BuildContext context, AppLanguage language) async {
    try {
      await repository.setSetting('preferredLanguage', language.code);
      onLanguageChanged(language);
    } catch (error) {
      debugPrint('Could not save language preference: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this setting. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _saveYearLevel(BuildContext context, String? value) async {
    final yearLevel = value == null || value == 'all' ? null : int.parse(value);
    try {
      await repository.setSetting(
        'preferredYearLevel',
        yearLevel?.toString() ?? 'all',
      );
      onYearLevelChanged(yearLevel);
    } catch (error) {
      debugPrint('Could not save year level: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this setting. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _showDictionaryImport(BuildContext context) async {
    final controller = TextEditingController();
    final importCount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import dictionary'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste a version 1 JSON export. The full file is validated before any entries are saved.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: '{"schemaVersion": 1, "entries": [...]}',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final count = await importer.importJson(controller.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext, count);
              } on DictionaryImportException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              } catch (error) {
                debugPrint('Dictionary import failed: $error');
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Import could not be completed. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Validate and import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (context.mounted && importCount != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $importCount dictionary entries.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Learning preferences',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<AppLanguage>(
              initialValue: preferredLanguage,
              decoration: const InputDecoration(
                labelText: 'Preferred learning language',
                border: OutlineInputBorder(),
              ),
              items: AppLanguage.all
                  .map(
                    (language) => DropdownMenuItem(
                      value: language,
                      child: Text(language.name),
                    ),
                  )
                  .toList(),
              onChanged: (language) {
                if (language != null) _saveLanguage(context, language);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: preferredYearLevel?.toString() ?? 'all',
              decoration: const InputDecoration(
                labelText: 'SJKC year level',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All years')),
                for (var year = 1; year <= 6; year++)
                  DropdownMenuItem(value: '$year', child: Text('Year $year')),
              ],
              onChanged: (value) {
                if (value != null) _saveYearLevel(context, value);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Dictionary content',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Reviewed entries only'),
                subtitle: Text(
                  'Only entries marked "published" are used by the offline translator.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import dictionary JSON'),
                subtitle: const Text('Version 1 · English, BM and Chinese'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDictionaryImport(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'About offline learning',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your translation history, saved words, favourites, and review counts are stored on this device. The current translator uses the imported local dictionary; no student text is sent to an AI provider.',
            ),
          ),
        ),
      ],
    );
  }
}
