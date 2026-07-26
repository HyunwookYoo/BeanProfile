# ☕ BeanProfile — OCR 칩 드래그 병합 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-26 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획 대기 |
| 선행 | M3.1 칩 배정 UX `v0.3.1` · M3.3 좌표 파서 `v0.3.3` · 사진 OCR 신뢰성 `v0.6.x` |
| 상위 문서 | [`milestone-3.1-ux-design.md`](milestone-3.1-ux-design.md) · [`photo-ocr-reliability-design.md`](photo-ocr-reliability-design.md) |
| 영향 범위 | `bean_form_screen` · `OcrChipsPanel` (파서·데이터 모델 불변) |

---

## 1. 문제

칩은 OCR이 필드에 자동 배정하지 못한 나머지 텍스트 줄이다(`OcrDraft.chips`, `List<String>`). 칩을 탭하면 "어디에 넣을까요?" 시트가 열리고, 6개 대상 중 **컵노트만 추가(append)**, 나머지 5개는 **교체**다.

실사용에서 두 가지가 섞여 나타난다.

1. **한 값이 여러 칩으로 쪼개진다.** ML Kit은 카드를 줄·열 단위로 끊어 읽으므로 지역 `에티오피아 구지 샤키소`가 칩 3개로 나온다. 교체 배정이라 하나씩 넣으면 **앞의 값이 덮어써져** 조립할 방법이 없다.
2. **여러 조각을 한 칸에 모으고 싶다.** 컵노트는 append라 되지만, 제품명·지역처럼 교체인 칸은 두 번째 칩을 넣는 순간 첫 번째가 사라진다.

두 경우 모두 **칩을 배정하기 전에 합칠 수단**이 없다는 하나의 결핍에서 나온다.

## 2. 확정 결정 (브레인스토밍 2026-07-26)

| # | 결정 | 선택 |
|---|---|---|
| Q1 | 해결할 문제 | 위 1·2 **혼재** — 쪼개진 값 조립 + 조각 누적을 한 수단으로 |
| Q2 | 구분자 | **배정 대상이 결정** — 칩은 조각 목록을 유지하다가, 컵노트엔 `, `로 나머지 칸엔 공백으로 붙는다 |
| Q3 | 병합 순서 | **드래그 방향이 결정** — 떨군 자리의 칩이 앞, 끌어온 칩이 뒤 |
| Q4 | 되돌리기 | **병합 칩의 ✕ 버튼** — 언제든 분해. Undo 스낵바는 두지 않는다 |
| Q5 | 상호작용 | **`LongPressDraggable` + `DragTarget`** (다중선택 버튼 · 시트 '뒤에 붙이기'는 기각) |

### M3.1 Q3(드래그드롭 미지원)과의 관계

M3.1은 드래그드롭을 기각했다. 그 판단은 **칩 → 폼 필드** 드래그를 대상으로 했고, 근거는 "칩은 폼 하단·대상 칸은 상단 → 드래그 중 자동스크롤을 직접 구현해야 하고 터치 정확도·테스트가 취약하다"였다.

**칩 → 칩**은 같은 패널 안에서 일어나 그 근거가 성립하지 않는다. 거리가 짧고 스크롤이 끼어들지 않으며 드롭 대상이 항상 화면에 있다. M3.1의 기각은 **칩 → 필드에 한해 그대로 유효**하며(§6 스코프 밖), 이번 설계는 그 결정을 뒤집지 않는다.

## 3. 설계

### 3.1 데이터 모델 — 칩이 "문자열"에서 "조각 목록"이 된다

구분자를 배정 시점에 정하려면 칩이 자기 조각들을 기억해야 한다. 순수 파일 하나를 새로 만든다(M4 `computeTasteProfile`, M5 `backup_codec`과 같은 결 — Flutter 의존 없는 순수 로직 + 단위 테스트).

