# M4 — 취향 대시보드 (설계)

> 상태: 승인됨(2026-07-20). 계획: `milestone-4-plan.md`. 목표 릴리스 **v0.4.0**.
> 목업: [`../mockups/m4-taste-dashboard.html`](../mockups/m4-taste-dashboard.html) · v1 원안 화면 05: [`../mockups/ui-mockup-v1.html`](../mockups/ui-mockup-v1.html)

## 1. 배경 & 목표

탭 2 「취향」은 아직 `'취향 분석은 곧 추가됩니다'` 한 줄짜리 플레이스홀더다(`lib/features/profile/profile_screen.dart`). M1~M3에서 쌓인 원두·시음 데이터를 집계해 **내 취향 프로필**을 되돌려주는 것이 M4다. 새로 입력받는 데이터는 없고, **스키마 변경도 없다** — 4개 위젯이 쓰는 컬럼이 이미 전부 존재한다.

**설계 전제 (브레인스토밍에서 확정):** 사용자의 실제 데이터는 현재 **원두 0~3개** 수준이다. 따라서 **"데이터 부족" 상태는 예외가 아니라 이 화면의 주 경로**다. 폴백·빈 상태를 나중에 덧붙이는 게 아니라 처음부터 1급 시민으로 설계한다.

## 2. 목표 & 범위

**목표:** 설계 [`../design.md`](../design.md) §6의 4개 위젯 + 상단 요약을 데이터가 거의 없는 상태에서도 정직하게 동작하도록 구현한다.

**범위 내:**
- `BeanRepository.watchTasteSnapshot()` — 3테이블 원시 스냅샷 스트림
- `computeTasteProfile()` — 순수 함수 집계 (DB 무관)
- `ProfileScreen` 교체 + 위젯 4종 (요약 행 · 패널 · 막대 줄 · 강도 레이더)
- 폴백 기준 표시(배지) · 전체 빈 상태 · 패널별 빈 상태

**범위 밖(무변경):** DB 스키마, `BeanRepository`의 기존 메서드, 원두/시음 CRUD·폼·OCR, 설정 탭, 백업(M5), 원두 검색/정렬(M5).

## 3. 원안 대비 변경 2건

브레인스토밍에서 근거를 갖고 원안을 바꾼 항목이다.

### 3.1 집계 위치: SQL → **순수 Dart**

로드맵은 "분석 쿼리"라고 적었지만 **위젯 ③은 SQL로 불가능하다.** `beans.cupNotes`는 `StringListConverter`로 **JSON 문자열** 한 칸에 저장된다(`lib/data/converters.dart`). `["블루베리","자스민"]`이 통째로 들어가 있어 `GROUP BY`로 태그 빈도를 셀 수 없다.

②④는 SQL로 가능하지만 그러면 집계 로직이 SQL과 Dart로 쪼개진다. 데이터는 개인용 수십~수백 행이라 SQL 집계의 성능 이점은 0이다.

→ **원두·구성·시음을 한 번 로드해 순수 Dart 함수로 계산한다.** 4개 위젯이 같은 스냅샷을 공유하고, 비율 가중·컵노트 로직이 한곳에 모이며, **DB 없이 유닛 테스트되는 순수 함수**가 된다(M3.3의 `parseOcr`와 같은 이유).

### 3.2 차트: `fl_chart` → **의존성 0**

설계 §7은 `fl_chart`를 적었으나 아직 `pubspec.yaml`에 없다. **목업을 다시 보면 막대 3개는 차트가 아니다** — `<span class="track"><span class="fill" style="width:92%">`, 즉 Flutter로는 `Container` + `FractionallySizedBox`다. 진짜 차트는 레이더 하나뿐이고 그것도 **4축 고정 · 값 0~5**라 일반 레이더보다 훨씬 단순하다.

→ **막대는 위젯 조합, 레이더는 `CustomPainter`.** 새 의존성 0 → iOS CI 리스크 0(배포 제약: 파이프라인이 깨지면 iOS는 존재하지 않는다). 목업 색·모노스페이스와 픽셀 단위로 일치하고, 좌표 계산을 순수 함수로 분리하면 레이더도 유닛 테스트된다.

