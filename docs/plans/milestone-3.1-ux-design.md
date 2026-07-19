# ☕ BeanProfile — M3.1 설계: OCR 칩 배정 재설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-19 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획(writing-plans) 대기 |
| 마일스톤 | M3.1 (M3 위 UX 패치) |
| 선행 | M3 (사진 & OCR) **DONE** · `v0.3.0` |
| 목표 버전 | `v0.3.1` (패치 태그, M3 파이프라인 재사용) |
| 목업 | [`../mockups/m3.1-chip-assign.html`](../mockups/m3.1-chip-assign.html) · [아티팩트](https://claude.ai/code/artifact/7cfa6937-5cd9-4bcb-a2fe-b727723d11f8) |
| 상위 문서 | M3 [`milestone-3-design.md`](milestone-3-design.md) · 설계 [`../design.md`](../design.md) §5 |

---

## 1. 목표 & 범위

M3 온디바이스 테스트에서 드러난 **인식 칩 배정 UX의 2가지 결함**을 고친다. 데이터 모델·기능 변화가 아니라 **상호작용 재설계**이며, `bean_form_screen`과 `OcrChipsPanel`에 국한된다.

### 확정 결정 (브레인스토밍 2026-07-19)

| # | 결정 | 선택 |
|---|---|---|
| Q1 | 배정 상호작용 | **칩 먼저** — 칩 탭 → "어디에 넣을까요?" 시트 → 대상 탭 (포커스-먼저 폐기) |
| Q2 | 자동값 텍스트 칸 | **시트에 포함(덮어쓰기 허용)** — 현재 값 미리보기와 함께 표시 |
| Q3 | 드래그드롭 | **미지원** — 이 레이아웃(칩 아래·칸 위·스크롤)에선 자동스크롤 커스텀·터치 정확도·테스트 취약으로 역효과 |
| — | 배정 대상 | **모든 자유 텍스트 필드**(제품명·로스터리·원산지 국가·지역·컵노트·메모). 컵노트=추가, 그 외=교체 |

---

## 2. 문제 (온디바이스 발견)

1. **지역·국가를 못 채움.** M3 Task 5는 칩 배정 대상을 상위 4개 필드(제품명·로스터리·컵노트·메모)로만 배선했다(`_activeField` + 4개 `FocusNode`). 구성(원산지) 안의 **국가·지역 필드는 배정 배선이 없다** → OCR이 지역을 읽어 칩으로 보여줘도 넣을 곳이 없다.
2. **포커스-먼저 방식이 구조적으로 취약.** 칩 패널은 폼 **하단**, 대상 칸은 **위**. "칸 포커스 → 칩까지 스크롤 → 칩 탭"인데, 스크롤 시 (a) 키보드가 내려가고(M2.1 `onDrag` dismiss) (b) 대상 칸이 화면 밖으로 사라져 **무엇을 채우는지 안 보인다.** "멀리 떨어진 대상 + 보이지 않는 유지 상태" 조합이 근본 원인.

---

## 3. 설계

### 3.1 상호작용 — 칩 먼저 (배정 시트)

`OcrChipsPanel`의 칩을 탭하면 **모달 바텀시트**가 열려 "이 텍스트를 어디에 넣을지" 묻는다. 대상을 탭하면 해당 칸에 채워지고 칩은 흐려진다(used). 스크롤 위치·포커스와 무관하고, 시트는 모달 오버레이라 **대상 칸이 화면에 안 보여도 배정된다** — 이것이 핵심.

### 3.2 배정 대상 & 규칙

| 대상(라벨) | 컨트롤러 | 규칙 |
|---|---|---|
| 제품명 | `_name` | 교체 |
| 로스터리 | `_roaster` | 교체 |
| 원산지 국가 | `_components.first.country` | 교체 |
| 지역 | `_components.first.region` | 교체 |
| 컵노트에 추가 | `_cupNotes` | **추가**(비어있으면 그대로, 아니면 `, ` 뒤에 붙임) |
| 메모 | `_memo` | 교체 |

- **자동값 포함:** 이미 자동으로 찬 칸(예: 국가=Ethiopia)도 목록에 **현재 값을 부제로** 표시하고 탭하면 덮어쓴다(오탐 교정). 빈 칸은 "비어있음".
- 로스팅단계·날짜·가공은 enum/날짜라 문자열 칩 대상이 아님 → 기존 피커로 수정(불변).
- **첫 구성만** 대상(Task 5의 프리필과 동일). 블렌드 2번째+ 구성 필드는 직접 입력(스코프 밖).

### 3.3 제거 (포커스 메커니즘 폐기)

`bean_form_screen`에서 삭제한다:
- 필드: `_nameFocus`, `_roasterFocus`, `_cupNotesFocus`, `_memoFocus`, `_activeField`.
- `initState`의 4개 focus 리스너, `dispose`의 4개 focus 해제.
- `_assignChip`의 기존 본문(활성 필드 채우기 + "먼저 채울 칸을 탭…" SnackBar).
- 4개 TextField(name/roaster/cupNotes/memo)의 `focusNode:` 인자.

(키보드 내리기(M2.1 GestureDetector unfocus + `keyboardDismissBehavior`)와 "OCR 자동" 하이라이트는 무관하므로 **유지**.)

### 3.4 추가 / 변경

- `bean_form_screen`에 `Future<void> _openAssignSheet(String chip)` 추가:

```dart
Future<void> _openAssignSheet(String chip) async {
  // (라벨, 컨트롤러, append?)
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

- `OcrChipsPanel` 호출을 `onTap: _assignChip` → `onTap: _openAssignSheet`로 변경.
- `OcrChipsPanel`의 힌트 문구를 "인식된 텍스트 — **칩을 누르면 어디에 넣을지 물어봐요**"로 갱신.
- 지역 TextField(`_componentEditor`)에 `key: Key('field-region-$i')` 추가(테스트가 값 확인용).

---

## 4. 파일 영향

**수정**
- `lib/features/beans/bean_form_screen.dart` — 포커스 메커니즘 제거, `_openAssignSheet` 추가, 칩 onTap 변경, 지역 필드 key.
- `lib/features/beans/widgets/ocr_chips_panel.dart` — 힌트 문구.
- `test/widget/ocr_form_test.dart` — 옛 focus-routing 테스트를 시트 배정 테스트로 교체 + 지역/자동값 케이스 추가.

(데이터 모델·저장소·providers 변경 없음. `helpers.dart` 불변.)

---

## 5. 테스트 전략 (docs/testing.md 3계층 · `test/helpers` 재사용)

M3 Task 5의 `ocr_form_test.dart`에서 **focus-routing 테스트(2칩→2필드)는 폐기**(메커니즘 삭제)하고 다음으로 대체:

- **칩 탭 → 시트:** draft chips로 폼 pump(뷰포트 확대 — 칩 패널이 하단) → 칩 탭 → `find.byKey(Key('assign-지역'))` 등 시트 항목이 뜬다.
- **지역 배정(Problem 1 회귀 가드):** 시트에서 "지역" 탭 → `field-region-0` TextField의 값이 칩 텍스트 · 칩 흐려짐. (스크롤로 지역 칸이 안 보여도 배정됨 — 시트가 모달이라.)
- **컵노트 추가:** "컵노트에 추가" 탭 → 기존 값에 `, {칩}` 붙음.
- **자동값 덮어쓰기:** 국가 자동으로 찬 draft → 시트의 "원산지 국가" 부제가 현재 값 → 탭하면 칩으로 덮임.
- 유지: 프리필+하이라이트+칩 렌더, 빈 draft→배너, 저장 시 photoPath persist, persist 실패 graceful.

---

## 6. 스코프 밖 (이번 아님)

- 블렌드 2번째+ 구성의 국가·지역 배정(첫 구성만).
- 드래그드롭, quick-assign(직전 대상 기억/추천).
- 농장·품종·고도 등 폼에 없는 필드 신설(칩은 있으나 넣을 칸 없음 — 후속).
- 파서 오탐 자체(§5 반자동, 사용자 교정).

---

## 7. 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green.
- 칩 탭 → 시트 → **지역 포함 모든 자유 텍스트 칸에 배정**(스크롤 무관).
- 컵노트 추가 · 자동값 칸 덮어쓰기 동작.
- 태스크별 SDD 리뷰 + opus 최종 리뷰 통과 → `v0.3.1` 태그 → 기기 확인(지역 배정·시트 흐름).
