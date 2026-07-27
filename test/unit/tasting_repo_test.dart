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
