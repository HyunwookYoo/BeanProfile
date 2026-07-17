import 'package:drift/drift.dart';
import 'database.dart';
import 'models.dart';
export 'models.dart';

class BeanRepository {
  BeanRepository(this.db);
  final AppDatabase db;

  Future<int> createBean(BeanInput input) {
    return db.transaction(() async {
      final beanId = await db.into(db.beans).insert(BeansCompanion.insert(
            name: input.name,
            roaster: Value(input.roaster),
            type: input.type,
            roastLevel: Value(input.roastLevel),
            roastDate: Value(input.roastDate),
            cupNotes: Value(input.cupNotes),
            memo: Value(input.memo),
            createdAt: DateTime.now(),
          ));
      for (final c in input.components) {
        await db.into(db.originComponents).insert(
              OriginComponentsCompanion.insert(
                beanId: beanId,
                country: c.country,
                region: Value(c.region),
                farm: Value(c.farm),
                variety: Value(c.variety),
                process: Value(c.process),
                altitude: Value(c.altitude),
                ratioPercent: Value(c.ratioPercent),
              ),
            );
      }
      return beanId;
    });
  }

  Stream<List<BeanSummary>> watchBeanSummaries() {
    final avg = db.tastings.overall.avg();
    final cnt = db.tastings.id.count();
    final query = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
    ])
      ..addColumns([avg, cnt])
      ..groupBy([db.beans.id])
      ..orderBy([OrderingTerm.desc(db.beans.createdAt)]);

    return query.watch().asyncMap((rows) async {
      final result = <BeanSummary>[];
      for (final row in rows) {
        final bean = row.readTable(db.beans);
        final comps = await (db.select(db.originComponents)
              ..where((c) => c.beanId.equals(bean.id)))
            .get();
        result.add(BeanSummary(
          bean: bean,
          originLabel: _originLabel(comps),
          avgRating: row.read(avg),
          tastingCount: row.read(cnt) ?? 0,
        ));
      }
      return result;
    });
  }

  String? _originLabel(List<OriginComponent> comps) {
    if (comps.isEmpty) return null;
    final first = comps.first.country;
    return comps.length == 1 ? first : '$first 외 ${comps.length - 1}';
  }

  Future<BeanDetail?> getBeanDetail(int beanId) async {
    final bean = await (db.select(db.beans)..where((b) => b.id.equals(beanId)))
        .getSingleOrNull();
    if (bean == null) return null;
    final comps = await (db.select(db.originComponents)
          ..where((c) => c.beanId.equals(beanId)))
        .get();
    final tastings = await (db.select(db.tastings)
          ..where((t) => t.beanId.equals(beanId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return BeanDetail(bean: bean, components: comps, tastings: tastings);
  }

  Stream<BeanDetail?> watchBeanDetail(int beanId) {
    return (db.select(db.beans)..where((b) => b.id.equals(beanId)))
        .watchSingleOrNull()
        .asyncMap((_) => getBeanDetail(beanId));
  }
}
