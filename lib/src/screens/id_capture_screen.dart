import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../utils/permission_manager.dart';
import '../widgets/document_overlay.dart';

/// Pantalla de captura de documento (frente o reverso del DNI/Cédula).
///
/// Devuelve un [XFile] con la imagen capturada (sin comprimir).
/// La compresión se aplica en [KycFlowScreen].
class IdCaptureScreen extends StatefulWidget {
  const IdCaptureScreen({
    super.key,
    required this.title,
    required this.hint,
  });

  /// Ej: "Frente del documento" / "Reverso del documento"
  final String title;

  /// Ej: "Asegúrate que el texto sea legible"
  final String hint;

  /// Ruta de navegación nombrada.
  static const routeName = '/kyc/id-capture';

  @override
  State<IdCaptureScreen> createState() => _IdCaptureScreenState();
}

class _IdCaptureScreenState extends State<IdCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
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

      // Cámara trasera para documentos
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error al inicializar cámara: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(xFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar: $e')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
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
          title: Text(widget.title,
              style: const TextStyle(fontSize: 17)),
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
        // Preview de cámara a pantalla completa
        Positioned.fill(child: CameraPreview(_controller!)),

        // Overlay con guía de documento
        DocumentOverlay(
          label: widget.hint,
          isCapturing: _isCapturing,
        ),

        // Botón de captura
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: _CaptureButton(
            onTap: _isCapturing ? null : _capture,
            isLoading: _isCapturing,
          ),
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({this.onTap, this.isLoading = false});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap != null ? Colors.white : Colors.white38,
            border: Border.all(
              color: onTap != null ? Colors.white : Colors.white24,
              width: 4,
            ),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.black),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
