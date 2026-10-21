import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum TextReaderSource { camera, gallery }

class LiveTextCameraScreen extends StatefulWidget {
  const LiveTextCameraScreen({
    this.initialSource = TextReaderSource.camera,
    super.key,
  });

  final TextReaderSource initialSource;

  @override
  State<LiveTextCameraScreen> createState() => _LiveTextCameraScreenState();
}

class _LiveTextCameraScreenState extends State<LiveTextCameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  late final List<TextRecognizer> _recognizers;
  CameraController? _controller;
  List<String> _candidates = const [];
  String? _imagePath;
  String? _error;
  bool _processingFrame = false;
  bool _processingImage = false;
  bool _initializingCamera = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialSource == TextReaderSource.camera) {
        _requestCamera();
      } else {
        _chooseImage();
      }
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
        !_processingImage &&
        _imagePath == null) {
      _initializeCamera();
    }
  }

  Future<void> _requestCamera() async {
    _cameraRequested = true;
    if (mounted) {
      setState(() {
        _imagePath = null;
        _candidates = const [];
        _error = null;
      });
    }
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializingCamera || _controller != null || !mounted) return;
    setState(() {
      _initializingCamera = true;
      _error = null;
    });

    CameraController? controller;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw CameraException(
          'unsupported_platform',
          'Camera text recognition is available on Android and iOS.',
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
      if (!mounted || _controller != controller) return;
      await controller.startImageStream(_processFrame);
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      if (_controller == controller) await _releaseCamera();
      if (mounted) setState(() => _error = _cameraErrorMessage(error));
    } catch (error, stackTrace) {
      debugPrint('Could not start text-reading camera: $error\n$stackTrace');
      if (_controller == controller) await _releaseCamera();
      if (mounted) {
        setState(
          () => _error = 'Could not start the camera. Allow camera access or choose an image.',
        );
      }
    } finally {
      if (mounted) setState(() => _initializingCamera = false);
    }
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted') {
      return 'Camera access is needed to read text. Allow camera access in device settings, or choose an image.';
    }
    return error.description ?? 'Could not start the camera.';
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
      debugPrint('Could not stop text-recognition camera stream: $error');
    }
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('Could not dispose text-recognition camera: $error');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    final now = DateTime.now();
    if (_processingFrame ||
        _processingImage ||
        _choosingImage ||
        controller == null ||
        _imagePath != null ||
        now.difference(_lastProcessedFrame).inMilliseconds < 350) {
      return;
    }

    _processingFrame = true;
    final frameDone = Completer<void>();
    _frameRecognitionDone = frameDone;
    _lastProcessedFrame = now;
    try {
      final input = _inputImageFromCameraImage(image, controller);
      if (input == null) {
        const message =
            'This camera does not provide a supported image format for text recognition.';
        if (mounted && _error != message) setState(() => _error = message);
        return;
      }
      final candidates = await _recognize(input);
      if (mounted && _imagePath == null && !_processingImage) {
        setState(() {
          _candidates = candidates;
          _error = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Live text recognition failed: $error\n$stackTrace');
      if (mounted && _imagePath == null && !_processingImage) {
        setState(() {
          _candidates = const [];
          _error = error is _RecognitionFailure
              ? error.message
              : 'Could not read text from the camera. Please try again.';
        });
      }
    } finally {
      _processingFrame = false;
      frameDone.complete();
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

  Future<List<String>> _recognize(InputImage input) async {
    final candidates = <String, String>{};
    final failedScripts = <String, String>{};
    var successfulRecognizers = 0;
    for (final recognizer in _recognizers) {
      try {
        final result = await recognizer.processImage(input);
        successfulRecognizers++;
        for (final block in result.blocks) {
          for (final line in block.lines) {
            _addCandidate(candidates, line.text);
            for (final element in line.elements) {
              _addCandidate(candidates, element.text);
            }
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Text recognition failed for ${recognizer.script.name}: '
          '$error\n$stackTrace',
        );
        failedScripts[recognizer.script.name] = error.toString();
      }
    }
    if (successfulRecognizers == 0) {
      final details = failedScripts.entries
          .map((failure) => '${failure.key}: ${failure.value}')
          .join('; ');
      throw _RecognitionFailure('Text recognition failed. $details');
    }
    return candidates.values.toList(growable: false);
  }

  void _addCandidate(Map<String, String> candidates, String rawText) {
    final text = rawText.trim();
    if (text.isNotEmpty) {
      candidates.putIfAbsent(text.toLowerCase(), () => text);
    }
  }

  Future<void> _chooseImage() async {
    if (_processingImage || _choosingImage) return;
    _choosingImage = true;
    _processingImage = true;
    if (mounted) setState(() => _error = null);
    try {
      await _releaseCamera();
      await _frameRecognitionDone?.future;
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted && widget.initialSource == TextReaderSource.gallery) {
          Navigator.of(context).pop();
        }
        return;
      }
      final candidates = await _recognize(InputImage.fromFilePath(image.path));
      if (mounted) {
        setState(() {
          _imagePath = image.path;
          _candidates = candidates;
          _error = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Could not read selected image: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = error is _RecognitionFailure ? error.message : 'Could not read this image. Choose another image or use the camera.';
        });
      }
    } finally {
      _choosingImage = false;
      if (mounted) {
        setState(() => _processingImage = false);
        if (_imagePath == null && _cameraRequested) {
          await _initializeCamera();
        }
      }
    }
  }

  void _selectText(String text) {
    Navigator.of(context).pop(text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final pendingFrame = _frameRecognitionDone?.future;
    unawaited(_shutdown(pendingFrame));
    super.dispose();
  }

  Future<void> _shutdown(Future<void>? pendingFrame) async {
    await _releaseCamera();
    try {
      await pendingFrame;
    } catch (error) {
      debugPrint('Live OCR frame did not finish cleanly: $error');
    }
    for (final recognizer in _recognizers) {
      await recognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showingImage = _imagePath != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read text'),
        actions: [
          if (!showingImage)
            IconButton(
              tooltip: 'Read an image from storage',
              onPressed: _processingImage || _choosingImage
                  ? null
                  : _chooseImage,
              icon: const Icon(Icons.photo_library_outlined),
            )
          else
            IconButton(
              tooltip: 'Use camera',
              onPressed: _requestCamera,
              icon: const Icon(Icons.camera_alt_outlined),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_imagePath case final path?)
            Center(child: Image.file(File(path), fit: BoxFit.contain))
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
              showingImage: showingImage,
              busy: _initializingCamera || _processingImage,
              onSelect: _selectText,
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
    required this.showingImage,
    required this.busy,
    required this.onSelect,
  });

  final List<String> candidates;
  final bool showingImage;
  final bool busy;
  final ValueChanged<String> onSelect;

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
              'Detected text — tap a word or line',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              showingImage
                  ? 'English, Malay, Simplified Chinese and Traditional Chinese'
                  : 'Point at clear text and choose a detected result',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (busy)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (candidates.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    showingImage
                        ? 'No text found. Try a clearer image or choose another.'
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
                        .toList(growable: false),
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
            'Allow camera access to identify text live, or choose an image from storage.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RecognitionFailure implements Exception {
  const _RecognitionFailure(this.message);

  final String message;
}
