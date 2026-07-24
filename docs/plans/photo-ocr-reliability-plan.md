# 사진 OCR 신뢰성 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사진 촬영·갤러리 입력에서 싱글/블렌드를 안전하게 판별하고 복수 원산지 구성을 올바르게 채우며, 저대비 사진은 조건부 보정 OCR로 개선하고 복구 불가능한 사진은 비차단 재촬영 안내를 제공한다.

**Architecture:** 기존 `PhotoService → OcrService → parseOcr → BeanFormScreen` 흐름에 사진 품질 분석기, OCR 이미지 전처리기, 결정적 후보 점수기, 조건부 `OcrPipeline`을 삽입한다. OCR 초안은 단일 원산지 필드 대신 `OcrComponentDraft[]`와 확실/불명확 유형 판정을 가지며, UI는 품질 경고를 먼저 처리한 뒤 필요한 경우에만 유형을 확인한다.

**Tech Stack:** Flutter 3.44.6, Dart 3.9, Riverpod 3, ML Kit Text Recognition 0.16.0, image 4.9.1, image_picker 1.2.3, drift, flutter_test, integration_test

## Global Constraints

- 모든 처리는 온디바이스·오프라인이어야 하며 서버, 계정, 외부 커피 카탈로그를 추가하지 않는다.
- 기존 M3.3 좌표 기반 라벨↔값, 콜론/키워드 폴백, 칩 배정 UX를 보존한다.
- 원본/최대 품질 파일은 OCR에 사용하고, 저장용 컬러 사진만 JPEG 품질 85로 인코딩한다. 미지원 형식은 원본 복사로 폴백한다.
- OCR 보정은 방향 반영 → 회색조 → 히스토그램 양 끝 1.5% 클립 → 대비 1.2 → 임시 PNG 한 개로 제한한다.
- 두 번째 OCR은 저대비, 제품명 누락, 국가 구성 누락, 유효 줄 4개 미만, 또는 평균 신뢰도 0.65 미만일 때만 실행한다.
- 유형 단서 없음·충돌은 `ambiguous`; 확실한 유형은 묻지 않고, 불명확할 때만 한 번 확인한다.
- 싱글은 제품명과 첫 국가가 필수다. 블렌드는 제품명만 필수이며 구성 0~N개 저장을 허용한다.
- OCR 구성의 가공 방식이 인식되지 않으면 `Process.other`를 사용해 `washed`를 사실처럼 생성하지 않는다.
- 품질 문제와 약한 OCR 결과가 함께 있을 때만 재촬영을 권하고, 사용자는 그대로 진행할 수 있다.
- 실제 상용 카드 사진은 명시적 허가 없이 저장소에 커밋하지 않는다. 공개 저장소에는 합성 픽스처만 둔다.
- 모든 기능은 실패 테스트 → 최소 구현 → 대상 테스트 통과 순서를 지킨다.
- 커밋 전 `flutter analyze`와 관련 테스트를 실행한다. 전체 작업 종료 전 `flutter test`를 실행한다.
- **사용자 커밋 승인 게이트:** 모든 `git commit` 전에 변경 파일·검증 결과·예정 메시지를 사용자에게 먼저 알리고, 명시적 승인을 기다린 뒤에만 커밋한다.

---

## File Map

| 경로 | 책임 |
|---|---|
| `lib/services/ocr_service.dart` | ML Kit 줄 텍스트·좌표·nullable confidence 반환 |
| `lib/services/photo_service.dart` | 최대 품질 촬영/선택, 컬러 사진 품질 85 저장, 미지원 형식 복사 |
| `lib/services/image_quality_analyzer.dart` | 1024px 분석 사본에서 저대비·흐림·강한 하이라이트 판정 |
| `lib/services/ocr_image_preprocessor.dart` | OCR용 보정 PNG 생성·삭제 |
| `lib/features/beans/ocr/ocr_draft.dart` | 복수 구성과 유형 판정이 포함된 OCR 초안 |
| `lib/features/beans/ocr/ocr_type_inference.dart` | 문구·구성 수를 이용한 순수 유형 추론 |
| `lib/features/beans/ocr/ocr_component_parser.dart` | 국가 앵커와 지역·가공·비율을 구성별로 결합 |
| `lib/features/beans/ocr/ocr_parser.dart` | 기존 필드 파싱과 새 구성·유형 파서를 조합 |
| `lib/features/beans/ocr/ocr_candidate.dart` | OCR 후보 순위, 약한 결과 판정, 안전한 보완 |
| `lib/features/beans/ocr/ocr_pipeline.dart` | 품질 분석 → 원본 OCR → 조건부 보정 OCR → 정리 조정 |
| `lib/features/beans/add_bean_sheet.dart` | 품질 경고, 재촬영 루프, 불명확 유형 확인, 폼 진입 |
| `lib/features/beans/bean_form_screen.dart` | 복수 구성 프리필, 불완전 블렌드 경고, 유형 전환 안전성 |
| `lib/providers.dart` | 새 analyzer/preprocessor/pipeline 프로바이더 배선 |
| `test/helpers.dart` | 큐 기반 OCR·사진·파이프라인 페이크와 provider override |
| `scripts/generate_ocr_fixtures.dart` | 공개 가능한 영문 블렌드·저대비·흐림 합성 카드 생성 |
| `integration_test/ocr_probe_test.dart` | 기존 카드 비회귀와 새 파이프라인 실 ML Kit 검증 |

---

### Task 1: OCR 줄·초안 모델을 복수 구성 기반으로 전환

**Files:**
- Modify: `lib/services/ocr_service.dart:4-36`
- Modify: `lib/features/beans/ocr/ocr_draft.dart:1-37`
- Modify: `lib/features/beans/ocr/ocr_parser.dart:170-218`
- Modify: `lib/features/beans/bean_form_screen.dart:10-78`
- Modify: `test/helpers.dart:80-91`
- Modify: `test/unit/ocr_parser_test.dart`
- Modify: `test/widget/ocr_form_test.dart`
- Modify: `integration_test/ocr_probe_test.dart`
- Create: `test/unit/ocr_draft_test.dart`

**Interfaces:**
- Produces: `OcrLine(String text, {double left, double top, double right, double bottom, double? confidence})`, `OcrComponentDraft`, `OcrTypeDecision`, `OcrTypeReason`, `OcrDraft.components`, `OcrDraft.inferredType`
- Preserves: `OcrService.recognize(String) -> Future<List<OcrLine>>`, `parseOcr(List<OcrLine>) -> OcrDraft`

- [ ] **Step 1: Write failing model tests**

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('certain type exposes inferredType', () {
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.certainBlend).inferredType,
      BeanType.blend,
    );
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.certainSingle).inferredType,
      BeanType.singleOrigin,
    );
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.ambiguous).inferredType,
      isNull,
    );
  });

  test('component list is part of non-empty draft', () {
    const draft = OcrDraft(
      components: [OcrComponentDraft(country: 'Ethiopia')],
    );
    expect(draft.isEmpty, isFalse);
    expect(draft.components.single.process, isNull);
  });
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run: `flutter test test/unit/ocr_draft_test.dart`

Expected: FAIL because `OcrComponentDraft`, `OcrTypeDecision`, and the new constructor fields do not exist.

- [ ] **Step 3: Implement the new model and confidence field**

Use this public shape in `ocr_draft.dart`:

```dart
import '../../../data/enums.dart';

enum OcrTypeDecision { certainSingle, certainBlend, ambiguous }

enum OcrTypeReason {
  explicitSingle,
  explicitBlend,
  multipleComponents,
  conflictingSignals,
  insufficientEvidence,
}

class OcrComponentDraft {
  final String? country;
  final String? region;
  final Process? process;
  final int? ratioPercent;
  const OcrComponentDraft({
    this.country,
    this.region,
    this.process,
    this.ratioPercent,
  });

  bool get isEmpty =>
      country == null && region == null && process == null && ratioPercent == null;
}

class OcrDraft {
  final String? name;
  final String? roaster;
  final DateTime? roastDate;
  final RoastLevel? roastLevel;
  final List<OcrComponentDraft> components;
  final List<String> cupNotes;
  final List<String> chips;
  final OcrTypeDecision typeDecision;
  final Set<OcrTypeReason> typeReasons;

  const OcrDraft({
    this.name,
    this.roaster,
    this.roastDate,
    this.roastLevel,
    this.components = const [],
    this.cupNotes = const [],
    this.chips = const [],
    this.typeDecision = OcrTypeDecision.ambiguous,
    this.typeReasons = const {OcrTypeReason.insufficientEvidence},
  });

  BeanType? get inferredType => switch (typeDecision) {
        OcrTypeDecision.certainSingle => BeanType.singleOrigin,
        OcrTypeDecision.certainBlend => BeanType.blend,
        OcrTypeDecision.ambiguous => null,
      };

  bool get isEmpty =>
      name == null &&
      roaster == null &&
      roastDate == null &&
      roastLevel == null &&
      components.every((c) => c.isEmpty) &&
      cupNotes.isEmpty &&
      chips.isEmpty;
}
```

