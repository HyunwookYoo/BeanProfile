import 'package:beanprofile/data/enums.dart';
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

  test(
    'low contrast merges complementary fields for matching components',
    () async {
      final pipeline = DefaultOcrPipeline(
        ocr: QueueOcrService([
          [
            const OcrLine('Name: House Blend', confidence: .9),
            const OcrLine('Roaster: BeanProfile Lab', confidence: .9),
            const OcrLine('Roast date: 2026.07.24', confidence: .9),
            const OcrLine('MEDIUM', confidence: .9),
            const OcrLine('Brazil 60%', confidence: .9),
            const OcrLine('Cerrado', confidence: .9),
            const OcrLine('Ethiopia 40%', confidence: .9),
          ],
          [
            const OcrLine('Name: House Blend', confidence: .9),
            const OcrLine('Brazil 60%', confidence: .9),
            const OcrLine('Natural', confidence: .9),
            const OcrLine('Ethiopia 40%', confidence: .9),
            const OcrLine('Guji', confidence: .9),
            const OcrLine('Washed', confidence: .9),
          ],
        ]),
        qualityAnalyzer: FakeQualityAnalyzer(
          const ImageQualityReport({ImageQualityIssue.lowContrast}),
        ),
        preprocessor: FakePreprocessor('/tmp/enhanced.png'),
      );

      final result = await pipeline.analyze('/tmp/original.jpg');

      expect(result.usedEnhanced, isFalse);
      expect(result.draft.components, [
        isA<OcrComponentDraft>()
            .having((component) => component.country, 'country', 'Brazil')
            .having((component) => component.region, 'region', 'Cerrado')
            .having(
              (component) => component.process,
              'process',
              Process.natural,
            )
            .having((component) => component.ratioPercent, 'ratio', 60),
        isA<OcrComponentDraft>()
            .having((component) => component.country, 'country', 'Ethiopia')
            .having((component) => component.region, 'region', 'Guji')
            .having((component) => component.process, 'process', Process.washed)
            .having((component) => component.ratioPercent, 'ratio', 40),
      ]);
    },
  );

  test('iOS EXIF-rotated C card retries with baked geometry', () async {
    final ocr = QueueOcrService([
      _iosOriginalCCardLines,
      _iosEnhancedCCardLines,
    ]);
    final pipeline = DefaultOcrPipeline(
      ocr: ocr,
      qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
      preprocessor: FakePreprocessor('/tmp/enhanced.png'),
    );

    final result = await pipeline.analyze('/tmp/original.jpg');

    expect(ocr.paths, ['/tmp/original.jpg', '/tmp/enhanced.png']);
    expect(result.usedEnhanced, isTrue);
    expect(result.draft.name, 'DAYBREAK HOUSE BLEND');
    expect(result.draft.roaster, 'BEANPROFILE LAB');
    expect(result.draft.components, [
      isA<OcrComponentDraft>()
          .having((component) => component.country, 'country', 'Brazil')
          .having((component) => component.region, 'region', 'CERRAD0')
          .having((component) => component.process, 'process', Process.natural)
          .having((component) => component.ratioPercent, 'ratio', 60),
      isA<OcrComponentDraft>()
          .having((component) => component.country, 'country', 'Ethiopia')
          .having((component) => component.region, 'region', 'GUJI')
          .having((component) => component.process, 'process', Process.washed)
          .having((component) => component.ratioPercent, 'ratio', 40),
    ]);
  });

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

