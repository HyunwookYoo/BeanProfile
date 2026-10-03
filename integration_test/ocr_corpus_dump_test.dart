// OCR 코퍼스 덤프 — 기기에서 실제 ML Kit을 돌려 픽스처 원료를 만든다.
// 혼자 돌리지 않는다. 호스트 드라이버가 사진을 서빙하고 결과를 받는다:
//   flutter drive --driver=test_driver/ocr_corpus_driver.dart \
//     --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554
// 설계: docs/plans/ocr-corpus-design.md §4.6
import 'dart:convert';
import 'dart:io';

import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// 에뮬레이터에서 호스트 루프백은 10.0.2.2다. 실기기는 `adb reverse tcp:8765
// tcp:8765` 후 --dart-define=OCR_CORPUS_HOST=http://127.0.0.1:8765 로 바꾼다.
const _host = String.fromEnvironment(
  'OCR_CORPUS_HOST',
  defaultValue: 'http://10.0.2.2:8765',
);

Future<List<int>> _get(String path) async {
  // 응답 없이 막히는 주소(에뮬레이터에서 호스트의 닫힌 포트 등)는 OS 연결
  // 타임아웃이 2분이 넘는다. 기한을 시도 사이에만 보는 _index()가 90초를 훌쩍
  // 넘겨서야 실패하므로 시도마다 끊는다.
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final response = await (await client.getUrl(Uri.parse('$_host/$path'))).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('${response.statusCode} $_host/$path');
    }
    return await consolidateHttpClientResponseBytes(response);
  } finally {
    client.close();
  }
}

/// 드라이버가 테스트보다 늦게 뜰 수 있어 잠깐 기다린다. 끝내 못 닿으면 무한
/// 대기하지 않고 주소를 알려주며 실패한다.
Future<Map<String, String>> _index() async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (true) {
    try {
      final json = jsonDecode(utf8.decode(await _get('index.json')));
      return (json as Map).cast<String, String>();
    } on SocketException catch (error) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('$_host 에 닿지 못했다 ($error). 드라이버가 떠 있는지, '
            '실기기라면 OCR_CORPUS_HOST를 바꿨는지 확인');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}

Map<String, Object?> _line(OcrLine line) => {
      'text': line.text,
      'l': line.left,
      't': line.top,
      'r': line.right,
      'b': line.bottom,
      'conf': line.confidence,
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR 코퍼스 덤프', (tester) async {
    final index = await _index();
    final ocr = MlkitOcrService();
    final quality = DartImageQualityAnalyzer();
    // 사진과 보정본을 cache가 아닌 앱 지원 폴더에 둔다. 에뮬레이터 /data가 거의 차
    // 있으면 안드로이드(installd)가 실행 중에 앱 cache를 비워 처리 중인 파일이
    // 사라지고, OcrService는 없는 파일도 빈 목록으로 삼키므로 조용히 틀린 덤프가
    // 나올 수 있다.
    final work = await getApplicationSupportDirectory();
    final preprocessor =
        DartOcrImagePreprocessor(temporaryDirectory: getApplicationSupportDirectory);
    final cards = <Map<String, Object?>>[];

    for (final MapEntry(key: id, value: source) in index.entries) {
      final image = File('${work.path}/ocr_corpus_$id.${source.split('.').last}');
      await image.writeAsBytes(await _get('card/$id'));

      // DefaultOcrDiagnosticsService.collect(ocr_diagnostics.dart)와 같은 순서다.
      // 다만 조건과 무관하게 보정 패스를 항상 돌린다 — 재생 쪽에서 파이프라인이
      // 어느 분기를 타든 재현할 수 있게(설계 §4.1).
      final issues = [
        for (final issue in (await quality.analyze(image.path)).issues) issue.name,
      ];
      final original = await ocr.recognize(image.path);
      List<OcrLine>? enhanced;
      String? enhancedPath;
      try {
        enhancedPath = await preprocessor.enhance(image.path);
        enhanced = await ocr.recognize(enhancedPath);
      } catch (_) {
        // 보정 실패는 null로 남긴다 — 재생이 기기의 보정 실패 경로를 그대로 탄다.
      } finally {
        if (enhancedPath != null) await preprocessor.delete(enhancedPath);
      }
      await image.delete();

      cards.add({
        'id': id,
        'source': source,
        'quality': issues,
        'original': [for (final line in original) _line(line)],
        'enhanced':
            enhanced == null ? null : [for (final line in enhanced) _line(line)],
      });
      // ignore: avoid_print
      print('덤프 $id: 원본 ${original.length}줄, '
          '보정 ${enhanced?.length ?? '없음'}, 품질 $issues');
    }
    binding.reportData = {'cards': cards};
  }, timeout: const Timeout(Duration(minutes: 30)));
}
