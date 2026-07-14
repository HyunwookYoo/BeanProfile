# M1 — 기반 & 원두 추가/조회 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter 앱 골격 위에서 원두를 **수동으로 추가 → 리스트로 조회 → 상세(읽기)** 까지 되는, 로컬 저장 기반의 동작하는 첫 증분을 만든다.

**Architecture:** feature-first 폴더 구조. 데이터는 drift(SQLite) 3테이블(Beans/OriginComponents/Tastings)에 저장하고 `BeanRepository`가 CRUD를 캡슐화한다. UI는 Riverpod provider로 DB 스트림을 구독한다. M1은 시음/OCR/대시보드/편집·삭제를 제외한 **추가·리스트·상세(읽기)** 만 다룬다.

**Tech Stack:** Flutter(stable, Dart 3) · drift + drift_flutter(SQLite) · flutter_riverpod · intl · (dev) drift_dev, build_runner.

> 코드는 검증된 참고 구현이다. 패키지 최신 API에 맞춰 사소한 조정이 필요할 수 있다. 각 코드 스텝은 그대로 실행 가능한 것을 목표로 한다.

## Global Constraints

- Flutter stable / Dart 3, null-safety. 상태관리는 flutter_riverpod, DB는 drift.
- **오프라인·로컬 전용:** 네트워크 사용 안 함. DB 파일명 `beanprofile`.
- **한국어:** 모든 사용자 노출 문자열은 한국어.
- **디자인 토큰(목업 확정값):** oat `#ECE6DB` · cup `#FCFBF8` · espresso `#2B2019` · crema `#B67B2E` · cremaInk `#8A5A18` · appMuted `#8C8172` · appLine `#E4DED2` · cherry `#9E3B2D`. 데이터(날짜·고도·비율·평점)는 모노스페이스.
- **데이터 모델:** `Bean 1—N OriginComponent`(싱글=1, 블렌드=N), `Bean 1—N Tasting`. 평가 강도 4축 1~5 + overall 1~5 + comment.
- **평가/시음 UI는 M2**, OCR은 M3. M1의 원두 추가는 **수동 입력**이다.

---

## 테스트 전략

자동화 테스트로 **기능 추가 시 빠른 회귀 확인**을 보장한다. 상세 규약·공유 헬퍼 전체 코드·CI·Windows sqlite3 셋업은 [`../testing.md`](../testing.md) 참조.

- **3계층:** 유닛/데이터(인메모리 drift DB) · 위젯/UI(Riverpod override) · 스모크.
- **공유 헬퍼** `test/helpers.dart`: `testDatabase()` · `testRepository(db)` · `testContainer(db)` · `wrapApp(widget, db:)` · `sampleSingle()/sampleBlend()`. 아래 태스크의 반복 셋업을 이 헬퍼로 대체할 수 있고, M2부터는 기본 사용한다.
- **Windows sqlite3:** 호스트 `flutter test`엔 `sqlite3.dll`이 필요 — testing.md의 셋업을 따른다. (Linux/CI는 불필요.)
- **CI:** `.github/workflows/test.yml`(Linux)이 push마다 `flutter analyze` + `flutter test` 자동 실행.
- **커밋 전:** `flutter analyze && flutter test` 초록불.

---

## File Structure

```
lib/
  main.dart                       # ProviderScope + BeanProfileApp
  app.dart                        # MaterialApp, HomeShell(3탭)
  theme.dart                      # AppTheme.light, AppColors(ThemeExtension), monoStyle
  providers.dart                  # databaseProvider, beanRepositoryProvider, beanListProvider, beanDetailProvider
  data/
    enums.dart                    # BeanType, RoastLevel, Process + 한글 label
    converters.dart               # StringListConverter (컵노트 List<String> ↔ JSON)
    tables.dart                   # Beans, OriginComponents, Tastings
    database.dart (+ .g.dart)     # AppDatabase
    models.dart                   # BeanSummary, BeanDetail (뷰 모델)
    bean_repository.dart          # createBean / watchBeanSummaries / watchBeanDetail
  features/
    beans/
      bean_list_screen.dart
      bean_form_screen.dart       # 원두 추가(수동)
      bean_detail_screen.dart     # 읽기 전용
      widgets/
        bean_card.dart
        star_rating.dart
    profile/profile_screen.dart   # M1 자리표시(취향 탭)
    settings/settings_screen.dart # M1 자리표시(설정 탭)
test/
  helpers.dart                  # 공유 헬퍼 (testDatabase/wrapApp/sample*) — testing.md
  data/converters_test.dart
  data/database_test.dart
  data/bean_repository_test.dart
  providers_test.dart
  widget/app_shell_test.dart
  widget/bean_list_test.dart
  widget/bean_form_test.dart
  widget/bean_detail_test.dart
.github/workflows/test.yml        # CI: analyze + test (Linux)
```

---

### Task 1: 프로젝트 스캐폴드 & 의존성

**Files:**
- Create: 프로젝트 전체(`flutter create`), `pubspec.yaml`(수정), `lib/main.dart`(교체)
- Test: `test/smoke_test.dart`
- Delete: `test/widget_test.dart`(기본 생성물)

- [ ] **Step 1: Flutter 프로젝트 생성** (이미 `C:\BeanProfile`에 `docs/`, `CLAUDE.md` 존재 — 비어있지 않은 폴더에 생성)

Run:
```bash
flutter create --org com.beanprofile --project-name beanprofile --platforms=android,ios .
```

- [ ] **Step 2: 의존성 추가**

