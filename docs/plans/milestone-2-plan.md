# M2 구현 계획 — 원두 편집/삭제 & 시음 기록

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원두를 편집·삭제하고, 원두마다 시음(강도 4축 + 종합 별점 + 코멘트)을 생성·수정·삭제하며, 상세에서 시음 리스트와 평균 별점을 본다.

**Architecture:** 기존 feature-first 구조 유지. 데이터는 drift 리포지토리에 CRUD 메서드를 더하고, 상세 스트림을 3테이블 watch로 고쳐 시음/구성 쓰기에 반응하게 한다. UI는 추가 폼을 편집 겸용으로 재사용하고, 시음은 신규 `features/tasting/` 폼 + 도트/별점 입력 위젯으로 처리한다.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2 · drift 2.31.0 · flutter_riverpod 3.3.2 · intl 0.20.x

**참조 문서:** 설계 [`milestone-2-design.md`](milestone-2-design.md) · 테스트 규약 [`../testing.md`](../testing.md) · 상위 설계 [`../design.md`](../design.md)

## Global Constraints

모든 태스크에 암묵적으로 적용된다.

- **한국어 UI:** 사용자 노출 문자열은 모두 한국어.
- **오프라인·로컬 전용:** 네트워크 없음, 모든 데이터는 기기 내 drift(SQLite).
- **FK 정의는 `customConstraint`로:** `.references(Table, #id, ...)`는 drift_dev 2.31/analyzer 10.2에서 FK를 조용히 누락시킨다. 새 FK가 필요하면 `customConstraint('... REFERENCES ... ON DELETE CASCADE')`를 쓴다. (M2는 새 테이블/FK 추가 없음 — 기존 스키마 사용.)
- **drift 스트림 provider 테스트:** `container.read(streamProvider.future)` 앞에 반드시 `container.listen(streamProvider, (_, _) {});`를 둔다(무청취 시 스트림이 pause되어 future가 영영 안 풀림).
- **drift 스트림을 watch하는 위젯 테스트:** teardown 전에 `await db.close();`를 명시 호출한다(스트림 마지막 청취 해제 시 drift가 zero-duration Timer를 예약 → `!timersPending` 실패). `addTearDown(db.close)`는 안전망으로 유지(두 번 close는 no-op).
- **Windows 호스트 테스트:** `flutter test`는 호스트에서 돌아 `NativeDatabase.memory()`가 `sqlite3.dll`을 필요로 한다. DLL은 이미 프로젝트 루트에 있음(gitignore). CI(Linux)는 불필요.
- **커밋 규약:** main에 직접 커밋(트렁크 기반). 커밋 전 `flutter analyze && flutter test` **초록불**. 모든 커밋 메시지 끝에 다음 트레일러(빈 줄 뒤):

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

  이후 각 태스크의 커밋 스텝은 제목만 적는다 — 트레일러는 위 규약대로 붙인다.
- **TDD:** 실패 테스트 → 최소 구현 → 통과 → 커밋. 새 테스트는 `test/helpers.dart`를 사용한다.

---

## 파일 구조

**신규**
- `test/helpers.dart` — 공유 테스트 헬퍼(인메모리 DB·repo·container·wrapApp·sample 팩토리). 내용은 testing.md §2에 명세됨.
- `lib/features/tasting/tasting_form_screen.dart` — 시음 생성/편집 폼.
- `lib/features/tasting/widgets/intensity_selector.dart` — 1–5 강도 도트 선택기.
- `lib/features/tasting/widgets/star_input.dart` — 1–5 종합 별점 입력.
- 테스트: `test/data/watch_reactivity_test.dart` · `test/data/tasting_repository_test.dart` · `test/data/bean_edit_repository_test.dart` · `test/widget/tasting_form_test.dart` · `test/widget/bean_detail_actions_test.dart`

**수정**
- `lib/data/models.dart` — `TastingInput` 추가, `BeanDetail`에 `avgRating`/`tastingCount` getter.
- `lib/data/bean_repository.dart` — `createTasting`/`updateTasting`/`deleteTasting`/`updateBean`/`deleteBean` 추가, `watchBeanDetail` 3테이블 반응성 수정.
- `lib/providers.dart` — `beanDetailProvider` → `autoDispose`.
- `lib/features/beans/bean_form_screen.dart` — 편집 모드(`existing`) + 저장 실패 처리.
- `lib/features/beans/bean_detail_screen.dart` — 평균★·편집/삭제 액션·시음 추가·시음 행 탭.

---

## Task 1: 기반 정비 (반응성 · autoDispose · 테스트 헬퍼 · 카스케이드 가드)

**Files:**
- Create: `test/helpers.dart`
- Create: `test/data/watch_reactivity_test.dart`
- Modify: `lib/data/bean_repository.dart:88-92` (`watchBeanDetail`)
- Modify: `lib/providers.dart:19-21` (`beanDetailProvider`)

**Interfaces:**
- Consumes: `AppDatabase.forTesting`, `BeanRepository`, `databaseProvider`, `BeanInput`/`ComponentInput`, `AppTheme.light` (모두 기존).
- Produces:
  - `AppDatabase testDatabase()` · `BeanRepository testRepository(AppDatabase)` · `ProviderContainer testContainer(AppDatabase)` · `Widget wrapApp(Widget, {AppDatabase? db})` · `BeanInput sampleSingle({String name, String country})` · `BeanInput sampleBlend({String name})` — from `test/helpers.dart`.
  - `Stream<BeanDetail?> watchBeanDetail(int beanId)` (변경: beans+tastings+originComponents watch).

