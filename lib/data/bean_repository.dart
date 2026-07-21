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
            photoPath: Value(input.photoPath),
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

  Future<void> updateBean(int beanId, BeanInput input) {
    return db.transaction(() async {
      await (db.update(db.beans)..where((b) => b.id.equals(beanId))).write(
        BeansCompanion(
          name: Value(input.name),
          roaster: Value(input.roaster),
          type: Value(input.type),
          roastLevel: Value(input.roastLevel),
          roastDate: Value(input.roastDate),
          cupNotes: Value(input.cupNotes),
          memo: Value(input.memo),
          photoPath: Value(input.photoPath),
        ),
      );
      await (db.delete(db.originComponents)..where((c) => c.beanId.equals(beanId)))
          .go();
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
    });
  }

  Future<void> deleteBean(int beanId) {
    // FK ON DELETE CASCADE로 originComponents + tastings가 함께 삭제된다.
    return (db.delete(db.beans)..where((b) => b.id.equals(beanId))).go();
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

  Future<int> createTasting(int beanId, TastingInput t) {
    return db.into(db.tastings).insert(TastingsCompanion.insert(
          beanId: beanId,
          date: t.date,
          acidity: t.acidity,
          sweetness: t.sweetness,
          body: t.body,
          bitterness: t.bitterness,
          overall: t.overall,
          comment: Value(t.comment),
          createdAt: DateTime.now(),
        ));
  }

  Future<void> updateTasting(int tastingId, TastingInput t) {
    return (db.update(db.tastings)..where((x) => x.id.equals(tastingId)))
        .write(TastingsCompanion(
      date: Value(t.date),
      acidity: Value(t.acidity),
      sweetness: Value(t.sweetness),
      body: Value(t.body),
      bitterness: Value(t.bitterness),
      overall: Value(t.overall),
      comment: Value(t.comment),
    ));
  }

  Future<void> deleteTasting(int tastingId) {
    return (db.delete(db.tastings)..where((x) => x.id.equals(tastingId))).go();
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
    // beans/tastings/originComponents 어느 것이 바뀌어도 재방출되도록 셋을
    // 조인으로 등록한다(행은 무시, getBeanDetail로 재조회). watchBeanSummaries와
    // 같은 패턴.
    final trigger = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
      leftOuterJoin(db.originComponents,
          db.originComponents.beanId.equalsExp(db.beans.id)),
    ])..where(db.beans.id.equals(beanId));
    return trigger.watch().asyncMap((_) => getBeanDetail(beanId));
  }

  Future<TasteSnapshot> getTasteSnapshot() async {
    final beans = await db.select(db.beans).get();
    final components = await db.select(db.originComponents).get();
    final tastings = await db.select(db.tastings).get();
    return TasteSnapshot(
        beans: beans, components: components, tastings: tastings);
  }

  /// 3테이블을 전부 지우고 스냅샷으로 대체한다(백업 복원). 단일 트랜잭션이라
  /// 전부 성공 또는 전부 롤백. 행의 id를 그대로 삽입해 백업 값을 보존한다.
  Future<void> replaceAll(TasteSnapshot snap) {
    return db.transaction(() async {
      await db.delete(db.tastings).go();
      await db.delete(db.originComponents).go();
      await db.delete(db.beans).go();
      await db.batch((b) {
        b.insertAll(db.beans, snap.beans.map((e) => e.toCompanion(false)));
        b.insertAll(
            db.originComponents, snap.components.map((e) => e.toCompanion(false)));
        b.insertAll(db.tastings, snap.tastings.map((e) => e.toCompanion(false)));
      });
    });
  }

  Stream<TasteSnapshot> watchTasteSnapshot() {
    // 셋 중 무엇이 바뀌어도 재방출되도록 3테이블을 조인으로 등록한다.
    // 조인 결과 행은 쓰지 않고(중복 행이 나옴) 트리거로만 쓴 뒤
    // getTasteSnapshot으로 재조회한다 — watchBeanDetail과 같은 패턴.
    final trigger = db.select(db.beans).join([
      leftOuterJoin(db.tastings, db.tastings.beanId.equalsExp(db.beans.id)),
      leftOuterJoin(db.originComponents,
          db.originComponents.beanId.equalsExp(db.beans.id)),
    ]);
    return trigger.watch().asyncMap((_) => getTasteSnapshot());
  }
}
