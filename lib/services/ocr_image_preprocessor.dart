import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

typedef TemporaryDirectory = Future<Directory> Function();

abstract interface class OcrImagePreprocessor {
  Future<String> enhance(String imagePath);
  Future<void> delete(String imagePath);
}

class DartOcrImagePreprocessor implements OcrImagePreprocessor {
  DartOcrImagePreprocessor({TemporaryDirectory? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final TemporaryDirectory _temporaryDirectory;

  @override
  Future<String> enhance(String imagePath) async {
    final dir = await _temporaryDirectory();
    final output =
        '${dir.path}/beanprofile_ocr_${DateTime.now().microsecondsSinceEpoch}.png';
    await Isolate.run(() async {
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
      await File(output).writeAsBytes(img.encodePng(image));
    });
    return output;
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
}
