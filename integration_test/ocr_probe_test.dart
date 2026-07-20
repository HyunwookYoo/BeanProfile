// OCR 프로브: 실제 ML Kit가 테스트 카드를 뭐라고 읽는지 + 파서 결과를 출력한다.
// 실행: flutter test integration_test/ocr_probe_test.dart -d <android-emulator>
import 'dart:io';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR 프로브: 카드 인식 → 파서', (tester) async {
    final bytes = await rootBundle.load('assets/test/ocr_card_ko.png');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ocr_card_ko.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());

    final lines = await MlkitOcrService().recognize(file.path);
    // ignore: avoid_print
    print('===OCR_LINES_START===');
    for (final l in lines) {
      // ignore: avoid_print
      print('[${l.left.toStringAsFixed(0)},${l.top.toStringAsFixed(0)} '
          '${l.right.toStringAsFixed(0)},${l.bottom.toStringAsFixed(0)}] ${l.text}');
    }
    // ignore: avoid_print
    print('===OCR_LINES_END===');
    final d = parseOcr(lines);
    // ignore: avoid_print
    print('PARSED name=${d.name} | roaster=${d.roaster} | country=${d.country} '
        '| region=${d.region} | process=${d.process} | roast=${d.roastLevel} '
        '| date=${d.roastDate} | notes=${d.cupNotes}');
    // ignore: avoid_print
    print('CHIPS=${d.chips}');

    // 실제 ML Kit OCR → 파서가 8개 필드를 모두 채우는지(회귀 가드).
    expect(lines, isNotEmpty);
    expect(d.name, '예가체프 코체레');
    expect(d.roaster, '아우어사이드');
    expect(d.country, 'Ethiopia');
    expect(d.region, '예가체프 코체레');
    expect(d.process, Process.washed);
    expect(d.roastLevel, RoastLevel.lightMedium);
    expect(d.roastDate, DateTime(2026, 7, 10));
    expect(d.cupNotes, ['블루베리', '자스민', '홍차']);
  });

  // 스타일 카드(콜론 없음, 라벨/값 컬럼) — 좌표 기반 parseOcr이 채우는지 확인.
  testWidgets('OCR 프로브: 원본(콜론없음) 카드 → 파서', (tester) async {
    final bytes = await rootBundle.load('assets/test/ocr_card_orig.png');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ocr_card_orig.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());

    final lines = await MlkitOcrService().recognize(file.path);
    // ignore: avoid_print
    print('===ORIG_LINES_START===');
    for (final l in lines) {
      // ignore: avoid_print
      print('[${l.left.toStringAsFixed(0)},${l.top.toStringAsFixed(0)} '
          '${l.right.toStringAsFixed(0)},${l.bottom.toStringAsFixed(0)}] ${l.text}');
    }
    // ignore: avoid_print
    print('===ORIG_LINES_END===');
    final d = parseOcr(lines);
    // ignore: avoid_print
    print('ORIG_PARSED name=${d.name} | roaster=${d.roaster} | country=${d.country} '
        '| region=${d.region} | process=${d.process} | roast=${d.roastLevel} '
        '| date=${d.roastDate} | notes=${d.cupNotes}');

    // 실제 ML Kit OCR → 스타일 카드(콜론 없음)도 좌표 파싱으로 4개 필드가 채워지는지.
    expect(lines, isNotEmpty);
    expect(d.country, 'Colombia');
    expect(d.process, Process.natural);
    expect(d.roastLevel, RoastLevel.medium);
    expect(d.roastDate, DateTime(2026, 7, 5));
    expect(d.region, '후일라');
    expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    expect(d.name, '콜롬비아 핑크버번 내추럴');
    expect(d.roaster, contains('베이스캠프')); // '베이스캠프 로스 터스'(자간 오독 허용)
  });
}
