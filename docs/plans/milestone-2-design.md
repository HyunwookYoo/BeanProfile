# ☕ BeanProfile — M2 설계: 원두 편집/삭제 & 시음 기록

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-18 |
| 상태 | 설계 승인 (브레인스토밍) → 구현 계획(writing-plans) 대기 |
| 마일스톤 | M2 |
| 선행 | M1 (원두 추가/조회) **DONE** · `v0.1.0` |
| 상위 문서 | 설계 [`../design.md`](../design.md) · 로드맵 [`roadmap.md`](roadmap.md) · 목업 [`../mockups/ui-mockup-v1.html`](../mockups/ui-mockup-v1.html) · 테스트 [`../testing.md`](../testing.md) |

---

## 1. 목표 & 범위

M2 완료 시 동작하는 것: **원두 편집·삭제** · **시음 완전 CRUD**(강도 4축 + 종합 별점 + 코멘트) · 상세 화면의 시음 리스트 · **평균 별점** 표시.

### 확정 범위 (브레인스토밍 2026-07-18)

| 결정 | 선택 |
|---|---|
| 시음(Tasting) 범위 | **완전 CRUD** (생성·수정·삭제). 원두와 대칭이고 저널 앱 실사용에 필요 |
| 원두 편집 범위 | **원두 필드 + 구성(OriginComponent) 전체**. 추가 폼 재사용 + 구성 전체 교체 |

M1에서 이미 완료되어 M2가 **재사용**하는 것:
- `watchBeanSummaries`(repo:40)가 SQL 집계(`AVG(overall)`·`COUNT(id)` + `LEFT JOIN tastings`)로 **리스트 평균★·시음횟수를 이미 계산**하며, 조인이 `tastings`를 참조하므로 **시음 쓰기에 리스트가 자동 갱신**된다. → "평균 별점 계산"은 리스트 측에서 사실상 완료.
- `getBeanDetail`(repo:74)가 시음을 `date` 내림차순으로 이미 로드.
- FK CASCADE + 마이그레이션 `PRAGMA foreign_keys = ON`이 켜져 있어 원두 삭제 시 구성·시음이 자동 정리.

---

## 2. 접근법 결정

| 결정 | 선택 | 근거 / 기각한 대안 |
|---|---|---|
| **편집 폼** | 기존 `BeanFormScreen`에 `existing` 파라미터 추가 → 프리필 후 `updateBean` | "편집 = 프리필된 추가" 모델, DRY. 대안(별도 편집 화면)은 폼 로직 중복 → 기각 |
| **구성 편집** | 저장 시 해당 원두의 구성을 **전체 교체**(delete-all → re-insert) | 구성은 다른 테이블이 FK로 참조하지 않아 교체가 안전(분석은 쿼리 시점에 원두→국가 귀속). row-diff 로직 불필요 |
| **시음 폼** | 신규 `TastingFormScreen({beanId, existing?})` 생성/편집 겸용 | 원두 폼과 동일한 파라미터화 패턴. 삭제는 편집 모드에서 노출 |
| **상세 평균★** | `BeanDetail.tastings`에서 Dart로 계산(getter) | 개인용이라 N이 작음. 별도 집계 쿼리 불필요 |
| **상세 반응성** | `watchBeanDetail`(repo:88)를 **beans + tastings + originComponents 3테이블 watch**로 교체 | 현재 `beans` 행만 watch → 시음/구성 쓰기에 무반응(M1 리뷰 발견). join-to-register로 3테이블 등록 후 `asyncMap`으로 `getBeanDetail` 재조회 |
| **시음 삭제 경로** | 시음 행 탭 → 편집 화면의 삭제 버튼(확인 다이얼로그) | 단일 경로·단순. 스와이프-삭제/undo는 폴리시로 이후 |
| **원두 삭제** | 상세 AppBar 휴지통 → 확인 다이얼로그 → `deleteBean` → 리스트로 pop | CASCADE로 구성·시음 자동 삭제. 되돌리기 없음(v1) |

---

## 3. 데이터 계층

### 3.1 모델 — `lib/data/models.dart`

신규 입력 DTO:

```dart
class TastingInput {
  final DateTime date;
  final int acidity, sweetness, body, bitterness, overall; // 각 1–5
  final String? comment;
  const TastingInput({
    required this.date,
    required this.acidity,
    required this.sweetness,
    required this.body,
    required this.bitterness,
    required this.overall,
    this.comment,
  });
}
```

`BeanDetail`에 계산 getter 추가(리포지토리·쿼리 변경 없음):

```dart
int get tastingCount => tastings.length;
double? get avgRating => tastings.isEmpty
    ? null
    : tastings.map((t) => t.overall).reduce((a, b) => a + b) / tastings.length;
```

