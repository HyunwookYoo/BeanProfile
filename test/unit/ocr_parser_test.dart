import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

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
      expect(parseOcrText('Ethiopia Yirgacheffe G1').components.single.country, 'Ethiopia');
      expect(parseOcrText('에티오피아 예가체프').components.single.country, 'Ethiopia');
      expect(parseOcrText('Costa Rica Tarrazu').components.single.country, 'Costa Rica');
    });
    test('원산지 아니면 null', () {
      expect(parseOcrText('Fritz Coffee Company').components, isEmpty);
    });
    test('설명문의 다른 국가는 두 번째 구성으로 채택하지 않음', () {
      final d = parseOcrText(
          'Ethiopia Guji\nRoasted in Colombia by Example Roasters');
      expect(d.components, hasLength(1));
      expect(d.components.single.country, 'Ethiopia');
    });
    test('좌표 없는 제목 국가와 구조화 원산지 중복은 한 구성으로 합침', () {
      final d = parseOcrText('Colombia Pink Bourbon\nOrigin\nColombia');
      expect(d.components, hasLength(1));
      expect(d.components.single.country, 'Colombia');
      expect(d.typeDecision, isNot(OcrTypeDecision.certainBlend));
    });
    test('구조적인 복수 원산지가 parseOcr 구성과 유형 판별까지 연결됨', () {
      final d = parseOcr(const [
        OcrLine('BLEND', left: 20, top: 10, right: 140, bottom: 40),
        OcrLine('Brazil 60%', left: 20, top: 80, right: 240, bottom: 120),
        OcrLine('Cerrado Natural', left: 20, top: 130, right: 300, bottom: 170),
        OcrLine('Ethiopia 40%', left: 20, top: 220, right: 270, bottom: 260),
        OcrLine('Guji Washed', left: 20, top: 270, right: 260, bottom: 310),
      ]);
      expect(d.components.map((c) => c.country), ['Brazil', 'Ethiopia']);
      expect(d.components.map((c) => c.ratioPercent), [60, 40]);
      expect(d.typeDecision, OcrTypeDecision.certainBlend);
      expect(d.typeReasons, contains(OcrTypeReason.multipleComponents));
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
      expect(parseOcrText('Ethiopia Washed').components.single.process, Process.washed);
      expect(parseOcrText('Ethiopia 내추럴').components.single.process, Process.natural);
      expect(parseOcrText('Ethiopia Honey process').components.single.process, Process.honey);
      expect(parseOcrText('Ethiopia Anaerobic').components.single.process, Process.anaerobic);
    });
    test('라벨된 미인식 가공값은 전역 키워드보다 Process.other가 우선', () {
      final d = parseOcrText('Ethiopia\n가공\n무산소 발효');
      expect(d.components.single.process, Process.other);
      expect(d.components.single.region, isNull);
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
      expect(parseOcrText('Ethiopia\n지역: 후일라').components.single.region, '후일라');
      expect(parseOcrText('Ethiopia\nRegion: Yirgacheffe').components.single.region, 'Yirgacheffe');
      expect(parseOcrText('Ethiopia\nREGION : Yirgacheffe · Kochere').components.single.region, 'Yirgacheffe · Kochere');
    });
    test('라벨 없으면 null; 국가 라벨(원산지:)은 지역 아님', () {
      expect(parseOcrText('Ethiopia Yirgacheffe').components.single.region, isNull);
      expect(parseOcrText('원산지: 콜롬비아').components.single.region, isNull);
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
      expect(d.components.single.country, 'Ethiopia');
      expect(d.components.single.process, Process.washed);
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
      expect(d.components, isEmpty);
    });
    test('라벨 아래 값 → cupNotes(구분자 분리)', () {
      final d = parseOcr(const [
        OcrLine('컵노트', left: 10, top: 200, right: 90, bottom: 230),
        OcrLine('딸기, 복숭아, 레드와인', left: 10, top: 240, right: 400, bottom: 270),
      ]);
      expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    });
    test('컵노트 후보에서 날짜를 제외하고 유일한 노트 칩을 사용', () {
      final d = parseOcr(const [
        OcrLine('컵노트', left: 713, top: 3419, right: 900, bottom: 3457),
        OcrLine(
          'COCOA, BERRY, JASMINE',
          left: 1541,
          top: 3543,
          right: 2401,
          bottom: 3618,
        ),
        OcrLine(
          '2026.07.24',
          left: 713,
          top: 3589,
          right: 1033,
          bottom: 3643,
        ),
        OcrLine('로스팅일', left: 318, top: 3602, right: 515, bottom: 3646),
      ]);

      expect(d.cupNotes, ['COCOA', 'BERRY', 'JASMINE']);
    });
    test('컵노트 후보에서 구조화 필드 값을 제외하고 유일한 노트 칩을 사용', () {
      final d = parseOcr(const [
        OcrLine('컵노트', left: 713, top: 3419, right: 900, bottom: 3457),
        OcrLine('MEDIUM', left: 713, top: 3480, right: 1033, bottom: 3520),
        OcrLine('WASHED', left: 713, top: 3530, right: 1033, bottom: 3570),
        OcrLine('BRAZIL', left: 713, top: 3580, right: 1033, bottom: 3620),
        OcrLine('BLEND', left: 713, top: 3630, right: 1033, bottom: 3670),
        OcrLine('2026.07.24', left: 713, top: 3680, right: 1033, bottom: 3720),
        OcrLine('60%', left: 713, top: 3730, right: 1033, bottom: 3770),
        OcrLine(
          'COCOA, BERRY, JASMINE',
          left: 1541,
          top: 3543,
          right: 2401,
          bottom: 3618,
        ),
      ]);

      expect(d.cupNotes, ['COCOA', 'BERRY', 'JASMINE']);
    });
    test('값 없으면 region null', () {
      final d = parseOcr(const [OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130)]);
      expect(d.components, isEmpty);
    });
    test('2열 카드: 지역=같은 행, 국가=키워드', () {
      final d = parseOcr(const [
        OcrLine('원산지', left: 10, top: 100, right: 70, bottom: 130),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 180),
        OcrLine('콜롬비아', left: 120, top: 100, right: 260, bottom: 130),
        OcrLine('후일라', left: 120, top: 150, right: 260, bottom: 180),
      ]);
      expect(d.components.single.country, 'Colombia');
      expect(d.components.single.region, '후일라');
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
    test('제목 바로 위 유일한 브랜드는 가로 좌표가 벌어져도 로스터리로 채움', () {
      final d = parseOcr(const [
        OcrLine('BEANPROFILE LAB', left: 900, top: 10, right: 1100, bottom: 30),
        OcrLine('BLEND', left: 700, top: 10, right: 800, bottom: 30),
        OcrLine('DAYBREAK HOUSE', left: 100, top: 50, right: 500, bottom: 120),
        OcrLine('BRAZIL', left: 100, top: 180, right: 220, bottom: 220),
      ]);

      expect(d.name, 'DAYBREAK HOUSE');
      expect(d.roaster, 'BEANPROFILE LAB');
    });
    test('유일한 브랜드 표식 줄은 좌표 연결이 없어도 로스터리로 채움', () {
      final d = parseOcr(const [
        OcrLine('BEANPROFILE LAB'),
        OcrLine('Name: DAYBREAK HOUSE'),
        OcrLine('BLEND'),
        OcrLine('Brazil 60%'),
        OcrLine('Ethiopia 40%'),
      ]);

      expect(d.name, 'DAYBREAK HOUSE');
      expect(d.roaster, 'BEANPROFILE LAB');
    });
    test('제품 유형 줄이 제목과 겹쳐도 로스터리로 사용하지 않음', () {
      final d = parseOcr(const [
        OcrLine('BLEND', left: 100, top: 10, right: 250, bottom: 30),
        OcrLine('BEANPROFILE LAB', left: 900, top: 10, right: 1100, bottom: 30),
        OcrLine('DAYBREAK HOUSE', left: 100, top: 50, right: 500, bottom: 120),
        OcrLine('BRAZIL', left: 100, top: 180, right: 220, bottom: 220),
      ]);

      expect(d.name, 'DAYBREAK HOUSE');
      expect(d.roaster, 'BEANPROFILE LAB');
    });
    test('세로 푸터가 있어도 가로 제품명을 선택함', () {
      final d = parseOcr(const [
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
        OcrLine('BRAZIL', left: 1373, top: 1539, right: 1696, bottom: 1646),
        OcrLine(
          'CUPPING LAB TWO ORIGINS ROAST PROFILE 04',
          left: 193,
          top: 2882,
          right: 264,
          bottom: 3907,
        ),
      ]);

      expect(d.name, 'DAYBREAK HOUSE BLEND');
      expect(d.roaster, 'BEANPROFILE LAB');
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
      expect(d.components, isEmpty);
    });
    test('바레 라벨 바로 다음 줄도 바레 라벨이면 region null', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130),
        OcrLine('품종', left: 10, top: 150, right: 70, bottom: 180),
      ]);
      expect(d.components, isEmpty);
    });
    test('스큐로 같은 행 정렬 실패 시 아래 이웃 라벨을 값으로 오채움하지 않음(region null)', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 180),
        // 스큐로 센터Y가 임계(0.6h)를 넘어 같은 행 매칭 실패.
        OcrLine('후일라', left: 200, top: 210, right: 300, bottom: 240),
        OcrLine('품종', left: 10, top: 200, right: 70, bottom: 230),
      ]);
      expect(d.components, isEmpty);
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
      expect(d.components.single.country, 'Ethiopia');
      expect(d.components.single.region, '예가체프 코체레');
      expect(d.components.single.process, Process.washed);
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
      expect(d.components.single.country, 'Colombia');
      expect(d.components.single.process, Process.natural);
      expect(d.roastLevel, RoastLevel.medium);
      expect(d.roastDate, DateTime(2026, 7, 5));
      expect(d.components.single.region, '후일라');
      expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
      expect(d.name, '콜롬비아 핑크버번 내추럴');
      expect(d.roaster, contains('베이스캠프'));
    });
  });

  group('RED CASCARA 실기기 픽스처(한/영 병기 블렌드 카드)', () {
    test('로스터리는 제목의 영문판이 아니라 그 위 이브로우', () {
      final d = parseOcr(redCascaraLines);

      expect(d.name, '레드 카스카라');
      expect(d.roaster, 'UNSPECIALTY');
    });

    // 가드 — 접미 정리가 이브로우를 빈 문자열로 만들어 기존 null 처리를
    // 빠져나가지 않는지 본다. 수정 전후 모두 통과해야 한다.
    test('이브로우가 원두 타입 토큰뿐이면 로스터리는 비운다', () {
      final d = parseOcr(const [
        OcrLine('BLEND', left: 100, top: 100, right: 260, bottom: 140),
        OcrLine('하우스 블렌드', left: 100, top: 200, right: 700, bottom: 290),
        OcrLine('원산지', left: 100, top: 400, right: 220, bottom: 430),
        OcrLine('브라질', left: 300, top: 400, right: 450, bottom: 430),
      ]);

      expect(d.name, '하우스 블렌드');
      expect(d.roaster, isNull);
    });

    test('한/영 2줄 라벨 옆 컵노트를 두 줄 다 가져온다', () {
      final d = parseOcr(redCascaraLines);

      expect(d.cupNotes, [
        'Raspberrie',
        'Sapphire Grape',
        'Complexity',
        'Citrus fnish',
      ]);
    });

    test('값 수집은 다음 라벨 블록에서 멈춘다', () {
      // 상한이 없으면 `로스터기` 블록 오른쪽의 기계 이름이 컵노트로 새어 든다.
      final d = parseOcr(const [
        OcrLine('노트', left: 80, top: 100, right: 160, bottom: 140),
        OcrLine('Notes', left: 80, top: 150, right: 160, bottom: 190),
        OcrLine('딸기, 자두', left: 300, top: 100, right: 600, bottom: 140),
        OcrLine('블루베리', left: 300, top: 150, right: 600, bottom: 190),
        OcrLine('로스터기', left: 80, top: 400, right: 200, bottom: 440),
        OcrLine('Roaster', left: 80, top: 450, right: 200, bottom: 490),
        OcrLine('Stronghold S7X', left: 300, top: 400, right: 600, bottom: 440),
      ]);

      expect(d.cupNotes, ['딸기', '자두', '블루베리']);
    });

    test('아래에 라벨이 없어도 값 수집은 여백에서 끊긴다', () {
      final d = parseOcr(const [
        OcrLine('노트', left: 80, top: 100, right: 160, bottom: 140),
        OcrLine('Notes', left: 80, top: 150, right: 160, bottom: 190),
        OcrLine('딸기, 자두', left: 300, top: 100, right: 600, bottom: 140),
        OcrLine('블루베리', left: 300, top: 150, right: 600, bottom: 190),
        OcrLine('LOT A1234', left: 300, top: 900, right: 600, bottom: 940),
      ]);

      expect(d.cupNotes, ['딸기', '자두', '블루베리']);
    });

    test('카드 전체 — 성분 3개와 비율, 비율 불명은 null로 남긴다', () {
      final d = parseOcr(redCascaraLines);

      expect(d.typeDecision, OcrTypeDecision.certainBlend);
      expect(
        d.components.map((c) => c.country),
        ['Thailand', 'Ethiopia', 'Colombia'],
      );
      // Thailand의 비율은 복구하지 않는다 — OCR이 `Natural 709 - 40%`를
      // `Natural 70940%`로 붙여 읽어 단어 경계가 사라졌다. 추측해 채우면
      // 조용히 틀린 값이 저장된다.
      expect(d.components.map((c) => c.ratioPercent), [null, 40, 20]);
      // region은 실측값을 그대로 고정한다 — 지역 라벨이 카드에 아예 없어
      // 셋 다 지역명이 아니다. Thailand는 "Blending Info" 섹션 헤더를
      // 값으로 오채움하던 버그를 고쳤지만, 다음으로 가까운 후보인
      // "bio control Natural 70940%"에서 가공법만 제거한 나머지라 여전히
      // 지역명이 아니다(같은 OCR 붙어읽기로 비율까지 뭉개진 잔여물). 이
      // 값을 "더 낫게" 보이도록 추측 로직을 얹지 않는다 — 그러면 라벨
      // 오채움과 같은 실수를 반복하게 된다.
      expect(
        d.components.map((c) => c.region),
        ['bio control 70940%', 'GI -', 'Papayo'],
      );
    });
  });
}