- [ ] **Step 1: `test/helpers.dart` 생성** (testing.md §2 명세 그대로)

```dart
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 인메모리 테스트 DB (FK on). 반드시 addTearDown(db.close).
AppDatabase testDatabase() => AppDatabase.forTesting(NativeDatabase.memory());

/// DB를 주입한 저장소.
BeanRepository testRepository(AppDatabase db) => BeanRepository(db);

/// DB를 override한 ProviderContainer. addTearDown(container.dispose).
ProviderContainer testContainer(AppDatabase db) =>
    ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

/// 위젯 테스트용: 테마 + (선택) DB override로 화면을 감싼다.
Widget wrapApp(Widget child, {AppDatabase? db}) => ProviderScope(
      overrides: [if (db != null) databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

/// 샘플 싱글 오리진.
BeanInput sampleSingle({String name = '예가체프 코체레', String country = 'Ethiopia'}) =>
    BeanInput(
      name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null,
      cupNotes: const ['블루베리', '자스민'], memo: null,
      components: [ComponentInput(country: country, process: Process.washed)],
    );

/// 샘플 블렌드 (구성 2개 + 비율).
BeanInput sampleBlend({String name = '하우스 블렌드'}) => BeanInput(
      name: name, roaster: '테라로사', type: BeanType.blend,
      roastLevel: RoastLevel.medium, roastDate: null,
      cupNotes: const ['다크초콜릿'], memo: null,
      components: const [
        ComponentInput(country: 'Brazil', process: Process.natural, ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
      ],
    );
```

- [ ] **Step 2: 실패 테스트 작성** — `test/data/watch_reactivity_test.dart`

`watchBeanDetail` 반응성 테스트는 현재 코드(`beans`만 watch)에서 **실패**해야 한다. 카스케이드 테스트는 스키마 FK를 문서화하는 가드로 즉시 통과한다.

```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/models.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  test('watchBeanDetail re-emits when a tasting is inserted', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    // expectLater가 동기적으로 구독 → 이후 insert가 재방출을 유발해야 함.
    final expectation = expectLater(
      repo.watchBeanDetail(id),
      emitsThrough(
          predicate<BeanDetail?>((d) => d != null && d.tastings.length == 1)),
    );

    await db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: id, date: DateTime(2026, 7, 1),
          acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: 4,
          createdAt: DateTime(2026, 7, 1),
        ));

    await expectation;
  });

  test('deleting a bean cascades to its tastings and components', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleBlend()); // 구성 2개
    await db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: id, date: DateTime(2026, 7, 1),
          acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: 4,
          createdAt: DateTime(2026, 7, 1),
        ));

    await (db.delete(db.beans)..where((b) => b.id.equals(id))).go();

    final tastings =
        await (db.select(db.tastings)..where((t) => t.beanId.equals(id))).get();
    final comps = await (db.select(db.originComponents)
          ..where((c) => c.beanId.equals(id)))
        .get();
    expect(tastings, isEmpty);
    expect(comps, isEmpty);
  });
}
```

- [ ] **Step 3: 반응성 테스트 실패 확인**

Run: `flutter test test/data/watch_reactivity_test.dart`
Expected: `re-emits when a tasting is inserted` **FAIL**(타임아웃 — 재방출 안 됨), `cascades` **PASS**.

- [ ] **Step 4: `watchBeanDetail` 3테이블 watch로 수정** — `lib/data/bean_repository.dart:88-92` 교체

```dart
  Stream<BeanDetail?> watchBeanDetail(int beanId) {
    // beans/tastings/originComponents 어느 것이 바뀌어도 재방출되도록 셋을
    // 조인으로 등록한다(행은 무시, getBeanDetail로 재조회). watchBeanSummaries와
    // 같은 패턴.
    final trigger = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
      leftOuterJoin(db.originComponents,
          db.originComponents.beanId.equalsExp(db.beans.id)),
    ])..where(db.beans.id.equals(beanId));
    return trigger.watch().asyncMap((_) => getBeanDetail(beanId));
  }
```

- [ ] **Step 5: 반응성 테스트 통과 확인**

Run: `flutter test test/data/watch_reactivity_test.dart`
Expected: 두 테스트 모두 **PASS**.

- [ ] **Step 6: `beanDetailProvider` → autoDispose** — `lib/providers.dart:19-21` 교체

```dart
final beanDetailProvider =
    StreamProvider.autoDispose.family<BeanDetail?, int>(
  (ref, beanId) => ref.watch(beanRepositoryProvider).watchBeanDetail(beanId),
);
```

- [ ] **Step 7: 전체 스위트 초록불 확인** (기존 `bean_detail_test.dart`의 `overrideWith`가 autoDispose에서도 컴파일·통과해야 함)

Run: `flutter analyze && flutter test`
Expected: analyze 0 issues, 모든 테스트 PASS. (만약 detail 테스트의 override 시그니처가 깨지면 `beanDetailProvider(7).overrideWith((ref) => Stream.value(detail))` 형태 유지로 조정.)

- [ ] **Step 8: 커밋**

```bash
git add test/helpers.dart test/data/watch_reactivity_test.dart lib/data/bean_repository.dart lib/providers.dart
git commit -m "feat(data): watch tastings/components in detail + autoDispose + test helpers"
```

---

## Task 2: TastingInput 모델 + createTasting

**Files:**
- Modify: `lib/data/models.dart` (`TastingInput` 추가, `BeanDetail` getter)
- Modify: `lib/data/bean_repository.dart` (`createTasting` 추가)
- Modify: `test/helpers.dart` (`sampleTasting` 추가)
- Create: `test/data/tasting_repository_test.dart`