Add `final double? confidence` to `OcrLine`, default it to `null`, and map `line.confidence` in `MlkitOcrService`.

For this task only, keep existing parser behavior by returning zero or one component:

```dart
final country = _firstMatch(lower, _countries);
return OcrDraft(
  name: name,
  roaster: roaster,
  roastDate: _matchDate(joined),
  roastLevel: _firstMatch(lower, _roastKeywords),
  components: country == null
      ? const []
      : [
          OcrComponentDraft(
            country: country,
            region: region,
            process: _firstMatch(lower, _processKeywords),
          ),
        ],
  cupNotes: cupNotes,
  chips: _dedupe(texts),
);
```

Update the form and tests to read/write `draft.components[index]`. Do not keep legacy `OcrDraft(country:, region:, process:)` constructor parameters.

- [ ] **Step 4: Run model, parser, form, and probe compile tests**

Run: `flutter test test/unit/ocr_draft_test.dart test/unit/ocr_parser_test.dart test/widget/ocr_form_test.dart`

Expected: PASS, including all existing M3.3 8-field coordinate fixtures.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, the test/analyze results, and proposed message `refactor(ocr): model structured origin drafts`. Wait for explicit approval.

- [ ] **Step 7: Commit only after approval**

```bash
git add lib/services/ocr_service.dart lib/features/beans/ocr/ocr_draft.dart lib/features/beans/ocr/ocr_parser.dart lib/features/beans/bean_form_screen.dart test/helpers.dart test/unit/ocr_draft_test.dart test/unit/ocr_parser_test.dart test/widget/ocr_form_test.dart integration_test/ocr_probe_test.dart
git commit -m "refactor(ocr): model structured origin drafts"
```

Expected: one commit containing only Task 1 files.

---

### Task 2: 확실/불명확 원두 유형 추론

**Files:**
- Create: `lib/features/beans/ocr/ocr_type_inference.dart`
- Create: `test/unit/ocr_type_inference_test.dart`
- Modify: `lib/features/beans/ocr/ocr_parser.dart:170-205`

**Interfaces:**
- Consumes: `OcrLine`, `OcrComponentDraft`, `OcrTypeDecision`, `OcrTypeReason`
- Produces: `OcrTypeInference inferBeanType(List<OcrLine>, List<OcrComponentDraft>)`

- [ ] **Step 1: Write failing inference tests**

```dart
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_type_inference.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OcrLine line(String text) => OcrLine(text);

  test('explicit Blend is certain without two components', () {
    final result = inferBeanType([line('House Blend')], const []);
    expect(result.decision, OcrTypeDecision.certainBlend);
    expect(result.reasons, contains(OcrTypeReason.explicitBlend));
  });

  test('two structural components are certain blend', () {
    final result = inferBeanType(const [], const [
      OcrComponentDraft(country: 'Brazil'),
      OcrComponentDraft(country: 'Ethiopia'),
    ]);
    expect(result.decision, OcrTypeDecision.certainBlend);
    expect(result.reasons, contains(OcrTypeReason.multipleComponents));
  });

  test('explicit single with one component is certain single', () {
    final result = inferBeanType(
      [line('Single-Origin')],
      const [OcrComponentDraft(country: 'Kenya')],
    );
    expect(result.decision, OcrTypeDecision.certainSingle);
  });

  test('conflicting text or no evidence is ambiguous', () {
    expect(
      inferBeanType([line('Single Origin Blend')], const []).decision,
      OcrTypeDecision.ambiguous,
    );
    expect(
      inferBeanType([line('Ethiopia')], const [
        OcrComponentDraft(country: 'Ethiopia'),
      ]).decision,
      OcrTypeDecision.ambiguous,
    );
    expect(
      inferBeanType([line('Single Estate')], const []).decision,
      OcrTypeDecision.ambiguous,
    );
  });
}
```

- [ ] **Step 2: Run the inference test to verify it fails**

Run: `flutter test test/unit/ocr_type_inference_test.dart`

Expected: FAIL because `inferBeanType` and `OcrTypeInference` do not exist.

- [ ] **Step 3: Implement deterministic inference**

Use an immutable result and boundary-safe phrase normalization:

```dart
class OcrTypeInference {
  final OcrTypeDecision decision;
  final Set<OcrTypeReason> reasons;
  const OcrTypeInference(this.decision, this.reasons);
}

String _normalizedText(List<OcrLine> lines) => lines
    .map((l) => l.text.toLowerCase())
    .join(' ')
    .replaceAll(RegExp(r'[-_]'), ' ')
    .replaceAll(RegExp(r'[^a-z0-9가-힣]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _hasEnglishPhrase(String text, String phrase) =>
    RegExp('(^| )${RegExp.escape(phrase)}( |$)').hasMatch(text);

OcrTypeInference inferBeanType(
  List<OcrLine> lines,
  List<OcrComponentDraft> components,
) {
  final text = _normalizedText(lines);
  final explicitBlend =
      _hasEnglishPhrase(text, 'blend') ||
      _hasEnglishPhrase(text, 'house blend') ||
      text.split(' ').contains('블렌드');
  final explicitSingle =
      _hasEnglishPhrase(text, 'single origin') ||
      text.contains('싱글 오리진');
  final multiple = components.where((c) => c.country != null).length >= 2;

  if ((explicitBlend && explicitSingle) || (explicitSingle && multiple)) {
    return const OcrTypeInference(
      OcrTypeDecision.ambiguous,
      {OcrTypeReason.conflictingSignals},
    );
  }
  if (explicitBlend || multiple) {
    return OcrTypeInference(OcrTypeDecision.certainBlend, {
      if (explicitBlend) OcrTypeReason.explicitBlend,
      if (multiple) OcrTypeReason.multipleComponents,
    });
  }
  if (explicitSingle) {
    return const OcrTypeInference(
      OcrTypeDecision.certainSingle,
      {OcrTypeReason.explicitSingle},
    );
  }
  return const OcrTypeInference(
    OcrTypeDecision.ambiguous,
    {OcrTypeReason.insufficientEvidence},
  );
}
```

Call it at the end of `parseOcr` and copy `decision/reasons` into `OcrDraft`.

- [ ] **Step 4: Run inference and parser tests**

Run: `flutter test test/unit/ocr_type_inference_test.dart test/unit/ocr_parser_test.dart`

Expected: PASS; existing cards without explicit type remain `ambiguous` but retain all 8 parsed fields.

- [ ] **Step 5: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test result, and proposed message `feat(ocr): infer single and blend type`. Wait for explicit approval.

- [ ] **Step 6: Commit only after approval**

```bash
git add lib/features/beans/ocr/ocr_type_inference.dart lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_type_inference_test.dart
git commit -m "feat(ocr): infer single and blend type"
```

Expected: one commit containing only Task 2 files.

---

### Task 3: 국가 앵커 기반 복수 원산지 구성 파싱

**Files:**
- Create: `lib/features/beans/ocr/ocr_component_parser.dart`
- Create: `test/unit/ocr_component_parser_test.dart`
- Modify: `lib/features/beans/ocr/ocr_parser.dart:6-203`
- Modify: `test/unit/ocr_parser_test.dart:115-272`

**Interfaces:**
- Consumes: `List<OcrLine>`
- Produces: `List<OcrComponentDraft> parseOcrComponents(List<OcrLine>)`
- Preserves: single-card region/process behavior and all M3.3 geometry fixtures

