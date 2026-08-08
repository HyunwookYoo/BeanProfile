# 인라인 블렌드 행 카드 OCR 파싱 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실기기 실패 카드(One Half Coffee Roastery `HWACHAE BLEND`)에서 블렌드 성분 3개와 로스팅 날짜가 채워지도록 파서 규칙 3건을 고친다.

**Architecture:** 파서 전용 변경이다. `ocr_component_parser.dart`에서 ① 성분 앵커가 접두의 선행 라벨(`info.`)과 선행 비율(`45% `)을 걷어내게 하고, ② 값이 앵커 줄에 인라인으로 들어가는 카드를 위한 반복-토폴로지 갈래를 더하고, ③ 국가 **앞**에 적힌 비율을 읽는다. `ocr_parser.dart`에는 영문 월 이름 날짜 매처를 더한다. UI·스키마·백업·프로바이더·의존성 변경 없음.

**Tech Stack:** Flutter / Dart, 순수 함수 + 호스트 단위 테스트. 새 패키지 없음.

**설계 문서:** [`ocr-inline-blend-card-design.md`](./ocr-inline-blend-card-design.md) — 측정 근거와 기각된 대안(특히 §2.3 제목 수정 기각)이 거기 있다.

## Global Constraints

- **파서 전용.** `lib/features/beans/ocr/ocr_parser.dart`, `lib/features/beans/ocr/ocr_component_parser.dart`, 그리고 테스트 파일만 건드린다. UI·drift 스키마·백업 코덱·프로바이더는 손대지 않는다. 마이그레이션 없음.
- **새 의존성 금지.** `pubspec.yaml`을 수정하지 않는다.
- **기존 356개 테스트가 하나도 깨지지 않을 것.** 특히 실기기 좌표 픽스처 3종(`ocr_card_ko` 콜론 카드 · `ocr_card_orig` 콜론없음 카드 · `redCascaraLines` 한/영 병기 카드)이 그대로 통과해야 한다. (신규 테스트만큼 총계는 늘어난다 — 총계 숫자를 목표로 삼지 않는다.)
- **새 가드마다 뮤테이션 증거를 남긴다.** 가드를 지우거나 뒤집고 해당 테스트를 돌려 **실패하는 것을 확인한 뒤 복원**한다. 명령과 실패 출력을 보고서에 적는다. 직전 브랜치에서 태스크 리뷰 4개를 통과한 테스트 3개가 무력했고(가드를 지워도 초록), 원인은 나중에 추가된 넓은 가드가 먼저 발동해 앞선 판별 테스트를 조용히 무력화한 것이었다.
- **테스트 실행은 Windows 관례를 따른다:** `flutter test --concurrency=1 -r expanded` (병렬 실행 시 출력이 중복돼 판독이 어렵다).
- **`flutter analyze`는 0 유지.**
- **`dart format`을 돌리지 않는다.** 이 레포에는 기존 포맷 드리프트가 있어 전체 포맷을 돌리면 변경이 무관한 잡음에 묻힌다.
- **주석은 한국어.** 기존 파일의 주석 밀도·어투를 따른다. "무엇"이 아니라 "왜"를 적는다.
- **루트의 `AGENTS.md`와 `data/`는 untracked로 둔다.** 각 태스크의 `git add` 경로를 그대로 쓰고 `git add -A`·`git add .`을 쓰지 않는다.
- **에뮬레이터·실기기 불필요.** 호스트 픽스처가 기기 출력을 재현하는 것이 확인됐다(설계 §2.1).
- **커밋 메시지 끝에 다음 줄을 붙인다:** `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

---

## Task 1: 픽스처 + 성분 앵커·인라인 토폴로지 → 성분 3개

설계 §4.1과 §4.3을 **한 태스크로 묶는다.** 둘 중 하나만 해서는 공개 API로 관찰되는 변화가 없기 때문이다 — 앵커만 고치면 여전히 증거가 없어 성분이 1개로 남고, 인라인 갈래만 더하면 `_anchorsRepeat`가 앵커를 요구하므로 도달하지 않는다.

**Files:**
- Modify: `test/helpers.dart` (픽스처 추가)
- Modify: `lib/features/beans/ocr/ocr_component_parser.dart` (`_isCountryAnchorText`, `_hasRepeatedTopologyPair`, 신규 헬퍼 1개 + 정규식 2개)
- Modify: `test/unit/ocr_component_parser_test.dart`

**Interfaces:**
- Produces: `hwachaeLines` — `const List<OcrLine>`, `test/helpers.dart`. Task 2·3·4가 그대로 쓴다. **줄 순서를 바꾸지 말 것** (`admitted = [mentions.first]` 등 순서 의존 경로가 있다).

- [ ] **Step 1: 픽스처를 `test/helpers.dart`에 추가**

파일 끝, 기존 `redCascaraLines` 아래에 붙인다. `OcrLine`은 이미 import돼 있다.

```dart
// 2026-08-08 Android 에뮬레이터 ML Kit(korean) ORIGINAL 패스 출력.
// 원본 4032x3024 / EXIF orientation 6. 줄 순서 유지 — 순서 의존 경로가 있다.
// `Alt 한/영`은 사진에 찍힌 키보드다. 파서가 실제로 견뎌야 하는 입력이라
// 일부러 남긴다(설계 §2.3 — 이 줄이 제품명이 되면 안 된다).
const hwachaeLines = <OcrLine>[
  OcrLine('info. 109% panama blackmoon, geisha, anaerobic n',
      left: 157, top: 1376, right: 1672, bottom: 1442),
  OcrLine('45% ecuador meridiano, typica mejorado, washed',
      left: 301, top: 1450, right: 1818, bottom: 1520),
  OcrLine('45% ethiopia gute mini, 74110 peaberry, washed',
      left: 302, top: 1521, right: 1769, bottom: 1598),
  OcrLine('avour berry bomb, tropicalfruits,',
      left: 155, top: 1743, right: 1196, bottom: 1828),
  OcrLine('igtlk tea, plun sorbet',
      left: 159, top: 1847, right: 954, bottom: 1915),
  OcrLine('Alt 한/영', left: 1244, top: 202, right: 1661, bottom: 311),
  OcrLine('a Cotee Roastery', left: 366, top: 2260, right: 885, bottom: 2328),
  OcrLine('NSI or quaity, seasonality, and harmony.',
      left: 229, top: 2344, right: 1455, bottom: 2407),
  OcrLine('HWACHAE BLEND', left: 2173, top: 1377, right: 2979, bottom: 1452),
  OcrLine('Designed for', left: 2172, top: 1495, right: 2737, bottom: 1593),
  OcrLine('UNSPECIALTY', left: 2171, top: 1616, right: 2800, bottom: 1697),
  OcrLine('13 JUL 2026', left: 2353, top: 2198, right: 2956, bottom: 2340),
  OcrLine('Roasted in Malaysia',
      left: 2162, top: 2347, right: 2727, bottom: 2406),
];
```

- [ ] **Step 2: 실패하는 테스트 세 개를 쓴다**

`test/unit/ocr_component_parser_test.dart` 끝(마지막 `}` 직전)에 새 group을 넣는다. 이 파일은 이미 `import '../helpers.dart';`를 갖고 있다.

**이 태스크에서는 `ratioPercent`를 단언하지 않는다.** 국가 앞의 비율을 읽는 것은 Task 2이며, 그 전까지 비율이 어떤 값이 되는지는 확인되지 않았다. 여기서 섣불리 고정하면 Task 2의 RED가 무의미해진다.

```dart
  group('HWACHAE 실기기 픽스처 — 인라인 성분 행', () {
    test('선행 라벨·선행 비율이 붙은 세 줄이 모두 성분이 된다', () {
      final components = parseOcrComponents(hwachaeLines);

      expect(
        components.map((c) => c.country),
        ['Panama', 'Ecuador', 'Ethiopia'],
      );
    });

    test('선행 라벨을 걷어내도 산문 줄은 앵커가 아니다', () {
      // `info` 제거 후에도 `about our`가 남아 앵커가 되면 안 된다.
      // 비율을 일부러 넣지 않는다 — `mention.ratio`가 잡히면 앵커 여부와
      // 무관하게 증거가 성립해 이 테스트가 앵커 규칙을 재지 못한다.
      final components = parseOcrComponents(const [
        OcrLine('Info about our Ethiopia washed beans',
            left: 100, top: 100, right: 900, bottom: 160),
        OcrLine('Info about our Colombia washed beans',
            left: 100, top: 300, right: 900, bottom: 360),
      ]);

      expect(components, hasLength(1));
    });

    test('인라인 성분 데이터가 없는 두 앵커는 인라인 갈래로 붙지 않는다', () {
      // 국가 이름만 있고 비율도 가공도 없는 줄들.
      final components = parseOcrComponents(const [
        OcrLine('Ethiopia', left: 100, top: 100, right: 400, bottom: 160),
        OcrLine('Colombia', left: 100, top: 300, right: 400, bottom: 360),
      ]);

      expect(components, hasLength(1));
    });
  });
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "세 줄이 모두 성분이 된다" -r expanded --concurrency=1`
Expected: FAIL — `Actual: ['Panama']` (성분 1개)

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "산문 줄은 앵커가 아니다" -r expanded --concurrency=1`
Expected: PASS — 이 둘은 가드다. 지금도 통과하는 것이 정상이고, Step 6에서 **여전히** 통과하는지가 요점이다.

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "인라인 갈래로 붙지 않는다" -r expanded --concurrency=1`
Expected: PASS — 같은 이유.

- [ ] **Step 4: 앵커 접두 처리를 고친다**

`lib/features/beans/ocr/ocr_component_parser.dart`의 `_isCountryAnchorText` 바로 위에 정규식 두 개를 추가한다.

```dart
/// `_isCountryAnchorText` ① 갈래 전용 접두 잡음. 기존 문자군에 `%`와 `.`을 더해
/// `45% `·`info. ` 같은 선행 표기를 지운다. ② 갈래는 `ratioPattern`으로 이미
/// 비율을 지우므로 기존 문자군을 그대로 쓴다 — 넓히면 오탐만 는다.
final _anchorPrefixNoise = RegExp(r'[\s\-–—|/·,:：()\[\]#\d%.]+');

