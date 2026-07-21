import 'package:async/async.dart';
import 'package:beanprofile/data/database.dart';
import 'package:drift/drift.dart';
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

  test('원두의 컵노트를 수정하면 재방출된다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    final queue = StreamQueue(repo.watchTasteSnapshot());
    final first = await queue.next; // 최초 방출 — 결정적
    expect(first.beans.single.cupNotes, ['블루베리', '자스민']);

    await (db.update(db.beans)..where((b) => b.id.equals(id))).write(
        const BeansCompanion(cupNotes: Value(['오렌지'])));

    final second = await queue.next; // watchTasteSnapshot이 재방출해야만 완료됨
    expect(second.beans.single.cupNotes, ['오렌지']);
    await queue.cancel();
  });
}
