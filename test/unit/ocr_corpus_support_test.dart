import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ocr_corpus.dart';
import '../support/ocr_score.dart';

// 같은 높이·같은 열의 콜론 라벨 줄 — 타이포그래피 경로를 타지 않고 라벨로만 읽힌다.
Map<String, Object?> _row(String text, int index) => {
      'text': text,
      'l': 10,
      't': index * 40,
      'r': 400,
      'b': index * 40 + 30,
      'conf': null,
    };

CorpusFixture fixture({
  required List<String> original,
  List<String>? enhanced,
  List<String>? quality,
}) =>
    CorpusFixture.fromJson({
      'id': 'f',
      'source': 'test',
      'quality': quality,
      'original': [for (final (i, text) in original.indexed) _row(text, i)],
      'enhanced': enhanced == null
          ? null
          : [for (final (i, text) in enhanced.indexed) _row(text, i)],
    });

// 계획 단계 실측(2026-10-03): strong은 약하지 않고(isWeakOcr false), weak는
// 제품명이 없어 약하다.
const strong = ['제품명: 테스트 원두', '원산지: 에티오피아', '가공: 워시드', '로스팅: 미디엄'];
const strongPlusRoaster = [...strong, '로스터리: 보정 로스터'];
const weak = ['원산지: 에티오피아', '가공: 워시드', '로스팅: 미디엄', '고도: 1,800m'];
const weakPlusName = ['제품명: 보정 원두', ...weak];