Run:
```bash
flutter pub add drift drift_flutter flutter_riverpod intl
dart pub add --dev drift_dev build_runner
```

- [ ] **Step 3: 폴더 생성**

Run:
```bash
mkdir -p lib/data lib/features/beans/widgets lib/features/profile lib/features/settings test/data test/widget
```

- [ ] **Step 4: `lib/main.dart` 최소 앱으로 교체**

```dart
import 'package:flutter/material.dart';

void main() => runApp(const _Boot());

class _Boot extends StatelessWidget {
  const _Boot();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('BeanProfile'))),
      );
}
```

- [ ] **Step 5: 기본 위젯 테스트 삭제 후 스모크 테스트 작성**

Run: `rm test/widget_test.dart`

`test/smoke_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots and shows app name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('BeanProfile'))),
    ));
    expect(find.text('BeanProfile'), findsOneWidget);
  });
}
```

- [ ] **Step 6: 분석 & 테스트 통과 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 0 issues, 1 test PASS.

- [ ] **Step 7: 커밋**

```bash
git init
git add -A
git commit -m "chore: scaffold Flutter project and dependencies"
```

---

### Task 2: 열거형 & 컵노트 컨버터

**Files:**
- Create: `lib/data/enums.dart`, `lib/data/converters.dart`
- Test: `test/data/converters_test.dart`

**Interfaces:**
- Produces: `enum BeanType { singleOrigin, blend }`, `enum RoastLevel { light, lightMedium, medium, mediumDark, dark }`, `enum Process { washed, natural, honey, anaerobic, other }`, 각 `.label` (String) 확장. `class StringListConverter extends TypeConverter<List<String>, String>`.

- [ ] **Step 1: 실패 테스트 작성**

`test/data/converters_test.dart`:
```dart
import 'package:beanprofile/data/converters.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conv = StringListConverter();

  test('round-trips a list of strings', () {
    const notes = ['블루베리', '자스민', '홍차'];
    final sql = conv.toSql(notes);
    expect(conv.fromSql(sql), notes);
  });

  test('empty list round-trips', () {
    expect(conv.fromSql(conv.toSql(const [])), isEmpty);
  });

  test('enum labels are Korean', () {
    expect(BeanType.blend.label, '블렌드');
    expect(Process.natural.label, '내추럴');
    expect(RoastLevel.mediumDark.label, '미디엄다크');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/converters_test.dart`
Expected: FAIL — `enums.dart`/`converters.dart` 없음(컴파일 에러).

- [ ] **Step 3: enums 구현**

`lib/data/enums.dart`:
```dart
enum BeanType { singleOrigin, blend }

enum RoastLevel { light, lightMedium, medium, mediumDark, dark }

enum Process { washed, natural, honey, anaerobic, other }

extension BeanTypeLabel on BeanType {
  String get label => switch (this) {
        BeanType.singleOrigin => '싱글 오리진',
        BeanType.blend => '블렌드',
      };
}

extension RoastLevelLabel on RoastLevel {
  String get label => switch (this) {
        RoastLevel.light => '라이트',
        RoastLevel.lightMedium => '라이트미디엄',
        RoastLevel.medium => '미디엄',
        RoastLevel.mediumDark => '미디엄다크',
        RoastLevel.dark => '다크',
      };
}

extension ProcessLabel on Process {
  String get label => switch (this) {
        Process.washed => '워시드',
        Process.natural => '내추럴',
        Process.honey => '허니',
        Process.anaerobic => '무산소',
        Process.other => '기타',
      };
}
```

- [ ] **Step 4: converter 구현**

`lib/data/converters.dart`:
```dart
import 'dart:convert';
import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (json.decode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => json.encode(value);
}
```

- [ ] **Step 5: 테스트 통과 & 커밋**

Run: `flutter test test/data/converters_test.dart` → PASS
```bash
git add -A && git commit -m "feat(data): add enums and cup-notes converter"
```

---

### Task 3: drift 테이블 & 데이터베이스

**Files:**
- Create: `lib/data/tables.dart`, `lib/data/database.dart`
- Generated: `lib/data/database.g.dart` (build_runner)
- Test: `test/data/database_test.dart`

**Interfaces:**
- Produces: `class AppDatabase`(`.forTesting(QueryExecutor)` 생성자 포함), drift 생성 행 클래스 `Bean`, `OriginComponent`, `Tasting` 및 companion `BeansCompanion`, `OriginComponentsCompanion`, `TastingsCompanion`, 테이블 접근자 `db.beans`, `db.originComponents`, `db.tastings`. FK는 `PRAGMA foreign_keys = ON`으로 cascade 삭제.

- [ ] **Step 1: 실패 테스트 작성**

`test/data/database_test.dart`:
```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('inserts and reads back a bean with cup notes', () async {
    final id = await db.into(db.beans).insert(BeansCompanion.insert(
          name: '예가체프 코체레',
          type: BeanType.singleOrigin,
          cupNotes: const Value(['블루베리', '자스민']),
          createdAt: DateTime(2026, 7, 14),
        ));
    final bean = await (db.select(db.beans)..where((b) => b.id.equals(id)))
        .getSingle();
    expect(bean.name, '예가체프 코체레');
    expect(bean.type, BeanType.singleOrigin);
    expect(bean.cupNotes, ['블루베리', '자스민']);
  });

  test('deleting a bean cascades to its components', () async {
    final beanId = await db.into(db.beans).insert(BeansCompanion.insert(
          name: '테스트', type: BeanType.blend, createdAt: DateTime(2026)));
    await db.into(db.originComponents).insert(
        OriginComponentsCompanion.insert(beanId: beanId, country: 'Ethiopia'));

    await (db.delete(db.beans)..where((b) => b.id.equals(beanId))).go();

    final comps = await db.select(db.originComponents).get();
    expect(comps, isEmpty);
  });
}
```

