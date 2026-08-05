# 한/영 병기 블렌드 카드 OCR 파싱 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실기기 실패 카드(UNSPECIALTY `RED CASCARA`)에서 로스터리·컵노트·블렌드 성분이 채워지도록 OCR 파서 규칙 4건을 고친다.

**Architecture:** 파서 전용 변경이다. `ocr_parser.dart`에 "라벨 블록"(한/영 2줄 라벨을 하나로 묶기) 개념을 더해 컵노트 값을 여러 줄 모으고, `_titleEyebrow`가 제목의 다른 언어판을 로스터리로 오인하지 않게 하며, `ocr_component_parser.dart`의 `_isCountryAnchorText`를 완화해 "국가 + 농장/등급" 한 줄짜리 성분을 앵커로 인정한다. UI·스키마·백업·프로바이더·의존성 변경 없음.

**Tech Stack:** Flutter / Dart, 순수 함수 + 호스트 단위 테스트. 새 패키지 없음.

**설계 문서:** [`ocr-bilingual-blend-card-design.md`](./ocr-bilingual-blend-card-design.md) — 측정 근거와 기각된 대안이 거기 있다.

## Global Constraints

- **파서 전용.** `lib/features/beans/ocr/ocr_parser.dart`와 `ocr_component_parser.dart`, 그리고 테스트 파일만 건드린다. UI·drift 스키마·백업 코덱·프로바이더는 손대지 않는다. 마이그레이션 없음.
- **새 의존성 금지.** `pubspec.yaml`을 수정하지 않는다.
- **기존 346개 테스트 회귀 금지.** 특히 `test/unit/ocr_parser_test.dart`의 실기기 좌표 픽스처 2종(`ocr_card_ko` 콜론 카드 8필드 · `ocr_card_orig` 콜론없음 카드 8필드)이 그대로 통과해야 한다.
- **테스트 실행은 Windows 관례를 따른다:** `flutter test --concurrency=1 -r expanded` (병렬 실행 시 출력이 중복돼 판독이 어렵다).
- **`flutter analyze`는 0 유지.**
- **주석은 한국어.** 기존 파일의 주석 밀도·어투를 따른다. "무엇"이 아니라 "왜"를 적는다.
- **에뮬레이터·실기기 불필요.** 호스트 픽스처가 기기 출력을 재현하는 것이 확인됐다(설계 §2.4).
- **커밋 메시지 끝에 다음 줄을 붙인다:**
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

---

## Task 1: 실기기 픽스처 도입 + 이브로우가 제목급이면 건너뛴다

한/영 병기 제목(`RED CASCARA` 위 `레드 카스카라`)에서 `_titleEyebrow`가 **같은 제품명의 영문판**을 로스터리로 잡는다. 진짜 로스터리는 그 위의 `UNSPECIALTY BLEND`다.

**Files:**
- Modify: `test/helpers.dart` (픽스처 상수 추가)
- Modify: `test/unit/ocr_parser_test.dart` (새 group 추가)
- Modify: `lib/features/beans/ocr/ocr_parser.dart:154-191` (`_titleEyebrow`)

**Interfaces:**
- Produces: `redCascaraLines` — `const List<OcrLine>`, `test/helpers.dart`. Task 2·3·4가 그대로 쓴다. **줄 순서를 바꾸지 말 것** (`admitted = [mentions.first]` 등 순서 의존 경로가 있다).

- [ ] **Step 1: 픽스처를 `test/helpers.dart`에 추가**

파일 끝에 붙인다. `OcrLine`은 이미 `package:beanprofile/services/ocr_service.dart`로 import돼 있다.

