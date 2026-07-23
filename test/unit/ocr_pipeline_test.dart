import 'package:beanprofile/features/beans/ocr/ocr_candidate.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strong original skips enhancement and second OCR', () async {
    final ocr = QueueOcrService([
      [
        const OcrLine('Name: House Blend', confidence: .9),
        const OcrLine('Brazil', confidence: .9),
        const OcrLine('Natural', confidence: .9),
        const OcrLine('Notes: Cocoa', confidence: .9),
      ],
    ]);
    final preprocessor = FakePreprocessor('/tmp/enhanced.png');
    final pipeline = DefaultOcrPipeline(
      ocr: ocr,
      qualityAnalyzer: FakeQualityAnalyzer(
        const ImageQualityReport({
          ImageQualityIssue.blurry,
          ImageQualityIssue.strongHighlights,
        }),
      ),
      preprocessor: preprocessor,
    );

    final result = await pipeline.analyze('/tmp/original.jpg');

    expect(ocr.paths, ['/tmp/original.jpg']);
    expect(preprocessor.enhanceCalls, 0);
    expect(result.usedEnhanced, isFalse);
    expect(result.shouldWarnQuality, isFalse);
  });

  test(
    'low contrast retries once and always deletes temporary image',
    () async {
      final ocr = QueueOcrService([
        [const OcrLine('Decorative', confidence: .4)],
        [
          const OcrLine('Name: House Blend', confidence: .9),
          const OcrLine('Brazil 60%', confidence: .9),
          const OcrLine('Ethiopia 40%', confidence: .9),
          const OcrLine('Notes: Cocoa', confidence: .9),
        ],
      ]);
      final preprocessor = FakePreprocessor('/tmp/enhanced.png');
      final pipeline = DefaultOcrPipeline(
        ocr: ocr,
        qualityAnalyzer: FakeQualityAnalyzer(
          const ImageQualityReport({ImageQualityIssue.lowContrast}),
        ),
        preprocessor: preprocessor,
      );

      final result = await pipeline.analyze('/tmp/original.jpg');

      expect(ocr.paths, ['/tmp/original.jpg', '/tmp/enhanced.png']);
      expect(preprocessor.enhanceCalls, 1);
      expect(preprocessor.deleted, ['/tmp/enhanced.png']);
      expect(result.usedEnhanced, isTrue);
    },
  );

  test('weak original retries exactly once without a quality issue', () async {
    final ocr = QueueOcrService([
      [const OcrLine('Decorative', confidence: .9)],
      [const OcrLine('Still decorative', confidence: .9)],
    ]);
    final preprocessor = FakePreprocessor('/tmp/enhanced.png');
    final pipeline = DefaultOcrPipeline(
      ocr: ocr,
      qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
      preprocessor: preprocessor,
    );

    await pipeline.analyze('/tmp/original.jpg');

    expect(ocr.paths, ['/tmp/original.jpg', '/tmp/enhanced.png']);
    expect(preprocessor.enhanceCalls, 1);
    expect(preprocessor.deleted, ['/tmp/enhanced.png']);
  });

  test('analyzer failure still returns original OCR', () async {
    final pipeline = DefaultOcrPipeline(
      ocr: QueueOcrService([
        [
          const OcrLine('Name: A', confidence: .9),
          const OcrLine('Brazil', confidence: .9),
          const OcrLine('Natural', confidence: .9),
          const OcrLine('Notes: Cocoa', confidence: .9),
        ],
      ]),
      qualityAnalyzer: ThrowingQualityAnalyzer(),
      preprocessor: FakePreprocessor('/tmp/enhanced.png'),
    );

    final result = await pipeline.analyze('/tmp/original.jpg');

    expect(result.draft.name, 'A');
    expect(result.quality.issues, isEmpty);
  });

  test(
    'preprocessor failure keeps weak original and warns with quality issue',
    () async {
      final pipeline = DefaultOcrPipeline(
        ocr: QueueOcrService([
          [const OcrLine('Decorative', confidence: .4)],
        ]),
        qualityAnalyzer: FakeQualityAnalyzer(
          const ImageQualityReport({ImageQualityIssue.blurry}),
        ),
        preprocessor: ThrowingPreprocessor(),
      );

      final result = await pipeline.analyze('/tmp/original.jpg');

      expect(result.draft.chips, ['Decorative']);
      expect(result.usedEnhanced, isFalse);
      expect(result.shouldWarnQuality, isTrue);
    },
  );

  test(
    'enhanced OCR failure deletes temporary image and keeps original',
    () async {
      final ocr = QueueOcrService([
        [const OcrLine('Decorative', confidence: .4)],
      ], throwOnCall: 2);
      final preprocessor = FakePreprocessor('/tmp/enhanced.png');
      final pipeline = DefaultOcrPipeline(
        ocr: ocr,
        qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
        preprocessor: preprocessor,
      );

      final result = await pipeline.analyze('/tmp/original.jpg');

      expect(result.draft.chips, ['Decorative']);
      expect(result.usedEnhanced, isFalse);
      expect(preprocessor.deleted, ['/tmp/enhanced.png']);
    },
  );

  test('all-null confidence is ignored and strong fields are not weak', () {
    const candidate = OcrCandidate(
      lines: [
        OcrLine('Name: A'),
        OcrLine('Brazil'),
        OcrLine('Natural'),
        OcrLine('Notes: Cocoa'),
      ],
      draft: OcrDraft(
        name: 'A',
        components: [OcrComponentDraft(country: 'Brazil')],
      ),
      knownLabelCount: 2,
      fromEnhanced: false,
    );

    expect(candidate.meanConfidence, isNull);
    expect(isWeakOcr(candidate), isFalse);
  });
}

class QueueOcrService implements OcrService {
  QueueOcrService(this.results, {this.throwOnCall});

  final List<List<OcrLine>> results;
  final int? throwOnCall;
  final paths = <String>[];
  var _index = 0;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    paths.add(imagePath);
    if (paths.length == throwOnCall) throw Exception('OCR failed');
    return results[_index++];
  }
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
    throw Exception('analysis failed');
  }
}

class FakePreprocessor implements OcrImagePreprocessor {
  FakePreprocessor(this.path);

  final String path;
  final deleted = <String>[];
  var enhanceCalls = 0;

  @override
  Future<String> enhance(String imagePath) async {
    enhanceCalls++;
    return path;
  }

  @override
  Future<void> delete(String imagePath) async {
    deleted.add(imagePath);
  }
}

class ThrowingPreprocessor implements OcrImagePreprocessor {
  @override
  Future<String> enhance(String imagePath) async {
    throw Exception('enhancement failed');
  }

  @override
  Future<void> delete(String imagePath) async {}
}
