# M3.1 OCR 칩 배정 재설계 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 취약한 "칸 포커스 → 스크롤 → 칩 탭" 배정을 **"칩 탭 → '어디에 넣을까요?' 시트 → 대상 탭"** 으로 교체하고, 지역·국가를 포함한 **모든 자유 텍스트 필드**를 배정 대상으로 만든다.

**Architecture:** `FocusNode` 기반 `_activeField` 메커니즘을 제거한다. `OcrChipsPanel`의 칩 탭은 이제 모달 바텀시트를 열어 텍스트 필드 대상 목록(현재 값 미리보기 포함)을 보여주고, 선택 시 해당 컨트롤러에 채운다(컵노트=추가, 그 외=교체) + 칩을 used로 표시. 시트가 모달이라 대상 칸이 스크롤로 안 보여도 배정된다.

**Tech Stack:** Flutter · flutter_riverpod · Dart 3 records · flutter_test.

## Global Constraints

- **한국어 UI** · 오프라인/로컬 전용.
- **데이터 모델·저장소·providers 변경 없음** (순수 UI 상호작용 패치).
- `flutter analyze` 0 · 기존 테스트 green 유지.
- 커밋 트레일러: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` · main 직접 커밋(트렁크).
- 배정 대상 = 제품명·로스터리·원산지 국가·지역·컵노트·메모(첫 구성만). 컵노트=추가, 그 외=교체. 자동으로 찬 칸도 포함(덮어쓰기).
- 로스팅단계·날짜·가공은 enum/날짜라 칩 대상 아님(기존 피커 유지). 키보드 내리기·"OCR 자동" 하이라이트 유지.

---

## File Structure

**수정 (신규 파일 없음)**
- `lib/features/beans/bean_form_screen.dart` — 포커스 메커니즘 제거 + `_openAssignSheet` 추가 + 칩 onTap 교체 + 지역 필드 key.
- `lib/features/beans/widgets/ocr_chips_panel.dart` — 힌트/문서 문구.
- `test/widget/ocr_form_test.dart` — 포커스-라우팅 테스트 → 시트 배정 테스트로 교체.

작은 단일 패치라 **1 태스크**로 구성한다(제거+추가가 서로 얽혀 중간 상태가 컴파일되지 않으므로 분리 불가).

---

### Task 1: 칩-먼저 배정 시트로 교체

**Files:**
- Modify: `lib/features/beans/bean_form_screen.dart`, `lib/features/beans/widgets/ocr_chips_panel.dart`
- Test: `test/widget/ocr_form_test.dart`

**Interfaces:**
- Consumes: `OcrChipsPanel({required List<String> chips, required Set<String> used, required void Function(String) onTap})` (시그니처 불변 — `onTap`이 이제 시트를 연다) · `BeanFormScreen` 상태의 `_name`/`_roaster`/`_cupNotes`/`_memo`/`_components`/`_usedChips`.
- Produces: (내부) `Future<void> _openAssignSheet(String chip)` · 지역 필드 `Key('field-region-$i')`.

- [ ] **Step 1: 포커스-라우팅 테스트를 시트 배정 테스트로 교체 (실패 테스트 작성)**

`test/widget/ocr_form_test.dart`에서 **기존 두 번째 테스트 `'칩이 포커스된 칸으로 라우팅됨 (하드코딩 아님)'` 전체(현재 40–67행)를 삭제**하고 그 자리에 아래 4개 테스트를 넣는다(나머지 테스트는 불변):

```dart
  testWidgets('칩 탭 → 배정 시트가 대상 목록을 보여줌', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['Yirgacheffe'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-Yirgacheffe')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('assign-지역')), findsOneWidget);
    expect(find.byKey(const Key('assign-원산지 국가')), findsOneWidget);
    expect(find.byKey(const Key('assign-컵노트에 추가')), findsOneWidget);
  });

  testWidgets('시트에서 지역 선택 → 지역 칸에 채워지고 칩 흐려짐', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['Yirgacheffe'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-Yirgacheffe')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    expect(t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text, 'Yirgacheffe');
    expect(t.widget<ActionChip>(find.byKey(const Key('chip-Yirgacheffe'))).onPressed, isNull);
  });

  testWidgets('시트에서 컵노트에 추가 → 기존 값에 append', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(cupNotes: ['블루베리'], chips: ['홍차'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-홍차')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-컵노트에 추가')));
    await t.pumpAndSettle();

    expect(find.text('블루베리, 홍차'), findsOneWidget);
  });

  testWidgets('자동으로 찬 국가 칸도 시트에서 덮어쓸 수 있음', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(country: 'Ethiopia', chips: ['Colombia'])),
      db: db,
    ));
    await t.pump();

    expect(t.widget<TextField>(find.byKey(const Key('field-country-0'))).controller!.text, 'Ethiopia');

    await t.tap(find.byKey(const Key('chip-Colombia')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-원산지 국가')));
    await t.pumpAndSettle();

    expect(t.widget<TextField>(find.byKey(const Key('field-country-0'))).controller!.text, 'Colombia');
  });
