import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

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

  test('deleteBean removes the bean and cascades components + tastings, leaving other beans intact', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final a = await repo.createBean(sampleBlend());          // 2 components
    await repo.createTasting(a, sampleTasting());
    final b = await repo.createBean(sampleSingle(name: '남는 원두')); // control, must survive
    await repo.createTasting(b, sampleTasting());

    await repo.deleteBean(a);

    // A gone AND children actually cascaded — query child tables directly
    // (getBeanDetail short-circuits to null once the beans row is gone).
    expect(await repo.getBeanDetail(a), isNull);
    expect(await (db.select(db.originComponents)..where((c) => c.beanId.equals(a))).get(), isEmpty);
    expect(await (db.select(db.tastings)..where((t) => t.beanId.equals(a))).get(), isEmpty);

    // B untouched — proves the delete was scoped, not delete-all
    final bDetail = await repo.getBeanDetail(b);
    expect(bDetail, isNotNull);
    expect(bDetail!.components, isNotEmpty);
    expect(bDetail.tastings, hasLength(1));
  });
}