- [ ] **Step 1: Write failing component tests**

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_component_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated rows become two ordered components', () {
    final components = parseOcrComponents(const [
      OcrLine('BLEND', left: 20, top: 10, right: 140, bottom: 40),
      OcrLine('Brazil 60%', left: 20, top: 80, right: 240, bottom: 120),
      OcrLine('Cerrado Natural', left: 20, top: 130, right: 300, bottom: 170),
      OcrLine('Ethiopia 40%', left: 20, top: 220, right: 270, bottom: 260),
      OcrLine('Guji Washed', left: 20, top: 270, right: 260, bottom: 310),
    ]);
    expect(components, hasLength(2));
    expect(components[0].country, 'Brazil');
    expect(components[0].region, 'Cerrado');
    expect(components[0].process, Process.natural);
    expect(components[0].ratioPercent, 60);
    expect(components[1].country, 'Ethiopia');
    expect(components[1].region, 'Guji');
    expect(components[1].process, Process.washed);
    expect(components[1].ratioPercent, 40);
  });

  test('inline country ratios preserve textual order', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil 60% / Ethiopia 40%'),
    ]);
    expect(components.map((c) => c.country), ['Brazil', 'Ethiopia']);
    expect(components.map((c) => c.ratioPercent), [60, 40]);
  });

  test('country in unrelated description does not create second component', () {
    final components = parseOcrComponents(const [
      OcrLine('Ethiopia Guji'),
      OcrLine('Roasted in Colombia by Example Roasters'),
    ]);
    expect(components, hasLength(1));
    expect(components.single.country, 'Ethiopia');
  });
}
```

- [ ] **Step 2: Run the component test to verify it fails**

Run: `flutter test test/unit/ocr_component_parser_test.dart`

Expected: FAIL because the component parser does not exist.

- [ ] **Step 3: Implement country mentions, structural admission, and grouping**

Create private `_CountryMention` records with line index, text offset, country, optional ratio, and `OcrLine`. Apply these rules in order:

```dart
const countryKeywords = <String, String>{
  'costa rica': 'Costa Rica', '코스타리카': 'Costa Rica',
  'el salvador': 'El Salvador', '엘살바도르': 'El Salvador',
  'ethiopia': 'Ethiopia', '에티오피아': 'Ethiopia',
  'colombia': 'Colombia', '콜롬비아': 'Colombia',
  'kenya': 'Kenya', '케냐': 'Kenya',
  'brazil': 'Brazil', '브라질': 'Brazil',
  'guatemala': 'Guatemala', '과테말라': 'Guatemala',
  'panama': 'Panama', '파나마': 'Panama',
  'honduras': 'Honduras', '온두라스': 'Honduras',
  'indonesia': 'Indonesia', '인도네시아': 'Indonesia',
  'rwanda': 'Rwanda', '르완다': 'Rwanda',
  'burundi': 'Burundi', '부룬디': 'Burundi',
  'peru': 'Peru', '페루': 'Peru',
  'nicaragua': 'Nicaragua', '니카라과': 'Nicaragua',
  'yemen': 'Yemen', '예멘': 'Yemen',
  'tanzania': 'Tanzania', '탄자니아': 'Tanzania',
  'mexico': 'Mexico', '멕시코': 'Mexico',
  'uganda': 'Uganda', '우간다': 'Uganda',
  'bolivia': 'Bolivia', '볼리비아': 'Bolivia',
  'ecuador': 'Ecuador', '에콰도르': 'Ecuador',
};

final ratioPattern = RegExp(r'\b(100|[1-9]?\d)\s*%');
final bareLocalComponentLabel = RegExp(
  r'^(origin|원산지|생산지|component|구성)(\s*\d+)?\s*[:：]?$',
  caseSensitive: false,
);
```

- Sort keyword matching by key length descending so `Costa Rica` wins before shorter overlaps.
- Evaluate bounded evidence for every country mention before admitting any anchor. If at least one mention has structured/local evidence, admit only evidenced anchors; use the first textual country as the single-origin fallback only when no mention has evidence anywhere.
- Valid anchor evidence is an inline or locally labeled ratio, a separator/ratio-only multi-country line, a genuinely adjacent `Origin/Component` label region, or a repeated row/column coordinate structure made from country-like anchor lines. Descriptive multi-country prose, a `Blend` title, or an `Origin` label elsewhere on the card never admits an address/description country.
- Deduplicate the same country from the same line and coordinate, but keep the same country on a different row/inline segment.
- Associate explicit `Region/Process/Ratio` label values with each anchor by same-row/same-column geometry first, including OCR that emits all country headers before the value columns. In a repeated table, assign bounded unlabeled values by anchor-axis proximity in process → percentage → remaining region order. Use the bounded segment until the next anchor only when geometry is absent or ambiguous. Support `Ratio: 60%`, bare `Ratio` followed by `60%`, and inline country ratios.
- For a one-component result, overwrite its region/process with the existing global geometry parser when that produces a non-null value. This preserves M3.3.
- Move `countryKeywords` and process keyword lookup into the component parser and import them from `ocr_parser.dart`; do not duplicate keyword tables.

- [ ] **Step 4: Integrate component parsing and type inference**

At the end of `parseOcr`:

```dart
final components = parseOcrComponents(lines);
final type = inferBeanType(lines, components);
return OcrDraft(
  name: name,
  roaster: roaster,
  roastDate: _matchDate(joined),
  roastLevel: _firstMatch(lower, _roastKeywords),
  components: components,
  cupNotes: cupNotes,
  chips: _dedupe(texts),
  typeDecision: type.decision,
  typeReasons: type.reasons,
);
```

- [ ] **Step 5: Run component, inference, and full parser tests**

Run: `flutter test test/unit/ocr_component_parser_test.dart test/unit/ocr_type_inference_test.dart test/unit/ocr_parser_test.dart`

Expected: PASS; both existing real-coordinate cards still fill 8 fields, and blend fixtures return two ordered components.

- [ ] **Step 6: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test result, and proposed message `feat(ocr): parse structured blend components`. Wait for explicit approval.

- [ ] **Step 7: Commit only after approval**

```bash
git add lib/features/beans/ocr/ocr_component_parser.dart lib/features/beans/ocr/ocr_parser.dart test/unit/ocr_component_parser_test.dart test/unit/ocr_parser_test.dart
git commit -m "feat(ocr): parse structured blend components"
```

Expected: one commit containing only Task 3 files.

---

### Task 4: 최대 품질 OCR 입력과 저장용 컬러 사진 압축

**Files:**
- Modify: `pubspec.yaml:30-44`
- Modify: `pubspec.lock`
- Modify: `lib/services/photo_service.dart:1-42`
- Create: `test/unit/photo_service_test.dart`

**Interfaces:**
- Preserves: `PhotoService.pick({required bool fromCamera})`, `PhotoService.persist(String)`
- Produces: testable `ImagePickerPhotoService({Future<Directory> Function()? documentsDirectory})`

- [ ] **Step 1: Add direct image dependency**

Add under main dependencies:

```yaml
  image: ^4.9.1
```

Run: `flutter pub get`

Expected: `image` remains at 4.9.1 in `pubspec.lock` and changes from transitive to direct main.

- [ ] **Step 2: Write failing persistence tests**

```dart
import 'dart:io';
import 'package:beanprofile/services/photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory root;
  late ImagePickerPhotoService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('beanprofile-photo-');
    service = ImagePickerPhotoService(documentsDirectory: () async => root);
  });
  tearDown(() => root.delete(recursive: true));

  test('decodable image is persisted as quality-85 jpg', () async {
    final source = File('${root.path}/source.png');
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(40, 80, 120));
    await source.writeAsBytes(img.encodePng(image));

    final result = await service.persist(source.path);

    expect(result, endsWith('.jpg'));
    expect(await img.decodeImageFile(result), isNotNull);
    expect(await File(result).length(), greaterThan(0));
  });

  test('unsupported bytes are copied without failing save', () async {
    final source = File('${root.path}/source.heic');
    const bytes = [0, 1, 2, 3, 4, 5];
    await source.writeAsBytes(bytes);

    final result = await service.persist(source.path);

    expect(result, endsWith('.heic'));
    expect(await File(result).readAsBytes(), bytes);
  });
}
```

- [ ] **Step 3: Run persistence tests to verify they fail**

Run: `flutter test test/unit/photo_service_test.dart`

Expected: FAIL because constructor injection and JPEG encoding do not exist.

- [ ] **Step 4: Implement full-quality pick and safe persistence**

Use this constructor seam and persist algorithm:

```dart
typedef DocumentsDirectory = Future<Directory> Function();

