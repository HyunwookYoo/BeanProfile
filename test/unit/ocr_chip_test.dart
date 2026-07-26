import 'package:beanprofile/features/beans/ocr/ocr_chip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> labels(List<OcrChip> chips) => chips.map((c) => c.label).toList();

  test('병합은 떨군 칩 뒤에 끌어온 칩을 붙인다', () {
    const chips = [OcrChip(['에티오피아']), OcrChip(['구지'])];
    expect(labels(mergeChips(chips, target: 0, source: 1)), ['에티오피아 · 구지']);
  });

  test('드래그 방향이 병합 순서를 뒤집는다', () {
    const chips = [OcrChip(['에티오피아']), OcrChip(['구지'])];
    expect(mergeChips(chips, target: 0, source: 1).single.parts, ['에티오피아', '구지']);
    expect(mergeChips(chips, target: 1, source: 0).single.parts, ['구지', '에티오피아']);
  });

  test('앞쪽 칩을 끌어와도 병합 칩은 보이던 자리에 남는다', () {
    const chips = [OcrChip(['샤키소']), OcrChip(['에티오피아']), OcrChip(['구지'])];
    // 0번(샤키소)을 2번(구지) 위로 끌면, 앞이 빠지면서 인덱스는 당겨진다.
    expect(labels(mergeChips(chips, target: 2, source: 0)), ['에티오피아', '구지 · 샤키소']);
  });

  test('병합 칩에 또 떨구면 조각이 쌓인다', () {
    var chips = const [OcrChip(['에티오피아']), OcrChip(['구지']), OcrChip(['샤키소'])];
    chips = mergeChips(chips, target: 0, source: 1);
    chips = mergeChips(chips, target: 0, source: 1);
    expect(chips.single.parts, ['에티오피아', '구지', '샤키소']);
  });

  test('병합 칩끼리도 합쳐진다', () {
    var chips = const [
      OcrChip(['에티오피아']), OcrChip(['구지']), OcrChip(['샤키소']), OcrChip(['G1']),
    ];
    chips = mergeChips(chips, target: 0, source: 1); // [에티오피아·구지][샤키소][G1]
    chips = mergeChips(chips, target: 1, source: 2); // [에티오피아·구지][샤키소·G1]
    chips = mergeChips(chips, target: 0, source: 1);
    expect(chips.single.parts, ['에티오피아', '구지', '샤키소', 'G1']);
  });

  test('분해는 병합 칩 자리에 조각을 순서대로 펼친다', () {
    const chips = [
      OcrChip(['샤키소']), OcrChip(['구지', '에티오피아']), OcrChip(['무세']),
    ];
    expect(labels(splitChip(chips, 1)), ['샤키소', '구지', '에티오피아', '무세']);
  });

  test('분해된 조각은 배정 전 상태로 돌아온다', () {
    const chips = [OcrChip(['구지', '에티오피아'], used: true)];
    expect(splitChip(chips, 0).every((c) => !c.used), isTrue);
  });

  test('구분자는 배정 대상이 정한다', () {
    const chip = OcrChip(['자몽', '초콜릿']);
    expect(chip.text(comma: false), '자몽 초콜릿');
    expect(chip.text(comma: true), '자몽, 초콜릿');
    expect(chip.label, '자몽 · 초콜릿');
    expect(chip.isMerged, isTrue);
    expect(const OcrChip(['자몽']).isMerged, isFalse);
  });
}
