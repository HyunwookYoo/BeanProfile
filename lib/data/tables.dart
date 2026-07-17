import 'package:drift/drift.dart';
import 'converters.dart';
import 'enums.dart';

class Beans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get roaster => text().withDefault(const Constant(''))();
  IntColumn get type => intEnum<BeanType>()();
  IntColumn get roastLevel => intEnum<RoastLevel>().nullable()();
  DateTimeColumn get roastDate => dateTime().nullable()();
  TextColumn get cupNotes =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get photoPath => text().nullable()();
  RealColumn get scaScore => real().nullable()();
  IntColumn get weightGrams => integer().nullable()();
  IntColumn get price => integer().nullable()();
  TextColumn get shop => text().nullable()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class OriginComponents extends Table {
  IntColumn get id => integer().autoIncrement()();
  // NOTE: drift_dev 2.31.0's `.references(Beans, #id, onDelete: ...)` resolver
  // requires the table argument to parse as an `Identifier` AST node, but the
  // analyzer resolved here (10.2.0) represents a bare class name used as a
  // value as a `TypeLiteral` instead, so the FK constraint is silently
  // dropped (confirmed via a resolved-AST probe). Using `customConstraint`
  // with a raw SQL fragment sidesteps that Dart-DSL resolver path entirely
  // and produces the identical schema (NOT NULL + FK cascade delete).
  IntColumn get beanId => integer()
      .customConstraint('NOT NULL REFERENCES beans(id) ON DELETE CASCADE')();
  TextColumn get country => text()();
  TextColumn get region => text().nullable()();
  TextColumn get farm => text().nullable()();
  TextColumn get variety => text().nullable()();
  IntColumn get process => intEnum<Process>().withDefault(const Constant(0))();
  TextColumn get altitude => text().nullable()();
  IntColumn get ratioPercent => integer().nullable()();
}

class Tastings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get beanId => integer()
      .customConstraint('NOT NULL REFERENCES beans(id) ON DELETE CASCADE')();
  DateTimeColumn get date => dateTime()();
  IntColumn get acidity => integer()();
  IntColumn get sweetness => integer()();
  IntColumn get body => integer()();
  IntColumn get bitterness => integer()();
  IntColumn get overall => integer()();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