/// 성분 줄 앞에 붙는 섹션 라벨 — `info. 45% ethiopia …`의 `info.`.
/// `_bareLocalComponentLabel`은 줄 전체가 라벨인 경우를 보고, 이건 접두만 본다.
final _leadingComponentLabel = RegExp(
  r'^(?:info|origin|원산지|생산지|component|구성|blend|블렌드)\s*[.:：·\-]?\s*',
  caseSensitive: false,
);
```

그리고 `_isCountryAnchorText`의 ① 갈래 두 줄을 교체한다.

기존:
```dart
  final prefix = mention.line.text.substring(0, mention.textOffset);
  if (prefix.replaceAll(RegExp(r'[\s\-–—|/·,:：()\[\]#\d]+'), '').isEmpty) {
    return true;
  }
```

교체:
```dart
  //    접두의 섹션 라벨(`info.`)과 선행 비율(`45% `)도 걷어낸다 — 비율을 국가
  //    앞에 적는 카드가 있다. 라벨을 지운 뒤에도 글자가 남으면 앵커가 아니다.
  final prefix = mention.line.text
      .substring(0, mention.textOffset)
      .replaceFirst(_leadingComponentLabel, '');
  if (prefix.replaceAll(_anchorPrefixNoise, '').isEmpty) {
    return true;
  }
