import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/app_strings.dart';
import '../../../core/languages.dart';
import '../../../core/learning_level.dart';
import '../../../data/repositories/learning_repository.dart';
import '../models/translation.dart';
import '../services/translator_service.dart';
import 'live_text_camera_screen.dart';
import '../widgets/translation_meanings_panel.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({
    required this.service,
    required this.repository,
    required this.preferredLanguage,
    required this.learningLevel,
    super.key,
  });

  final TranslatorService service;
  final LearningRepository repository;
  final AppLanguage preferredLanguage;
  final LearningLevel learningLevel;

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late AppLanguage _sourceLanguage;
  late AppLanguage _targetLanguage;
  Translation? _result;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  bool _saved = false;
  bool _listening = false;
  bool _autoDetectSource = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _sourceLanguage = widget.preferredLanguage;
    _targetLanguage = AppLanguage.chinese;
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  void _swapLanguages() {
    if (_loading || _saving || _listening) return;
    setState(() {
      final previousSource = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = previousSource;
      _invalidateTranslation();
    });
  }

  void _invalidateTranslation() {
    _result = null;
    _error = null;
    _saved = false;
  }

  void _onInputChanged(String _) {
    if (_result == null && _error == null && !_saved) return;
    setState(_invalidateTranslation);
  }

  Future<void> _translate() async {
    if (_loading || _saving) return;
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
    }
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
        from: _autoDetectSource ? 'Auto detect' : _sourceLanguage.name,
        to: _targetLanguage.name,
        yearLevel: widget.learningLevel.promptYearLevel,
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
    if (_loading || _saving || _listening) return;
    _requestId++;
    _controller.clear();
    setState(_invalidateTranslation);
  }

  Future<void> _readFromCamera() async {
    final strings = AppStrings.of(context);
    final source = await showModalBottomSheet<TextReaderSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(strings.text('openCamera')),
              subtitle: Text(strings.text('capturePrompt')),
              onTap: () => Navigator.pop(context, TextReaderSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.text('readStoredImage')),
              subtitle: Text(strings.text('capturePrompt')),
              onTap: () => Navigator.pop(context, TextReaderSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LiveTextCameraScreen(initialSource: source),
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

  Future<void> _toggleVoiceInput() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (mounted) {
            setState(() => _listening = false);
            if (error.errorMsg.toLowerCase().contains('language')) {
              _showVoiceLanguageSettings();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
              );
            }
          }
        },
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Speech recognition is unavailable on this device.',
              ),
            ),
          );
        }
        return;
      }
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          if (mounted) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.collapsed(
                offset: _controller.text.length,
              );
              _result = null;
              _error = null;
              _saved = false;
            });
          }
        },
      );
      if (mounted) setState(() => _listening = true);
    } catch (error) {
      debugPrint('Voice input failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start voice input. Check microphone permission and device language support.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showVoiceLanguageSettings() async {
    if (!mounted) return;
    final strings = AppStrings.of(context);
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('enableSpeechLanguage')),
        content: SingleChildScrollView(
          child: Text(strings.text('voiceSetupHelp')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.settings_outlined),
            label: Text(strings.text('openVoiceSettings')),
          ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return;

    try {
      final opened = await const MethodChannel(
        'com.cazstudio.edutranslate_ai/voice_settings',
      ).invokeMethod<bool>('openVoiceInputSettings');
      if (opened != true && mounted) {
        _showManualVoiceSettingsHint();
      }
    } on PlatformException catch (error) {
      debugPrint('Could not open voice input settings: ${error.message}');
      if (mounted) _showManualVoiceSettingsHint();
    } on MissingPluginException {
      if (mounted) _showManualVoiceSettingsHint();
    }
  }

  void _showManualVoiceSettingsHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Open your device Settings and search for Voice input or speech recognition.',
        ),
      ),
    );
  }

  Future<void> _speak(String text, String languageCode) async {
    if (text.trim().isEmpty) return;
    final locale = switch (languageCode) {
      'zh' => 'zh-CN',
      'ms' => 'ms-MY',
      _ => 'en-US',
    };
    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (error) {
      debugPrint('Text to speech failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Speech playback is unavailable for this language on this device.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final strings = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text(
          strings.text('understandWord'),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          strings.text('translatorSubtitle'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _sourceDropdown()),
            IconButton(
              tooltip: strings.text('swapLanguages'),
              onPressed: _loading || _saving || _listening
                  ? null
                  : _swapLanguages,
              icon: const Icon(Icons.swap_horiz),
            ),
            Expanded(
              child: _languageDropdown(
                label: strings.text('to'),
                value: _targetLanguage,
                onChanged: (language) => setState(() {
                  _targetLanguage = language;
                  if (_sourceLanguage == _targetLanguage) {
                    _sourceLanguage = AppLanguage.all.firstWhere(
                      (item) => item != language,
                    );
                  }
                  _invalidateTranslation();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          enabled: !_loading && !_saving && !_listening,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          onChanged: _onInputChanged,
          onSubmitted: (_) => _translate(),
          decoration: InputDecoration(
            hintText: strings.text('typeText'),
            filled: true,
            suffixIcon: IconButton(
              tooltip: strings.text('clearText'),
              onPressed: _loading || _saving || _listening ? null : _clear,
              icon: const Icon(Icons.clear),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading || _saving || _listening ? null : _readFromCamera,
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(strings.text('readImage')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading || _saving ? null : _toggleVoiceInput,
          icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
          label: Text(strings.text(_listening ? 'listening' : 'pressToSpeak')),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            strings.text('speechHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _translate,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate),
          label: Text(strings.text(_loading ? 'translating' : 'translate')),
        ),
        const SizedBox(height: 16),
        if (_error != null) _MessageCard(message: _error!, isError: true),
        if (result != null)
          _TranslationCard(
            translation: result,
            saving: _saving,
            saved: _saved,
            onSave: _saveVocabulary,
            onSpeakTranslation: (text) => _speak(text, result.targetLanguage),
            onSpeakExample: (text) => _speak(text, result.targetLanguage),
            onSpeakOriginal: () =>
                _speak(result.originalText, result.sourceLanguage),
          ),
        if (_result == null && _error == null)
          _MessageCard(message: strings.text('translationPrivacy')),
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
      onChanged: _loading || _saving || _listening
          ? null
          : (language) {
              if (language != null) onChanged(language);
            },
    );
  }

  Widget _sourceDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _autoDetectSource ? 'auto' : _sourceLanguage.code,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppStrings.of(context).text('from'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: [
        DropdownMenuItem(
          value: 'auto',
          child: Text(AppStrings.of(context).text('autoDetect')),
        ),
        ...AppLanguage.all.map(
          (language) => DropdownMenuItem(
            value: language.code,
            child: Text(language.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _loading || _saving || _listening
          ? null
          : (code) {
              if (code == null) return;
              setState(() {
                _autoDetectSource = code == 'auto';
                if (!_autoDetectSource) {
                  _sourceLanguage = AppLanguage.fromCode(code);
                  if (_sourceLanguage == _targetLanguage) {
                    _targetLanguage = AppLanguage.all.firstWhere(
                      (item) => item != _sourceLanguage,
                    );
                  }
                }
                _invalidateTranslation();
              });
            },
    );
  }
}

class _TranslationCard extends StatefulWidget {
  const _TranslationCard({
    required this.translation,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onSpeakTranslation,
    required this.onSpeakExample,
    required this.onSpeakOriginal,
  });

  final Translation translation;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;
  final ValueChanged<String> onSpeakTranslation;
  final ValueChanged<String> onSpeakExample;
  final VoidCallback onSpeakOriginal;

  @override
  State<_TranslationCard> createState() => _TranslationCardState();
}

class _TranslationCardState extends State<_TranslationCard> {
  int _selectedMeaningIndex = 0;

  @override
  void didUpdateWidget(covariant _TranslationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.translation, widget.translation)) {
      _selectedMeaningIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = widget.translation;
    final strings = AppStrings.of(context);
    final selectedMeaning =
        translation.possibleMeanings[_selectedMeaningIndex.clamp(
          0,
          translation.possibleMeanings.length - 1,
        )];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (translation.isAiGenerated) ...[
              Chip(
                avatar: Icon(Icons.auto_awesome, size: 16),
                label: Text(strings.text('aiCheck')),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: AppStrings.of(context).text('readTranslation'),
                onPressed: () =>
                    widget.onSpeakTranslation(selectedMeaning.translatedText),
                icon: const Icon(Icons.volume_up_outlined),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${translation.originalText} · ${selectedMeaning.partOfSpeech ?? translation.partOfSpeech ?? ''}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: AppStrings.of(context).text('readOriginal'),
                onPressed: widget.onSpeakOriginal,
                icon: const Icon(Icons.volume_up_outlined),
              ),
            ),
            if (translation.pronunciation?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                '${AppStrings.of(context).text('pronunciation')}: ${translation.pronunciation}',
              ),
            ],
            const Divider(height: 28),
            TranslationMeaningsPanel(
              translation: translation,
              selectedIndex: _selectedMeaningIndex,
              onSelected: (index) =>
                  setState(() => _selectedMeaningIndex = index),
              onSpeakExample: widget.onSpeakExample,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.saving || widget.saved ? null : widget.onSave,
              icon: Icon(
                widget.saved ? Icons.check : Icons.bookmark_add_outlined,
              ),
              label: Text(
                widget.saved
                    ? AppStrings.of(context).text('savedWord')
                    : AppStrings.of(context).text('saveWord'),
              ),
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
