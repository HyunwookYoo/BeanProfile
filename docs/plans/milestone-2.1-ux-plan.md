# M2.1 UX 개선 구현 계획 — 키보드·스와이프 삭제

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 텍스트 필드 키보드를 탭/스크롤로 내리고, 시음·원두 카드를 스와이프로 삭제한다(시음=Undo, 원두=확인).

**Architecture:** 거의 순수 UI. `deleteTasting`/`deleteBean`은 M2에 이미 있음. 폼 body를 `GestureDetector`+`keyboardDismissBehavior`로 감싸고, 리스트/시음 행을 `Dismissible`로 감싼다. 반응형 스트림 리스트와의 충돌을 피하려 **`confirmDismiss`에서 삭제 후 `false`를 반환**(반응형 리빌드가 항목을 제거)한다.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2 · drift 2.31.0 · flutter_riverpod 3.3.2

**참조:** 설계 [`milestone-2.1-ux-design.md`](milestone-2.1-ux-design.md) · 목업 [`../mockups/m2-ux-improvements.html`](../mockups/m2-ux-improvements.html) · 테스트 규약 [`../testing.md`](../testing.md)

## Global Constraints

- **한국어 UI 문자열.** 오프라인·로컬 전용, 네트워크 없음.
- **Dismissible + 반응형 스트림 리스트:** `confirmDismiss`에서 실제 삭제를 수행하고 **항상 `false`를 반환**한다. 이러면 Dismissible이 "dismissed, 트리에 남음" 상태로 진입하지 않고, drift 스트림 재방출이 항목을 제거한다(assert 회피, 로컬 리스트 불필요).
- **drift 스트림을 watch하는 위젯 테스트:** teardown 전에 `await db.close();`. 스트림이 활성인 채로 close하면 취소되므로, 마지막에 `await tester.pump(const Duration(milliseconds: 300));` 후 `db.close()`. `addTearDown(db.close)`는 안전망.
- **main 직접 커밋(트렁크).** 커밋 메시지 끝에 빈 줄 뒤:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
- 커밋 전 `flutter analyze` 0 issues + `flutter test` 전체 green. 새 테스트는 `test/helpers.dart` 사용. TDD.
- **`.superpowers/sdd/progress.md`는 컨트롤러 소유** — 구현자는 편집하지 말 것. 자기 리포트 파일만 작성.

---

## 파일 구조

**신규**
- `lib/features/beans/widgets/delete_ux.dart` — `SwipeDeleteBackground` 위젯(공용 빨간 삭제 배경) + `confirmDeleteBeanDialog(context)` 함수(원두 삭제 확인, 상세·리스트 공용).
- 테스트: `test/widget/keyboard_dismiss_test.dart` · `test/widget/tasting_swipe_test.dart` · `test/widget/bean_swipe_test.dart`

**수정**
- `lib/features/tasting/tasting_form_screen.dart` — 키보드 dismiss (T1)
- `lib/features/beans/bean_form_screen.dart` — 키보드 dismiss (T1)
- `lib/data/models.dart` — `TastingInput.fromTasting` 팩토리 (T2)
- `lib/features/beans/bean_detail_screen.dart` — `_tastingRow` Dismissible + Undo (T2), `_confirmDeleteBean`가 공용 다이얼로그 사용 (T3)
- `lib/features/beans/bean_list_screen.dart` — `BeanCard` Dismissible + 확인 (T3)

---

## Task 1: 키보드 내리기 (두 폼)

**Files:**
- Modify: `lib/features/tasting/tasting_form_screen.dart`
- Modify: `lib/features/beans/bean_form_screen.dart`
- Create: `test/widget/keyboard_dismiss_test.dart`

**Interfaces:**
- Consumes: `wrapApp`/`testDatabase`/`testRepository`/`sampleSingle` (helpers), `FocusScope`/`GestureDetector` (Flutter).
- Produces: 두 폼 body가 빈 곳 탭 + 스크롤로 키보드를 내림. 새 public API 없음.

- [ ] **Step 1: 실패 테스트 작성** — `test/widget/keyboard_dismiss_test.dart`

