import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'models/kyc_result.dart';
import 'screens/id_capture_screen.dart';
import 'screens/selfie_capture_screen.dart';
import 'utils/image_compressor.dart';

/// Orchestrates the full 3-step KYC flow:
///   1. Capture front of ID
///   2. Capture back of ID
///   3. Selfie with liveness check
///
/// On completion calls [onComplete] with a [KycResult].
/// On cancellation / error calls [onCancel].
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => KycFlowScreen(
///     onComplete: (result) async { /* upload result.idFront etc. */ },
///     onCancel: () => Navigator.of(context).pop(),
///   ),
/// ));
/// ```
class KycFlowScreen extends StatefulWidget {
  const KycFlowScreen({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  final void Function(KycResult result) onComplete;
  final VoidCallback onCancel;

  @override
  State<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends State<KycFlowScreen> {
  _KycStep _step = _KycStep.idFront;
  bool _isProcessing = false;

  // Archivos temporales comprimidos
  File? _idFront;
  File? _idBack;

  Future<void> _onIdFrontCaptured(XFile? raw) async {
    if (raw == null) {
      widget.onCancel();
      return;
    }
    await _processAndAdvance(raw, tag: 'id_front', onDone: (file) {
      _idFront = file;
      setState(() => _step = _KycStep.idBack);
    });
  }

  Future<void> _onIdBackCaptured(XFile? raw) async {
    if (raw == null) {
      widget.onCancel();
      return;
    }
    await _processAndAdvance(raw, tag: 'id_back', onDone: (file) {
      _idBack = file;
      setState(() => _step = _KycStep.selfie);
    });
  }

  Future<void> _onSelfieCaptured(XFile? raw) async {
    if (raw == null) {
      widget.onCancel();
      return;
    }
    await _processAndAdvance(raw, tag: 'selfie', onDone: (selfie) {
      widget.onComplete(KycResult(
        idFront: _idFront!,
        idBack: _idBack!,
        selfie: selfie,
      ));
    });
  }

  Future<void> _processAndAdvance(
    XFile raw, {
    required String tag,
    required void Function(File) onDone,
  }) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final compressed = await ImageCompressor.compress(raw, tag: tag);
      if (!mounted) return;
      onDone(compressed);
    } catch (e) {
      if (!mounted) return;
      _showError('Error procesando imagen: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const _ProcessingScreen();
    }

    return switch (_step) {
      _KycStep.idFront => _buildIdCapture(
          title: 'Frente del documento',
          hint: 'Encuadra el frente de tu DNI/Cédula',
          onPopped: _onIdFrontCaptured,
        ),
      _KycStep.idBack => _buildIdCapture(
          title: 'Reverso del documento',
          hint: 'Encuadra el reverso de tu DNI/Cédula',
          onPopped: _onIdBackCaptured,
        ),
      _KycStep.selfie => _buildSelfie(),
    };
  }

  Widget _buildIdCapture({
    required String title,
    required String hint,
    required Future<void> Function(XFile?) onPopped,
  }) {
    return _NavWrapper(
      onPopped: onPopped,
      child: IdCaptureScreen(title: title, hint: hint),
    );
  }

  Widget _buildSelfie() {
    return _NavWrapper(
      onPopped: _onSelfieCaptured,
      child: const SelfieCaptureScreen(),
    );
  }
}

enum _KycStep { idFront, idBack, selfie }

/// Envuelve una pantalla de captura para interceptar su resultado vía pop.
class _NavWrapper extends StatefulWidget {
  const _NavWrapper({required this.child, required this.onPopped});

  final Widget child;
  final Future<void> Function(XFile?) onPopped;

  @override
  State<_NavWrapper> createState() => _NavWrapperState();
}

class _NavWrapperState extends State<_NavWrapper> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pushed) {
      _pushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _push());
    }
  }

  Future<void> _push() async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(builder: (_) => widget.child),
    );
    if (!mounted) return;
    await widget.onPopped(result);
  }

  @override
  Widget build(BuildContext context) {
    return const _ProcessingScreen();
  }
}

class _ProcessingScreen extends StatelessWidget {
  const _ProcessingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Procesando imagen...',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
