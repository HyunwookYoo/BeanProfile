// release 스모크 — R8을 거친 release 빌드에서 ML Kit OCR·파서·sqlite가 실제로 도는지 확인하는
// 테스트 전용 진입점이다. flutter drive는 release 모드를 거부하고 profile 빌드는 R8을 돌리지
// 않으므로, 배포 빌드와 같은 Gradle·R8 설정에 진입점만 이 파일로 바꾼 APK를 에뮬레이터에서 돌린다.
// 기대값은 debug 프로브와 공유한다(support/bundled_card_checks.dart).
//
// 빌드: flutter build apk --release --target-platform android-x64 \
//         -t integration_test/release_smoke.dart --dart-define=ENABLE_OCR_DIAGNOSTICS=false
// 판정: python scripts/release_smoke.py (docs/deployment.md §6-H)
import 'dart:io';

import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'support/bundled_card_checks.dart';

/// scripts/release_smoke.py는 logcat에서 이 머리말로 시작하는 줄만 읽는다.
const _marker = 'BEANPROFILE_SMOKE';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _runChecks();
  } catch (error) {
    // ignore: avoid_print
    print('$_marker FATAL $error');
  }
}

Future<void> _runChecks() async {
  final temp = await getTemporaryDirectory();
  final work = await Directory('${temp.path}/beanprofile_release_smoke')
      .create(recursive: true);

  Future<String> asset(String path) async {
    final bytes = await rootBundle.load(path);
    final file = File('${work.path}/${path.split('/').last}');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file.path;
  }

  final ocr = MlkitOcrService();
  final pipeline = DefaultOcrPipeline(
    ocr: ocr,
    qualityAnalyzer: DartImageQualityAnalyzer(),
    preprocessor: DartOcrImagePreprocessor(),
  );

  final checks = <String, Future<List<String>> Function()>{
    'ocr_card_ko': () async {
      final lines =
          await ocr.recognize(await asset('assets/test/ocr_card_ko.png'));
      return koreanCardFailures(lines, parseOcr(lines));
    },
    'ocr_card_orig': () async {
      final lines =
          await ocr.recognize(await asset('assets/test/ocr_card_orig.png'));
      return originalCardFailures(lines, parseOcr(lines));
    },
    'ocr_blend_en': () async {
      final lines =
          await ocr.recognize(await asset('assets/test/ocr_blend_en.png'));
      return brightBlendFailures(parseOcr(lines));
    },
    'ocr_dark_blend_en': () async => darkBlendFailures(
          await pipeline
              .analyze(await asset('assets/test/ocr_dark_blend_en.png')),
        ),
    'ocr_bad_quality_en': () async => badQualityFailures(
          await pipeline
              .analyze(await asset('assets/test/ocr_bad_quality_en.png')),
        ),
    'sqlite': () => _sqliteFailures(work),
  };

  var passed = 0;
  for (final entry in checks.entries) {
    List<String> failures;
    try {
      failures = await entry.value();
    } catch (error) {
      failures = ['exception: $error'];
    }
    if (failures.isEmpty) passed++;
    final verdict = failures.isEmpty ? 'PASS' : 'FAIL ${failures.join(' | ')}';
    // ignore: avoid_print
    print('$_marker CHECK ${entry.key} $verdict');
  }
  // ignore: avoid_print
  print('$_marker DONE $passed/${checks.length}');
  await work.delete(recursive: true);
}

/// 배포 앱처럼 백그라운드 isolate에서 파일 DB를 열어 쓰고 읽는다(drift_flutter도 이 방식이다).
/// 임시 폴더의 별도 파일이라 앱의 실제 DB(에뮬레이터의 개발용 기록)는 건드리지 않는다.
Future<List<String>> _sqliteFailures(Directory work) async {
  final db = AppDatabase.forTesting(
    NativeDatabase.createInBackground(File('${work.path}/smoke.sqlite')),
  );
  try {
    final now = DateTime(2026, 10, 5);
    final beanId = await db.into(db.beans).insert(
          BeansCompanion.insert(
            name: 'release smoke',
            type: BeanType.singleOrigin,
            createdAt: now,
          ),
        );
    await db.into(db.tastings).insert(
          TastingsCompanion.insert(
            beanId: beanId,
            date: now,
            acidity: 3,
            sweetness: 4,
            body: 3,
            bitterness: 2,
            overall: 4,
            createdAt: now,
          ),
        );
    final beans = await db.select(db.beans).get();
    final tastings = await db.select(db.tastings).get();
    return [
      if (beans.length != 1 || beans.single.name != 'release smoke')
        'beans: ${beans.map((b) => b.name).toList()}',
      if (tastings.length != 1 || tastings.single.beanId != beanId)
        'tastings: ${tastings.map((t) => t.beanId).toList()}',
    ];
  } finally {
    await db.close();
  }
}