## 4. 데이터 흐름 & 타입

```
BeanRepository.watchTasteSnapshot()   →  Stream<TasteSnapshot>   (원시 3테이블)
        ↓  .map(computeTasteProfile)                              ← 순수, DB 무관
tasteProfileProvider (StreamProvider)  →  TasteProfile
        ↓
ProfileScreen  →  요약 3숫자 + 패널 4개
```

`watchTasteSnapshot()`은 기존 `watchBeanDetail()`과 같은 패턴을 쓴다: 3테이블을 조인해 **변경 트리거로만** 등록하고(행은 무시) 재조회한다.

```dart
class TasteSnapshot {
  final List<Bean> beans;
  final List<OriginComponent> components;
  final List<Tasting> tastings;
}

class Intensity { final double acidity, sweetness, body, bitterness; }

class Bar { final String label; final double value; }

class TasteProfile {
  final int beanCount, tastingCount;
  final double? topBeanRating;        // 시음 0건이면 null
  final Intensity? intensity;         // 시음 0건이면 null
  final bool intensityHighRatedOnly;  // 배지: '★4+ 기준' / '전체 기준'
  final List<Bar> byCountry, byProcess;   // 값 = 평균★ (0~5)
  final List<Bar> cupNotes;               // 값 = 빈도 (정수를 double로)
  final bool cupNotesHighRatedOnly;       // 배지: '★4+ 빈도' / '전체 빈도'
  bool get isEmpty => tastingCount == 0;
}
```

## 5. 계산 규칙

### 5.1 공통 전제

**시음이 0건이면 `isEmpty`** → 화면 전체가 빈 상태. *원두만 등록하고 시음이 0건이어도 마찬가지다* — 평점 없이는 취향이 없다.

### 5.2 ① 선호 강도 (레이더)

- 모집단: `overall >= 4` 인 시음.
- **0건이면 전체 시음으로 폴백**하고 `intensityHighRatedOnly = false`.
- 값: 산미·단맛·바디·쓴맛 각각 산술평균(1~5).

폴백을 조용히 하지 않는다 — 패널 헤더 배지가 `★4+ 기준` ↔ `전체 기준`으로 바뀌어 **무엇을 보고 있는지 항상 드러난다**. 원두 2~3개 시점엔 ★4+가 0건일 확률이 높아 폴백이 사실상 주 경로다.

### 5.3 ② 원산지별 · ④ 가공방식별 평균 평점 (막대)

전체 시음 기준(★4+ 필터 없음). 각 시음 × 그 원두의 각 구성 → `(키, overall, w)` 로 펼친 뒤:

```
값(키) = Σ(overall × w) / Σ(w)
```

키는 ②가 `country` 문자열, ④가 `Process` **enum**이다(집계 후 `label`로 바꿔 `Bar`에 담는다 — 라벨 문자열로 묶으면 라벨이 겹칠 때 조용히 합쳐진다).

**가중치 `w` — 원두 단위 all-or-nothing:**

| 조건 | w |
|---|---|
| 그 원두의 구성 **전부**에 `ratioPercent`가 있음 | `ratioPercent / 100` |
| 구성 중 **하나라도** `ratioPercent`가 null | 그 원두의 전 구성이 `1 / n` |

싱글 오리진은 `n = 1`이라 비율 유무와 무관하게 항상 `w = 1`.

부분적으로만 채워진 비율을 추측해 메우지 않는 것이 핵심이다(예: 60%만 입력됐을 때 나머지를 나눠 갖게 하지 않는다). 규칙이 원두 단위로 all-or-nothing이라 동작이 명확하고 테스트가 쉽다. `ratioPercent`는 nullable이고 OCR로 자동 채워지지 않으므로 실제로는 균등 경로가 흔하다.

가중치는 **평균**에 쓰이므로(합이 아니라) 어떤 국가가 항상 10% 구성으로만 등장해도 그 국가의 평균은 왜곡되지 않는다. 가중치는 같은 키에 서로 다른 비중의 데이터 포인트가 섞일 때만 작동한다.

### 5.4 ③ 선호 컵노트 (막대)