**Interfaces:**
- Consumes: `testDatabase`/`testRepository`/`sampleSingle` (T1), `TastingsCompanion.insert` (drift).
- Produces:
  - `class TastingInput { DateTime date; int acidity, sweetness, body, bitterness, overall; String? comment; }` (const 생성자, `comment` 선택).
  - `int BeanDetail.tastingCount` · `double? BeanDetail.avgRating`.
  - `Future<int> BeanRepository.createTasting(int beanId, TastingInput t)`.
  - `TastingInput sampleTasting({int acidity, sweetness, body, bitterness, overall, String? comment, DateTime? date})`.

- [ ] **Step 1: `TastingInput` + `BeanDetail` getter 추가** — `lib/data/models.dart`

`BeanDetail` 클래스( `models.dart:57-66` )에 getter를 추가하고, 파일 끝에 `TastingInput`을 추가한다.

`BeanDetail`을 다음으로 교체:

```dart
class BeanDetail {
  final Bean bean;
  final List<OriginComponent> components;
  final List<Tasting> tastings;
  const BeanDetail({
    required this.bean,
    required this.components,
    required this.tastings,
  });

  int get tastingCount => tastings.length;
  double? get avgRating => tastings.isEmpty
      ? null
      : tastings.map((t) => t.overall).reduce((a, b) => a + b) / tastings.length;
}
```

파일 끝에 추가:

```dart
class TastingInput {
  final DateTime date;
  final int acidity;
  final int sweetness;
  final int body;
  final int bitterness;
  final int overall;
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

- [ ] **Step 2: `sampleTasting` 헬퍼 추가** — `test/helpers.dart` 끝에 추가

```dart
/// 샘플 시음 (강도 4축 + 종합 + 코멘트).
TastingInput sampleTasting({
  int acidity = 4,
  int sweetness = 3,
  int body = 3,
  int bitterness = 2,
  int overall = 4,
  String? comment = '균형이 좋다',
  DateTime? date,
}) =>
    TastingInput(
      date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall, comment: comment,
    );
```

- [ ] **Step 3: 실패 테스트 작성** — `test/data/tasting_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  test('createTasting persists and getBeanDetail returns it with avg', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    await repo.createTasting(id, sampleTasting(overall: 4));
    await repo.createTasting(id, sampleTasting(overall: 2, comment: null));

    final detail = await repo.getBeanDetail(id);
    expect(detail!.tastings, hasLength(2));
    expect(detail.tastingCount, 2);
    expect(detail.avgRating, 3.0); // (4+2)/2
  });

  test('avgRating is null when there are no tastings', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    final detail = await repo.getBeanDetail(id);
    expect(detail!.avgRating, isNull);
    expect(detail.tastingCount, 0);
  });

  test('watchBeanSummaries reflects avg + count after createTasting', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 5));
    final list = await repo.watchBeanSummaries().first;
    expect(list.first.tastingCount, 1);
    expect(list.first.avgRating, 5.0);
  });
}
```

- [ ] **Step 4: 실패 확인**

Run: `flutter test test/data/tasting_repository_test.dart`
Expected: FAIL — `createTasting` 미정의 컴파일 에러.

- [ ] **Step 5: `createTasting` 구현** — `lib/data/bean_repository.dart`의 `getBeanDetail` 앞(또는 클래스 내 적당한 위치)에 추가

```dart
  Future<int> createTasting(int beanId, TastingInput t) {
    return db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: beanId,
          date: t.date,
          acidity: t.acidity,
          sweetness: t.sweetness,
          body: t.body,
          bitterness: t.bitterness,
          overall: t.overall,
          comment: Value(t.comment),
          createdAt: DateTime.now(),
        ));
  }
```

- [ ] **Step 6: 통과 확인**

Run: `flutter test test/data/tasting_repository_test.dart`
Expected: 3 테스트 PASS.

- [ ] **Step 7: 커밋**

```bash
git add lib/data/models.dart lib/data/bean_repository.dart test/helpers.dart test/data/tasting_repository_test.dart
git commit -m "feat(data): TastingInput + createTasting + BeanDetail avg getters"
```

---

## Task 3: 시음 입력 화면(생성) + 도트/별점 위젯 + 상세 "시음 추가"

**Files:**
- Create: `lib/features/tasting/widgets/intensity_selector.dart`
- Create: `lib/features/tasting/widgets/star_input.dart`
- Create: `lib/features/tasting/tasting_form_screen.dart`
- Modify: `lib/features/beans/bean_detail_screen.dart` (시음 추가 버튼 + 빈 상태 문구)
- Create: `test/widget/tasting_form_test.dart`

**Interfaces:**
- Consumes: `createTasting`/`TastingInput` (T2), `beanRepositoryProvider`, `context.colors`/`monoStyle` (theme), `wrapApp`/`sampleSingle` (helpers).
- Produces:
  - `IntensitySelector({required String label, required int value, required ValueChanged<int> onChanged})` — 도트 키 `Key('intensity-$label-$i')`.
  - `StarInput({required int value, required ValueChanged<int> onChanged, double size})` — 별 키 `Key('star-$i')`.
  - `TastingFormScreen({required int beanId})` — 저장 버튼 키 `Key('save-tasting')`.

- [ ] **Step 1: `IntensitySelector` 위젯** — `lib/features/tasting/widgets/intensity_selector.dart`

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 1–5 강도 도트 선택기. 도트를 탭하면 그 값으로 설정한다.
class IntensitySelector extends StatelessWidget {
  const IntensitySelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: TextStyle(color: c.espresso))),
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            key: Key('intensity-$label-$i'),
            onTap: () => onChanged(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= value ? c.crema : c.oat,
                border: Border.all(color: c.appLine),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text('$value', style: monoStyle(size: 12, color: c.appMuted)),
      ]),
    );
  }
}
```

