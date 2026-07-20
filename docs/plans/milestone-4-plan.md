# M4 취향 대시보드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 탭 2「취향」의 플레이스홀더를 상단 요약 3숫자 + 위젯 4개(선호 강도 레이더 · 원산지별 평점 · 선호 컵노트 · 가공방식별 평점) 대시보드로 교체한다.

**Architecture:** `BeanRepository.watchTasteSnapshot()`이 3테이블 원시 스냅샷을 스트림으로 흘리고, **순수 함수** `computeTasteProfile(TasteSnapshot)`이 전부 계산한다(SQL 집계 없음 — `beans.cupNotes`가 JSON 문자열이라 `GROUP BY`로 태그 빈도를 셀 수 없다). 차트는 새 의존성 없이 그린다: 막대는 `Container`+`FractionallySizedBox`, 레이더는 `CustomPainter` + 순수 좌표 함수. 데이터가 거의 없는 상태(★4+ 0건, 시음 0건)가 주 경로이므로 폴백과 빈 상태를 1급으로 다룬다.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, drift 2.31, flutter_riverpod 3.3.2. **새 패키지 의존성 없음.** 테스트: flutter_test(호스트 3계층).

**Spec:** `docs/plans/milestone-4-design.md` · 목업: `docs/mockups/m4-taste-dashboard.html`

## Global Constraints

- 한국어 UI 문자열. 오프라인·로컬 전용(네트워크 없음).
- **DB 스키마·마이그레이션 무변경. 새 패키지 의존성 추가 금지**(`pubspec.yaml` 무변경).
- `BeanRepository`의 기존 메서드·`BeanInput`/`BeanSummary`/`BeanDetail`·원두/시음 CRUD·폼·OCR·설정 탭 **무변경**.
- 테마에 있는 색은 반드시 `context.colors.*`(`AppColors`)에서, 모노스페이스 수치는 `monoStyle(...)`에서 가져온다. **예외:** 목업 전용 파생 톤 두 개(`#EAD9BE` 폴백 배지 배경, `#D3A862` 빈도 막대 그라데이션 끝)는 각각 한 곳에서만 쓰이므로 해당 위젯 파일 안에 `const`로 둔다 — 단일 사용처를 위해 `AppColors`를 늘리지 않는다.
- SDD: 구현·태스크리뷰·수정 sonnet, 최종 전체-브랜치 리뷰 opus. main 직접 커밋. 진행원장 `.superpowers/sdd/progress.md`에 M4 섹션 추가(gitignore, controller 소유).
- 커밋 트레일러: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- 각 커밋 전 `flutter analyze`(0 이슈) + 관련 테스트 green. 목표 릴리스 **v0.4.0**.
- Windows 호스트에서 `flutter test` 출력이 간헐적으로 파일 단위로 누락·중복된다(성공 보고는 유지). 의심되면 `flutter test --concurrency=1 -r expanded`로 재실행해 확인한다.
- `flutter analyze`는 `integration_test/`도 검사한다 — lib 시그니처를 바꾸면 그쪽 호출부도 같이 고쳐야 게이트를 통과한다. (M4는 `integration_test/`를 건드리지 않지만 lib 시그니처 변경이 없는지 확인할 것.)

## File Structure

- `lib/data/models.dart` — `TasteSnapshot` 값 타입 추가 (Task 1).
- `lib/data/bean_repository.dart` — `getTasteSnapshot()` / `watchTasteSnapshot()` 추가 (Task 1).
- `lib/features/profile/taste_profile.dart` — **신규.** `Intensity` · `Bar` · `TasteProfile` · `componentWeights()` · `computeTasteProfile()`. 순수 Dart(Flutter 위젯 의존 없음) (Task 2·3).
- `lib/features/profile/widgets/summary_row.dart` — **신규.** 상단 stat 3개 (Task 4).
- `lib/features/profile/widgets/dashboard_panel.dart` — **신규.** 제목 + 배지 + child 카드 (Task 4).
- `lib/features/profile/widgets/bar_row.dart` — **신규.** 막대 한 줄 (Task 4).
- `lib/features/profile/widgets/intensity_radar.dart` — **신규.** `radarPoint()` 순수 함수 + `IntensityRadar` + `CustomPainter` (Task 5).
- `lib/providers.dart` — `tasteProfileProvider` 추가 (Task 6).
- `lib/features/profile/profile_screen.dart` — 플레이스홀더 → 대시보드 (Task 6).
- `test/helpers.dart` — drift 행 팩토리 `beanRow()`/`compRow()`/`tastingRow()` 추가 (Task 2).
- `test/unit/taste_snapshot_test.dart` — **신규** (Task 1).
- `test/unit/taste_profile_test.dart` — **신규** (Task 2·3).
- `test/unit/intensity_radar_test.dart` — **신규** (Task 5).
- `test/widget/profile_screen_test.dart` — **신규** (Task 6).

---

### Task 1: 데이터 레이어 — `TasteSnapshot` + `watchTasteSnapshot()`

순수 부가 작업. 기존 메서드·소비자는 건드리지 않으므로 저장소는 계속 컴파일되고 기존 테스트는 그대로 green.

**Files:**
- Modify: `lib/data/models.dart` (파일 끝에 `TasteSnapshot` 추가)
- Modify: `lib/data/bean_repository.dart` (`watchBeanDetail` 아래, 클래스 닫는 `}` 앞에 추가)
- Test: `test/unit/taste_snapshot_test.dart` (신규)

**Interfaces:**
- Consumes: 없음(기존 `AppDatabase` 테이블만).
- Produces:
  - `class TasteSnapshot { final List<Bean> beans; final List<OriginComponent> components; final List<Tasting> tastings; const TasteSnapshot({required this.beans, required this.components, required this.tastings}); }`
  - `Future<TasteSnapshot> BeanRepository.getTasteSnapshot()`
  - `Stream<TasteSnapshot> BeanRepository.watchTasteSnapshot()`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/taste_snapshot_test.dart` 를 새로 만든다:

```dart
import 'package:async/async.dart';
import 'package:beanprofile/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('watchTasteSnapshot이 3테이블을 모두 싣는다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleBlend()); // 구성 2개
    await repo.createTasting(id, sampleTasting(overall: 5));

    final snap = await repo.watchTasteSnapshot().first;
    expect(snap.beans, hasLength(1));
    expect(snap.components, hasLength(2));
    expect(snap.tastings, hasLength(1));
    expect(snap.tastings.first.overall, 5);

    // `.first`는 구독 후 즉시 취소 → drift가 취소 시 0ms 디바운스 Timer를
    // 예약하는데, 테스트 바인딩의 pending-timer 검사가 그보다 먼저 돈다.
    // 여기서 닫아 두면 drift가 그 Timer를 건너뛴다(_isShuttingDown).
    await db.close();
  });

  test('원두가 하나도 없으면 빈 스냅샷을 방출한다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);

    final snap = await repo.watchTasteSnapshot().first;
    expect(snap.beans, isEmpty);
    expect(snap.components, isEmpty);
    expect(snap.tastings, isEmpty);
    await db.close();
  });

  test('시음이 삽입되면 재방출된다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    final queue = StreamQueue(repo.watchTasteSnapshot());
    final first = await queue.next; // 최초 방출 — 결정적
    expect(first.tastings, isEmpty);

    await db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: id, date: DateTime(2026, 7, 1),
          acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: 4,
          createdAt: DateTime(2026, 7, 1),
        ));

    final second = await queue.next; // watchTasteSnapshot이 재방출해야만 완료됨
    expect(second.tastings, hasLength(1));
    await queue.cancel();
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/unit/taste_snapshot_test.dart`
Expected: 컴파일 에러 — `The method 'watchTasteSnapshot' isn't defined for the type 'BeanRepository'`