class ImagePickerPhotoService implements PhotoService {
  ImagePickerPhotoService({DocumentsDirectory? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final ImagePicker _picker = ImagePicker();
  final DocumentsDirectory _documentsDirectory;

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    return x?.path;
  }

  @override
  Future<String> persist(String tempPath) async {
    final dir = await _documentsDirectory();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final decoded = await img.decodeImageFile(tempPath);
    if (decoded != null) {
      final dest = '${photos.path}/$stamp.jpg';
      final oriented = img.bakeOrientation(decoded);
      await File(dest).writeAsBytes(img.encodeJpg(oriented, quality: 85));
      return dest;
    }
    final ext = tempPath.contains('.') ? tempPath.split('.').last : 'img';
    final dest = '${photos.path}/$stamp.$ext';
    await File(tempPath).copy(dest);
    return dest;
  }
}
```

Do not pass `imageQuality` to `pickImage`; `null` returns original/max quality.

- [ ] **Step 5: Run persistence and existing photo tests**

Run: `flutter test test/unit/photo_service_test.dart test/unit/photo_path_repository_test.dart test/widget/ocr_form_test.dart`

Expected: PASS; photo path round-trip and form persistence behavior remain intact.

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test/analyze results, and proposed message `feat(photo): preserve OCR input quality`. Wait for explicit approval.

- [ ] **Step 8: Commit only after approval**

```bash
git add pubspec.yaml pubspec.lock lib/services/photo_service.dart test/unit/photo_service_test.dart
git commit -m "feat(photo): preserve OCR input quality"
```

Expected: one commit containing only Task 4 files.

---

### Task 5: 사진 품질 분석기와 OCR 보정 PNG

**Files:**
- Create: `lib/services/image_quality_analyzer.dart`
- Create: `lib/services/ocr_image_preprocessor.dart`
- Create: `test/unit/image_quality_analyzer_test.dart`
- Create: `test/unit/ocr_image_preprocessor_test.dart`

**Interfaces:**
- Produces: `ImageQualityIssue`, `ImageQualityReport`, `ImageQualityAnalyzer.analyze(String)`
- Produces: `OcrImagePreprocessor.enhance(String) -> Future<String>`, `delete(String)`

- [ ] **Step 1: Write failing quality tests with synthetic pixels**

```dart
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  img.Image checker(int a, int b) {
    final image = img.Image(width: 128, height: 128);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = ((x ~/ 8 + y ~/ 8).isEven) ? a : b;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    return image;
  }

  test('narrow luminance range is low contrast', () {
    final report = analyzeDecodedImage(checker(100, 130));
    expect(report.issues, contains(ImageQualityIssue.lowContrast));
  });

  test('sharp black-white edges are not blurry or low contrast', () {
    final report = analyzeDecodedImage(checker(0, 255));
    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
    expect(report.issues, isNot(contains(ImageQualityIssue.blurry)));
  });

  test('large clipped highlight cluster is reported', () {
    final image = img.Image(width: 128, height: 128);
    img.fill(image, color: img.ColorRgb8(30, 30, 30));
    img.fillRect(
      image,
      x1: 16,
      y1: 16,
      x2: 95,
      y2: 95,
      color: img.ColorRgb8(255, 255, 255),
    );
    final report = analyzeDecodedImage(image);
    expect(report.issues, contains(ImageQualityIssue.strongHighlights));
  });
}
```

- [ ] **Step 2: Write failing preprocessor file test**

```dart
import 'dart:io';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('enhance writes grayscale PNG and delete removes it', () async {
    final root = await Directory.systemTemp.createTemp('beanprofile-enhance-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/source.jpg');
    final input = img.Image(width: 64, height: 32);
    img.fill(input, color: img.ColorRgb8(80, 100, 120));
    await source.writeAsBytes(img.encodeJpg(input));
    final service = DartOcrImagePreprocessor(
      temporaryDirectory: () async => root,
    );

    final enhancedPath = await service.enhance(source.path);
    final enhanced = await img.decodeImageFile(enhancedPath);

    expect(enhancedPath, endsWith('.png'));
    expect(enhanced, isNotNull);
    final pixel = enhanced!.getPixel(0, 0);
    expect(pixel.r, pixel.g);
    expect(pixel.g, pixel.b);
    expect(await source.exists(), isTrue);

    await service.delete(enhancedPath);
    expect(await File(enhancedPath).exists(), isFalse);
  });
}
```

- [ ] **Step 3: Run both new tests to verify they fail**

Run: `flutter test test/unit/image_quality_analyzer_test.dart test/unit/ocr_image_preprocessor_test.dart`

Expected: FAIL because the two services and public types do not exist.

- [ ] **Step 4: Implement quality report and normalized analysis**

Use these exact thresholds on a direction-baked grayscale image whose long edge is 1024px:

```dart
enum ImageQualityIssue { lowContrast, blurry, strongHighlights }

class ImageQualityReport {
  final Set<ImageQualityIssue> issues;
  const ImageQualityReport([this.issues = const {}]);
  bool get lowContrast => issues.contains(ImageQualityIssue.lowContrast);
  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class ImageQualityAnalyzer {
  Future<ImageQualityReport> analyze(String imagePath);
}
```

- Low contrast: `(p95 luminance - p05 luminance) < 64` **and** luminance standard deviation `< 30`.
- Blurry: variance of the 3×3 Laplacian response `< 100`.
- Strong highlights: at least 6% of all pixels have luminance ≥250 and at least one 64×64 tile has ≥30% such pixels.
- `DartImageQualityAnalyzer.analyze` uses `Isolate.run`; decode failure returns `const ImageQualityReport()` rather than throwing.
- Keep `analyzeDecodedImage(img.Image)` public for deterministic host tests.

- [ ] **Step 5: Implement one enhanced temporary variant**

```dart
typedef TemporaryDirectory = Future<Directory> Function();

abstract interface class OcrImagePreprocessor {
  Future<String> enhance(String imagePath);
  Future<void> delete(String imagePath);
}

class DartOcrImagePreprocessor implements OcrImagePreprocessor {
  DartOcrImagePreprocessor({TemporaryDirectory? temporaryDirectory})
      : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final TemporaryDirectory _temporaryDirectory;

  @override
  Future<String> enhance(String imagePath) async {
    final dir = await _temporaryDirectory();
    final output =
        '${dir.path}/beanprofile_ocr_${DateTime.now().microsecondsSinceEpoch}.png';
    await Isolate.run(() async {
      var image = await img.decodeImageFile(imagePath);
      if (image == null) throw const FormatException('Unsupported image');
      image = img.bakeOrientation(image);
      image = img.grayscale(image);
      image = img.histogramStretch(
        image,
        mode: img.HistogramEqualizeMode.grayscale,
        stretchClipRatio: 0.015,
      );
      image = img.adjustColor(image, contrast: 1.2);
      await File(output).writeAsBytes(img.encodePng(image));
    });
    return output;
  }

  @override
  Future<void> delete(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      return;
    }
  }
}
```

- [ ] **Step 6: Run service tests and analysis**

Run: `flutter test test/unit/image_quality_analyzer_test.dart test/unit/ocr_image_preprocessor_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test/analyze results, and proposed message `feat(ocr): analyze and enhance input images`. Wait for explicit approval.

- [ ] **Step 8: Commit only after approval**

```bash
git add lib/services/image_quality_analyzer.dart lib/services/ocr_image_preprocessor.dart test/unit/image_quality_analyzer_test.dart test/unit/ocr_image_preprocessor_test.dart
git commit -m "feat(ocr): analyze and enhance input images"
```

Expected: one commit containing only Task 5 files.

---

### Task 6: 결정적 후보 점수와 조건부 두 번째 OCR 파이프라인

**Files:**
- Create: `lib/features/beans/ocr/ocr_candidate.dart`
- Create: `lib/features/beans/ocr/ocr_pipeline.dart`
- Create: `test/unit/ocr_candidate_test.dart`
- Create: `test/unit/ocr_pipeline_test.dart`
- Modify: `test/helpers.dart:80-109`

**Interfaces:**
- Produces: `OcrCandidate`, `isWeakOcr`, `compareOcrCandidates`, `mergeOcrCandidates`
- Produces: `OcrPipeline.analyze(String) -> Future<OcrPipelineResult>`
- Consumes: `OcrService`, `ImageQualityAnalyzer`, `OcrImagePreprocessor`, `parseOcr`

- [ ] **Step 1: Write failing candidate-order tests**

```dart
import 'package:beanprofile/features/beans/ocr/ocr_candidate.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required fields outrank line confidence', () {
    const complete = OcrCandidate(
      lines: [OcrLine('Name: A', confidence: .7), OcrLine('Brazil', confidence: .7)],
      draft: OcrDraft(
        name: 'A',
        components: [OcrComponentDraft(country: 'Brazil')],
      ),
      knownLabelCount: 1,
      fromEnhanced: true,
    );
    const confidentButEmpty = OcrCandidate(
      lines: [OcrLine('Decorative', confidence: .99)],
      draft: OcrDraft(),
      knownLabelCount: 0,
      fromEnhanced: false,
    );
    expect(compareOcrCandidates(complete, confidentButEmpty), greaterThan(0));
  });

  test('merge fills blanks but never overwrites conflicts', () {
    const primary = OcrCandidate(
      lines: [],
      draft: OcrDraft(name: 'Primary'),
      knownLabelCount: 0,
      fromEnhanced: false,
    );
    const secondary = OcrCandidate(
      lines: [],
      draft: OcrDraft(name: 'Secondary', roaster: 'Roaster'),
      knownLabelCount: 0,
      fromEnhanced: true,
    );
    final merged = mergeOcrCandidates(primary, secondary);
    expect(merged.name, 'Primary');
    expect(merged.roaster, 'Roaster');
  });
}
```

- [ ] **Step 2: Write failing orchestration tests**