### 3.2 Repository — `lib/data/bean_repository.dart`

추가 메서드(시그니처 + 핵심 시맨틱). 구현은 계획 단계에서 상세화.

```dart
// 원두 필드 update + 구성 전체 교체. createdAt 보존(update 대상 아님).
Future<void> updateBean(int beanId, BeanInput input);   // 트랜잭션

// beans 행 삭제 → FK CASCADE로 originComponents + tastings 자동 삭제
Future<void> deleteBean(int beanId);

Future<int>  createTasting(int beanId, TastingInput t); // createdAt = now()
Future<void> updateTasting(int tastingId, TastingInput t); // beanId·createdAt 보존
Future<void> deleteTasting(int tastingId);
```

- `updateBean`은 **항상 beans 행을 write**한다(구성만 바뀌어도). → 리스트/상세 watch가 확실히 재방출됨.
- `updateTasting`은 `beanId`·`createdAt`을 건드리지 않는다(companion에서 해당 필드 생략).

### 3.3 상세 반응성 — `watchBeanDetail`

**요구사항:** beans·tastings·originComponents 중 **어느 하나라도 쓰기가 발생하면** 재방출해야 한다. 권장 구현은 기존 `watchBeanSummaries`와 같은 join-to-register(조인으로 watch 대상 테이블 등록, 행은 무시하고 `getBeanDetail`로 재조회):

```dart
Stream<BeanDetail?> watchBeanDetail(int beanId) {
  final q = db.select(db.beans).join([
    leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
    leftOuterJoin(db.originComponents, db.originComponents.beanId.equalsExp(db.beans.id)),
  ])..where(db.beans.id.equals(beanId));
  return q.watch().asyncMap((_) => getBeanDetail(beanId));
}
```

원두 삭제 시 조인 결과가 0행 → `getBeanDetail` → `null` → 상세는 "삭제된 원두예요" 표시.

### 3.4 Provider — `lib/providers.dart`

`beanDetailProvider`를 `autoDispose`로 변경(상세를 벗어나면 스트림 구독 해제):

```dart
final beanDetailProvider =
    StreamProvider.autoDispose.family<BeanDetail?, int>(
  (ref, beanId) => ref.watch(beanRepositoryProvider).watchBeanDetail(beanId),
);
```

---

## 4. 화면 & UX

목업(`ui-mockup-v1.html`)의 시각 언어를 그대로 따른다. 새 시각 자료 없음.

### 4.1 원두 상세 — `bean_detail_screen.dart` (수정)
- **AppBar 액션:** ✎ 편집 · 🗑 삭제
- **상단:** 이름/로스터 아래 **평균★(`StarRating`) · 시음 N회** 표시
- **시음 리스트:** 각 행에 **종합 별점 표시**, 행 **탭 → 시음 편집**. 빈 상태 문구에서 "다음 단계에서 추가" 제거
- **하단 `bottomNavigationBar`:** "시음 추가" 버튼 — ListView `cacheExtent` 테스트 함정(M1 교훈) 회피 겸 주요 액션 고정

### 4.2 원두 편집 — `bean_form_screen.dart` (수정, 재사용)
- 생성자에 `BeanDetail? existing` 추가. `existing != null`이면 AppBar "원두 편집", 컨트롤러·구성·enum 프리필, 저장 시 `updateBean(existing.bean.id, input)` 호출
- 폼이 잡는 구성 필드는 국가·지역·가공·비율(현행 유지). farm/variety/altitude는 폼 범위 밖 → §9 참조

### 4.3 시음 폼 — `lib/features/tasting/tasting_form_screen.dart` (신규)
- 필드: 날짜(기본 오늘, `showDatePicker`) · 강도 4축(도트 슬라이더) · 종합 별점(입력) · 코멘트(멀티라인)
- 저장 버튼 `bottomNavigationBar`. 편집 모드에서 삭제 버튼(확인 다이얼로그) 노출
- 생성 시 `createTasting(beanId, input)`, 편집 시 `updateTasting(existing.id, input)`

### 4.4 입력 위젯 (신규) — `lib/features/tasting/widgets/`
- `IntensitySelector` — 1–5 도트 탭 선택(강도 4축용)
- `StarInput` — 1–5 별 탭 선택(종합용). 기존 `StarRating`은 **표시 전용 유지**

### 4.5 실패 처리 (M2-prep d)
두 폼의 저장을 `try/catch`로 감싼다: 실패 시 `_saving = false` 리셋 + `SnackBar`로 알림, 성공 시 `pop`. (현재 `bean_form_screen`은 `createBean` 실패 시 `_saving`이 영구히 true로 남음.)

---

## 5. 테스트 전략 (docs/testing.md 3계층)