- [ ] **Step 2: `StarInput` 위젯** — `lib/features/tasting/widgets/star_input.dart`

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 1–5 종합 별점 입력. 별을 탭하면 그 값으로 설정한다.
class StarInput extends StatelessWidget {
  const StarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 32,
  });
  final int value; // 1–5
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crema = context.colors.crema;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          key: Key('star-$i'),
          onPressed: () => onChanged(i),
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(i <= value ? Icons.star : Icons.star_border, color: crema),
        ),
    ]);
  }
}
```

- [ ] **Step 3: `TastingFormScreen`(생성 모드)** — `lib/features/tasting/tasting_form_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'widgets/intensity_selector.dart';
import 'widgets/star_input.dart';

class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen({super.key, required this.beanId});
  final int beanId;
  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormScreenState();
}

class _TastingFormScreenState extends ConsumerState<TastingFormScreen> {
  DateTime _date = DateTime.now();
  int _acidity = 3, _sweetness = 3, _body = 3, _bitterness = 3, _overall = 3;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final input = TastingInput(
      date: _date,
      acidity: _acidity, sweetness: _sweetness, body: _body,
      bitterness: _bitterness, overall: _overall,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );
    try {
      await ref.read(beanRepositoryProvider).createTasting(widget.beanId, input);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('시음 기록')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Row(children: [
          Expanded(
            child: Text('시음일 ${_date.toIso8601String().substring(0, 10)}',
                style: TextStyle(color: c.espresso)),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2100),
                  initialDate: _date);
              if (picked != null) setState(() => _date = picked);
            },
            child: const Text('날짜 선택'),
          ),
        ]),
        const SizedBox(height: 8),
        Text('강도', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        IntensitySelector(label: '산미', value: _acidity, onChanged: (v) => setState(() => _acidity = v)),
        IntensitySelector(label: '단맛', value: _sweetness, onChanged: (v) => setState(() => _sweetness = v)),
        IntensitySelector(label: '바디', value: _body, onChanged: (v) => setState(() => _body = v)),
        IntensitySelector(label: '쓴맛', value: _bitterness, onChanged: (v) => setState(() => _bitterness = v)),
        const SizedBox(height: 14),
        Text('종합 만족도', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        const SizedBox(height: 6),
        StarInput(value: _overall, onChanged: (v) => setState(() => _overall = v)),
        const SizedBox(height: 14),
        TextField(
          controller: _comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '코멘트'),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('save-tasting'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: c.espresso,
                foregroundColor: c.oat,
                minimumSize: const Size.fromHeight(48)),
            child: Text(_saving ? '저장 중…' : '저장'),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 상세에 "시음 추가" 버튼 + 빈 상태 문구 수정** — `lib/features/beans/bean_detail_screen.dart`

상단 import에 추가:

```dart
import '../tasting/tasting_form_screen.dart';
```

`BeanDetailScreen.build`의 `Scaffold`에 `bottomNavigationBar`를 추가한다. `build`를 다음으로 교체(액션은 T5/T6에서 추가; 여기선 body 상단에 `final c`만 필요 없음 — 버튼만 추가):

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beanDetailProvider(beanId));
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('원두 상세')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (d) => d == null
            ? const Center(child: Text('삭제된 원두예요'))
            : _DetailBody(detail: d),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('add-tasting'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TastingFormScreen(beanId: beanId))),
            icon: const Icon(Icons.add),
            label: const Text('시음 추가'),
            style: FilledButton.styleFrom(
                backgroundColor: c.crema,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
    );
  }
```

빈 상태 문구 수정 — `_DetailBody`의 `bean_detail_screen.dart:69` 텍스트를 교체(접두 '아직 시음 기록이 없어요'는 유지 → 기존 detail 테스트 그대로 통과):

```dart
          child: Text('아직 시음 기록이 없어요\n＋ 시음 추가로 첫 기록을 남겨보세요',
              textAlign: TextAlign.center, style: TextStyle(color: c.appMuted)),
