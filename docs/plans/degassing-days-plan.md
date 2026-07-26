# 디개싱 일수 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시음 기록마다 "로스팅 후 며칠째에 마셨는가"를 남긴다 — 로스팅 날짜가 있으면 자동 계산, 없으면 직접 입력.

**Architecture:** `Tastings`에 nullable `degassingDays` 컬럼 하나를 더하고(프로젝트 첫 drift 마이그레이션), 표시 문자열은 Flutter 의존 없는 순수 함수 `degassingLabel` 하나가 전담한다. 시음 폼과 원두 상세의 시음 카드가 그 함수를 같이 쓴다.

**Tech Stack:** Flutter 3.44.6 · Dart SDK `^3.9.0` · drift 2.31 + drift_flutter · Riverpod 3.x · flutter_test

**설계 문서:** [`degassing-days-design.md`](degassing-days-design.md) · **목업:** [`../mockups/degassing-days.html`](../mockups/degassing-days.html)

## Global Constraints

- **사용자 문구는 전부 한국어.** 이 앱에는 `localizationsDelegates`가 등록돼 있지 않아 Material 기본 문구는 영어로 새어 나온다.
- **표기는 `디개싱 8일`.** 0일은 `당일`, 음수는 `날짜 확인`. `8일차`는 쓰지 않는다.
- **기준일은 시음일**(`tasting.date`)이지 오늘(`DateTime.now()`)이 아니다.
- **로스팅 날짜가 있으면 계산값이 이긴다.** 저장된 수동 입력값이 있어도 무시하되 지우지는 않는다.
- **표시에 상한이 없다.** 128일이든 400일이든 그대로 보여준다. 입력칸만 숫자·세 자리로 제한한다.
- **`backup_codec.dart`의 `_schemaVersion`은 1 그대로 둔다.** `decodeBackup`이 정확히 일치하는지만 보므로 올리면 기존 백업 파일이 거부된다.
- **`MigrationStrategy`의 `beforeOpen`에 있는 `PRAGMA foreign_keys = ON`을 절대 지우지 않는다.** FK cascade delete가 여기 걸려 있다.
- 테스트 실행은 `flutter test --concurrency=1 -r expanded` — Windows에서 기본 리포터가 출력을 중복시켜 개수를 잘못 읽게 만든다.
- 커밋은 `main`에 직접(트렁크 방식). 태스크마다 한 커밋.

---

## File Structure

**신규**

| 파일 | 책임 |
|---|---|
| `lib/features/tasting/degassing.dart` | `degassingLabel` 순수 함수. Flutter import 금지 |
| `test/unit/degassing_test.dart` | 위 함수의 규칙표 + UTC 정규화 |
| `test/unit/migration_test.dart` | v1 → v2 마이그레이션에서 데이터 생존 |
| `test/unit/tasting_repo_test.dart` | `createTasting`/`updateTasting`의 새 필드 왕복 |

**수정**

| 파일 | 변경 |
|---|---|
| `lib/data/tables.dart` | `Tastings.degassingDays` 컬럼 |
| `lib/data/database.dart` | `schemaVersion` 2 + `onUpgrade` |
| `lib/data/database.g.dart` | 코드 생성 결과 (직접 편집 금지) |
| `lib/data/models.dart` | `TastingInput.degassingDays` + `fromTasting` |
| `lib/data/bean_repository.dart` | 컴패니언 매핑 2곳 |
| `lib/features/tasting/tasting_form_screen.dart` | `roastDate` 파라미터 · 디개싱 줄 · 저장 |
| `lib/features/beans/bean_detail_screen.dart` | 호출부 2곳 · `_tastingRow` 알약 |
| `test/helpers.dart` | `sampleTasting`/`tastingRow`/`beanRow` 파라미터 |
| `test/unit/backup_codec_test.dart` | 옛 백업 디코드 |
| `test/widget/tasting_form_test.dart` · `tasting_edit_test.dart` · `keyboard_dismiss_test.dart` | `roastDate` 인수 + 코멘트 필드 Key |
| `test/widget/bean_detail_test.dart` | 알약 케이스 |

---

## Task 1: 데이터 레이어 — 컬럼 · 첫 마이그레이션 · 백업 호환

**Files:**
- Modify: `lib/data/tables.dart` · `lib/data/database.dart` · `lib/data/models.dart` · `lib/data/bean_repository.dart` · `test/helpers.dart`
- Create: `test/unit/migration_test.dart` · `test/unit/tasting_repo_test.dart`
- Test: `test/unit/backup_codec_test.dart` (추가)

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces:
  - `Tasting.degassingDays` → `int?` (drift 생성 행 클래스의 필드)
  - `TastingInput({..., int? degassingDays})` — 이름 있는 선택 파라미터, 기본 `null`
  - `TastingInput.fromTasting(Tasting t)`가 `degassingDays`를 함께 옮긴다
  - `sampleTasting({..., int? degassingDays})` · `tastingRow({..., int? degassingDays})` (test/helpers.dart)