- [ ] **Step 3: `TasteSnapshot` 추가**

`lib/data/models.dart` 파일 **맨 끝**에 추가(기존 내용 수정 금지):

```dart
/// 취향 분석용 원시 스냅샷 — 3테이블 전부. 집계는 하지 않는다.
/// (`computeTasteProfile`이 순수 함수로 계산한다)
class TasteSnapshot {
  final List<Bean> beans;
  final List<OriginComponent> components;
  final List<Tasting> tastings;
  const TasteSnapshot({
    required this.beans,
    required this.components,
    required this.tastings,
  });
}
```

- [ ] **Step 4: 저장소 메서드 추가**

`lib/data/bean_repository.dart` 의 `watchBeanDetail(...)` 메서드 **아래**, 클래스 닫는 `}` **앞**에 추가:

```dart
  Future<TasteSnapshot> getTasteSnapshot() async {
    final beans = await db.select(db.beans).get();
    final components = await db.select(db.originComponents).get();
    final tastings = await db.select(db.tastings).get();
    return TasteSnapshot(
        beans: beans, components: components, tastings: tastings);
  }

  Stream<TasteSnapshot> watchTasteSnapshot() {
    // 셋 중 무엇이 바뀌어도 재방출되도록 3테이블을 조인으로 등록한다.
    // 조인 결과 행은 쓰지 않고(중복 행이 나옴) 트리거로만 쓴 뒤
    // getTasteSnapshot으로 재조회한다 — watchBeanDetail과 같은 패턴.
    final trigger = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
      leftOuterJoin(db.originComponents,
          db.originComponents.beanId.equalsExp(db.beans.id)),
    ]);
    return trigger.watch().asyncMap((_) => getTasteSnapshot());
  }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/unit/taste_snapshot_test.dart`
Expected: PASS (3개 테스트)

- [ ] **Step 6: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 기존 92개 + 신규 3개 = **95개 PASS**

- [ ] **Step 7: 커밋**

```bash
git add lib/data/models.dart lib/data/bean_repository.dart test/unit/taste_snapshot_test.dart
git commit -m "feat(m4): TasteSnapshot + watchTasteSnapshot 3테이블 스트림"
```

---

### Task 2: 순수 집계 ① — 타입 + 구성 가중치 + 요약 + 선호 강도

`computeTasteProfile`의 뼈대와 **가중치 규칙**(원두 단위 all-or-nothing), 요약 3숫자, ①선호 강도(★4+ → 전체 폴백)를 만든다. 막대 3종(`byCountry`/`byProcess`/`cupNotes`)은 **이번 태스크에서 의도적으로 빈 리스트**를 반환하고 Task 3에서 채운다.

**Files:**
- Create: `lib/features/profile/taste_profile.dart`
- Modify: `test/helpers.dart` (파일 끝에 drift 행 팩토리 3개 추가)
- Test: `test/unit/taste_profile_test.dart` (신규)

**Interfaces:**
- Consumes: `TasteSnapshot`(Task 1), drift 행 타입 `Bean`/`OriginComponent`/`Tasting`(`lib/data/database.dart`), `Process` enum(`lib/data/enums.dart`).
- Produces:
  - `class Intensity { final double acidity, sweetness, body, bitterness; const Intensity({required ...}); }`
  - `class Bar { final String label; final double value; const Bar(this.label, this.value); }` — **위치 인자**
  - `class TasteProfile { final int beanCount, tastingCount; final double? topBeanRating; final Intensity? intensity; final bool intensityHighRatedOnly; final List<Bar> byCountry, cupNotes, byProcess; final bool cupNotesHighRatedOnly; bool get isEmpty; }`
  - `List<double> componentWeights(List<OriginComponent> comps)`
  - `TasteProfile computeTasteProfile(TasteSnapshot snap)` — 이번 태스크에서 `byCountry`/`byProcess`/`cupNotes`는 항상 `const []`, `cupNotesHighRatedOnly`는 항상 `false`. **Task 3이 채운다.**
  - 테스트 헬퍼: `Bean beanRow({int id, String name, List<String> cupNotes})` · `OriginComponent compRow({int id, int beanId, String country, Process process, int? ratioPercent})` · `Tasting tastingRow({int id, int beanId, int overall, int acidity, int sweetness, int body, int bitterness})`

- [ ] **Step 1: 테스트 헬퍼(drift 행 팩토리) 추가**

`test/helpers.dart` 파일 **맨 끝**에 추가. 필요한 import(`database.dart` · `enums.dart`)는 이미 상단에 있으므로 추가하지 않는다:

```dart
// ── 순수 함수(computeTasteProfile) 테스트용 drift 행 팩토리 ──
// BeanInput이 아니라 DB에서 읽힌 '행' 그대로가 필요해서 직접 만든다(DB 불필요).

Bean beanRow({int id = 1, String name = '원두', List<String> cupNotes = const []}) =>
    Bean(
      id: id, name: name, roaster: '', type: BeanType.singleOrigin,
      cupNotes: cupNotes, createdAt: DateTime(2026, 7, 1),
    );

OriginComponent compRow({
  int id = 1,
  int beanId = 1,
  String country = 'Ethiopia',
  Process process = Process.washed,
  int? ratioPercent,
}) =>
    OriginComponent(
      id: id, beanId: beanId, country: country,
      process: process, ratioPercent: ratioPercent,
    );

Tasting tastingRow({
  int id = 1,
  int beanId = 1,
  int overall = 4,
  int acidity = 3,
  int sweetness = 3,
  int body = 3,
  int bitterness = 3,
}) =>
    Tasting(
      id: id, beanId: beanId, date: DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall,
      createdAt: DateTime(2026, 7, 1),
    );
```

