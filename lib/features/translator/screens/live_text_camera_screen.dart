import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Streams camera frames through on-device OCR and returns selected text.
class LiveTextCameraScreen extends StatefulWidget {
  const LiveTextCameraScreen({required this.script, super.key});

  final TextRecognitionScript script;

  @override
  State<LiveTextCameraScreen> createState() => _LiveTextCameraScreenState();
}

class _LiveTextCameraScreenState extends State<LiveTextCameraScreen>
    with WidgetsBindingObserver {
  late final TextRecognizer _recognizer;
  CameraController? _controller;
  List<String> _candidates = const [];
  String? _error;
  bool _processing = false;
  bool _initializing = false;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = TextRecognizer(script: widget.script);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
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
          'Live text recognition is available on Android and iOS.',
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_processFrame);
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraErrorMessage(error));
      await _releaseCamera();
    } catch (error) {
      debugPrint('Could not start live text recognition: $error');
      if (mounted) {
        setState(
          () => _error =
              'Could not start the camera. Check its permission and try again.',
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
      return 'Camera access is needed to read text. Allow camera access in your device settings, then try again.';
    }
    return error.description ?? 'Could not start the camera. Please try again.';
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The camera may already have been released by the platform.
    }
    await controller.dispose();
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    final now = DateTime.now();
    if (_processing ||
        controller == null ||
        now.difference(_lastProcessed).inMilliseconds < 350) {
      return;
    }
    _processing = true;
    _lastProcessed = now;
    try {
      final inputImage = _inputImageFromCameraImage(image, controller);
      if (inputImage == null) return;
      final recognized = await _recognizer.processImage(inputImage);
      final candidates = <String>{};
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isNotEmpty) candidates.add(text);
          for (final element in line.elements) {
            final word = element.text.trim();
            if (word.isNotEmpty) candidates.add(word);
          }
        }
      }
      if (mounted && !_sameCandidates(_candidates, candidates.toList())) {
        setState(() => _candidates = candidates.take(40).toList());
      }
    } catch (error) {
      debugPrint('Live OCR frame failed: $error');
    } finally {
      _processing = false;
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
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormatValue.fromRawValue(image.format.raw);
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

  bool _sameCandidates(List<String> current, List<String> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != next[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseCamera();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read with camera'),
        actions: [
          IconButton(
            tooltip: 'Restart camera',
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller?.value.isInitialized == true)
            Center(child: CameraPreview(controller!))
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _initializeCamera,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _DetectedTextPanel(
                candidates: _candidates,
                onSelect: (text) => Navigator.of(context).pop(text),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetectedTextPanel extends StatelessWidget {
  const _DetectedTextPanel({required this.candidates, required this.onSelect});

  final List<String> candidates;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 260),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap a word or line',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Point the camera at clear, well-lit text.'),
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
                              maxLines: 2,
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