```dart
// ── 실기기 OCR 좌표 픽스처 ──
// 2026-08-04 Android 에뮬레이터 ML Kit(korean) ORIGINAL 패스 출력.
// 원본 4032x3024 / EXIF orientation 6 → ML Kit이 3024x4032 좌표계로 돌려준 값.
// 줄 순서가 파서 결과에 영향을 준다(순서 의존 경로 있음) — 재정렬 금지.
const redCascaraLines = <OcrLine>[
  OcrLine('블렌딩:', left: 876, top: 2453, right: 1095, bottom: 2520),
  OcrLine('노트:', left: 839, top: 3349, right: 1046, bottom: 3413),
  OcrLine('Blending Info', left: 876, top: 2559, right: 1218, bottom: 2617),
  OcrLine('Notes', left: 875, top: 3451, right: 1034, bottom: 3501),
  OcrLine('UNSPECIALTY BLEND', left: 1191, top: 191, right: 2160, bottom: 260),
  OcrLine('RED CASCARA', left: 1137, top: 511, right: 2303, bottom: 610),
  OcrLine('로스터기:', left: 873, top: 3708, right: 1159, bottom: 3781),
  OcrLine('Roaster', left: 864, top: 3820, right: 1073, bottom: 3874),
  OcrLine('레드 카스카라', left: 1312, top: 773, right: 2127, bottom: 895),
  OcrLine('Thailand Phupanna coffee',
      left: 1329, top: 2465, right: 2096, bottom: 2536),
  OcrLine('bio control Natural 70940%',
      left: 1352, top: 2563, right: 2236, bottom: 2622),
  OcrLine('Ethiopia Sidama Bensa Keramo Ako',
      left: 1327, top: 2745, right: 2394, bottom: 2807),
  OcrLine('GI Natural- 40%', left: 1366, top: 2836, right: 1846, bottom: 2901),
  OcrLine('Colombia Inmaculada Fellow Farnms',
      left: 1327, top: 3017, right: 2393, bottom: 3078),
  OcrLine('Papayo Natural 20%',
      left: 1345, top: 3102, right: 1973, bottom: 3176),
  OcrLine('Raspberrie, Sapphire Grape,',
      left: 1328, top: 3351, right: 2318, bottom: 3443),
  OcrLine('Complexity, Citrus fnish',
      left: 1328, top: 3450, right: 2197, bottom: 3527),
  OcrLine('Stronghold S7X Ver.2',
      left: 1326, top: 3704, right: 2065, bottom: 3780),
];
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test/unit/ocr_parser_test.dart` 끝(마지막 `}` 직전)에 새 group을 넣는다. 파일 상단에 `import '../helpers.dart';`가 없으면 추가한다.

```dart
  group('RED CASCARA 실기기 픽스처(한/영 병기 블렌드 카드)', () {
    test('로스터리는 제목의 영문판이 아니라 그 위 이브로우', () {
      final d = parseOcr(redCascaraLines);

      expect(d.name, '레드 카스카라');
      expect(d.roaster, 'UNSPECIALTY');
    });

    // 가드 — 접미 정리가 이브로우를 빈 문자열로 만들어 기존 null 처리를
    // 빠져나가지 않는지 본다. 수정 전후 모두 통과해야 한다.
    test('이브로우가 원두 타입 토큰뿐이면 로스터리는 비운다', () {
      final d = parseOcr(const [
        OcrLine('BLEND', left: 100, top: 100, right: 260, bottom: 140),
        OcrLine('하우스 블렌드', left: 100, top: 200, right: 700, bottom: 290),
        OcrLine('원산지', left: 100, top: 400, right: 220, bottom: 430),
        OcrLine('브라질', left: 300, top: 400, right: 450, bottom: 430),
      ]);

      expect(d.name, '하우스 블렌드');
      expect(d.roaster, isNull);
    });
  });
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "로스터리는 제목의 영문판이" -r expanded --concurrency=1`
Expected: FAIL — `Expected: 'UNSPECIALTY'  Actual: 'RED CASCARA'`

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "원두 타입 토큰뿐이면" -r expanded --concurrency=1`
Expected: PASS — 이건 가드라서 지금도 통과한다. Step 5에서 여전히 통과하는지가 요점이다.

- [ ] **Step 4: `_titleEyebrow`를 고친다**

`lib/features/beans/ocr/ocr_parser.dart`의 `_titleEyebrow` 이브로우 루프를 아래로 교체한다.

기존:
```dart
  OcrLine? eyebrow;
  for (final l in real) {
    if (identical(l, title)) continue;
    final above = l.bottom <= title.top + 0.3 * title.height;
    final xOverlap = l.left <= title.right && l.right >= title.left;
    if (above && xOverlap && l.height < title.height) {
      if (eyebrow == null || l.bottom > eyebrow.bottom) eyebrow = l;
    }
  }
  return (title.text.trim(), eyebrow?.text.trim());