### 5.1 공유 헬퍼 (신규, M2-prep c) — `test/helpers.dart`
인메모리 `AppDatabase`(NativeDatabase.memory) + `BeanRepository` 생성 헬퍼, 위젯 테스트용 `pumpApp(tester, overrides)` 헬퍼. 신규 M2 테스트가 사용(기존 테스트 마이그레이션은 중복이 실제로 줄 때만, 최소 변경).

### 5.2 리포지토리 테스트
- `updateBean`: 필드 갱신 + 구성 교체(옛 구성 제거·새 구성 존재)
- **`deleteBean` CASCADE**(M2-prep e): 해당 원두의 tastings·originComponents가 함께 삭제, 다른 원두는 무영향
- 시음 CRUD 왕복(create→read→update→delete)
- 시음 추가 후 `watchBeanSummaries`의 `avgRating`/`tastingCount` 재계산
- **`watchBeanDetail` 재방출**(반응성 회귀): listen 후 `createTasting` → 새 emission에 시음 포함

### 5.3 위젯 테스트
- 시음 폼: 입력 → 저장 → pop, 필수/검증
- 상세: 편집/삭제/시음추가 네비게이션, 삭제 확인 다이얼로그
- 원두 폼 편집 모드 프리필

---

## 6. M2-prep 5건 착지점

| # | 항목 | 위치 |
|---|---|---|
| a | `watchBeanDetail` 3테이블 재방출 | §3.3 · T1 |
| b | `beanDetailProvider` autoDispose | §3.4 · T1 |
| c | `test/helpers.dart` 생성 | §5.1 · T1 |
| d | 폼 `_saving` 리셋 + SnackBar | §4.5 · T3·T5 |
| e | Tastings-cascade 테스트 | §5.2 · T1 |

---

## 7. 태스크 분해 (writing-plans에서 상세화)

각 태스크: 실패 테스트 → 최소 구현 → 통과 → 커밋(main 직접). 태스크별 SDD 리뷰 + 최종 opus 전체브랜치 리뷰(M1과 동일).

1. **기반 정비** — `watchBeanDetail` 반응성, `beanDetailProvider` autoDispose, `test/helpers.dart`, cascade 테스트 (prep a·b·c·e)
2. **TastingInput + createTasting** — 모델 + repo + 테스트
3. **시음 입력 화면(생성)** — `TastingFormScreen` + `IntensitySelector`/`StarInput` + 상세 "시음 추가" 연결 + 실패 처리(d)
4. **시음 수정/삭제** — `updateTasting`/`deleteTasting` + 폼 편집 모드/삭제 + 상세 행 탭·삭제
5. **원두 편집** — `updateBean` + 구성 교체 + 폼 편집 모드 + 상세 편집 액션 + 실패 처리(d)
6. **원두 삭제** — `deleteBean` + 상세 삭제 액션 + 확인 다이얼로그
7. **상세 평균★·시음 행 정리** — `BeanDetail` getter 표시 + placeholder 제거

---

## 8. 파일 영향

**신규**
- `lib/features/tasting/tasting_form_screen.dart`
- `lib/features/tasting/widgets/intensity_selector.dart`
- `lib/features/tasting/widgets/star_input.dart`
- `test/helpers.dart` + M2 테스트 파일들

**수정**
- `lib/data/models.dart` — `TastingInput`, `BeanDetail` getter
- `lib/data/bean_repository.dart` — 5개 메서드 + `watchBeanDetail`
- `lib/providers.dart` — `beanDetailProvider` autoDispose
- `lib/features/beans/bean_form_screen.dart` — 편집 모드 + 실패 처리
- `lib/features/beans/bean_detail_screen.dart` — 평균★·액션·시음추가·행 탭

---

## 9. 스코프 밖 · 가정 · 리스크

**스코프 밖**(design.md §8 및 이후 마일스톤): 브루잉 파라미터 · 되돌리기/소프트삭제 · 스와이프-삭제 · farm/variety/altitude 폼 입력 · 검색/정렬(M5) · OCR(M3).

**가정 / 리스크**
- **구성 전체 교체의 무손실성:** 폼이 국가·지역·가공·비율만 잡으므로 farm/variety/altitude는 생성 때도 비어 있어 편집 교체로 손실될 값이 없다. M3에서 OCR이 이 필드를 채우면 그 시점에 폼 확장 또는 편집 전략 재검토 필요.
- **리스트 originLabel 갱신:** `watchBeanSummaries`는 originComponents를 watch하지 않지만, `updateBean`이 항상 beans 행을 write하므로 리스트가 재방출되어 실사용상 최신 유지.
- **삭제 후 네비게이션:** 상세에서 원두 삭제 시 리스트로 pop. 상세가 열린 채 스트림이 `null`을 emit해도 "삭제된 원두예요" 폴백이 있어 안전.