```dart
// lib/features/beans/ocr/ocr_chip.dart
class OcrChip {
  const OcrChip(this.parts, {this.used = false});
  final List<String> parts;            // ['에티오피아', '구지'] — 최소 1개
  final bool used;

  bool get isMerged => parts.length > 1;
  String get label => parts.join(' · ');            // 칩에 보이는 글자
  String text({required bool comma}) =>             // 칸에 들어갈 값
      parts.join(comma ? ', ' : ' ');
}

List<OcrChip> mergeChips(List<OcrChip> chips, {required int target, required int source});
List<OcrChip> splitChip(List<OcrChip> chips, int index);
```

- **`mergeChips`** — 떨군 칩(`target`)의 `parts`가 `target.parts + source.parts`가 되고, 끌어온 칩은 목록에서 사라진다. 드래그 방향이 곧 순서다(Q3).
  병합 칩은 `target`이 있던 **순서상 위치**에 남는다. 끌어온 칩이 앞쪽에 있었다면(`source < target`) 그것이 빠지면서 인덱스는 하나 당겨진다 — 눈에 보이는 자리는 그대로다.
- **`splitChip`** — 병합 칩 **자리에** 조각들이 순서대로 펼쳐진다. 원래 위치 복원이 아니다.
  `[샤키소][구지 · 에티오피아][무세공]` → `[샤키소][구지][에티오피아][무세공]`
- 병합 칩에 또 떨구면 조각이 3개가 되고, 병합 칩끼리도 합쳐진다 — 리스트 이어붙이기라 별도 처리가 없다.
- 자기 자신에 떨구기·배정된 칩 관여는 **UI에서 걸러**(§3.2) 순수 함수까지 오지 않는다. 단일 칩 분해도 마찬가지다 — ✕는 병합 칩에만 붙는다. 두 곳에서 막지 않는다.

폼은 `List<OcrChip>` 하나만 상태로 들고, 기존 `_usedChips` Set은 사라진다.

### 3.2 상호작용

각 칩은 **끌 수 있으면서 동시에 받을 수 있는** 위젯이 된다. 폼 본문이 `ListView`(세로 스크롤)라 즉시 시작하는 `Draggable`은 스크롤 제스처와 경합한다 → `LongPressDraggable`을 쓴다. 오조작 방지는 덤이다.

| 상태 | 위젯 | 동작 |
|---|---|---|
| 일반 칩 | `ActionChip` (기존과 동일) | 탭 = 배정 시트 · 길게 눌러 끌기 |
| 병합 칩 | `InputChip` + ✕ | 탭 = 배정 시트 · ✕ = 분해 · 길게 눌러 끌기 |
| 배정된 칩 | 흐림(`oat`) | 탭·드래그·드롭 **전부 불가** |

- 끌리는 동안 원래 자리는 흐려지고(`childWhenDragging`), 손가락엔 떠 있는 칩이 붙는다(`feedback`).
- 드롭 대상 위에 오면 **그 칩만 테두리 강조**. 자기 자신·배정된 칩 위에서는 강조가 뜨지 않는다(`onWillAcceptWithDetails`에서 거름).
- 콜백은 문자열이 아니라 **인덱스**로 주고받는다: `onTap(int)` · `onMerge(int target, int source)` · `onSplit(int)`.
- 힌트 문구: `인식된 텍스트 — 탭하면 어디에 넣을지 물어봐요 · 길게 눌러 다른 칩에 끌면 합쳐져요`

### 3.3 배정 시트 연동

시트 구성(6개 대상·현재 값 부제)은 그대로다. 값을 만드는 한 줄만 바뀐다.

```dart
final (_, ctrl, append) = targets[picked];
final value = chip.text(comma: append);
```

기존 `append` 플래그(컵노트만 `true`)가 **쉼표 여부와 정확히 일치**한다 — 컵노트는 원래 여러 값을 `, `로 모으는 칸이고 나머지 5개는 한 값을 담는 칸이다. 플래그를 새로 만들지 않고 `append` 하나를 그대로 쓴다.

- 시트 제목은 **실제 들어갈 값**을 쓴다: `'에티오피아 구지' 어디에 넣을까요?`
  칩의 `·`는 "합쳐진 칩"이라는 표시일 뿐이라 제목에는 나오지 않는다.
