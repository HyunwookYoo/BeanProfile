// OCR 프로브: 실제 ML Kit가 테스트 카드를 뭐라고 읽는지 + 파서 결과를 출력한다.
// 실행: flutter test integration_test/ocr_probe_test.dart -d <android-emulator>
import 'dart:io';

import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<String> _copyAssetToTemp(String assetPath) async {
  final bytes = await rootBundle.load(assetPath);
  final temp = await getTemporaryDirectory();
  final dir = await Directory(
    '${temp.path}/beanprofile_ocr_probe_'
    '${DateTime.now().microsecondsSinceEpoch}',
  ).create();
  addTearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  final file = File('${dir.path}/${assetPath.split('/').last}');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return file.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR 프로브: 카드 인식 → 파서', (tester) async {
    final path = await _copyAssetToTemp('assets/test/ocr_card_ko.png');
    final lines = await MlkitOcrService().recognize(path);
    // ignore: avoid_print
    print('===OCR_LINES_START===');
    for (final l in lines) {
      // ignore: avoid_print
      print(
        '[${l.left.toStringAsFixed(0)},${l.top.toStringAsFixed(0)} '
        '${l.right.toStringAsFixed(0)},${l.bottom.toStringAsFixed(0)}] ${l.text}',
      );
    }
    // ignore: avoid_print
    print('===OCR_LINES_END===');
    final d = parseOcr(lines);
    final component = d.components.single;
    // ignore: avoid_print
    print(
      'PARSED name=${d.name} | roaster=${d.roaster} | country=${component.country} '
      '| region=${component.region} | process=${component.process} | roast=${d.roastLevel} '
      '| date=${d.roastDate} | notes=${d.cupNotes}',
    );
    // ignore: avoid_print
    print('CHIPS=${d.chips}');

    // 실제 ML Kit OCR → 파서가 8개 필드를 모두 채우는지(회귀 가드).
    expect(lines, isNotEmpty);
    expect(d.name, '예가체프 코체레');
    expect(d.roaster, '아우어사이드');
    expect(component.country, 'Ethiopia');
    expect(component.region, '예가체프 코체레');
    expect(component.process, Process.washed);
    expect(d.roastLevel, RoastLevel.lightMedium);
    expect(d.roastDate, DateTime(2026, 7, 10));
    expect(d.cupNotes, ['블루베리', '자스민', '홍차']);
  });

  // 스타일 카드(콜론 없음, 라벨/값 컬럼) — 좌표 기반 parseOcr이 채우는지 확인.
  testWidgets('OCR 프로브: 원본(콜론없음) 카드 → 파서', (tester) async {
    final path = await _copyAssetToTemp('assets/test/ocr_card_orig.png');
    final lines = await MlkitOcrService().recognize(path);
    // ignore: avoid_print
    print('===ORIG_LINES_START===');
    for (final l in lines) {
      // ignore: avoid_print
      print(
        '[${l.left.toStringAsFixed(0)},${l.top.toStringAsFixed(0)} '
        '${l.right.toStringAsFixed(0)},${l.bottom.toStringAsFixed(0)}] ${l.text}',
      );
    }
    // ignore: avoid_print
    print('===ORIG_LINES_END===');
    final d = parseOcr(lines);
    final component = d.components.single;
    // ignore: avoid_print
    print(
      'ORIG_PARSED name=${d.name} | roaster=${d.roaster} | country=${component.country} '
      '| region=${component.region} | process=${component.process} | roast=${d.roastLevel} '
      '| date=${d.roastDate} | notes=${d.cupNotes}',
    );

    // 실제 ML Kit OCR → 스타일 카드(콜론 없음) 8개 필드(그중 지역·컵노트·제품명·로스터리가 좌표 기반).
    expect(lines, isNotEmpty);
    expect(component.country, 'Colombia');
    expect(component.process, Process.natural);
    expect(d.roastLevel, RoastLevel.medium);
    expect(d.roastDate, DateTime(2026, 7, 5));
    expect(component.region, '후일라');
    expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    expect(d.name, '콜롬비아 핑크버번 내추럴');
    expect(d.roaster, contains('베이스캠프')); // '베이스캠프 로스 터스'(자간 오독 허용)
  });

  testWidgets('bright blend is certain and has two components', (tester) async {
    final path = await _copyAssetToTemp('assets/test/ocr_blend_en.png');
    final lines = await MlkitOcrService().recognize(path);
    final draft = parseOcr(lines);

    expect(draft.typeDecision, OcrTypeDecision.certainBlend);
    expect(draft.components, hasLength(2));
    expect(draft.components.map((c) => c.country), ['Brazil', 'Ethiopia']);
    expect(draft.components.map((c) => c.ratioPercent), [60, 40]);
  });

  testWidgets('dark blend uses enhanced candidate and restores required data', (
    tester,
  ) async {
    final path = await _copyAssetToTemp('assets/test/ocr_dark_blend_en.png');
    final pipeline = DefaultOcrPipeline(
      ocr: MlkitOcrService(),
      qualityAnalyzer: DartImageQualityAnalyzer(),
      preprocessor: DartOcrImagePreprocessor(),
    );
    final result = await pipeline.analyze(path);

    expect(result.usedEnhanced, isTrue);
    expect(result.draft.name, isNotNull);
    expect(
      result.draft.components.where((c) => c.country != null),
      hasLength(2),
    );
  });

  testWidgets('blur and glare produce non-blocking quality warning', (
    tester,
  ) async {
    final path = await _copyAssetToTemp('assets/test/ocr_bad_quality_en.png');
    final pipeline = DefaultOcrPipeline(
      ocr: MlkitOcrService(),
      qualityAnalyzer: DartImageQualityAnalyzer(),
      preprocessor: DartOcrImagePreprocessor(),
    );
    final result = await pipeline.analyze(path);

    expect(result.quality.hasIssues, isTrue);
    expect(result.shouldWarnQuality, isTrue);
  });
}
