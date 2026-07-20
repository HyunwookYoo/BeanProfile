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

  group('parseOcr 타이포 제목/이브로우', () {
    test('최대폰트 상단줄=제품명, 그 위 작은줄=로스터리', () {
      final d = parseOcr(const [
        OcrLine('베이스캠프 로스터스', left: 10, top: 10, right: 200, bottom: 30),
        OcrLine('콜롬비아 핑크버번 내추럴', left: 10, top: 40, right: 500, bottom: 90),
        OcrLine('원산지', left: 10, top: 120, right: 70, bottom: 140),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 170),
      ]);
      expect(d.name, '콜롬비아 핑크버번 내추럴');
      expect(d.roaster, '베이스캠프 로스터스');
    });
    test('제목은 있으나 위에 작은 줄이 없으면 name만 채워지고 roaster는 null', () {
      final d = parseOcr(const [
        OcrLine('콜롬비아 핑크버번 내추럴', left: 10, top: 10, right: 500, bottom: 60),
        OcrLine('원산지', left: 10, top: 120, right: 70, bottom: 140),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 170),
      ]);
      expect(d.name, '콜롬비아 핑크버번 내추럴');
      expect(d.roaster, isNull);
    });
    test('가드: 균일 높이면 name/roaster null', () {
      final d = parseOcr(const [
        OcrLine('원산지', left: 10, top: 10, right: 70, bottom: 30),
        OcrLine('콜롬비아', left: 120, top: 10, right: 260, bottom: 30),
        OcrLine('지역', left: 10, top: 40, right: 60, bottom: 60),
      ]);
      expect(d.name, isNull);
      expect(d.roaster, isNull);
    });
    test('콜론 라벨은 타이포 없이도 폴백으로 채워짐(비회귀)', () {
      expect(parseOcrText('제품명: 예가체프 코체레').name, '예가체프 코체레');
      expect(parseOcrText('로스터리: 아우어사이드').roaster, '아우어사이드');
    });
  });

  group('parseOcr 인접 라벨 오채움 가드(FIX1)', () {
    test('같은 행 값이 비어있고 아래는 라벨(품종)뿐이면 region null(라벨을 값으로 오채움 금지)', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130),
        OcrLine('', left: 120, top: 100, right: 200, bottom: 130),
        OcrLine('품종', left: 10, top: 150, right: 70, bottom: 180),
      ]);
      expect(d.region, isNull);
    });
    test('바레 라벨 바로 다음 줄도 바레 라벨이면 region null', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130),
        OcrLine('품종', left: 10, top: 150, right: 70, bottom: 180),
      ]);
      expect(d.region, isNull);
    });
    test('스큐로 같은 행 정렬 실패 시 아래 이웃 라벨을 값으로 오채움하지 않음(region null)', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 180),
        // 스큐로 센터Y가 임계(0.6h)를 넘어 같은 행 매칭 실패.
        OcrLine('후일라', left: 200, top: 210, right: 300, bottom: 240),
        OcrLine('품종', left: 10, top: 200, right: 70, bottom: 230),
      ]);
      expect(d.region, isNull);
    });
  });

  group('parseOcr 실기기 좌표 픽스처(회귀, task-4-report.md 실측 ML Kit 좌표)', () {
    test('콜론 카드(ocr_card_ko.png) 실측 좌표 → 8개 필드', () {
      final d = parseOcr(const [
        OcrLine('COFFEE INFO', left: 92, top: 57, right: 385, bottom: 91),
        OcrLine('제품명: 예가체프 코체레', left: 94, top: 135, right: 737, bottom: 191),
        OcrLine('로스터리: 아우어사이드', left: 94, top: 284, right: 720, bottom: 342),
        OcrLine('원산지: 에티오피아', left: 96, top: 434, right: 602, bottom: 492),
        OcrLine('지역: 예가체프 코체레', left: 75, top: 582, right: 677, bottom: 647),
        OcrLine('품종: 헤어룸', left: 94, top: 734, right: 418, bottom: 792),
        OcrLine('가공: 워시드', left: 71, top: 879, right: 419, bottom: 944),
        OcrLine('로스팅: 라이트미디엄', left: 98, top: 1030, right: 654, bottom: 1092),
        OcrLine('로스팅일: 2026.07.10', left: 93, top: 1181, right: 651, bottom: 1243),
        OcrLine('컵노트: 블루베리, 자스민, 홍차', left: 72, top: 1330, right: 910, bottom: 1398),
      ]);
      expect(d.name, '예가체프 코체레');
      expect(d.roaster, '아우어사이드');
      expect(d.country, 'Ethiopia');
      expect(d.region, '예가체프 코체레');
      expect(d.process, Process.washed);
      expect(d.roastLevel, RoastLevel.lightMedium);
      expect(d.roastDate, DateTime(2026, 7, 10));
      expect(d.cupNotes, ['블루베리', '자스민', '홍차']);
    });

    test('스타일 카드(ocr_card_orig.png, 콜론없음) 실측 좌표 → 8개 필드(좌표 기반)', () {
      final d = parseOcr(const [
        OcrLine('베이스캠프 로스 터스', left: 68, top: 57, right: 391, bottom: 88),
        OcrLine('콜롬비아 핑크버번 내추럴', left: 81, top: 121, right: 939, bottom: 194),
        OcrLine('원산지', left: 77, top: 302, right: 155, bottom: 328),
        OcrLine('지역', left: 78, top: 385, right: 127, bottom: 409),
        OcrLine('품종', left: 78, top: 466, right: 128, bottom: 490),
        OcrLine('가공', left: 78, top: 547, right: 126, bottom: 571),
        OcrLine('로스팅', left: 77, top: 626, right: 155, bottom: 651),
        OcrLine('로스팅일', left: 77, top: 704, right: 183, bottom: 731),
        OcrLine('고도', left: 78, top: 789, right: 128, bottom: 808),
        OcrLine('컵노트', left: 78, top: 910, right: 156, bottom: 936),
        OcrLine('콜롬비아', left: 345, top: 283, right: 519, bottom: 333),
        OcrLine('후일라', left: 346, top: 368, right: 476, bottom: 412),
        OcrLine('핑크 버번', left: 348, top: 446, right: 528, bottom: 493),
        OcrLine('내추럴', left: 349, top: 531, right: 471, bottom: 574),
        OcrLine('미디엄', left: 349, top: 609, right: 468, bottom: 655),
        OcrLine('2026.07.05', left: 346, top: 697, right: 604, bottom: 728),
        OcrLine('1,750 m', left: 347, top: 778, right: 525, bottom: 817),
        OcrLine('딸기, 복숭아, 레드와인', left: 62, top: 967, right: 558, bottom: 1022),
      ]);
      expect(d.country, 'Colombia');
      expect(d.process, Process.natural);
      expect(d.roastLevel, RoastLevel.medium);
      expect(d.roastDate, DateTime(2026, 7, 5));
      expect(d.region, '후일라');
      expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
      expect(d.name, '콜롬비아 핑크버번 내추럴');
      expect(d.roaster, contains('베이스캠프'));
    });
  });
}
