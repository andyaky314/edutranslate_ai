import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Reads text (English, Malay, Simplified/Traditional Chinese) from the camera
/// or from a gallery image. The user taps one or more detected words/lines and
/// presses "Use"; the screen pops with the selected String.
class LiveTextCameraScreen extends StatefulWidget {
  const LiveTextCameraScreen({super.key});
  @override
  State<LiveTextCameraScreen> createState() => _LiveTextCameraScreenState();
}

class _LiveTextCameraScreenState extends State<LiveTextCameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  late final List<TextRecognizer> _recognizers;
  CameraController? _controller;
  List<String> _candidates = const [];
  final List<String> _selected = [];
  String? _capturedPath;
  Size? _imageSize;
  List<Rect> _recognizedRegions = const [];
  String? _error;
  bool _processing = false;
  bool _imageProcessing = false;
  bool _initializing = false;
  bool _choosingImage = false;
  bool _cameraRequested = false;
  DateTime _lastProcessedFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Completer<void>? _frameRecognitionDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizers = [
      TextRecognitionScript.latin,
      TextRecognitionScript.chinese,
    ].map((script) => TextRecognizer(script: script)).toList();
    _cameraRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed &&
        _cameraRequested &&
        !_choosingImage &&
        !_imageProcessing &&
        _capturedPath == null) {
      _initializeCamera();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _requestCamera() async {
    _cameraRequested = true;
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializing || _controller != null || !mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    CameraController? controller;
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
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      // The permission dialog can trigger inactive -> _releaseCamera() while
      // initialize() is still running. Bail out if we no longer own it.
      if (!mounted || _controller != controller) return;
      await controller.startImageStream(_processFrame);
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      if (_controller == controller) await _releaseCamera();
      if (mounted) setState(() => _error = _cameraErrorMessage(error));
    } catch (error) {
      debugPrint('Could not start text-reading camera: $error');
      if (_controller == controller) await _releaseCamera();
      if (mounted) {
        setState(
          () => _error =
              'Could not start the camera. You can choose an image instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted') {
      return 'Camera access is needed to read text. Allow camera access in device settings, or choose an image.';
    }
    return error.description ??
        'Could not start the camera. You can choose an image instead.';
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (error) {
      debugPrint('Could not stop image stream: $error');
    }
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('Could not dispose camera: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Live frame recognition
  // ---------------------------------------------------------------------------

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    final now = DateTime.now();
    if (_processing ||
        _imageProcessing ||
        _choosingImage ||
        controller == null ||
        _capturedPath != null ||
        now.difference(_lastProcessedFrame).inMilliseconds < 350) {
      return;
    }
    _processing = true;
    final frameRecognitionDone = Completer<void>();
    _frameRecognitionDone = frameRecognitionDone;
    _lastProcessedFrame = now;
    try {
      final input = _inputImageFromCameraImage(image, controller);
      if (input == null) {
        const message =
            'This camera does not provide a supported image format for text recognition.';
        if (mounted && _error != message) {
          setState(() => _error = message);
        }
        return;
      }
      final result = await _recognizeInputImage(input);
      if (mounted && _capturedPath == null && !_imageProcessing) {
        setState(() {
          _candidates = result.words;
          _error = result.warning;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Live text recognition failed: $error\n$stackTrace');
      if (mounted && _capturedPath == null && !_imageProcessing) {
        setState(() {
          _candidates = const [];
          _error = error is _RecognitionFailure
              ? error.message
              : 'Could not recognize text from the camera. Choose an image or try again.';
        });
      }
    } finally {
      _processing = false;
      frameRecognitionDone.complete();
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final sensorOrientation = controller.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var compensation = orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation =
          controller.description.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + compensation) % 360
          : (sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null ||
        format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recognition helpers
  // ---------------------------------------------------------------------------

  /// Strips leading/trailing punctuation, symbols and whitespace so that
  /// "apple," becomes "apple".
  static final RegExp _edgeJunk = RegExp(
    r'^[\p{P}\p{S}\s]+|[\p{P}\p{S}\s]+$',
    unicode: true,
  );
  String _clean(String s) => s.replaceAll(_edgeJunk, '');

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

  Future<_RecognitionResult> _recognizeImage(String path) {
    return _recognizeInputImage(InputImage.fromFilePath(path));
  }

  Future<_RecognitionResult> _recognizeInputImage(InputImage input) async {
    final candidates = <String, String>{};
    final regionKeys = <String>{};
    final regions = <Rect>[];
    final failedScripts = <String, String>{};
    var successfulRecognizers = 0;

    void addRegion(Rect rect) {
      // Both recognizers may report the same box; keep one.
      final key = '${rect.left.round()},${rect.top.round()},'
          '${rect.right.round()},${rect.bottom.round()}';
      if (regionKeys.add(key)) regions.add(rect);
    }

    void addCandidate(String raw) {
      final text = _clean(raw.trim());
      if (text.isEmpty) return;
      candidates.putIfAbsent(text.toLowerCase(), () => text);
    }

    for (final recognizer in _recognizers) {
      try {
        final recognized = await recognizer.processImage(input);
        successfulRecognizers++;
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            if (line.text.trim().isEmpty) continue;
            addCandidate(line.text);
            for (final element in line.elements) {
              if (element.text.trim().isEmpty) continue;
              addCandidate(element.text);
              addRegion(element.boundingBox);
            }
            if (line.elements.isEmpty) addRegion(line.boundingBox);
          }
        }
      } catch (error, stackTrace) {
        final script = recognizer.script.name;
        debugPrint('Text recognition failed for $script: $error\n$stackTrace');
        failedScripts[script] = error.toString();
      }
    }
    if (successfulRecognizers == 0) {
      final details = failedScripts.entries
          .map((failure) => '${failure.key}: ${failure.value}')
          .join('; ');
      throw _RecognitionFailure('Text recognition failed. $details');
    }
    return _RecognitionResult(
      candidates.values.toList(),
      regions,
      failedScripts.isEmpty
          ? null
          : 'Some text recognizers failed (${failedScripts.keys.join(', ')}). '
                'Available results are still shown.',
    );
  }

  // ---------------------------------------------------------------------------
  // Capture / gallery
  // ---------------------------------------------------------------------------

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _imageProcessing ||
        _choosingImage) {
      return;
    }
    setState(() {
      _imageProcessing = true;
      _error = null;
    });
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await _frameRecognitionDone?.future;
      final file = await controller.takePicture();
      await _releaseCamera();
      await _readImage(file.path);
    } catch (error, stackTrace) {
      debugPrint('Could not capture photo: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = error is _RecognitionFailure
              ? error.message
              : 'Could not capture the photo. Please try again.';
        });
      }
      // Capture failed before we left live mode: resume the camera.
      if (mounted && _capturedPath == null && _controller == null) {
        unawaited(_initializeCamera());
      }
    } finally {
      if (mounted) setState(() => _imageProcessing = false);
    }
  }

  Future<void> _chooseImage() async {
    if (_imageProcessing || _choosingImage) return;
    final restoreCamera = _cameraRequested && _capturedPath == null;
    _choosingImage = true;
    _imageProcessing = true;
    if (mounted) setState(() => _error = null);
    try {
      await _releaseCamera();
      await _frameRecognitionDone?.future;
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      await _readImage(image.path);
    } catch (error, stackTrace) {
      debugPrint('Could not choose or read image: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error = error is _RecognitionFailure
              ? error.message
              : 'Could not open this image. Please choose another.',
        );
      }
    } finally {
      _choosingImage = false;
      if (mounted) {
        setState(() => _imageProcessing = false);
        if (_capturedPath == null && restoreCamera) {
          await _initializeCamera();
        }
      }
    }
  }

  Future<void> _readImage(String path) async {
    if (mounted) {
      setState(() {
        _capturedPath = path;
        _imageSize = null;
        _recognizedRegions = const [];
        _candidates = const [];
        _selected.clear();
      });
    }
    // Run sequentially so a failure in one never becomes an unhandled error
    // while we are awaiting the other.
    final result = await _recognizeImage(path);
    final imageSize = await _readImageSize(path);
    if (mounted) {
      setState(() {
        _candidates = result.words;
        _recognizedRegions = result.regions;
        _imageSize = imageSize;
        _error = result.warning;
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
      _selected.clear();
      _error = null;
    });
    if (_controller == null) await _requestCamera();
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void _toggle(String text) {
    setState(() {
      if (!_selected.remove(text)) _selected.add(text);
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_joinSelected(_selected));
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final pending = _frameRecognitionDone?.future;
    unawaited(_shutdown(pending));
    super.dispose();
  }

  /// Release the camera and close recognizers only after any in-flight frame
  /// has finished, so ML Kit is never closed mid-recognition.
  Future<void> _shutdown(Future<void>? pendingFrame) async {
    await _releaseCamera();
    try {
      await pendingFrame;
    } catch (_) {}
    for (final recognizer in _recognizers) {
      await recognizer.close();
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
            onPressed: _imageProcessing || _choosingImage || _initializing
                ? null
                : _chooseImage,
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
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const _CameraStartPanel(),
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
              selected: _selected,
              captured: isCaptured,
              busy: _initializing || _imageProcessing,
              cameraReady: controller?.value.isInitialized == true,
              onRetake: _retake,
              onCapture: _capture,
              onToggle: _toggle,
              onClear: () => setState(_selected.clear),
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

bool _isCjk(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0x20000 && rune <= 0x2A6DF);

/// Joins selected pieces in tap order: no space around Chinese characters
/// ("苹" + "果" -> "苹果"), a space between Latin words ("good" + "morning").
String _joinSelected(List<String> parts) {
  final buffer = StringBuffer();
  int? lastRune;
  for (final part in parts) {
    if (part.isEmpty) continue;
    final first = part.runes.first;
    if (lastRune != null && !_isCjk(lastRune) && !_isCjk(first)) {
      buffer.write(' ');
    }
    buffer.write(part);
    lastRune = part.runes.last;
  }
  return buffer.toString();
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

class _DetectedTextPanel extends StatelessWidget {
  const _DetectedTextPanel({
    required this.candidates,
    required this.selected,
    required this.captured,
    required this.busy,
    required this.cameraReady,
    required this.onRetake,
    required this.onCapture,
    required this.onToggle,
    required this.onClear,
    required this.onConfirm,
  });

  final List<String> candidates;
  final List<String> selected;
  final bool captured;
  final bool busy;
  final bool cameraReady;
  final VoidCallback onRetake;
  final VoidCallback onCapture;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected items that are no longer in the live list stay visible too.
    final chips = <String>[
      ...selected.where((s) => !candidates.contains(s)),
      ...candidates,
    ];
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 340),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              captured
                  ? 'Tap the words you want, then press Use'
                  : 'Point at text, press Capture, then pick words',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'English, Malay, Simplified Chinese and Traditional Chinese',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (captured)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onRetake,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Use camera'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || !cameraReady ? null : onCapture,
                      icon: const Icon(Icons.camera),
                      label: const Text('Capture'),
                    ),
                  ),
                ],
              ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _joinSelected(selected),
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear selection',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
                  FilledButton(
                    onPressed: onConfirm,
                    child: const Text('Use'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (busy)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (chips.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    captured
                        ? 'No text found. Try a closer, sharper photo or choose another image.'
                        : 'Point the camera at clear, well-lit text.',
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
                    children: chips
                        .map(
                          (text) => FilterChip(
                            label: Text(
                              text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: selected.contains(text),
                            onSelected: (_) => onToggle(text),
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

class _CameraStartPanel extends StatelessWidget {
  const _CameraStartPanel();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Transform.translate(
        offset: const Offset(0, -100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Read text with your camera',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Point the camera at clear text, or choose an image from your phone.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecognitionResult {
  const _RecognitionResult(this.words, this.regions, this.warning);

  final List<String> words;
  final List<Rect> regions;
  final String? warning;
}

class _RecognitionFailure implements Exception {
  const _RecognitionFailure(this.message);

  final String message;
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          // Avoid decoding a full-resolution photo just for display.
          cacheWidth: 1600,
        ),
      ),
      if (imageSize != null && regions.isNotEmpty)
        CustomPaint(
          painter: _TextRegionPainter(imageSize: imageSize!, regions: regions),
        ),
    ],
  );
}

class _TextRegionPainter extends CustomPainter {
  const _TextRegionPainter({required this.imageSize, required this.regions});

  final Size imageSize;
  final List<Rect> regions;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        (size.width / imageSize.width) < (size.height / imageSize.height)
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
      imageSize != oldDelegate.imageSize || regions != oldDelegate.regions;
}