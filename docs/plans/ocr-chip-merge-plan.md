# OCR 칩 드래그 병합 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OCR 칩을 **길게 눌러 다른 칩 위로 끌면 합쳐지고**, 합쳐진 칩의 **✕로 다시 나뉘게** 만든다. 합쳐진 값은 배정 대상에 따라 컵노트엔 `, `로, 나머지 칸엔 공백으로 들어간다.

**Architecture:** 칩을 `String`에서 **조각 목록을 가진 순수 모델 `OcrChip`**으로 바꾼다(구분자를 배정 시점에 정해야 하므로). 병합·분해는 `ocr_chip.dart`의 순수 함수(`mergeChips`/`splitChip`)가 맡고, `OcrChipsPanel`은 각 칩을 `LongPressDraggable` + `DragTarget`으로 감싸 인덱스를 주고받는다. 폼은 `List<OcrChip>` 하나만 상태로 들고 기존 `_usedChips` Set을 버린다.

**Tech Stack:** Flutter · flutter_riverpod · Dart 3 records · flutter_test (드래그는 `TestGesture`).

설계: [`ocr-chip-merge-design.md`](ocr-chip-merge-design.md)

## Global Constraints

- **한국어 UI** · 오프라인/로컬 전용 · 새 패키지 의존성 **0**.
- **데이터 모델·저장소·providers·OCR 파서 변경 없음.** `OcrDraft.chips`는 계속 `List<String>` 입력이다.
- 배정 대상 6개(제품명·로스터리·원산지 국가·지역·컵노트에 추가·메모)와 규칙(컵노트만 append, 나머지 교체)은 **불변**.
- 구분자: 컵노트 = `', '`, 나머지 = `' '`. 칩에 보이는 라벨 = `' · '`. **새 플래그를 만들지 말고 기존 `append` 플래그를 그대로 쓴다.**
- 병합 순서 = 드래그 방향. **떨군 칩(target)이 앞, 끌어온 칩(source)이 뒤.**
- 위젯 Key는 `Key('chip-${chip.label}')`로 유지한다(기존 테스트 호환).
- 커밋 트레일러: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` · `main` 직접 커밋(트렁크).
- 각 태스크 커밋 전 `flutter analyze` 0 + `flutter test` 전체 green.

### 계획이 해소한 설계 모호점

설계 §3.2 표에서 "병합 칩 = ✕ 있음"과 "배정된 칩 = 탭·드래그·드롭 전부 불가"가 **배정된 병합 칩**에서 겹친다. 이 계획은 **배정된 칩이 이긴다**로 정한다 — used 칩은 병합 여부와 무관하게 ✕ 없는 흐린 `ActionChip`이다. 규칙이 하나로 단순해지고("쓴 칩은 더 이상 조작 대상이 아니다"), 비활성 `InputChip`에서 삭제 아이콘이 눌리는지에 대한 프레임워크 의존을 피한다.

---

## File Structure

**신규**

- `lib/features/beans/ocr/ocr_chip.dart` — `OcrChip` 모델 + `mergeChips` + `splitChip`. Flutter 의존 없는 순수 파일(M4 `taste_profile.dart`, M5 `backup_codec.dart`와 같은 자리).
- `test/unit/ocr_chip_test.dart` — 위 순수 로직 단위 테스트.

**수정**

- `lib/features/beans/widgets/ocr_chips_panel.dart` — 드래그·드롭·✕·인덱스 콜백으로 재작성.
- `lib/features/beans/bean_form_screen.dart` — `_usedChips` Set → `List<OcrChip>` 상태, `_openAssignSheet(int)`, 병합·분해 핸들러.
- `test/widget/ocr_form_test.dart` — 병합/분해 시나리오 추가(기존 테스트는 손대지 않는다).

**태스크 분할 근거:** T1은 순수 로직이라 UI 없이 완결된다. T2는 패널 시그니처와 폼 배선이 서로를 요구해 중간 상태가 컴파일되지 않으므로 한 태스크다. T3(✕ 분해·used 잠금)는 T2 위에 얹히는 독립 기능이라 리뷰어가 T2를 승인하면서 T3만 거부할 수 있다.

---

### Task 1: 순수 모델 `OcrChip` + 병합/분해 함수

**Files:**
- Create: `lib/features/beans/ocr/ocr_chip.dart`
- Test: `test/unit/ocr_chip_test.dart`

**Interfaces:**
- Consumes: 없음(순수 Dart).
- Produces: `class OcrChip { const OcrChip(List<String> parts, {bool used = false}); final List<String> parts; final bool used; bool get isMerged; String get label; String text({required bool comma}); }` · `List<OcrChip> mergeChips(List<OcrChip> chips, {required int target, required int source})` · `List<OcrChip> splitChip(List<OcrChip> chips, int index)`

- [ ] **Step 1: 실패 테스트 작성**

`test/unit/ocr_chip_test.dart`를 새로 만든다:

```dart
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
```

- [ ] **Step 2: RED 확인**

Run: `flutter test test/unit/ocr_chip_test.dart`
Expected: 컴파일 실패 — `Error: Couldn't resolve the package ... ocr_chip.dart` / `OcrChip` 미정의.