Define fakes local to `ocr_pipeline_test.dart` and verify these cases:

```dart
test('strong original skips enhancement and second OCR', () async {
  final ocr = QueueOcrService([
    [
      const OcrLine('Name: House Blend', confidence: .9),
      const OcrLine('Brazil', confidence: .9),
      const OcrLine('Natural', confidence: .9),
      const OcrLine('Notes: Cocoa', confidence: .9),
    ],
  ]);
  final preprocessor = FakePreprocessor('/tmp/enhanced.png');
  final pipeline = DefaultOcrPipeline(
    ocr: ocr,
    qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
    preprocessor: preprocessor,
  );

  final result = await pipeline.analyze('/tmp/original.jpg');

  expect(ocr.paths, ['/tmp/original.jpg']);
  expect(preprocessor.enhanceCalls, 0);
  expect(result.usedEnhanced, isFalse);
});

test('low contrast retries once and always deletes temporary image', () async {
  final ocr = QueueOcrService([
    [const OcrLine('Decorative', confidence: .4)],
    [
      const OcrLine('Name: House Blend', confidence: .9),
      const OcrLine('Brazil 60%', confidence: .9),
      const OcrLine('Ethiopia 40%', confidence: .9),
      const OcrLine('Notes: Cocoa', confidence: .9),
    ],
  ]);
  final preprocessor = FakePreprocessor('/tmp/enhanced.png');
  final pipeline = DefaultOcrPipeline(
    ocr: ocr,
    qualityAnalyzer: FakeQualityAnalyzer(
      const ImageQualityReport({ImageQualityIssue.lowContrast}),
    ),
    preprocessor: preprocessor,
  );

  final result = await pipeline.analyze('/tmp/original.jpg');

  expect(ocr.paths, ['/tmp/original.jpg', '/tmp/enhanced.png']);
  expect(preprocessor.deleted, ['/tmp/enhanced.png']);
  expect(result.usedEnhanced, isTrue);
});
```

Add these failure/edge tests in the same file:

```dart
test('analyzer failure still returns original OCR', () async {
  final pipeline = DefaultOcrPipeline(
    ocr: QueueOcrService([
      [
        const OcrLine('Name: A', confidence: .9),
        const OcrLine('Brazil', confidence: .9),
        const OcrLine('Natural', confidence: .9),
        const OcrLine('Notes: Cocoa', confidence: .9),
      ],
    ]),
    qualityAnalyzer: ThrowingQualityAnalyzer(),
    preprocessor: FakePreprocessor('/tmp/enhanced.png'),
  );
  final result = await pipeline.analyze('/tmp/original.jpg');
  expect(result.draft.name, 'A');
  expect(result.quality.issues, isEmpty);
});

test('preprocessor failure keeps weak original and warns only with quality issue', () async {
  final pipeline = DefaultOcrPipeline(
    ocr: QueueOcrService([
      [const OcrLine('Decorative', confidence: .4)],
    ]),
    qualityAnalyzer: FakeQualityAnalyzer(
      const ImageQualityReport({ImageQualityIssue.blurry}),
    ),
    preprocessor: ThrowingPreprocessor(),
  );
  final result = await pipeline.analyze('/tmp/original.jpg');
  expect(result.draft.chips, ['Decorative']);
  expect(result.usedEnhanced, isFalse);
  expect(result.shouldWarnQuality, isTrue);
});

test('all-null confidence is ignored and strong fields suppress warning', () async {
  const candidate = OcrCandidate(
    lines: [
      OcrLine('Name: A'),
      OcrLine('Brazil'),
      OcrLine('Natural'),
      OcrLine('Notes: Cocoa'),
    ],
    draft: OcrDraft(
      name: 'A',
      components: [OcrComponentDraft(country: 'Brazil')],
    ),
    knownLabelCount: 2,
    fromEnhanced: false,
  );
  expect(candidate.meanConfidence, isNull);
  expect(isWeakOcr(candidate), isFalse);
});
```

- [ ] **Step 3: Run candidate and pipeline tests to verify they fail**

Run: `flutter test test/unit/ocr_candidate_test.dart test/unit/ocr_pipeline_test.dart`

Expected: FAIL because candidate and pipeline types do not exist.

- [ ] **Step 4: Implement candidate tuple and safe merge**

```dart
class OcrCandidate {
  final List<OcrLine> lines;
  final OcrDraft draft;
  final int knownLabelCount;
  final bool fromEnhanced;
  const OcrCandidate({
    required this.lines,
    required this.draft,
    required this.knownLabelCount,
    required this.fromEnhanced,
  });

  int get requiredCount =>
      (draft.name == null ? 0 : 1) +
      (draft.components.any((c) => c.country != null) ? 1 : 0);
  int get countryComponentCount =>
      draft.components.where((c) => c.country != null).length;
  double? get meanConfidence {
    final values = lines.map((l) => l.confidence).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

bool isWeakOcr(OcrCandidate candidate) {
  final confidence = candidate.meanConfidence;
  return candidate.draft.name == null ||
      candidate.countryComponentCount == 0 ||
      candidate.lines.where((l) => l.text.trim().isNotEmpty).length < 4 ||
      (confidence != null && confidence < .65);
}
```

Implement lexicographic comparison in this exact order: required count, country component count, total filled scalar+component fields, known label count, mean confidence only if both are non-null, then original over enhanced. `mergeOcrCandidates` fills only missing scalar values, chooses the whole component list with more country-filled components, and appends unique secondary chips.

- [ ] **Step 5: Implement pipeline and cleanup guarantee**

```dart
class OcrPipelineResult {
  final OcrDraft draft;
  final ImageQualityReport quality;
  final bool usedEnhanced;
  final bool shouldWarnQuality;
  const OcrPipelineResult({
    required this.draft,
    required this.quality,
    required this.usedEnhanced,
    required this.shouldWarnQuality,
  });
}

abstract interface class OcrPipeline {
  Future<OcrPipelineResult> analyze(String imagePath);
}

class DefaultOcrPipeline implements OcrPipeline {
  final OcrService ocr;
  final ImageQualityAnalyzer qualityAnalyzer;
  final OcrImagePreprocessor preprocessor;
  const DefaultOcrPipeline({
    required this.ocr,
    required this.qualityAnalyzer,
    required this.preprocessor,
  });

  @override
  Future<OcrPipelineResult> analyze(String imagePath) async {
    ImageQualityReport quality;
    try {
      quality = await qualityAnalyzer.analyze(imagePath);
    } catch (_) {
      quality = const ImageQualityReport();
    }
    final original = buildOcrCandidate(await ocr.recognize(imagePath), false);
    if (!quality.lowContrast && !isWeakOcr(original)) {
      return OcrPipelineResult(
        draft: original.draft,
        quality: quality,
        usedEnhanced: false,
        shouldWarnQuality: false,
      );
    }

    String? enhancedPath;
    OcrCandidate? enhanced;
    try {
      enhancedPath = await preprocessor.enhance(imagePath);
      enhanced = buildOcrCandidate(await ocr.recognize(enhancedPath), true);
    } catch (_) {
      enhanced = null;
    } finally {
      if (enhancedPath != null) await preprocessor.delete(enhancedPath);
    }

    final best = enhanced == null
        ? original
        : compareOcrCandidates(original, enhanced) >= 0
            ? original
            : enhanced;
    final other = identical(best, original) ? enhanced : original;
    final draft = other == null ? best.draft : mergeOcrCandidates(best, other);
    final finalCandidate = OcrCandidate(
      lines: best.lines,
      draft: draft,
      knownLabelCount: best.knownLabelCount,
      fromEnhanced: best.fromEnhanced,
    );
    return OcrPipelineResult(
      draft: draft,
      quality: quality,
      usedEnhanced: best.fromEnhanced,
      shouldWarnQuality: quality.hasIssues && isWeakOcr(finalCandidate),
    );
  }
}
```

`buildOcrCandidate` must call `parseOcr(lines)` and count the known labels already defined by the parser; expose a pure `isKnownOcrLabel(String)` rather than duplicating the label set.

- [ ] **Step 6: Run candidate, pipeline, and parser regressions**

