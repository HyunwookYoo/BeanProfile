import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

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
}