```

교체:
```dart
  OcrLine? eyebrow;
  for (final l in real) {
    if (identical(l, title)) continue;
    final above = l.bottom <= title.top + 0.3 * title.height;
    final xOverlap = l.left <= title.right && l.right >= title.left;
    // 제목급 크기의 줄은 이브로우가 아니다 — 한/영 병기 제목에서 다른 언어판이
    // 로스터리로 잡히는 걸 막는다. 임계는 제목 판정과 같은 값을 쓴다.
    final titleClass = l.height >= 1.3 * medianH;
    if (above && xOverlap && !titleClass && l.height < title.height) {
      if (eyebrow == null || l.bottom > eyebrow.bottom) eyebrow = l;
    }
  }
  return (title.text.trim(), _stripBeanTypeSuffix(eyebrow?.text.trim()));
```

같은 파일의 `_beanTypeOnly` 선언 바로 아래에 접미 정리를 추가한다.

```dart
final RegExp _beanTypeSuffix = RegExp(
  r'\s+(?:blend|블렌드|single[\s-]*origin|싱글\s*오리진)$',
  caseSensitive: false,
);

/// 이브로우 끝의 원두 타입 토큰을 뗀다 — `UNSPECIALTY BLEND` → `UNSPECIALTY`.
/// 앞에 다른 글자가 있을 때만(`\s+` 요구) 뗀다. 토큰 단독이면 그대로 두어
/// `parseOcr`의 기존 `_beanTypeOnly` 처리가 null로 만들게 한다.
String? _stripBeanTypeSuffix(String? text) {
  if (text == null) return null;
  final stripped = text.replaceFirst(_beanTypeSuffix, '').trim();
  return stripped.isEmpty ? text : stripped;
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "로스터리는 제목의 영문판이" -r expanded --concurrency=1`
Expected: PASS

- [ ] **Step 6: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과. 특히 `ocr_card_orig` 픽스처의 `expect(d.roaster, contains('베이스캠프'))`가 살아 있어야 한다(그 카드의 이브로우 높이 31은 제목급 임계 40.3 미만이라 영향받지 않는다).

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add test/helpers.dart test/unit/ocr_parser_test.dart lib/features/beans/ocr/ocr_parser.dart
git commit -m "$(cat <<'EOF'
fix(ocr): skip title-class lines when picking the roastery eyebrow

A bilingual title stack made _titleEyebrow pick the other-language copy of
the product name as the roastery. Exclude candidates that are themselves
title-sized, and strip a trailing bean-type token from the result.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 라벨 블록 — 한/영 2줄 라벨 옆 컵노트를 여러 줄 모은다

`노트:`(위) / `Notes`(아래) 2줄 라벨이라 각각 다른 값줄과 같은 행에 놓인다. 지금은 `_cupTokens`에 `노트`가 없어 `Notes`로 매칭되고, `_valueFor`가 값을 한 줄만 가져와 앞줄이 통째로 사라진다.

**Files:**
- Modify: `lib/features/beans/ocr/ocr_parser.dart` (`_cupTokens`, `_otherLabelTokens`, 신규 헬퍼 3개, `parseOcr`)
- Modify: `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Consumes: `redCascaraLines` (Task 1)
- Produces: 없음 (파일 내부 private 헬퍼)

- [ ] **Step 1: 실패하는 테스트 두 개를 쓴다**

Task 1이 만든 group 안에 추가한다.

```dart
    test('한/영 2줄 라벨 옆 컵노트를 두 줄 다 가져온다', () {
      final d = parseOcr(redCascaraLines);

      expect(d.cupNotes, [
        'Raspberrie',
        'Sapphire Grape',
        'Complexity',
        'Citrus fnish',
      ]);
    });

    test('값 수집은 다음 라벨 블록에서 멈춘다', () {
      // 상한이 없으면 `로스터기` 블록 오른쪽의 기계 이름이 컵노트로 새어 든다.
      final d = parseOcr(const [
        OcrLine('노트', left: 80, top: 100, right: 160, bottom: 140),
        OcrLine('Notes', left: 80, top: 150, right: 160, bottom: 190),
        OcrLine('딸기, 자두', left: 300, top: 100, right: 600, bottom: 140),
        OcrLine('블루베리', left: 300, top: 150, right: 600, bottom: 190),
        OcrLine('로스터기', left: 80, top: 400, right: 200, bottom: 440),
        OcrLine('Roaster', left: 80, top: 450, right: 200, bottom: 490),
        OcrLine('Stronghold S7X', left: 300, top: 400, right: 600, bottom: 440),
      ]);

      expect(d.cupNotes, ['딸기', '자두', '블루베리']);
    });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "컵노트를 두 줄" -r expanded --concurrency=1`
Expected: FAIL — `Actual: ['Complexity', 'Citrus fnish']` (앞줄 유실)

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "다음 라벨 블록에서 멈춘다" -r expanded --concurrency=1`
Expected: FAIL — 한 줄만 잡히거나 빈 리스트

- [ ] **Step 3: 어휘를 추가한다**

`lib/features/beans/ocr/ocr_parser.dart`의 토큰 집합 둘을 고친다.

```dart
const Set<String> _cupTokens = {
  '컵노트', '컵 노트', '노트', 'notes', 'cup notes', 'cup note', 'tasting notes', '향미',
};
const Set<String> _otherLabelTokens = {
  '원산지','생산지','품종','가공','가공방식','로스팅','로스팅일','고도','제품명','상품명','로스터리','로스터','중량',
  // 어떤 칸에도 매핑하지 않는다 — "값이 아님" 표시 + 값 수집 구간의 종료자 역할.
  // `로스터기`는 특히 중요하다: 이 라벨의 값은 로스팅 기계(예: Stronghold S7X)라
  // 로스터리가 아니고, 라벨로 등록돼 있어야 컵노트 수집이 그 앞에서 멈춘다.
  '블렌딩','블렌딩정보','blending info','로스터기',
  'origin','variety','varietal','process','roast','roast date','roasted','altitude','name','product name','roaster',
};
```

- [ ] **Step 4: 라벨 블록과 값 수집기를 추가한다**

`_isLabel` 정의 아래(=`isKnownOcrLabel` 위)에 넣는다.

```dart
/// 세로로 붙어 있는 같은 열의 라벨 줄 묶음 — 한글 라벨 위, 영문 라벨 아래로
/// 2줄 스택을 이루는 카드가 있어서 라벨 하나를 두 줄로 봐야 한다.
List<List<OcrLine>> _labelBlocks(List<OcrLine> lines) {
  final labels = <OcrLine>[
    for (final line in lines)
      if (_isLabel(line.text) && line.height > 0) line,
  ]..sort((a, b) => a.top.compareTo(b.top));

  final blocks = <List<OcrLine>>[];
  for (final label in labels) {
    List<OcrLine>? target;
    for (final block in blocks) {
      final previous = block.last;
      final scale = previous.height > label.height
          ? previous.height
          : label.height;
      if (previous.left <= label.right &&
          label.left <= previous.right &&
          label.top >= previous.bottom &&
          label.top - previous.bottom <= 1.5 * scale) {
        target = block;
        break;
      }
    }
    if (target == null) {
      blocks.add([label]);
    } else {
      target.add(label);
    }
  }
  return blocks;
}

/// 라벨 블록 오른쪽 열의 값 줄들 — 다음 라벨 블록이 시작되기 전까지. 값이 여러
/// 줄로 이어지는 카드를 위해 `_valueFor`(한 줄)와 별도로 둔다.
List<String> _valuesRightOf(
  List<OcrLine> lines,
  List<List<OcrLine>> blocks,
  List<OcrLine> block, {
  required bool Function(String value) acceptsValue,
}) {
  final h = block.first.height <= 0 ? 1.0 : block.first.height;
  final top = block.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final right = block.map((l) => l.right).reduce((a, b) => a > b ? a : b);
  var upper = double.infinity;
  for (final other in blocks) {
    if (identical(other, block)) continue;
    final otherTop = other.map((l) => l.top).reduce((a, b) => a < b ? a : b);
    if (otherTop > top && otherTop < upper) upper = otherTop;
  }

  final values = <OcrLine>[];
  for (final line in lines) {
    final text = line.text.trim();
    if (text.isEmpty || _isLabel(text) || !acceptsValue(text)) continue;
    if (line.left < right - 0.5 * h) continue;
    if (line.centerY < top - 0.5 * h || line.centerY >= upper) continue;
    values.add(line);
  }
  values.sort((a, b) => a.top.compareTo(b.top));
  return [for (final line in values) line.text.trim()];
}

/// 컵노트 라벨을 품은 블록 오른쪽의 값 줄들. 오른쪽에 값이 없는 카드(값이 라벨
/// 아래에 오는 배치)는 빈 리스트를 돌려 `_spatialValue` 폴백으로 넘긴다.
List<String> _cupNoteBlockValues(List<OcrLine> lines) {
  final blocks = _labelBlocks(lines);
  for (final block in blocks) {
    if (!block.any((line) => _cupTokens.contains(_norm(line.text)))) continue;
    final values = _valuesRightOf(
      lines,
      blocks,
      block,
      acceptsValue: _isCupNoteValue,
    );
    if (values.isNotEmpty) return values;
  }
  return const [];
}
```

- [ ] **Step 5: `parseOcr`에서 블록 수집을 먼저 쓴다**

`parseOcr`의 `// 4.1 좌표 라벨→값` 블록을 교체한다.

기존:
```dart
  String? region = _spatialValue(lines, _regionTokens);
  final cupSpatial = _spatialValue(
    lines,
    _cupTokens,
    acceptsValue: _isCupNoteValue,
  );
  var cupNotes = cupSpatial == null ? const <String>[] : _splitNotes(cupSpatial);
```

교체:
```dart
  String? region = _spatialValue(lines, _regionTokens);
  // 컵노트만 여러 줄을 모은다 — 원래 여러 항목의 나열이라 줄바꿈이 자연스럽다.
  // 지역·제품명은 한 줄이 관례라 과수집 위험이 커서 단일 줄을 유지한다.
  var cupNotes = _splitNotes(_cupNoteBlockValues(lines).join(', '));
  if (cupNotes.isEmpty) {
    final cupSpatial = _spatialValue(
      lines,
      _cupTokens,
      acceptsValue: _isCupNoteValue,
    );
    cupNotes = cupSpatial == null
        ? const <String>[]
        : _splitNotes(cupSpatial);
  }
```

- [ ] **Step 6: 통과를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 2개 PASS, 기존 테스트 전부 PASS.

`ocr_card_orig` 픽스처가 깨지면 폴백이 안 걸린 것이다 — 그 카드는 컵노트 값(`딸기, 복숭아, 레드와인`, left 62)이 라벨(`컵노트`, right 156) **왼쪽 아래**에 있어 `_valuesRightOf`가 빈 리스트를 줘야 하고, 그래야 `_spatialValue`의 아래-폴백이 값을 찾는다.

- [ ] **Step 7: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: 커밋**

```bash
git add lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_parser_test.dart
git commit -m "$(cat <<'EOF'
fix(ocr): collect multi-line cup notes beside bilingual label stacks

Cards that stack a Korean label over its English translation put each label
line on a different row than the value it belongs to, so single-line value
matching kept only the last row. Group adjacent label lines into a block and
collect every value line to its right up to the next block. Register the
labels that bound that range, including the roasting-machine label.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 성분 앵커 완화 — 줄 머리에 국가가 오면 앵커

블렌드 성분이 3개인데 1개만 나온다. `_hasComponentEvidence`의 여러 경로 중 이 배치를 알아볼 수 있는 건 `_hasRepeatedTopology`인데, 그 입구 `_anchorsRepeat`가 `_isCountryAnchorText`를 요구한다. 이 함수는 국가·비율·라벨을 뺀 나머지가 **비어 있어야** 앵커로 인정하므로 `Ethiopia Sidama Bensa Keramo Ako`가 탈락한다. 증거가 0이 되면 `admitted = [mentions.first]`로 첫 언급 하나만 남는다.

**Files:**
- Modify: `lib/features/beans/ocr/ocr_component_parser.dart:642-653` (`_isCountryAnchorText`)
- Modify: `test/unit/ocr_component_parser_test.dart`

**Interfaces:**
- Consumes: `redCascaraLines` (Task 1). `parseOcrComponents(List<OcrLine>) -> List<OcrComponentDraft>`는 기존 공개 함수다.
- Produces: 없음

> 이 시점에는 `Thailand`가 아직 사전에 없어 성분이 **2개**다. 3개는 Task 4에서 완성된다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/unit/ocr_component_parser_test.dart` 끝에 group을 추가한다. 파일 상단에 `import '../helpers.dart';`가 없으면 추가한다.

```dart
  group('RED CASCARA 실기기 픽스처 — 줄머리 국가 앵커', () {
    test('국가 뒤에 농장/등급이 붙어도 성분으로 인정한다', () {
      final components = parseOcrComponents(redCascaraLines);

      expect(components.map((c) => c.country), ['Ethiopia', 'Colombia']);
      expect(components.map((c) => c.ratioPercent), [40, 20]);
      expect(
        components.map((c) => c.process),
        [Process.natural, Process.natural],
      );
    });

    test('줄 중간의 국가 언급만으로는 앵커가 되지 않는다', () {
      final components = parseOcrComponents(const [
        OcrLine('our Ethiopia roast', left: 100, top: 100, right: 700, bottom: 160),
        OcrLine('our Colombia roast', left: 100, top: 300, right: 700, bottom: 360),
      ]);

      expect(components, hasLength(1));
    });
  });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "농장/등급이 붙어도" -r expanded --concurrency=1`
Expected: FAIL — `Actual: ['Ethiopia']` (성분 1개)

- [ ] **Step 3: `_isCountryAnchorText`에 줄머리 분기를 넣는다**

`lib/features/beans/ocr/ocr_component_parser.dart`의 `_isCountryAnchorText`를 교체한다.

```dart
bool _isCountryAnchorText(_CountryMention mention) {
  // ① 국가가 줄 머리에 오면 앵커 — `Ethiopia Sidama Bensa Keramo Ako`처럼 국가
  //    뒤에 농장·지역·등급이 붙는 성분 줄을 살린다. 앵커가 됐다고 성분이 되는
  //    건 아니다. `_hasComponentEvidence`가 여전히 비율이나 반복 토폴로지를
  //    요구하고, 반복 토폴로지는 같은 열의 앵커가 둘 이상이어야 성립한다.
  final prefix = mention.line.text.substring(0, mention.textOffset);
  if (prefix.replaceAll(RegExp(r'[\s\-–—|/·,:：()\[\]#\d]+'), '').isEmpty) {
    return true;
  }
  // ② 기존: 국가·비율·라벨을 빼고 남은 글자가 없으면 앵커.
  var remainder = mention.line.text.replaceRange(
    mention.textOffset,
    mention.textOffset + mention.matchLength,
    ' ',
  );
  remainder = remainder
      .replaceAll(ratioPattern, ' ')
      .replaceFirst(_bareLocalComponentLabel, ' ')
      .replaceAll(RegExp(r'[\s\-–—|/·,:：()\[\]#\d]+'), '');
  return remainder.isEmpty;
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 2개 PASS.

**국가 2개는 맞는데 `ratioPercent`나 `process`가 `null`이면** — 앵커·토폴로지는 열렸고 값 채움 경로가 막힌 것이다. 확인 순서:
1. `_isUnlabeledTableCandidate`가 `GI Natural- 40%` / `Papayo Natural 20%`를 후보로 받는지. 값 줄 셋은 `_nonComponentTableText`(`blend|roast*|notes?|coffee|variety|altitude|product|name`)에 걸리지 않으므로 다른 조건이 원인이다.
2. `_repeatedLayout(mentions)`가 `null`이 아닌지(앵커 2개 이상이면 non-null).
3. `_ownerForLine`은 확인됐다 — 앵커가 세로로 넓게 퍼져(centerY 최근접) 배정되고, 최근접 92 대 차순위 179 이상으로 벌어져 있어 0.5px 동점 가드에 걸리지 않는다.

**국가가 여전히 1개면** `_anchorsRepeat`의 `sameColumn`을 본다(left 차 0 ≤ 124, centerY 차 271.5 ≤ 372이어야 한다).

- [ ] **Step 5: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과. 특히 `ocr_blend_en`·`ocr_dark_blend_en` 관련 기존 성분 테스트가 그대로여야 한다.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/beans/ocr/ocr_component_parser.dart test/unit/ocr_component_parser_test.dart
git commit -m "$(cat <<'EOF'
fix(ocr): treat a line-initial country as a blend component anchor

Component lines that read "country + farm + grade" failed the anchor test,
which required nothing to remain after removing the country and ratio. That
killed repeated-topology detection, so a three-origin blend collapsed to its
first mention. Accept a country that starts the line; evidence rules still
gate whether it becomes a component.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 국가 사전 확장 + 카드 전체 통합 단언

`countryKeywords`에 `Thailand`가 없어 3번째 성분이 후보로도 오르지 못한다.

**Files:**
- Modify: `lib/features/beans/ocr/ocr_component_parser.dart:5-46` (`countryKeywords`)
- Modify: `test/unit/ocr_parser_test.dart` (통합 단언)

**Interfaces:**
- Consumes: `redCascaraLines` (Task 1), Task 2·3의 변경
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

Task 1이 만든 group 안에 추가한다.

```dart
    test('카드 전체 — 성분 3개와 비율, 비율 불명은 null로 남긴다', () {
      final d = parseOcr(redCascaraLines);

      expect(d.typeDecision, OcrTypeDecision.certainBlend);
      expect(
        d.components.map((c) => c.country),
        ['Thailand', 'Ethiopia', 'Colombia'],
      );
      // Thailand의 비율은 복구하지 않는다 — OCR이 `Natural 709 - 40%`를
      // `Natural 70940%`로 붙여 읽어 단어 경계가 사라졌다. 추측해 채우면
      // 조용히 틀린 값이 저장된다.
      expect(d.components.map((c) => c.ratioPercent), [null, 40, 20]);
    });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "성분 3개와 비율" -r expanded --concurrency=1`
Expected: FAIL — `Actual: ['Ethiopia', 'Colombia']`

- [ ] **Step 3: 국가 사전을 늘린다**

`countryKeywords` 맵의 `'ecuador': 'Ecuador', '에콰도르': 'Ecuador',` 다음, 닫는 `};` 앞에 추가한다.

```dart
  'thailand': 'Thailand',
  '태국': 'Thailand',
  'vietnam': 'Vietnam',
  '베트남': 'Vietnam',
  'india': 'India',
  '인도': 'India',
  'laos': 'Laos',
  '라오스': 'Laos',
  'myanmar': 'Myanmar',
  '미얀마': 'Myanmar',
  'papua new guinea': 'Papua New Guinea',
  '파푸아뉴기니': 'Papua New Guinea',
  'timor': 'East Timor',
  '동티모르': 'East Timor',
  'jamaica': 'Jamaica',
  '자메이카': 'Jamaica',
  'hawaii': 'Hawaii',
  '하와이': 'Hawaii',
  // China는 넣지 않는다 — `_matchesIn`이 단어 경계 없는 부분 문자열 매칭이라
  // 니카라과 산지 `Chinandega`를 China로 오인한다.
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart -r expanded --concurrency=1`
Expected: 모두 PASS.

Task 3의 성분 테스트는 이제 2개가 아니라 3개가 되므로 함께 고친다.

```dart
      expect(
        components.map((c) => c.country),
        ['Thailand', 'Ethiopia', 'Colombia'],
      );
      expect(components.map((c) => c.ratioPercent), [null, 40, 20]);
      expect(
        components.map((c) => c.process),
        [Process.natural, Process.natural, Process.natural],
      );
```

- [ ] **Step 5: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/beans/ocr/ocr_component_parser.dart test/unit/ocr_parser_test.dart test/unit/ocr_component_parser_test.dart
git commit -m "$(cat <<'EOF'
feat(ocr): add nine coffee origins to the country dictionary

Thailand was missing, so a 40% component never became a candidate. Add the
Asian and Pacific origins the dictionary lacked. China is deliberately left
out: substring matching would read Nicaragua's Chinandega as China.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 완료 확인

- [ ] `flutter test --concurrency=1 -r expanded` 전체 통과, 기존 346개 중 깨진 것 없음
- [ ] `flutter analyze` → `No issues found!`
- [ ] `git diff --stat main` 이 `ocr_parser.dart` · `ocr_component_parser.dart` · 테스트 3개만 보여준다 (설계의 "파서 전용" 제약)
- [ ] 설계 §5 기대 결과와 대조: 제품명 `레드 카스카라` · 로스터리 `UNSPECIALTY` · 컵노트 4개 · 성분 3개(비율 null/40/20) · `certainBlend`
- [ ] 배포 후 사용자가 실기기에서 같은 카드를 스캔해 확인 (설계 §9 DoD 4)
