import 'dart:io';

/// Resultado final del flujo KYC.
/// Todos los archivos ya están comprimidos (≤ 800 KB, JPEG).
class KycResult {
  const KycResult({
    required this.idFront,
    required this.idBack,
    required this.selfie,
  });

  final File idFront;
  final File idBack;
  final File selfie;

  /// Destruye los archivos temporales del dispositivo.
  /// Llámalo una vez que hayas subido los archivos al backend.
  Future<void> dispose() async {
    for (final file in [idFront, idBack, selfie]) {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  String toString() =>
      'KycResult(idFront: ${idFront.path}, idBack: ${idBack.path}, selfie: ${selfie.path})';
}