- [ ] **Step 2: 테이블 정의**

`lib/data/tables.dart`:
```dart
import 'package:drift/drift.dart';
import 'converters.dart';
import 'enums.dart';

class Beans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get roaster => text().withDefault(const Constant(''))();
  IntColumn get type => intEnum<BeanType>()();
  IntColumn get roastLevel => intEnum<RoastLevel>().nullable()();
  DateTimeColumn get roastDate => dateTime().nullable()();
  TextColumn get cupNotes =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get photoPath => text().nullable()();
  RealColumn get scaScore => real().nullable()();
  IntColumn get weightGrams => integer().nullable()();
  IntColumn get price => integer().nullable()();
  TextColumn get shop => text().nullable()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class OriginComponents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get beanId =>
      integer().references(Beans, #id, onDelete: KeyAction.cascade)();
  TextColumn get country => text()();
  TextColumn get region => text().nullable()();
  TextColumn get farm => text().nullable()();
  TextColumn get variety => text().nullable()();
  IntColumn get process => intEnum<Process>().withDefault(const Constant(0))();
  TextColumn get altitude => text().nullable()();
  IntColumn get ratioPercent => integer().nullable()();
}

class Tastings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get beanId =>
      integer().references(Beans, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get acidity => integer()();
  IntColumn get sweetness => integer()();
  IntColumn get body => integer()();
  IntColumn get bitterness => integer()();
  IntColumn get overall => integer()();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
```

- [ ] **Step 3: 데이터베이스 정의**

`lib/data/database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Beans, OriginComponents, Tastings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'beanprofile'));
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
```

- [ ] **Step 4: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/database.g.dart` 생성, 에러 없음.

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/data/database_test.dart`
Expected: 2 tests PASS.
> Windows에서 `NativeDatabase.memory()` 실행 시 sqlite3 네이티브 라이브러리가 필요하다. 에러가 나면 dev 의존성 `sqlite3_flutter_libs`가 앱에 포함돼 있는지 확인하고, 호스트 테스트용으로 `sqlite3` DLL이 PATH에 있어야 한다.

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(data): add drift schema and database"
```

---

### Task 4: 뷰 모델 & 저장소(생성·조회)

**Files:**
- Create: `lib/data/models.dart`, `lib/data/bean_repository.dart`
- Test: `test/data/bean_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(Task 3).
- Produces:
  - `class BeanInput { String name; String roaster; BeanType type; RoastLevel? roastLevel; DateTime? roastDate; List<String> cupNotes; String? memo; List<ComponentInput> components; }`
  - `class ComponentInput { String country; String? region; String? farm; String? variety; Process process; String? altitude; int? ratioPercent; }`
  - `class BeanSummary { Bean bean; String? originLabel; double? avgRating; int tastingCount; }`
  - `class BeanDetail { Bean bean; List<OriginComponent> components; List<Tasting> tastings; }`
  - `class BeanRepository { Future<int> createBean(BeanInput); Stream<List<BeanSummary>> watchBeanSummaries(); Stream<BeanDetail?> watchBeanDetail(int id); Future<BeanDetail?> getBeanDetail(int id); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/data/bean_repository_test.dart`:
```dart
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BeanRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BeanRepository(db);
  });
  tearDown(() => db.close());

  BeanInput sampleSingle() => const BeanInput(
        name: '예가체프 코체레',
        roaster: '프릳츠',
        type: BeanType.singleOrigin,
        roastLevel: RoastLevel.lightMedium,
        roastDate: null,
        cupNotes: ['블루베리', '자스민'],
        memo: null,
        components: [ComponentInput(country: 'Ethiopia', process: Process.washed)],
      );

  test('createBean persists bean + components and detail reads them', () async {
    final id = await repo.createBean(sampleSingle());
    final detail = await repo.getBeanDetail(id);
    expect(detail, isNotNull);
    expect(detail!.bean.name, '예가체프 코체레');
    expect(detail.components, hasLength(1));
    expect(detail.components.first.country, 'Ethiopia');
    expect(detail.tastings, isEmpty);
  });

  test('summary shows null rating and 0 count when no tastings', () async {
    await repo.createBean(sampleSingle());
    final list = await repo.watchBeanSummaries().first;
    expect(list, hasLength(1));
    expect(list.first.avgRating, isNull);
    expect(list.first.tastingCount, 0);
    expect(list.first.originLabel, 'Ethiopia');
  });

  test('blend originLabel shows "외 N"', () async {
    await repo.createBean(const BeanInput(
      name: '하우스 블렌드', roaster: '테라로사', type: BeanType.blend,
      roastLevel: null, roastDate: null, cupNotes: [], memo: null,
      components: [
        ComponentInput(country: 'Brazil', ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', ratioPercent: 40),
      ],
    ));
    final list = await repo.watchBeanSummaries().first;
    expect(list.first.originLabel, 'Brazil 외 1');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/bean_repository_test.dart`
Expected: FAIL — `models.dart`/`bean_repository.dart` 없음.

- [ ] **Step 3: 뷰 모델 구현**

