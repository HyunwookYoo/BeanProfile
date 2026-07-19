# ☕ BeanProfile — M3 설계: 사진 & OCR 반자동 입력

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-19 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획(writing-plans) 대기 |
| 마일스톤 | M3 (사진 & OCR 리뷰) |
| 선행 | M2/M2.1 **DONE** · `v0.2.1` |
| 목표 버전 | `v0.3.0` |
| 목업 | [`../mockups/m3-photo-ocr.html`](../mockups/m3-photo-ocr.html) · [아티팩트](https://claude.ai/code/artifact/f384ab78-3d8f-4a47-b8a6-ee29cf25e564) |
| 상위 문서 | 설계 [`../design.md`](../design.md) §5 · 로드맵 [`roadmap.md`](roadmap.md) · 배포 [`../deployment.md`](../deployment.md) |

---

## 1. 목표 & 범위

**커피 정보 사진**(원두 봉투 인쇄물 또는 별도 정보 카드)을 촬영/선택하면, 온디바이스 OCR이 전체 텍스트를 읽고, 앱이 명확한 패턴만 자동으로 채운 **폼 + 인식 칩** 리뷰 화면에서 사용자가 확정해 원두를 추가한다. 촬영한 사진은 저장되어 리스트 카드 썸네일과 상세 화면에 표시된다. OCR이 실패해도 수동 입력으로 매끄럽게 이어진다.

이번 마일스톤은 앱 **최초의 네이티브 플러그인**(카메라·OCR·파일)을 도입한다. 따라서 "무엇을 만드는가"만큼 **"무엇을 어떻게 테스트하는가"** 가 설계의 핵심이다(§3).

### 확정 결정 (브레인스토밍 2026-07-19)

| # | 결정 | 선택 |
|---|---|---|
| Q1 | 리뷰 화면 | **기존 추가 폼(`bean_form_screen`) 확장** — 자동채움 + 인식 칩 패널 |
| Q2 | 사진 범위 | **촬영 → 저장 → 표시** (카드 썸네일 + 상세 사진) |
| Q3 | CI 검증 시점 | **초기 스파이크 빌드** — 플러그인·권한을 먼저 기기 검증 |
| Q4 | 상세 사진 배치 | **이름 옆 컴팩트 썸네일** (탭 → 전체화면). 풀폭 배너 아님 |
| J1 | 이름·로스터리 자동추측 | **안 함** (오탐 위험 → 칩 배정/직접 입력) |
| J2 | 사진 저장 시점 | **Copy-on-save** (취소 시 고아 파일 없음) |
| J3 | 칩 배정 대상 | **자유 텍스트 필드에만** (날짜·enum은 피커) |

---

## 2. 용어 (문서·UI 공통)

"봉투"라는 단어는 단독으로 쓰지 않는다. OCR 소스가 봉투 인쇄물일 수도, 별도 정보 카드일 수도 있기 때문이다.

| 개념 | 표기 |
|---|---|
| 촬영/선택한 원본 이미지 | **커피 정보 사진** (또는 중립적으로 "사진") |
| 소스를 지칭할 때 | **봉투·정보 카드** (열거) |
| OCR이 뽑은 글자 조각 | **인식된 텍스트** |
| 진입 동작 라벨 | **촬영** / **갤러리에서 선택** / **직접 입력** (명사 대신 동작 중심, 서브라인으로 보완) |

---

## 3. 아키텍처 & 테스트 경계

호스트(Windows `flutter test`)에서 실행 불가능한 플러그인 호출을 **얇은 인터페이스 뒤로 격리**하고, 필드 추측 로직은 **순수 Dart 파서**로 분리한다. 이 경계가 M3 품질의 핵심이다.

| 유닛 | 책임 | 테스트 |
|---|---|---|
| `OcrService` (interface) + `MlkitOcrService` | 이미지 경로 → 인식 텍스트 | 기기 전용(가짜 주입) |
| `PhotoService` (interface): `pick()` / `persist()` | 카메라·갤러리 선택(임시경로), 저장 시 문서폴더 복사 | 기기 전용(가짜 주입) |
| **`parseOcrText(String) → OcrDraft`** | 인식 텍스트 → 필드 추측 + 칩 | **순수 Dart 유닛 = TDD 심장** |
| `bean_form_screen` 확장 | draft 프리필 + 칩 배정 + 저장 | 위젯(가짜 draft/service) |
| 리스트 카드·상세 썸네일 | `photoPath` 렌더 | 위젯 |

인터페이스 스케치:

```dart
// lib/services/ocr_service.dart
abstract class OcrService {
  /// 온디바이스 OCR로 [imagePath]의 전체 텍스트를 인식한다.
  Future<String> recognize(String imagePath);
}

// lib/services/photo_service.dart
abstract class PhotoService {
  /// 카메라(fromCamera=true) 또는 갤러리에서 이미지를 고른다.
  /// 반환: 임시 파일 경로, 취소 시 null.
  Future<String?> pick({required bool fromCamera});

  /// 임시 이미지를 앱 문서 디렉터리로 복사하고 영구 경로를 반환한다.
  Future<String> persist(String tempPath);
}
```

Riverpod로 주입해 테스트에서 가짜로 교체한다:

```dart
// lib/providers.dart
final ocrServiceProvider = Provider<OcrService>((ref) => MlkitOcrService());
final photoServiceProvider = Provider<PhotoService>((ref) => ImagePickerPhotoService());
```

- `MlkitOcrService`는 `TextRecognizer(script: TextRecognitionScript.korean)`를 감싼다(한글 스크립트 모델이 라틴 문자도 인식).
- `ImagePickerPhotoService`는 `image_picker`(선택) + `path_provider`(문서 디렉터리 복사)를 감싼다.

---

## 4. 데이터 흐름

```
원두 리스트 FAB(+) → 바텀시트 [촬영 / 갤러리에서 선택 / 직접 입력]
  촬영·갤러리 → PhotoService.pick() → 임시경로(취소면 종료)
             → OcrService.recognize(임시경로) → 원문 텍스트
             → parseOcrText(원문) → OcrDraft
             → BeanFormScreen(draft, photoTempPath) : 자동값 하이라이트 + 인식 칩 패널
  직접 입력   → BeanFormScreen(빈 폼)  ← 기존 M1 경로 그대로
저장 시 → (photoTempPath 있으면) PhotoService.persist() → 문서폴더 영구경로
        → createBean(BeanInput{ ..., photoPath: 영구경로 })
표시 → 리스트 카드 썸네일 · 상세 컴팩트 썸네일(탭 → 전체화면)
```

**Copy-on-save (J2):** `pick()`은 `image_picker`의 임시 캐시 경로를 그대로 쓰고, 문서폴더 복사(`persist`)는 **저장 버튼을 눌렀을 때만** 일어난다. 리뷰 화면에서 취소하면 문서폴더에 파일이 남지 않는다.

---

## 5. OCR 파서 명세 (순수 Dart)

`parseOcrText(String rawText) → OcrDraft`. 설계 §5의 자동추측 5종만 채우고, 나머지는 칩으로 넘긴다. 이름·로스터리는 자동추측하지 않는다(J1).

```dart
// lib/features/beans/ocr/ocr_draft.dart
class OcrDraft {
  final String? country;        // 원산지 사전 매칭
  final DateTime? roastDate;    // 날짜 정규식
  final RoastLevel? roastLevel; // 키워드
  final Process? process;       // 키워드
  final List<String> cupNotes;  // "Notes:" 라벨 뒤
  final List<String> chips;     // 배정 대기 텍스트 조각(줄 단위)
  const OcrDraft({
    this.country,
    this.roastDate,
    this.roastLevel,
    this.process,
    this.cupNotes = const [],
    this.chips = const [],
  });
}
```

추측 규칙(시드 값 — 구현 시 확장 가능):

| 필드 | 방법 | 시드 |
|---|---|---|
| country | 원산지 사전 매칭(영/한, 대소문자 무시). 첫 매칭만 채우고 나머지는 칩 | Ethiopia/에티오피아, Colombia/콜롬비아, Kenya/케냐, Brazil/브라질, Guatemala/과테말라, Costa Rica/코스타리카, Panama/파나마, Honduras/온두라스, Indonesia/인도네시아, Rwanda/르완다, Burundi/부룬디, El Salvador/엘살바도르, Peru/페루, Nicaragua/니카라과, Yemen/예멘, Tanzania/탄자니아, Mexico/멕시코, Uganda/우간다, Bolivia/볼리비아, Ecuador/에콰도르 |
| roastDate | 정규식, 첫 유효 날짜 | `YYYY[.\-/]M[.\-/]D`, `YY[.\-/]M[.\-/]D`, `YYYY년 M월 D일` |
| roastLevel | 키워드 → enum | Light/라이트, LightMedium/라이트미디엄, Medium/미디엄·시티, MediumDark/미디엄다크·풀시티, Dark/다크·프렌치 |
| process | 키워드 → enum | Washed/워시드/수세식, Natural/내추럴/건식, Honey/허니, Anaerobic/무산소·애너로빅, 그 외 Other |
| cupNotes | 라벨 라인 뒤를 `,` `/` `·` `、`로 분리 | 라벨: `Notes` / `Cup Notes` / `Tasting Notes` / `컵노트` / `노트` / `향미` (뒤에 `:` 또는 `：`) |
| chips | 비어있지 않은 모든 줄(trim·중복제거) | — |

---

## 6. 폼 확장 UX (`bean_form_screen`)

`BeanFormScreen`에 선택적 인자 `OcrDraft? draft`, `String? photoTempPath`를 추가한다. draft가 있을 때만 OCR 전용 UI가 렌더된다.

- **프리필 + 하이라이트:** draft의 자동값을 필드에 채우고, "OCR이 채운 값"을 앰버 배지(✓ 자동)로 표시.
- **인식 칩 패널(`OcrChipsPanel`):** 하단에 `draft.chips`를 탭 가능한 칩으로 나열. draft 없으면 렌더 안 함.
- **배정 인터랙션(J3):** 자유 **텍스트 필드에 포커스** → **칩 탭** → 그 필드에 칩 텍스트가 채워지고, 쓴 칩은 흐려진다(used). 포커스된 텍스트 필드가 없으면 칩 탭은 무시(힌트 표시).
- **경계:** 칩 배정 대상은 자유 텍스트 필드뿐(제품명·로스터리·지역·농장·품종·고도·메모·컵노트). 날짜·로스팅단계·가공방식 같은 **구조화 필드는 파서 자동값**을 기존 피커로 수정한다.
- **OCR 실패(인식 0건):** 칩 패널 대신 안내 배너("글자를 자동 인식하지 못했어요…")를 띄우고 빈 폼으로 이어간다. 사진은 유지.

`bean_form_screen`이 비대해지지 않도록 OCR 칩 패널은 별도 위젯(`OcrChipsPanel`)으로 분리한다.

---

## 7. 사진 저장 · 표시

- **모델:** `BeanInput`에 `String? photoPath`를 추가한다. `createBean`/`updateBean`이 이 값을 기록한다(`Bean.photoPath` 컬럼은 이미 존재 → **마이그레이션 불필요**).
- **저장:** 저장 시 `photoTempPath`가 있으면 `PhotoService.persist()`로 문서폴더에 복사하고 영구 경로를 `photoPath`에 넣는다.
- **리스트 카드:** leading 썸네일 — 사진 있으면 `Image.file`, 없으면 기본 아이콘 플레이스홀더. 카드 레이아웃은 M1/M2 그대로.
- **상세 화면(Q4):** 이름 옆 **컴팩트 썸네일**(탭 → 전체화면 뷰어). 사진 없으면 플레이스홀더. 모노 스펙시트 정체성 유지를 위해 풀폭 배너는 쓰지 않는다.

---

## 8. 진입 & 화면 상태

- **진입:** 원두 리스트 FAB(+) → `showModalBottomSheet` 3옵션.
  - **촬영** — `봉투·정보 카드를 찍어 자동 인식` → `pick(fromCamera: true)`
  - **갤러리에서 선택** — `저장된 사진에서` → `pick(fromCamera: false)`
  - **직접 입력** — `사진 없이 수동으로` → 기존 빈 폼
- **성공:** 자동값 하이라이트 + 인식 칩 패널(§6).
- **실패:** 안내 배너 + 빈 폼(사진 유지).
- 목업의 A~E 화면이 이 상태들을 그대로 반영한다.

---

## 9. 권한 & CI 스파이크

M3는 M0 이후 가장 무거운 iOS 빌드 변경이다(ML Kit 파드 + 모델). **맥이 없고 CI macOS 러너가 유일한 맥**이므로, 파이프라인이 깨지면 iOS 빌드가 불가능해진다. 따라서 **첫 태스크를 스파이크로** 둔다.

- **iOS** `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (한국어 문구). ML Kit 파드 해소를 위해 **Podfile iOS 최소버전 상향이 필요할 수 있음**(스파이크가 확인·고정).
- **Android** `AndroidManifest.xml`: 카메라 권한(코드 크로스플랫폼 유지용; CI 검증은 iOS만).
- **스파이크(Task 1):** 플러그인 3종 + 권한 + seam(`OcrService`/`PhotoService`) + 최소 디버그 화면("사진 → OCR → 원문 표시")만 넣고, **pre-release 태그로 CI가 설치 가능한 `.ipa`를 만드는지, 기기에서 OCR이 도는지 먼저 검증**한다. seam은 유지, 디버그 화면은 이후 실플로우로 교체.

---

## 10. 파일 영향

**신규**
- `lib/services/ocr_service.dart` — `OcrService` + `MlkitOcrService`
- `lib/services/photo_service.dart` — `PhotoService` + `ImagePickerPhotoService`
- `lib/features/beans/ocr/ocr_draft.dart` — `OcrDraft`
- `lib/features/beans/ocr/ocr_parser.dart` — `parseOcrText`
- `lib/features/beans/widgets/ocr_chips_panel.dart` — 인식 칩 패널
- `lib/features/beans/add_bean_sheet.dart` — FAB 바텀시트(촬영/갤러리/직접)

**수정**
- `pubspec.yaml` — `google_mlkit_text_recognition` · `image_picker` · `path_provider`
- `lib/data/models.dart` — `BeanInput.photoPath`
- `lib/data/bean_repository.dart` — `createBean`/`updateBean`에 `photoPath` 반영
- `lib/providers.dart` — `ocrServiceProvider` · `photoServiceProvider`
- `lib/features/beans/bean_form_screen.dart` — `draft`/`photoTempPath` 인자, 프리필·하이라이트, 칩 패널, 저장 시 persist
- `lib/features/beans/bean_list_screen.dart` — FAB → 바텀시트, 카드 썸네일
- `lib/features/beans/widgets/bean_card.dart` — leading 썸네일(사진/플레이스홀더)
- `lib/features/beans/bean_detail_screen.dart` — 컴팩트 썸네일(탭 → 전체화면)
- `ios/Runner/Info.plist` · `android/app/src/main/AndroidManifest.xml` — 권한

---

## 11. 테스트 전략 (docs/testing.md 3계층 · `test/helpers` 재사용)

- **유닛(대량 · TDD 심장):** `parseOcrText` — 국가 hit/miss, 날짜 포맷 3종, 로스팅/가공 키워드, 컵노트 라벨 분리, 칩 추출·중복제거. 각 추측기가 독립적으로 검증됨.
- **데이터:** `photoPath`가 `createBean`/`updateBean`/`watchBeanDetail`을 왕복(drift, sqlite3.dll 호스트).
- **위젯:** 폼 프리필·앰버 하이라이트, 칩 패널 렌더, 포커스→칩탭 채움·used 처리, 저장 시 `photoPath` 포함 `BeanInput`(가짜 `PhotoService`), 바텀시트 3옵션, 카드 썸네일(사진/플레이스홀더), 실패 배너.
- **기기 전용(호스트 불가):** `image_picker` · ML Kit 인식 · `path_provider` — 스파이크(Task 1) + 최종 DoD에서 검증. 문서에 명시.

---

## 12. 스코프 밖 (이번 아님)

- 사진 편집/크롭/회전, 여러 장 첨부.
- 블렌드 다국가 자동 다중배정(첫 매칭만 자동, 나머지는 칩).
- OCR 인식 언어 토글(한글 스크립트 모델 고정).
- 사진 포함 JSON 백업(M5).
- 사진 교체 시 옛 파일 정리(고아 파일 — 후속).
- name/roaster 휴리스틱 자동추측.

---

## 13. 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green · 파서 유닛 커버리지 확보.
- **기기에서:** 촬영/갤러리 → OCR → 자동필드 + 칩 배정 → 저장 → 리스트 카드·상세에 사진 표시. OCR 실패 시 배너 + 수동 입력으로 이어짐.
- 태스크별 SDD 리뷰 + opus 최종 리뷰 통과 → `v0.3.0` 태그 → AltStore 설치·동작 확인.