> drift가 생성한 행 클래스의 nullable 컬럼은 생성자에서 생략 가능하다. 만약 생성자가 어떤 인자를 required로 요구해 컴파일이 실패하면 `lib/data/database.g.dart` 에서 해당 클래스 생성자를 확인하고 **기본값을 채워** 넘긴다(팩토리 시그니처는 바꾸지 말 것).

- [ ] **Step 2: 실패하는 테스트 작성**

`test/unit/taste_profile_test.dart` 를 새로 만든다:

```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/profile/taste_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

TasteSnapshot snap({
  List<Bean> beans = const [],
  List<OriginComponent> components = const [],
  List<Tasting> tastings = const [],
}) =>
    TasteSnapshot(beans: beans, components: components, tastings: tastings);

void main() {
  group('빈 상태', () {
    test('완전히 빈 스냅샷 → isEmpty', () {
      final p = computeTasteProfile(snap());
      expect(p.isEmpty, isTrue);
      expect(p.beanCount, 0);
      expect(p.tastingCount, 0);
      expect(p.topBeanRating, isNull);
      expect(p.intensity, isNull);
    });

    test('원두만 있고 시음 0건 → isEmpty지만 beanCount는 센다', () {
      final p = computeTasteProfile(snap(beans: [beanRow(id: 1), beanRow(id: 2)]));
      expect(p.isEmpty, isTrue);
      expect(p.beanCount, 2);
      expect(p.topBeanRating, isNull);
      expect(p.intensity, isNull);
    });
  });

  group('구성 가중치 — 원두 단위 all-or-nothing', () {
    test('구성 전부에 비율이 있으면 ratio/100', () {
      final w = componentWeights([
        compRow(id: 1, country: 'Brazil', ratioPercent: 60),
        compRow(id: 2, country: 'Ethiopia', ratioPercent: 40),
      ]);
      expect(w, [0.6, 0.4]);
    });

    test('하나라도 null이면 전 구성이 1/n', () {
      final w = componentWeights([
        compRow(id: 1, country: 'Brazil', ratioPercent: 60),
        compRow(id: 2, country: 'Ethiopia'), // null
      ]);
      expect(w, [0.5, 0.5]);
    });

    test('싱글 오리진은 비율 유무와 무관하게 1.0', () {
      expect(componentWeights([compRow()]), [1.0]);
      expect(componentWeights([compRow(ratioPercent: 100)]), [1.0]);
    });

    test('구성이 없으면 빈 리스트', () {
      expect(componentWeights(const []), isEmpty);
    });
  });

  group('요약 3숫자', () {
    test('최고 평점 원두 = 시음이 있는 원두별 평균★의 최댓값', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2), beanRow(id: 3)], // 3번은 시음 없음
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 1, overall: 3), // 1번 평균 4.0
          tastingRow(id: 3, beanId: 2, overall: 5), // 2번 평균 5.0
        ],
      ));
      expect(p.beanCount, 3);
      expect(p.tastingCount, 3);
      expect(p.topBeanRating, 5.0);
      expect(p.isEmpty, isFalse);
    });
  });

  group('① 선호 강도', () {
    test('★4+가 있으면 그 시음들만 평균내고 배지는 ★4+ 기준', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 5, acidity: 4, sweetness: 4, body: 2, bitterness: 2),
          tastingRow(id: 2, overall: 4, acidity: 2, sweetness: 2, body: 4, bitterness: 4),
          tastingRow(id: 3, overall: 1, acidity: 5, sweetness: 5, body: 5, bitterness: 5), // 제외
        ],
      ));
      expect(p.intensityHighRatedOnly, isTrue);
      expect(p.intensity!.acidity, 3.0);    // (4+2)/2
      expect(p.intensity!.sweetness, 3.0);
      expect(p.intensity!.body, 3.0);
      expect(p.intensity!.bitterness, 3.0);
    });

    test('★4+가 0건이면 전체 시음으로 폴백하고 배지는 전체 기준', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 3, acidity: 2, sweetness: 2, body: 2, bitterness: 2),
          tastingRow(id: 2, overall: 2, acidity: 4, sweetness: 4, body: 4, bitterness: 4),
        ],
      ));
      expect(p.intensityHighRatedOnly, isFalse);
      expect(p.intensity!.acidity, 3.0);    // (2+4)/2
      expect(p.intensity!.bitterness, 3.0);
    });

    test('★4는 경계값으로 포함된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 4, acidity: 5),
          tastingRow(id: 2, overall: 3, acidity: 1), // 제외돼야 함
        ],
      ));
      expect(p.intensityHighRatedOnly, isTrue);
      expect(p.intensity!.acidity, 5.0);
    });
  });
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: `flutter test test/unit/taste_profile_test.dart`
Expected: 컴파일 에러 — `Target of URI doesn't exist: 'package:beanprofile/features/profile/taste_profile.dart'`

- [ ] **Step 4: `taste_profile.dart` 작성**

`lib/features/profile/taste_profile.dart` 를 새로 만든다:

```dart
import '../../data/database.dart';
import '../../data/models.dart';

/// 강도 4축 평균 (1~5).
class Intensity {
  final double acidity, sweetness, body, bitterness;
  const Intensity({
    required this.acidity,
    required this.sweetness,
    required this.body,
    required this.bitterness,
  });
}

/// 막대 한 줄. `value`의 의미(평점 0~5 / 빈도 정수)와 표기는 소비자가 정한다.
class Bar {
  final String label;
  final double value;
  const Bar(this.label, this.value);
}

/// 대시보드가 그리는 데 필요한 모든 값. 계산은 전부 `computeTasteProfile`에서 끝난다.
class TasteProfile {
  final int beanCount, tastingCount;
  final double? topBeanRating;
  final Intensity? intensity;
  final bool intensityHighRatedOnly;
  final List<Bar> byCountry, cupNotes, byProcess;
  final bool cupNotesHighRatedOnly;

  const TasteProfile({
    required this.beanCount,
    required this.tastingCount,
    required this.topBeanRating,
    required this.intensity,
    required this.intensityHighRatedOnly,
    required this.byCountry,
    required this.cupNotes,
    required this.byProcess,
    required this.cupNotesHighRatedOnly,
  });

  /// 시음이 0건이면 계산할 취향이 없다 — 원두만 등록된 경우도 포함.
  bool get isEmpty => tastingCount == 0;
}

/// 한 원두의 구성별 가중치.
///
/// 구성 **전부**에 비율이 있으면 `ratio/100`, **하나라도** 비어 있으면 전 구성이 `1/n`.
/// 부분적으로 채워진 비율을 추측해 메우지 않는다(원두 단위 all-or-nothing).
/// 싱글 오리진은 n=1이라 항상 1.0.
List<double> componentWeights(List<OriginComponent> comps) {
  if (comps.isEmpty) return const [];
  if (comps.any((c) => c.ratioPercent == null)) {
    return List.filled(comps.length, 1 / comps.length);
  }
  return [for (final c in comps) c.ratioPercent! / 100];
}

Intensity _meanIntensity(List<Tasting> ts) {
  double avg(int Function(Tasting) f) =>
      ts.map(f).reduce((a, b) => a + b) / ts.length;
  return Intensity(
    acidity: avg((t) => t.acidity),
    sweetness: avg((t) => t.sweetness),
    body: avg((t) => t.body),
    bitterness: avg((t) => t.bitterness),
  );
}

double _meanOverall(List<Tasting> ts) =>
    ts.map((t) => t.overall).reduce((a, b) => a + b) / ts.length;

/// 스냅샷 → 대시보드 값. 순수 함수(DB·Flutter 무관) — 예외를 던지지 않는다.
TasteProfile computeTasteProfile(TasteSnapshot snap) {
  final tastings = snap.tastings;

  if (tastings.isEmpty) {
    return TasteProfile(
      beanCount: snap.beans.length,
      tastingCount: 0,
      topBeanRating: null,
      intensity: null,
      intensityHighRatedOnly: false,
      byCountry: const [],
      cupNotes: const [],
      byProcess: const [],
      cupNotesHighRatedOnly: false,
    );
  }

  // ① 선호 강도 — ★4+ 우선, 0건이면 전체 시음으로 폴백(배지로 기준을 드러낸다).
  final highRated = tastings.where((t) => t.overall >= 4).toList();
  final intensityHighRatedOnly = highRated.isNotEmpty;
  final intensity =
      _meanIntensity(intensityHighRatedOnly ? highRated : tastings);

  // 원두별 시음 인덱스 — 요약과 ③컵노트가 함께 쓴다.
  final tastingsOf = <int, List<Tasting>>{};
  for (final t in tastings) {
    (tastingsOf[t.beanId] ??= []).add(t);
  }
  final topBeanRating = tastingsOf.values
      .map(_meanOverall)
      .reduce((a, b) => a > b ? a : b);

  return TasteProfile(
    beanCount: snap.beans.length,
    tastingCount: tastings.length,
    topBeanRating: topBeanRating,
    intensity: intensity,
    intensityHighRatedOnly: intensityHighRatedOnly,
    byCountry: const [], // Task 3에서 채운다
    cupNotes: const [], // Task 3에서 채운다
    byProcess: const [], // Task 3에서 채운다
    cupNotesHighRatedOnly: false, // Task 3에서 채운다
  );
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/unit/taste_profile_test.dart`
Expected: PASS (10개 테스트)

- [ ] **Step 6: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: **105개 PASS**

- [ ] **Step 7: 커밋**

```bash
git add lib/features/profile/taste_profile.dart test/helpers.dart test/unit/taste_profile_test.dart
git commit -m "feat(m4): computeTasteProfile 뼈대 — 구성 가중치 + 요약 + 선호 강도 폴백"
```

---

### Task 3: 순수 집계 ② — 원산지·가공방식 가중 평균 + 컵노트 원두 1표 + 정렬

Task 2에서 `const []`로 비워 둔 막대 3종을 채운다. `computeTasteProfile`의 `return` 문만 바뀌고 시그니처는 그대로다.

**Files:**
- Modify: `lib/features/profile/taste_profile.dart`
- Test: `test/unit/taste_profile_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: `componentWeights()`, `Bar`, `TasteProfile`(Task 2).
- Produces: 시그니처 변경 없음. `byCountry`/`byProcess`(값 = 가중 평균★ 0~5) · `cupNotes`(값 = 원두 수) · `cupNotesHighRatedOnly` 가 실제 값으로 채워진다. 정렬은 **값 내림차순, 동점이면 라벨 오름차순**.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/taste_profile_test.dart` 파일 끝(마지막 `}` 앞)에 그룹을 추가:

```dart
  group('②원산지 · ④가공방식 — 가중 평균', () {
    test('싱글 오리진 여러 개는 국가별 산술평균', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Ethiopia'),
          compRow(id: 2, beanId: 2, country: 'Ethiopia'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 3),
        ],
      ));
      expect(p.byCountry.single.label, 'Ethiopia');
      expect(p.byCountry.single.value, 4.0);
    });

    test('블렌드 60/40 비율이 국가별 가중평균에 반영된다', () {
      // 블렌드1(Brazil 60 / Ethiopia 40) ★5, 싱글2(Ethiopia) ★1
      // Ethiopia = (5*0.4 + 1*1.0) / (0.4 + 1.0) = 3.0 / 1.4 ≈ 2.142857
      // Brazil    = (5*0.6) / 0.6 = 5.0
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Brazil', ratioPercent: 60),
          compRow(id: 2, beanId: 1, country: 'Ethiopia', ratioPercent: 40),
          compRow(id: 3, beanId: 2, country: 'Ethiopia'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 1),
        ],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Ethiopia']);
      expect(p.byCountry[0].value, 5.0);
      expect(p.byCountry[1].value, closeTo(3.0 / 1.4, 1e-9));
    });

    test('비율이 하나라도 비면 그 원두는 균등(1/n)으로 계산된다', () {
      // 블렌드(Brazil 60 / Ethiopia null) ★5 → 둘 다 w=0.5 → 각각 평균 5.0
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Brazil', ratioPercent: 60),
          compRow(id: 2, beanId: 1, country: 'Ethiopia'),
        ],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Ethiopia']);
      expect(p.byCountry[0].value, 5.0);
      expect(p.byCountry[1].value, 5.0);
    });

    test('가공방식은 한국어 라벨로 집계된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, process: Process.natural),
          compRow(id: 2, beanId: 2, process: Process.washed),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 3),
        ],
      ));
      expect(p.byProcess.map((b) => b.label), ['내추럴', '워시드']);
      expect(p.byProcess[0].value, 5.0);
      expect(p.byProcess[1].value, 3.0);
    });

    test('동점이면 라벨 오름차순으로 정렬된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Kenya'),
          compRow(id: 2, beanId: 2, country: 'Brazil'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 4),
          tastingRow(id: 2, beanId: 2, overall: 4),
        ],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Kenya']);
    });
  });

  group('③ 선호 컵노트 — 원두 1표', () {
    test('평균★ 4 이상 원두의 태그만 세고 원두당 1표', () {
      // 원두1(평균 4.5, 블루베리·자스민) 시음 2회 / 원두2(평균 2.0, 초콜릿)
      final p = computeTasteProfile(snap(
        beans: [
          beanRow(id: 1, cupNotes: ['블루베리', '자스민']),
          beanRow(id: 2, cupNotes: ['초콜릿']),
        ],
        components: [compRow(id: 1, beanId: 1), compRow(id: 2, beanId: 2)],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 1, overall: 4),
          tastingRow(id: 3, beanId: 2, overall: 2),
        ],
      ));
      expect(p.cupNotesHighRatedOnly, isTrue);
      // 2회 마셨어도 원두 1표 → 각 1. 동점이라 라벨 오름차순(블 < 자).
      expect(p.cupNotes.map((b) => b.label), ['블루베리', '자스민']);
      expect(p.cupNotes.every((b) => b.value == 1.0), isTrue);
    });

    test('한 원두 안의 중복 태그는 1회만 센다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1, cupNotes: ['블루베리', '블루베리'])],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes.single.value, 1.0);
    });

    test('평균★ 4 이상 원두가 없으면 시음이 있는 전체 원두로 폴백', () {
      final p = computeTasteProfile(snap(
        beans: [
          beanRow(id: 1, cupNotes: ['초콜릿']),
          beanRow(id: 2, cupNotes: ['견과']), // 시음 없음 → 폴백 대상 아님
        ],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 2)],
      ));
      expect(p.cupNotesHighRatedOnly, isFalse);
      expect(p.cupNotes.map((b) => b.label), ['초콜릿']);
    });

    test('컵노트가 하나도 없으면 빈 리스트(패널만 빈다)', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1)],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes, isEmpty);
      expect(p.byCountry, isNotEmpty); // 다른 패널은 정상
    });

    test('빈도 동점이면 라벨 오름차순', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1, cupNotes: ['자스민', '감귤'])],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes.map((b) => b.label), ['감귤', '자스민']);
    });
  });
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/unit/taste_profile_test.dart`
Expected: FAIL — 새 그룹의 테스트들이 `Expected: ['Ethiopia'] Actual: []` 형태로 실패(막대가 아직 빈 리스트). Task 2의 기존 10개는 계속 PASS.

