import 'package:async/async.dart';
import 'package:beanprofile/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('watchBeanDetail re-emits when a tasting is inserted', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    final queue = StreamQueue(repo.watchBeanDetail(id));
    final first = await queue.next; // initial emission — deterministic
    expect(first?.tastings, isEmpty);

    await db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: id, date: DateTime(2026, 7, 1),
          acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: 4,
          createdAt: DateTime(2026, 7, 1),
        ));

    final second = await queue.next; // only completes if watchBeanDetail RE-EMITS
    expect(second?.tastings, hasLength(1));
    await queue.cancel();
  });

  test('watchBeanDetail re-emits when an origin component is inserted', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle()); // 구성 1개로 시작

    final queue = StreamQueue(repo.watchBeanDetail(id));
    final first = await queue.next;
    expect(first?.components, hasLength(1));

    await db.into(db.originComponents).insert(
        OriginComponentsCompanion.insert(beanId: id, country: 'Kenya'));

    final second = await queue.next; // only completes if watchBeanDetail RE-EMITS
    expect(second?.components, hasLength(2));
    await queue.cancel();
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
