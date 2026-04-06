import 'package:flutter/material.dart';

/// Overlay semitransparente con ventana ovalada para selfie.
/// El borde cambia de color según el estado de detección de rostro.
class FaceOverlay extends StatelessWidget {
  const FaceOverlay({
    super.key,
    required this.state,
    required this.feedbackText,
  });

  final FaceOverlayState state;
  final String feedbackText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _FaceOverlayPainter(state: state)),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.68,
          left: 24,
          right: 24,
          child: _FeedbackBanner(text: feedbackText, state: state),
        ),
      ],
    );
  }
}

enum FaceOverlayState {
  /// Sin rostro detectado
  idle,

  /// Rostro detectado pero condición de liveness no cumplida
  faceDetected,

  /// Listo para capturar (sonrisa o ojo cerrado detectado)
  ready,
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({required this.state});

  final FaceOverlayState state;

  Color get _borderColor => switch (state) {
        FaceOverlayState.idle => Colors.white54,
        FaceOverlayState.faceDetected => const Color(0xFFFFC107), // amber
        FaceOverlayState.ready => Colors.greenAccent,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final ovalWidth = size.width * 0.72;
    final ovalHeight = ovalWidth * 1.28; // ligeramente más alto que ancho
    final ovalLeft = (size.width - ovalWidth) / 2;
    final ovalTop = (size.height - ovalHeight) / 2 - size.height * 0.04;

    final ovalRect =
        Rect.fromLTWH(ovalLeft, ovalTop, ovalWidth, ovalHeight);

    // Fondo oscuro con hueco ovalado
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backgroundPaint);

    // Borde ovalado
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == FaceOverlayState.ready ? 3.5 : 2.0;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(_FaceOverlayPainter old) => old.state != state;
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.text, required this.state});

  final String text;
  final FaceOverlayState state;

  Color get _bg => switch (state) {
        FaceOverlayState.idle => Colors.black54,
        FaceOverlayState.faceDetected => Colors.orange.withValues(alpha: 0.85),
        FaceOverlayState.ready => Colors.green.withValues(alpha: 0.85),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