**이 태스크가 이 변경에서 가장 위험한 부분이다.** 지금까지 이 프로젝트에 마이그레이션이 한 번도 없었고(`schemaVersion => 1`, `onUpgrade` 없음), 사용자 폰에는 실제 시음 기록이 들어 있다. 그래서 구현보다 테스트를 먼저 쓴다.

- [ ] **Step 1: 마이그레이션 테스트를 먼저 쓴다 (RED)**

`test/unit/migration_test.dart` 생성:

```dart
import 'package:beanprofile/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// v1 스키마 그대로의 DDL. drift는 camelCase를 snake_case로, DateTime을
/// INTEGER(unix ms)로 저장한다. tastings에 degassing_days가 없는 것이 핵심.
const _v1Ddl = [
  '''
  CREATE TABLE beans (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    roaster TEXT NOT NULL DEFAULT '',
    type INTEGER NOT NULL,
    roast_level INTEGER NULL,
    roast_date INTEGER NULL,
    cup_notes TEXT NOT NULL DEFAULT '[]',
    photo_path TEXT NULL,
    sca_score REAL NULL,
    weight_grams INTEGER NULL,
    price INTEGER NULL,
    shop TEXT NULL,
    memo TEXT NULL,
    created_at INTEGER NOT NULL
  )''',
  '''
  CREATE TABLE origin_components (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    bean_id INTEGER NOT NULL REFERENCES beans(id) ON DELETE CASCADE,
    country TEXT NOT NULL,
    region TEXT NULL,
    farm TEXT NULL,
    variety TEXT NULL,
    process INTEGER NOT NULL DEFAULT 0,
    altitude TEXT NULL,
    ratio_percent INTEGER NULL
  )''',
  '''
  CREATE TABLE tastings (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    bean_id INTEGER NOT NULL REFERENCES beans(id) ON DELETE CASCADE,
    date INTEGER NOT NULL,
    acidity INTEGER NOT NULL,
    sweetness INTEGER NOT NULL,
    body INTEGER NOT NULL,
    bitterness INTEGER NOT NULL,
    overall INTEGER NOT NULL,
    comment TEXT NULL,
    created_at INTEGER NOT NULL
  )''',
];

void main() {
  test('v1 데이터가 v2로 올라가도 살아남는다', () async {
    // NativeDatabase.memory의 setup은 drift가 DB를 건드리기 전에 실행된다 —
    // 여기서 v1 스키마와 데이터를 심고 user_version을 1로 두면
    // drift가 열면서 onUpgrade(1, 2)를 돈다.
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      for (final ddl in _v1Ddl) {
        raw.execute(ddl);
      }
      raw.execute(
        "INSERT INTO beans (id, name, roaster, type, cup_notes, created_at) "
        "VALUES (1, '예가체프', '프릳츠', 0, '[]', 1767225600000)",
      );
      raw.execute(
        'INSERT INTO tastings '
        '(id, bean_id, date, acidity, sweetness, body, bitterness, overall, comment, created_at) '
        "VALUES (1, 1, 1767225600000, 4, 3, 3, 2, 5, '균형이 좋다', 1767225600000)",
      );
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final tastings = await db.select(db.tastings).get();

    expect(tastings, hasLength(1), reason: 'v1 시음 기록이 마이그레이션에서 사라지면 안 된다');
    expect(tastings.single.comment, '균형이 좋다', reason: '기존 컬럼 값이 보존돼야 한다');
    expect(tastings.single.degassingDays, isNull, reason: '새 컬럼은 기존 행에서 null이다');

    final beans = await db.select(db.beans).get();
    expect(beans.single.name, '예가체프');

    // beforeOpen의 PRAGMA가 마이그레이션 후에도 적용됐는지 — FK cascade가 여기 달려 있다.
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1, reason: 'FK가 꺼지면 원두 삭제 시 시음이 고아로 남는다');
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/migration_test.dart --concurrency=1 -r expanded`
Expected: 컴파일 실패 — `The getter 'degassingDays' isn't defined for the type 'Tasting'`

- [ ] **Step 3: 컬럼을 추가한다**

`lib/data/tables.dart`의 `Tastings`에서 `comment` 아래, `createdAt` 위에 한 줄:

```dart
  TextColumn get comment => text().nullable()();
  IntColumn get degassingDays => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
```