- [ ] **Step 3: 가중 평균 누산기 + 정렬 헬퍼 추가**

`lib/features/profile/taste_profile.dart` 의 `_meanOverall` 정의 **아래**, `computeTasteProfile` **위**에 추가. 파일 상단 import에 `import '../../data/enums.dart';` 를 추가한다:

```dart
class _WeightedMean {
  double _sum = 0, _weight = 0;
  void add(double value, double w) {
    _sum += value * w;
    _weight += w;
  }

  double get mean => _sum / _weight;
}

/// 값 내림차순, 동점이면 라벨 오름차순 — 순서를 결정적으로 만들어 테스트 가능하게 한다.
List<Bar> _sorted(Iterable<Bar> bars) {
  final list = bars.toList();
  list.sort((a, b) {
    final byValue = b.value.compareTo(a.value);
    return byValue != 0 ? byValue : a.label.compareTo(b.label);
  });
  return list;
}
```

- [ ] **Step 4: 집계 본문 추가**

`computeTasteProfile` 안, `topBeanRating` 계산 **아래**·`return` **위**에 추가:

```dart
  // 원두별 구성 인덱스.
  final componentsOf = <int, List<OriginComponent>>{};
  for (final c in snap.components) {
    (componentsOf[c.beanId] ??= []).add(c);
  }

  // ②④ — 시음 × 그 원두의 각 구성으로 펼쳐 가중 평균.
  // 가중치는 평균의 분모·분자에 함께 들어가므로, 어떤 키가 항상 낮은 비중으로만
  // 등장해도 평균 자체는 왜곡되지 않는다.
  final countries = <String, _WeightedMean>{};
  final processes = <Process, _WeightedMean>{};
  for (final t in tastings) {
    final comps = componentsOf[t.beanId] ?? const <OriginComponent>[];
    final weights = componentWeights(comps);
    for (var i = 0; i < comps.length; i++) {
      final overall = t.overall.toDouble();
      (countries[comps[i].country] ??= _WeightedMean()).add(overall, weights[i]);
      (processes[comps[i].process] ??= _WeightedMean()).add(overall, weights[i]);
    }
  }

  // ③ 컵노트 — 평균★ ≥ 4 인 원두 1표. 0개면 시음이 있는 전체 원두로 폴백.
  final ratedBeans =
      snap.beans.where((b) => tastingsOf.containsKey(b.id)).toList();
  final lovedBeans = ratedBeans
      .where((b) => _meanOverall(tastingsOf[b.id]!) >= 4)
      .toList();
  final cupNotesHighRatedOnly = lovedBeans.isNotEmpty;
  final noteCounts = <String, int>{};
  for (final b in (cupNotesHighRatedOnly ? lovedBeans : ratedBeans)) {
    for (final note in b.cupNotes.toSet()) {
      // 원두 안 중복 태그는 1회
      noteCounts[note] = (noteCounts[note] ?? 0) + 1;
    }
  }
```

- [ ] **Step 5: `return` 문 교체**

`computeTasteProfile` 의 마지막 `return TasteProfile(...)` 에서 네 줄을 바꾼다.

바꾸기 전:

```dart
    byCountry: const [], // Task 3에서 채운다
    cupNotes: const [], // Task 3에서 채운다
    byProcess: const [], // Task 3에서 채운다
    cupNotesHighRatedOnly: false, // Task 3에서 채운다
```

바꾼 뒤:

```dart
    byCountry: _sorted(
        countries.entries.map((e) => Bar(e.key, e.value.mean))),
    cupNotes: _sorted(
        noteCounts.entries.map((e) => Bar(e.key, e.value.toDouble()))),
    byProcess: _sorted(
        processes.entries.map((e) => Bar(e.key.label, e.value.mean))),
    cupNotesHighRatedOnly: cupNotesHighRatedOnly,
```

> 가공방식은 **`Process` enum으로 집계한 뒤** 마지막에 `label`로 바꾼다. 라벨 문자열로 묶으면 라벨이 겹칠 때 서로 다른 enum이 조용히 합쳐진다.

- [ ] **Step 6: 테스트 통과 확인**

Run: `flutter test test/unit/taste_profile_test.dart`
Expected: PASS (20개 테스트)

- [ ] **Step 7: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: **115개 PASS**

- [ ] **Step 8: 커밋**

```bash
git add lib/features/profile/taste_profile.dart test/unit/taste_profile_test.dart
git commit -m "feat(m4): 원산지·가공 가중평균 + 컵노트 원두 1표 + 결정적 정렬"
```

---

### Task 4: 표시 위젯 3종 — `SummaryRow` · `DashboardPanel` · `BarRow`

화면 조립 없이 순수 표시 위젯만 만든다. 값 계산은 전부 호출부(Task 6) 책임.

**Files:**
- Create: `lib/features/profile/widgets/summary_row.dart`
- Create: `lib/features/profile/widgets/dashboard_panel.dart`
- Create: `lib/features/profile/widgets/bar_row.dart`
- Test: `test/widget/profile_widgets_test.dart` (신규)