```

- [ ] **Step 5: 실패 테스트 작성** — `test/widget/tasting_form_test.dart`

```dart
import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('filling and saving a tasting persists it', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(TastingFormScreen(beanId: beanId), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byType(TextField), '초콜릿, 견과');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.acidity, 5);
    expect(detail.tastings.first.overall, 4);
    expect(detail.tastings.first.comment, '초콜릿, 견과');
  });
}
```

- [ ] **Step 6: 실패 확인**

Run: `flutter test test/widget/tasting_form_test.dart`
Expected: FAIL — `TastingFormScreen` 등 미정의(스텝 1–3 미구현 상태에서 작성했다면). 스텝 1–3을 먼저 구현했다면 이 스텝은 **PASS**로 바로 넘어간다(위젯이 존재하므로). TDD 순서를 지키려면 스텝 5를 스텝 1보다 먼저 작성해도 되지만, 위젯 파일 3개가 상호 의존하므로 여기서는 구현 후 통과를 확인한다.

- [ ] **Step 7: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS(기존 `bean_detail_test.dart`의 '아직 시음 기록이 없어요' 포함).

- [ ] **Step 8: 커밋**

```bash
git add lib/features/tasting/ lib/features/beans/bean_detail_screen.dart test/widget/tasting_form_test.dart
git commit -m "feat(tasting): tasting create form + intensity/star inputs + detail add button"
```

---

## Task 4: 시음 수정/삭제

**Files:**
- Modify: `lib/data/bean_repository.dart` (`updateTasting`/`deleteTasting`)
- Modify: `lib/features/tasting/tasting_form_screen.dart` (편집 모드 + 삭제)
- Modify: `lib/features/beans/bean_detail_screen.dart` (시음 행 탭 → 편집)
- Modify: `test/data/tasting_repository_test.dart` (update/delete 테스트 추가)
- Create: `test/widget/tasting_edit_test.dart`

**Interfaces:**
- Consumes: `createTasting`/`TastingInput` (T2), `Tasting` (drift data class), `deleteTasting`/`updateTasting`.
- Produces:
  - `Future<void> BeanRepository.updateTasting(int tastingId, TastingInput t)` (beanId·createdAt 보존).
  - `Future<void> BeanRepository.deleteTasting(int tastingId)`.
  - `TastingFormScreen({required int beanId, Tasting? existing})` — 편집 모드, 삭제 키 `Key('delete-tasting')`.

- [ ] **Step 1: 실패 테스트 작성** — `test/data/tasting_repository_test.dart`에 추가

```dart
  test('updateTasting changes fields and preserves beanId', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    final tid = await repo.createTasting(id, sampleTasting(overall: 2));

    await repo.updateTasting(tid, sampleTasting(overall: 5, comment: '수정됨'));

    final detail = await repo.getBeanDetail(id);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.overall, 5);
    expect(detail.tastings.first.comment, '수정됨');
    expect(detail.tastings.first.beanId, id);
  });

  test('deleteTasting removes only that tasting', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    final t1 = await repo.createTasting(id, sampleTasting(overall: 3));
    await repo.createTasting(id, sampleTasting(overall: 4));

    await repo.deleteTasting(t1);

    final detail = await repo.getBeanDetail(id);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.overall, 4);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/data/tasting_repository_test.dart`
Expected: FAIL — `updateTasting`/`deleteTasting` 미정의.

- [ ] **Step 3: repo 메서드 구현** — `lib/data/bean_repository.dart`의 `createTasting` 뒤에 추가

```dart
  Future<void> updateTasting(int tastingId, TastingInput t) {
    return (db.update(db.tastings)..where((x) => x.id.equals(tastingId)))
        .write(TastingsCompanion(
      date: Value(t.date),
      acidity: Value(t.acidity),
      sweetness: Value(t.sweetness),
      body: Value(t.body),
      bitterness: Value(t.bitterness),
      overall: Value(t.overall),
      comment: Value(t.comment),
    ));
  }

  Future<void> deleteTasting(int tastingId) {
    return (db.delete(db.tastings)..where((x) => x.id.equals(tastingId))).go();
  }
```

- [ ] **Step 4: repo 테스트 통과 확인**

Run: `flutter test test/data/tasting_repository_test.dart`
Expected: 5 테스트 PASS.

- [ ] **Step 5: 폼 편집 모드 + 삭제** — `lib/features/tasting/tasting_form_screen.dart`

import 추가:

```dart
import '../../data/database.dart';
```

위젯/상태 교체(생성자에 `existing`, `initState` 프리필, `_save` 분기, 삭제 액션):

```dart
class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen({super.key, required this.beanId, this.existing});
  final int beanId;
  final Tasting? existing;
  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormScreenState();
}

class _TastingFormScreenState extends ConsumerState<TastingFormScreen> {
  DateTime _date = DateTime.now();
  int _acidity = 3, _sweetness = 3, _body = 3, _bitterness = 3, _overall = 3;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = e.date;
      _acidity = e.acidity;
      _sweetness = e.sweetness;
      _body = e.body;
      _bitterness = e.bitterness;
      _overall = e.overall;
      _comment.text = e.comment ?? '';
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final input = TastingInput(
      date: _date,
      acidity: _acidity, sweetness: _sweetness, body: _body,
      bitterness: _bitterness, overall: _overall,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );
    try {
      final repo = ref.read(beanRepositoryProvider);
      if (widget.existing == null) {
        await repo.createTasting(widget.beanId, input);
      } else {
        await repo.updateTasting(widget.existing!.id, input);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요')));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('시음 기록 삭제'),
        content: const Text('이 시음 기록을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(beanRepositoryProvider).deleteTasting(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제에 실패했어요')));
      }
    }
  }