```

② 갈래(`var remainder = …` 이하)는 건드리지 않는다.

- [ ] **Step 5: 인라인 토폴로지 갈래를 더한다**

같은 파일의 `_hasRepeatedTopologyPair` 위에 헬퍼를 추가한다.

```dart
/// 앵커 줄 자체가 성분 데이터를 품고 있는가 — 국가 이름을 뺀 나머지에 비율이나
/// 가공이 있으면 그 줄 하나가 성분 행이다. 값을 별도 줄로 빼지 않고 한 줄에
/// 다 적는 카드(`45% ecuador meridiano, typica mejorado, washed`)를 위한 것.
bool _hasInlineComponentData(_CountryMention mention) {
  final rest = mention.line.text.replaceRange(
    mention.textOffset,
    mention.textOffset + mention.matchLength,
    ' ',
  );
  return ratioPattern.hasMatch(rest) || firstProcessMatch(rest) != null;
}
```

그리고 `_hasRepeatedTopologyPair`의 마지막 `return`을 교체한다.

기존:
```dart
  return bothLocallyLabeled || _hasParallelComponentValues(a, b, lines);
```

교체:
```dart
  // `_hasParallelComponentValues`는 값이 **별도 줄**로 평행하게 놓일 때만
  // 성립한다. 값이 앵커 줄 안에 인라인으로 들어가는 카드를 위해 갈래를 하나 더
  // 둔다. `_anchorsRepeat`가 같은 열과 국가 앵커 텍스트를 이미 요구하므로
  // 무관한 두 줄이 여기로 붙지는 않는다.
  return bothLocallyLabeled ||
      _hasParallelComponentValues(a, b, lines) ||
      (_hasInlineComponentData(a) && _hasInlineComponentData(b));
