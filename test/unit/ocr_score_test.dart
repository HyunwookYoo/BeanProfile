// 채점기 자체 테스트. 채점기가 조용히 고장나면 리포트가 그럴듯한 숫자를 내면서
// 아무것도 재지 않는다 — 이 프로젝트가 두 번 만난 실패 모드다(설계 §4.5).
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ocr_score.dart';

Map<String, Object?> comp({
  Object? country,
  Object? region,
  Object? process,
  Object? ratioPercent,
}) =>
    {
      'country': country,
      'region': region,
      'process': process,
      'ratioPercent': ratioPercent,
    };

/// 최소 정답표. 시험하는 칸만 넘긴다.
Truth truth({
  Object? name,
  Object? roaster,
  Object? roastDate,
  Object? roastLevel,
  Object? type = 'single',
  List<String> cupNotes = const [],
  List<Map<String, Object?>> components = const [],
}) =>
    Truth.fromJson({
      'id': 't',
      'name': name,
      'roaster': roaster,
      'roastDate': roastDate,
      'roastLevel': roastLevel,
      'type': type,
      'cupNotes': cupNotes,
      'components': components,
    });

Map<String, Cell> score(Truth truth, OcrDraft draft) =>
    {for (final cell in scoreDraft(truth, draft)) cell.key: cell};