```

`build`의 `AppBar`를 다음으로 교체(제목 분기 + 편집 모드 삭제 액션):

```dart
      appBar: AppBar(
        title: Text(widget.existing == null ? '시음 기록' : '시음 편집'),
        actions: [
          if (widget.existing != null)
            IconButton(
              key: const Key('delete-tasting'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
```

(build의 나머지 body/bottomNavigationBar는 Task 3과 동일 — 변경 없음.)

- [ ] **Step 6: 상세 시음 행 탭 → 편집** — `lib/features/beans/bean_detail_screen.dart`의 `_tastingRow`(bean_detail_screen.dart:103) 반환부를 `InkWell`로 감싼다

```dart
  Widget _tastingRow(BuildContext context, Tasting t) {
    final c = context.colors;
    return InkWell(
      key: Key('tasting-row-${t.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TastingFormScreen(beanId: t.beanId, existing: t))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.cup, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.appLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.date.toIso8601String().substring(0, 10), style: monoStyle(size: 11, color: c.appMuted)),
          const SizedBox(height: 4),
          Text('산미 ${t.acidity} · 단맛 ${t.sweetness} · 바디 ${t.body} · 쓴맛 ${t.bitterness} · 종합 ${t.overall}',
              style: monoStyle(size: 11, color: c.espresso)),
          if (t.comment != null && t.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(t.comment!, style: TextStyle(fontSize: 12, color: c.espresso)),
          ],
        ]),
      ),
    );
  }
```

- [ ] **Step 7: 위젯 테스트(편집 프리필 + 갱신)** — `test/widget/tasting_edit_test.dart`

```dart
import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('editing a tasting prefills and updates', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 2, comment: '초안'));
    final tasting = (await repo.getBeanDetail(id))!.tastings.first;

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: id, existing: tasting), db: db));
    await tester.pumpAndSettle();

    expect(find.text('초안'), findsOneWidget); // 프리필된 코멘트
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.tastings.first.overall, 5);
  });
}
```

- [ ] **Step 8: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS.

- [ ] **Step 9: 커밋**

```bash
git add lib/data/bean_repository.dart lib/features/tasting/tasting_form_screen.dart lib/features/beans/bean_detail_screen.dart test/data/tasting_repository_test.dart test/widget/tasting_edit_test.dart
git commit -m "feat(tasting): edit + delete tasting"
```

---

## Task 5: 원두 편집 (폼 재사용 + 구성 전체 교체)

**Files:**
- Modify: `lib/data/bean_repository.dart` (`updateBean`)
- Modify: `lib/features/beans/bean_form_screen.dart` (편집 모드 + 실패 처리 prep-d)
- Modify: `lib/features/beans/bean_detail_screen.dart` (편집 액션)
- Create: `test/data/bean_edit_repository_test.dart`
- Create: `test/widget/bean_edit_test.dart`

**Interfaces:**
- Consumes: `BeanInput`/`ComponentInput`, `BeanDetail` (T2), `updateBean`, `BeansCompanion`/`OriginComponentsCompanion` (drift).
- Produces:
  - `Future<void> BeanRepository.updateBean(int beanId, BeanInput input)` (트랜잭션: beans update + 구성 전체 교체, createdAt 보존).
  - `BeanFormScreen({BeanDetail? existing})` — 편집 모드 프리필 + `updateBean`.

- [ ] **Step 1: 실패 테스트 작성** — `test/data/bean_edit_repository_test.dart`

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  test('updateBean updates fields and replaces components', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleBlend()); // 구성 2개(Brazil, Ethiopia)

    await repo.updateBean(
        id,
        const BeanInput(
          name: '수정된 블렌드', roaster: '새 로스터', type: BeanType.singleOrigin,
          roastLevel: RoastLevel.dark, roastDate: null,
          cupNotes: ['카라멜'], memo: '메모',
          components: [ComponentInput(country: 'Guatemala', process: Process.honey)],
        ));

    final detail = await repo.getBeanDetail(id);
    expect(detail!.bean.name, '수정된 블렌드');
    expect(detail.bean.type, BeanType.singleOrigin);
    expect(detail.bean.cupNotes, ['카라멜']);
    expect(detail.components, hasLength(1));
    expect(detail.components.first.country, 'Guatemala');
    expect(detail.components.first.process, Process.honey);
  });

  test('updateBean preserves createdAt', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    final before = (await repo.getBeanDetail(id))!.bean.createdAt;

    await repo.updateBean(id, sampleSingle(name: '이름만 변경'));

    final after = (await repo.getBeanDetail(id))!.bean.createdAt;
    expect(after, before);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/data/bean_edit_repository_test.dart`
Expected: FAIL — `updateBean` 미정의.

- [ ] **Step 3: `updateBean` 구현** — `lib/data/bean_repository.dart`의 `createBean` 뒤에 추가

```dart
  Future<void> updateBean(int beanId, BeanInput input) {
    return db.transaction(() async {
      await (db.update(db.beans)..where((b) => b.id.equals(beanId))).write(
        BeansCompanion(
          name: Value(input.name),
          roaster: Value(input.roaster),
          type: Value(input.type),
          roastLevel: Value(input.roastLevel),
          roastDate: Value(input.roastDate),
          cupNotes: Value(input.cupNotes),
          memo: Value(input.memo),
        ),
      );
      await (db.delete(db.originComponents)..where((c) => c.beanId.equals(beanId)))
          .go();
      for (final c in input.components) {
        await db.into(db.originComponents).insert(
              OriginComponentsCompanion.insert(
                beanId: beanId,
                country: c.country,
                region: Value(c.region),
                farm: Value(c.farm),
                variety: Value(c.variety),
                process: Value(c.process),
                altitude: Value(c.altitude),
                ratioPercent: Value(c.ratioPercent),
              ),
            );
      }
    });
  }
```

- [ ] **Step 4: repo 테스트 통과 확인**

Run: `flutter test test/data/bean_edit_repository_test.dart`
Expected: 2 테스트 PASS.

- [ ] **Step 5: `BeanFormScreen` 편집 모드 + 실패 처리** — `lib/features/beans/bean_form_screen.dart`

import 추가:

```dart
import '../../data/database.dart';
```

위젯 생성자에 `existing` 추가(bean_form_screen.dart:8-12 교체):

```dart
class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({super.key, this.existing});
  final BeanDetail? existing;
  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}
```

`_BeanFormScreenState`에 `initState` 추가(dispose 앞):

