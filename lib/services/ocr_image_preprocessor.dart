import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

typedef TemporaryDirectory = Future<Directory> Function();
typedef EnhancedImageWriter = Future<void> Function(
    String path, List<int> bytes);

abstract interface class OcrImagePreprocessor {
  Future<String> enhance(String imagePath);
  Future<void> delete(String imagePath);
}

class DartOcrImagePreprocessor implements OcrImagePreprocessor {
  DartOcrImagePreprocessor({
    TemporaryDirectory? temporaryDirectory,
    EnhancedImageWriter? writeEnhancedImage,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _writeEnhancedImage =
           writeEnhancedImage ?? _writeEnhancedImageToFile;

  final TemporaryDirectory _temporaryDirectory;
  final EnhancedImageWriter _writeEnhancedImage;

  @override
  Future<String> enhance(String imagePath) async {
    final dir = await _temporaryDirectory();
    final output =
        '${dir.path}/beanprofile_ocr_${DateTime.now().microsecondsSinceEpoch}.png';
    try {
      final encoded = await Isolate.run(() async {
        var image = await img.decodeImageFile(imagePath);
        if (image == null) throw const FormatException('Unsupported image');
        image = img.bakeOrientation(image);
        image = img.grayscale(image);
        image = img.histogramStretch(
          image,
          mode: img.HistogramEqualizeMode.grayscale,
          stretchClipRatio: 0.015,
        );
        image = img.adjustColor(image, contrast: 1.2);
        return img.encodePng(image);
      });
      await _writeEnhancedImage(output, encoded);
      return output;
    } catch (error, stackTrace) {
      final partial = File(output);
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {
        // Preserve the enhancement failure; pipeline fallback handles it.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> delete(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      return;
    }
  }

  static Future<void> _writeEnhancedImageToFile(
          String path, List<int> bytes) =>
      File(path).writeAsBytes(bytes);
}