**Interfaces:**
- Consumes: `context.colors`(`AppColors`) · `monoStyle(...)` (`lib/theme.dart`).
- Produces:
  - `SummaryRow({required int beanCount, required int tastingCount, required double? topRating})`
  - `DashboardPanel({required String title, String? badge, bool badgeHighlighted = false, required Widget child})`
  - `BarRow({required String label, required double fraction, required String text, bool soft = false})` — `fraction`은 0~1 트랙 채움 비율, `text`는 **이미 포맷된** 오른쪽 수치. 기준값(5.0 고정 / 1위 상대)과 표기(소수 1자리 / 정수)는 호출부가 정한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/widget/profile_widgets_test.dart` 를 새로 만든다:

```dart
import 'package:beanprofile/features/profile/widgets/bar_row.dart';
import 'package:beanprofile/features/profile/widgets/dashboard_panel.dart';
import 'package:beanprofile/features/profile/widgets/summary_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('SummaryRow는 3개 수치와 라벨을 보여준다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: SummaryRow(beanCount: 6, tastingCount: 14, topRating: 4.65),
    )));
    expect(find.text('6'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget); // 소수점 1자리
    expect(find.text('기록한 원두'), findsOneWidget);
    expect(find.text('누적 시음'), findsOneWidget);
    expect(find.text('최고 평점 원두'), findsOneWidget);
  });

  testWidgets('SummaryRow는 topRating이 null이면 —', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: SummaryRow(beanCount: 3, tastingCount: 0, topRating: null),
    )));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('DashboardPanel은 제목과 배지를 보여준다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: DashboardPanel(
          title: '선호 강도', badge: '★4+ 기준', child: Text('내용')),
    )));
    expect(find.text('선호 강도'), findsOneWidget);
    expect(find.text('★4+ 기준'), findsOneWidget);
    expect(find.text('내용'), findsOneWidget);
  });

  testWidgets('DashboardPanel은 배지가 없으면 제목만', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: DashboardPanel(title: '원산지별 평균 평점', child: Text('내용')),
    )));
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    expect(find.byKey(const Key('panel-badge')), findsNothing);
  });

  testWidgets('BarRow는 fraction만큼 트랙을 채운다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: '에티오피아', fraction: 0.92, text: '4.6'),
    )));
    expect(find.text('에티오피아'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 0.92);
  });

  testWidgets('BarRow는 fraction을 0~1로 클램프한다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: '초과', fraction: 1.8, text: '9.0'),
    )));
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 1.0);
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/widget/profile_widgets_test.dart`
Expected: 컴파일 에러 — `Target of URI doesn't exist: '.../widgets/summary_row.dart'`

- [ ] **Step 3: `SummaryRow` 작성**