- [ ] **Step 4: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart`가 갱신되고 `Tasting.degassingDays`, `TastingsCompanion.degassingDays`가 생긴다. `database.g.dart`는 직접 편집하지 않는다.

- [ ] **Step 5: 마이그레이션을 연다**

`lib/data/database.dart` — `schemaVersion`을 2로 올리고 `onUpgrade`를 더한다. **`beforeOpen`은 그대로 남긴다:**

```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // v2: 시음에 디개싱 일수(nullable) 추가. 기존 행은 null이 된다.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(tastings, tastings.degassingDays);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
```

`onCreate`는 지정하지 않는다 — drift 기본값 `m.createAll()`이 신규 설치에 v2 스키마를 그대로 만든다.

- [ ] **Step 6: 마이그레이션 테스트가 통과하는지 확인한다**

Run: `flutter test test/unit/migration_test.dart --concurrency=1 -r expanded`
Expected: PASS (1 test)

> **막히면:** 행이 안 읽히면 손으로 쓴 v1 DDL이 drift가 기대하는 컬럼명과 어긋난 것이다. 테스트 안에서 `await db.customSelect("SELECT sql FROM sqlite_master WHERE name='tastings'").getSingle()`을 찍어 실제 스키마와 비교하라. 컬럼 **이름과 타입**만 맞으면 되고 `AUTOINCREMENT` 유무는 상관없다.

- [ ] **Step 7: `TastingInput`에 필드를 더한다**

`lib/data/models.dart`의 `TastingInput` — 필드·생성자·`fromTasting` 세 곳 모두:

```dart
class TastingInput {
  final DateTime date;
  final int acidity;
  final int sweetness;
  final int body;
  final int bitterness;
  final int overall;
  final String? comment;
  final int? degassingDays;
  const TastingInput({
    required this.date,
    required this.acidity,
    required this.sweetness,
    required this.body,
    required this.bitterness,
    required this.overall,
    this.comment,
    this.degassingDays,
  });

  factory TastingInput.fromTasting(Tasting t) => TastingInput(
        date: t.date,
        acidity: t.acidity,
        sweetness: t.sweetness,
        body: t.body,
        bitterness: t.bitterness,
        overall: t.overall,
        comment: t.comment,
        degassingDays: t.degassingDays,
      );
}
```

`fromTasting`을 빠뜨리면 시음 삭제 후 **실행취소**가 일수를 잃는다(`bean_detail_screen.dart`의 Undo 스낵바가 이 팩토리를 쓴다).

- [ ] **Step 8: 저장소 매핑 2곳**

`lib/data/bean_repository.dart` — `createTasting`의 `comment` 아래, `updateTasting`의 `comment` 아래 각각 한 줄:

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
          degassingDays: Value(t.degassingDays),
          createdAt: DateTime.now(),
        ));
  }

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
      degassingDays: Value(t.degassingDays),
    ));
  }
```

- [ ] **Step 9: 테스트 헬퍼에 파라미터를 더한다**

`test/helpers.dart` — `sampleTasting`과 `tastingRow` 두 곳:

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
  int? degassingDays,
}) =>
    TastingInput(
      date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall, comment: comment,
      degassingDays: degassingDays,
    );
```

```dart
Tasting tastingRow({
  int id = 1,
  int beanId = 1,
  int overall = 4,
  int acidity = 3,
  int sweetness = 3,
  int body = 3,
  int bitterness = 3,
  int? degassingDays,
}) =>
    Tasting(
      id: id, beanId: beanId, date: DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall,
      degassingDays: degassingDays,
      createdAt: DateTime(2026, 7, 1),
    );
```

- [ ] **Step 10: 저장소 왕복 테스트를 쓴다**

`test/unit/tasting_repo_test.dart` 생성:

```dart
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('디개싱 일수가 저장·수정·되읽기를 왕복한다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await repo.createTasting(beanId, sampleTasting(degassingDays: 8));
    var t = (await repo.getBeanDetail(beanId))!.tastings.single;
    expect(t.degassingDays, 8);

    await repo.updateTasting(t.id, sampleTasting(degassingDays: 12));
    t = (await repo.getBeanDetail(beanId))!.tastings.single;
    expect(t.degassingDays, 12, reason: '수정이 반영돼야 한다');

    await repo.updateTasting(t.id, sampleTasting());
    t = (await repo.getBeanDetail(beanId))!.tastings.single;
    expect(t.degassingDays, isNull, reason: '값을 비우면 null로 지워져야 한다');
  });

  test('실행취소용 fromTasting이 일수를 함께 옮긴다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());
    await repo.createTasting(beanId, sampleTasting(degassingDays: 8));
    final original = (await repo.getBeanDetail(beanId))!.tastings.single;

    await repo.deleteTasting(original.id);
    // 실행취소 스낵바가 하는 그대로 — bean_detail_screen의 _deleteTastingWithUndo 참조.
    await repo.createTasting(beanId, TastingInput.fromTasting(original));

    final restored = (await repo.getBeanDetail(beanId))!.tastings.single;
    expect(restored.degassingDays, 8);
  });
}
```

- [ ] **Step 11: 옛 백업이 여전히 읽히는지 테스트한다**

`test/unit/backup_codec_test.dart` 맨 아래 `main()` 안에 추가. 파일 상단에 `import 'dart:convert';`가 없으면 더한다:

```dart
  test('degassingDays 키가 없는 옛 백업도 그대로 읽힌다', () {
    final snap = TasteSnapshot(
      beans: [beanRow(id: 1)],
      components: const [],
      tastings: [tastingRow(id: 1, beanId: 1, degassingDays: 8)],
    );
    final fresh = encodeBackup(snap, const {}, exportedAt: DateTime.utc(2026, 7, 22));

    // v0.5.0이 만든 백업 파일에는 이 키가 아예 없다 — 지워서 그때 파일을 재현한다.
    final root = jsonDecode(fresh) as Map<String, dynamic>;
    for (final t in (root['tastings'] as List)) {
      expect((t as Map).remove('degassingDays'), 8, reason: '새 백업에는 키가 실려야 한다');
    }

    final decoded = decodeBackup(jsonEncode(root));
    expect(decoded.snapshot.tastings.single.degassingDays, isNull,
        reason: '키가 없는 옛 백업은 null로 읽혀야 한다 — 예외를 던지면 안 된다');
  });
