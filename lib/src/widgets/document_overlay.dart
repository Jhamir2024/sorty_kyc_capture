import 'package:flutter/material.dart';

/// Overlay semitransparente con una ventana rectangular apaisada (ratio ≈ 1.586:1)
/// que guía al usuario a encuadrar su DNI/Cédula.
class DocumentOverlay extends StatelessWidget {
  const DocumentOverlay({
    super.key,
    this.label = 'Encuadra tu documento aquí',
    this.isCapturing = false,
  });

  final String label;

  /// Si `true`, el borde del recuadro pulsa en verde indicando captura.
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _DocumentOverlayPainter(isCapturing: isCapturing)),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.28,
          left: 0,
          right: 0,
          child: _FeedbackLabel(label: label),
        ),
      ],
    );
  }
}

class _DocumentOverlayPainter extends CustomPainter {
  _DocumentOverlayPainter({required this.isCapturing});

  final bool isCapturing;

  // Ratio estándar ISO/IEC 7810 ID-1 (tarjetas de crédito / DNI)
  static const double _cardRatio = 85.6 / 54.0; // ≈ 1.586

  @override
  void paint(Canvas canvas, Size size) {
    const double horizontalPadding = 28.0;
    final cardWidth = size.width - horizontalPadding * 2;
    final cardHeight = cardWidth / _cardRatio;
    final cardTop = (size.height - cardHeight) / 2;

    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(horizontalPadding, cardTop, cardWidth, cardHeight),
      const Radius.circular(12),
    );

    // Fondo oscuro con agujero rectangular
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, backgroundPaint);

    // Borde del recuadro
    final borderPaint = Paint()
      ..color = isCapturing ? Colors.greenAccent : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCapturing ? 3.0 : 2.0;
    canvas.drawRRect(cutout, borderPaint);

    // Esquinas de guía (líneas de alineación)
    _drawCornerGuides(canvas, cutout.outerRect, isCapturing);
  }

  void _drawCornerGuides(Canvas canvas, Rect rect, bool highlight) {
    const double len = 24.0;
    const double thickness = 3.5;
    final paint = Paint()
      ..color = highlight ? Colors.greenAccent : const Color(0xFFFFC107)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final corners = [
      // top-left
      [Offset(rect.left, rect.top + len), rect.topLeft,
          Offset(rect.left + len, rect.top)],
      // top-right
      [Offset(rect.right - len, rect.top), rect.topRight,
          Offset(rect.right, rect.top + len)],
      // bottom-left
      [Offset(rect.left, rect.bottom - len), rect.bottomLeft,
          Offset(rect.left + len, rect.bottom)],
      // bottom-right
      [Offset(rect.right - len, rect.bottom), rect.bottomRight,
          Offset(rect.right, rect.bottom - len)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
      canvas.drawLine(corner[1], corner[2], paint);
    }
  }

  @override
  bool shouldRepaint(_DocumentOverlayPainter old) =>
      old.isCapturing != isCapturing;
}

class _FeedbackLabel extends StatelessWidget {
  const _FeedbackLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
