# ☕ BeanProfile — 디개싱 일수 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-27 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획 대기 |
| 선행 | M2 시음 CRUD `v0.2.0` · M5 백업 `v0.5.0` |
| 상위 문서 | [`design.md`](../design.md) · [`testing.md`](../testing.md) |
| 목업 | [`mockups/degassing-days.html`](../mockups/degassing-days.html) |
| 영향 범위 | `Tastings` 스키마(프로젝트 첫 마이그레이션) · `tasting_form_screen` · `bean_detail_screen` |

---

## 1. 문제

커피는 로스팅 후 이산화탄소가 빠지면서 맛이 변한다. 같은 원두라도 1일차와 8일차가 다르고, 어느 구간이 좋은지는 사람마다 다르다. 이 앱의 목적이 "내 데이터로 내 취향을 찾는 것"인데, **그 축이 통째로 빠져 있다.**

시음 기록은 지금 시음일·강도 4축·별점·코멘트만 남긴다. `Beans.roastDate`가 이미 있으니 대부분의 경우 뺄셈 한 번이면 되는데, 아무도 그 뺄셈을 하지 않는다.

로스팅 날짜가 카드에 없는 원두도 있다. 그때는 사용자가 아는 일수를 직접 적을 수 있어야 한다.

## 2. 확정 결정 (브레인스토밍 2026-07-27)

| # | 결정 | 선택 |
|---|---|---|
| Q1 | 기준일 | 오늘이 아니라 **시음일** |
| Q2 | 수동 입력 저장 위치 | **`Tastings`에 nullable 컬럼** (원두 로스팅 날짜 역산은 기각) |
| Q3 | 입력 위젯 | **숫자 필드** (스테퍼 기각) |
| Q4 | 시음 카드 | **날짜 옆 알약** |
| Q5 | 음수 | **빨간 `날짜 확인`** (조용히 숨기기 기각) |
| Q6 | 표기 | **`디개싱 8일`** (`8일차` 기각) |

### 왜 오늘이 아니라 시음일인가

최초 요청은 "현재 날짜와 계산"이었다. 오늘 기록하면 둘이 같지만, **지난 시음을 나중에 열어보면 갈린다** — 오늘 기준이면 기록을 열 때마다 숫자가 커진다. 시음 기록에 남길 값은 "그때 며칠째였나"라는 고정된 사실이므로 기준은 시음일이다.

"지금 이 원두가 로스팅 후 며칠"이라는 오늘 기준 카운터는 별개의 유용한 기능이지만, 두 기준의 숫자가 한 화면에 같이 뜨면 헷갈린다. §6으로 뺀다.

### 왜 로스팅 날짜 역산이 아닌가

수동 입력값을 저장하는 대신 `roastDate = 시음일 − 입력일수`로 원두에 역산해 넣으면 새 컬럼도 마이그레이션도 필요 없다. 기각한 이유는 **과거 기록이 조용히 바뀌기 때문이다.**

```
시음 A(07-27)에 '8일' 입력  → bean.roastDate = 07-19
시음 B(07-30)에 '5일' 입력  → bean.roastDate = 07-25로 덮임
                            → 시음 A가 8일 → 2일로 변함
```

부수적으로, 사용자가 본 적 없는 날짜를 앱이 원두 상세에 사실처럼 적게 된다. 기록 앱에서 할 일이 아니다.

## 3. 설계

### 3.1 데이터 — 컬럼 하나, 그리고 첫 마이그레이션

```dart
// lib/data/tables.dart — Tastings
IntColumn get degassingDays => integer().nullable()();
```

```dart
// lib/data/database.dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) await m.addColumn(tastings, tastings.degassingDays);
      },
      // 기존 동작 — FK cascade delete가 여기에 걸려 있으므로 절대 지우지 않는다.
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
```

지금까지 이 프로젝트에 마이그레이션이 한 번도 없었다(`schemaVersion => 1`, `onUpgrade` 없음). **폰에 실데이터가 있으므로 이번 변경에서 가장 위험한 지점이 여기다.** nullable 컬럼 추가는 SQLite에서 가장 안전한 형태(`ALTER TABLE ADD COLUMN`)지만, 첫 마이그레이션이라 관례를 세우는 뜻에서 테스트를 붙인다(§5).

`onCreate`는 지정하지 않는다 — drift 기본값 `m.createAll()`이 신규 설치에 v2 스키마를 그대로 만든다.

### 3.2 계산 — 순수 함수 하나

M4 `computeTasteProfile`, M5 `backup_codec`과 같은 결. Flutter 의존 없는 순수 로직 + 단위 테스트.

