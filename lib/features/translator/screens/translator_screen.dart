import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
    if (_loading || _saving || _listening) return;
    _requestId++;
    _controller.clear();
    setState(_invalidateTranslation);
  }

  Future<void> _readFromCamera() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LiveTextCameraScreen(
          script: _autoDetectSource
              ? null
              : _sourceLanguage.code == 'zh'
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

  String? get _speechLocale => _autoDetectSource
      ? null
      : switch (_sourceLanguage.code) {
          'zh' => 'zh_CN',
          'ms' => 'ms_MY',
          _ => 'en_US',
        };

  String? _availableSpeechLocale(
    List<LocaleName> locales,
    String requestedLocale,
  ) {
    String normalized(String locale) =>
        locale.toLowerCase().replaceAll('-', '_').split('_#').first;

    final requested = normalized(requestedLocale);
    final exact = locales.where(
      (locale) => normalized(locale.localeId) == requested,
    );
    if (exact.isNotEmpty) return exact.first.localeId;

    if (requested.startsWith('zh')) {
      // Prefer Simplified Mandarin. A generic zh locale is an acceptable
      // fallback, but zh-HK and zh-TW are Cantonese/Traditional alternatives.
      for (final locale in locales) {
        final id = normalized(locale.localeId);
        if (id.startsWith('zh_cn') || id.startsWith('zh_hans')) {
          return locale.localeId;
        }
      }
      for (final locale in locales) {
        if (normalized(locale.localeId) == 'zh') return locale.localeId;
      }
      return null;
    }

    final language = requested.split('_').first;
    for (final locale in locales) {
      if (normalized(locale.localeId).startsWith('${language}_')) {
        return locale.localeId;
      }
    }
    return null;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
            );
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
      final locales = await _speech.locales();
      final requestedLocale = _speechLocale;
      final localeId = requestedLocale == null
          ? null
          : _availableSpeechLocale(locales, requestedLocale);
      if (requestedLocale != null && localeId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _sourceLanguage.code == 'zh'
                    ? 'Mandarin speech recognition is not available. Install or enable a Simplified Chinese speech pack in your phone settings.'
                    : 'Speech recognition for ${_sourceLanguage.name} is not available in your phone\'s speech service.',
              ),
            ),
          );
        }
        return;
      }
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
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
            Expanded(child: _sourceDropdown()),
            IconButton(
              tooltip: 'Swap languages',
              onPressed: _loading || _saving || _listening
                  ? null
                  : _swapLanguages,
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
            hintText: 'Type a word or sentence',
            filled: true,
            suffixIcon: IconButton(
              tooltip: 'Clear text',
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
          label: const Text('Read text from camera or image'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading || _saving ? null : _toggleVoiceInput,
          icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
          label: Text(_listening ? 'Listening… tap to stop' : 'Press to speak'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            _autoDetectSource
                ? 'Auto detect asks Android 14+ to switch between English, Malay, and Mandarin. This needs a compatible speech service and its language models.'
                : 'Voice input uses ${_sourceLanguage.name}. For Chinese, the app requests Simplified Mandarin.',
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
          label: Text(_loading ? 'Translating…' : 'Translate'),
        ),
        const SizedBox(height: 16),
        if (_error != null) _MessageCard(message: _error!, isError: true),
        if (result != null)
          _TranslationCard(
            translation: result,
            saving: _saving,
            saved: _saved,
            onSave: _saveVocabulary,
            onSpeakTranslation: () =>
                _speak(result.translatedText, result.targetLanguage),
            onSpeakExample: () =>
                _speak(result.exampleSentence ?? '', result.targetLanguage),
            onSpeakOriginal: () =>
                _speak(result.originalText, result.sourceLanguage),
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
        labelText: 'From',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: [
        const DropdownMenuItem(value: 'auto', child: Text('Auto detect')),
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

class _TranslationCard extends StatelessWidget {
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
  final VoidCallback onSpeakTranslation;
  final VoidCallback onSpeakExample;
  final VoidCallback onSpeakOriginal;

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
            if (translation.alternateMeanings.length <= 1)
              Text(
                translation.translatedText,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Read translation aloud',
                onPressed: onSpeakTranslation,
                icon: const Icon(Icons.volume_up_outlined),
              ),
            ),
            if (translation.alternateMeanings.length > 1) ...[
              const SizedBox(height: 8),
              Text('Possible meanings',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (var index = 0;
                  index < translation.alternateMeanings.length;
                  index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${index + 1}. ${translation.alternateMeanings[index]}',
                    style: index == 0
                        ? Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)
                        : null,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Text(
              '${translation.originalText} · ${translation.partOfSpeech ?? ''}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Read original aloud',
                onPressed: onSpeakOriginal,
                icon: const Icon(Icons.volume_up_outlined),
              ),
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onSpeakExample,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Read example aloud'),
                ),
              ),
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
