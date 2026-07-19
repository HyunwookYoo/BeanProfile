# M3.2 지역 OCR 자동채움 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 사진 자동채움에서 **지역(region)** 이 채워지도록 한다 — `"Region:/지역:"` 라벨 줄에서 추출(이전엔 지역이 칩으로만 떨어짐).

**Architecture:** 파서에 컵노트와 같은 **라벨 휴리스틱**(`^(region|지역)\s*[:：]\s*(.+)$`)을 추가하고, `OcrDraft`에 `region` 필드를 더해 폼이 첫 구성의 지역 칸을 프리필(+ "OCR 자동" 하이라이트)한다. **라벨 기반만** — 라벨 없이 이름줄에 섞인 지역은 여전히 칩(M3.1 시트로 배정). 국가 라벨 `원산지:`는 줄이 "원"으로 시작해 `^지역`/`^region`에 안 걸려 충돌 없음.

**Tech Stack:** 순수 Dart 파서 · Flutter 폼 · flutter_test.

## Global Constraints

- 한국어 UI · 오프라인/로컬. **데이터 모델·저장소·providers 변경 없음**(파서+폼 프리필만).
- `flutter analyze` 0 · 기존 테스트 green 유지.
- 커밋 트레일러 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` · main 직커밋 · TDD.
- **라벨 기반만**(설계 §5 "패턴이 명확한 것만 자동"). 국가 인접 휴리스틱은 스코프 밖.

---

## File Structure

**수정 (신규 파일 없음)**
- `lib/features/beans/ocr/ocr_draft.dart` — `OcrDraft.region`.
- `lib/features/beans/ocr/ocr_parser.dart` — `_regionLabel` + `_matchRegion` + `region:` 채움.
- `lib/features/beans/bean_form_screen.dart` — draft.region 프리필 + 지역 칸 "OCR 자동".
- `test/unit/ocr_parser_test.dart` · `test/widget/ocr_form_test.dart` — 테스트.

단일 태스크.

---

### Task 1: 지역 라벨 자동채움

**Files:**
- Modify: `ocr_draft.dart`, `ocr_parser.dart`, `bean_form_screen.dart`
- Test: `test/unit/ocr_parser_test.dart`, `test/widget/ocr_form_test.dart`

**Interfaces:**
- Produces: `OcrDraft({..., String? region})` · `parseOcrText`가 라벨 줄에서 region 채움.

- [ ] **Step 1: 실패 테스트 — 파서 (`test/unit/ocr_parser_test.dart`)**

기존 파일에 group 추가(다른 테스트 불변):

```dart
  group('region', () {
    test('지역/Region 라벨에서 추출', () {
      expect(parseOcrText('지역: 후일라').region, '후일라');
      expect(parseOcrText('Region: Yirgacheffe').region, 'Yirgacheffe');
      expect(parseOcrText('REGION : Yirgacheffe · Kochere').region, 'Yirgacheffe · Kochere');
    });
    test('라벨 없으면 null; 국가 라벨(원산지:)은 지역 아님', () {
      expect(parseOcrText('Ethiopia Yirgacheffe').region, isNull);
      expect(parseOcrText('원산지: 콜롬비아').region, isNull);
    });
  });
```

- [ ] **Step 2: 실패 테스트 — 폼 프리필 (`test/widget/ocr_form_test.dart`)**

파일에 테스트 추가:

```dart
  testWidgets('draft.region → 지역 칸 프리필 + OCR 자동', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(country: 'Ethiopia', region: '예가체프')),
      db: db,
    ));
    await t.pump();

    expect(t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text, '예가체프');
    expect(find.text('OCR 자동'), findsNWidgets(2)); // 국가 + 지역
  });
```

- [ ] **Step 3: RED 확인**

Run: `flutter test test/unit/ocr_parser_test.dart test/widget/ocr_form_test.dart`
Expected: 새 테스트 FAIL — `OcrDraft`에 `region` 이름 인자 없음(컴파일 에러) / region 미채움.

- [ ] **Step 4: `OcrDraft`에 region 추가 (`ocr_draft.dart`)**

```dart
class OcrDraft {
  final String? country;
  final String? region;
  final DateTime? roastDate;
  final RoastLevel? roastLevel;
  final Process? process;
  final List<String> cupNotes;
  final List<String> chips;
  const OcrDraft({
    this.country,
    this.region,
    this.roastDate,
    this.roastLevel,
    this.process,
    this.cupNotes = const [],
    this.chips = const [],
  });

