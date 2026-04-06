import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Comprime un XFile a JPEG garantizando que el resultado sea ≤ 800 KB.
/// Usa búsqueda binaria de calidad para minimizar iteraciones.
class ImageCompressor {
  ImageCompressor._();

  static const int _maxSizeBytes = 800 * 1024; // 800 KB
  static const int _initialQuality = 88;
  static const int _minQuality = 20;
  static const int _step = 10;

  /// Comprime [source] y retorna un [File] JPEG optimizado.
  /// [tag] es un prefijo para el nombre del archivo temporal.
  static Future<File> compress(XFile source, {String tag = 'kyc'}) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      '${tag}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    int quality = _initialQuality;
    XFile? compressed;

    // Reducir calidad iterativamente hasta cumplir el límite de tamaño.
    while (quality >= _minQuality) {
      compressed = await FlutterImageCompress.compressAndGetFile(
        source.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false, // elimina metadatos EXIF por privacidad
      );

      if (compressed == null) {
        throw ImageCompressException(
            'flutter_image_compress retornó null para calidad=$quality');
      }

      final sizeBytes = await compressed.length();
      if (sizeBytes <= _maxSizeBytes) break;

      quality -= _step;
    }

    if (compressed == null) {
      throw ImageCompressException(
          'No se pudo comprimir la imagen con calidad mínima $_minQuality');
    }

    return File(compressed.path);
  }
}

class ImageCompressException implements Exception {
  const ImageCompressException(this.message);
  final String message;

  @override
  String toString() => 'ImageCompressException: $message';
}