```dart
// lib/features/tasting/degassing.dart

/// 시음 카드·폼에 띄울 디개싱 표시. 띄울 게 없으면 null.
/// 로스팅 날짜가 있으면 시음일과의 차이가 이기고, 없으면 사용자가 적은 값을 쓴다.
({String text, bool warn})? degassingLabel({
  DateTime? roastDate,
  required DateTime tastingDate,
  int? manualDays,
}) {
  final days = roastDate != null ? _dayDiff(roastDate, tastingDate) : manualDays;
  if (days == null) return null;
  if (days < 0) return (text: '날짜 확인', warn: true);
  if (days == 0) return (text: '당일', warn: false);
  return (text: '디개싱 $days일', warn: false);
}

// 로컬 DateTime끼리 빼면 서머타임 경계에서 23시간이 나와 .inDays가 하루 틀린다.
// 두 날짜를 UTC 자정으로 정규화하면 차이가 항상 정확한 일수의 배수다.
int _dayDiff(DateTime roast, DateTime tasting) =>
    DateTime.utc(tasting.year, tasting.month, tasting.day)
        .difference(DateTime.utc(roast.year, roast.month, roast.day))
        .inDays;
```

| 입력 | 결과 |
|---|---|
| `roastDate` 있음 · 차이 8 | `(text: '디개싱 8일', warn: false)` |
| `roastDate` 있음 · 차이 0 | `(text: '당일', warn: false)` |
| `roastDate` 있음 · 차이 −4 | `(text: '날짜 확인', warn: true)` |
| `roastDate` 없음 · 입력 8 | `(text: '디개싱 8일', warn: false)` |
| `roastDate` 없음 · 입력 0 | `(text: '당일', warn: false)` |
| 둘 다 없음 | `null` |

**계산값이 항상 이긴다.** 수동 입력값이 저장된 시음에 나중에 로스팅 날짜가 채워지면, 화면은 계산값으로 바뀌고 저장된 숫자는 쓰이지 않는다. 지우지는 않는다 — 로스팅 날짜를 다시 비우면 그대로 돌아오고, 유지하는 데 코드가 들지 않는다.

**표시에는 상한이 없다.** 128일이든 400일이든 계산된 그대로 보여준다 — 사용자가 실제로 그렇게 마신 기록이다. (입력칸의 세 자리 제한은 §3.3의 별개 이야기로, 오타를 줄이려는 위젯 제약이지 값의 상한 규칙이 아니다.)

### 3.3 UI

#### 시음 폼 (`tasting_form_screen.dart`)

`TastingFormScreen`에 `required DateTime? roastDate`를 추가한다. 호출부 2곳이 모두 `bean_detail_screen.dart`에 있고 둘 다 `detail.bean`이 이미 손에 있어, provider를 새로 watch하지 않아도 된다 — 폼은 지금처럼 동기 상태로 남는다. `required`로 두면 세 번째 호출부가 생겨도 빠뜨릴 수 없다(기존 테스트 3곳에 `roastDate: null` 한 줄씩 추가).

위치는 **시음일 줄 바로 아래, 강도 위**. 둘 다 "이 시음이 언제였나"를 말하는 줄이라 붙이고, 그 아래를 구분선으로 끊는다.

| `roastDate` | 렌더 |
|---|---|
| 있음 | 읽기 전용 `디개싱 8일` + 출처 `로스팅 2026-07-19`. 시음일을 바꾸면 같이 바뀐다 |
| 없음 | 숫자 입력(`Key('degassing-input')`) + `로스팅 날짜 없음` |

입력 제약은 `keyboardType: TextInputType.number` + `FilteringTextInputFormatter.digitsOnly` + `maxLength: 3`. digitsOnly가 음수·문자를 막고 maxLength가 999에서 끊는다. **그 위에 상한 규칙(예: 365)은 두지 않는다** — 에러 상태·문구·테스트가 따라붙는데 999는 이상할 뿐 아무것도 깨뜨리지 않는다(문자열로만 흘러간다). M4의 `%` NaN 같은 실제 위험이 아니다.

컨트롤러는 `roastDate` 여부와 무관하게 `existing?.degassingDays`로 초기화하고, 저장할 때 항상 `int.tryParse(text)`를 쓴다. 이러면 `roastDate`가 있어 입력칸이 안 보이는 동안에도 기존 값이 그대로 보존되며, 분기가 필요 없다.

#### 시음 카드 (`bean_detail_screen.dart::_tastingRow`)

날짜 옆에 알약 하나(`Key('degassing-pill-${t.id}')`). `warn`이면 `c.cherry` 계열, 아니면 기존 `oat`/`cremaInk` 톤. `null`이면 알약 없이 날짜만 — 줄이 밀리지 않는다.

같은 원두를 1일·4일·8일에 마신 기록이 위아래로 붙어 곡선이 읽히는 것이 이 기능의 실제 쓸모다.

### 3.4 백업 — 버전을 올리지 않는다

`backup_codec.dart`의 `_schemaVersion`은 **1로 유지한다.**

```dart
// backup_codec.dart:44
if (root is! Map || root['schemaVersion'] != _schemaVersion) {
  throw const FormatException('지원하지 않는 백업 형식 또는 버전입니다');
}
```