- 모집단: 시음이 1건 이상이고 **평균 종합★ ≥ 4** 인 원두.
- **0개면 시음이 있는 전체 원두로 폴백**하고 `cupNotesHighRatedOnly = false`.
- 집계: **원두 1표** — 각 원두의 `cupNotes` 태그마다 +1. 한 원두 안의 중복 태그는 1회만 센다.

막대 숫자가 곧 "그 컵노트를 가진 원두 개수"라 직관적이고, 같은 원두를 여러 번 마셨다고 순위가 왜곡되지 않는다.

### 5.5 상단 요약 3숫자

| 항목 | 값 |
|---|---|
| 기록한 원두 | `beans.length` |
| 누적 시음 | `tastings.length` |
| 최고 평점 원두 | **시음이 있는** 원두별 평균★ 중 최댓값 (시음 0건이면 `null` → `—`) |

### 5.6 정렬 · 막대 최대치

**정렬:** 값 내림차순, **동점이면 라벨 오름차순**. 동점 순서가 결정적이어야 테스트가 가능하다.

**막대 트랙 100% 기준:**

| 위젯 | 기준 | 값 표기 | 목업 검증 |
|---|---|---|---|
| ② 원산지 · ④ 가공방식 | **5.0 고정**(별점 만점) | 소수점 1자리 `4.6` | `4.6 → 92%` ✅ |
| ③ 컵노트 | **1위 값 기준 상대** | **정수** `3` | `12 → 100%`, `9 → 75%` ✅ |

`Bar.value`는 셋 다 `double`이지만 **표기 규칙이 다르다** — 컵노트를 `3.0`으로 찍으면 안 된다. 기준값과 표기는 `BarRow` 호출부에서 정한다.

**상위 N 자르기는 하지 않는다.** 데이터가 거의 없는 지금 자를 것이 없고, 필요해지면 M5(검색/정렬)에서 다룬다. YAGNI.

## 6. 화면 & 컴포넌트

```
AppBar '내 취향'
ListView
  SummaryRow                                      기록한 원두 / 누적 시음 / 최고 평점 원두
  DashboardPanel '선호 강도'      배지 ★4+ 기준|전체 기준  → IntensityRadar
  DashboardPanel '원산지별 평균 평점'                      → BarRow × N
  DashboardPanel '선호 컵노트'    배지 ★4+ 빈도|전체 빈도  → BarRow × N
  DashboardPanel '가공방식별 평점'                         → BarRow × N
```

### 6.1 레이더 (`IntensityRadar`)

4축 고정 — 위 산미 → 오른쪽 단맛 → 아래 바디 → 왼쪽 쓴맛(목업 순서). 격자 마름모 5겹(`appLine`), 값 폴리곤은 `crema` 28% 채움 + 2px 테두리 + 꼭짓점 점, 축 라벨은 모노스페이스 `appMuted`. 크기 180×164.

좌표는 순수 함수로 분리한다:

```dart
Offset radarPoint(int axis, double value, {required Offset center, required double radius});
```

**painter가 아니라 이 함수를 유닛 테스트한다.**

### 6.2 막대 (`BarRow`)

라벨(고정폭) · 트랙(`Container` + `FractionallySizedBox`) · 값(모노스페이스)의 `Row` 한 줄.

## 7. 오류 처리 & 빈 상태 레이어링

**프로바이더 레벨:** `beanListProvider` 패턴 그대로 — `loading` → 스피너, `error` → `'불러오기 오류: $e'`.

**순수 함수:** 던지지 않는다. `Σw` 0-나눗셈은 구조적으로 불가능하다 — `w > 0`이므로 모집단이 비면 그 키 자체가 결과에 없다.

**빈 상태 두 층위:**

| 층위 | 조건 | 표시 |
|---|---|---|
| 전체 | `isEmpty` (시음 0건) | **요약 행은 유지**하고 패널 자리에 안내 하나. `최고 평점 원두`는 `—` |
| 패널 | 그 패널의 막대 리스트가 빔 (일반 규칙, 3패널 공통) | 그 패널만 짧은 안내. **패널을 숨기지는 않는다** — 자리가 사라지면 무엇이 빠졌는지 알 수 없다 |

