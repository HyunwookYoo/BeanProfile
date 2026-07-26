/// 배정 대기 중인 OCR 텍스트 칩.
///
/// 여러 칩을 합치면 조각(`parts`)이 드래그한 순서대로 쌓인다. 칸에 넣을 때의
/// 구분자는 **배정 대상**이 정한다 — 컵노트는 쉼표, 나머지 칸은 공백.
class OcrChip {
  const OcrChip(this.parts, {this.used = false});

  /// 조각들. 최소 1개. 합쳐진 칩만 2개 이상이다.
  final List<String> parts;

  /// 이미 어느 칸에 배정된 칩(패널에서 흐려진다).
  final bool used;

  bool get isMerged => parts.length > 1;

  /// 칩에 보이는 글자. `·`는 "합쳐진 칩"이라는 표시일 뿐 실제 값이 아니다.
  String get label => parts.join(' · ');

  /// 칸에 실제로 들어갈 값.
  String text({required bool comma}) => parts.join(comma ? ', ' : ' ');
}

/// `source` 칩을 `target` 칩 뒤에 이어붙인다 — 드래그 방향이 곧 순서다.
///
/// 병합 칩은 `target`이 있던 순서상 위치에 남고 `source`는 목록에서 사라진다.
/// 자기 자신에 떨구는 경우(`target == source`)는 패널이 걸러 여기까지 오지 않는다.
/// 이미 배정된(`used: true`) 칩도 마찬가지로 패널이 걸러낸다 — 여기 오면 1-인자
/// 생성자 탓에 `used`가 `false`로 되살아난다.
List<OcrChip> mergeChips(
  List<OcrChip> chips, {
  required int target,
  required int source,
}) {
  final next = [...chips];
  // target에 먼저 쓰고 나서 source를 지운다 — 순서를 바꾸면 인덱스가 어긋난다.
  next[target] = OcrChip([...chips[target].parts, ...chips[source].parts]);
  next.removeAt(source);
  return next;
}

/// 병합 칩을 그 자리에서 조각 칩들로 펼친다(원래 위치 복원이 아니다).
List<OcrChip> splitChip(List<OcrChip> chips, int index) => [
      ...chips.take(index),
      for (final part in chips[index].parts) OcrChip([part]),
      ...chips.skip(index + 1),
    ];