```

- [ ] **Step 2: RED 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 새 4개 테스트 FAIL — 칩을 탭해도 시트(`assign-*` ListTile)가 안 열림(현재는 `_assignChip`이 SnackBar만 띄움). (기존 유지 테스트는 PASS.)

- [ ] **Step 3a: `bean_form_screen.dart` — 상태 필드에서 포커스 메커니즘 제거**

현재 상태 필드 블록(현 37–42행):

```dart
  bool _saving = false;
  final _nameFocus = FocusNode();
  final _roasterFocus = FocusNode();
  final _cupNotesFocus = FocusNode();
  final _memoFocus = FocusNode();
  TextEditingController? _activeField;
  final _usedChips = <String>{};
```

를 아래로 교체(포커스 필드·`_activeField` 삭제, `_usedChips` 유지):

```dart
  bool _saving = false;
  final _usedChips = <String>{};
```

- [ ] **Step 3b: `initState`의 포커스 리스너 4줄 삭제**

`initState` 끝의 아래 4줄(현 79–82행)을 **삭제**:

```dart
    _nameFocus.addListener(() { if (_nameFocus.hasFocus) _activeField = _name; });
    _roasterFocus.addListener(() { if (_roasterFocus.hasFocus) _activeField = _roaster; });
    _cupNotesFocus.addListener(() { if (_cupNotesFocus.hasFocus) _activeField = _cupNotes; });
    _memoFocus.addListener(() { if (_memoFocus.hasFocus) _activeField = _memo; });
```

- [ ] **Step 3c: `dispose`의 포커스 해제 2줄 삭제**

`dispose`에서 아래 2줄(현 88–89행)을 **삭제**(나머지 dispose는 유지):

```dart
    _nameFocus.dispose(); _roasterFocus.dispose();
    _cupNotesFocus.dispose(); _memoFocus.dispose();