`lib/data/models.dart`:
```dart
import 'database.dart';

class ComponentInput {
  final String country;
  final String? region;
  final String? farm;
  final String? variety;
  final Object process; // Process — Object로 두면 순환 import 방지 불필요; 아래 주석 참고
  final String? altitude;
  final int? ratioPercent;
  const ComponentInput({
    required this.country,
    this.region,
    this.farm,
    this.variety,
    required this.process,
    this.altitude,
    this.ratioPercent,
  });
}

class BeanInput {
  final String name;
  final String roaster;
  final Object type; // BeanType
  final Object? roastLevel; // RoastLevel?
  final DateTime? roastDate;
  final List<String> cupNotes;
  final String? memo;
  final List<ComponentInput> components;
  const BeanInput({
    required this.name,
    required this.roaster,
    required this.type,
    required this.roastLevel,
    required this.roastDate,
    required this.cupNotes,
    required this.memo,
    required this.components,
  });
}

class BeanSummary {
  final Bean bean;
  final String? originLabel;
  final double? avgRating;
  final int tastingCount;
  const BeanSummary({
    required this.bean,
    required this.originLabel,
    required this.avgRating,
    required this.tastingCount,
  });
}

class BeanDetail {
  final Bean bean;
  final List<OriginComponent> components;
  final List<Tasting> tastings;
  const BeanDetail({
    required this.bean,
    required this.components,
    required this.tastings,
  });
}
```
> 참고: `ComponentInput.process`/`BeanInput.type`을 `Object`로 둔 것은 예시 단순화용이 아니라 **명시적으로 enum 타입을 쓰도록** 아래처럼 교체한다 — `models.dart` 상단에 `import 'enums.dart';` 추가하고 `Object process` → `Process process`, `Object type` → `BeanType type`, `Object? roastLevel` → `RoastLevel? roastLevel`로 바꾼다. (enum과 모델이 같은 `data/`에 있어 순환 import 문제 없음.)

- [ ] **Step 4: 저장소 구현**

`lib/data/bean_repository.dart`:
```dart
import 'package:drift/drift.dart';
import 'database.dart';
import 'enums.dart';
import 'models.dart';

class BeanRepository {
  BeanRepository(this.db);
  final AppDatabase db;

  Future<int> createBean(BeanInput input) {
    return db.transaction(() async {
      final beanId = await db.into(db.beans).insert(BeansCompanion.insert(
            name: input.name,
            roaster: Value(input.roaster),
            type: input.type as BeanType,
            roastLevel: Value(input.roastLevel as RoastLevel?),
            roastDate: Value(input.roastDate),
            cupNotes: Value(input.cupNotes),
            memo: Value(input.memo),
            createdAt: DateTime.now(),
          ));
      for (final c in input.components) {
        await db.into(db.originComponents).insert(
              OriginComponentsCompanion.insert(
                beanId: beanId,
                country: c.country,
                region: Value(c.region),
                farm: Value(c.farm),
                variety: Value(c.variety),
                process: Value(c.process as Process),
                altitude: Value(c.altitude),
                ratioPercent: Value(c.ratioPercent),
              ),
            );
      }
      return beanId;
    });
  }

  Stream<List<BeanSummary>> watchBeanSummaries() {
    final avg = db.tastings.overall.avg();
    final cnt = db.tastings.id.count();
    final query = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
    ])
      ..addColumns([avg, cnt])
      ..groupBy([db.beans.id])
      ..orderBy([OrderingTerm.desc(db.beans.createdAt)]);

    return query.watch().asyncMap((rows) async {
      final result = <BeanSummary>[];
      for (final row in rows) {
        final bean = row.readTable(db.beans);
        final comps = await (db.select(db.originComponents)
              ..where((c) => c.beanId.equals(bean.id)))
            .get();
        result.add(BeanSummary(
          bean: bean,
          originLabel: _originLabel(comps),
          avgRating: row.read(avg),
          tastingCount: row.read(cnt) ?? 0,
        ));
      }
      return result;
    });
  }

  String? _originLabel(List<OriginComponent> comps) {
    if (comps.isEmpty) return null;
    final first = comps.first.country;
    return comps.length == 1 ? first : '$first 외 ${comps.length - 1}';
  }

  Future<BeanDetail?> getBeanDetail(int beanId) async {
    final bean = await (db.select(db.beans)..where((b) => b.id.equals(beanId)))
        .getSingleOrNull();
    if (bean == null) return null;
    final comps = await (db.select(db.originComponents)
          ..where((c) => c.beanId.equals(beanId)))
        .get();
    final tastings = await (db.select(db.tastings)
          ..where((t) => t.beanId.equals(beanId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return BeanDetail(bean: bean, components: comps, tastings: tastings);
  }

  Stream<BeanDetail?> watchBeanDetail(int beanId) {
    return (db.select(db.beans)..where((b) => b.id.equals(beanId)))
        .watchSingleOrNull()
        .asyncMap((_) => getBeanDetail(beanId));
  }
}
```

- [ ] **Step 5: 테스트 통과 & 커밋**

Run: `flutter test test/data/bean_repository_test.dart` → 3 PASS
```bash
git add -A && git commit -m "feat(data): bean repository create/read + view models"
```

---

### Task 5: Riverpod providers

**Files:**
- Create: `lib/providers.dart`
- Test: `test/providers_test.dart`

**Interfaces:**
- Produces: `databaseProvider` (`Provider<AppDatabase>`), `beanRepositoryProvider` (`Provider<BeanRepository>`), `beanListProvider` (`StreamProvider<List<BeanSummary>>`), `beanDetailProvider` (`StreamProvider.family<BeanDetail?, int>`).
- 테스트/위젯에서 `databaseProvider.overrideWithValue(AppDatabase.forTesting(...))`로 대체.