```

이 테스트가 판별력을 갖는 이유: 키를 지우기 **전에** 8이었는지 확인하므로, 값이 원래 null이라 통과하는 위양성이 없다.

- [ ] **Step 12: 전체 테스트 + 정적 분석**

Run: `flutter analyze && flutter test --concurrency=1 -r expanded`
Expected: analyze 0 issues · 전부 PASS (기존 324 + 신규 4 = 328)

- [ ] **Step 13: 커밋**

```bash
git add lib/data test/helpers.dart test/unit/migration_test.dart test/unit/tasting_repo_test.dart test/unit/backup_codec_test.dart
git commit -m "feat(tasting): store degassing days on tastings"
```

---

## Task 2: 순수 함수 `degassingLabel`

**Files:**
- Create: `lib/features/tasting/degassing.dart`
- Test: `test/unit/degassing_test.dart`

**Interfaces:**
- Consumes: 없음. **Flutter를 import하지 않는다** (M4 `computeTasteProfile`, M5 `backup_codec`과 같은 결)
- Produces:
  ```dart
  ({String text, bool warn})? degassingLabel({
    DateTime? roastDate,
    required DateTime tastingDate,
    int? manualDays,
  })
  ```
  Task 3(시음 폼)과 Task 4(시음 카드)가 이 함수 하나를 같이 쓴다.

- [ ] **Step 1: 테스트를 먼저 쓴다 (RED)**

`test/unit/degassing_test.dart` 생성:

```dart
import 'package:beanprofile/features/tasting/degassing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('로스팅 날짜가 있으면 시음일과의 차이를 쓴다', () {
    test('8일 차이', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 27));
      expect(r?.text, '디개싱 8일');
      expect(r?.warn, isFalse);
    });

    test('같은 날이면 당일', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 19));
      expect(r?.text, '당일');
      expect(r?.warn, isFalse);
    });

    test('시음일이 앞서면 날짜 확인', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 15));
      expect(r?.text, '날짜 확인');
      expect(r?.warn, isTrue);
    });

    test('큰 값도 자르지 않는다', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 1, 1), tastingDate: DateTime(2026, 7, 27));
      expect(r?.text, '디개싱 207일');
    });

    test('수동 입력값이 있어도 계산값이 이긴다', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19),
          tastingDate: DateTime(2026, 7, 27),
          manualDays: 99);
      expect(r?.text, '디개싱 8일', reason: '로스팅 날짜가 사실이고 입력값은 대역이다');
    });
  });

  group('로스팅 날짜가 없으면 입력값을 쓴다', () {
    test('입력 8', () {
      final r = degassingLabel(tastingDate: DateTime(2026, 7, 27), manualDays: 8);
      expect(r?.text, '디개싱 8일');
      expect(r?.warn, isFalse);
    });

    test('입력 0은 당일', () {
      final r = degassingLabel(tastingDate: DateTime(2026, 7, 27), manualDays: 0);
      expect(r?.text, '당일');
    });

    test('둘 다 없으면 null', () {
      expect(degassingLabel(tastingDate: DateTime(2026, 7, 27)), isNull);
    });
  });

  test('시각이 섞여도 날짜 차이만 센다', () {
    // 시음 폼의 _date는 DateTime.now()라 시각이 붙어 있고,
    // roastDate는 날짜 선택기에서 와 자정이다. 정규화하지 않으면 하루가 틀어진다.
    final r = degassingLabel(
      roastDate: DateTime(2026, 7, 19, 0, 0),
      tastingDate: DateTime(2026, 7, 27, 23, 30),
    );
    expect(r?.text, '디개싱 8일', reason: '23:30이라고 9일이 되면 안 된다');

    final back = degassingLabel(
      roastDate: DateTime(2026, 7, 19, 23, 30),
      tastingDate: DateTime(2026, 7, 27, 0, 0),
    );
    expect(back?.text, '디개싱 8일', reason: '반대 방향도 마찬가지로 8일이다');
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/unit/degassing_test.dart --concurrency=1 -r expanded`
Expected: 컴파일 실패 — `Error: Couldn't resolve the package 'beanprofile/features/tasting/degassing.dart'`

- [ ] **Step 3: 함수를 구현한다**

`lib/features/tasting/degassing.dart` 생성:

```dart
/// 시음 카드·폼에 띄울 디개싱 표시. 띄울 게 없으면 null.
///
/// 로스팅 날짜가 있으면 시음일과의 차이가 이기고, 없으면 사용자가 적은 값을 쓴다.
/// 기준은 오늘이 아니라 시음일이라, 지난 기록을 다시 열어도 숫자가 흔들리지 않는다.
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

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/unit/degassing_test.dart --concurrency=1 -r expanded`
Expected: PASS (9 tests) — 전체는 Task 1의 328 + 9 = 337 안팎

> 계획에 적힌 테스트 총계는 어긋나도 괜찮은 **눈대중**이다(리뷰 중 회귀 테스트가 붙으면 늘어난다). 게이트는 숫자가 아니라 "전부 green"이다.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/tasting/degassing.dart test/unit/degassing_test.dart
git commit -m "feat(tasting): compute degassing label from roast and tasting dates"
```

---

## Task 3: 시음 폼 — 자동 표시와 직접 입력

**Files:**
- Modify: `lib/features/tasting/tasting_form_screen.dart` · `lib/features/beans/bean_detail_screen.dart:59,215`
- Test: `test/widget/tasting_form_test.dart` · `test/widget/tasting_edit_test.dart` · `test/widget/keyboard_dismiss_test.dart`

**Interfaces:**
- Consumes:
  - `TastingInput({..., int? degassingDays})` (Task 1)
  - `degassingLabel({DateTime? roastDate, required DateTime tastingDate, int? manualDays})` → `({String text, bool warn})?` (Task 2)
- Produces:
  - `TastingFormScreen({required int beanId, required DateTime? roastDate, Tasting? existing})`
  - 위젯 Key: `Key('degassing-input')` (수동 입력칸) · `Key('tasting-comment')` (코멘트 필드)

> **먼저 알아야 할 함정:** 지금 `tasting_form_test.dart:18`과 `keyboard_dismiss_test.dart:22`가 `find.byType(TextField)`로 코멘트 필드를 찾는다. 디개싱 입력칸이 생기면 TextField가 둘이 되어 **`find.byType(TextField)`가 애매해지고 기존 테스트가 깨진다.** 그래서 코멘트 필드에 `Key('tasting-comment')`를 붙이고 두 테스트를 그 Key로 바꾼다. 이 변경은 이번 작업이 만든 문제를 치우는 것이라 범위 안이다.

- [ ] **Step 1: 위젯 테스트를 먼저 쓴다 (RED)**

`test/widget/tasting_form_test.dart` — 기존 테스트의 18번째 줄을 Key 기반으로 바꾸고, 그 아래에 새 테스트 셋을 더한다. 파일 전체:

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

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byKey(const Key('tasting-comment')), '초콜릿, 견과');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.acidity, 5);
    expect(detail.tastings.first.overall, 4);
    expect(detail.tastings.first.comment, '초콜릿, 견과');
  });

  testWidgets('로스팅 날짜가 있으면 자동 계산해서 읽기 전용으로 보여준다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: beanId, roastDate: DateTime(2026, 7, 19)),
        db: db));
    await tester.pumpAndSettle();

    expect(find.textContaining('로스팅 2026-07-19'), findsOneWidget,
        reason: '숫자의 출처를 감추지 않는다');
    expect(find.byKey(const Key('degassing-input')), findsNothing,
        reason: '계산되는 값이라 입력칸이 없어야 한다');
  });

  testWidgets('시음일을 바꾸면 표시된 일수가 따라 바뀐다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: beanId, roastDate: DateTime(2026, 7, 19)),
        db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    // 날짜 선택기를 27일로 옮긴다 — 기본값이 오늘이라 직접 고른다.
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 8일'), findsOneWidget);
  });

  testWidgets('로스팅 날짜가 없으면 직접 입력해서 저장한다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    expect(find.text('로스팅 날짜 없음'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('degassing-input')), '12');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings.single.degassingDays, 12);
  });

  testWidgets('입력칸은 숫자만 받는다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('degassing-input')), '-8일');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings.single.degassingDays, 8,
        reason: '부호와 문자는 formatter가 걸러 8만 남는다');
  });
}
```

- [ ] **Step 2: 편집 화면 테스트를 고친다 (프리필 검증 추가)**

`test/widget/tasting_edit_test.dart` 전체:

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
    await repo.createTasting(
        id, sampleTasting(overall: 2, comment: '초안', degassingDays: 8));
    final tasting = (await repo.getBeanDetail(id))!.tastings.first;

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: id, roastDate: null, existing: tasting),
        db: db));
    await tester.pumpAndSettle();

    expect(find.text('초안'), findsOneWidget); // 프리필된 코멘트
    expect(find.text('8'), findsOneWidget); // 프리필된 디개싱 일수
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.tastings.first.overall, 5);
    expect(updated.tastings.first.degassingDays, 8,
        reason: '건드리지 않은 일수가 저장에서 지워지면 안 된다');
  });
}
```

- [ ] **Step 3: 키보드 dismiss 테스트를 Key 기반으로 바꾼다**

`test/widget/keyboard_dismiss_test.dart` — 19·22번째 줄만 바꾼다:

```dart
    await tester.pumpWidget(
        wrapApp(const TastingFormScreen(beanId: 1, roastDate: null), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tasting-comment'))); // focus the comment field
```

`const` 생성자 호출은 그대로 유지된다 — `null`은 컴파일 타임 상수다.

- [ ] **Step 4: 실패를 확인한다**

Run: `flutter test test/widget/tasting_form_test.dart test/widget/tasting_edit_test.dart test/widget/keyboard_dismiss_test.dart --concurrency=1 -r expanded`
Expected: 컴파일 실패 — `No named parameter with the name 'roastDate'`

- [ ] **Step 5: 폼에 파라미터와 상태를 더한다**

`lib/features/tasting/tasting_form_screen.dart` — 상단 import에 두 줄을 더한다:

```dart
import 'package:flutter/services.dart';
import 'degassing.dart';
```

생성자와 필드:

```dart
class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen({
    super.key,
    required this.beanId,
    required this.roastDate,
    this.existing,
  });
  final int beanId;
  /// 원두의 로스팅 날짜. 있으면 디개싱 일수를 계산해 읽기 전용으로 보여주고,
  /// 없으면 사용자가 직접 적는다.
  final DateTime? roastDate;
  final Tasting? existing;
  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormScreenState();
}
```

상태 필드 — `_comment` 아래:

```dart
  final _comment = TextEditingController();
  final _degassing = TextEditingController();
```

`initState`의 `if (e != null) { ... }` 블록 맨 아래:

```dart
      _comment.text = e.comment ?? '';
      _degassing.text = e.degassingDays?.toString() ?? '';
```

`dispose`:

```dart
  @override
  void dispose() {
    _comment.dispose();
    _degassing.dispose();
    super.dispose();
  }
```

- [ ] **Step 6: 저장에 값을 싣는다**

`_save()`의 `TastingInput` 생성에 한 줄:

```dart
    final input = TastingInput(
      date: _date,
      acidity: _acidity, sweetness: _sweetness, body: _body,
      bitterness: _bitterness, overall: _overall,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      degassingDays: int.tryParse(_degassing.text),
    );
```

컨트롤러는 `roastDate` 여부와 무관하게 초기화되고 저장도 무조건 이 한 줄을 쓴다. 그래서 `roastDate`가 있어 입력칸이 **안 보이는 동안에도** 기존 값이 그대로 보존되며, 분기가 필요 없다.

- [ ] **Step 7: 디개싱 줄을 그린다**

`_TastingFormScreenState`에 메서드를 더한다(`build` 바로 위):

```dart
  Widget _degassingRow(BuildContext context) {
    final c = context.colors;
    const label = SizedBox(
        width: 52, child: Text('디개싱', style: TextStyle(fontSize: 13.5)));

    if (widget.roastDate == null) {
      return Row(children: [
        label,
        SizedBox(
          width: 82,
          child: TextField(
            key: const Key('degassing-input'),
            controller: _degassing,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(counterText: '', suffixText: '일'),
          ),
        ),
        const SizedBox(width: 10),
        Text('로스팅 날짜 없음', style: TextStyle(fontSize: 11.5, color: c.appMuted)),
      ]);
    }

    final deg = degassingLabel(roastDate: widget.roastDate, tastingDate: _date);
    if (deg == null) return const SizedBox.shrink(); // roastDate가 있으면 도달하지 않는다
    return Row(children: [
      label,
      Text(deg.text,
          style: monoStyle(
              size: 13, weight: FontWeight.w600,
              color: deg.warn ? c.cherry : c.espresso)),
      const SizedBox(width: 10),
      Text('로스팅 ${widget.roastDate!.toIso8601String().substring(0, 10)}',
          style: TextStyle(fontSize: 11.5, color: c.appMuted)),
    ]);
  }
```

- [ ] **Step 8: 줄을 폼에 끼운다**

`build`의 `ListView` children — 시음일 `Row` 바로 다음의 `const SizedBox(height: 8)`를 다음으로 **교체**한다:

```dart
        ]),
        _degassingRow(context),
        const Divider(height: 20),
        Text('강도', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
```

- [ ] **Step 9: 코멘트 필드에 Key를 붙인다**

같은 `build`의 맨 아래 `TextField`:

```dart
        TextField(
          key: const Key('tasting-comment'),
          controller: _comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '코멘트'),
        ),
