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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
