import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class LiveTextCameraScreen extends StatefulWidget {
  const LiveTextCameraScreen({this.script, super.key});

  /// Null runs Latin and Chinese recognition to support Auto detect and mixed
  /// language images. A selected script keeps capture faster.
  final TextRecognitionScript? script;

  @override
  State<LiveTextCameraScreen> createState() => _LiveTextCameraScreenState();
}

class _LiveTextCameraScreenState extends State<LiveTextCameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  late final List<TextRecognizer> _recognizers;
  CameraController? _controller;
  List<String> _candidates = const [];
  String _recognizedText = '';
  String? _capturedPath;
  Size? _imageSize;
  List<Rect> _recognizedRegions = const [];
  String? _error;
  bool _processing = false;
  bool _initializing = false;
  bool _choosingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizers = (widget.script == null
            ? [TextRecognitionScript.latin, TextRecognitionScript.chinese]
            : [widget.script!])
        .map((script) => TextRecognizer(script: script))
        .toList();
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
        // Ask for the sharpest still the device supports; small print needs
        // more source pixels for OCR to find and distinguish characters.
        ResolutionPreset.max,
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

  Future<Size?> _readImageSize(String path) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (error) {
      debugPrint('Could not read captured image dimensions: $error');
      return null;
    } finally {
      codec?.dispose();
    }
  }

  Future<_RecognitionResult> _recognizeImage(String path) async {
    final input = InputImage.fromFilePath(path);
    final candidates = <String, String>{};
    final lines = <_RecognizedLine>[];
    final regions = <Rect>[];
    for (final recognizer in _recognizers) {
      final recognized = await recognizer.processImage(input);
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          candidates.putIfAbsent(text.toLowerCase(), () => text);
          for (final element in line.elements) {
            final word = element.text.trim();
            if (word.isNotEmpty) {
              candidates.putIfAbsent(word.toLowerCase(), () => word);
              regions.add(element.boundingBox);
            }
          }
          if (line.elements.isEmpty) regions.add(line.boundingBox);
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
      candidates.values.toList(),
      lines.map((line) => line.text).join('\n'),
      regions,
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
    } catch (error, stackTrace) {
      debugPrint('Could not capture or read image: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error =
              'Could not read this image. Try again or choose another.',
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
    } catch (error, stackTrace) {
      debugPrint('Could not choose or read image: $error\n$stackTrace');
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
    if (mounted) {
      setState(() {
        _capturedPath = path;
        _imageSize = null;
        _recognizedRegions = const [];
      });
    }
    final imageSizeFuture = _readImageSize(path);
    final recognitionFuture = _recognizeImage(path);
    final imageSize = await imageSizeFuture;
    final result = await recognitionFuture;
    if (mounted) {
      setState(() {
        _candidates = result.words;
        _recognizedText = result.text;
        _recognizedRegions = result.regions;
        _imageSize = imageSize;
      });
    }
  }

  Future<void> _retake() async {
    if (!mounted) return;
    setState(() {
      _capturedPath = null;
      _imageSize = null;
      _recognizedRegions = const [];
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
    for (final recognizer in _recognizers) {
      recognizer.close();
    }
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
            _CapturedImageWithRegions(
              path: _capturedPath!,
              imageSize: _imageSize,
              regions: _recognizedRegions,
            )
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
              captured ? 'Recognized areas outlined — tap a word' : 'Read text',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (captured && recognizedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 72),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(recognizedText),
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
                  if (candidates.isNotEmpty) ...[
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
                        ? 'No text found. Try a closer, sharper photo or choose another image.'
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
                              maxLines: 3,
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
  const _RecognitionResult(this.words, this.text, this.regions);

  final List<String> words;
  final String text;
  final List<Rect> regions;
}

class _RecognizedLine {
  const _RecognizedLine(this.text, this.bounds);

  final String text;
  final Rect bounds;
}

class _CapturedImageWithRegions extends StatelessWidget {
  const _CapturedImageWithRegions({
    required this.path,
    required this.imageSize,
    required this.regions,
  });

  final String path;
  final Size? imageSize;
  final List<Rect> regions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: Image.file(File(path), fit: BoxFit.contain)),
              if (imageSize != null && regions.isNotEmpty)
                CustomPaint(
                  painter: _TextRegionPainter(
                    imageSize: imageSize!,
                    regions: regions,
                  ),
                ),
            ],
          );
        },
      );
}

class _TextRegionPainter extends CustomPainter {
  const _TextRegionPainter({
    required this.imageSize,
    required this.regions,
  });

  final Size imageSize;
  final List<Rect> regions;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / imageSize.width) <
            (size.height / imageSize.height)
        ? (size.width / imageSize.width)
        : (size.height / imageSize.height);
    final fittedWidth = imageSize.width * scale;
    final fittedHeight = imageSize.height * scale;
    final offsetX = (size.width - fittedWidth) / 2;
    final offsetY = (size.height - fittedHeight) / 2;
    final paint = Paint()
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final region in regions) {
      final fitted = Rect.fromLTRB(
        offsetX + region.left * scale,
        offsetY + region.top * scale,
        offsetX + region.right * scale,
        offsetY + region.bottom * scale,
      );
      canvas.drawRect(fitted, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TextRegionPainter oldDelegate) =>
      imageSize != oldDelegate.imageSize ||
      regions != oldDelegate.regions;
}