const _iosOriginalCCardLines = [
  OcrLine('BLEND ANALYSIS', left: 677, top: 2501, right: 715, bottom: 2882),
  OcrLine('60', left: 760, top: 2691, right: 940, bottom: 2874),
  OcrLine('40', left: 961, top: 2678, right: 1138, bottom: 2870),
  OcrLine('68;', left: 680, top: 2617, right: 1141, bottom: 2882),
  OcrLine('ORIGIN e2', left: 2504, top: 1917, right: 2547, bottom: 2146),
  OcrLine('성', left: 2558, top: 2094, right: 2595, bottom: 2128),
  OcrLine(
    'BEANPROFILE LAB',
    left: 554,
    top: 1491,
    right: 602,
    bottom: 2034,
  ),
  OcrLine('BLEND', left: 537, top: 205, right: 581, bottom: 400),
  OcrLine(
    'DAYBREAK HOUSE BLEND',
    left: 651,
    top: 359,
    right: 806,
    bottom: 2024,
  ),
  OcrLine('지역', left: 1274, top: 802, right: 1311, bottom: 880),
  OcrLine('CERRAD0', left: 1259, top: 310, right: 1306, bottom: 549),
  OcrLine('BRAZIL', left: 1541, top: 1329, right: 1642, bottom: 1650),
  OcrLine('60%', left: 1701, top: 1535, right: 1767, bottom: 1654),
  OcrLine('ETHIOPIA', left: 2448, top: 1241, right: 2538, bottom: 1647),
  OcrLine('40%', left: 2599, top: 1536, right: 2661, bottom: 1658),
  OcrLine('가공', left: 1738, top: 806, right: 1777, bottom: 887),
  OcrLine('NATURAL', left: 1727, top: 330, right: 1773, bottom: 558),
  OcrLine('지역', left: 2192, top: 814, right: 2231, bottom: 893),
  OcrLine('GUJI', left: 2181, top: 459, right: 2231, bottom: 567),
  OcrLine('가공', left: 2639, top: 817, right: 2683, bottom: 907),
  OcrLine('WASHED', left: 2626, top: 368, right: 2680, bottom: 577),
  OcrLine('로스팅', left: 3289, top: 1989, right: 3327, bottom: 2104),
  OcrLine('MEDIUM', left: 3283, top: 1550, right: 3329, bottom: 1742),
  OcrLine('로스팅일', left: 3301, top: 909, right: 3344, bottom: 1068),
  OcrLine('2026.07.24', left: 3296, top: 443, right: 3343, bottom: 702),
  OcrLine('컵노트', left: 3634, top: 1915, right: 3668, bottom: 2029),
  OcrLine(
    'COCOA, BERRY, JASMINE',
    left: 3735,
    top: 1239,
    right: 3811,
    bottom: 2030,
  ),
  OcrLine(
    'CUPPING LAB TWO ORIGINS RO AST PROF ILE 84',
    left: 2882,
    top: 2763,
    right: 3886,
    bottom: 2831,
  ),
];

const _iosEnhancedCCardLines = [
  OcrLine('BLEND ANALYSIS', left: 142, top: 678, right: 523, bottom: 715),
  OcrLine('60', left: 150, top: 764, right: 329, bottom: 940),
  OcrLine('40', left: 160, top: 967, right: 345, bottom: 1136),
  OcrLine(
    'BEANPROFILE LAB',
    left: 990,
    top: 555,
    right: 1532,
    bottom: 602,
  ),
  OcrLine('BLEND', left: 2625, top: 538, right: 2818, bottom: 580),
  OcrLine(
    'DAYBREAK HOUSE BLEND',
    left: 996,
    top: 650,
    right: 2665,
    bottom: 806,
  ),
  OcrLine('지역', left: 2144, top: 1273, right: 2222, bottom: 1311),
  OcrLine('CERRAD0', left: 2475, top: 1259, right: 2714, bottom: 1306),
  OcrLine('성 1', left: 888, top: 1662, right: 975, bottom: 1699),
  OcrLine('BRAZIL', left: 1373, top: 1539, right: 1696, bottom: 1646),
  OcrLine('60%', left: 1351, top: 1700, right: 1490, bottom: 1764),
  OcrLine('가공', left: 2137, top: 1738, right: 2218, bottom: 1776),
  OcrLine('NATURAL', left: 2466, top: 1727, right: 2695, bottom: 1773),
  OcrLine('지역', left: 2131, top: 2192, right: 2210, bottom: 2232),
  OcrLine('GUJI', left: 2456, top: 2180, right: 2565, bottom: 2231),
  OcrLine('ORIGIN 02 T', left: 889, top: 2506, right: 1212, bottom: 2548),
  OcrLine('성', left: 895, top: 2557, right: 930, bottom: 2595),
  OcrLine('ETHIOPIA', left: 1377, top: 2448, right: 1779, bottom: 2538),
  OcrLine('40%', left: 1370, top: 2601, right: 1487, bottom: 2658),
  OcrLine('가공', left: 2126, top: 2644, right: 2203, bottom: 2682),
  OcrLine('WASHED', left: 2447, top: 2626, right: 2656, bottom: 2680),
  OcrLine('로스팅', left: 921, top: 3291, right: 1035, bottom: 3325),
  OcrLine('MEDIUM', left: 1281, top: 3283, right: 1474, bottom: 3329),
  OcrLine('로스팅일', left: 1957, top: 3304, right: 2113, bottom: 3339),
  OcrLine('2026.07.24', left: 2322, top: 3295, right: 2580, bottom: 3344),
  OcrLine('컵노트', left: 994, top: 3634, right: 1109, bottom: 3668),
  OcrLine(
    'COCOA, BERRY, JASMINE',
    left: 994,
    top: 3735,
    right: 1785,
    bottom: 3813,
  ),
  OcrLine(
    'CUPPING LAB TWO ORIGINS ROAST PROF ILE 04',
    left: 193,
    top: 2882,
    right: 264,
    bottom: 3907,
  ),
];

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