- [ ] **Step 1: 실패 테스트 작성**

`test/providers_test.dart`:
```dart
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beanListProvider emits inserted beans', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(beanRepositoryProvider).createBean(const BeanInput(
          name: '케냐 니에리 AA', roaster: '리브레', type: BeanType.singleOrigin,
          roastLevel: null, roastDate: null, cupNotes: [], memo: null,
          components: [ComponentInput(country: 'Kenya', process: Process.washed)],
        ));

    final list = await container.read(beanListProvider.future);
    expect(list, hasLength(1));
    expect(list.first.bean.name, '케냐 니에리 AA');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/providers_test.dart` → FAIL(`providers.dart` 없음)

- [ ] **Step 3: providers 구현**

`lib/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/bean_repository.dart';
import 'data/database.dart';
import 'data/models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final beanRepositoryProvider = Provider<BeanRepository>(
  (ref) => BeanRepository(ref.watch(databaseProvider)),
);

final beanListProvider = StreamProvider<List<BeanSummary>>(
  (ref) => ref.watch(beanRepositoryProvider).watchBeanSummaries(),
);

final beanDetailProvider = StreamProvider.family<BeanDetail?, int>(
  (ref, beanId) => ref.watch(beanRepositoryProvider).watchBeanDetail(beanId),
);
```

- [ ] **Step 4: 통과 & 커밋**

Run: `flutter test test/providers_test.dart` → PASS
```bash
git add -A && git commit -m "feat: riverpod providers for db and bean lists"
```

---

### Task 6: 테마 & 앱 셸(3탭)

**Files:**
- Create: `lib/theme.dart`, `lib/app.dart`, `lib/features/profile/profile_screen.dart`, `lib/features/settings/settings_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/widget/app_shell_test.dart`

**Interfaces:**
- Produces: `AppTheme.light` (`ThemeData`), `AppColors` (`ThemeExtension<AppColors>` — `oat/cup/espresso/crema/cremaInk/appMuted/appLine/cherry`), `monoStyle(...)` 헬퍼, `BeanProfileApp` (루트), `HomeShell` (하단 3탭). `context.colors` 확장으로 토큰 접근.

- [ ] **Step 1: 실패 위젯 테스트 작성**

`test/widget/app_shell_test.dart`:
```dart
import 'package:beanprofile/app.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows 3 tabs and switches to 취향', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const BeanProfileApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('원두'), findsWidgets);
    expect(find.text('취향'), findsWidgets);
    expect(find.text('설정'), findsWidgets);

    await tester.tap(find.text('취향'));
    await tester.pumpAndSettle();
    expect(find.text('취향 분석은 곧 추가됩니다'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/app_shell_test.dart` → FAIL

- [ ] **Step 3: 테마 구현**

`lib/theme.dart`:
```dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color oat, cup, espresso, crema, cremaInk, appMuted, appLine, cherry;
  const AppColors({
    required this.oat,
    required this.cup,
    required this.espresso,
    required this.crema,
    required this.cremaInk,
    required this.appMuted,
    required this.appLine,
    required this.cherry,
  });

  static const light = AppColors(
    oat: Color(0xFFECE6DB),
    cup: Color(0xFFFCFBF8),
    espresso: Color(0xFF2B2019),
    crema: Color(0xFFB67B2E),
    cremaInk: Color(0xFF8A5A18),
    appMuted: Color(0xFF8C8172),
    appLine: Color(0xFFE4DED2),
    cherry: Color(0xFF9E3B2D),
  );

  @override
  AppColors copyWith({Color? oat, Color? cup, Color? espresso, Color? crema,
      Color? cremaInk, Color? appMuted, Color? appLine, Color? cherry}) =>
      AppColors(
        oat: oat ?? this.oat, cup: cup ?? this.cup,
        espresso: espresso ?? this.espresso, crema: crema ?? this.crema,
        cremaInk: cremaInk ?? this.cremaInk, appMuted: appMuted ?? this.appMuted,
        appLine: appLine ?? this.appLine, cherry: cherry ?? this.cherry,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      oat: Color.lerp(oat, other.oat, t)!,
      cup: Color.lerp(cup, other.cup, t)!,
      espresso: Color.lerp(espresso, other.espresso, t)!,
      crema: Color.lerp(crema, other.crema, t)!,
      cremaInk: Color.lerp(cremaInk, other.cremaInk, t)!,
      appMuted: Color.lerp(appMuted, other.appMuted, t)!,
      appLine: Color.lerp(appLine, other.appLine, t)!,
      cherry: Color.lerp(cherry, other.cherry, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

TextStyle monoStyle({double size = 12, FontWeight weight = FontWeight.w600, Color? color}) =>
    TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'Consolas'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class AppTheme {
  static ThemeData get light {
    const c = AppColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.crema,
      brightness: Brightness.light,
    ).copyWith(surface: c.cup, primary: c.crema);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.oat,
      extensions: const [c],
      appBarTheme: const AppBarTheme(
        backgroundColor: c.oat,
        foregroundColor: c.espresso,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
```

- [ ] **Step 4: 자리표시 탭 화면**

`lib/features/profile/profile_screen.dart`:
```dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('취향 분석은 곧 추가됩니다')),
      );
}
```

`lib/features/settings/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('설정은 곧 추가됩니다')),
      );
}
```

- [ ] **Step 5: 앱 & 셸**

`lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'features/beans/bean_list_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme.dart';

class BeanProfileApp extends StatelessWidget {
  const BeanProfileApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BeanProfile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _tabs = [BeanListScreen(), ProfileScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.coffee_outlined), selectedIcon: Icon(Icons.coffee), label: '원두'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '취향'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
```

`lib/main.dart` (교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() => runApp(const ProviderScope(child: BeanProfileApp()));
```

- [ ] **Step 6: 통과 & 커밋**

Run: `flutter test test/widget/app_shell_test.dart` → PASS
> `BeanListScreen`은 Task 7에서 구현한다. 이 태스크에서 셸 테스트를 먼저 통과시키려면 `bean_list_screen.dart`에 임시 `class BeanListScreen extends StatelessWidget { ... Scaffold(body: Center(child: Text('원두'))) }`를 두고, Task 7에서 실제 구현으로 교체한다.
```bash
git add -A && git commit -m "feat(ui): theme tokens and 3-tab app shell"
```

---

### Task 7: 원두 리스트 화면

**Files:**
- Create: `lib/features/beans/widgets/star_rating.dart`, `lib/features/beans/widgets/bean_card.dart`, `lib/features/beans/bean_list_screen.dart`(교체)
- Test: `test/widget/bean_list_test.dart`

**Interfaces:**
- Consumes: `beanListProvider`(Task 5), `BeanSummary`, `context.colors`, `monoStyle`.
- Produces: `BeanListScreen`(원두 탭 본문), `BeanCard({required BeanSummary summary, VoidCallback? onTap})`, `StarRating({double? value, double size})`.

- [ ] **Step 1: 실패 위젯 테스트**

`test/widget/bean_list_test.dart`:
```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Bean _bean(String name) => Bean(
      id: 1, name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const ['블루베리'],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));