```

- [ ] **Step 3d: `_assignChip`을 `_openAssignSheet`로 교체**

기존 `_assignChip` 메서드(현 100–116행)를 **삭제**하고 아래로 교체:

```dart
  Future<void> _openAssignSheet(String chip) async {
    // (라벨, 대상 컨트롤러, append 여부)
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
              child: Text('‘$chip’ 어디에 넣을까요?',
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
    setState(() {
      if (append) {
        final cur = ctrl.text.trim();
        ctrl.text = cur.isEmpty ? chip : '$cur, $chip';
      } else {
        ctrl.text = chip;
      }
      _usedChips.add(chip);
    });
  }
```

- [ ] **Step 3e: 4개 TextField에서 `focusNode:` 인자 제거**

제품명·로스터리(현 180·183행), 컵노트(227행), 메모(232행)의 `focusNode: _nameFocus`(등)를 **삭제**. 교체 후 4줄:

```dart
        TextField(key: const Key('field-name'), controller: _name,
            decoration: const InputDecoration(labelText: '제품명 *')),
```

```dart
        TextField(key: const Key('field-roaster'), controller: _roaster,
            decoration: const InputDecoration(labelText: '로스터리')),
```

```dart
        TextField(controller: _cupNotes,
            decoration: InputDecoration(
                labelText: '컵노트 (쉼표로 구분)', hintText: '블루베리, 자스민, 홍차',
                helperText: _auto && widget.draft!.cupNotes.isNotEmpty ? 'OCR 자동' : null)),
```

```dart
        TextField(controller: _memo, maxLines: 3,
            decoration: const InputDecoration(labelText: '메모')),
```

- [ ] **Step 3f: 칩 패널 onTap 교체**

`OcrChipsPanel` 호출(현 246행)의 `onTap: _assignChip`을 `onTap: _openAssignSheet`로:

```dart
          else if (widget.draft!.chips.isNotEmpty)
            OcrChipsPanel(chips: widget.draft!.chips, used: _usedChips, onTap: _openAssignSheet),
```

- [ ] **Step 3g: 지역 TextField에 key 추가**

`_componentEditor`의 지역 TextField(현 288–289행)에 key를 단다:

```dart
          Expanded(child: TextField(
              key: Key('field-region-$i'),
              controller: comp.region,
              decoration: const InputDecoration(labelText: '지역'))),
```

- [ ] **Step 3h: `ocr_chips_panel.dart` 힌트·문서 문구 갱신**

문서 주석(현 4행)과 힌트 텍스트(현 21–22행)를 교체:

```dart
/// 인식된 텍스트 칩. 탭하면 '어디에 넣을지' 배정 시트가 열린다. 쓴 칩은 흐려짐.
```

```dart
        Text('인식된 텍스트 — 칩을 누르면 어디에 넣을지 물어봐요',
            style: TextStyle(fontSize: 11, color: c.cremaInk, fontWeight: FontWeight.w600)),
```

- [ ] **Step 4: GREEN + analyze + 전체**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: 전체 PASS(유지 테스트 + 새 4개).
Run: `flutter analyze`
Expected: No issues (제거된 `_nameFocus` 등에 대한 미사용/미정의 참조가 하나도 남지 않았는지 확인).
Run: `flutter test`
Expected: 전체 green(기존에서 net: 포커스 테스트 1 제거 + 새 4 = +3).

- [ ] **Step 5: Commit**

```bash
git add lib/features/beans/bean_form_screen.dart lib/features/beans/widgets/ocr_chips_panel.dart test/widget/ocr_form_test.dart
git commit -m "feat(m3.1): chip-first assign sheet (all text fields, incl region); drop focus mechanism"
```

---

## Self-Review (계획 작성자 체크)

**Spec coverage** (milestone-3.1-ux-design.md 대비):
- §3.1 칩-먼저 시트 → Step 3d(_openAssignSheet) + 3f(onTap). ✅
- §3.2 대상 6필드·규칙(append/replace)·자동값 포함 → _openAssignSheet의 targets + subtitle. ✅
- §3.3 포커스 메커니즘 제거 → Step 3a/3b/3c/3e. ✅
- §3.4 패널 힌트·지역 key → Step 3h·3g. ✅
- §5 테스트(칩탭→시트·지역 배정·컵노트 추가·자동값 덮어쓰기, focus-routing 폐기) → Step 1. ✅

**Placeholder scan:** TBD/TODO 없음. 모든 코드 단계에 실제 코드. ✅

**Type consistency:** `_openAssignSheet(String)`가 `OcrChipsPanel.onTap`(`void Function(String)`)에 호환(Future 반환이지만 tear-off는 `void` 컨텍스트에 할당 가능 — Dart는 `Future<void> Function(String)`을 `void Function(String)`로 허용). 시트 ListTile key `assign-{라벨}`가 테스트의 `Key('assign-지역')` 등과 일치. 지역 key `field-region-$i`가 테스트의 `field-region-0`과 일치. ✅

**주의(구현 시):**
- `_openAssignSheet` tear-off를 `onTap`에 넘길 때 반환형 `Future<void>` → `void` 함수 타입 할당은 Dart에서 허용되나, 혹시 analyzer가 경고하면 `onTap: (chip) => _openAssignSheet(chip)` 로 래핑.
- 컵노트 필드엔 key가 없어 테스트가 `find.text('블루베리, 홍차')`로 확인 — 그 문자열은 화면에 유일(칩 '홍차'와 다름)하므로 findsOneWidget.
- 시트는 모달이라 대상 칸이 스크롤 밖이어도 배정됨(핵심). 단 테스트가 배정 후 필드 값을 읽으려면 필드가 트리에 있어야 하므로 뷰포트 확대(2400×4000, dpr 3.0) 유지.
