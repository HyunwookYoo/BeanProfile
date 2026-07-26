import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_diagnostics.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('collect always analyzes original and enhanced images', () async {
    final ocr = RecordingOcrService([
      const [
        OcrLine('Name: House Blend', left: 1, top: 2, right: 3, bottom: 4),
        OcrLine('Brazil 60%'),
        OcrLine('Ethiopia 40%'),
      ],
      const [
        OcrLine('Brazil 60%'),
        OcrLine('Natural'),
        OcrLine('Ethiopia 40%'),
        OcrLine('Guji'),
        OcrLine('Washed'),
      ],
    ]);
    final preprocessor = RecordingPreprocessor();
    final service = DefaultOcrDiagnosticsService(
      ocr: ocr,
      qualityAnalyzer: FakeQualityAnalyzer(
        const ImageQualityReport({ImageQualityIssue.lowContrast}),
      ),
      preprocessor: preprocessor,
      platform: 'ios',
    );

    final text = await service.collect('/tmp/source.jpg');

    expect(ocr.paths, ['/tmp/source.jpg', '/tmp/enhanced.png']);
    expect(preprocessor.deleted, ['/tmp/enhanced.png']);
    expect(text, contains('--- ORIGINAL ---'));
    expect(text, contains('--- ENHANCED ---'));
    expect(text, contains('--- FINAL ---'));
    expect(text, isNot(contains('/tmp/source.jpg')));
    expect(text, isNot(contains('/tmp/enhanced.png')));
  });

  test(
    'report includes safe metadata, coordinates, confidence and components',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'beanprofile-diagnostic-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/source.jpg');
      final image = img.Image(width: 32, height: 48);
      image.exif.imageIfd.orientation = 6;
      await source.writeAsBytes(img.encodeJpg(image));

      final service = DefaultOcrDiagnosticsService(
        ocr: RecordingOcrService([
          const [
            OcrLine(
              'Brazil 100%',
              left: 1,
              top: 2,
              right: 3,
              bottom: 4,
              confidence: .875,
            ),
          ],
          const [OcrLine('Brazil 100%')],
        ]),
        qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
        preprocessor: RecordingPreprocessor(),
        platform: 'ios',
      );

      final text = await service.collect(source.path);

      expect(text, startsWith('=== BEANPROFILE OCR DIAGNOSTICS v1 ==='));
      expect(text, contains('platform: ios'));
      expect(text, contains('image: 32x48'));
      expect(text, contains('exifOrientation=6'));
      expect(text, contains('[1.0,2.0,3.0,4.0]'));
      expect(text, contains('confidence='));
      expect(text, contains('component[0]:'));
      expect(text, isNot(contains(source.path)));
    },
  );

  test('enhancement failure still returns the original diagnostic', () async {
    final service = DefaultOcrDiagnosticsService(
      ocr: RecordingOcrService([
        const [OcrLine('Brazil 100%')],
      ]),
      qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
      preprocessor: ThrowingPreprocessor(),
      platform: 'ios',
    );

    final text = await service.collect('/tmp/source.jpg');

    expect(text, contains('--- ORIGINAL ---'));
    expect(text, contains('enhancementError: StateError'));
    expect(text, contains('selected: original'));
    expect(text, isNot(contains('/tmp/source.jpg')));
  });

  test(
    'quality and cleanup failures are recorded without losing the result',
    () async {
      final service = DefaultOcrDiagnosticsService(
        ocr: RecordingOcrService([
          const [OcrLine('Brazil 100%')],
          const [OcrLine('Brazil 100%')],
        ]),
        qualityAnalyzer: ThrowingQualityAnalyzer(),
        preprocessor: ThrowingDeletePreprocessor(),
        platform: 'ios',
      );

      final text = await service.collect('/tmp/source.jpg');

      expect(text, contains('qualityError: StateError'));
      expect(text, contains('cleanupError: StateError'));
      expect(text, contains('selected: original'));
      expect(text, isNot(contains('/tmp/source.jpg')));
      expect(text, isNot(contains('/tmp/enhanced.png')));
    },
  );

  test('OCR failure records only its error type', () async {
    final service = DefaultOcrDiagnosticsService(
      ocr: RecordingOcrService([
        const [OcrLine('unused')],
        const [OcrLine('Brazil 100%')],
      ], throwOnCall: 1),
      qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
      preprocessor: RecordingPreprocessor(),
      platform: 'ios',
    );

    final text = await service.collect('/private/source.jpg');

    expect(text, contains('error: StateError'));
    expect(text, contains('selected: enhanced'));
    expect(text, isNot(contains('OCR failed')));
    expect(text, isNot(contains('/private/source.jpg')));
  });
}

class RecordingOcrService implements OcrService {
  RecordingOcrService(this.results, {this.throwOnCall});

  final List<List<OcrLine>> results;
  final int? throwOnCall;
  final paths = <String>[];
  var index = 0;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    paths.add(imagePath);
    if (paths.length == throwOnCall) {
      index++;
      throw StateError('OCR failed');
    }
    return results[index++];
  }
}

class RecordingPreprocessor implements OcrImagePreprocessor {
  final enhancedPath = '/tmp/enhanced.png';
  final deleted = <String>[];

  @override
  Future<String> enhance(String imagePath) async => enhancedPath;

  @override
  Future<void> delete(String imagePath) async => deleted.add(imagePath);
}

class FakeQualityAnalyzer implements ImageQualityAnalyzer {
  FakeQualityAnalyzer(this.report);

  final ImageQualityReport report;

  @override
  Future<ImageQualityReport> analyze(String imagePath) async => report;
}

class ThrowingQualityAnalyzer implements ImageQualityAnalyzer {
  @override
  Future<ImageQualityReport> analyze(String imagePath) async {
    throw StateError('quality failed');
  }
}

class ThrowingPreprocessor implements OcrImagePreprocessor {
  @override
  Future<String> enhance(String imagePath) async {
    throw StateError('enhance failed');
  }

  @override
  Future<void> delete(String imagePath) async {}
}

class ThrowingDeletePreprocessor extends RecordingPreprocessor {
  @override
  Future<void> delete(String imagePath) async {
    throw StateError('delete failed');
  }
}
