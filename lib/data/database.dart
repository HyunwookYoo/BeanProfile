import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'converters.dart';
import 'enums.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Beans, OriginComponents, Tastings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'beanprofile'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // v2: 시음에 디개싱 일수(nullable) 추가. 기존 행은 null이 된다.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(tastings, tastings.degassingDays);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