- [ ] **Step 3: 최소 구현**

`lib/features/beans/ocr/ocr_chip.dart`를 새로 만든다:

```dart
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
```

- [ ] **Step 4: GREEN 확인**

Run: `flutter test test/unit/ocr_chip_test.dart`
Expected: 8개 테스트 전부 PASS.
Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/beans/ocr/ocr_chip.dart test/unit/ocr_chip_test.dart
git commit -m "feat(ocr): model mergeable text chips"
```

---

### Task 2: 드래그로 칩 병합 (패널 재작성 + 폼 배선)

**Files:**
- Modify: `lib/features/beans/widgets/ocr_chips_panel.dart` (전체 교체) · `lib/features/beans/bean_form_screen.dart` (상태 필드 57행 · `initState` 86행 부근 · `_openAssignSheet` 144–187행 · 패널 호출 406–407행 · import 9행 부근)
- Test: `test/widget/ocr_form_test.dart` (테스트 추가만)

**Interfaces:**
- Consumes: Task 1의 `OcrChip` · `mergeChips`.
- Produces: `OcrChipsPanel({required List<OcrChip> chips, required void Function(int index) onTap, required void Function(int target, int source) onMerge})` · 폼 내부 `List<OcrChip> _chips` · `Future<void> _openAssignSheet(int index)` · `void _mergeChips(int target, int source)`

- [ ] **Step 1: 실패 테스트 작성**

`test/widget/ocr_form_test.dart` 맨 위 import 블록에 한 줄 추가한다. `kLongPressTimeout`은 `material.dart`가 재수출하지 않으므로 **명시적으로 import해야 한다**:

```dart
import 'package:flutter/gestures.dart';
```

그리고 `void main() {` **바로 앞**에 드래그 헬퍼를 넣는다:

```dart
/// 칩 `from`을 길게 눌러 집은 뒤 칩 `onto` 위에 떨군다.
Future<void> dragChipOnto(WidgetTester t, String from, String onto) async {
  final gesture = await t.startGesture(t.getCenter(find.byKey(Key('chip-$from'))));
  // LongPressDraggable은 길게 누르는 시간이 지나야 집힌다.
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(t.getCenter(find.byKey(Key('chip-$onto'))));
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
}
```

이어서 `main()` 안 **마지막 테스트 뒤**에 아래 4개 테스트를 추가한다(기존 테스트는 수정하지 않는다):

```dart
  testWidgets('칩을 다른 칩 위로 끌면 하나로 합쳐진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '구지', '에티오피아');

    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsNothing);
  });

  testWidgets('드래그 방향이 병합 순서를 정한다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '에티오피아', '구지'); // 반대 방향

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsNothing);
  });

  testWidgets('병합 칩을 지역에 배정하면 공백으로 이어진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '구지', '에티오피아');
    await t.tap(find.byKey(const Key('chip-에티오피아 · 구지')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    expect(
      t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text,
      '에티오피아 구지',
    );
  });

  testWidgets('병합 칩을 컵노트에 추가하면 쉼표로 이어진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['자몽', '초콜릿'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '초콜릿', '자몽');
    await t.tap(find.byKey(const Key('chip-자몽 · 초콜릿')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-컵노트에 추가')));
    await t.pumpAndSettle();

    expect(find.text('자몽, 초콜릿'), findsOneWidget);
  });
```

- [ ] **Step 2: RED 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 새 4개 FAIL — 드래그해도 아무 일이 없어 `chip-에티오피아 · 구지`가 없다("Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<zero widgets>"). 기존 테스트는 PASS.

- [ ] **Step 3a: `ocr_chips_panel.dart` 전체 교체**

파일 내용을 아래로 통째로 바꾼다:

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../ocr/ocr_chip.dart';

/// 인식된 텍스트 칩. 탭하면 '어디에 넣을지' 배정 시트가 열리고,
/// 길게 눌러 다른 칩 위로 끌면 두 칩이 합쳐진다. 쓴 칩은 흐려짐.
class OcrChipsPanel extends StatelessWidget {
  const OcrChipsPanel({
    super.key,
    required this.chips,
    required this.onTap,
    required this.onMerge,
  });
  final List<OcrChip> chips;
  final void Function(int index) onTap;

  /// 떨군 칩(`target`) 뒤에 끌어온 칩(`source`)을 붙인다.
  final void Function(int target, int source) onMerge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.crema, style: BorderStyle.solid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('인식된 텍스트 — 탭하면 어디에 넣을지 물어봐요 · 길게 눌러 다른 칩에 끌면 합쳐져요',
            style: TextStyle(fontSize: 11, color: c.cremaInk, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < chips.length; i++) _slot(context, i),
        ]),
      ]),
    );
  }

  /// 칩 하나 = 끌 수 있으면서 동시에 받을 수 있는 자리.
  Widget _slot(BuildContext context, int index) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMerge(index, d.data),
      builder: (context, candidate, _) => LongPressDraggable<int>(
        data: index,
        // feedback은 오버레이에 뜨므로 Key를 주지 않는다 — 드래그 중 같은 Key가
        // 둘이 되면 find.byKey가 흔들린다.
        feedback: Material(
          color: Colors.transparent,
          child: _chip(context, index, highlighted: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _chip(context, index, key: _keyOf(index)),
        ),
        child: _chip(context, index,
            key: _keyOf(index), highlighted: candidate.isNotEmpty),
      ),
    );
  }

  Key _keyOf(int index) => Key('chip-${chips[index].label}');

  Widget _chip(BuildContext context, int index, {Key? key, bool highlighted = false}) {
    final c = context.colors;
    final chip = chips[index];
    return ActionChip(
      key: key,
      label: Text(chip.label),
      onPressed: chip.used ? null : () => onTap(index),
      backgroundColor: chip.used ? c.oat : c.crema,
      side: highlighted ? BorderSide(color: c.cremaInk, width: 2) : null,
    );
  }
}
```

- [ ] **Step 3b: `bean_form_screen.dart` — import 추가**

9행 `import 'widgets/ocr_chips_panel.dart';` **위**에 한 줄 넣는다:

```dart
import 'ocr/ocr_chip.dart';
```

- [ ] **Step 3c: 상태 필드 교체**

57행을 교체한다:

```dart
  final _usedChips = <String>{};
```

→

```dart
  final _chips = <OcrChip>[];
```

- [ ] **Step 3d: `initState`에서 칩 초기화**

86행 `final d = widget.draft;` **바로 뒤**에 한 줄 넣는다:

```dart
    final d = widget.draft;
    if (d != null) _chips.addAll(d.chips.map((text) => OcrChip([text])));
```

- [ ] **Step 3e: `_openAssignSheet`를 인덱스 기반으로 교체**

144–187행의 `_openAssignSheet` 메서드 전체를 아래로 바꾼다:

```dart
  Future<void> _openAssignSheet(int index) async {
    final chip = _chips[index];
    // (라벨, 대상 컨트롤러, append 여부) — append는 곧 '쉼표로 이어붙임'이다.
    final targets = <(String, TextEditingController, bool)>[
      ('제품명', _name, false),
      ('로스터리', _roaster, false),
      ('원산지 국가', _components.first.country, false),
      ('지역', _components.first.region, false),
      ('컵노트에 추가', _cupNotes, true),
      ('메모', _memo, false),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              // 칩의 ' · '가 아니라 실제로 들어갈 값을 보여준다.
              child: Text('‘${chip.text(comma: false)}’ 어디에 넣을까요?',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          for (var i = 0; i < targets.length; i++)
            ListTile(
              key: Key('assign-${targets[i].$1}'),
              title: Text(targets[i].$1),
              subtitle: Text(targets[i].$2.text.trim().isEmpty ? '비어있음' : targets[i].$2.text),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    final (_, ctrl, append) = targets[picked];
    final value = chip.text(comma: append);
    setState(() {
      if (append) {
        final cur = ctrl.text.trim();
        ctrl.text = cur.isEmpty ? value : '$cur, $value';
      } else {
        ctrl.text = value;
      }
      _chips[index] = OcrChip(chip.parts, used: true);
    });
  }

  void _mergeChips(int target, int source) => setState(() {
        final next = mergeChips(_chips, target: target, source: source);
        _chips
          ..clear()
          ..addAll(next);
      });
```

- [ ] **Step 3f: 패널 호출 교체**

406–407행을 교체한다:

```dart
          else if (widget.draft!.chips.isNotEmpty)
            OcrChipsPanel(chips: widget.draft!.chips, used: _usedChips, onTap: _openAssignSheet),
```

→

```dart
          else if (_chips.isNotEmpty)
            OcrChipsPanel(chips: _chips, onTap: _openAssignSheet, onMerge: _mergeChips),
```

- [ ] **Step 4: GREEN 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 전부 PASS(기존 + 새 4개). 특히 기존 `'시트에서 지역 선택 → 지역 칸에 채워지고 칩 흐려짐'`의 `t.widget<ActionChip>(...).onPressed, isNull`이 그대로 통과해야 한다(단일 칩은 계속 `ActionChip`).
Run: `flutter analyze`
Expected: No issues found. `_usedChips` 잔여 참조가 하나도 없어야 한다.
Run: `flutter test`
Expected: 전체 green (Windows에서 출력이 중복돼 보이면 `flutter test --concurrency=1 -r expanded`로 확인).

- [ ] **Step 5: Commit**

```bash
git add lib/features/beans/ocr/ocr_chip.dart lib/features/beans/widgets/ocr_chips_panel.dart lib/features/beans/bean_form_screen.dart test/widget/ocr_form_test.dart
git commit -m "feat(ocr): merge chips by dragging"
```

---

### Task 3: ✕로 분해 · 배정된 칩 잠금

**Files:**
- Modify: `lib/features/beans/widgets/ocr_chips_panel.dart` (`onSplit` 추가 · `_slot`/`_chip`) · `lib/features/beans/bean_form_screen.dart` (`_splitChips` 추가 · 패널 호출)
- Test: `test/widget/ocr_form_test.dart` (테스트 추가만)

**Interfaces:**
- Consumes: Task 1의 `splitChip` · Task 2의 `OcrChipsPanel`·`_chips`·`_mergeChips`.
- Produces: `OcrChipsPanel(... required void Function(int index) onSplit)` · 폼 내부 `void _splitChips(int index)`

- [ ] **Step 1: 실패 테스트 작성**

`test/widget/ocr_form_test.dart` 마지막에 3개 테스트를 추가한다:

```dart
  testWidgets('병합 칩의 ✕를 누르면 원래 칩들로 나뉜다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '에티오피아', '구지'); // 일부러 거꾸로: 구지 · 에티오피아
    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsOneWidget);

    await t.tap(find.descendant(
      of: find.byKey(const Key('chip-구지 · 에티오피아')),
      matching: find.byIcon(Icons.close),
    ));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아')), findsOneWidget);
  });

  testWidgets('배정된 칩은 드롭 대상이 되지 않는다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-에티오피아')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    await dragChipOnto(t, '구지', '에티오피아');

    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsOneWidget);
  });

  testWidgets('배정된 칩은 끌 수 없다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-에티오피아')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    await dragChipOnto(t, '에티오피아', '구지'); // 배정된 칩을 끌어본다

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-에티오피아')), findsOneWidget);
  });
```

- [ ] **Step 2: RED 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 3개 FAIL — 병합 칩에 `Icons.close`가 없어 첫 테스트가 "zero widgets"로 실패하고, 배정된 칩이 여전히 드래그·드롭에 반응해 나머지 둘이 실패한다.

- [ ] **Step 3a: 패널에 `onSplit` 추가**

생성자와 필드를 바꾼다:

```dart
  const OcrChipsPanel({
    super.key,
    required this.chips,
    required this.onTap,
    required this.onMerge,
    required this.onSplit,
  });
  final List<OcrChip> chips;
  final void Function(int index) onTap;

  /// 떨군 칩(`target`) 뒤에 끌어온 칩(`source`)을 붙인다.
  final void Function(int target, int source) onMerge;

  /// 병합 칩을 조각들로 되돌린다.
  final void Function(int index) onSplit;
```

- [ ] **Step 3b: 배정된 칩은 드래그·드롭에서 빼기**

`_slot`의 첫 줄에 조기 반환을 넣는다(나머지 본문은 그대로):

```dart
  Widget _slot(BuildContext context, int index) {
    // 배정된 칩은 조작 대상이 아니다 — 끌 수도, 받을 수도 없다.
    if (chips[index].used) return _chip(context, index, key: _keyOf(index));
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMerge(index, d.data),
```

- [ ] **Step 3c: 병합 칩을 ✕ 달린 `InputChip`으로**

`_chip` 전체를 아래로 바꾼다:

```dart
  Widget _chip(BuildContext context, int index, {Key? key, bool highlighted = false}) {
    final c = context.colors;
    final chip = chips[index];
    final border = highlighted ? BorderSide(color: c.cremaInk, width: 2) : null;
    // 배정된 칩은 병합 칩이어도 ✕ 없이 흐린 ActionChip이다(조작 대상 아님).
    if (chip.isMerged && !chip.used) {
      return InputChip(
        key: key,
        label: Text(chip.label),
        onPressed: () => onTap(index),
        backgroundColor: c.crema,
        side: border,
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => onSplit(index),
      );
    }
    return ActionChip(
      key: key,
      label: Text(chip.label),
      onPressed: chip.used ? null : () => onTap(index),
      backgroundColor: chip.used ? c.oat : c.crema,
      side: border,
    );
  }
```

- [ ] **Step 3d: 폼에 분해 핸들러 추가**

`bean_form_screen.dart`의 `_mergeChips` **바로 뒤**에 넣는다:

```dart
  void _splitChips(int index) => setState(() {
        final next = splitChip(_chips, index);
        _chips
          ..clear()
          ..addAll(next);
      });
```

- [ ] **Step 3e: 패널 호출에 `onSplit` 연결**

```dart
          else if (_chips.isNotEmpty)
            OcrChipsPanel(
              chips: _chips,
              onTap: _openAssignSheet,
              onMerge: _mergeChips,
              onSplit: _splitChips,
            ),
```

- [ ] **Step 4: GREEN 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 전부 PASS.
Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: 전체 green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/beans/widgets/ocr_chips_panel.dart lib/features/beans/bean_form_screen.dart test/widget/ocr_form_test.dart
git commit -m "feat(ocr): split merged chips and lock assigned ones"
```

---

## Self-Review (계획 작성자 체크)

**Spec coverage** (`ocr-chip-merge-design.md` 대비)

| 설계 | 태스크 |
|---|---|
| §3.1 `OcrChip`·`mergeChips`·`splitChip` (순서·자리·연쇄) | T1 Step 3 · 테스트 8개 |
| §3.2 `LongPressDraggable`+`DragTarget`·드롭 하이라이트·인덱스 콜백 | T2 Step 3a |
| §3.2 병합 칩 `InputChip`+✕ | T3 Step 3c |
| §3.2 배정된 칩 탭·드래그·드롭 불가 | T3 Step 3b·3c + 테스트 2개 |
| §3.2 힌트 문구 | T2 Step 3a |
| §3.3 `chip.text(comma: append)` · used 표시 · 시트 제목=실제 값 | T2 Step 3e |
| §5 단위 테스트(방향 판별 포함) | T1 Step 1 |
| §5 위젯 테스트 5종 | T2 Step 1(4개) + T3 Step 1(3개) |
| §5 비회귀(기존 테스트 무수정) | T2 Step 4가 명시적으로 확인 |

**Placeholder scan:** TBD/TODO 없음. 모든 코드 단계에 실제 코드가 들어 있다. ✅

**Type consistency:** `OcrChipsPanel.onTap`은 `void Function(int)`이고 폼의 `_openAssignSheet`는 `Future<void> Function(int)` — Dart는 이 할당을 허용한다(M3.1에서 검증된 패턴). `onMerge(int, int)` ↔ `_mergeChips(int, int)`, `onSplit(int)` ↔ `_splitChips(int)` 일치. T1의 `mergeChips(chips, {target, source})` 명명 인자가 T2 `_mergeChips` 본문과 일치. Key `chip-${label}`이 T2·T3 테스트의 `Key('chip-에티오피아 · 구지')`와 일치. ✅

**구현 시 주의**

- **`kLongPressTimeout` import**: `package:flutter/material.dart`는 이 상수를 재수출하지 않는다(M4에서 `listEquals`로 같은 함정을 겪었다). `package:flutter/gestures.dart`를 명시적으로 import한다.
- **드래그가 안 잡히면**: `moveTo` 전에 `await gesture.moveBy(const Offset(0, 8)); await t.pump();`를 한 줄 넣어 본다. `LongPressDraggable`은 지연 시간이 지나면 움직임 없이도 집히지만, 프레임 타이밍에 따라 첫 이동이 필요할 수 있다.
- **뷰포트 확대 필수**: 칩 패널은 폼 하단이라 기본 뷰포트에선 마운트되지 않는다. 모든 새 위젯 테스트가 `t.view.physicalSize = Size(2400, 4000)` + `devicePixelRatio = 3.0` + `addTearDown(t.view.reset)`을 쓴다(기존 테스트와 동일).
- **`ActionChip.side`/`InputChip.side`**: `null`을 넘기면 테마 기본값이라 평소 모양이 유지된다.
- T2에서 배정된 칩도 잠시 끌 수 있는 상태로 남는다(T3에서 잠근다). 의도된 중간 상태다.