정확히 일치하는지만 보므로, 올리는 순간 사용자가 2026-07-22에 왕복 확인한 기존 백업 파일이 거부된다. 새 필드는 nullable이라 옛 백업에 키가 없으면 drift가 null로 읽는다(`serializer.fromJson<int?>(json['degassingDays'])`). 백업 **형식**이 깨진 것이 아니므로 버전을 올릴 이유가 없다.

내보내기는 drift 생성 `toJson`이 새 키를 자동으로 싣는다. 코덱 코드는 손대지 않는다.

## 4. 파일 영향

**신규**

- `lib/features/tasting/degassing.dart` — `degassingLabel`
- `test/unit/degassing_test.dart`
- `test/unit/migration_test.dart`

**수정**

- `lib/data/tables.dart` — `Tastings.degassingDays`
- `lib/data/database.dart` — `schemaVersion` 2 + `onUpgrade`
- `lib/data/database.g.dart` — 코드 생성 결과
- `lib/data/models.dart` — `TastingInput.degassingDays`
- `lib/data/bean_repository.dart` — `TastingInput` → 컴패니언 매핑
- `lib/features/tasting/tasting_form_screen.dart` — `roastDate` 파라미터 + 디개싱 줄
- `lib/features/beans/bean_detail_screen.dart` — 호출부 2곳 + `_tastingRow` 알약
- `test/widget/tasting_form_test.dart` · `tasting_edit_test.dart` · `keyboard_dismiss_test.dart` — `roastDate: null` 추가
- `test/widget/bean_detail_test.dart` — 시음 카드 알약 케이스 추가
- `test/unit/backup_codec_test.dart` — 옛 백업 디코드 케이스 추가
- `docs/mockups/degassing-days.html` — 목업

**불변**

- `lib/features/settings/backup_codec.dart` — `_schemaVersion` 1 유지, 코드 변경 없음
- OCR 파이프라인 · 취향 대시보드 · 원두 폼

## 5. 테스트 전략 (`docs/testing.md` 3계층)

### 단위 — `test/unit/degassing_test.dart`

- §3.2 표 6줄 각각
- **UTC 정규화 판별**: 시각이 다른 두 `DateTime`(로스팅 07-19 00:00, 시음 07-27 23:30)이 9일이 아니라 8일을 내는지
- 큰 값(128일)이 잘리지 않는지

### 단위 — `test/unit/migration_test.dart`

v1 스키마를 raw SQL로 만들고 원두+시음을 넣은 뒤 `AppDatabase`로 연다. 검증: **행이 살아남고**, `degassingDays`가 null이며, FK가 여전히 켜져 있다.

### 단위 — `test/unit/backup_codec_test.dart` (추가)

`degassingDays` 키가 없는 옛 백업 JSON이 그대로 디코드되고 값이 null인지. M5에서 drift `fromJson<List<String>>`이 실제로 깨졌던 전례가 있으므로 추정하지 않고 확인한다.

### 위젯 — `test/widget/tasting_form_test.dart` (추가)

- `roastDate` 있음 → `디개싱 8일` 표시, 입력칸 없음
- 시음일을 바꾸면 표시된 일수가 따라 바뀐다
- `roastDate` 없음 → 입력칸 있음, 값 넣고 저장 → 다시 열면 남아 있다
- 입력칸에 문자·음수를 넣어도 들어가지 않는다

### 위젯 — `test/widget/bean_detail_test.dart` (추가)

알약이 뜨는 시음과 뜨지 않는 시음이 **한 목록에 같이 있을 때** 각각 맞게 그려지는지. `warn` 케이스도 별도로.

### 비회귀

기존 시음 폼·편집·키보드 테스트는 `roastDate: null` 한 줄만 더해 그대로 통과한다.

## 6. 스코프 밖

- **오늘 기준 실시간 카운터** — 원두 리스트·상세의 "지금 로스팅 후 12일". 두 기준이 한 화면에 섞이면 헷갈린다
- **취향 탭 디개싱 분석** — "며칠째를 선호하는가". 데이터가 먼저 쌓여야 의미가 있다
- 로스팅 날짜 역산(§2)
- 입력값 상한 규칙(§3.3)
- 원두 폼의 블렌드 `%` 입력 검증 — M4부터 이월된 별건

## 7. 완료 기준 (DoD)

- `flutter analyze` 0 · `flutter test` 전체 green
- 마이그레이션 테스트가 **v1 데이터의 생존**을 확인한다
- 단위 테스트가 **UTC 정규화**를 판별한다(시각이 섞여도 일수가 안 흔들림)
- 옛 백업(키 없음) 디코드가 확인된다
- 기기에서: 로스팅 날짜 있는 원두 → 자동 표시 / 없는 원두 → 직접 입력 → 카드 알약까지 왕복
- **기기 업데이트 후 기존 시음 기록이 그대로 남아 있다** (마이그레이션 실증)
- 태스크별 SDD 리뷰 + opus 전체-브랜치 리뷰 통과