```

- [ ] **Step 10: 호출부 2곳에 로스팅 날짜를 넘긴다**

`lib/features/beans/bean_detail_screen.dart` — 59번째 줄 근처(`add-tasting` 버튼). 이 `onPressed`는 `detail`이 non-null인 분기 밖에 있으므로 `detail?.bean.roastDate`로 읽는다:

```dart
          child: FilledButton.icon(
            key: const Key('add-tasting'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TastingFormScreen(
                    beanId: beanId, roastDate: detail?.bean.roastDate))),
```

215번째 줄 근처(`_DetailBody._tastingRow`) — 여기서는 `detail.bean`이 non-null이다:

```dart
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TastingFormScreen(
                beanId: t.beanId,
                roastDate: detail.bean.roastDate,
                existing: t))),
```

- [ ] **Step 11: 테스트가 통과하는지 확인한다**

Run: `flutter analyze && flutter test --concurrency=1 -r expanded`
Expected: analyze 0 issues · 전부 PASS (Task 2까지의 337 + 신규 4 = 341 안팎)

> **막히면:** "시음일을 바꾸면…" 테스트에서 `find.text('27')`이 여러 개 잡히면(날짜 선택기에 27이 두 번 나올 수 있다) `find.text('27').last`로 좁혀라. `find.text('OK')`가 안 잡히면 이 앱에 `localizationsDelegates`가 없어 Material 기본 영어 문구가 뜨는 것이 정상이다 — 실제로 뜬 문구를 `tester.allWidgets` 덤프로 확인하고 그 문구를 쓰라.

- [ ] **Step 12: 커밋**

```bash
git add lib/features/tasting/tasting_form_screen.dart lib/features/beans/bean_detail_screen.dart test/widget
git commit -m "feat(tasting): show and enter degassing days on the tasting form"
```

---

## Task 4: 시음 카드 알약

**Files:**
- Modify: `lib/features/beans/bean_detail_screen.dart:201-239` (`_DetailBody._tastingRow`) · `test/helpers.dart`
- Test: `test/widget/bean_detail_test.dart`

**Interfaces:**
- Consumes: `degassingLabel(...)` (Task 2) · `Tasting.degassingDays` (Task 1)
- Produces: 위젯 Key `Key('degassing-pill-<tastingId>')`

- [ ] **Step 1: 헬퍼에 날짜·로스팅 날짜 파라미터를 더한다**

`test/helpers.dart` — `beanRow`에 `roastDate`, `tastingRow`에 `date`를 더한다(`tastingRow`의 `degassingDays`는 Task 1에서 이미 들어갔다):

```dart
Bean beanRow({
  int id = 1,
  String name = '원두',
  String roaster = '',
  List<String> cupNotes = const [],
  String? photoPath,
  DateTime? createdAt,
  DateTime? roastDate,
}) =>
    Bean(
      id: id, name: name, roaster: roaster, type: BeanType.singleOrigin,
      cupNotes: cupNotes, photoPath: photoPath, roastDate: roastDate,
      createdAt: createdAt ?? DateTime(2026, 7, 1),
    );
