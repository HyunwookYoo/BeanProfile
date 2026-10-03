import 'dart:io';

import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ocr_corpus.dart';

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
}
