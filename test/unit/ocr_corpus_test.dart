// OCR 코퍼스 회귀 게이트. 카드마다 기록된 ML Kit 출력을 실제 파이프라인에
// 태우고, 사진에서 쓴 정답표와 칸 단위로 대조해 베이스라인과 비교한다.
// 설계: docs/plans/ocr-corpus-design.md
//
// 베이스라인 갱신(의도한 변화일 때만):
//   flutter test --dart-define=UPDATE_OCR_BASELINE=true test/unit/ocr_corpus_test.dart
// 갱신하면 리포트가 출력된다. baseline.json diff를 같은 커밋에 남긴다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/ocr_corpus.dart';
import '../support/ocr_score.dart';

const _update = bool.fromEnvironment('UPDATE_OCR_BASELINE');
final _dir = Directory('test/fixtures/ocr_corpus');

void main() {
  test('코퍼스 채점이 베이스라인과 칸 단위로 같다', () async {
    final cards = loadCorpus(_dir);
    expect(cards, isNotEmpty, reason: '코퍼스가 비었다 — ${_dir.absolute.path}');
    final scored = {
      for (final card in cards)
        card.id: scoreDraft(card.truth, await replayPipeline(card.fixture)),
    };
    final current = toBaseline(scored);
    final file = File('${_dir.path}/baseline.json');

    if (_update) {
      file.writeAsStringSync(encodeBaseline(current));
      // ignore: avoid_print
      print(corpusReport(cards, scored));
      return;
    }

    expect(file.existsSync(), isTrue,
        reason: '베이스라인이 없다 — --dart-define=UPDATE_OCR_BASELINE=true 로 만든다');
    final changed = diffBaseline(decodeBaseline(file.readAsStringSync()), current);
    expect(changed, isEmpty,
        reason: '채점이 바뀐 칸 ${changed.length}개:\n${changed.join('\n')}\n\n'
            '의도한 변화면 --dart-define=UPDATE_OCR_BASELINE=true 로 갱신하고 '
            'baseline.json diff를 커밋에 남긴다.');
  });

  test('이관한 실측 픽스처가 test/helpers.dart 원본과 같다', () {
    // 두 카드는 원본 사진이 없어 이 좌표가 유일본이다. 한쪽만 고쳐지면 안 된다.
    for (final (id, lines) in [
      ('red_cascara', redCascaraLines),
      ('hwachae', hwachaeLines),
    ]) {
      final fixture = CorpusFixture.fromJson(jsonDecode(
              File('${_dir.path}/$id.ocr.json').readAsStringSync())
          as Map<String, Object?>);
      expect(
        [
          for (final line in fixture.original)
            [line.text, line.left, line.top, line.right, line.bottom],
        ],
        [
          for (final line in lines)
            [line.text, line.left, line.top, line.right, line.bottom],
        ],
        reason: id,
      );
    }
  });
}