전체 빈 상태에서 요약 행을 남기는 이유: 원두 수는 이미 유효한 정보이고, *"원두 3개는 있는데 시음이 0"* 이라는 상태가 한눈에 읽힌다. 원두가 0개여도 같은 화면을 쓴다(요약이 전부 0) — **평점 없이는 취향이 없다**는 원칙이라 분기하지 않는다.

패널 빈 상태는 세 막대 패널에 공통으로 적용하지만, **실제로 발생하는 건 ③컵노트뿐**이다 — 시음이 있어도 OCR이 컵노트를 못 잡았으면 태그가 전부 비어 있다. ①은 시음이 있으면 항상 값이 있고, ②는 폼이 구성을 최소 1개 요구하며, ④는 `process`가 non-null 기본값이라 항상 값이 있다. 즉 ③은 불가능한 경우에 대한 방어가 아니라 실제로 흔한 경로고, ②④의 안내는 같은 규칙이 공짜로 덮는 것이다.

## 8. 테스트 ([`../testing.md`](../testing.md) 3계층)

| 계층 | 파일 | 내용 |
|---|---|---|
| 유닛 (DB 없음) | `test/unit/taste_profile_test.dart` | 빈 스냅샷 · 원두만 있고 시음 0 · ★4+ 축 평균 · **★4+ 0건 → 폴백 + 배지 false** · **블렌드 60/40 가중평균** · **비율 일부 null → 균등** · 싱글+블렌드 혼합 국가 집계 · 가공방식 집계 · 컵노트 원두 1표 / 원두 내 중복 태그 1회 / 평균★<4 제외 / 폴백 · **동점 시 라벨 오름차순** · `topBeanRating` |
| 유닛 (DB 없음) | `test/unit/intensity_radar_test.dart` | `radarPoint` — 4축 각도, `value` 0/5 경계 |
| 유닛 (인메모리 DB) | `test/unit/taste_snapshot_test.dart` | `watchTasteSnapshot()`가 3테이블을 싣고, 시음 추가 시 재방출 |
| 위젯 | `test/widget/profile_screen_test.dart` | 전체 빈 상태 안내 · 패널 4개 + 막대 렌더 · **배지 텍스트 전환** · 컵노트 전무 시 그 패널만 안내 |

`test/helpers.dart`에 drift 행 팩토리 `beanRow()` / `compRow()` / `tastingRow()` 를 추가한다(약 12개 테스트가 공유). 기존 `sampleSingle()` / `sampleBlend()`(비율 60/40 내장) / `sampleTasting()` 은 그대로 쓴다.

## 9. 실행 규약

M2~M3.3과 동일: **SDD**(태스크별 구현 서브에이전트 + 태스크 리뷰, 마지막에 opus 전체-브랜치 리뷰) · TDD(실패 테스트 → 최소 구현 → 통과 → 커밋) · 태스크 단위 main 직커밋 · 커밋 전 `flutter analyze && flutter test` 초록불.

## 10. 파일 영향

| 파일 | 변경 |
|---|---|
| `lib/data/bean_repository.dart` | `watchTasteSnapshot()` 추가 |
| `lib/data/models.dart` | `TasteSnapshot` 추가 |
| `lib/providers.dart` | `tasteProfileProvider` 추가 |
| `lib/features/profile/taste_profile.dart` | **신규** — `TasteProfile` · `Intensity` · `Bar` · `computeTasteProfile()` |
| `lib/features/profile/profile_screen.dart` | 플레이스홀더 → 대시보드 |
| `lib/features/profile/widgets/summary_row.dart` | **신규** |
| `lib/features/profile/widgets/dashboard_panel.dart` | **신규** |
| `lib/features/profile/widgets/bar_row.dart` | **신규** |
| `lib/features/profile/widgets/intensity_radar.dart` | **신규** — `CustomPainter` + `radarPoint()` |
| `test/helpers.dart` | 행 팩토리 3개 추가 |
| `test/unit/taste_profile_test.dart` | **신규** |
| `test/unit/intensity_radar_test.dart` | **신규** |
| `test/unit/taste_snapshot_test.dart` | **신규** |
| `test/widget/profile_screen_test.dart` | **신규** |

DB 스키마·마이그레이션 변경 없음. 새 패키지 의존성 없음.
