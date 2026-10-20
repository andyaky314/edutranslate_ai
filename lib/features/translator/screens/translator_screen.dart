import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/languages.dart';
import '../../../data/repositories/learning_repository.dart';
import '../models/translation.dart';
import '../services/translator_service.dart';
import 'live_text_camera_screen.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({
    required this.service,
    required this.repository,
    required this.preferredLanguage,
    required this.preferredYearLevel,
    super.key,
  });

  final TranslatorService service;
  final LearningRepository repository;
  final AppLanguage preferredLanguage;
  final int? preferredYearLevel;

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TextEditingController _controller = TextEditingController();
  late AppLanguage _sourceLanguage;
  late AppLanguage _targetLanguage;
  Translation? _result;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  bool _saved = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _sourceLanguage = widget.preferredLanguage;
    _targetLanguage = AppLanguage.all.firstWhere(
      (language) => language != _sourceLanguage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _swapLanguages() {
    setState(() {
      final previousSource = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = previousSource;
    });
  }

  Future<void> _translate() async {
    if (_loading) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _saved = false;
    });
    try {
      final translation = await widget.service.translate(
        text: _controller.text,
        from: _sourceLanguage.name,
        to: _targetLanguage.name,
        yearLevel: widget.preferredYearLevel,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _result = translation);
    } on TranslationUnavailableException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      debugPrint('Translation operation failed: $error');
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Translation failed. Please try again.');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveVocabulary() async {
    final result = _result;
    if (result == null || _saving || _saved) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveVocabulary(result);
      if (mounted) setState(() => _saved = true);
    } catch (error) {
      debugPrint('Could not save vocabulary item: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this word. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clear() {
    _requestId++;
    _controller.clear();
    setState(() {
      _result = null;
      _error = null;
      _saved = false;
      _loading = false;
    });
  }

  Future<void> _readFromCamera() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LiveTextCameraScreen(
          script: _sourceLanguage.code == 'zh'
              ? TextRecognitionScript.chinese
              : TextRecognitionScript.latin,
        ),
      ),
    );
    if (text == null || !mounted) return;
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      _result = null;
      _error = null;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text(
          'Understand a word',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Translate words and sentences with Gemini AI. Your history stays on this device.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _languageDropdown(
                label: 'From',
                value: _sourceLanguage,
                onChanged: (language) => setState(() {
                  _sourceLanguage = language;
                  if (_sourceLanguage == _targetLanguage) {
                    _targetLanguage = AppLanguage.all.firstWhere(
                      (item) => item != language,
                    );
                  }
                }),
              ),
            ),
            IconButton(
              tooltip: 'Swap languages',
              onPressed: _swapLanguages,
              icon: const Icon(Icons.swap_horiz),
            ),
            Expanded(
              child: _languageDropdown(
                label: 'To',
                value: _targetLanguage,
                onChanged: (language) => setState(() {
                  _targetLanguage = language;
                  if (_sourceLanguage == _targetLanguage) {
                    _sourceLanguage = AppLanguage.all.firstWhere(
                      (item) => item != language,
                    );
                  }
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _translate(),
          decoration: InputDecoration(
            hintText: 'Type a word or sentence',
            filled: true,
            suffixIcon: IconButton(
              tooltip: 'Clear text',
              onPressed: _clear,
              icon: const Icon(Icons.clear),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _readFromCamera,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Read text with camera'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _translate,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate),
          label: Text(_loading ? 'Translating…' : 'Translate'),
        ),
        const SizedBox(height: 16),
        if (_error != null) _MessageCard(message: _error!, isError: true),
        if (_result != null)
          _TranslationCard(
            translation: _result!,
            saving: _saving,
            saved: _saved,
            onSave: _saveVocabulary,
          ),
        if (_result == null && _error == null)
          const _MessageCard(
            message: 'AI-generated translations may need checking. Do not enter personal or private information.',
          ),
      ],
    );
  }

  Widget _languageDropdown({
    required String label,
    required AppLanguage value,
    required ValueChanged<AppLanguage> onChanged,
  }) {
    return DropdownButtonFormField<AppLanguage>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: AppLanguage.all
          .map(
            (language) => DropdownMenuItem(
              value: language,
              child: Text(language.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _loading
          ? null
          : (language) {
              if (language != null) onChanged(language);
            },
    );
  }
}

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.translation,
    required this.saving,
    required this.saved,
    required this.onSave,
  });

  final Translation translation;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (translation.isAiGenerated) ...[
              const Chip(
                avatar: Icon(Icons.auto_awesome, size: 16),
                label: Text('AI-generated · Check the meaning'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              translation.translatedText,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${translation.originalText} · ${translation.partOfSpeech ?? ''}',
            ),
            if (translation.pronunciation?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text('Pronunciation: ${translation.pronunciation}'),
            ],
            const Divider(height: 28),
            Text(
              'What it means',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(translation.definition ?? translation.studentExplanation),
            const SizedBox(height: 12),
            Text(
              'In simple words',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(translation.studentExplanation),
            if (translation.exampleSentence?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Example',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(translation.exampleSentence!),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: saving || saved ? null : onSave,
              icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(saved ? 'Saved to vocabulary' : 'Save this word'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}