Widget _host(List<BeanSummary> data) => ProviderScope(
      overrides: [
        beanListProvider.overrideWith((ref) => Stream.value(data)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const BeanListScreen()),
    );

void main() {
  testWidgets('renders bean cards', (tester) async {
    await tester.pumpWidget(_host([
      BeanSummary(bean: _bean('예가체프 코체레'), originLabel: 'Ethiopia', avgRating: 4.5, tastingCount: 6),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('블루베리'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 기록한 원두가 없어요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/widget/bean_list_test.dart` → FAIL

- [ ] **Step 3: StarRating 위젯**

`lib/features/beans/widgets/star_rating.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 15});
  final double? value; // null = 평가 없음
  final double size;

  @override
  Widget build(BuildContext context) {
    final crema = context.colors.crema;
    if (value == null) {
      return Text('평가 없음',
          style: TextStyle(fontSize: size * 0.8, color: context.colors.appMuted));
    }
    final v = value!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          v >= i ? Icons.star : (v >= i - 0.5 ? Icons.star_half : Icons.star_border),
          size: size, color: crema,
        ),
      const SizedBox(width: 4),
      Text(v.toStringAsFixed(1), style: monoStyle(size: size * 0.8, color: context.colors.espresso)),
    ]);
  }
}
```

- [ ] **Step 4: BeanCard 위젯**

`lib/features/beans/widgets/bean_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../data/enums.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import 'star_rating.dart';

class BeanCard extends StatelessWidget {
  const BeanCard({super.key, required this.summary, this.onTap});
  final BeanSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bean = summary.bean;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.cup,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.appLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bean.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text([bean.roaster, summary.originLabel].where((e) => e != null && e.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12, color: c.appMuted)),
          const SizedBox(height: 8),
          Row(children: [
            if (bean.type == BeanType.blend) ...[
              _Badge(text: 'BLEND', color: c.cremaInk),
              const SizedBox(width: 8),
            ],
            StarRating(value: summary.avgRating),
            const Spacer(),
            Text('시음 ${summary.tastingCount}', style: monoStyle(size: 11, color: c.appMuted)),
          ]),
          if (bean.cupNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final n in bean.cupNotes.take(4)) _Note(text: n, color: c),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text; final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: monoStyle(size: 10, color: color)),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});
  final String text; final AppColors color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.oat,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.appLine),
        ),
        child: Text(text, style: TextStyle(fontSize: 10.5, color: color.espresso)),
      );
}
```

- [ ] **Step 5: 리스트 화면**

`lib/features/beans/bean_list_screen.dart` (교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'bean_detail_screen.dart';
import 'bean_form_screen.dart';
import 'widgets/bean_card.dart';

class BeanListScreen extends ConsumerWidget {
  const BeanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beans = ref.watch(beanListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BeanFormScreen())),
        backgroundColor: context.colors.crema,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: beans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('아직 기록한 원두가 없어요\n＋ 로 첫 원두를 추가해 보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.appMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = list[i];
              return BeanCard(
                summary: s,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BeanDetailScreen(beanId: s.bean.id))),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: 통과 & 커밋** (BeanFormScreen/BeanDetailScreen은 Task 8/9에서 구현 — 그 전까지 이 태스크 테스트만 돌리려면 두 파일에 최소 스텁 클래스를 먼저 만들어 둔다.)

Run: `flutter test test/widget/bean_list_test.dart` → PASS
```bash
git add -A && git commit -m "feat(ui): bean list screen with cards and empty state"
```

---

### Task 8: 원두 추가(수동) 폼

**Files:**
- Create: `lib/features/beans/bean_form_screen.dart`(교체)
- Test: `test/widget/bean_form_test.dart`

**Interfaces:**
- Consumes: `beanRepositoryProvider`(create), `BeanInput`/`ComponentInput`, enums, `context.colors`.
- Produces: `BeanFormScreen`(원두 추가 화면). 저장 성공 시 `Navigator.pop`.

- [ ] **Step 1: 실패 위젯 테스트**

`test/widget/bean_form_test.dart`:
```dart
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entering name + country and saving persists a bean', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = () {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      return container.read(beanRepositoryProvider);
    }();

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const BeanFormScreen()),
    ));

    await tester.enterText(find.byKey(const Key('field-name')), '수프리모');
    await tester.enterText(find.byKey(const Key('field-country-0')), 'Colombia');
    await tester.tap(find.byKey(const Key('save-bean')));
    await tester.pumpAndSettle();

    final list = await repo.watchBeanSummaries().first;
    expect(list, hasLength(1));
    expect(list.first.bean.name, '수프리모');
    expect(list.first.originLabel, 'Colombia');
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/widget/bean_form_test.dart` → FAIL

- [ ] **Step 3: 폼 구현**

`lib/features/beans/bean_form_screen.dart` (교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';

class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({super.key});
  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _ComponentDraft {
  final country = TextEditingController();
  final region = TextEditingController();
  Process process = Process.washed;
  final ratio = TextEditingController();
  void dispose() { country.dispose(); region.dispose(); ratio.dispose(); }
}

class _BeanFormScreenState extends ConsumerState<BeanFormScreen> {
  final _name = TextEditingController();
  final _roaster = TextEditingController();
  final _cupNotes = TextEditingController();
  final _memo = TextEditingController();
  BeanType _type = BeanType.singleOrigin;
  RoastLevel? _roast;
  DateTime? _roastDate;
  final _components = [_ComponentDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _roaster.dispose(); _cupNotes.dispose(); _memo.dispose();
    for (final c in _components) { c.dispose(); }
    super.dispose();
  }

  List<String> _parseNotes() => _cupNotes.text
      .split(RegExp(r'[,\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

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
    await ref.read(beanRepositoryProvider).createBean(input);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('원두 추가')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        TextField(key: const Key('field-name'), controller: _name,
            decoration: const InputDecoration(labelText: '제품명 *')),
        const SizedBox(height: 10),
        TextField(controller: _roaster, decoration: const InputDecoration(labelText: '로스터리')),
        const SizedBox(height: 14),
        SegmentedButton<BeanType>(
          segments: const [
            ButtonSegment(value: BeanType.singleOrigin, label: Text('싱글')),
            ButtonSegment(value: BeanType.blend, label: Text('블렌드')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 14),
        Text('원산지 구성', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        for (var i = 0; i < _components.length; i++) _componentEditor(i),
        if (_type == BeanType.blend)
          TextButton.icon(
            onPressed: () => setState(() => _components.add(_ComponentDraft())),
            icon: const Icon(Icons.add), label: const Text('구성 원두 추가'),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RoastLevel>(
          initialValue: _roast,
          decoration: const InputDecoration(labelText: '로스팅 단계'),
          items: [for (final r in RoastLevel.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (v) => setState(() => _roast = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(_roastDate == null ? '로스팅 날짜 없음'
              : '로스팅 ${_roastDate!.toIso8601String().substring(0, 10)}')),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context,
                  firstDate: DateTime(2015), lastDate: DateTime(2100),
                  initialDate: DateTime.now());
              if (picked != null) setState(() => _roastDate = picked);
            },
            child: const Text('날짜 선택'),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _cupNotes,
            decoration: const InputDecoration(labelText: '컵노트 (쉼표로 구분)', hintText: '블루베리, 자스민, 홍차')),
        const SizedBox(height: 10),
        TextField(controller: _memo, maxLines: 3, decoration: const InputDecoration(labelText: '메모')),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('save-bean'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: c.espresso, foregroundColor: c.oat,
              minimumSize: const Size.fromHeight(48)),
          child: Text(_saving ? '저장 중…' : '저장'),
        ),
      ]),
    );
  }

  Widget _componentEditor(int i) {
    final comp = _components[i];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              key: Key('field-country-$i'),
              controller: comp.country,
              decoration: InputDecoration(labelText: i == 0 ? '원산지 국가 *' : '국가'),
            ),
          ),
          if (_type == BeanType.blend && _components.length > 1)
            IconButton(
              onPressed: () => setState(() { _components.removeAt(i).dispose(); }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: comp.region,
              decoration: const InputDecoration(labelText: '지역'))),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<Process>(
              initialValue: comp.process,
              decoration: const InputDecoration(labelText: '가공'),
              items: [for (final p in Process.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (v) => setState(() => comp.process = v ?? Process.washed),
            ),
          ),
          if (_type == BeanType.blend) ...[
            const SizedBox(width: 10),
            SizedBox(width: 64, child: TextField(controller: comp.ratio,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '%'))),
          ],
        ]),
      ]),
    );
  }
}
```

- [ ] **Step 4: 통과 & 커밋**

Run: `flutter test test/widget/bean_form_test.dart` → PASS
```bash
git add -A && git commit -m "feat(ui): manual add-bean form with origin components"
```

---

### Task 9: 원두 상세(읽기 전용)

**Files:**
- Create: `lib/features/beans/bean_detail_screen.dart`(교체)
- Test: `test/widget/bean_detail_test.dart`

**Interfaces:**
- Consumes: `beanDetailProvider(beanId)`, `BeanDetail`, enums, `context.colors`, `monoStyle`.
- Produces: `BeanDetailScreen({required int beanId})`. 시음 섹션은 빈 상태(추가 버튼 M2).