포커스가 텍스트 필드에 있는지 판정하는 헬퍼로, 빈 곳(비상호작용 라벨) 탭 시 포커스가 풀리는지 검증한다.

```dart
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

bool _textFieldFocused() {
  final f = FocusManager.instance.primaryFocus;
  return f != null && f.context?.widget is EditableText;
}

void main() {
  testWidgets('tasting form: tapping empty area dismisses the keyboard', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(wrapApp(const TastingFormScreen(beanId: 1), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first); // focus the comment field
    await tester.pump();
    expect(_textFieldFocused(), isTrue);

    await tester.tap(find.text('강도')); // non-interactive label → translucent GestureDetector
    await tester.pump();
    expect(_textFieldFocused(), isFalse);
  });

  testWidgets('bean form: tapping empty area dismisses the keyboard', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(wrapApp(const BeanFormScreen(), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field-name')));
    await tester.pump();
    expect(_textFieldFocused(), isTrue);

    await tester.tap(find.text('원산지 구성'));
    await tester.pump();
    expect(_textFieldFocused(), isFalse);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/keyboard_dismiss_test.dart`
Expected: FAIL — 현재는 빈 곳 탭에 unfocus가 없어 `_textFieldFocused()`가 여전히 true.

- [ ] **Step 3: `tasting_form_screen.dart` body 감싸기** — `build`의 `body:`를 교체

```dart
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ... 기존 children 그대로 (Row 날짜, 강도, IntensitySelector 4개, 별점, 코멘트 TextField) ...
          ],
        ),
      ),
```

(기존 `body: ListView(padding: ..., children: [...])`의 children은 손대지 않고, `ListView`를 `GestureDetector`로 감싸고 `keyboardDismissBehavior`만 추가.)

- [ ] **Step 4: `bean_form_screen.dart` body 감싸기** — `build`의 `body:`를 동일 패턴으로 교체

```dart
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ... 기존 children 그대로 (제품명/로스터리 TextField, SegmentedButton, 구성 에디터, 드롭다운, 날짜, 컵노트, 메모) ...
          ],
        ),
      ),
```

- [ ] **Step 5: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS(키보드 2개 포함).

- [ ] **Step 6: 커밋**

```bash
git add lib/features/tasting/tasting_form_screen.dart lib/features/beans/bean_form_screen.dart test/widget/keyboard_dismiss_test.dart
git commit -m "feat(ux): dismiss keyboard on tap-outside + scroll in forms"
```

---

## Task 2: 시음 카드 스와이프 삭제 + Undo

**Files:**
- Create: `lib/features/beans/widgets/delete_ux.dart`
- Modify: `lib/data/models.dart` (`TastingInput.fromTasting`)
- Modify: `lib/features/beans/bean_detail_screen.dart`
- Create: `test/widget/tasting_swipe_test.dart`

**Interfaces:**
- Consumes: `deleteTasting`/`createTasting`/`TastingInput` (M2), `context.colors.cherry` (theme), `Dismissible` (Flutter).
- Produces:
  - `class SwipeDeleteBackground extends StatelessWidget` (const 생성자) — Dismissible `background`용.
  - `TastingInput.fromTasting(Tasting t)` 팩토리.
  - `_DetailBody`가 `void Function(Tasting) onDeleteTasting` 콜백을 받음.

- [ ] **Step 1: `TastingInput.fromTasting` 추가** — `lib/data/models.dart`의 `TastingInput` 클래스에 팩토리 추가(`Tasting`은 `database.dart`에서 이미 import됨)

```dart
  factory TastingInput.fromTasting(Tasting t) => TastingInput(
        date: t.date,
        acidity: t.acidity,
        sweetness: t.sweetness,
        body: t.body,
        bitterness: t.bitterness,
        overall: t.overall,
        comment: t.comment,
      );
```

- [ ] **Step 2: 공용 삭제 배경 위젯** — `lib/features/beans/widgets/delete_ux.dart` 생성

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Dismissible 스와이프-삭제의 빨간 배경 (trailing 정렬). 시음·원두 공용.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: c.cherry,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_outline, color: Colors.white, size: 20),
        SizedBox(width: 6),
        Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