Run: `flutter test test/unit/ocr_candidate_test.dart test/unit/ocr_pipeline_test.dart test/unit/ocr_parser_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test/analyze results, and proposed message `feat(ocr): add conditional enhancement pipeline`. Wait for explicit approval.

- [ ] **Step 8: Commit only after approval**

```bash
git add lib/features/beans/ocr/ocr_candidate.dart lib/features/beans/ocr/ocr_pipeline.dart lib/features/beans/ocr/ocr_parser.dart test/helpers.dart test/unit/ocr_candidate_test.dart test/unit/ocr_pipeline_test.dart
git commit -m "feat(ocr): add conditional enhancement pipeline"
```

Expected: one commit containing only Task 6 files.

---

### Task 7: 파이프라인 프로바이더와 재촬영·유형 확인 흐름

**Files:**
- Modify: `lib/providers.dart:1-31`
- Modify: `lib/features/beans/add_bean_sheet.dart:1-70`
- Modify: `lib/features/beans/bean_form_screen.dart:10-48`
- Modify: `test/helpers.dart:24-108`
- Create: `test/widget/add_bean_sheet_ocr_test.dart`

**Interfaces:**
- Consumes: `OcrPipelineResult`, `OcrDraft.typeDecision`, `OcrDraft.inferredType`
- Produces: `ocrPipelineProvider`, quality choice dialog, ambiguous type dialog, retake loop
- Passes: `BeanFormScreen(initialType:, draft:, photoTempPath:)`

- [ ] **Step 1: Add failing widget harness tests**

```dart
class AddHarness extends ConsumerWidget {
  const AddHarness({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: FilledButton(
          key: const Key('open-add'),
          onPressed: () => showAddBeanSheet(context, ref),
          child: const Text('add'),
        ),
      );
}

Future<void> openCamera(WidgetTester t) async {
  await t.tap(find.byKey(const Key('open-add')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('add-camera')));
  await t.pump();
  await t.pumpAndSettle();
}

testWidgets('certain blend opens form without type dialog', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  final pipeline = FakeOcrPipeline([
    const OcrPipelineResult(
      draft: OcrDraft(
        name: 'House Blend',
        typeDecision: OcrTypeDecision.certainBlend,
        typeReasons: {OcrTypeReason.explicitBlend},
        components: [
          OcrComponentDraft(country: 'Brazil'),
          OcrComponentDraft(country: 'Ethiopia'),
        ],
      ),
      quality: ImageQualityReport(),
      usedEnhanced: false,
      shouldWarnQuality: false,
    ),
  ]);
  await t.pumpWidget(wrapApp(
    const AddHarness(),
    db: db,
    photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
    pipeline: pipeline,
  ));

  await openCamera(t);

  expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
  expect(find.byType(BeanFormScreen), findsOneWidget);
  expect(find.text('OCR 자동'), findsWidgets);
});

testWidgets('ambiguous result asks type exactly once', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const AddHarness(),
    db: db,
    photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
    pipeline: FakeOcrPipeline([
      const OcrPipelineResult(
        draft: OcrDraft(name: 'Mystery Coffee'),
        quality: ImageQualityReport(),
        usedEnhanced: false,
        shouldWarnQuality: false,
      ),
    ]),
  ));

  await openCamera(t);
  expect(find.text('원두 유형을 확인해 주세요'), findsOneWidget);
  await t.tap(find.byKey(const Key('confirm-type-blend')));
  await t.pumpAndSettle();
  expect(find.byType(BeanFormScreen), findsOneWidget);
  expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
});
```

Add these tests in the same file:

```dart
testWidgets('quality warning precedes ambiguous type confirmation', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const AddHarness(),
    db: db,
    photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
    pipeline: FakeOcrPipeline([
      const OcrPipelineResult(
        draft: OcrDraft(name: 'Weak Mystery'),
        quality: ImageQualityReport({ImageQualityIssue.blurry}),
        usedEnhanced: true,
        shouldWarnQuality: true,
      ),
    ]),
  ));
  await openCamera(t);

  expect(find.text('사진을 충분히 읽지 못했어요'), findsOneWidget);
  expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
  await t.tap(find.byKey(const Key('quality-continue')));
  await t.pumpAndSettle();
  expect(find.text('원두 유형을 확인해 주세요'), findsOneWidget);
});

testWidgets('retake discards first draft and uses second photo result', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  final photo = FakePhotoService(
    pickResults: const ['/tmp/first.jpg', '/tmp/second.jpg'],
  );
  final pipeline = FakeOcrPipeline([
    const OcrPipelineResult(
      draft: OcrDraft(name: 'Discard Me'),
      quality: ImageQualityReport({ImageQualityIssue.blurry}),
      usedEnhanced: false,
      shouldWarnQuality: true,
    ),
    const OcrPipelineResult(
      draft: OcrDraft(
        name: 'Keep Me',
        typeDecision: OcrTypeDecision.certainSingle,
        typeReasons: {OcrTypeReason.explicitSingle},
        components: [OcrComponentDraft(country: 'Kenya')],
      ),
      quality: ImageQualityReport(),
      usedEnhanced: false,
      shouldWarnQuality: false,
    ),
  ]);
  await t.pumpWidget(wrapApp(
    const AddHarness(),
    db: db,
    photo: photo,
    pipeline: pipeline,
  ));
  await openCamera(t);
  await t.tap(find.byKey(const Key('quality-retake')));
  await t.pumpAndSettle();

  expect(photo.pickCalls, 2);
  expect(pipeline.paths, ['/tmp/first.jpg', '/tmp/second.jpg']);
  expect(find.text('Keep Me'), findsOneWidget);
  expect(find.text('Discard Me'), findsNothing);
});
```

- [ ] **Step 2: Run widget tests to verify they fail**

Run: `flutter test test/widget/add_bean_sheet_ocr_test.dart`

Expected: FAIL because the pipeline provider, fake, dialogs, and `initialType` parameter do not exist.

- [ ] **Step 3: Wire providers and fakes**

Add these providers:

```dart
final imageQualityAnalyzerProvider = Provider<ImageQualityAnalyzer>(
  (ref) => DartImageQualityAnalyzer(),
);
final ocrImagePreprocessorProvider = Provider<OcrImagePreprocessor>(
  (ref) => DartOcrImagePreprocessor(),
);
final ocrPipelineProvider = Provider<OcrPipeline>(
  (ref) => DefaultOcrPipeline(
    ocr: ref.watch(ocrServiceProvider),
    qualityAnalyzer: ref.watch(imageQualityAnalyzerProvider),
    preprocessor: ref.watch(ocrImagePreprocessorProvider),
  ),
);
```

Extend `wrapApp` with `OcrPipeline? pipeline`. Add a queue-based fake:

```dart
class FakeOcrPipeline implements OcrPipeline {
  FakeOcrPipeline(this.results);
  final List<OcrPipelineResult> results;
  final paths = <String>[];
  var _index = 0;

