// OCR 프로브: 실제 ML Kit가 테스트 카드를 뭐라고 읽는지 + 파서 결과를 출력한다.
// 실행: flutter test integration_test/ocr_probe_test.dart -d <android-emulator>
// 기대값은 support/bundled_card_checks.dart 한 곳에 있다 — release 스모크와 공유한다.
import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/bundled_card_checks.dart';

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
    expect(koreanCardFailures(lines, d), isEmpty);
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
    expect(originalCardFailures(lines, d), isEmpty);
  });

  testWidgets('bright blend is certain and has two components', (tester) async {
    final path = await _copyAssetToTemp('assets/test/ocr_blend_en.png');
    final lines = await MlkitOcrService().recognize(path);
    final draft = parseOcr(lines);

    expect(brightBlendFailures(draft), isEmpty);
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

    expect(darkBlendFailures(result), isEmpty);
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

    expect(badQualityFailures(result), isEmpty);
  });
}