```

- [ ] **Step 6: 통과를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 3개 PASS, 기존 테스트 전부 PASS.

- [ ] **Step 7: 뮤테이션으로 두 가드의 판별력을 증명한다**

두 변경이 각각 load-bearing인지 확인한다. 매번 **원상 복구**하고 통과를 재확인한다.

1. Step 4의 `.replaceFirst(_leadingComponentLabel, '')`를 지운다 → `--plain-name "세 줄이 모두 성분이 된다"` 실행 → 실패해야 한다(Panama가 앵커를 잃는다). 복구.
2. `_anchorPrefixNoise`에서 `%`를 뺀다 → 같은 테스트 실행 → 실패해야 한다(ecuador·ethiopia가 앵커를 잃는다). 복구.
3. Step 5의 `(_hasInlineComponentData(a) && _hasInlineComponentData(b))` 항을 지운다 → 같은 테스트 실행 → 실패해야 한다. 복구.

각 뮤테이션의 명령·실패 출력·복구 후 통과를 보고서에 적는다. **어느 하나라도 실패하지 않으면(= 지워도 초록이면) 그 사실을 보고하라** — 테스트가 그 가드를 재고 있지 않다는 뜻이고, 내가 알아야 할 정보다.

- [ ] **Step 8: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과. 실기기 픽스처 3종(`ocr_card_ko` · `ocr_card_orig` · `redCascaraLines`)이 특히 중요하다 — 셋 다 접두가 빈 문자열이라 이 변경의 영향을 받지 않아야 한다.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: 커밋**

```bash
git add test/helpers.dart test/unit/ocr_component_parser_test.dart lib/features/beans/ocr/ocr_component_parser.dart
git commit -m "$(cat <<'EOF'
fix(ocr): recognise blend components written one per line

Cards that put a section label and the ratio ahead of the country left every
anchor rejected, so repeated-topology detection never ran and a three-origin
blend collapsed to its first mention. Strip a leading section label and the
leading ratio before the anchor test, and add a topology branch for cards
whose component values sit inline on the anchor line rather than in a
parallel column.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 국가 **앞**의 비율 읽기

**Files:**
- Modify: `lib/features/beans/ocr/ocr_component_parser.dart` (`_countryMentions`)
- Modify: `test/unit/ocr_component_parser_test.dart`

**Interfaces:**
- Consumes: `hwachaeLines` (Task 1)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트 두 개를 쓴다**

