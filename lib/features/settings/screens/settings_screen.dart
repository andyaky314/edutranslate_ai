import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/learning_level.dart';
import '../../../data/repositories/learning_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.repository,
    required this.appLanguageCode,
    required this.learningLevel,
    required this.themeMode,
    required this.onAppLanguageChanged,
    required this.onLearningLevelChanged,
    required this.onThemeModeChanged,
    super.key,
  });

  final LearningRepository repository;
  final String appLanguageCode;
  final LearningLevel learningLevel;
  final ThemeMode themeMode;
  final ValueChanged<String> onAppLanguageChanged;
  final ValueChanged<LearningLevel> onLearningLevelChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  Future<void> _save(
    BuildContext context,
    String key,
    String value,
    VoidCallback onSaved,
  ) async {
    try {
      await repository.setSetting(key, value);
      onSaved();
    } catch (error) {
      debugPrint('Could not save app setting $key: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this setting. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: appLanguageCode,
              decoration: InputDecoration(
                labelText: strings.text('appLanguage'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(strings.text('followPhone')),
                ),
                const DropdownMenuItem(
                  value: 'ms',
                  child: Text('Bahasa Melayu'),
                ),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'zh', child: Text('中文')),
              ],
              onChanged: (code) {
                if (code == null) return;
                _save(
                  context,
                  'appLanguage',
                  code,
                  () => onAppLanguageChanged(code),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<LearningLevel>(
              initialValue: learningLevel,
              decoration: InputDecoration(
                labelText: strings.text('learningLevel'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: LearningLevel.lowerPrimary,
                  child: Text(strings.text('lowerPrimary')),
                ),
                DropdownMenuItem(
                  value: LearningLevel.upperPrimary,
                  child: Text(strings.text('upperPrimary')),
                ),
                DropdownMenuItem(
                  value: LearningLevel.standard,
                  child: Text(strings.text('standard')),
                ),
              ],
              onChanged: (level) {
                if (level == null) return;
                _save(
                  context,
                  'learningLevel',
                  level.code,
                  () => onLearningLevelChanged(level),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<ThemeMode>(
              initialValue: themeMode,
              decoration: InputDecoration(
                labelText: strings.text('appearance'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(strings.text('systemTheme')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(strings.text('light')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(strings.text('dark')),
                ),
              ],
              onChanged: (mode) {
                if (mode == null) return;
                final value = switch (mode) {
                  ThemeMode.light => 'light',
                  ThemeMode.dark => 'dark',
                  ThemeMode.system => 'system',
                };
                _save(
                  context,
                  'themeMode',
                  value,
                  () => onThemeModeChanged(mode),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
