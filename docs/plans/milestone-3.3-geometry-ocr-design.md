# M3.3 — 좌표 기반 OCR 파싱 (설계)

> 상태: 승인됨(2026-07-20). 계획: `milestone-3.3-geometry-ocr-plan.md`. 목표 릴리스 **v0.3.3**.

## 1. 배경 & 문제

M3~M3.2에서 "사진 자동채움이 실제 카드에서 안 된다"는 문제가 반복됐다. 에뮬레이터 실측(실제 ML Kit OCR, `assets/test/ocr_card_orig.png`)으로 근본 원인을 확정했다.

깨끗한 `라벨: 값` 카드는 **8/8** 자동채움, 실제형(콜론 없는 2열 레이아웃) 카드는 **4/8** 만 채워진다.

| 필드 | 방식 | 콜론 카드 | 실제형 카드 |
|---|---|:--:|:--:|
| 국가·가공·로스팅·날짜 | 키워드/정규식(내용 매칭) | ✅ | ✅ |
| 제품명·로스터리·지역·컵노트 | 라벨(콜론) 매칭 | ✅ | ❌ |

**원인:** ML Kit은 실제형 카드의 텍스트를 **라벨 열 전체 → 값 열 전체** 순서로 직렬화한다. 즉 텍스트 순서상 `지역`과 값 `후일라`가 떨어져 있고, 콜론도 없어 한 줄로 묶을 수 없다. 내용만으로 잡는 4필드는 레이아웃과 무관하게 성공하지만, 라벨↔값 **인접성**에 의존하는 4필드는 실패한다.

**관찰:** 텍스트 순서로는 못 묶지만, 각 줄의 **boundingBox 좌표**로는 `지역`(왼쪽)과 `후일라`(같은 y·오른쪽)가 같은 행임을 알 수 있다. 즉 좌표를 살리면 라벨↔값을 공간적으로 복원할 수 있다.

## 2. 목표 & 범위

**목표:** 실제형 카드에서 **지역·컵노트·제품명·로스터리** 자동채움을 좌표 기반으로 복원한다.

**범위 내:**
- `OcrService.recognize` 반환 타입을 `String` → `List<OcrLine>`(텍스트+좌표)로 확장.
- 파서를 좌표 기반 `라벨→값` 공간 매칭 + 타이포 제목/이브로우 추정으로 재작성. 콜론/키워드/칩 폴백은 유지.
- 페이크·테스트·에뮬레이터 프로브를 구조화 입력으로 갱신.

**범위 밖(무변경):** `OcrDraft` 모델, `bean_form_screen`(폼·칩 배정 UX), 데이터 모델·저장소·DB, 촬영/갤러리 UX, 프로바이더 배선(타입만 바뀜).

**비회귀 보장:** 콜론 카드·기존 문자열 테스트는 폴백 레이어로 계속 동작한다. 최악의 경우(험한 실제 봉투)에도 지금보다 나빠지지 않는다.

## 3. seam 변경

`lib/services/ocr_service.dart`:

```dart
/// OCR 한 줄(텍스트 + 이미지 픽셀 좌표). 순수 Dart(dart:ui 비의존)로 호스트 테스트에서 손쉽게 생성.
class OcrLine {
  final String text;
  final double left, top, right, bottom;
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
  double get width => right - left;
}

abstract class OcrService {
  /// 이미지의 인식 라인들을 반환한다. 실패/빈 이미지면 빈 리스트.
  Future<List<OcrLine>> recognize(String imagePath);
}
```

`MlkitOcrService`: `result.blocks`의 각 `TextBlock.lines`를 순회, `TextLine.text`와 `TextLine.boundingBox`(Rect)를 `OcrLine`으로 매핑. 예외 시 `[]` 반환(기존 '자동 인식 실패' 배너로 이어짐).

```dart
final result = await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
return [
  for (final block in result.blocks)
    for (final line in block.lines)
      OcrLine(line.text,
          left: line.boundingBox.left, top: line.boundingBox.top,
          right: line.boundingBox.right, bottom: line.boundingBox.bottom),
];
```

프로바이더(`ocrServiceProvider`)는 코드 변경 없음(반환 타입만 바뀜).

## 4. 파서 재설계 (`lib/features/beans/ocr/ocr_parser.dart`)

새 코어 **`OcrDraft parseOcr(List<OcrLine> lines)`**. 4개 레이어를 순서대로 적용한다.

### 4.1 좌표 라벨→값 (지역·컵노트)

**바레-라벨 줄**: 줄의 트림·소문자·후행 `:：` 제거 텍스트가 라벨 토큰과 **정확히 일치**하는 줄.
- region 토큰: `지역`, `region`
- cupNotes 토큰: `컵노트`, `컵 노트`, `notes`, `cup notes`, `cup note`, `tasting notes`, `향미`

라벨 줄 `L`의 값 후보 탐색(모든 임계값은 `L.height` 단위 → 스케일 불변):
1. **같은 행·오른쪽**: 수직 정렬(`|V.centerY - L.centerY| ≤ 0.6·L.height`)이고 `V.left ≥ L.right - 0.5·L.height`이며 바레-라벨이 아닌 줄 `V` 중 `V.left`가 가장 작은(가장 가까운 오른쪽) 것.
2. 없으면 **바로 아래**: `V.top ≥ L.bottom - 0.5·L.height`이고 x가 겹치거나(`V.left ≤ L.right && V.right ≥ L.left`) 같은 열 시작(`|V.left - L.left| ≤ 1.5·L.height`)이며 바레-라벨이 아닌 줄 중 `V.top`이 가장 작은(가장 가까운 아래) 것.