```

```dart
Tasting tastingRow({
  int id = 1,
  int beanId = 1,
  int overall = 4,
  int acidity = 3,
  int sweetness = 3,
  int body = 3,
  int bitterness = 3,
  int? degassingDays,
  DateTime? date,
}) =>
    Tasting(
      id: id, beanId: beanId, date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall,
      degassingDays: degassingDays,
      createdAt: DateTime(2026, 7, 1),
    );
```

- [ ] **Step 2: 위젯 테스트를 먼저 쓴다 (RED)**

`test/widget/bean_detail_test.dart`의 `main()` 안에 추가. 상단 import에 `import '../helpers.dart';`가 없으면 더한다:

```dart
  testWidgets('시음 카드가 계산·수동·없음·음수를 한 목록에서 각각 맞게 그린다', (tester) async {
    final bean = beanRow(id: 9, name: '구지', roastDate: DateTime(2026, 7, 19));
    final detail = BeanDetail(bean: bean, components: const [], tastings: [
      tastingRow(id: 1, beanId: 9, date: DateTime(2026, 7, 27)), // 계산 → 8일
      tastingRow(id: 2, beanId: 9, date: DateTime(2026, 7, 19)), // 계산 → 당일
      tastingRow(id: 3, beanId: 9, date: DateTime(2026, 7, 15)), // 계산 → 음수
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(9).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 9)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 8일'), findsOneWidget);
    expect(find.text('당일'), findsOneWidget);
    expect(find.text('날짜 확인'), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-1')), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-3')), findsOneWidget);
  });

  testWidgets('로스팅 날짜가 없으면 입력값을 쓰고, 그것도 없으면 알약이 없다', (tester) async {
    final bean = beanRow(id: 10, name: '무명', roastDate: null);
    final detail = BeanDetail(bean: bean, components: const [], tastings: [
      tastingRow(id: 4, beanId: 10, degassingDays: 12),
      tastingRow(id: 5, beanId: 10), // 로스팅 날짜도 입력값도 없음
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(10).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 10)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 12일'), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-4')), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-5')), findsNothing,
        reason: '보여줄 게 없으면 알약 자체가 없어야 한다');
  });
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/widget/bean_detail_test.dart --concurrency=1 -r expanded`
Expected: FAIL — `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets with text "디개싱 8일">`

- [ ] **Step 4: 알약을 그린다**

`lib/features/beans/bean_detail_screen.dart` 상단 import에 한 줄:

```dart
import '../tasting/degassing.dart';
```

`_DetailBody`에 메서드를 더한다(`_tastingRow` 바로 위):

```dart
  Widget _degassingPill(BuildContext context, ({String text, bool warn}) deg, int tastingId) {
    final c = context.colors;
    return Container(
      key: Key('degassing-pill-$tastingId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: deg.warn ? c.cherry.withValues(alpha: 0.12) : c.oat,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: deg.warn ? c.cherry : c.appLine),
      ),
      child: Text(deg.text,
          style: monoStyle(
              size: 10.5, weight: FontWeight.w700,
              color: deg.warn ? c.cherry : c.cremaInk)),
    );
  }
