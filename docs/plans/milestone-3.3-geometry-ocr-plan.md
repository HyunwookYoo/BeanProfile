# M3.3 좌표 기반 OCR 파싱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실제형(콜론 없는 2열 레이아웃) OCR 카드에서 지역·컵노트·제품명·로스터리를 좌표 기반으로 자동채움한다.

**Architecture:** `OcrService.recognize`를 `String` → `List<OcrLine>`(텍스트+boundingBox 좌표)로 확장하고, 새 `parseOcr(List<OcrLine>)` 코어가 라벨↔값을 공간적으로(같은 행·오른쪽 → 아래) 매칭한다. 제품명·로스터리는 글자 크기(타이포) 휴리스틱으로 추정한다. 콜론/키워드/칩 폴백을 유지해 기존 카드·테스트는 비회귀. 파서를 먼저 부가적으로 만든 뒤(Task 1·2) seam을 뒤집는다(Task 3).

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, google_mlkit_text_recognition 0.16.0(한국어 팩 설치됨), flutter_riverpod 3.x, drift(무변경). 테스트: flutter_test(호스트 3계층) + integration_test(에뮬레이터 실측).

**Spec:** `docs/plans/milestone-3.3-geometry-ocr-design.md`

## Global Constraints

- 한국어 UI 문자열. 오프라인·로컬 전용(네트워크 없음).
- 데이터 모델·저장소·DB·`OcrDraft`·`bean_form_screen` **무변경**.
- ML Kit 한국어 팩은 이미 설치됨(iOS pod + Android gradle) — 건드리지 않는다.
- SDD: 구현·리뷰·수정 sonnet, 최종 리뷰 opus. main 직접 커밋. 진행원장 `.superpowers/sdd/progress.md`에 M3.3 섹션 추가(gitignore, controller 소유).
- 커밋 트레일러: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- 각 커밋 전 `flutter analyze`(0 이슈) + 관련 테스트 green. 목표 릴리스 **v0.3.3**.
- `parseOcr`의 모든 공간 임계값은 라벨 높이(`label.height`) 단위 → 이미지 스케일 불변.

## File Structure

- `lib/services/ocr_service.dart` — `OcrLine` 값 타입 추가(Task 1), `recognize` 시그니처 `List<OcrLine>` + ML Kit 매핑(Task 3).
- `lib/features/beans/ocr/ocr_parser.dart` — `parseOcr(List<OcrLine>)` 코어(Task 1·2) + `parseOcrText(String)` 하위호환 래퍼(Task 1).
- `lib/features/beans/add_bean_sheet.dart` — 호출부를 `parseOcr(lines)`로(Task 3).
- `test/helpers.dart` — `FakeOcrService.lines(...)`/`.text(...)`(Task 3).
- `test/unit/ocr_parser_test.dart` — `parseOcr` 공간/타이포 테스트 추가(Task 1·2), 기존 문자열 테스트 유지.
- `test/widget/add_bean_sheet_test.dart` — `FakeOcrService.text(...)`로 갱신(Task 3).
- `integration_test/ocr_probe_test.dart` — `recognize→parseOcr` 갱신 + 스타일 카드 필드 단언(Task 4).

---

### Task 1: `parseOcr` 코어 — OcrLine 타입 + 좌표 라벨→값(지역·컵노트) + 문자열 래퍼

순수 부가 작업: `recognize`는 아직 `String` 반환. `OcrLine`을 추가하고 `parseOcr`를 만들며 `parseOcrText`를 그 래퍼로 리팩터. 소비자(add_bean_sheet) 무변경 → 저장소 계속 컴파일·green.

