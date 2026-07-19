import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name & roaster', () {
    test('제품명/로스터리 라벨에서 추출(영/한)', () {
      expect(parseOcrText('제품명: 예가체프 코체레').name, '예가체프 코체레');
      expect(parseOcrText('로스터리: 아우어사이드').roaster, '아우어사이드');
      expect(parseOcrText('Name: Kochere').name, 'Kochere');
      expect(parseOcrText('Roaster: Ourside').roaster, 'Ourside');
    });
    test('라벨 없으면 null; 로스팅(roast)은 로스터리 아님', () {
      expect(parseOcrText('Ethiopia Yirgacheffe').name, isNull);
      expect(parseOcrText('Ethiopia Yirgacheffe').roaster, isNull);
      expect(parseOcrText('로스팅: 라이트미디엄').roaster, isNull);
    });
  });

  group('country', () {
    test('영문/한글 원산지를 표준 표기로', () {
      expect(parseOcrText('Ethiopia Yirgacheffe G1').country, 'Ethiopia');
      expect(parseOcrText('에티오피아 예가체프').country, 'Ethiopia');
      expect(parseOcrText('Costa Rica Tarrazu').country, 'Costa Rica');
    });
    test('원산지 아니면 null', () {
      expect(parseOcrText('Fritz Coffee Company').country, isNull);
    });
  });

  group('roastDate', () {
    test('여러 포맷', () {
      expect(parseOcrText('Roasted: 2026-07-02').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('로스팅 2026.07.02').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('2026년 7월 2일 로스팅').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('26/07/02').roastDate, DateTime(2026, 7, 2));
    });
    test('말이 안 되는 숫자는 무시', () {
      expect(parseOcrText('lot 99.99.99').roastDate, isNull);
    });
    test('로스팅 라벨 줄의 날짜가 유통기한 등 다른 날짜보다 우선', () {
      expect(parseOcrText('Best Before 2027-01-15\nRoasted 2026-07-02').roastDate,
          DateTime(2026, 7, 2));
      expect(parseOcrText('로스팅일 2026.07.02\n유통기한 2027.01.15').roastDate,
          DateTime(2026, 7, 2));
    });
  });

  group('roastLevel', () {
    test('복합어가 단일어보다 우선', () {
      expect(parseOcrText('Light-Medium roast').roastLevel, RoastLevel.lightMedium);
      expect(parseOcrText('Full City').roastLevel, RoastLevel.mediumDark);
      expect(parseOcrText('미디엄 로스팅').roastLevel, RoastLevel.medium);
      expect(parseOcrText('다크').roastLevel, RoastLevel.dark);
    });
    test('라이트미디엄/light medium 복합어가 단일어보다 우선(순서 회귀 가드)', () {
      expect(parseOcrText('라이트미디엄 로스팅').roastLevel, RoastLevel.lightMedium);
      expect(parseOcrText('Light Medium').roastLevel, RoastLevel.lightMedium);
    });
  });

  group('process', () {
    test('영/한 키워드', () {
      expect(parseOcrText('Washed').process, Process.washed);
      expect(parseOcrText('내추럴').process, Process.natural);
      expect(parseOcrText('Honey process').process, Process.honey);
      expect(parseOcrText('Anaerobic').process, Process.anaerobic);
    });
  });

  group('cupNotes', () {
    test('라벨 뒤를 구분자로 분리', () {
      expect(parseOcrText('Notes: Blueberry, Jasmine, Black Tea').cupNotes,
          ['Blueberry', 'Jasmine', 'Black Tea']);
      expect(parseOcrText('컵노트: 블루베리 · 자스민').cupNotes, ['블루베리', '자스민']);
    });
    test('라벨 없으면 빈 리스트', () {
      expect(parseOcrText('Ethiopia').cupNotes, isEmpty);
    });
  });

  group('region', () {
    test('지역/Region 라벨에서 추출', () {
      expect(parseOcrText('지역: 후일라').region, '후일라');
      expect(parseOcrText('Region: Yirgacheffe').region, 'Yirgacheffe');
      expect(parseOcrText('REGION : Yirgacheffe · Kochere').region, 'Yirgacheffe · Kochere');
    });
    test('라벨 없으면 null; 국가 라벨(원산지:)은 지역 아님', () {
      expect(parseOcrText('Ethiopia Yirgacheffe').region, isNull);
      expect(parseOcrText('원산지: 콜롬비아').region, isNull);
    });
  });

  group('chips & isEmpty', () {
    test('비어있지 않은 줄을 중복제거해 칩으로', () {
      final d = parseOcrText('프릳츠\n\nG1\n프릳츠');
      expect(d.chips, ['프릳츠', 'G1']);
    });
    test('빈 입력은 isEmpty', () {
      expect(parseOcrText('').isEmpty, isTrue);
      expect(parseOcrText('   \n  ').isEmpty, isTrue);
    });
    test('실제 라벨 종합', () {
      final d = parseOcrText(
          'Fritz Coffee\nEthiopia Yirgacheffe\nWashed\nRoasted 2026.07.02\nNotes: Blueberry, Jasmine');
      expect(d.country, 'Ethiopia');
      expect(d.process, Process.washed);
      expect(d.roastDate, DateTime(2026, 7, 2));
      expect(d.cupNotes, ['Blueberry', 'Jasmine']);
      expect(d.chips, contains('Fritz Coffee'));
    });
  });

  group('parseOcr 좌표 라벨→값', () {
    test('같은 행 오른쪽 값 → region', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130),
        OcrLine('후일라', left: 120, top: 100, right: 260, bottom: 130),
      ]);
      expect(d.region, '후일라');
    });
    test('라벨 아래 값 → cupNotes(구분자 분리)', () {
      final d = parseOcr(const [
        OcrLine('컵노트', left: 10, top: 200, right: 90, bottom: 230),
        OcrLine('딸기, 복숭아, 레드와인', left: 10, top: 240, right: 400, bottom: 270),
      ]);
      expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    });
    test('값 없으면 region null', () {
      final d = parseOcr(const [OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130)]);
      expect(d.region, isNull);
    });
    test('2열 카드: 지역=같은 행, 국가=키워드', () {
      final d = parseOcr(const [
        OcrLine('원산지', left: 10, top: 100, right: 70, bottom: 130),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 180),
        OcrLine('콜롬비아', left: 120, top: 100, right: 260, bottom: 130),
        OcrLine('후일라', left: 120, top: 150, right: 260, bottom: 180),
      ]);
      expect(d.country, 'Colombia');
      expect(d.region, '후일라');
    });
  });
}