Task 1이 만든 `HWACHAE 실기기 픽스처 — 인라인 성분 행` group 안에 추가한다.

```dart
    test('국가 앞에 적힌 비율을 읽는다', () {
      final components = parseOcrComponents(hwachaeLines);

      // Panama는 null로 남는다 — OCR이 `10%`를 `109%`로 읽어 단어 경계가
      // 깨졌다. 추측해 채우면 조용히 틀린 값이 저장된다(설계 §3).
      expect(components.map((c) => c.ratioPercent), [null, 45, 45]);
    });

    test('두 번째 국가는 앞 성분의 비율을 훔치지 않는다', () {
      // Brazil의 "앞 구간"은 Ethiopia의 "뒤 구간"과 같은 span이다.
      final components = parseOcrComponents(const [
        OcrLine('Ethiopia 60% Brazil',
            left: 100, top: 100, right: 900, bottom: 160),
        OcrLine('Natural', left: 100, top: 200, right: 400, bottom: 260),
      ]);

      final brazil = components.where((c) => c.country == 'Brazil');
      expect(brazil.map((c) => c.ratioPercent), everyElement(isNull));
    });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "국가 앞에 적힌 비율을 읽는다" -r expanded --concurrency=1`
Expected: FAIL — 비율이 `[null, null, null]`이거나 그 밖의 값.

**이 테스트가 이미 통과하면 멈추고 보고하라.** Task 1의 변경만으로 비율이 채워졌다는 뜻이고, 그렇다면 이 태스크는 무의미하거나 다른 경로가 값을 만들고 있다. 어느 쪽이든 내가 알아야 한다.

Run: `flutter test test/unit/ocr_component_parser_test.dart --plain-name "앞 성분의 비율을 훔치지" -r expanded --concurrency=1`
Expected: PASS — 가드다. Step 4에서 여전히 통과하는지가 요점이다.

- [ ] **Step 3: `_countryMentions`가 앞 구간도 보게 한다**

`lib/features/beans/ocr/ocr_component_parser.dart`의 `_countryMentions` 안, `final ratioMatch = …` 를 교체한다.

기존:
```dart
      final ratioMatch = ratioPattern.firstMatch(
        line.text.substring(match.offset + match.length, end),
      );
```