- [ ] **Step 1: 실패 위젯 테스트**

`test/widget/bean_detail_test.dart`:
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
  testWidgets('shows profile spec and empty tasting state', (tester) async {
    final bean = Bean(
      id: 7, name: '예가체프 코체레', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null, cupNotes: const ['블루베리'],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));
    final comp = OriginComponent(
      id: 1, beanId: 7, country: 'Ethiopia', region: 'Yirgacheffe',
      farm: null, variety: 'Heirloom', process: Process.washed,
      altitude: '1900m', ratioPercent: null);
    final detail = BeanDetail(bean: bean, components: [comp], tastings: const []);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(7).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 7)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.textContaining('Ethiopia'), findsWidgets);
    expect(find.textContaining('아직 시음 기록이 없어요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/widget/bean_detail_test.dart` → FAIL

- [ ] **Step 3: 상세 화면 구현**

`lib/features/beans/bean_detail_screen.dart` (교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';

class BeanDetailScreen extends ConsumerWidget {
  const BeanDetailScreen({super.key, required this.beanId});
  final int beanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beanDetailProvider(beanId));
    return Scaffold(
      appBar: AppBar(title: const Text('원두 상세')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (d) => d == null
            ? const Center(child: Text('삭제된 원두예요'))
            : _DetailBody(detail: d),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});
  final BeanDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bean = detail.bean;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(bean.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text([bean.roaster, bean.type.label].where((e) => e.isNotEmpty).join(' · '),
          style: TextStyle(color: c.appMuted)),
      const SizedBox(height: 14),
      for (final comp in detail.components) _componentBlock(context, comp),
      if (bean.roastLevel != null || bean.roastDate != null)
        _specRow(context, '로스팅',
            [bean.roastDate?.toIso8601String().substring(0, 10), bean.roastLevel?.label]
                .where((e) => e != null).join(' · ')),
      if (bean.cupNotes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final n in bean.cupNotes)
            Chip(label: Text(n), backgroundColor: c.oat, side: BorderSide(color: c.appLine)),
        ]),
      ],
      if (bean.memo != null && bean.memo!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(bean.memo!, style: TextStyle(color: c.espresso)),
      ],
      const Divider(height: 32),
      Text('시음 기록 ${detail.tastings.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (detail.tastings.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cup, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.appLine),
          ),
          child: Text('아직 시음 기록이 없어요\n(시음 입력은 다음 단계에서 추가됩니다)',
              textAlign: TextAlign.center, style: TextStyle(color: c.appMuted)),
        )
      else
        for (final t in detail.tastings) _tastingRow(context, t),
    ]);
  }

  Widget _componentBlock(BuildContext context, OriginComponent comp) {
    final parts = <String>[
      comp.country,
      if (comp.region != null) comp.region!,
      if (comp.variety != null) comp.variety!,
      comp.process.label,
      if (comp.altitude != null) comp.altitude!,
      if (comp.ratioPercent != null) '${comp.ratioPercent}%',
    ];
    return _specRow(context, '원산지', parts.join(' · '));
  }

  Widget _specRow(BuildContext context, String k, String v) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.appLine)),
      child: Row(children: [
        SizedBox(width: 64, child: Text(k, style: TextStyle(color: c.appMuted, fontSize: 12))),
        Expanded(child: Text(v, style: monoStyle(size: 12, color: c.espresso))),
      ]),
    );
  }

  Widget _tastingRow(BuildContext context, Tasting t) {
    final c = context.colors;
    return Container(
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
    );
  }
}
```

- [ ] **Step 4: 전체 테스트 & 커밋**

Run: `flutter test` (전체) → 모두 PASS · `flutter analyze` → 0 issues
```bash
git add -A && git commit -m "feat(ui): read-only bean detail screen"
```

---

## Self-Review

**스펙 커버리지 (M1 범위):** 프로젝트 셋업 ✅(T1) · 데이터 모델 3테이블 ✅(T3) · 컵노트 태그 ✅(T2,T4) · 블렌드 구성별 구조화 ✅(T4,T8) · 로컬 저장 ✅(T3) · 원두 추가/리스트/상세 ✅(T7,T8,T9) · 테마 토큰/3탭 ✅(T6). 시음·OCR·대시보드·편집/삭제·백업 = **M2~M5로 의도적 이월**(로드맵 명시).

**플레이스홀더 스캔:** `models.dart`의 `Object` 필드는 Task 4 Step 3에서 enum 타입으로 교체하도록 명시(임시 아님). Task 6/7의 상호 의존은 "최소 스텁 후 교체"로 순서 명시. TODO/미정 없음.

**타입 일관성:** `BeanInput`/`ComponentInput`/`BeanSummary`/`BeanDetail` 필드가 T4 정의와 T7/T8/T9 사용처에서 일치. `createBean`·`watchBeanSummaries`·`watchBeanDetail`·`getBeanDetail` 시그니처가 provider(T5)와 화면(T7~T9)에서 동일하게 사용됨. drift 생성 클래스명 `Bean`/`OriginComponent`/`Tasting`을 테스트/화면에서 일관 사용.

## 실행 참고

- M1 완료 = **앱 실행 → 원두 추가 → 리스트에 표시 → 탭하면 상세** 가 실제 기기/에뮬레이터에서 동작.
- 실기기 실행: `flutter run` (Android 에뮬레이터 또는 iOS 시뮬레이터 필요).
- 다음: M2 상세 계획(원두 편집/삭제 + 시음 기록) 작성.
