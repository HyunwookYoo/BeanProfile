import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('replaceAll이 기존을 지우고 스냅샷으로 교체한다(id 보존)', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);

    await repo.createBean(sampleSingle(name: '기존 원두')); // id 1 + 구성 1개

    final snap = TasteSnapshot(
      beans: [beanRow(id: 42, name: '복원된 원두', cupNotes: const ['자몽'])],
      components: [compRow(id: 7, beanId: 42, country: 'Kenya')],
      tastings: [tastingRow(id: 3, beanId: 42, overall: 5)],
    );

    await repo.replaceAll(snap);

    final after = await repo.getTasteSnapshot();
    expect(after.beans.map((b) => b.name), ['복원된 원두']);
    expect(after.beans.single.id, 42); // id 보존
    expect(after.components.single.country, 'Kenya');
    expect(after.tastings.single.overall, 5);
  });

  test('replaceAll에 빈 스냅샷을 주면 전부 비운다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleBlend());

    await repo.replaceAll(const TasteSnapshot(beans: [], components: [], tastings: []));

    final after = await repo.getTasteSnapshot();
    expect(after.beans, isEmpty);
    expect(after.components, isEmpty);
    expect(after.tastings, isEmpty);
  });
}