`lib/features/profile/widgets/summary_row.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 대시보드 상단 요약 3칸.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.beanCount,
    required this.tastingCount,
    required this.topRating,
  });

  final int beanCount, tastingCount;
  final double? topRating;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Stat(value: '$beanCount', label: '기록한 원두'),
          const SizedBox(width: 10),
          _Stat(value: '$tastingCount', label: '누적 시음'),
          const SizedBox(width: 10),
          _Stat(
            value: topRating == null ? '—' : topRating!.toStringAsFixed(1),
            label: '최고 평점 원두',
            muted: topRating == null,
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.muted = false});
  final String value, label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.cup,
          border: Border.all(color: c.appLine),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: monoStyle(
                    size: 22,
                    weight: FontWeight.w800,
                    color: muted ? c.appMuted : c.espresso)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.appMuted)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `DashboardPanel` 작성**

`lib/features/profile/widgets/dashboard_panel.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 대시보드 위젯 하나를 감싸는 카드. `badge`는 계산 기준 표시(예: '★4+ 기준').
/// `badgeHighlighted`가 true면 폴백 중임을 강조한다.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    this.badge,
    this.badgeHighlighted = false,
    required this.child,
  });

  final String title;
  final String? badge;
  final bool badgeHighlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: c.cup,
        border: Border.all(color: c.appLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.espresso)),
              if (badge != null)
                Container(
                  key: const Key('panel-badge'),
                  padding: badgeHighlighted
                      ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: badgeHighlighted
                      ? BoxDecoration(
                          color: const Color(0xFFEAD9BE),
                          border: Border.all(color: c.crema),
                          borderRadius: BorderRadius.circular(7),
                        )
                      : null,
                  child: Text(badge!,
                      style: monoStyle(
                        size: 10,
                        weight:
                            badgeHighlighted ? FontWeight.w700 : FontWeight.w600,
                        color: badgeHighlighted ? c.cremaInk : c.appMuted,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: `BarRow` 작성**

`lib/features/profile/widgets/bar_row.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 막대 한 줄. 라벨 · 트랙(fraction만큼 채움) · 이미 포맷된 수치.
/// 기준값과 표기 규칙은 호출부가 정한다(평점은 5.0 고정·소수 1자리,
/// 빈도는 1위 기준 상대·정수).
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.text,
    this.soft = false,
  });

  final String label;
  final double fraction;
  final String text;

  /// 빈도 막대는 평점 막대와 구분되도록 옅은 그라데이션을 쓴다.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.espresso)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: c.oat,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: soft
                        ? LinearGradient(
                            colors: [c.crema, const Color(0xFFD3A862)])
                        : null,
                    color: soft ? null : c.crema,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 26,
            child: Text(text,
                textAlign: TextAlign.right,
                style: monoStyle(
                    size: 11, weight: FontWeight.w700, color: c.espresso)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `flutter test test/widget/profile_widgets_test.dart`
Expected: PASS (6개 테스트)

- [ ] **Step 7: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: **121개 PASS**

- [ ] **Step 8: 커밋**

```bash
git add lib/features/profile/widgets/ test/widget/profile_widgets_test.dart
git commit -m "feat(m4): 대시보드 표시 위젯 3종(요약·패널·막대)"
```

---

### Task 5: 강도 레이더 — `radarPoint` 순수 함수 + `CustomPainter`

**Files:**
- Create: `lib/features/profile/widgets/intensity_radar.dart`
- Test: `test/unit/intensity_radar_test.dart` (신규)

**Interfaces:**
- Consumes: `Intensity`(Task 2), `context.colors`, `monoStyle(...)`.
- Produces:
  - `Offset radarPoint(int axis, double value, {required Offset center, required double radius})` — `axis` 0=산미(위) 1=단맛(오른쪽) 2=바디(아래) 3=쓴맛(왼쪽), `value` 0~5.
  - `class IntensityRadar extends StatelessWidget { const IntensityRadar({super.key, required Intensity intensity}); }` — 180×164 고정.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/intensity_radar_test.dart` 를 새로 만든다:

```dart
import 'dart:ui';

import 'package:beanprofile/features/profile/widgets/intensity_radar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const center = Offset(90, 80);
  const radius = 58.0;

  test('축 0(산미)은 위쪽 — y가 작아진다', () {
    final p = radarPoint(0, 5, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(22, 1e-6));
  });

  test('축 1(단맛)은 오른쪽', () {
    final p = radarPoint(1, 5, center: center, radius: radius);
    expect(p.dx, closeTo(148, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('축 2(바디)는 아래쪽', () {
    final p = radarPoint(2, 5, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(138, 1e-6));
  });

  test('축 3(쓴맛)은 왼쪽', () {
    final p = radarPoint(3, 5, center: center, radius: radius);
    expect(p.dx, closeTo(32, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('값 0이면 중심', () {
    final p = radarPoint(1, 0, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('값은 반지름에 선형 비례한다', () {
    final p = radarPoint(0, 2.5, center: center, radius: radius);
    expect(p.dy, closeTo(80 - 29, 1e-6)); // 절반
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/unit/intensity_radar_test.dart`
Expected: 컴파일 에러 — `Target of URI doesn't exist: '.../widgets/intensity_radar.dart'`

- [ ] **Step 3: `intensity_radar.dart` 작성**

`lib/features/profile/widgets/intensity_radar.dart` 를 새로 만든다. `listEquals`는 `package:flutter/material.dart`가 이미 re-export하므로 `foundation.dart`를 따로 import하지 않는다(`unnecessary_import` 린트에 걸린다).

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../taste_profile.dart';

const _axisLabels = ['산미', '단맛', '바디', '쓴맛'];
const _maxValue = 5.0;

/// 레이더 축 위의 점. 축 0=산미(위) 1=단맛(오른쪽) 2=바디(아래) 3=쓴맛(왼쪽).
/// 화면 좌표계(y가 아래로 증가)라 위쪽이 `-pi/2`다.
Offset radarPoint(int axis, double value,
        {required Offset center, required double radius}) =>
    center +
    Offset.fromDirection(
        -math.pi / 2 + axis * math.pi / 2, radius * value / _maxValue);

/// 강도 4축 레이더. 크기는 목업과 동일하게 180×164 고정.
class IntensityRadar extends StatelessWidget {
  const IntensityRadar({super.key, required this.intensity});

  final Intensity intensity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SizedBox(
        width: 180,
        height: 164,
        child: CustomPaint(
          painter: _RadarPainter(
            values: [
              intensity.acidity,
              intensity.sweetness,
              intensity.body,
              intensity.bitterness,
            ],
            grid: c.appLine,
            accent: c.crema,
            labelColor: c.appMuted,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.grid,
    required this.accent,
    required this.labelColor,
  });

  final List<double> values;
  final Color grid, accent, labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 축 라벨이 들어갈 여백을 위·아래로 남긴다(목업의 164 높이 기준).
    const center = Offset(90, 80);
    const radius = 58.0;

    Path ring(double value) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final p = radarPoint(i, value, center: center, radius: radius);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (var step = 1; step <= 5; step++) {
      canvas.drawPath(ring(step.toDouble()), gridPaint);
    }
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
          center, radarPoint(i, _maxValue, center: center, radius: radius),
          gridPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < 4; i++) {
      final p = radarPoint(i, values[i], center: center, radius: radius);
      i == 0 ? valuePath.moveTo(p.dx, p.dy) : valuePath.lineTo(p.dx, p.dy);
    }
    valuePath.close();
    canvas.drawPath(valuePath, Paint()..color = accent.withValues(alpha: 0.28));
    canvas.drawPath(
        valuePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent);

    final dot = Paint()..color = accent;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
          radarPoint(i, values[i], center: center, radius: radius), 3.2, dot);
    }

    // 축 라벨 — 위/아래는 가운데 정렬, 좌/우는 바깥쪽 정렬.
    const labelAnchors = [
      Offset(90, 4), // 산미 (위)
      Offset(153, 74), // 단맛 (오른쪽)
      Offset(90, 146), // 바디 (아래)
      Offset(27, 74), // 쓴맛 (왼쪽)
    ];
    for (var i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: _axisLabels[i],
            style: monoStyle(
                size: 10.5, weight: FontWeight.w700, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = labelAnchors[i];
      final dx = switch (i) {
        1 => anchor.dx, // 오른쪽: 왼쪽 정렬
        3 => anchor.dx - tp.width, // 왼쪽: 오른쪽 정렬
        _ => anchor.dx - tp.width / 2, // 위·아래: 가운데
      };
      tp.paint(canvas, Offset(dx, anchor.dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      !listEquals(old.values, values) || old.accent != accent;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/unit/intensity_radar_test.dart`
Expected: PASS (6개 테스트)

- [ ] **Step 5: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!` — 안 쓰는 import가 남아 있으면 여기서 걸린다.

Run: `flutter test`
Expected: **127개 PASS**

- [ ] **Step 6: 커밋**

```bash
git add lib/features/profile/widgets/intensity_radar.dart test/unit/intensity_radar_test.dart
git commit -m "feat(m4): 강도 4축 레이더 — radarPoint 순수 함수 + CustomPainter"
```

---

### Task 6: 화면 조립 — `tasteProfileProvider` + `ProfileScreen`

**Files:**
- Modify: `lib/providers.dart` (파일 끝에 추가)
- Modify: `lib/features/profile/profile_screen.dart` (전체 교체)
- Test: `test/widget/profile_screen_test.dart` (신규)

**Interfaces:**
- Consumes: `watchTasteSnapshot()`(Task 1) · `computeTasteProfile`/`TasteProfile`/`Bar`(Task 2·3) · `SummaryRow`/`DashboardPanel`/`BarRow`(Task 4) · `IntensityRadar`(Task 5) · `beanRepositoryProvider`(기존).
- Produces: `final tasteProfileProvider = StreamProvider<TasteProfile>(...)`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/widget/profile_screen_test.dart` 를 새로 만든다:

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/profile/profile_screen.dart';
import 'package:beanprofile/features/profile/widgets/bar_row.dart';
import 'package:beanprofile/features/profile/widgets/intensity_radar.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  // 패널 4개 + 요약이 기본 800x600 뷰포트를 넘어가면 ListView가 하단 패널을
  // 마운트하지 않는다(M3 ocr_form_test와 같은 이유). 세로로 넉넉히 확장한다.
  void expandViewport(WidgetTester t) {
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
  }

  testWidgets('시음 0건 → 요약은 남기고 빈 상태 안내', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    await testRepository(db).createBean(sampleSingle());

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);        // 기록한 원두
    expect(find.text('—'), findsOneWidget);         // 최고 평점 원두
    expect(find.textContaining('아직 시음 기록이 없어요'), findsOneWidget);
    expect(find.byType(IntensityRadar), findsNothing);
    await db.close();
  });

  testWidgets('시음이 있으면 패널 4개와 막대가 그려진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle()); // Ethiopia, 워시드, 컵노트 2개
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('선호 강도'), findsOneWidget);
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    expect(find.text('선호 컵노트'), findsOneWidget);
    expect(find.text('가공방식별 평점'), findsOneWidget);
    expect(find.byType(IntensityRadar), findsOneWidget);
    expect(find.byType(BarRow), findsNWidgets(4)); // 국가1 + 컵노트2 + 가공1
    await db.close();
  });

  testWidgets('★4+가 있으면 배지는 ★4+ 기준', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('★4+ 기준'), findsOneWidget);
    expect(find.text('★4+ 빈도'), findsOneWidget);
    await db.close();
  });

  testWidgets('★4+가 0건이면 배지가 전체 기준으로 바뀐다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 2));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('전체 기준'), findsOneWidget);
    expect(find.text('전체 빈도'), findsOneWidget);
    expect(find.text('★4+ 기준'), findsNothing);
    await db.close();
  });

  testWidgets('컵노트가 없으면 그 패널만 안내를 띄운다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(const BeanInput(
      name: '무노트', roaster: '', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: [], memo: null,
      components: [ComponentInput(country: 'Kenya')],
    ));
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.textContaining('컵노트가 기록된 원두가 없어요'), findsOneWidget);
    expect(find.text('선호 컵노트'), findsOneWidget); // 패널 자체는 남는다
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/widget/profile_screen_test.dart`
Expected: FAIL — 현재 `ProfileScreen`이 `'취향 분석은 곧 추가됩니다'` 만 그리므로 `find.text('선호 강도')` 등이 `findsNothing`으로 실패.

- [ ] **Step 3: 프로바이더 추가**

`lib/providers.dart` 상단 import에 한 줄을 추가한다:

```dart
import 'features/profile/taste_profile.dart';
```

그리고 파일 **맨 끝**에 추가:

추가할 프로바이더:

```dart
final tasteProfileProvider = StreamProvider<TasteProfile>(
  (ref) => ref
      .watch(beanRepositoryProvider)
      .watchTasteSnapshot()
      .map(computeTasteProfile),
);
```

- [ ] **Step 4: `ProfileScreen` 교체**

`lib/features/profile/profile_screen.dart` 전체를 아래로 교체한다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'taste_profile.dart';
import 'widgets/bar_row.dart';
import 'widgets/dashboard_panel.dart';
import 'widgets/intensity_radar.dart';
import 'widgets/summary_row.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(tasteProfileProvider);
    return Scaffold(
      appBar: AppBar(
          title: const Text('내 취향',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SummaryRow(
              beanCount: p.beanCount,
              tastingCount: p.tastingCount,
              topRating: p.topBeanRating,
            ),
            const SizedBox(height: 14),
            if (p.isEmpty)
              const _EmptyAll()
            else ...[
              DashboardPanel(
                title: '선호 강도',
                badge: p.intensityHighRatedOnly ? '★4+ 기준' : '전체 기준',
                badgeHighlighted: !p.intensityHighRatedOnly,
                child: IntensityRadar(intensity: p.intensity!),
              ),
              DashboardPanel(
                title: '원산지별 평균 평점',
                child: _RatingBars(bars: p.byCountry, empty: '원산지 정보가 없어요'),
              ),
              DashboardPanel(
                title: '선호 컵노트',
                badge: p.cupNotesHighRatedOnly ? '★4+ 빈도' : '전체 빈도',
                badgeHighlighted: !p.cupNotesHighRatedOnly,
                child: _CountBars(bars: p.cupNotes),
              ),
              DashboardPanel(
                title: '가공방식별 평점',
                child: _RatingBars(bars: p.byProcess, empty: '가공방식 정보가 없어요'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 평점 막대 — 트랙 100%는 별점 만점(5.0) 고정, 수치는 소수점 1자리.
class _RatingBars extends StatelessWidget {
  const _RatingBars({required this.bars, required this.empty});
  final List<Bar> bars;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return _PanelEmpty(message: empty);
    return Column(
      children: [
        for (final b in bars)
          BarRow(
            label: b.label,
            fraction: b.value / 5.0,
            text: b.value.toStringAsFixed(1),
          ),
      ],
    );
  }
}

/// 빈도 막대 — 트랙 100%는 1위 값 기준 상대, 수치는 정수.
class _CountBars extends StatelessWidget {
  const _CountBars({required this.bars});
  final List<Bar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const _PanelEmpty(
          message: '컵노트가 기록된 원두가 없어요\n원두를 편집해 컵노트를 추가해 보세요');
    }
    final top = bars.first.value; // 정렬이 값 내림차순이라 첫 항목이 최댓값
    return Column(
      children: [
        for (final b in bars)
          BarRow(
            label: b.label,
            fraction: b.value / top,
            text: b.value.toStringAsFixed(0),
            soft: true,
          ),
      ],
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5, height: 1.55, color: context.colors.appMuted)),
      );
}

class _EmptyAll extends StatelessWidget {
  const _EmptyAll();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: c.cup,
        border: Border.all(color: c.appLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(Icons.coffee_outlined, size: 34, color: c.appLine),
          const SizedBox(height: 10),
          Text('아직 시음 기록이 없어요',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.espresso)),
          const SizedBox(height: 6),
          Text('원두를 열고 시음을 추가하면\n취향 분석이 여기에 나타납니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.7, color: c.appMuted)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/widget/profile_screen_test.dart`
Expected: PASS (5개 테스트)

- [ ] **Step 6: 전체 회귀 + 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: **132개 PASS**

의심스러우면: `flutter test --concurrency=1 -r expanded`

- [ ] **Step 7: 커밋**

```bash
git add lib/providers.dart lib/features/profile/profile_screen.dart test/widget/profile_screen_test.dart
git commit -m "feat(m4): 취향 대시보드 화면 조립 — 폴백 배지·빈 상태 2층위"
```

---

## 마무리 (controller 담당, 태스크 아님)

- opus 전체-브랜치 리뷰(`scripts/review-package BASE HEAD`) → 발견 사항은 **단일 수정 웨이브**로 처리.
- `CLAUDE.md` Status 갱신(M4 DONE, v0.4.0).
- 릴리스 여부·태그는 사용자에게 확인 후 진행.

## 예상 테스트 수 추이

| 시점 | 누적 |
|---|---|
| 시작 | 92 |
| Task 1 | 95 |
| Task 2 | 105 |
| Task 3 | 115 |
| Task 4 | 121 |
| Task 5 | 127 |
| Task 6 | 132 |

> 숫자는 **가이드**다. 실제 개수가 다르면 테스트를 지우지 말고 그대로 두고 보고할 것 — 계획의 추정치가 틀린 것이지 구현이 틀린 게 아니다.