매칭된 `V.text`가 값. 컵노트는 `[,/·、]`로 분할(기존 `_matchCupNotes`와 동일).
→ 스타일 카드: `지역=후일라`(같은 행), `컵노트=딸기,복숭아,레드와인`(아래).

### 4.2 타이포 제목/이브로우 (제품명·로스터리)

전 줄 높이의 **중앙값** `medianH`. 최대 높이 줄 `T`.
- `T.height < 1.3·medianH`(균일 텍스트)이면 타이포 추정 없음 → 제품명·로스터리 이 단계에서 `null`(오채움 회피).
- `T`가 상단부(`T.top ≤ minTop + 0.45·(maxBottom − minTop)`, 여기서 minTop/maxBottom은 전 줄 경계)이면 **제품명 = `T.text`**.
- **로스터리 = 이브로우**: `T` 위(`V.bottom ≤ T.top + 0.3·T.height`)이고 x가 겹치며 `V.height < T.height`인 줄 중 가장 가까운(가장 큰 `V.bottom`) 것. 없으면 `null`.
→ 스타일 카드: `제품명=콜롬비아 핑크버번 내추럴`, `로스터리=베이스캠프 로스 터스`(자간 오독은 사용자가 수정).

### 4.3 콜론/키워드 폴백 (기존 로직 재사용)

4.1·4.2에서 못 채운 라벨 필드는 **줄 텍스트에 기존 콜론 라벨 추출**로 보강 → 깨끗한 콜론 카드 계속 동작.
- name/roaster/region: `_firstLabel(texts, _nameLabel/_roasterLabel/_regionLabel)`
- cupNotes: `_matchCupNotes(texts)`

내용 매칭 필드는 **조인 텍스트**(줄들을 `\n`로 결합)에 기존 로직 그대로:
- country: `_firstMatch(lower, _countries)`
- roastLevel: `_firstMatch(lower, _roastKeywords)`
- process: `_firstMatch(lower, _processKeywords)`
- roastDate: `_matchDate(joined)`

### 4.4 칩

전 줄 텍스트 dedupe(기존 `_dedupe`). 무변경.

### 4.5 하위호환 래퍼

`OcrDraft parseOcrText(String rawText)` 유지: `\n` 분할·트림·비어있지 않은 줄을 **세로로 쌓은 합성 라인**(`OcrLine(text, top: i·H, bottom: i·H+H, left: 0, right: W)`)으로 만들어 `parseOcr` 호출. 단일 열이라 4.1의 "같은 행·오른쪽"은 매칭되지 않고, 콜론 줄은 4.3 폴백이 처리 → **기존 유닛 테스트 전부 유지**.

## 5. 데이터 흐름

`add_bean_sheet._recognize`: `ref.read(ocrServiceProvider).recognize(path)` → `List<OcrLine>` → `parseOcr(lines)` → `OcrDraft`. 스피너·폼 이동 등 나머지는 동일. `BeanFormScreen`·`OcrDraft` 무변경.

## 6. 오류 처리 & 폴백 레이어링

- `recognize` 예외/빈 이미지 → `[]` → `parseOcr([])` → 전 필드 null/빈 → 폼의 '자동 인식 실패' 배너(기존 경로).
- 좌표 매칭 실패(험한 레이아웃) → 콜론/키워드 폴백 → 그래도 못 잡으면 칩으로 노출(기존 배정 UX). 어느 단계도 예외를 던지지 않는다.

## 7. 테스트 (3계층 + 실측)

- **유닛(`test/unit/ocr_parser_test.dart`)**: `parseOcr`에 손으로 만든 라인+좌표로
  - (a) 2열 스타일: `지역`(왼쪽)+`후일라`(같은 y·오른쪽) → region; `컵노트`(위)+값(아래) → cupNotes.
  - (b) 제목/이브로우: 큰 줄 → name, 그 위 작은 줄 → roaster.
  - (c) 균일 높이 → name/roaster null(오채움 가드).
  - (d) 콜론 문자열 폴백: 기존 `parseOcrText` 문자열 테스트 전부 유지.
- **위젯(`test/widget/…`)**: `FakeOcrService`에 `.lines([...])`/`.text('...')` 두 생성자. 기존 폼 프리필·칩 테스트는 `.text` 경로 유지.
- **실측(`integration_test/ocr_probe_test.dart`)**: `recognize→parseOcr`로 갱신. 스타일 카드(`ocr_card_orig.png`)에서 **지역·컵노트·제품명·로스터리까지** 채워지는지 emulator로 검증(근본해결 증거). 콜론 카드(`ocr_card_ko.png`)는 8/8 회귀 가드 유지.

## 8. 실행 규약

TDD + SDD(구현·리뷰·수정 sonnet, 최종 opus, main 직접 커밋). 진행원장 `.superpowers/sdd/progress.md`에 M3.3 섹션. 목표 릴리스 **v0.3.3**(대기 중인 적응형 아이콘·콜론 제품명/로스터리 커밋도 함께 실림).

## 9. 파일 영향

- 변경: `lib/services/ocr_service.dart`(OcrLine + 반환타입), `lib/features/beans/ocr/ocr_parser.dart`(parseOcr 코어 + parseOcrText 래퍼), `lib/features/beans/add_bean_sheet.dart`(호출부), `test/helpers.dart`(FakeOcrService), `test/unit/ocr_parser_test.dart`, `test/widget/*`(페이크 생성자), `integration_test/ocr_probe_test.dart`.
- 무변경: `ocr_draft.dart`, `bean_form_screen.dart`, `providers.dart`(코드), 데이터/DB/저장소.