void main() {
  group('파이프라인 재생', () {
    test('원본이 약하지 않고 품질 문제도 없으면 보정 패스를 보지 않는다', () async {
      final draft = await replayPipeline(
          fixture(original: strong, enhanced: strongPlusRoaster, quality: []));
      expect(draft.name, '테스트 원두');
      expect(draft.roaster, isNull);
    });

    test('저대비면 원본이 멀쩡해도 보정 패스를 본다', () async {
      final draft = await replayPipeline(fixture(
          original: strong,
          enhanced: strongPlusRoaster,
          quality: ['lowContrast']));
      expect(draft.roaster, '보정 로스터');
    });

    test('원본이 약하면 보정 패스로 메운다', () async {
      final draft = await replayPipeline(
          fixture(original: weak, enhanced: weakPlusName, quality: []));
      expect(draft.name, '보정 원두');
    });

    test('보정 패스 기록이 없으면 기기에서 보정이 실패한 것처럼 원본만 쓴다', () async {
      final draft = await replayPipeline(fixture(original: weak, quality: []));
      expect(draft.name, isNull);
      expect(draft.components.single.country, 'Ethiopia');
    });

    test('품질 기록이 없으면 빈 보고서로 재생한다', () async {
      final draft = await replayPipeline(
          fixture(original: strong, enhanced: strongPlusRoaster));
      expect(draft.roaster, isNull);
    });

    test('OCR이 한 줄도 못 읽은 픽스처도 재생된다', () async {
      final draft = await replayPipeline(
          fixture(original: const [], enhanced: const [], quality: []));
      expect(draft.isEmpty, isTrue);
    });
  });

  // 파이프라인에 새 이미지(크롭·회전·세 번째 패스)가 생기면 원본 기록을 대신
  // 먹이지 말고 실패해야 한다. 실제 파이프라인은 품질 분석과 보정 구간의 예외를
  // 삼키므로, 안쪽 expectLater가 그 삼킴을 흉내 낸다 — seam이 거절하고(안쪽),
  // 거절이 삼켜져도 재생은 실패한다(바깥). 보정 패스가 있는 픽스처를 쓴다: 없으면
  // 보정 쪽 거절의 throw만 지워도 "기록 없음" StateError가 그 자리를 채워 안쪽
  // 단언이 통과한다(실측: 변이가 살아남는다).
  group('기록에 없는 이미지는 원본을 대신 먹이지 않고 실패한다', () {
    final f = fixture(original: strong, enhanced: strongPlusRoaster, quality: []);

    test('OCR', () async {
      await expectLater(
        withReplaySeams(f, (ocr, qualityAnalyzer, preprocessor) async {
          await expectLater(ocr.recognize('corpus/crop'), throwsStateError);
          return const OcrDraft();
        }),
        throwsStateError,
      );
    });

    test('품질 분석', () async {
      await expectLater(
        withReplaySeams(f, (ocr, qualityAnalyzer, preprocessor) async {
          await expectLater(
              qualityAnalyzer.analyze('corpus/crop'), throwsStateError);
          return const OcrDraft();
        }),
        throwsStateError,
      );
    });

    test('보정', () async {
      await expectLater(
        withReplaySeams(f, (ocr, qualityAnalyzer, preprocessor) async {
          await expectLater(
              preprocessor.enhance('corpus/crop'), throwsStateError);
          return const OcrDraft();
        }),
        throwsStateError,
      );
    });
  });

  group('픽스처 형식', () {
    test('좌표·confidence·품질을 그대로 읽는다', () {
      final f = CorpusFixture.fromJson({
        'id': 'x',
        'source': 's',
        'quality': ['blurry', 'strongHighlights'],
        'original': [
          {'text': 'RED CASCARA', 'l': 1137, 't': 511.5, 'r': 2303, 'b': 610, 'conf': 0.91},
        ],
        'enhanced': null,
      });
      final line = f.original.single;
      expect(
        [line.text, line.left, line.top, line.right, line.bottom, line.confidence],
        ['RED CASCARA', 1137.0, 511.5, 2303.0, 610.0, 0.91],
      );
      expect(f.quality,
          {ImageQualityIssue.blurry, ImageQualityIssue.strongHighlights});
      expect(f.enhanced, isNull);
    });

    test('키가 빠지면 실패한다', () {
      expect(
          () => CorpusFixture.fromJson(
              {'id': 'x', 'source': 's', 'quality': null, 'original': []}),
          throwsFormatException);
    });
  });

  group('코퍼스 폴더 읽기', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ocr_corpus_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String name, String body) =>
        File('${dir.path}/$name').writeAsStringSync(body);
    const ocr =
        '{"id": "a", "source": "s", "quality": [], "original": [], "enhanced": null}';
    const truth = '{"id": "a", "name": null, "roaster": null, "roastDate": null, '
        '"roastLevel": null, "type": "single", "cupNotes": [], "components": []}';
    String ocr_(String id) =>
        '{"id": "$id", "source": "s", "quality": [], "original": [], "enhanced": null}';
    String truth_(String id) =>
        '{"id": "$id", "name": null, "roaster": null, "roastDate": null, '
        '"roastLevel": null, "type": "single", "cupNotes": [], "components": []}';

    test('픽스처와 정답표를 id로 짝짓고 다른 파일은 무시한다', () {
      write('a.ocr.json', ocr);
      write('a.truth.json', truth);
      write('baseline.json', '{}');
      write('sources.json', '{}');
      expect(loadCorpus(dir).map((card) => card.id), ['a']);
    });

    test('짝 없는 파일이 있으면 실패한다', () {
      write('a.ocr.json', ocr);
      expect(() => loadCorpus(dir), throwsStateError);
    });

    test('파일 이름과 id가 다르면 실패한다', () {
      write('b.ocr.json', ocr);
      write('b.truth.json', truth.replaceFirst('"a"', '"b"'));
      expect(() => loadCorpus(dir), throwsFormatException);
    });

    test('폴더가 없으면 0장으로 조용히 넘어가지 않고 실패한다', () {
      expect(() => loadCorpus(Directory('${dir.path}/없음')), throwsStateError);
    });

    test('정답표만 있고 픽스처가 없으면 실패한다', () {
      write('a.truth.json', truth_('a'));
      expect(() => loadCorpus(dir), throwsStateError);
    });

    test('정답표 id가 파일 이름과 다르면 실패한다', () {
      write('b.ocr.json', ocr_('b'));
      write('b.truth.json', truth_('a'));
      expect(() => loadCorpus(dir), throwsFormatException);
    });

    test('문법이 깨진 JSON은 파일 경로와 함께 FormatException', () {
      write('a.ocr.json', '{not json');
      write('a.truth.json', truth_('a'));
      expect(
        () => loadCorpus(dir),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('a.ocr.json'))),
      );
    });

    test('모양이 틀린 JSON도 FormatException', () {
      write(
          'a.ocr.json',
          '{"id": "a", "source": "s", "quality": ["lowcontrast"], '
              '"original": [], "enhanced": null}');
      write('a.truth.json', truth_('a'));
      expect(() => loadCorpus(dir), throwsFormatException);
    });

    test('최상위가 객체가 아니어도 FormatException', () {
      write('a.ocr.json', '[]');
      write('a.truth.json', truth_('a'));
      expect(() => loadCorpus(dir), throwsFormatException);
    });
  });

  group('베이스라인', () {
    test('정렬된 JSON으로 쓰고 그대로 읽는다', () {
      const baseline = {
        'b': {'name': 'correct'},
        'a': {'roaster': 'wrong: KWAMI', 'name': 'missing'},
      };
      final text = encodeBaseline(baseline);
      expect(text.indexOf('"a"'), lessThan(text.indexOf('"b"')));
      expect(text.indexOf('"name"'), lessThan(text.indexOf('"roaster"')));
      expect(decodeBaseline(text), baseline);
    });

    test('바뀐 칸만 보고한다 — 한 칸 고치고 한 칸 깨도 상쇄되지 않는다', () {
      const before = {
        'hwachae': {
          'name': 'missing',
          'roaster': 'correct',
          'components[2].region': 'wrong: avour berry bomb tropicalfruits',
        },
      };
      const after = {
        'hwachae': {
          'name': 'correct',
          'roaster': 'missing',
          'components[2].region': 'wrong: Designed for',
        },
      };
      expect(diffBaseline(before, after), [
        'hwachae  components[2].region  wrong: avour berry bomb tropicalfruits → wrong: Designed for',
        'hwachae  name  missing → correct',
        'hwachae  roaster  correct → missing',
      ]);
    });

    test('생기거나 사라진 카드·칸도 보고한다', () {
      expect(
        diffBaseline(
          const {'a': {'name': 'correct'}},
          const {'b': {'name': 'correct'}},
        ),
        ['a  name  correct → (없음)', 'b  name  (없음) → correct'],
      );
    });

    test('같으면 빈 목록', () {
      expect(
        diffBaseline(
          const {'a': {'name': 'correct'}},
          const {'a': {'name': 'correct'}},
        ),
        isEmpty,
      );
    });
  });

  test('줄 순서를 그대로 둔다 — 정렬·역순 모두 잡는다', () {
    final f = CorpusFixture.fromJson({
      'id': 'x',
      'source': 's',
      'quality': null,
      'original': [
        {'text': 'second-above', 'l': 0, 't': 100, 'r': 10, 'b': 110, 'conf': null},
        {'text': 'first-below', 'l': 0, 't': 200, 'r': 10, 'b': 210, 'conf': null},
        {'text': 'third-top', 'l': 0, 't': 0, 'r': 10, 'b': 10, 'conf': null},
      ],
      'enhanced': [
        {'text': 'e-second', 'l': 0, 't': 100, 'r': 10, 'b': 110, 'conf': null},
        {'text': 'e-first', 'l': 0, 't': 200, 'r': 10, 'b': 210, 'conf': null},
        {'text': 'e-third', 'l': 0, 't': 0, 'r': 10, 'b': 10, 'conf': null},
      ],
    });
    expect(f.original.map((line) => line.text),
        ['second-above', 'first-below', 'third-top']);
    expect(f.enhanced!.map((line) => line.text),
        ['e-second', 'e-first', 'e-third']);
  });

  test('toBaseline은 카드 → 칸 → 인코딩된 판정으로 옮긴다', () {
    expect(
      toBaseline({
        'a': [
          const Cell('name', Verdict.correct, 'X', ['X']),
          const Cell('roaster', Verdict.wrong, 'Y', ['Z']),
          const Cell('roastDate', Verdict.missing, null, ['2026-01-01']),
        ],
      }),
      {
        'a': {
          'name': 'correct',
          'roaster': 'wrong: Y',
          'roastDate': 'missing',
        },
      },
    );
  });

  group('원인 구분 (근사 — 설계 §4.2)', () {
    final ocrText = normalize(
        'Oromia, West Guji Hambella Wamena, Danse Saysa Tacet Coffee Roasters');

    test('정답 단어가 OCR에 다 있으면 파서 문제', () {
      const cell =
          Cell('roaster', Verdict.missing, null, ['Tacet Coffee Roasters']);
      expect(causeOf(cell, ocrText), Cause.parser);
    });

    test('한 값이 두 줄로 쪼개지고 순서가 바뀌어도 단어로 본다', () {
      final text = normalize('Hambella Wamena, Danse Saysa\nOromia, West Guji');
      const cell = Cell('components[0].region', Verdict.wrong,
          'Oromia, West Guji', ['Oromia, West Guji Hambella Wamena, Danse Saysa']);
      expect(causeOf(cell, text), Cause.parser);
    });

    test('정답 단어가 OCR에 없으면 OCR 문제', () {
      const cell = Cell('roaster', Verdict.wrong, 'a Cotee Roastery',
          ['One Half Coffee Roastery']);
      expect(causeOf(cell, normalize('a Cotee Roastery Roasted in Malaysia')),
          Cause.ocr);
    });

    test('정답이 없는 칸을 채웠으면 파서 문제', () {
      const cell = Cell('cupNotes[+열대과일]', Verdict.wrong, '열대과일', []);
      expect(causeOf(cell, ocrText), Cause.parser);
    });

    test('열거형·국가·날짜·비율은 가리지 않는다', () {
      for (final key in [
        'type',
        'roastLevel',
        'roastDate',
        'components[0].country',
        'components[0].process',
        'components[0].ratioPercent',
      ]) {
        expect(causeOf(Cell(key, Verdict.missing, null, const ['x']), ocrText),
            Cause.unclassified,
            reason: key);
      }
    });

    test('정답의 구두점은 무시한다', () {
      const cell = Cell('components[0].region', Verdict.missing, null,
          ['Oromia, West Guji']);
      expect(causeOf(cell, normalize('Oromia West Guji')), Cause.parser);
    });

    test('OCR 텍스트도 구두점을 제거한 후 일치를 본다', () {
      const cell = Cell('cupNotes[x]', Verdict.missing, null,
          ['Stronghold S7X Ver.2']);
      expect(causeOf(cell, normalize('Stronghold S7X Ver.2')), Cause.parser);
    });

    test('하이픈도 구두점처럼 무시한다', () {
      const cell = Cell('components[0].region', Verdict.missing, null,
          ['Oromia - West Guji']);
      expect(causeOf(cell, normalize('Oromia West Guji')), Cause.parser);
    });

    test('숫자는 보존되어 같은 단어가 아니다', () {
      const cell =
          Cell('cupNotes[x]', Verdict.missing, null, ['Grade 1']);
      expect(causeOf(cell, normalize('Grade 2')), Cause.ocr);
    });
  });

  test('리포트는 카드별·합계 개수, 원인별 개수, 문제 칸 목록을 낸다', () async {
    final card = CorpusCard(
      fixture(original: strong, quality: []),
      Truth.fromJson({
        'id': 'f',
        'name': '테스트 원두',
        'roaster': '없는 로스터',
        'roastDate': null,
        'roastLevel': 'medium',
        'type': 'single',
        'cupNotes': <Object?>[],
        'components': [
          {'country': 'Ethiopia', 'region': null, 'process': 'washed', 'ratioPercent': null},
        ],
      }),
    );
    final scored = {
      'f': scoreDraft(card.truth, await replayPipeline(card.fixture)),
    };
    final report = corpusReport([card], scored);
    // 채움 정답 4(name·roastLevel·country·process), 비움 정답 3(roastDate·
    // region·ratioPercent), 빈칸 2(roaster·type — strong은 유형이 ambiguous).
    expect(report, contains('1장, 칸 9개'));
    expect(report, contains('  f  정답 7 (채움 4 / 비움 3)  빈칸 2  틀림 0'));
    expect(report, contains('합계  정답 7 (채움 4 / 비움 3)  빈칸 2  틀림 0'));
    expect(report, contains('  파서 0칸'));
    expect(report, contains('  OCR 1칸'));
    expect(report, contains('  미분류 1칸'));
    expect(report, contains('  f  roaster  missing  [OCR]'));
    expect(report, contains('  f  type  missing  [미분류]'));
  });

  group('원인 구분 — 보강', () {
    test('제품명 칸도 단어로 가린다', () {
      const cell = Cell('name', Verdict.missing, null, ['HWACHAE BLEND']);
      expect(causeOf(cell, normalize('HWACHAE BLEND Designed for')), Cause.parser);
      expect(causeOf(cell, normalize('Designed for')), Cause.ocr);
    });
    test('받아주는 값이 여럿이면 하나만 읽혀도 파서 문제다', () {
      const cell = Cell('name', Verdict.missing, null, ['레드 카스카라', 'RED CASCARA']);
      expect(causeOf(cell, normalize('레드 카스카라')), Cause.parser);
      expect(causeOf(cell, normalize('RED CASCARA')), Cause.parser);
      expect(causeOf(cell, normalize('다른 글자')), Cause.ocr);
    });
  });
  Truth truthOf(Map<String, Object?> over) => Truth.fromJson({
        'id': 'f', 'name': '테스트 원두', 'roaster': null, 'roastDate': null,
        'roastLevel': 'medium', 'type': 'single', 'cupNotes': <Object?>[],
        'components': <Object?>[], ...over,
      });
  test('리포트는 보정본 텍스트도 OCR 텍스트로 본다', () async {
    final card = CorpusCard(
      fixture(original: strong, enhanced: strongPlusRoaster, quality: []),
      truthOf({'roaster': '보정 로스터'}),
    );
    final scored = {'f': scoreDraft(card.truth, await replayPipeline(card.fixture))};
    expect(corpusReport([card], scored), contains('  f  roaster  missing  [파서]'));
  });
  test('틀린 칸과 파서 원인도 리포트에 센다', () async {
    final card = CorpusCard(
      fixture(original: strong, quality: []),
      truthOf({'name': null, 'components': [
        {'country': 'Ethiopia', 'region': null, 'process': 'washed', 'ratioPercent': null},
      ]}),
    );
    final scored = {'f': scoreDraft(card.truth, await replayPipeline(card.fixture))};
    final report = corpusReport([card], scored);
    expect(report, contains('  f  정답 7 (채움 3 / 비움 4)  빈칸 1  틀림 1'));
    expect(report, contains('합계  정답 7 (채움 3 / 비움 4)  빈칸 1  틀림 1'));
    expect(report, contains('  파서 1칸'));
    expect(report, contains('  f  name  wrong: 테스트 원두  [파서]'));
  });
}