**Files:**
- Modify: `lib/services/ocr_service.dart` (OcrLine 클래스 추가; recognize는 이번엔 유지)
- Modify: `lib/features/beans/ocr/ocr_parser.dart`
- Test: `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Produces: `class OcrLine { String text; double left,top,right,bottom; double get centerX/centerY/height/width; }` (const 생성자, 이름있는 좌표 인자 기본 0). `OcrDraft parseOcr(List<OcrLine> lines)`. `OcrDraft parseOcrText(String rawText)`(래퍼).

- [ ] **Step 1: `OcrLine` 타입 추가**

`lib/services/ocr_service.dart` 상단(import 아래, `abstract class OcrService` 위)에 추가:

```dart
/// OCR 한 줄: 텍스트 + 이미지 픽셀 좌표(boundingBox). 순수 Dart라 호스트 테스트에서 직접 생성 가능.
class OcrLine {
  final String text;
  final double left, top, right, bottom;
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
  double get width => right - left;
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`test/unit/ocr_parser_test.dart` 상단 import에 추가: `import 'package:beanprofile/services/ocr_service.dart';`
파일 끝(마지막 `}` 앞)에 그룹 추가:

```dart
  group('parseOcr 좌표 라벨→값', () {
    test('같은 행 오른쪽 값 → region', () {
      final d = parseOcr(const [
        OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130),
        OcrLine('후일라', left: 120, top: 100, right: 260, bottom: 130),
      ]);
      expect(d.region, '후일라');
    });
    test('라벨 아래 값 → cupNotes(구분자 분리)', () {
      final d = parseOcr(const [
        OcrLine('컵노트', left: 10, top: 200, right: 90, bottom: 230),
        OcrLine('딸기, 복숭아, 레드와인', left: 10, top: 240, right: 400, bottom: 270),
      ]);
      expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    });
    test('값 없으면 region null', () {
      final d = parseOcr(const [OcrLine('지역', left: 10, top: 100, right: 60, bottom: 130)]);
      expect(d.region, isNull);
    });
    test('2열 카드: 지역=같은 행, 국가=키워드', () {
      final d = parseOcr(const [
        OcrLine('원산지', left: 10, top: 100, right: 70, bottom: 130),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 180),
        OcrLine('콜롬비아', left: 120, top: 100, right: 260, bottom: 130),
        OcrLine('후일라', left: 120, top: 150, right: 260, bottom: 180),
      ]);
      expect(d.country, 'Colombia');
      expect(d.region, '후일라');
    });
  });
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/unit/ocr_parser_test.dart`
Expected: 컴파일 실패 — `parseOcr` 미정의.

- [ ] **Step 4: `parseOcr` + 헬퍼 구현, `parseOcrText`를 래퍼로**

`lib/features/beans/ocr/ocr_parser.dart` 상단 import에 추가: `import '../../../services/ocr_service.dart';`
`_roasterLabel` 정의 아래에 토큰/헬퍼 추가:

```dart
const Set<String> _regionTokens = {'지역', 'region'};
const Set<String> _cupTokens = {
  '컵노트', '컵 노트', 'notes', 'cup notes', 'cup note', 'tasting notes', '향미',
};

/// 값 줄이 라벨로 오인되지 않도록: 트림·소문자·후행 콜론 제거 후 토큰과 정확히 일치.
bool _isBareLabel(String text) {
  final t = text.trim().toLowerCase().replaceAll(RegExp(r'[:：]\s*$'), '').trim();
  return _regionTokens.contains(t) || _cupTokens.contains(t);
}

/// 토큰의 바레-라벨 줄을 찾아 공간적으로 값을 매칭.
String? _spatialValue(List<OcrLine> lines, Set<String> tokens) {
  for (final label in lines) {
    final t = label.text.trim().toLowerCase().replaceAll(RegExp(r'[:：]\s*$'), '').trim();
    if (!tokens.contains(t)) continue;
    final v = _valueFor(lines, label);
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// 라벨 줄의 값: ① 같은 행·오른쪽 → 없으면 ② 바로 아래(최근접).
String? _valueFor(List<OcrLine> lines, OcrLine label) {
  final h = label.height <= 0 ? 1.0 : label.height;
  OcrLine? best;
  for (final v in lines) {
    if (identical(v, label) || v.text.trim().isEmpty || _isBareLabel(v.text)) continue;
    final aligned = (v.centerY - label.centerY).abs() <= 0.6 * h;
    if (aligned && v.left >= label.right - 0.5 * h) {
      if (best == null || v.left < best.left) best = v;
    }
  }
  if (best != null) return best.text.trim();
  for (final v in lines) {
    if (identical(v, label) || v.text.trim().isEmpty || _isBareLabel(v.text)) continue;
    final below = v.top >= label.bottom - 0.5 * h;
    final xOverlap = v.left <= label.right && v.right >= label.left;
    final sameCol = (v.left - label.left).abs() <= 1.5 * h;
    if (below && (xOverlap || sameCol)) {
      if (best == null || v.top < best.top) best = v;
    }
  }
  return best?.text.trim();
}

List<String> _splitNotes(String s) => s
    .split(RegExp(r'[,/·、]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();
```

기존 `_matchCupNotes`를 `_splitNotes` 사용으로 교체:

```dart
List<String> _matchCupNotes(List<String> lines) {
  for (final line in lines) {
    final m = _noteLabel.firstMatch(line);
    if (m != null) return _splitNotes(m.group(2)!);
  }
  return const [];
}
```

기존 `parseOcrText` 함수 전체를 다음 두 함수로 교체:

```dart
OcrDraft parseOcr(List<OcrLine> lines) {
  final texts = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).toList();
  final joined = texts.join('\n');
  final lower = joined.toLowerCase();

  // 4.1 좌표 라벨→값
  String? region = _spatialValue(lines, _regionTokens);
  final cupSpatial = _spatialValue(lines, _cupTokens);
  var cupNotes = cupSpatial == null ? const <String>[] : _splitNotes(cupSpatial);

  // 4.2 타이포 제목/이브로우 (Task 2에서 채움)
  String? name;
  String? roaster;

  // 4.3 콜론/키워드 폴백
  name ??= _firstLabel(texts, _nameLabel);
  roaster ??= _firstLabel(texts, _roasterLabel);
  region ??= _firstLabel(texts, _regionLabel);
  if (cupNotes.isEmpty) cupNotes = _matchCupNotes(texts);

  return OcrDraft(
    name: name,
    roaster: roaster,
    country: _firstMatch(lower, _countries),
    region: region,
    roastDate: _matchDate(joined),
    roastLevel: _firstMatch(lower, _roastKeywords),
    process: _firstMatch(lower, _processKeywords),
    cupNotes: cupNotes,
    chips: _dedupe(texts),
  );
}

/// 문자열 하위호환: 줄을 세로로 쌓은 합성 라인으로 감싸 parseOcr에 위임.
OcrDraft parseOcrText(String rawText) {
  final texts = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final lines = [
    for (final (i, t) in texts.indexed)
      OcrLine(t, left: 0, top: i * 10.0, right: 100, bottom: i * 10.0 + 10),
  ];
  return parseOcr(lines);
}
```

- [ ] **Step 5: 전체 유닛 테스트 통과 확인**

Run: `flutter test test/unit/ocr_parser_test.dart`
Expected: PASS — 새 `parseOcr` 그룹 + 기존 문자열 테스트(country/roastDate/roastLevel/process/cupNotes/region/name&roaster/chips) 전부 green.

- [ ] **Step 6: 전체 테스트 + 정적분석**

Run: `flutter test && flutter analyze`
Expected: 전 테스트 PASS, analyze 0 이슈(소비자 무변경이라 회귀 없음).

- [ ] **Step 7: 커밋**

```bash
git add lib/services/ocr_service.dart lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_parser_test.dart
git commit -m "feat(m3.3): parseOcr core — spatial label→value (region/cupNotes) + OcrLine

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 타이포 제목/이브로우 (제품명·로스터리) + 오채움 가드

`parseOcr`에 4.2 추가. 여전히 부가 작업(소비자 무변경).

**Files:**
- Modify: `lib/features/beans/ocr/ocr_parser.dart`
- Test: `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Consumes: `parseOcr`, `OcrLine`(Task 1).
- Produces: `(String?, String?) _titleEyebrow(List<OcrLine>)` — (제품명, 로스터리).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/ocr_parser_test.dart` 끝(마지막 `}` 앞)에 추가:

```dart
  group('parseOcr 타이포 제목/이브로우', () {
    test('최대폰트 상단줄=제품명, 그 위 작은줄=로스터리', () {
      final d = parseOcr(const [
        OcrLine('베이스캠프 로스터스', left: 10, top: 10, right: 200, bottom: 30),
        OcrLine('콜롬비아 핑크버번 내추럴', left: 10, top: 40, right: 500, bottom: 90),
        OcrLine('원산지', left: 10, top: 120, right: 70, bottom: 140),
        OcrLine('지역', left: 10, top: 150, right: 60, bottom: 170),
      ]);
      expect(d.name, '콜롬비아 핑크버번 내추럴');
      expect(d.roaster, '베이스캠프 로스터스');
    });
    test('가드: 균일 높이면 name/roaster null', () {
      final d = parseOcr(const [
        OcrLine('원산지', left: 10, top: 10, right: 70, bottom: 30),
        OcrLine('콜롬비아', left: 120, top: 10, right: 260, bottom: 30),
        OcrLine('지역', left: 10, top: 40, right: 60, bottom: 60),
      ]);
      expect(d.name, isNull);
      expect(d.roaster, isNull);
    });
    test('콜론 라벨은 타이포 없이도 폴백으로 채워짐(비회귀)', () {
      expect(parseOcrText('제품명: 예가체프 코체레').name, '예가체프 코체레');
      expect(parseOcrText('로스터리: 아우어사이드').roaster, '아우어사이드');
    });
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/unit/ocr_parser_test.dart -n "타이포"`
Expected: FAIL — `name`/`roaster`가 null(4.2 미구현).

- [ ] **Step 3: `_titleEyebrow` 구현 + parseOcr에 연결**

`ocr_parser.dart`에 `_valueFor` 아래로 추가:

```dart
/// 제품명=상단 최대폰트 줄, 로스터리=그 위 작은 줄. 균일 텍스트면 (null,null)로 오채움 회피.
(String?, String?) _titleEyebrow(List<OcrLine> lines) {
  final real = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (real.length < 2) return (null, null);
  final hs = real.map((l) => l.height).toList()..sort();
  final n = hs.length;
  final medianH = n.isOdd ? hs[n ~/ 2] : (hs[n ~/ 2 - 1] + hs[n ~/ 2]) / 2;
  if (medianH <= 0) return (null, null);
  var title = real.first;
  for (final l in real) {
    if (l.height > title.height) title = l;
  }
  if (title.height < 1.3 * medianH) return (null, null);
  final minTop = real.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final maxBottom = real.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
  if (title.top > minTop + 0.45 * (maxBottom - minTop)) return (null, null);
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
}
```

`parseOcr` 안의 4.2 자리(주석 `// 4.2 타이포 제목/이브로우 (Task 2에서 채움)`와 두 줄 `String? name; String? roaster;`)를 다음으로 교체:

```dart
  // 4.2 타이포 제목/이브로우
  final te = _titleEyebrow(lines);
  String? name = te.$1;
  String? roaster = te.$2;
```

- [ ] **Step 4: 유닛 테스트 통과 확인**

Run: `flutter test test/unit/ocr_parser_test.dart`
Expected: PASS — 타이포 그룹 + 기존 전부 green(문자열 래퍼는 균일 높이라 타이포 미발동, 콜론 폴백 유지).

- [ ] **Step 5: 전체 테스트 + 정적분석**

Run: `flutter test && flutter analyze`
Expected: PASS, 0 이슈.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_parser_test.dart
git commit -m "feat(m3.3): typography title/eyebrow → name/roaster with misfire guard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: seam 뒤집기 — recognize→List<OcrLine>, ML Kit 매핑, FakeOcrService, 호출부

`parseOcr`가 검증됐으니 인터페이스를 기계적으로 교체한다. 저장소가 다시 컴파일·green이 되도록 소비자를 한 태스크에서 함께 갱신.

**Files:**
- Modify: `lib/services/ocr_service.dart` (recognize 시그니처 + ML Kit 매핑)
- Modify: `lib/features/beans/add_bean_sheet.dart`
- Modify: `test/helpers.dart` (FakeOcrService)
- Modify: `test/widget/add_bean_sheet_test.dart` (FakeOcrService.text)

**Interfaces:**
- Consumes: `parseOcr`, `OcrLine`(Task 1).
- Produces: `Future<List<OcrLine>> OcrService.recognize(String)`. `FakeOcrService.lines(List<OcrLine>)`, `factory FakeOcrService.text(String)`.

- [ ] **Step 1: `recognize` 시그니처 + ML Kit 매핑**

`lib/services/ocr_service.dart`의 `abstract class OcrService`와 `MlkitOcrService`를 교체(Task 1에서 추가한 `OcrLine` 클래스는 유지):

```dart
abstract class OcrService {
  /// 이미지의 인식 라인들. 실패/빈 이미지면 빈 리스트.
  Future<List<OcrLine>> recognize(String imagePath);
}

class MlkitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
      final result = await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text,
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                right: line.boundingBox.right,
                bottom: line.boundingBox.bottom),
      ];
    } catch (_) {
      return const []; // 인식 실패/모델 미다운로드 → 빈 리스트(폼의 '자동 인식 실패' 배너로 이어짐)
    }
  }
}
```

- [ ] **Step 2: 호출부를 `parseOcr(lines)`로**

`lib/features/beans/add_bean_sheet.dart`의 `_recognize` 안 `try` 블록에서
`final text = await ref.read(ocrServiceProvider).recognize(path);` + `return parseOcrText(text);`
두 줄을 다음으로 교체:

```dart
    final lines = await ref.read(ocrServiceProvider).recognize(path);
    return parseOcr(lines);
```

(`import 'ocr/ocr_parser.dart';`는 이미 있음 — `parseOcr`도 같은 파일에서 export됨.)

- [ ] **Step 3: `FakeOcrService` 두 생성자로**

`test/helpers.dart`의 `class FakeOcrService` 전체를 교체:

```dart
class FakeOcrService implements OcrService {
  FakeOcrService.lines(this._lines);
  factory FakeOcrService.text(String text) => FakeOcrService.lines([
        for (final (i, t) in _splitText(text).indexed)
          OcrLine(t, left: 0, top: i * 10.0, right: 100, bottom: i * 10.0 + 10),
      ]);
  final List<OcrLine> _lines;
  @override
  Future<List<OcrLine>> recognize(String imagePath) async => _lines;
  static List<String> _splitText(String s) =>
      s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}
```

- [ ] **Step 4: 위젯 테스트의 `FakeOcrService` 호출 갱신**

`test/widget/add_bean_sheet_test.dart`에서 두 곳 교체:
- `ocr: FakeOcrService('Ethiopia\nWashed\nNotes: 블루베리'),` → `ocr: FakeOcrService.text('Ethiopia\nWashed\nNotes: 블루베리'),`
- `ocr: FakeOcrService(''), // 인식 실패 → 빈 텍스트` → `ocr: FakeOcrService.text(''), // 인식 실패 → 빈 라인`

- [ ] **Step 5: 전체 테스트 + 정적분석**

Run: `flutter test && flutter analyze`
Expected: 전 테스트 PASS(촬영→OCR(가짜)→폼 프리필, 빈 결과 폴백 배너, wiring 등), analyze 0 이슈.

- [ ] **Step 6: 커밋**

```bash
git add lib/services/ocr_service.dart lib/features/beans/add_bean_sheet.dart test/helpers.dart test/widget/add_bean_sheet_test.dart
git commit -m "feat(m3.3): recognize() returns List<OcrLine> with coords; wire parseOcr

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 에뮬레이터 프로브 갱신 + 실측 검증

호스트 테스트로는 실제 ML Kit 좌표를 못 만든다. 프로브를 `recognize→parseOcr`로 갱신하고 에뮬레이터에서 스타일 카드가 실제로 채워지는지 확인. 임계값이 실측과 어긋나면 이 태스크에서 조정한다.

**Files:**
- Modify: `integration_test/ocr_probe_test.dart`

**Interfaces:**
- Consumes: `MlkitOcrService.recognize`(List<OcrLine>), `parseOcr`(Task 1·2·3).

- [ ] **Step 1: 프로브를 구조화 입력으로 갱신**

`integration_test/ocr_probe_test.dart`에서 두 테스트 모두 `recognize`→`parseOcr`로 바꾸고, 원문 출력은 라인+좌표로. 테스트 1 본문의
`final text = await MlkitOcrService().recognize(file.path);` … `final d = parseOcrText(text);`
를 다음으로 교체:

```dart
    final lines = await MlkitOcrService().recognize(file.path);
    // ignore: avoid_print
    print('===OCR_LINES_START===');
    for (final l in lines) {
      // ignore: avoid_print
      print('[${l.left.toStringAsFixed(0)},${l.top.toStringAsFixed(0)} '
          '${l.right.toStringAsFixed(0)},${l.bottom.toStringAsFixed(0)}] ${l.text}');
    }
    // ignore: avoid_print
    print('===OCR_LINES_END===');
    final d = parseOcr(lines);
```

테스트 2(원본 카드)도 동일하게 `recognize→parseOcr`로 바꾸고 라벨을 `ORIG_`로. import는 `ocr_parser.dart`(parseOcr)만 있으면 됨.

- [ ] **Step 2: 테스트 1(콜론 카드) 8/8 회귀 단언 유지**

테스트 1의 기존 8개 `expect`(name/roaster/country/region/process/roastLevel/roastDate/cupNotes)는 그대로 둔다.

- [ ] **Step 3: 테스트 2(스타일 카드)에 필드 단언 추가**

테스트 2의 `expect(text, isNotEmpty);`(있다면) 제거하고 다음으로 교체:

```dart
    expect(lines, isNotEmpty);
    expect(d.country, 'Colombia');
    expect(d.process, Process.natural);
    expect(d.roastLevel, RoastLevel.medium);
    expect(d.roastDate, DateTime(2026, 7, 5));
    expect(d.region, '후일라');
    expect(d.cupNotes, ['딸기', '복숭아', '레드와인']);
    expect(d.name, '콜롬비아 핑크버번 내추럴');
    expect(d.roaster, contains('베이스캠프')); // '베이스캠프 로스 터스'(자간 오독 허용)
```

`integration_test/ocr_probe_test.dart` import에 `package:beanprofile/data/enums.dart`가 이미 있음(Process/RoastLevel).

- [ ] **Step 4: 에뮬레이터에서 실행**

Run: `flutter test integration_test/ocr_probe_test.dart -d emulator-5554`
Expected: 두 테스트 PASS. 실패 시 `===OCR_LINES===` 출력의 실제 좌표로 `parseOcr` 임계값(0.6/0.5/1.5/1.3/0.45/0.3) 또는 토큰을 조정하고 재실행. **임계값을 바꾸면 Task 1·2 유닛 테스트도 다시 green인지 확인**(`flutter test`).

- [ ] **Step 5: 커밋**

```bash
git add integration_test/ocr_probe_test.dart lib/features/beans/ocr/ocr_parser.dart
git commit -m "test(m3.3): probe asserts styled card auto-fills region/cupNotes/name/roaster

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 최종 검증 (전 태스크 후)

- [ ] `flutter test` (호스트 3계층) 전부 green + `flutter analyze` 0 이슈.
- [ ] `flutter test integration_test/ocr_probe_test.dart -d emulator-5554` 두 테스트 green(콜론 8/8 + 스타일 카드 지역·컵노트·제품명·로스터리 채움).
- [ ] opus 전체-브랜치 리뷰(SDD 규약).
- [ ] `.superpowers/sdd/progress.md`에 M3.3 완료 기록.
- [ ] 릴리스 준비: 대기 중 커밋(적응형 아이콘, 콜론 제품명/로스터리) + M3.3 → **v0.3.3** (푸시·태그는 사용자 승인 후).