```dart
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.bean.name;
      _roaster.text = e.bean.roaster;
      _cupNotes.text = e.bean.cupNotes.join(', ');
      _memo.text = e.bean.memo ?? '';
      _type = e.bean.type;
      _roast = e.bean.roastLevel;
      _roastDate = e.bean.roastDate;
      for (final c in _components) {
        c.dispose();
      }
      _components
        ..clear()
        ..addAll(e.components.map((comp) {
          final d = _ComponentDraft();
          d.country.text = comp.country;
          d.region.text = comp.region ?? '';
          d.process = comp.process;
          d.ratio.text = comp.ratioPercent?.toString() ?? '';
          return d;
        }));
      if (_components.isEmpty) _components.add(_ComponentDraft());
    }
  }
```

`_save`를 다음으로 교체(생성/편집 분기 + try/catch prep-d):

```dart
  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _components.first.country.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제품명과 첫 원산지 국가는 필수예요')));
      return;
    }
    setState(() => _saving = true);
    final input = BeanInput(
      name: _name.text.trim(),
      roaster: _roaster.text.trim(),
      type: _type,
      roastLevel: _roast,
      roastDate: _roastDate,
      cupNotes: _parseNotes(),
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      components: [
        for (final c in _components)
          if (c.country.text.trim().isNotEmpty)
            ComponentInput(
              country: c.country.text.trim(),
              region: c.region.text.trim().isEmpty ? null : c.region.text.trim(),
              process: c.process,
              ratioPercent: int.tryParse(c.ratio.text.trim()),
            ),
      ],
    );
    try {
      final repo = ref.read(beanRepositoryProvider);
      if (widget.existing == null) {
        await repo.createBean(input);
      } else {
        await repo.updateBean(widget.existing!.bean.id, input);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요')));
      }
    }
  }
```

AppBar 제목 분기(bean_form_screen.dart:80):

```dart
      appBar: AppBar(title: Text(widget.existing == null ? '원두 추가' : '원두 편집')),
```

- [ ] **Step 6: 상세 편집 액션** — `lib/features/beans/bean_detail_screen.dart`

import 추가:

```dart
import 'bean_form_screen.dart';
```