- 배정이 끝나면 그 칩만 `used: true`로 교체한다. 목록에서 지우지 않는다 — 지금처럼 흐려진 채 남아 무엇을 썼는지 보인다.

## 4. 파일 영향

**신규**

- `lib/features/beans/ocr/ocr_chip.dart` — `OcrChip` + `mergeChips` + `splitChip`
- `test/unit/ocr_chip_test.dart`

**수정**

- `lib/features/beans/widgets/ocr_chips_panel.dart` — 드래그·드롭·✕·인덱스 콜백으로 재작성
- `lib/features/beans/bean_form_screen.dart` — `_usedChips` Set → `List<OcrChip>` 상태, `_openAssignSheet(int)`, 병합·분해 핸들러
- `test/widget/ocr_form_test.dart` — 병합 시나리오 추가

**불변**

- OCR 파이프라인·파서 — `OcrDraft.chips`는 계속 `List<String>` 입력이다
- 데이터 모델·저장소·providers·배정 대상 6개

## 5. 테스트 전략 (`docs/testing.md` 3계층)

### 단위 — `test/unit/ocr_chip_test.dart`

- `mergeChips`: 떨군 자리가 앞·끌어온 게 뒤 · 목록 길이가 하나 준다
- **방향 판별**: `merge(target: 0, source: 1)`과 `merge(target: 1, source: 0)`이 **서로 다른 순서**를 내놓는지 — 순서 규칙이 실제로 구현됐는지 가르는 테스트
- 3개 이상 연쇄 병합 · 병합 칩끼리 병합
- `splitChip`: 병합 칩 자리에 순서대로 펼쳐진다
- `text(comma:)`: `'에티오피아 구지'` vs `'자몽, 초콜릿'`

### 위젯 — `test/widget/ocr_form_test.dart`

기존 테스트처럼 `t.view.physicalSize`를 키워 칩 패널을 화면에 올린 뒤:

```dart
Future<void> dragChip(WidgetTester t, String from, String onto) async {
  final g = await t.startGesture(t.getCenter(find.byKey(Key('chip-$from'))));
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await g.moveTo(t.getCenter(find.byKey(Key('chip-$onto'))));
  await t.pump();
  await g.up();
  await t.pumpAndSettle();
}
```

- 드래그 → `chip-에티오피아 · 구지` 렌더 · 원래 칩 2개는 사라진다
- 병합 칩 → 지역 배정 → `field-region-0`이 `'에티오피아 구지'`
- 병합 칩 → 컵노트에 추가 → `'자몽, 초콜릿'`
- ✕ 탭 → 조각 칩 2개로 복귀
- 배정된(흐린) 칩은 드래그해도 병합되지 않는다

### 비회귀

기존 단일 칩 테스트(`Key('chip-Yirgacheffe')`, `t.widget<ActionChip>(...)`)는 **그대로 통과한다**. Key를 라벨 기반으로 유지하고 일반 칩은 계속 `ActionChip`이기 때문이다.

라벨 중복은 구조적으로 불가능하다 — 초기 칩은 `ocr_candidate.dart`에서 중복 제거되고, 병합은 둘을 하나로 줄이며, 분해는 원래 조각으로만 되돌린다. 따라서 같은 라벨의 칩이 둘 생길 수 없다.

## 6. 스코프 밖

- **칩 → 폼 필드** 직접 드래그 (M3.1 Q3 기각 유지 — 자동스크롤 문제 그대로)
- 파서가 좌표를 보고 **자동으로** 병합을 제안하는 것
- 블렌드 2번째+ 구성 필드 배정 (M3.1과 동일하게 첫 구성만)
- 병합 상태 저장 — 폼을 벗어나면 사라진다(지금 칩과 동일)
- 병합 직후 Undo 스낵바 (✕로 대체)

## 7. 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green
- 단위 테스트가 **드래그 방향에 따라 순서가 달라짐**을 판별한다
- 기기에서: 드래그 병합 → 지역·컵노트 배정 → ✕ 분해가 모두 동작한다
- 태스크별 SDD 리뷰 + opus 전체-브랜치 리뷰 통과
