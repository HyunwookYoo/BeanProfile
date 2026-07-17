import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BeanRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BeanRepository(db);
  });
  tearDown(() => db.close());

  BeanInput sampleSingle() => const BeanInput(
        name: '예가체프 코체레',
        roaster: '프릳츠',
        type: BeanType.singleOrigin,
        roastLevel: RoastLevel.lightMedium,
        roastDate: null,
        cupNotes: ['블루베리', '자스민'],
        memo: null,
        components: [ComponentInput(country: 'Ethiopia', process: Process.washed)],
      );

  test('createBean persists bean + components and detail reads them', () async {
    final id = await repo.createBean(sampleSingle());
    final detail = await repo.getBeanDetail(id);
    expect(detail, isNotNull);
    expect(detail!.bean.name, '예가체프 코체레');
    expect(detail.components, hasLength(1));
    expect(detail.components.first.country, 'Ethiopia');
    expect(detail.tastings, isEmpty);
  });

  test('summary shows null rating and 0 count when no tastings', () async {
    await repo.createBean(sampleSingle());
    final list = await repo.watchBeanSummaries().first;
    expect(list, hasLength(1));
    expect(list.first.avgRating, isNull);
    expect(list.first.tastingCount, 0);
    expect(list.first.originLabel, 'Ethiopia');
  });

  test('blend originLabel shows "외 N"', () async {
    await repo.createBean(const BeanInput(
      name: '하우스 블렌드', roaster: '테라로사', type: BeanType.blend,
      roastLevel: null, roastDate: null, cupNotes: [], memo: null,
      components: [
        ComponentInput(country: 'Brazil', ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', ratioPercent: 40),
      ],
    ));
    final list = await repo.watchBeanSummaries().first;
    expect(list.first.originLabel, 'Brazil 외 1');
  });
}