`build`에서 로드된 detail을 AppBar 액션에 쓰도록 교체(T3에서 만든 `bottomNavigationBar`는 유지):

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beanDetailProvider(beanId));
    final detail = async.valueOrNull;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('원두 상세'),
        actions: [
          if (detail != null)
            IconButton(
              key: const Key('edit-bean'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BeanFormScreen(existing: detail))),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (d) => d == null
            ? const Center(child: Text('삭제된 원두예요'))
            : _DetailBody(detail: d),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('add-tasting'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TastingFormScreen(beanId: beanId))),
            icon: const Icon(Icons.add),
            label: const Text('시음 추가'),
            style: FilledButton.styleFrom(
                backgroundColor: c.crema,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 7: 위젯 테스트(편집 프리필 + 갱신)** — `test/widget/bean_edit_test.dart`

```dart
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('editing a bean prefills the form and updates', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle(name: '원본'));
    final detail = await repo.getBeanDetail(id);

    await tester.pumpWidget(wrapApp(BeanFormScreen(existing: detail), db: db));
    await tester.pumpAndSettle();

    expect(find.text('원본'), findsOneWidget); // 프리필된 제품명
    await tester.enterText(find.byKey(const Key('field-name')), '변경됨');
    await tester.tap(find.byKey(const Key('save-bean')));
    await tester.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.bean.name, '변경됨');
  });
}
```

- [ ] **Step 8: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS.

- [ ] **Step 9: 커밋**

```bash
git add lib/data/bean_repository.dart lib/features/beans/bean_form_screen.dart lib/features/beans/bean_detail_screen.dart test/data/bean_edit_repository_test.dart test/widget/bean_edit_test.dart
git commit -m "feat(beans): edit bean + components via form reuse"
```

---

## Task 6: 원두 삭제 (확인 다이얼로그 + 카스케이드)

**Files:**
- Modify: `lib/data/bean_repository.dart` (`deleteBean`)
- Modify: `lib/features/beans/bean_detail_screen.dart` (삭제 액션 + 확인)
- Modify: `test/data/bean_edit_repository_test.dart` (deleteBean 테스트 추가)
- Create: `test/widget/bean_detail_actions_test.dart`

**Interfaces:**
- Consumes: `deleteBean`, `createTasting`/`sampleTasting`, `beanRepositoryProvider`.
- Produces:
  - `Future<void> BeanRepository.deleteBean(int beanId)` (CASCADE로 구성·시음 삭제).
  - 상세 삭제 액션 키 `Key('delete-bean')` + 확인 다이얼로그.

- [ ] **Step 1: 실패 테스트 작성** — `test/data/bean_edit_repository_test.dart`에 추가

```dart
  test('deleteBean removes the bean and cascades tastings + components', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleBlend());
    await repo.createTasting(id, sampleTasting());

    await repo.deleteBean(id);

    expect(await repo.getBeanDetail(id), isNull);
    final list = await repo.watchBeanSummaries().first;
    expect(list, isEmpty);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/data/bean_edit_repository_test.dart`
Expected: FAIL — `deleteBean` 미정의.

- [ ] **Step 3: `deleteBean` 구현** — `lib/data/bean_repository.dart`의 `updateBean` 뒤에 추가

```dart
  Future<void> deleteBean(int beanId) {
    // FK ON DELETE CASCADE로 originComponents + tastings가 함께 삭제된다.
    return (db.delete(db.beans)..where((b) => b.id.equals(beanId))).go();
  }
```

- [ ] **Step 4: repo 테스트 통과 확인**

Run: `flutter test test/data/bean_edit_repository_test.dart`
Expected: 3 테스트 PASS.

- [ ] **Step 5: 상세 삭제 액션 + 확인 다이얼로그** — `lib/features/beans/bean_detail_screen.dart`

Task 5에서 만든 AppBar `actions` 리스트의 `edit-bean` 뒤에 `delete-bean`을 추가:

```dart
          if (detail != null) ...[
            IconButton(
              key: const Key('edit-bean'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BeanFormScreen(existing: detail))),
            ),
            IconButton(
              key: const Key('delete-bean'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDeleteBean(context, ref, detail.bean.id),
            ),
          ],
```

`BeanDetailScreen` 클래스에 메서드 추가(build 아래):

```dart
  Future<void> _confirmDeleteBean(
      BuildContext context, WidgetRef ref, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('원두 삭제'),
        content: const Text('이 원두와 모든 시음 기록이 삭제됩니다. 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(beanRepositoryProvider).deleteBean(id);
    if (context.mounted) Navigator.of(context).pop(); // 리스트로 복귀
  }
```

- [ ] **Step 6: 위젯 테스트(삭제 확인 → DB 반영)** — `test/widget/bean_detail_actions_test.dart`

```dart
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('deleting a bean from detail removes it', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(BeanDetailScreen(beanId: id), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-bean')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제')); // 확인
    await tester.pumpAndSettle();

    expect(await repo.getBeanDetail(id), isNull);

    // 상세가 live drift 스트림을 watch → teardown 전 명시 close(Global Constraints).
    await db.close();
  });
}
```

- [ ] **Step 7: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS.

- [ ] **Step 8: 커밋**

```bash
git add lib/data/bean_repository.dart lib/features/beans/bean_detail_screen.dart test/data/bean_edit_repository_test.dart test/widget/bean_detail_actions_test.dart
git commit -m "feat(beans): delete bean with confirm (cascade)"
```

---

## Task 7: 상세 평균★ + 시음 행 별점

**Files:**
- Modify: `lib/features/beans/bean_detail_screen.dart` (평균★ 헤더 + 행 별점)
- Create: `test/widget/bean_detail_average_test.dart`

**Interfaces:**
- Consumes: `BeanDetail.avgRating`/`tastingCount` (T2), `StarRating` (기존 widget).
- Produces: 상세 상단 평균★ + '시음 N회' 표시, 시음 행에 종합 별점.

- [ ] **Step 1: 실패 테스트 작성** — `test/widget/bean_detail_average_test.dart`

```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail shows average rating and tasting count', (tester) async {
    final bean = Bean(
      id: 7, name: '예가체프 코체레', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null, cupNotes: const [],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));
    Tasting t(int id, int overall) => Tasting(
        id: id, beanId: 7, date: DateTime(2026, 7, id),
        acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: overall,
        comment: null, createdAt: DateTime(2026));
    final detail = BeanDetail(bean: bean, components: const [], tastings: [t(1, 4), t(2, 2)]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(7).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 7)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('시음 2회'), findsOneWidget);
    expect(find.text('3.0'), findsWidgets); // 평균 (4+2)/2 = 3.0, StarRating이 렌더
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/bean_detail_average_test.dart`
Expected: FAIL — '시음 2회'/'3.0' 없음.

- [ ] **Step 3: 평균★ 헤더 추가** — `lib/features/beans/bean_detail_screen.dart`

import 추가:

```dart
import 'widgets/star_rating.dart';
```

`_DetailBody`의 roaster 텍스트(bean_detail_screen.dart:40-41) 바로 뒤에 평균★ 행을 삽입:

```dart
      const SizedBox(height: 8),
      Row(children: [
        StarRating(value: detail.avgRating),
        const SizedBox(width: 10),
        Text('시음 ${detail.tastingCount}회',
            style: TextStyle(color: c.appMuted, fontSize: 12)),
      ]),
```

(`c`는 `_DetailBody.build`에 이미 `final c = context.colors;`로 있음.)

- [ ] **Step 4: 시음 행에 종합 별점** — `_tastingRow`(Task 4에서 InkWell로 감쌈)의 강도 텍스트 줄을 종합만 별점으로 분리

강도 텍스트를 종합 제외로 바꾸고 별점을 오른쪽에 둔다. `_tastingRow`의 `Text('산미 … 종합 …')` 줄을 다음으로 교체:

```dart
          Row(children: [
            Expanded(
              child: Text(
                  '산미 ${t.acidity} · 단맛 ${t.sweetness} · 바디 ${t.body} · 쓴맛 ${t.bitterness}',
                  style: monoStyle(size: 11, color: c.espresso)),
            ),
            StarRating(value: t.overall.toDouble(), size: 12),
          ]),
```

- [ ] **Step 5: 통과 확인 + 전체 회귀**

Run: `flutter analyze && flutter test`
Expected: analyze 0, 모든 테스트 PASS(기존 detail 테스트 포함).

- [ ] **Step 6: 커밋**

```bash
git add lib/features/beans/bean_detail_screen.dart test/widget/bean_detail_average_test.dart
git commit -m "feat(beans): show average rating + per-tasting stars on detail"
```

---

## 완료 기준 (DoD)

- `flutter analyze` 0 issues · `flutter test` 전체 초록불.
- 원두: 추가 → **편집**(구성 포함) → **삭제**(확인 다이얼로그, 시음 카스케이드) 동작.
- 시음: 상세에서 **추가 → 수정 → 삭제**, 리스트/상세 즉시 반영, 상세 상단 **평균★·시음횟수**.
- 태스크별 SDD 리뷰 + 최종 opus 전체브랜치 리뷰 통과(M1과 동일).
- (선택) `v0.2.0` 태그로 실기기 검증 후 로드맵/CLAUDE.md 상태 갱신.