```

- [ ] **Step 3: 실패 테스트 작성** — `test/widget/tasting_swipe_test.dart`

```dart
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('swiping a tasting deletes it and offers undo', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting());

    await tester.pumpWidget(wrapApp(BeanDetailScreen(beanId: id), db: db));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect((await repo.getBeanDetail(id))!.tastings, isEmpty); // deleted
    expect(find.text('실행취소'), findsOneWidget);               // undo offered

    await tester.tap(find.text('실행취소'));
    await tester.pumpAndSettle();
    expect((await repo.getBeanDetail(id))!.tastings, hasLength(1)); // restored

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });
}
```

- [ ] **Step 4: 실패 확인**

Run: `flutter test test/widget/tasting_swipe_test.dart`
Expected: FAIL — 시음 행이 아직 `Dismissible`이 아니라 `findsOneWidget` 실패(또는 스와이프 무반응).

- [ ] **Step 5: 상세에 Dismissible + Undo** — `lib/features/beans/bean_detail_screen.dart`

import 추가:

```dart
import 'widgets/delete_ux.dart';
```

`BeanDetailScreen.build`의 data 콜백에서 `_DetailBody`에 콜백 전달 — `data:` 줄 교체:

```dart
        data: (d) => d == null
            ? const Center(child: Text('삭제된 원두예요'))
            : _DetailBody(
                detail: d,
                onDeleteTasting: (t) => _deleteTastingWithUndo(context, ref, t),
              ),
```

`BeanDetailScreen`에 메서드 추가(`_confirmDeleteBean` 아래):

```dart
  void _deleteTastingWithUndo(BuildContext context, WidgetRef ref, Tasting t) {
    final repo = ref.read(beanRepositoryProvider);
    repo.deleteTasting(t.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('시음 기록을 삭제했어요'),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () => repo.createTasting(t.beanId, TastingInput.fromTasting(t)),
        ),
      ));
  }
```

`_DetailBody`에 콜백 필드 추가 — 클래스 헤더/생성자 교체:

```dart
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onDeleteTasting});
  final BeanDetail detail;
  final void Function(Tasting) onDeleteTasting;
```

`_tastingRow`를 `Dismissible`로 감싸기 — 반환부 교체(안쪽 InkWell/탭→편집은 그대로):

```dart
  Widget _tastingRow(BuildContext context, Tasting t) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey('tasting-${t.id}'),
      direction: DismissDirection.endToStart,
      background: const SwipeDeleteBackground(),
      confirmDismiss: (_) async {
        onDeleteTasting(t);   // 삭제 + Undo 스낵바
        return false;         // 반응형 리빌드가 행 제거(assert 회피)
      },
      child: InkWell(
        key: Key('tasting-row-${t.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TastingFormScreen(beanId: t.beanId, existing: t))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.cup, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.appLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.date.toIso8601String().substring(0, 10), style: monoStyle(size: 11, color: c.appMuted)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(
                    '산미 ${t.acidity} · 단맛 ${t.sweetness} · 바디 ${t.body} · 쓴맛 ${t.bitterness}',
                    style: monoStyle(size: 11, color: c.espresso)),
              ),
              StarRating(value: t.overall.toDouble(), size: 12),
            ]),
            if (t.comment != null && t.comment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t.comment!, style: TextStyle(fontSize: 12, color: c.espresso)),
            ],
          ]),
        ),
      ),
    );
  }