  @override
  Future<OcrPipelineResult> analyze(String imagePath) async {
    paths.add(imagePath);
    return results[_index++];
  }
}
```

Extend `FakePhotoService` with an optional `List<String?> pickResults`, a `pickCalls` counter, and ordered return values while preserving the existing `pickResult` constructor behavior.

Add `BeanFormScreen.initialType` now so the add flow has a defined consumer before Task 8 expands component behavior:

```dart
class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({
    super.key,
    this.existing,
    this.draft,
    this.initialType,
    this.photoTempPath,
  });
  final BeanDetail? existing;
  final OcrDraft? draft;
  final BeanType? initialType;
  final String? photoTempPath;
}
```

For new beans initialize `_type` from `widget.initialType ?? widget.draft?.inferredType ?? BeanType.singleOrigin`; existing bean type still has highest priority.

- [ ] **Step 4: Implement dialog ordering and retake loop**

Replace `_recognize` with `ref.read(ocrPipelineProvider).analyze(path)` under the existing non-dismissible spinner. Structure the camera/gallery branch as a loop:

```dart
while (context.mounted) {
  final tempPath = await ref
      .read(photoServiceProvider)
      .pick(fromCamera: choice == _AddChoice.camera);
  if (tempPath == null || !context.mounted) return;

  final result = await _analyze(context, ref, tempPath);
  if (result == null || !context.mounted) return;

  if (result.shouldWarnQuality) {
    final qualityChoice = await _showQualityWarning(context);
    if (!context.mounted || qualityChoice == null) return;
    if (qualityChoice == _QualityChoice.retake) continue;
  }

  var type = result.draft.inferredType;
  if (type == null) type = await _confirmBeanType(context);
  if (type == null || !context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BeanFormScreen(
      draft: result.draft,
      initialType: type,
      photoTempPath: tempPath,
    ),
  ));
  return;
}
```

Dialog copy and keys are fixed:

- Quality title: `사진을 충분히 읽지 못했어요`
- Quality body: `사진이 어둡거나 흐리거나 빛이 반사됐을 수 있어요.`
- Buttons: `quality-continue` / `quality-retake`
- Type title: `원두 유형을 확인해 주세요`
- Buttons: `confirm-type-single` / `confirm-type-blend`
- Both dialogs return `null` on system back and terminate the add flow without saving.

- [ ] **Step 5: Run add-flow and existing OCR form tests**

Run: `flutter test test/widget/add_bean_sheet_ocr_test.dart test/widget/ocr_form_test.dart`

Expected: PASS; certain type has no dialog, ambiguous type has one dialog, retake uses the second result, and direct form tests remain green.

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test/analyze results, and proposed message `feat(ocr): confirm uncertain scans and offer retake`. Wait for explicit approval.

- [ ] **Step 8: Commit only after approval**

```bash
git add lib/providers.dart lib/features/beans/add_bean_sheet.dart lib/features/beans/bean_form_screen.dart test/helpers.dart test/widget/add_bean_sheet_ocr_test.dart
git commit -m "feat(ocr): confirm uncertain scans and offer retake"
```

Expected: one commit containing only Task 7 files.

---

### Task 8: 복수 구성 폼·불완전 블렌드 저장·유형 전환 안전성

**Files:**
- Modify: `lib/features/beans/bean_form_screen.dart:10-326`
- Modify: `test/widget/ocr_form_test.dart`
- Modify: `test/widget/bean_form_test.dart`
- Modify: `test/data/bean_repository_test.dart`

**Interfaces:**
- Consumes: `BeanFormScreen.initialType`, `OcrDraft.components`
- Produces: component rows keyed `field-country-N`, `field-region-N`, `field-ratio-N`; incomplete blend banner; safe type transition

- [ ] **Step 1: Write failing multi-component prefill and warning tests**

```dart
testWidgets('blend draft prefills two component rows and ratios', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  t.view.physicalSize = const Size(2400, 4000);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(
      initialType: BeanType.blend,
      draft: OcrDraft(
        typeDecision: OcrTypeDecision.certainBlend,
        components: [
          OcrComponentDraft(
            country: 'Brazil',
            region: 'Cerrado',
            process: Process.natural,
            ratioPercent: 60,
          ),
          OcrComponentDraft(
            country: 'Ethiopia',
            region: 'Guji',
            process: Process.washed,
            ratioPercent: 40,
          ),
        ],
      ),
    ),
    db: db,
  ));
  await t.pump();

  expect(find.byKey(const Key('field-country-0')), findsOneWidget);
  expect(find.byKey(const Key('field-country-1')), findsOneWidget);
  expect(find.text('Brazil'), findsOneWidget);
  expect(find.text('Ethiopia'), findsOneWidget);
  expect(find.text('60'), findsOneWidget);
  expect(find.text('40'), findsOneWidget);
  expect(find.textContaining('충분히 읽지 못했어요'), findsNothing);
});

testWidgets('incomplete blend warns but saves with zero components', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  final repo = testRepository(db);
  t.view.physicalSize = const Size(2400, 4000);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(
      initialType: BeanType.blend,
      draft: OcrDraft(typeDecision: OcrTypeDecision.certainBlend),
    ),
    db: db,
  ));
  await t.pump();

  expect(find.textContaining('아는 내용만 입력해도 저장할 수 있어요'), findsOneWidget);
  await t.enterText(find.byKey(const Key('field-name')), '비공개 블렌드');
  await t.tap(find.byKey(const Key('save-bean')));
  await t.pumpAndSettle();

  final list = await repo.watchBeanSummaries().first;
  final detail = await repo.getBeanDetail(list.single.bean.id);
  expect(list.single.bean.type, BeanType.blend);
  expect(list.single.originLabel, isNull);
  expect(detail!.components, isEmpty);
  await db.close();
});
```

- [ ] **Step 2: Write failing type-transition tests**

Add these tests:

```dart
testWidgets('single to blend preserves first row and adds a second', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(
      draft: OcrDraft(
        components: [OcrComponentDraft(country: 'Kenya')],
      ),
      initialType: BeanType.singleOrigin,
    ),
    db: db,
  ));
  await t.pump();
  await t.tap(find.text('블렌드'));
  await t.pump();
  expect(find.byKey(const Key('field-country-0')), findsOneWidget);
  expect(find.byKey(const Key('field-country-1')), findsOneWidget);
  expect(find.text('Kenya'), findsOneWidget);
});

testWidgets('blend to single can cancel or confirm component removal', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(
      initialType: BeanType.blend,
      draft: OcrDraft(components: [
        OcrComponentDraft(country: 'Brazil'),
        OcrComponentDraft(country: 'Ethiopia'),
      ]),
    ),
    db: db,
  ));
  await t.pump();

  await t.tap(find.text('싱글'));
  await t.pumpAndSettle();
  expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
  await t.tap(find.byKey(const Key('keep-blend')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('field-country-1')), findsOneWidget);

  await t.tap(find.text('싱글'));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('confirm-single')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('field-country-0')), findsOneWidget);
  expect(find.byKey(const Key('field-country-1')), findsNothing);
});

testWidgets('single still requires first country', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(initialType: BeanType.singleOrigin),
    db: db,
  ));
  await t.pump();
  await t.enterText(find.byKey(const Key('field-name')), 'Missing Origin');
  await t.tap(find.byKey(const Key('save-bean')));
  await t.pump();
  expect(find.text('제품명과 첫 원산지 국가는 필수예요'), findsOneWidget);
});