교체:
```dart
      var ratioMatch = ratioPattern.firstMatch(
        line.text.substring(match.offset + match.length, end),
      );
      // 비율을 국가 앞에 적는 카드(`45% ecuador …`)를 위해 앞 구간도 본다.
      // 줄의 첫 번째 국가에만 적용한다 — 두 번째부터는 "앞 구간"이 직전 국가의
      // "뒤 구간"과 같은 span이라, 허용하면 앞 성분의 비율을 그대로 훔친다.
      if (ratioMatch == null && i == 0) {
        ratioMatch = ratioPattern.firstMatch(
          line.text.substring(0, match.offset),
        );
      }
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/unit/ocr_component_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 2개 PASS, 기존 테스트 전부 PASS.

- [ ] **Step 5: 뮤테이션으로 판별력을 증명한다**

1. Step 3에서 더한 `if (ratioMatch == null && i == 0) { … }` 블록 전체를 지운다 → `--plain-name "국가 앞에 적힌 비율을 읽는다"` 실행 → 실패해야 한다. 복구.
2. 같은 블록에서 `&& i == 0`만 지운다 → `--plain-name "앞 성분의 비율을 훔치지"` 실행 → 실패해야 한다(Brazil이 60을 가져간다). 복구.

명령·실패 출력·복구 후 통과를 보고서에 적는다. 어느 하나라도 지워도 초록이면 그 사실을 보고하라.

- [ ] **Step 6: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/features/beans/ocr/ocr_component_parser.dart test/unit/ocr_component_parser_test.dart
git commit -m "$(cat <<'EOF'
fix(ocr): read a ratio written ahead of the country

Component lines that lead with the ratio lost it entirely, because the
mention scanner only searched the span after the country name. Search the
span before it too, but only for the first country on a line: for later
ones that span is the previous country's own search range, so allowing it
would hand each component the ratio belonging to the one before it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 영문 월 이름 날짜 (`13 JUL 2026`)

**Files:**
- Modify: `lib/features/beans/ocr/ocr_parser.dart` (`_datePatterns` 아래에 매처 추가, `_dateIn` 확장)
- Modify: `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/unit/ocr_parser_test.dart` 끝(마지막 `}` 직전)에 새 group을 넣는다. 이 파일은 이미 `import '../helpers.dart';`를 갖고 있다.

```dart
  group('영문 월 이름 날짜', () {
    test('약어와 전체 이름을 모두 읽는다', () {
      expect(parseOcrText('13 JUL 2026').roastDate, DateTime(2026, 7, 13));
      expect(parseOcrText('13 July 2026').roastDate, DateTime(2026, 7, 13));
      expect(parseOcrText('1 Mar 2026').roastDate, DateTime(2026, 3, 1));
    });

    test('숫자와 단어가 붙어 있어도 날짜로 오인하지 않는다', () {
      // 이 카드의 `74110 peaberry`가 날짜로 잡히면 안 된다.
      expect(
        parseOcrText('45% ethiopia gute mini, 74110 peaberry, washed').roastDate,
        isNull,
      );
      expect(parseOcrText('13 XYZ 2026').roastDate, isNull);
      expect(parseOcrText('99 JUL 2026').roastDate, isNull);
    });

    test('기존 숫자 형식은 그대로 동작한다', () {
      expect(parseOcrText('로스팅: 2026.07.10').roastDate, DateTime(2026, 7, 10));
      expect(parseOcrText('로스팅: 26.07.02').roastDate, DateTime(2026, 7, 2));
    });
  });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "약어와 전체 이름을 모두 읽는다" -r expanded --concurrency=1`
Expected: FAIL — `Actual: <null>`

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "기존 숫자 형식은" -r expanded --concurrency=1`
Expected: PASS — 비회귀 가드다.

- [ ] **Step 3: 영문 월 매처를 추가한다**

`lib/features/beans/ocr/ocr_parser.dart`의 `_datePatterns` 선언 바로 아래에 추가한다.

```dart
const _englishMonths = <String, int>{
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// `13 JUL 2026` · `13 July 2026`. 연도를 `20xx`로 묶어 `74110 peaberry` 같은
/// 줄이 날짜로 잡히지 않게 한다. `JUL 13 2026`(미국식 순서)은 관측된 적이
/// 없어 넣지 않는다.
final RegExp _englishMonthDate = RegExp(
  r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(20\d{2})\b',
);
```

- [ ] **Step 4: `_dateIn`이 숫자 패턴 뒤에 이 매처를 시도하게 한다**

같은 파일의 `_dateIn`에서, 기존 `for` 루프 뒤이자 `return null;` 앞에 넣는다. 그룹 순서가 (일, 월이름, 연)이라 기존 루프의 (연, 월, 일) 처리와 섞을 수 없어 따로 둔다.