```

- [ ] **Step 6: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS(스와이프 삭제+Undo 포함, 기존 detail 테스트 유지).

- [ ] **Step 7: 커밋**

```bash
git add lib/data/models.dart lib/features/beans/widgets/delete_ux.dart lib/features/beans/bean_detail_screen.dart test/widget/tasting_swipe_test.dart
git commit -m "feat(ux): swipe-to-delete a tasting with undo"
```

---

## Task 3: 원두 카드 스와이프 삭제 + 확인

**Files:**
- Modify: `lib/features/beans/widgets/delete_ux.dart` (`confirmDeleteBeanDialog` 추가)
- Modify: `lib/features/beans/bean_detail_screen.dart` (`_confirmDeleteBean`가 공용 함수 사용)
- Modify: `lib/features/beans/bean_list_screen.dart` (`BeanCard` Dismissible)
- Create: `test/widget/bean_swipe_test.dart`

**Interfaces:**
- Consumes: `SwipeDeleteBackground` (T2), `deleteBean`/`beanRepositoryProvider` (M2), `BeanCard` (M1), `Dismissible`.
- Produces: `Future<bool> confirmDeleteBeanDialog(BuildContext context)` — 원두 삭제 확인 다이얼로그(공용).

- [ ] **Step 1: 실패 테스트 작성** — `test/widget/bean_swipe_test.dart`

```dart
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('swiping a bean confirms then deletes', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle(name: '삭제될 원두'));

    await tester.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('삭제될 원두'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('원두 삭제'), findsOneWidget); // confirm dialog
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(await repo.getBeanDetail(id), isNull);
    expect(find.text('삭제될 원두'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('cancelling the swipe keeps the bean', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '남는 원두'));

    await tester.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('남는 원두'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/bean_swipe_test.dart`
Expected: FAIL — 카드가 아직 `Dismissible`이 아님.

- [ ] **Step 3: 공용 확인 다이얼로그** — `lib/features/beans/widgets/delete_ux.dart`에 함수 추가

```dart
/// 원두 삭제 확인 다이얼로그. 사용자가 '삭제'를 누르면 true.
Future<bool> confirmDeleteBeanDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('원두 삭제'),
      content: const Text('이 원두와 모든 시음 기록이 삭제됩니다. 되돌릴 수 없어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
      ],
    ),
  );
  return ok == true;
}
```

- [ ] **Step 4: 상세의 `_confirmDeleteBean`를 공용 함수로** — `lib/features/beans/bean_detail_screen.dart` 교체(중복 제거)

```dart
  Future<void> _confirmDeleteBean(BuildContext context, WidgetRef ref, int id) async {
    if (!await confirmDeleteBeanDialog(context)) return;
    await ref.read(beanRepositoryProvider).deleteBean(id);
    if (context.mounted) Navigator.of(context).pop(); // 리스트로 복귀
  }
```

(`delete_ux.dart`는 T2에서 이미 import됨.)

- [ ] **Step 5: 리스트 카드에 Dismissible** — `lib/features/beans/bean_list_screen.dart`

import 추가:

```dart
import 'widgets/delete_ux.dart';
```

`itemBuilder`의 `return BeanCard(...)`를 `Dismissible`로 감싸기:

```dart
            itemBuilder: (_, i) {
              final s = list[i];
              return Dismissible(
                key: ValueKey('bean-${s.bean.id}'),
                direction: DismissDirection.endToStart,
                background: const SwipeDeleteBackground(),
                confirmDismiss: (_) async {
                  final ok = await confirmDeleteBeanDialog(context);
                  if (ok) await ref.read(beanRepositoryProvider).deleteBean(s.bean.id);
                  return false; // 반응형 리빌드가 삭제된 카드 제거(assert 회피)
                },
                child: BeanCard(
                  summary: s,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BeanDetailScreen(beanId: s.bean.id))),
                ),
              );
            },
```

(`bean_list_screen.dart`는 `ConsumerWidget`이라 `build(context, ref)`의 `ref`를 `itemBuilder` 클로저에서 사용 가능. `beanRepositoryProvider`는 `providers.dart`에서 이미 import됨.)

- [ ] **Step 6: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS(원두 스와이프 확인/취소 포함).

- [ ] **Step 7: 커밋**

```bash
git add lib/features/beans/widgets/delete_ux.dart lib/features/beans/bean_detail_screen.dart lib/features/beans/bean_list_screen.dart test/widget/bean_swipe_test.dart
git commit -m "feat(ux): swipe-to-delete a bean with confirm (shared dialog)"
```

---

## 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green.
- 코멘트/메모 입력 후 **빈 곳 탭 또는 스크롤 → 키보드 내려감**.
- 시음 행 **스와이프 → 삭제 + 실행취소** (탭→편집 유지).
- 원두 카드 **스와이프 → 확인 다이얼로그 → 삭제(연쇄)** / 취소 시 유지 (탭→상세 유지).
- 태스크별 SDD 리뷰 + 최종 리뷰 통과 → `v0.2.1` 태그 → 기기 확인.