  /// 자동 채운 값도, 배정할 칩도 하나도 없음(= OCR 실패/빈 이미지).
  bool get isEmpty =>
      country == null &&
      region == null &&
      roastDate == null &&
      roastLevel == null &&
      process == null &&
      cupNotes.isEmpty &&
      chips.isEmpty;
}
```

- [ ] **Step 5: 파서에 region 추출 (`ocr_parser.dart`)**

`_noteLabel` 아래에 region 라벨 정규식 추가:

```dart
final RegExp _regionLabel = RegExp(
  r'^(region|지역)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);
```

`parseOcrText`의 `OcrDraft(...)`에 `region` 추가:

```dart
  return OcrDraft(
    country: _firstMatch(lower, _countries),
    region: _matchRegion(lines),
    roastDate: _matchDate(rawText),
    roastLevel: _firstMatch(lower, _roastKeywords),
    process: _firstMatch(lower, _processKeywords),
    cupNotes: _matchCupNotes(lines),
    chips: _dedupe(lines),
  );
```

`_matchCupNotes` 아래에 `_matchRegion` 추가:

```dart
String? _matchRegion(List<String> lines) {
  for (final line in lines) {
    final m = _regionLabel.firstMatch(line);
    if (m != null) {
      final v = m.group(2)!.trim();
      if (v.isNotEmpty) return v;
    }
  }
  return null;
}
```

- [ ] **Step 6: 폼 프리필 + 하이라이트 (`bean_form_screen.dart`)**

`initState`의 draft 프리필 블록에 region 한 줄 추가(country 다음):

```dart
    if (e == null && d != null) {
      if (d.country != null) _components.first.country.text = d.country!;
      if (d.region != null) _components.first.region.text = d.region!;
      if (d.process != null) _components.first.process = d.process!;
      _roast = d.roastLevel;
      _roastDate = d.roastDate;
      if (d.cupNotes.isNotEmpty) _cupNotes.text = d.cupNotes.join(', ');
    }
```

`_componentEditor`의 지역 TextField에 하이라이트 추가(`const` 제거):

```dart
          Expanded(child: TextField(
              key: Key('field-region-$i'),
              controller: comp.region,
              decoration: InputDecoration(
                  labelText: '지역',
                  helperText: i == 0 && _auto && widget.draft!.region != null ? 'OCR 자동' : null))),
```

- [ ] **Step 7: GREEN + analyze + 전체**

Run: `flutter test test/unit/ocr_parser_test.dart test/widget/ocr_form_test.dart`
Expected: 전체 PASS(새 테스트 포함).
Run: `flutter analyze`
Expected: No issues.
Run: `flutter test`
Expected: 전체 green(+3 새 테스트).

- [ ] **Step 8: Commit**

```bash
git add lib/features/beans/ocr/ocr_draft.dart lib/features/beans/ocr/ocr_parser.dart lib/features/beans/bean_form_screen.dart test/unit/ocr_parser_test.dart test/widget/ocr_form_test.dart
git commit -m "feat(m3.2): auto-fill region from Region:/지역: label in OCR"
```

---

## Self-Review

**Spec coverage:** 라벨 추출(Step 5) · OcrDraft.region(Step 4) · 폼 프리필+하이라이트(Step 6) · 라벨-only(국가 라벨 비충돌 테스트 Step 1). ✅
**Placeholder scan:** 없음. ✅
**Type consistency:** `OcrDraft.region`(String?) 추가가 기존 호출부(모두 named args) 무손상. `region:` 채움이 draft 필드와 일치. 폼 프리필이 `_components.first.region` 사용(M3.1 지역 필드와 동일 컨트롤러). ✅
**주의:** 지역 라벨 정규식은 줄-시작 앵커라 `원산지:`(국가)와 충돌 안 함 — Step 1 음성 테스트로 가드. 지역 칸 helperText 추가로 `const InputDecoration` → 비-const 전환 필요(그대로 두면 컴파일 에러).
