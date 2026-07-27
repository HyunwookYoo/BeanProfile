import 'package:beanprofile/data/database.dart';
import 'package:drift/drift.dart' show Value;
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

    // 위 expect들은 전부 '읽기'다 — SELECT *는 없는 컬럼을 조용히 null로 읽으므로
    // onUpgrade가 통째로 no-op이어도 (컬럼이 아예 없어도) 똑같이 통과한다.
    // 마이그레이션이 실제로 컬럼을 더했는지는 스키마를 직접 봐야 판별된다.
    final cols = await db.customSelect("PRAGMA table_info('tastings')").get();
    expect(cols.map((r) => r.data['name']), contains('degassing_days'),
        reason: '마이그레이션이 실제로 컬럼을 더했는지');

    // 컬럼이 없으면 여기서 SqliteException('no such column: degassing_days')이
    // 터진다 — 읽기만으로는 못 잡는 no-op 마이그레이션을 쓰기로 잡는다.
    await db.into(db.tastings).insert(TastingsCompanion.insert(
        beanId: 1, date: DateTime(2026, 7, 27),
        acidity: 3, sweetness: 3, body: 3, bitterness: 3, overall: 4,
        degassingDays: const Value(8), createdAt: DateTime(2026, 7, 27)));
    expect((await db.select(db.tastings).get()).map((t) => t.degassingDays),
        containsAll([null, 8]));
  });
}