void main() {
  group('판정 다섯 갈래 (설계 §4.3 표)', () {
    test('정답 있음 + 같은 값이면 correct', () {
      final cells = score(
          truth(name: '예가체프 코체레'), const OcrDraft(name: '예가체프 코체레'));
      expect(cells['name']!.verdict, Verdict.correct);
    });

    test('정답 있음 + 비우면 missing', () {
      final cells = score(truth(name: '예가체프 코체레'), const OcrDraft());
      expect(cells['name']!.verdict, Verdict.missing);
    });

    test('정답 있음 + 다른 값이면 wrong이고 그 값을 남긴다', () {
      final cells =
          score(truth(name: 'HWACHAE BLEND'), const OcrDraft(name: 'Alt 한/영'));
      expect(cells['name']!.verdict, Verdict.wrong);
      expect(cells['name']!.encoded, 'wrong: Alt 한/영');
      expect(cells['name']!.expected, ['HWACHAE BLEND']);
    });

    test('정답 없음 + 비우면 correct', () {
      final cells = score(truth(roaster: null), const OcrDraft());
      expect(cells['roaster']!.verdict, Verdict.correct);
    });

    test('정답 없음 + 채우면 wrong — 지어낸 값', () {
      final cells =
          score(truth(roaster: null), const OcrDraft(roaster: 'KWAMI'));
      expect(cells['roaster']!.verdict, Verdict.wrong);
    });
  });

  group('정답 목록', () {
    test('목록 중 아무 값이나 correct, 목록 밖은 wrong', () {
      final t = truth(name: ['Ethiopia Worka', '에티오피아 웨스트 알시 넨세보 워르카']);
      final cells1 = score(t, const OcrDraft(name: '에티오피아 웨스트 알시 넨세보 워르카'));
      expect(cells1['name']!.verdict, Verdict.correct);
      expect(cells1['name']!.expected, ['Ethiopia Worka', '에티오피아 웨스트 알시 넨세보 워르카']);
      expect(score(t, const OcrDraft(name: 'Ethiopia Worka'))['name']!.verdict,
          Verdict.correct);
      expect(score(t, const OcrDraft(name: '#요거트 #황도'))['name']!.verdict,
          Verdict.wrong);
    });

    test('목록에 null이 있으면 비워도 correct, 없으면 missing', () {
      final optional =
          truth(components: [comp(country: 'Ethiopia', region: [null, '벤치마지'])]);
      final required =
          truth(components: [comp(country: 'Ethiopia', region: ['벤치마지'])]);
      const empty = OcrDraft(components: [OcrComponentDraft(country: 'Ethiopia')]);
      expect(score(optional, empty)['components[0].region']!.verdict,
          Verdict.correct);
      expect(score(required, empty)['components[0].region']!.verdict,
          Verdict.missing);
    });
  });

  group('정규화', () {
    test('공백과 대소문자 차이는 같은 값으로 본다 — OCR 자간 오독', () {
      expect(
          score(truth(roaster: '베이스캠프 로스터스'),
                  const OcrDraft(roaster: '베이스캠프 로스 터스'))['roaster']!
              .verdict,
          Verdict.correct);
      expect(
          score(truth(roaster: 'UNSPECIALTY'),
                  const OcrDraft(roaster: 'Unspecialty'))['roaster']!
              .verdict,
          Verdict.correct);
    });

    test('부분 일치는 받지 않는다', () {
      expect(
          score(truth(roaster: '베이스캠프 로스터스'),
                  const OcrDraft(roaster: '베이스캠프'))['roaster']!
              .verdict,
          Verdict.wrong);
    });
  });

  group('필드별 변환', () {
    test('유형: ambiguous는 빈칸, 반대 유형은 wrong', () {
      final t = truth(type: 'single');
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.certainSingle))[
                  'type']!
              .verdict,
          Verdict.correct);
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.ambiguous))[
                  'type']!
              .verdict,
          Verdict.missing);
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.certainBlend))[
                  'type']!
              .verdict,
          Verdict.wrong);
    });

    test('로스팅 날짜는 날짜만 비교한다', () {
      final t = truth(roastDate: '2026-07-13');
      expect(score(t, OcrDraft(roastDate: DateTime(2026, 7, 13)))['roastDate']!
          .verdict, Verdict.correct);
      expect(
          score(t, OcrDraft(roastDate: DateTime(2026, 7, 13, 9, 30)))[
                  'roastDate']!
              .verdict,
          Verdict.correct);
      expect(score(t, OcrDraft(roastDate: DateTime(2026, 7, 31)))['roastDate']!
          .verdict, Verdict.wrong);
    });

    test('열거형은 이름으로 비교한다', () {
      final t = truth(
        roastLevel: 'lightMedium',
        components: [comp(country: 'Ethiopia', process: 'washed')],
      );
      final cells = score(
        t,
        const OcrDraft(
          roastLevel: RoastLevel.lightMedium,
          components: [
            OcrComponentDraft(country: 'Ethiopia', process: Process.washed),
          ],
        ),
      );
      expect(cells['roastLevel']!.verdict, Verdict.correct);
      expect(cells['components[0].process']!.verdict, Verdict.correct);
    });

    test('비율은 정수로 비교한다', () {
      final t = truth(components: [comp(country: 'Panama', ratioPercent: 10)]);
      expect(
          score(t, const OcrDraft(components: [
            OcrComponentDraft(country: 'Panama', ratioPercent: 10),
          ]))['components[0].ratioPercent']!
              .verdict,
          Verdict.correct);
      expect(
          score(t, const OcrDraft(components: [
            OcrComponentDraft(country: 'Panama', ratioPercent: 109),
          ]))['components[0].ratioPercent']!
              .encoded,
          'wrong: 109');
    });
  });

  group('컵노트 — 노트 하나가 한 칸', () {
    test('순서와 무관하게 맞추고, 빠진 노트는 missing, 지어낸 노트는 wrong', () {
      final cells = score(
        truth(cupNotes: ['자스민', '사과', '귤']),
        const OcrDraft(cupNotes: ['사과', '#자스민', '녹차']),
      );
      expect(cells['cupNotes[사과]']!.verdict, Verdict.correct);
      expect(cells['cupNotes[사과]']!.expected, ['사과']);
      expect(cells['cupNotes[자스민]']!.verdict, Verdict.missing);
      expect(cells['cupNotes[귤]']!.verdict, Verdict.missing);
      expect(cells['cupNotes[+#자스민]']!.verdict, Verdict.wrong);
      expect(cells['cupNotes[+#자스민]']!.expected, isEmpty);
      expect(cells['cupNotes[+녹차]']!.verdict, Verdict.wrong);
      expect(cells.keys.where((key) => key.startsWith('cupNotes')), hasLength(5));
    });

    test('노트 공백·대소문자 차이는 같은 값으로 본다', () {
      final cells = score(
        truth(cupNotes: ['Peach Tea']),
        const OcrDraft(cupNotes: ['PEACH  tea']),
      );
      expect(cells['cupNotes[Peach Tea]']!.verdict, Verdict.correct);
      expect(cells['cupNotes[Peach Tea]']!.expected, ['Peach Tea']);
      expect(cells.keys.where((key) => key.startsWith('cupNotes[+')), isEmpty);
    });
  });

  group('성분 — index로 짝짓기', () {
    test('정답보다 적으면 모자란 성분의 칸이 missing', () {
      final t = truth(type: 'blend', components: [
        comp(country: 'Panama', ratioPercent: 10),
        comp(country: 'Ecuador', ratioPercent: 45),
        comp(country: 'Ethiopia', ratioPercent: 45),
      ]);
      final cells = score(
          t, const OcrDraft(components: [OcrComponentDraft(country: 'Panama')]));
      expect(cells['components[0].country']!.verdict, Verdict.correct);
      expect(cells['components[1].country']!.verdict, Verdict.missing);
      expect(cells['components[2].ratioPercent']!.verdict, Verdict.missing);
      // 정답이 null인 칸은 성분이 통째로 없어도 correct다.
      expect(cells['components[1].region']!.verdict, Verdict.correct);
    });

    test('정답보다 많으면 채운 값마다 wrong, 빈 칸은 칸을 만들지 않는다', () {
      final t = truth(components: [comp(country: 'Ethiopia')]);
      final cells = score(
        t,
        const OcrDraft(components: [
          OcrComponentDraft(country: 'Ethiopia'),
          OcrComponentDraft(country: 'Ethiopia', ratioPercent: 100),
          OcrComponentDraft(region: 'Designed for'),
          OcrComponentDraft(process: Process.washed),
        ]),
      );
      expect(cells['components[1].country']!.encoded, 'wrong: Ethiopia');
      expect(cells['components[1].ratioPercent']!.encoded, 'wrong: 100');
      expect(cells.containsKey('components[1].region'), isFalse);
      expect(cells['components[2].region']!.encoded, 'wrong: Designed for');
      expect(cells.containsKey('components[2].country'), isFalse);
      expect(cells['components[3].process']!.encoded, 'wrong: washed');
      expect(cells.containsKey('components[3].country'), isFalse);
    });

    test('정답보다 많은 성분이 비어 있으면 칸이 하나도 없다', () {
      final t = truth(components: [comp(country: 'Ethiopia')]);
      final cells = score(
        t,
        const OcrDraft(components: [
          OcrComponentDraft(country: 'Ethiopia'),
          OcrComponentDraft(),
        ]),
      );
      expect(cells.keys.where((key) => key.startsWith('components[1]')), isEmpty);
    });
  });

  test('OCR이 한 줄도 못 읽은 빈 초안도 채점된다 — 정답 칸은 missing, wrong은 없다', () {
    final t = truth(
      name: 'Ethiopia Worka',
      cupNotes: ['요거트'],
      components: [comp(country: 'Ethiopia', process: 'natural')],
    );
    final cells = scoreDraft(t, const OcrDraft());
    expect(cells.where((cell) => cell.verdict == Verdict.wrong), isEmpty);
    expect(
      {
        for (final cell in cells)
          if (cell.verdict == Verdict.missing) cell.key,
      },
      {
        'name',
        'type',
        'cupNotes[요거트]',
        'components[0].country',
        'components[0].process',
      },
    );
  });

  group('정답표 형식 검사 — 오타는 영구 wrong으로 숨지 말고 로드에서 실패', () {
    Map<String, Object?> valid() => {
          'id': 't',
          'name': null,
          'roaster': null,
          'roastDate': null,
          'roastLevel': null,
          'type': 'single',
          'cupNotes': <Object?>[],
          'components': <Object?>[],
        };

    test('정상 정답표와 notes는 통과', () {
      expect(() => Truth.fromJson({...valid(), 'notes': '근거'}), returnsNormally);
    });

    test('모르는 키', () {
      expect(() => Truth.fromJson({...valid(), 'roastlevel': 'light'}),
          throwsFormatException);
    });

    test('빠진 키', () {
      expect(() => Truth.fromJson(valid()..remove('type')), throwsFormatException);
    });

    test('성분 모르는 키', () {
      expect(
          () => Truth.fromJson({
                ...valid(),
                'components': [
                  {
                    'country': 'Ethiopia',
                    'region': null,
                    'process': null,
                    'ratioPercent': null,
                    'ratiopercent': 50,
                  }
                ],
              }),
          throwsFormatException);
    });

    test('성분 빠진 키', () {
      expect(
          () => Truth.fromJson({
                ...valid(),
                'components': [
                  {
                    'country': 'Ethiopia',
                    'region': null,
                    'process': null,
                  }
                ],
              }),
          throwsFormatException);
    });

    test('열거형 오타', () {
      expect(() => Truth.fromJson({...valid(), 'roastLevel': 'lightmedium'}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'type': 'blended'}),
          throwsFormatException);
      expect(
          () => Truth.fromJson({
                ...valid(),
                'components': [comp(country: 'Ethiopia', process: 'washd')],
              }),
          throwsFormatException);
    });

    test('날짜 형식', () {
      expect(() => Truth.fromJson({...valid(), 'roastDate': '2026-7-13'}),
          throwsFormatException);
    });

    test('날짜 불가능한 값', () {
      expect(() => Truth.fromJson({...valid(), 'roastDate': '2026-02-30'}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'roastDate': '2026-13-45'}),
          throwsFormatException);
    });

    test('type null이나 빈 목록 불가', () {
      expect(() => Truth.fromJson({...valid(), 'type': null}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'type': []}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'type': [null, 'single']}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'type': ['single', 'blend']}),
          throwsFormatException);
    });

    test('컵노트 중복(정규화 기준)', () {
      expect(
          () => Truth.fromJson({
                ...valid(),
                'cupNotes': ['자스민', '자 스민'],
              }),
          throwsFormatException);
    });

    test('값 자리에 문자열·정수·null 말고 다른 것', () {
      expect(() => Truth.fromJson({...valid(), 'name': true}),
          throwsFormatException);
    });
  });
}
