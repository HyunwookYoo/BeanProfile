import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

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
