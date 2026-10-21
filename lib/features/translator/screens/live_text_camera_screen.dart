import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class LiveTextCameraScreen extends StatefulWidget {
  const LiveTextCameraScreen({super.key});

  @override
  State<LiveTextCameraScreen> createState() => _LiveTextCameraScreenState();
}

class _LiveTextCameraScreenState extends State<LiveTextCameraScreen>
    with WidgetsBindingObserver {
  static final _wordPattern = RegExp(
    r"^[\p{L}\p{M}]+(?:['\u2019\-][\p{L}\p{M}]+)*$",
    unicode: true,
  );
  static final _wordSeparators = RegExp(r"['\u2019\-]");
  static final _singleCjkCharacter = RegExp(r'[\u3400-\u9fff]');

  final ImagePicker _imagePicker = ImagePicker();
  late final TextRecognizer _latinRecognizer;
  late final TextRecognizer _chineseRecognizer;
  CameraController? _controller;
  List<String> _candidates = const [];
  String _recognizedText = '';
  String? _capturedPath;
  String? _error;
  bool _processing = false;
  bool _initializing = false;
  bool _choosingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed &&
        !_choosingImage &&
        _capturedPath == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing || _controller != null || !mounted) return;
    _initializing = true;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw CameraException(
          'unsupported_platform',
          'Camera recognition is available on Android and iOS.',
        );
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera was found.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraErrorMessage(error));
      await _releaseCamera();
    } catch (error) {
      debugPrint('Could not start text-reading camera: $error');
      if (mounted) {
        setState(
          () => _error =
              'Could not start the camera. You can choose an image instead.',
        );
      }
      await _releaseCamera();
    } finally {
      _initializing = false;
    }
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted') {
      return 'Camera access is needed to capture text. Allow camera access in device settings, or choose an image.';
    }
    return error.description ??
        'Could not start the camera. You can choose an image instead.';
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    await controller.dispose();
  }

  List<String> _wordsIn(RecognizedText recognized) {
    final words = <String, String>{};
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final word = element.text.trim();
          if (!_isWord(word)) continue;
          words.putIfAbsent(word.toLowerCase(), () => word);
        }
      }
    }
    return words.values.take(60).toList();
  }

  bool _isWord(String text) {
    if (!_wordPattern.hasMatch(text)) return false;
    final letters = text.replaceAll(_wordSeparators, '');
    if (letters.runes.length >= 2) return true;
    return text.toLowerCase() == 'a' ||
        text.toLowerCase() == 'i' ||
        _singleCjkCharacter.hasMatch(text);
  }

  Future<_RecognitionResult> _recognizeImage(String path) async {
    final input = InputImage.fromFilePath(path);
    final candidates = <String, String>{};
    final lines = <_RecognizedLine>[];
    for (final recognizer in [_latinRecognizer, _chineseRecognizer]) {
      final recognized = await recognizer.processImage(input);
      for (final word in _wordsIn(recognized)) {
        candidates.putIfAbsent(word.toLowerCase(), () => word);
      }
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          // Retain whole OCR lines as selectable suggestions; strict word
          // filtering can otherwise discard useful text, especially Chinese.
          candidates.putIfAbsent(text.toLowerCase(), () => text);
          final duplicate = lines.any(
            (existing) =>
                existing.text.toLowerCase() == text.toLowerCase() &&
                existing.bounds.overlaps(line.boundingBox),
          );
          if (!duplicate) {
            lines.add(_RecognizedLine(text, line.boundingBox));
          }
        }
      }
    }
    lines.sort((a, b) {
      final verticalDelta = a.bounds.top - b.bounds.top;
      final sameRowTolerance = (a.bounds.height + b.bounds.height) / 4;
      if (verticalDelta.abs() > sameRowTolerance) {
        return verticalDelta.compareTo(0);
      }
      return a.bounds.left.compareTo(b.bounds.left);
    });
    return _RecognitionResult(
      candidates.values.take(60).toList(),
      lines.map((line) => line.text).join('\n'),
    );
  }

  Future<void> _captureImage() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _processing ||
        _capturedPath != null) {
      return;
    }
    setState(() {
      _processing = true;
      _candidates = const [];
      _recognizedText = '';
      _error = null;
    });
    try {
      final photo = await controller.takePicture();
      await _readImage(photo.path);
    } catch (error) {
      debugPrint('Could not capture or read image: $error');
      if (mounted) {
        setState(
          () => _error = 'Could not read this image. Try again or choose one.',
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _chooseImage() async {
    if (_processing) return;
    _choosingImage = true;
    if (mounted) {
      setState(() {
        _processing = true;
        _error = null;
      });
    }
    try {
      await _releaseCamera();
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() {
        _candidates = const [];
        _recognizedText = '';
      });
      await _readImage(image.path);
    } catch (error) {
      debugPrint('Could not choose or read image: $error');
      if (mounted) {
        setState(
          () => _error = 'Could not open this image. Please choose another.',
        );
      }
    } finally {
      _choosingImage = false;
      if (mounted) {
        setState(() => _processing = false);
        if (_capturedPath == null) await _initializeCamera();
      }
    }
  }

  Future<void> _readImage(String path) async {
    if (mounted) setState(() => _capturedPath = path);
    final result = await _recognizeImage(path);
    if (mounted) {
      setState(() {
        _candidates = result.words;
        _recognizedText = result.text;
      });
    }
  }

  Future<void> _retake() async {
    if (!mounted) return;
    setState(() {
      _capturedPath = null;
      _candidates = const [];
      _recognizedText = '';
      _error = null;
    });
    if (_controller == null) await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseCamera();
    _latinRecognizer.close();
    _chineseRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isCaptured = _capturedPath != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read text'),
        actions: [
          IconButton(
            tooltip: 'Choose image',
            onPressed: _processing || _initializing ? null : _chooseImage,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_capturedPath != null)
            Center(child: Image.file(File(_capturedPath!), fit: BoxFit.contain))
          else if (controller?.value.isInitialized == true)
            Center(child: CameraPreview(controller!))
          else
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DetectedTextPanel(
              candidates: _candidates,
              captured: isCaptured,
              recognizedText: _recognizedText,
              canUseAll: _recognizedText.isNotEmpty,
              busy: _processing,
              canCapture: controller?.value.isInitialized == true,
              canChooseImage: !_initializing,
              onCapture: _captureImage,
              onChooseImage: _chooseImage,
              onRetake: _retake,
              onSelectAll: () => Navigator.of(context).pop(_recognizedText),
              onSelect: (text) => Navigator.of(context).pop(text),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedTextPanel extends StatelessWidget {
  const _DetectedTextPanel({
    required this.candidates,
    required this.onSelect,
    required this.captured,
    required this.recognizedText,
    required this.canUseAll,
    required this.busy,
    required this.canCapture,
    required this.canChooseImage,
    required this.onCapture,
    required this.onChooseImage,
    required this.onRetake,
    required this.onSelectAll,
  });

  final List<String> candidates;
  final ValueChanged<String> onSelect;
  final bool captured;
  final String recognizedText;
  final bool canUseAll;
  final bool busy;
  final bool canCapture;
  final bool canChooseImage;
  final VoidCallback onCapture;
  final VoidCallback onChooseImage;
  final VoidCallback onRetake;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              captured ? 'Captured text ? tap a word to use it' : 'Read text',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (captured && recognizedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 88),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(recognizedText,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!captured) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || !canCapture ? null : onCapture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy || !canChooseImage ? null : onChooseImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose image'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onRetake,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  ),
                  if (canUseAll) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onSelectAll,
                        icon: const Icon(Icons.select_all),
                        label: const Text('Use all text'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (busy)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (candidates.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    captured
                        ? 'No text found. Move closer, keep the camera steady, and try brighter lighting. You can also choose a photo.'
                        : 'Capture text or choose an image to find words.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: candidates
                        .map(
                          (text) => ActionChip(
                            label: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => onSelect(text),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecognitionResult {
  const _RecognitionResult(this.words, this.text);

  final List<String> words;
  final String text;
}

class _RecognizedLine {
  const _RecognizedLine(this.text, this.bounds);

  final String text;
  final Rect bounds;
}