```dart
  final english = _englishMonthDate.firstMatch(s);
  if (english != null) {
    final month =
        _englishMonths[english.group(2)!.toLowerCase().substring(0, 3)];
    final day = int.parse(english.group(1)!);
    if (month != null && day >= 1 && day <= 31) {
      return DateTime(int.parse(english.group(3)!), month, day);
    }
  }
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 3개 PASS, 기존 테스트 전부 PASS.

- [ ] **Step 6: 뮤테이션으로 판별력을 증명한다**

1. Step 4에서 더한 블록 전체를 지운다 → `--plain-name "약어와 전체 이름을 모두 읽는다"` 실행 → 실패해야 한다. 복구.
2. `_englishMonthDate`의 `(20\d{2})`를 `(\d{4})`로 바꾼다 → `--plain-name "날짜로 오인하지 않는다"` 실행 → **`74110 peaberry` 케이스가 여전히 통과하는지 확인**하고, 통과한다면 그 사실을 보고하라(연도 제한이 그 케이스를 막고 있지 않다는 뜻이다). 복구.
3. `month != null && day >= 1 && day <= 31` 조건을 지운다 → `--plain-name "날짜로 오인하지 않는다"` 실행 → 실패해야 한다(`13 XYZ 2026`에서 `_englishMonths` 조회가 null이라 예외가 나거나 `99 JUL 2026`이 통과한다). 복구.

명령·실패 출력·복구 후 통과를 보고서에 적는다.

- [ ] **Step 7: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과. 특히 `ocr_card_ko` 픽스처의 `expect(d.roastDate, DateTime(2026, 7, 10))`이 살아 있어야 한다.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: 커밋**

```bash
git add lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_parser_test.dart
git commit -m "$(cat <<'EOF'
feat(ocr): read dates written with an English month name

A card stamped "13 JUL 2026" left the roast date empty: every existing
pattern wants punctuation separators and a numeric month. Match day, month
name and year separately, restricted to 20xx years so ordinary digit-word
pairs on a bean card are not mistaken for dates.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 카드 전체 통합 단언 + 제목 null 고정

앞의 세 태스크가 각자 자기 조각만 단언했다. 여기서 카드 하나가 통째로 어떤 결과를 내는지 고정하고, 설계 §2.3이 기각한 "제품명 자동 채움"을 코드로 못박는다.

**Files:**
- Modify: `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Consumes: `hwachaeLines` (Task 1), Task 2·3의 변경
- Produces: 없음

- [ ] **Step 1: 성분별 `process`와 `region`의 실제 값을 측정한다**

단언을 지어내지 말고 **먼저 재라.** 아래를 임시 테스트로 추가해 출력만 확인한다.

```dart
  test('TEMP: measure hwachae component fields', () {
    final d = parseOcr(hwachaeLines);
    // ignore: avoid_print
    print('name=${d.name} roaster=${d.roaster} date=${d.roastDate} '
        'notes=${d.cupNotes} type=${d.typeDecision}');
    for (final (i, c) in d.components.indexed) {
      // ignore: avoid_print
      print('component[$i]: country=${c.country} ratio=${c.ratioPercent} '
          'region=${c.region} process=${c.process}');
    }
  });
```

Run: `flutter test test/unit/ocr_parser_test.dart --plain-name "TEMP: measure" -r expanded --concurrency=1`

출력된 `process`·`region` 값을 보고서에 그대로 적는다. 그런 다음 이 임시 테스트를 **지운다**.

**`region`이 지역 이름이 아닌 값(라벨·문구·숫자 섞인 조각)이면 고치려 들지 말고 DONE_WITH_CONCERNS로 보고하라.** 직전 브랜치에서 같은 문제를 만나 "모르면 null" 후속 과제로 남겨둔 상태다(직전 설계 §8). 여기서 휴리스틱을 덧대면 그 결정을 뒤엎게 된다.

- [ ] **Step 2: 통합 단언을 쓴다**

Task 3이 만든 group 아래에 새 group을 넣는다. `process`와 `region`은 **Step 1에서 측정한 값**을 그대로 넣는다.

```dart
  group('HWACHAE 실기기 픽스처 — 카드 전체', () {
    test('성분 3개와 로스팅 날짜가 채워진다', () {
      final d = parseOcr(hwachaeLines);

      expect(d.typeDecision, OcrTypeDecision.certainBlend);
      expect(
        d.components.map((c) => c.country),
        ['Panama', 'Ecuador', 'Ethiopia'],
      );
      expect(d.components.map((c) => c.ratioPercent), [null, 45, 45]);
      expect(d.roastDate, DateTime(2026, 7, 13));
      // ↓ 이 주석 줄을 지우고, Step 1에서 **측정한** 값으로 두 줄을 채운다.
      //   expect(d.components.map((c) => c.process), [...]);
      //   expect(d.components.map((c) => c.region), [...]);
      //   값을 지어내지 말 것 — 측정한 그대로 넣는다. region이 지역 이름이
      //   아니면 여기서 고치지 말고 Step 1의 지시대로 보고한다.
    });

    test('제품명은 비운다 — 사진 속 키보드가 제품명이 되면 안 된다', () {
      final d = parseOcr(hwachaeLines);

      // 이 카드의 제품명 `HWACHAE BLEND`는 높이가 본문 중앙값과 같아
      // 타이포그래피로 찾을 수 없다. 억지로 찾게 만들면 사진에 찍힌 키보드
      // `Alt 한/영`(높이 109)이나 `Designed for`(98)가 제품명이 된다.
      // 비우는 쪽이 옳다 — 설계 §2.3에 계산 근거가 있다.
      expect(d.name, isNull);
    });

    test('컵노트는 비어 있고 로스터리는 OCR이 읽은 그대로다', () {
      final d = parseOcr(hwachaeLines);

      // 라벨 `flavour.`를 OCR이 `avour`로 뭉갰다. 어휘를 넓혀도 못 잡는다.
      expect(d.cupNotes, isEmpty);
      // `Roastery`로 끝나는 유일한 줄을 잡는 규칙은 정상 동작했다.
      // 철자가 틀린 건 OCR 오독이며 파서가 고칠 수 있는 것이 아니다.
      expect(d.roaster, 'a Cotee Roastery');
    });
  });
