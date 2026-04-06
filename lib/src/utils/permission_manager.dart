import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gestiona el permiso de cámara de forma declarativa.
class PermissionManager {
  /// Solicita el permiso de cámara.
  /// Retorna `true` si el permiso fue otorgado.
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Verifica sin solicitar.
  static Future<bool> hasCamera() async {
    return (await Permission.camera.status).isGranted;
  }

  /// Abre la configuración del sistema si el permiso fue denegado permanentemente.
  static Future<void> openSettings() => openAppSettings();
}

/// Widget que maneja el ciclo de vida del permiso de cámara.
/// Envuelve cualquier pantalla que necesite la cámara.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({
    super.key,
    required this.child,
    this.onDenied,
  });

  final Widget child;
  final VoidCallback? onDenied;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate> {
  _PermissionStatus _status = _PermissionStatus.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await PermissionManager.requestCamera();
    if (!mounted) return;
    setState(() {
      _status =
          granted ? _PermissionStatus.granted : _PermissionStatus.denied;
    });
    if (!granted) widget.onDenied?.call();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _PermissionStatus.checking => const _LoadingView(),
      _PermissionStatus.granted => widget.child,
      _PermissionStatus.denied => _DeniedView(onRetry: _check),
    };
  }
}

enum _PermissionStatus { checking, granted, denied }

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _DeniedView extends StatelessWidget {
  const _DeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Permiso de cámara requerido',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sorty necesita acceso a tu cámara para verificar tu identidad de forma segura.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: PermissionManager.openSettings,
              child: const Text('Abrir configuración',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
