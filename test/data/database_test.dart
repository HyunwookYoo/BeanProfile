import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('inserts and reads back a bean with cup notes', () async {
    final id = await db.into(db.beans).insert(BeansCompanion.insert(
          name: '예가체프 코체레',
          type: BeanType.singleOrigin,
          cupNotes: const Value(['블루베리', '자스민']),
          createdAt: DateTime(2026, 7, 14),
        ));
    final bean = await (db.select(db.beans)..where((b) => b.id.equals(id)))
        .getSingle();
    expect(bean.name, '예가체프 코체레');
    expect(bean.type, BeanType.singleOrigin);
    expect(bean.cupNotes, ['블루베리', '자스민']);
  });

  test('deleting a bean cascades to its components', () async {
    final beanId = await db.into(db.beans).insert(BeansCompanion.insert(
          name: '테스트', type: BeanType.blend, createdAt: DateTime(2026)));
    await db.into(db.originComponents).insert(
        OriginComponentsCompanion.insert(beanId: beanId, country: 'Ethiopia'));

    await (db.delete(db.beans)..where((b) => b.id.equals(beanId))).go();

    final comps = await db.select(db.originComponents).get();
    expect(comps, isEmpty);
  });
}