```

`_tastingRow`의 `Column` 첫 자식(날짜 `Text`)을 다음으로 **교체**한다:

```dart
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t.date.toIso8601String().substring(0, 10),
                  style: monoStyle(size: 11, color: c.appMuted)),
              if (deg != null) ...[
                const SizedBox(width: 7),
                _degassingPill(context, deg, t.id),
              ],
            ]),
            const SizedBox(height: 4),
```

그리고 `_tastingRow` 본문 맨 위, `final c = context.colors;` 아래에 값을 만든다:

```dart
  Widget _tastingRow(BuildContext context, Tasting t) {
    final c = context.colors;
    final deg = degassingLabel(
      roastDate: detail.bean.roastDate,
      tastingDate: t.date,
      manualDays: t.degassingDays,
    );
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter analyze && flutter test --concurrency=1 -r expanded`
Expected: analyze 0 issues · 전부 PASS (Task 3까지의 341 + 신규 2 = 343 안팎)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/beans/bean_detail_screen.dart test/helpers.dart test/widget/bean_detail_test.dart
git commit -m "feat(beans): badge each tasting card with its degassing days"
```

---

## 계획이 해소한 설계 모호점

설계 문서를 코드로 옮기면서 드러난, 설계에 안 적혀 있던 결정들:

1. **`find.byType(TextField)` 충돌.** 디개싱 입력칸이 생기면 폼에 TextField가 둘이 되어 기존 두 테스트가 깨진다. 코멘트 필드에 `Key('tasting-comment')`를 붙이는 것으로 해소했다(Task 3 Step 9). 설계에는 이 파급이 없었다.

2. **`add-tasting` 버튼의 `detail` 접근.** `bean_detail_screen.dart:58`의 `onPressed`는 `detail != null` 분기 **밖**에 있어 `detail`이 nullable이다. `detail?.bean.roastDate`로 읽는다 — 로딩 중 눌리면 `null`이 넘어가고 수동 입력 모드가 되는데, 로딩은 인메모리 DB 한 프레임이라 실질적으로 도달하지 않는다.

3. **`TastingInput.fromTasting`.** 실행취소 스낵바가 이 팩토리로 시음을 되살린다. 여기에 `degassingDays`를 안 넣으면 **삭제 후 복구할 때 일수만 사라진다.** Task 1 Step 7에서 명시하고 Step 10에서 테스트한다.

4. **저장 시 분기 없음.** 컨트롤러를 `roastDate`와 무관하게 초기화하고 저장도 무조건 `int.tryParse(_degassing.text)`를 쓰면, 입력칸이 안 보이는 동안 기존 값이 저절로 보존된다. "계산값이 이길 때 저장된 값을 어떻게 하나"라는 설계의 빈칸이 분기 0개로 메워진다.

5. **v1 DDL을 손으로 쓴다.** drift는 v1 스키마를 어디에도 보관하지 않으므로(스냅샷 도구 미도입) 마이그레이션 테스트가 쓸 v1 CREATE TABLE을 직접 적었다. 컬럼 이름·타입만 맞으면 되고, 어긋나면 `sqlite_master`를 찍어 비교하라는 지침을 Step 6에 달았다.

## 완료 후

4개 태스크가 모두 끝나면 `superpowers:finishing-a-development-branch`로 마무리한다. DoD는 설계 문서 §7:

- `flutter analyze` 0 · `flutter test` 전체 green (343 안팎)
- 마이그레이션 테스트가 v1 데이터의 생존을 확인한다
- 단위 테스트가 UTC 정규화를 판별한다
- 옛 백업(키 없음) 디코드가 확인된다
- **기기에서:** 로스팅 날짜 있는 원두 → 자동 표시 / 없는 원두 → 직접 입력 → 카드 알약까지 왕복
- **기기 업데이트 후 기존 시음 기록이 그대로 남아 있다** (마이그레이션 실증 — 이번 릴리스의 핵심 확인 항목)