testWidgets('unknown OCR process is shown as other, not washed', (t) async {
  final db = testDatabase();
  addTearDown(db.close);
  await t.pumpWidget(wrapApp(
    const BeanFormScreen(
      draft: OcrDraft(
        components: [OcrComponentDraft(country: 'Kenya')],
      ),
    ),
    db: db,
  ));
  await t.pump();
  final dropdown = t.widget<DropdownButtonFormField<Process>>(
    find.byType(DropdownButtonFormField<Process>).first,
  );
  expect(dropdown.initialValue, Process.other);
});
```

- [ ] **Step 3: Run form tests to verify they fail**

Run: `flutter test test/widget/ocr_form_test.dart test/widget/bean_form_test.dart`

Expected: FAIL because `initialType`, multi-component initialization, warning, and safe transitions are absent.

- [ ] **Step 4: Implement initialization and incomplete blend warning**

Add `final BeanType? initialType` to `BeanFormScreen`. Initialization priority is existing bean → `initialType` → `draft.inferredType` → `BeanType.singleOrigin`.

Build draft rows with this exact fallback:

```dart
for (final component in draft.components) {
  final row = _ComponentDraft();
  row.country.text = component.country ?? '';
  row.region.text = component.region ?? '';
  row.process = component.process ?? Process.other;
  row.ratio.text = component.ratioPercent?.toString() ?? '';
  _components.add(row);
}
if (_components.isEmpty) _components.add(_ComponentDraft());
if (_type == BeanType.blend) {
  while (_components.length < 2) {
    _components.add(_ComponentDraft(process: Process.other));
  }
}
```

Allow `_ComponentDraft({Process process = Process.washed})` so manual entry keeps its current washed default while OCR-created unknown processes use `other`.

Show the approved banner when `_type == BeanType.blend` and fewer than two rows have a non-empty country:

```dart
const Text(
  '블렌드 구성 정보를 충분히 읽지 못했어요. '
  '아는 내용만 입력해도 저장할 수 있어요.',
  key: Key('incomplete-blend-warning'),
)
```

- [ ] **Step 5: Implement validation and type transition**

```dart
Future<void> _changeType(BeanType next) async {
  if (next == _type) return;
  if (next == BeanType.blend) {
    setState(() {
      _type = next;
      while (_components.length < 2) {
        _components.add(_ComponentDraft());
      }
    });
    return;
  }

  final filled = _components.where((c) => c.country.text.trim().isNotEmpty).length;
  if (filled >= 2) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('싱글 오리진으로 변경할까요?'),
        content: const Text('첫 번째 구성만 남아요.'),
        actions: [
          TextButton(
            key: const Key('keep-blend'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-single'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
  }
  setState(() {
    _type = BeanType.singleOrigin;
    for (final row in _components.skip(1)) {
      row.dispose();
    }
    _components.removeRange(1, _components.length);
  });
}
```

Validation becomes:

```dart
final missingName = _name.text.trim().isEmpty;
final missingSingleCountry = _type == BeanType.singleOrigin &&
    _components.first.country.text.trim().isEmpty;
if (missingName || missingSingleCountry) {
  final message = _type == BeanType.singleOrigin
      ? '제품명과 첫 원산지 국가는 필수예요'
      : '제품명은 필수예요';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  return;
}
```

Continue filtering empty-country rows when building `BeanInput.components`. Add `Key('field-ratio-$i')` to ratio fields and call `_changeType` from the segmented button without an immediate `setState`.

- [ ] **Step 6: Run form and repository regressions**

Run: `flutter test test/widget/ocr_form_test.dart test/widget/bean_form_test.dart test/data/bean_repository_test.dart`

Expected: PASS, including zero-component blend list/detail and all existing single save tests.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: Request commit approval**

Run: `git diff --check` and `git diff --stat`

Tell the user the changed files, test/analyze results, and proposed message `feat(beans): review structured OCR components`. Wait for explicit approval.

- [ ] **Step 8: Commit only after approval**

```bash
git add lib/features/beans/bean_form_screen.dart test/widget/ocr_form_test.dart test/widget/bean_form_test.dart test/data/bean_repository_test.dart
git commit -m "feat(beans): review structured OCR components"
```

Expected: one commit containing only Task 8 files.

---

### Task 9: 합성 카드·실 ML Kit 통합 검증·전체 회귀

**Files:**
- Create: `scripts/generate_ocr_fixtures.dart`
- Create: `assets/test/ocr_blend_en.png`
- Create: `assets/test/ocr_dark_blend_en.png`
- Create: `assets/test/ocr_bad_quality_en.png`
- Modify: `pubspec.yaml:87-90`
- Modify: `integration_test/ocr_probe_test.dart`
- Modify: `docs/plans/photo-ocr-reliability-design.md`
- Regenerate: `docs/plans/photo-ocr-reliability-design.html`

**Interfaces:**
- Exercises: `MlkitOcrService` and `DefaultOcrPipeline` on Android emulator/device
- Verifies: existing bright-card non-regression, certain blend, enhanced retry, quality warning

- [ ] **Step 1: Add deterministic ASCII fixture generator**

Use `package:image` built-in bitmap fonts so generation needs no private photo or system font:

```dart
import 'dart:io';
import 'package:image/image.dart' as img;

img.Image card({required img.Color background, required img.Color ink}) {
  final image = img.Image(width: 1080, height: 1440);
  img.fill(image, color: background);
  const lines = [
    'HOUSE BLEND',
    'ORIGIN 1  BRAZIL 60%',
    'REGION  CERRADO',
    'PROCESS  NATURAL',
    'ORIGIN 2  ETHIOPIA 40%',
    'REGION  GUJI',
    'PROCESS  WASHED',
    'ROAST  MEDIUM',
    'NOTES  COCOA, BERRY',
  ];
  for (var i = 0; i < lines.length; i++) {
    img.drawString(
      image,
      lines[i],
      font: i == 0 ? img.arial48 : img.arial24,
      x: 80,
      y: 90 + i * 130,
      color: ink,
    );
  }
  return image;
}

void main() {
  final dir = Directory('assets/test')..createSync(recursive: true);
  final bright = card(
    background: img.ColorRgb8(245, 242, 232),
    ink: img.ColorRgb8(25, 20, 15),
  );
  final dark = card(
    background: img.ColorRgb8(38, 38, 42),
    ink: img.ColorRgb8(82, 82, 88),
  );
  final bad = img.gaussianBlur(dark.clone(), radius: 8);
  img.fillRect(
    bad,
    x1: 540,
    y1: 180,
    x2: 1000,
    y2: 900,
    color: img.ColorRgb8(255, 255, 255),
  );
  File('${dir.path}/ocr_blend_en.png').writeAsBytesSync(img.encodePng(bright));
  File('${dir.path}/ocr_dark_blend_en.png').writeAsBytesSync(img.encodePng(dark));
  File('${dir.path}/ocr_bad_quality_en.png').writeAsBytesSync(img.encodePng(bad));
}
```

Run: `dart run scripts/generate_ocr_fixtures.dart`

Expected: three 1080×1440 PNGs under `assets/test/`.

- [ ] **Step 2: Register fixtures and write integration expectations**

Add all three files to `flutter.assets`. In `ocr_probe_test.dart`, keep both existing 8-field tests and add helpers that copy bundled assets to a temporary file.

Add these end-to-end assertions:

```dart
testWidgets('bright blend is certain and has two components', (tester) async {
  final path = await copyAssetToTemp('assets/test/ocr_blend_en.png');
  final lines = await MlkitOcrService().recognize(path);
  final draft = parseOcr(lines);
  expect(draft.typeDecision, OcrTypeDecision.certainBlend);
  expect(draft.components, hasLength(2));
  expect(draft.components.map((c) => c.country), ['Brazil', 'Ethiopia']);
  expect(draft.components.map((c) => c.ratioPercent), [60, 40]);
});

testWidgets('dark blend uses enhanced candidate and restores required data', (tester) async {
  final path = await copyAssetToTemp('assets/test/ocr_dark_blend_en.png');
  final pipeline = DefaultOcrPipeline(
    ocr: MlkitOcrService(),
    qualityAnalyzer: DartImageQualityAnalyzer(),
    preprocessor: DartOcrImagePreprocessor(),
  );
  final result = await pipeline.analyze(path);
  expect(result.usedEnhanced, isTrue);
  expect(result.draft.name, isNotNull);
  expect(result.draft.components.where((c) => c.country != null), hasLength(2));
});

testWidgets('blur and glare produce non-blocking quality warning', (tester) async {
  final path = await copyAssetToTemp('assets/test/ocr_bad_quality_en.png');
  final pipeline = DefaultOcrPipeline(
    ocr: MlkitOcrService(),
    qualityAnalyzer: DartImageQualityAnalyzer(),
    preprocessor: DartOcrImagePreprocessor(),
  );
  final result = await pipeline.analyze(path);
  expect(result.quality.hasIssues, isTrue);
  expect(result.shouldWarnQuality, isTrue);
});
```

- [ ] **Step 3: Run the generator and host-side suite**

Run: `dart run scripts/generate_ocr_fixtures.dart`

Expected: exit 0 and three fixture files updated deterministically.

Run: `flutter test`

Expected: all host unit, data, and widget tests PASS.

- [ ] **Step 4: Run real ML Kit integration tests on Android emulator**

Run: `flutter test integration_test/ocr_probe_test.dart -d emulator-5554`

Expected: existing two cards retain 8 fields; bright blend returns two components; dark blend selects enhanced result; bad-quality card requests a non-blocking warning.

If actual ML Kit output exposes a threshold mismatch, adjust only the named constants in `image_quality_analyzer.dart` or the synthetic fixture ink/background values, rerun the targeted unit tests, then rerun this integration command. Do not weaken field/type assertions or add card-specific parser branches.

- [ ] **Step 5: Run final formatting, analysis, and complete regression**

Run: `dart format --output=none --set-exit-if-changed lib test integration_test scripts`

Expected: exit 0.

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: all tests PASS with zero failures.

- [ ] **Step 6: Update design status and render documentation**

Change the design header to:

```markdown
> 상태: 구현 완료, 실기기 검증 대기. 구현 계획: `photo-ocr-reliability-plan.md`.
```

Run: `python scripts/md2html.py docs/plans/photo-ocr-reliability-design.md docs/plans/photo-ocr-reliability-plan.md`

Expected: both sibling HTML files regenerate successfully.

- [ ] **Step 7: Perform final review before completion claim**

Invoke `superpowers:verification-before-completion`, then `superpowers:requesting-code-review`. Verify the complete branch diff against every design section, with special attention to zero-component blends, temporary-file cleanup, original-card non-regression, and no private photo assets.

Expected: review has no unresolved Critical or Important findings; all fixes are reverified with targeted tests and the full suite.

- [ ] **Step 8: Request final implementation commit approval**

Run: `git diff --check`, `git diff --stat`, and `git status --short`.

Tell the user the changed files, generator/integration/full-suite results, review result, and proposed message `test(ocr): verify blend and low-contrast scans`. Wait for explicit approval.

- [ ] **Step 9: Commit only after approval**

```bash
git add scripts/generate_ocr_fixtures.dart assets/test/ocr_blend_en.png assets/test/ocr_dark_blend_en.png assets/test/ocr_bad_quality_en.png pubspec.yaml integration_test/ocr_probe_test.dart docs/plans/photo-ocr-reliability-design.md docs/plans/photo-ocr-reliability-design.html docs/plans/photo-ocr-reliability-plan.md docs/plans/photo-ocr-reliability-plan.html
git commit -m "test(ocr): verify blend and low-contrast scans"
```

Expected: final task commit contains fixtures, integration coverage, and regenerated documentation only.

---

## Execution Completion Checklist

- [ ] Every task followed red → green TDD and its targeted test command passed.
- [ ] Every commit was announced with scope/message and explicitly approved by the user before execution.
- [ ] No implementation commit includes `.claude/`, `AGENTS.md`, private photos, unrelated formatting, or adjacent refactors.
- [ ] Existing `ocr_card_ko.png` and `ocr_card_orig.png` still produce their 8 expected fields.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` finishes with zero failures.
- [ ] Android emulator ML Kit integration test passes.
- [ ] Final review has no unresolved Critical or Important findings.
- [ ] User performs final physical-device checks for representative explicit-blend, multi-component, dark, glare, and blur photos before a release tag.
