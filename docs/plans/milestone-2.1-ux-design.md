# ☕ BeanProfile — M2.1 설계: UX 개선 (키보드·스와이프 삭제)

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-19 |
| 상태 | 설계 승인 (브레인스토밍) → 구현 계획(writing-plans) 대기 |
| 마일스톤 | M2.1 (M2 위 UX 패치) |
| 선행 | M2 (편집/삭제 + 시음 CRUD) **DONE** · `v0.2.0` |
| 목표 버전 | `v0.2.1` (패치 태그, M2 파이프라인 재사용) |
| 목업 | [`../mockups/m2-ux-improvements.html`](../mockups/m2-ux-improvements.html) · [아티팩트](https://claude.ai/code/artifact/8be0dfe9-964e-4d73-8d77-80c7ffada355) |
| 상위 문서 | 설계 [`../design.md`](../design.md) · M2 [`milestone-2-design.md`](milestone-2-design.md) |

---

## 1. 목표 & 범위

기기 사용 중 발견한 3가지 UX 문제를 고친다. 새 데이터 모델·기능이 아니라 **상호작용 개선**이며, `deleteTasting`/`deleteBean`은 M2에 이미 있으므로 **거의 순수 UI 변경**이다.

### 확정 결정 (브레인스토밍 2026-07-19)

| # | 결정 | 선택 |
|---|---|---|
| Q1 | 키보드 내리기 | **빈 곳 탭 + 스크롤로 dismiss** (완료 바/컨트롤-탭 자동내림은 스코프 밖) |
| Q2 | 삭제 제스처 | **스와이프-삭제** (시음·원두 카드 모두; 롱프레스는 스코프 밖) |
| Q3 | 삭제 확인 | **시음 = Undo 스낵바 / 원두 = 확인 다이얼로그** (파괴성에 비례) |

---

## 2. 설계

### 2.1 키보드 내리기 — `tasting_form_screen.dart` · `bean_form_screen.dart`

두 폼 모두 body가 `ListView`다. 두 가지를 더한다:

1. 스크롤로 내림 — ListView에 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.
2. 빈 곳 탭으로 내림 — body를 감싼다:

```dart
GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () => FocusScope.of(context).unfocus(),
  child: ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    ...
  ),
)
```

`translucent`라 컨트롤(별점·도트·버튼) 탭은 그대로 자식이 처리하고, 빈 여백 탭만 `onTap`이 받아 `unfocus()` → 키보드가 내려간다. 코멘트·메모·지역·비율% 등 **완료 키 없는 모든 필드**를 한 번에 커버한다. 새 위젯 없음.

### 2.2 시음 카드 — 스와이프 삭제 + Undo — `bean_detail_screen.dart`

`_tastingRow`의 `InkWell`을 `Dismissible`로 감싼다(탭→편집은 안쪽에 유지):

```dart
Dismissible(
  key: ValueKey('tasting-${t.id}'),
  direction: DismissDirection.endToStart,
  background: _deleteBackground(context),      // cherry 패널 + 🗑 삭제, 우측 정렬
  onDismissed: (_) => _deleteTastingWithUndo(context, ref, t),
  child: InkWell(/* 기존 행: 탭→편집 */),
)
```

`_deleteTastingWithUndo`: 삭제할 `Tasting`을 값으로 들고, `deleteTasting(t.id)` 실행 후 SnackBar:

```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: const Text('시음 기록을 삭제했어요'),
  action: SnackBarAction(
    label: '실행취소',
    onPressed: () => repo.createTasting(t.beanId, TastingInput.fromTasting(t)),
  ),
));
```

- Undo는 `createTasting`(M2 기존)으로 **재삽입**한다. 새 id가 붙지만 시음 id를 외부에서 참조하는 곳이 없어 무해하고, `date`가 보존되어 리스트 순서도 유지된다.
- `TastingInput.fromTasting(Tasting t)` 팩토리를 `models.dart`에 추가(유일한 repo/모델 변경).

### 2.3 원두 카드 — 스와이프 삭제 + 확인 — `bean_list_screen.dart`

리스트의 각 `BeanCard`를 `Dismissible`로 감싼다(탭→상세 유지). 파괴적(시음 연쇄삭제)이라 `confirmDismiss`로 **기존 확인 다이얼로그**를 띄운다:

```dart
Dismissible(
  key: ValueKey('bean-${s.bean.id}'),
  direction: DismissDirection.endToStart,
  background: _deleteBackground(context),
  confirmDismiss: (_) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('원두 삭제'),
      content: const Text('이 원두와 모든 시음 기록이 삭제됩니다. 되돌릴 수 없어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
      ],
    ));
    if (ok == true) {
      await ref.read(beanRepositoryProvider).deleteBean(s.bean.id);
      return true;   // 카드 제거
    }
    return false;    // 제자리 복귀
  },
)
```

`confirmDismiss`가 `false`면 카드가 원위치로 스냅백(삭제 안 됨). 확인 다이얼로그 문구·동작은 상세 화면의 `_confirmDeleteBean`과 동일 → 공용 위젯/헬퍼로 뽑아 재사용(중복 방지).

### 2.4 공용 삭제 배경 + Dismissible·반응형 리스트 주의

- `_deleteBackground(context)`: `c.cherry` 바탕에 흰 🗑 + "삭제", 우측(trailing) 정렬. 시음·원두 공용.
- **주의(구현 리스크):** `Dismissible`이 반응형 스트림 리스트와 함께 쓰일 때, dismiss 후 데이터 소스에서 항목이 사라지기 전에 같은 스냅샷으로 리빌드되면 *"A dismissed Dismissible widget is still part of the tree"* assert가 난다. 완화: (a) `key`를 항목별 고유값으로, (b) 시음은 `onDismissed`에서 즉시 `deleteTasting` → drift 스트림이 곧바로 재방출하며 목록에서 제거, (c) 원두는 `confirmDismiss`가 `deleteBean` 완료 후 `true`를 반환하므로 재방출과 위젯 제거가 정렬됨. 위젯 테스트로 assert가 안 나는지 확인한다. 만약 재현되면 로컬 제거셋/`AnimatedList` 대신 drift 재방출에 의존하는 현 구조를 유지하되 `onDismissed` 타이밍을 조정한다.

---

## 3. 파일 영향

**수정**
- `lib/features/tasting/tasting_form_screen.dart` — 키보드(2.1)
- `lib/features/beans/bean_form_screen.dart` — 키보드(2.1)
- `lib/features/beans/bean_detail_screen.dart` — `_tastingRow` Dismissible + Undo(2.2)
- `lib/features/beans/bean_list_screen.dart` — `BeanCard` Dismissible + 확인(2.3)
- `lib/data/models.dart` — `TastingInput.fromTasting` 팩토리

**신규(선택)**
- 공용 `_deleteBackground` + 원두 삭제 확인 헬퍼를 작은 위젯/함수로 분리(중복 제거)
- 테스트: `test/widget/tasting_swipe_test.dart` · `test/widget/bean_swipe_test.dart` · 키보드 dismiss 테스트

---

## 4. 테스트 전략 (docs/testing.md 3계층 · `test/helpers` 재사용)

- **시음 스와이프+Undo:** 상세를 실제 DB로 pump → 시음 행을 `tester.drag(finder, Offset(-500,0))` 후 `pumpAndSettle` → `getBeanDetail`로 삭제 확인 → SnackBar의 '실행취소' 탭 → 재삽입(개수 복원) 확인. (drift 스트림 watch → teardown 전 `db.close`/`pump` 주의: M2 T6 교훈.)
- **원두 스와이프+확인:** 리스트를 실제 DB로 pump → 카드 drag → 확인 다이얼로그 등장 → '삭제' 탭 → 리스트에서 제거 확인 / 별도 케이스로 '취소' 탭 → 카드 유지 확인.
- **키보드 dismiss:** 폼 pump → `TextField` 탭(포커스) → 빈 영역 탭 → 포커스 해제(`FocusScope`에 primaryFocus 없음) 확인. (실제 키보드 표시는 위젯 테스트로 검증 어려우니 포커스 상태로 확인.)

---

## 5. 스코프 밖 (이번 아님)

- 원두 삭제 Undo(전체 복원) — 이번은 확인 다이얼로그. 원두는 연쇄삭제라 안전 우선.
- 시음 **편집 화면**의 기존 삭제 버튼/다이얼로그 — 유지(스와이프는 리스트의 빠른 경로, 편집 화면은 신중한 경로).
- 롱프레스 액션 시트 — 이번은 스와이프만.
- 키보드 "완료" 바 / 컨트롤(별점·도트·날짜) 탭 시 자동 내림 — 이번은 탭+스크롤만.

---

## 6. 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green.
- 키보드: 코멘트/메모 입력 후 **빈 곳 탭 또는 스크롤로 내려감**.
- 시음: 행 **스와이프 → 삭제 + 실행취소** 동작, 상세/평균★ 반영.
- 원두: 카드 **스와이프 → 확인 다이얼로그 → 삭제(연쇄)** / 취소 시 복귀.
- 태스크별 SDD 리뷰 + 최종 리뷰 통과 → `v0.2.1` 태그 → 기기 확인.