```

- [ ] **Step 3: 통과를 확인한다**

Run: `flutter test test/unit/ocr_parser_test.dart -r expanded --concurrency=1`
Expected: 새 테스트 3개 PASS.

세 개 중 어느 하나라도 실패하면 단언을 느슨하게 만들지 말고 **실제 값과 함께 보고하라.** §5의 기대와 다른 결과가 나왔다는 뜻이고, 그건 설계가 틀렸다는 정보다.

- [ ] **Step 4: 제목 가드의 판별력을 증명한다**

`_titleEyebrow`(`lib/features/beans/ocr/ocr_parser.dart`)에서 위치 검사 `if (title.top > minTop + 0.45 * (maxBottom - minTop)) return (null, null);` 줄을 지운다 → `--plain-name "제품명은 비운다"` 실행 → **실패해야 한다**. 실패 메시지에 나온 실제 `name` 값을 보고서에 적는다(설계 §2.3의 계산대로면 `13 JUL 2026`이 나온다). 복구하고 통과를 재확인한다.

- [ ] **Step 5: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded`
Expected: 모두 통과

Run: `flutter analyze`
Expected: `No issues found!`

임시 테스트(Step 1)가 남아 있지 않은지 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add test/unit/ocr_parser_test.dart
git commit -m "$(cat <<'EOF'
test(ocr): pin the whole inline blend card outcome

Locks what this card produces end to end, including the two fields that
stay empty on purpose. The product name assertion is the important one: the
name is set at exactly the median text height, so making the typography rule
try harder picks a keyboard that was in frame instead.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 완료 확인

- [ ] `flutter test --concurrency=1 -r expanded` 전체 통과, 기존 356개 중 깨진 것 없음
- [ ] `flutter analyze` → `No issues found!`
- [ ] `git diff --stat main` 이 `ocr_parser.dart` · `ocr_component_parser.dart` · 테스트 3개만 보여준다
- [ ] 새 가드 6개 각각에 뮤테이션 증거(가드 제거 → 해당 테스트 실패 → 복구 → 통과)가 보고서에 남았다
- [ ] 설계 §5 기대 결과와 대조: 성분 `[Panama, Ecuador, Ethiopia]` / 비율 `[null, 45, 45]` / 날짜 `2026-07-13` / 제품명 `null` / 컵노트 비어 있음
- [ ] 배포 후 사용자가 실기기에서 같은 카드를 스캔해 확인 (설계 §9 DoD 5)
