import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/permission_manager.dart';
import '../widgets/face_overlay.dart';

/// Pantalla de captura de selfie con verificación de liveness local.
///
/// Condición para habilitar captura (anti-spoofing básico):
///   - Exactamente UN rostro en el encuadre, Y
///   - smiling probability > 0.7  OR  un ojo cerrado (prob. < 0.25)
///
/// Devuelve un [XFile] o hace `pop(null)` si el usuario cancela.
class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({super.key});

  static const routeName = '/kyc/selfie';

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isProcessingFrame = false;
  String? _errorMessage;

  // Estado de liveness
  FaceOverlayState _overlayState = FaceOverlayState.idle;
  String _feedbackText = 'Coloca tu rostro en el óvalo';
  bool _canCapture = false;

  late final FaceDetector _faceDetector;

  // Throttle: procesar máximo 1 frame por cada N ms
  static const int _frameThrottleMs = 150;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableClassification: true, // activa smiling + eye open probabilities
        enableTracking: false,
      ),
    );
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream().catchError((_) {});
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No se encontró cámara disponible.');
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // medium es suficiente para liveness
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // NV21 en Android; iOS ignora
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() => _isInitialized = true);

      // Iniciar stream para detección en tiempo real
      await _controller!.startImageStream(_onCameraFrame);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error al inicializar cámara: $e');
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    // Throttle
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameThrottleMs) {
      return;
    }
    _lastFrameTime = now;

    if (_isProcessingFrame || _isCapturing) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      _updateLivenessState(faces);
    } catch (_) {
      // Silenciar errores de frame individuales
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Convierte [CameraImage] a [InputImage] de ML Kit.
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    // En iOS el formato es bgra8888; en Android nv21/yuv420
    InputImageFormat? format;
    if (Platform.isAndroid) {
      format = InputImageFormatValue.fromRawValue(image.format.raw);
    } else {
      format = InputImageFormat.bgra8888;
    }
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _updateLivenessState(List<Face> faces) {
    if (faces.isEmpty) {
      _setFeedback(FaceOverlayState.idle, 'Coloca tu rostro en el óvalo',
          canCapture: false);
      return;
    }

    if (faces.length > 1) {
      _setFeedback(
          FaceOverlayState.idle, 'Solo una persona a la vez',
          canCapture: false);
      return;
    }

    final face = faces.first;
    final smileProb = face.smilingProbability ?? 0.0;
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

    // Liveness: el usuario debe sonreír O cerrar un ojo
    final isSmiling = smileProb > 0.70;
    final eyeClosed = leftEyeOpen < 0.25 || rightEyeOpen < 0.25;
    final livenessOk = isSmiling || eyeClosed;

    if (!livenessOk) {
      _setFeedback(
          FaceOverlayState.faceDetected, 'Sonríe para tomar la foto',
          canCapture: false);
      return;
    }

    _setFeedback(FaceOverlayState.ready, '¡Perfecto! Capturando...',
        canCapture: true);
  }

  void _setFeedback(FaceOverlayState state, String text,
      {required bool canCapture}) {
    if (!mounted) return;
    if (_overlayState == state &&
        _feedbackText == text &&
        _canCapture == canCapture) return;

    setState(() {
      _overlayState = state;
      _feedbackText = text;
      _canCapture = canCapture;
    });
  }

  Future<void> _capture() async {
    if (!_canCapture || _isCapturing) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(xFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      // Reiniciar stream si falla la captura
      await _controller!.startImageStream(_onCameraFrame);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar: $e')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraPermissionGate(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Selfie de verificación',
              style: TextStyle(fontSize: 17)),
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.white60),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_controller!)),

        // Overlay con estado de liveness
        FaceOverlay(
          state: _overlayState,
          feedbackText: _feedbackText,
        ),

        // Botón de captura — solo habilitado cuando liveness OK
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: _LivenessCaptureButton(
            canCapture: _canCapture && !_isCapturing,
            isLoading: _isCapturing,
            onTap: _capture,
          ),
        ),
      ],
    );
  }
}

class _LivenessCaptureButton extends StatelessWidget {
  const _LivenessCaptureButton({
    required this.canCapture,
    required this.isLoading,
    required this.onTap,
  });

  final bool canCapture;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: canCapture ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canCapture ? Colors.white : Colors.white24,
                boxShadow: canCapture
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.black),
                    )
                  : Icon(
                      Icons.camera_alt_rounded,
                      color: canCapture ? Colors.black : Colors.white38,
                      size: 30,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!canCapture)
          const Text(
            'Espera a que se detecte liveness',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
      ],
    );
  }
}
