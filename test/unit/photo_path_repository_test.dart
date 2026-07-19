import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('photoPath가 create/update/watchBeanDetail을 왕복한다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);

    final id = await repo.createBean(BeanInput(
      name: '예가체프', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const [], memo: null,
      components: [const ComponentInput(country: 'Ethiopia')],
      photoPath: '/app/photos/a.jpg',
    ));

    var detail = await repo.getBeanDetail(id);
    expect(detail!.bean.photoPath, '/app/photos/a.jpg');

    await repo.updateBean(id, BeanInput(
      name: '예가체프', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const [], memo: null,
      components: [const ComponentInput(country: 'Ethiopia')],
      photoPath: '/app/photos/b.jpg',
    ));
    detail = await repo.getBeanDetail(id);
    expect(detail!.bean.photoPath, '/app/photos/b.jpg');
  });
}
