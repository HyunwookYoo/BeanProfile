// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BeansTable extends Beans with TableInfo<$BeansTable, Bean> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roasterMeta = const VerificationMeta(
    'roaster',
  );
  @override
  late final GeneratedColumn<String> roaster = GeneratedColumn<String>(
    'roaster',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BeanType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<BeanType>($BeansTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<RoastLevel?, int> roastLevel =
      GeneratedColumn<int>(
        'roast_level',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<RoastLevel?>($BeansTable.$converterroastLeveln);
  static const VerificationMeta _roastDateMeta = const VerificationMeta(
    'roastDate',
  );
  @override
  late final GeneratedColumn<DateTime> roastDate = GeneratedColumn<DateTime>(
    'roast_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> cupNotes =
      GeneratedColumn<String>(
        'cup_notes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($BeansTable.$convertercupNotes);
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaScoreMeta = const VerificationMeta(
    'scaScore',
  );
  @override
  late final GeneratedColumn<double> scaScore = GeneratedColumn<double>(
    'sca_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<int> weightGrams = GeneratedColumn<int>(
    'weight_grams',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shopMeta = const VerificationMeta('shop');
  @override
  late final GeneratedColumn<String> shop = GeneratedColumn<String>(
    'shop',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    roaster,
    type,
    roastLevel,
    roastDate,
    cupNotes,
    photoPath,
    scaScore,
    weightGrams,
    price,
    shop,
    memo,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bean> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('roaster')) {
      context.handle(
        _roasterMeta,
        roaster.isAcceptableOrUnknown(data['roaster']!, _roasterMeta),
      );
    }
    if (data.containsKey('roast_date')) {
      context.handle(
        _roastDateMeta,
        roastDate.isAcceptableOrUnknown(data['roast_date']!, _roastDateMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('sca_score')) {
      context.handle(
        _scaScoreMeta,
        scaScore.isAcceptableOrUnknown(data['sca_score']!, _scaScoreMeta),
      );
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('shop')) {
      context.handle(
        _shopMeta,
        shop.isAcceptableOrUnknown(data['shop']!, _shopMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bean map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bean(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      roaster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roaster'],
      )!,
      type: $BeansTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      roastLevel: $BeansTable.$converterroastLeveln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}roast_level'],
        ),
      ),
      roastDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}roast_date'],
      ),
      cupNotes: $BeansTable.$convertercupNotes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cup_notes'],
        )!,
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      scaScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sca_score'],
      ),
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_grams'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      ),
      shop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BeansTable createAlias(String alias) {
    return $BeansTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BeanType, int, int> $convertertype =
      const EnumIndexConverter<BeanType>(BeanType.values);
  static JsonTypeConverter2<RoastLevel, int, int> $converterroastLevel =
      const EnumIndexConverter<RoastLevel>(RoastLevel.values);
  static JsonTypeConverter2<RoastLevel?, int?, int?> $converterroastLeveln =
      JsonTypeConverter2.asNullable($converterroastLevel);
  static TypeConverter<List<String>, String> $convertercupNotes =
      const StringListConverter();
}

class Bean extends DataClass implements Insertable<Bean> {
  final int id;
  final String name;
  final String roaster;
  final BeanType type;
  final RoastLevel? roastLevel;
  final DateTime? roastDate;
  final List<String> cupNotes;
  final String? photoPath;
  final double? scaScore;
  final int? weightGrams;
  final int? price;
  final String? shop;
  final String? memo;
  final DateTime createdAt;
  const Bean({
    required this.id,
    required this.name,
    required this.roaster,
    required this.type,
    this.roastLevel,
    this.roastDate,
    required this.cupNotes,
    this.photoPath,
    this.scaScore,
    this.weightGrams,
    this.price,
    this.shop,
    this.memo,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['roaster'] = Variable<String>(roaster);
    {
      map['type'] = Variable<int>($BeansTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || roastLevel != null) {
      map['roast_level'] = Variable<int>(
        $BeansTable.$converterroastLeveln.toSql(roastLevel),
      );
    }
    if (!nullToAbsent || roastDate != null) {
      map['roast_date'] = Variable<DateTime>(roastDate);
    }
    {
      map['cup_notes'] = Variable<String>(
        $BeansTable.$convertercupNotes.toSql(cupNotes),
      );
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || scaScore != null) {
      map['sca_score'] = Variable<double>(scaScore);
    }
    if (!nullToAbsent || weightGrams != null) {
      map['weight_grams'] = Variable<int>(weightGrams);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    if (!nullToAbsent || shop != null) {
      map['shop'] = Variable<String>(shop);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BeansCompanion toCompanion(bool nullToAbsent) {
    return BeansCompanion(
      id: Value(id),
      name: Value(name),
      roaster: Value(roaster),
      type: Value(type),
      roastLevel: roastLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(roastLevel),
      roastDate: roastDate == null && nullToAbsent
          ? const Value.absent()
          : Value(roastDate),
      cupNotes: Value(cupNotes),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      scaScore: scaScore == null && nullToAbsent
          ? const Value.absent()
          : Value(scaScore),
      weightGrams: weightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(weightGrams),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      shop: shop == null && nullToAbsent ? const Value.absent() : Value(shop),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory Bean.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bean(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      roaster: serializer.fromJson<String>(json['roaster']),
      type: $BeansTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      roastLevel: $BeansTable.$converterroastLeveln.fromJson(
        serializer.fromJson<int?>(json['roastLevel']),
      ),
      roastDate: serializer.fromJson<DateTime?>(json['roastDate']),
      cupNotes: serializer.fromJson<List<String>>(json['cupNotes']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      scaScore: serializer.fromJson<double?>(json['scaScore']),
      weightGrams: serializer.fromJson<int?>(json['weightGrams']),
      price: serializer.fromJson<int?>(json['price']),
      shop: serializer.fromJson<String?>(json['shop']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'roaster': serializer.toJson<String>(roaster),
      'type': serializer.toJson<int>($BeansTable.$convertertype.toJson(type)),
      'roastLevel': serializer.toJson<int?>(
        $BeansTable.$converterroastLeveln.toJson(roastLevel),
      ),
      'roastDate': serializer.toJson<DateTime?>(roastDate),
      'cupNotes': serializer.toJson<List<String>>(cupNotes),
      'photoPath': serializer.toJson<String?>(photoPath),
      'scaScore': serializer.toJson<double?>(scaScore),
      'weightGrams': serializer.toJson<int?>(weightGrams),
      'price': serializer.toJson<int?>(price),
      'shop': serializer.toJson<String?>(shop),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bean copyWith({
    int? id,
    String? name,
    String? roaster,
    BeanType? type,
    Value<RoastLevel?> roastLevel = const Value.absent(),
    Value<DateTime?> roastDate = const Value.absent(),
    List<String>? cupNotes,
    Value<String?> photoPath = const Value.absent(),
    Value<double?> scaScore = const Value.absent(),
    Value<int?> weightGrams = const Value.absent(),
    Value<int?> price = const Value.absent(),
    Value<String?> shop = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    DateTime? createdAt,
  }) => Bean(
    id: id ?? this.id,
    name: name ?? this.name,
    roaster: roaster ?? this.roaster,
    type: type ?? this.type,
    roastLevel: roastLevel.present ? roastLevel.value : this.roastLevel,
    roastDate: roastDate.present ? roastDate.value : this.roastDate,
    cupNotes: cupNotes ?? this.cupNotes,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    scaScore: scaScore.present ? scaScore.value : this.scaScore,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    price: price.present ? price.value : this.price,
    shop: shop.present ? shop.value : this.shop,
    memo: memo.present ? memo.value : this.memo,
    createdAt: createdAt ?? this.createdAt,
  );
  Bean copyWithCompanion(BeansCompanion data) {
    return Bean(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      roaster: data.roaster.present ? data.roaster.value : this.roaster,
      type: data.type.present ? data.type.value : this.type,
      roastLevel: data.roastLevel.present
          ? data.roastLevel.value
          : this.roastLevel,
      roastDate: data.roastDate.present ? data.roastDate.value : this.roastDate,
      cupNotes: data.cupNotes.present ? data.cupNotes.value : this.cupNotes,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      scaScore: data.scaScore.present ? data.scaScore.value : this.scaScore,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      price: data.price.present ? data.price.value : this.price,
      shop: data.shop.present ? data.shop.value : this.shop,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bean(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('roaster: $roaster, ')
          ..write('type: $type, ')
          ..write('roastLevel: $roastLevel, ')
          ..write('roastDate: $roastDate, ')
          ..write('cupNotes: $cupNotes, ')
          ..write('photoPath: $photoPath, ')
          ..write('scaScore: $scaScore, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('price: $price, ')
          ..write('shop: $shop, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    roaster,
    type,
    roastLevel,
    roastDate,
    cupNotes,
    photoPath,
    scaScore,
    weightGrams,
    price,
    shop,
    memo,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bean &&
          other.id == this.id &&
          other.name == this.name &&
          other.roaster == this.roaster &&
          other.type == this.type &&
          other.roastLevel == this.roastLevel &&
          other.roastDate == this.roastDate &&
          other.cupNotes == this.cupNotes &&
          other.photoPath == this.photoPath &&
          other.scaScore == this.scaScore &&
          other.weightGrams == this.weightGrams &&
          other.price == this.price &&
          other.shop == this.shop &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class BeansCompanion extends UpdateCompanion<Bean> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> roaster;
  final Value<BeanType> type;
  final Value<RoastLevel?> roastLevel;
  final Value<DateTime?> roastDate;
  final Value<List<String>> cupNotes;
  final Value<String?> photoPath;
  final Value<double?> scaScore;
  final Value<int?> weightGrams;
  final Value<int?> price;
  final Value<String?> shop;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const BeansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.roaster = const Value.absent(),
    this.type = const Value.absent(),
    this.roastLevel = const Value.absent(),
    this.roastDate = const Value.absent(),
    this.cupNotes = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.scaScore = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.price = const Value.absent(),
    this.shop = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BeansCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.roaster = const Value.absent(),
    required BeanType type,
    this.roastLevel = const Value.absent(),
    this.roastDate = const Value.absent(),
    this.cupNotes = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.scaScore = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.price = const Value.absent(),
    this.shop = const Value.absent(),
    this.memo = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<Bean> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? roaster,
    Expression<int>? type,
    Expression<int>? roastLevel,
    Expression<DateTime>? roastDate,
    Expression<String>? cupNotes,
    Expression<String>? photoPath,
    Expression<double>? scaScore,
    Expression<int>? weightGrams,
    Expression<int>? price,
    Expression<String>? shop,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (roaster != null) 'roaster': roaster,
      if (type != null) 'type': type,
      if (roastLevel != null) 'roast_level': roastLevel,
      if (roastDate != null) 'roast_date': roastDate,
      if (cupNotes != null) 'cup_notes': cupNotes,
      if (photoPath != null) 'photo_path': photoPath,
      if (scaScore != null) 'sca_score': scaScore,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (price != null) 'price': price,
      if (shop != null) 'shop': shop,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BeansCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? roaster,
    Value<BeanType>? type,
    Value<RoastLevel?>? roastLevel,
    Value<DateTime?>? roastDate,
    Value<List<String>>? cupNotes,
    Value<String?>? photoPath,
    Value<double?>? scaScore,
    Value<int?>? weightGrams,
    Value<int?>? price,
    Value<String?>? shop,
    Value<String?>? memo,
    Value<DateTime>? createdAt,
  }) {
    return BeansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      roaster: roaster ?? this.roaster,
      type: type ?? this.type,
      roastLevel: roastLevel ?? this.roastLevel,
      roastDate: roastDate ?? this.roastDate,
      cupNotes: cupNotes ?? this.cupNotes,
      photoPath: photoPath ?? this.photoPath,
      scaScore: scaScore ?? this.scaScore,
      weightGrams: weightGrams ?? this.weightGrams,
      price: price ?? this.price,
      shop: shop ?? this.shop,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roaster.present) {
      map['roaster'] = Variable<String>(roaster.value);
    }
    if (type.present) {
      map['type'] = Variable<int>($BeansTable.$convertertype.toSql(type.value));
    }
    if (roastLevel.present) {
      map['roast_level'] = Variable<int>(
        $BeansTable.$converterroastLeveln.toSql(roastLevel.value),
      );
    }
    if (roastDate.present) {
      map['roast_date'] = Variable<DateTime>(roastDate.value);
    }
    if (cupNotes.present) {
      map['cup_notes'] = Variable<String>(
        $BeansTable.$convertercupNotes.toSql(cupNotes.value),
      );
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (scaScore.present) {
      map['sca_score'] = Variable<double>(scaScore.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<int>(weightGrams.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (shop.present) {
      map['shop'] = Variable<String>(shop.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('roaster: $roaster, ')
          ..write('type: $type, ')
          ..write('roastLevel: $roastLevel, ')
          ..write('roastDate: $roastDate, ')
          ..write('cupNotes: $cupNotes, ')
          ..write('photoPath: $photoPath, ')
          ..write('scaScore: $scaScore, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('price: $price, ')
          ..write('shop: $shop, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OriginComponentsTable extends OriginComponents
    with TableInfo<$OriginComponentsTable, OriginComponent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OriginComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _beanIdMeta = const VerificationMeta('beanId');
  @override
  late final GeneratedColumn<int> beanId = GeneratedColumn<int>(
    'bean_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES beans(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _farmMeta = const VerificationMeta('farm');
  @override
  late final GeneratedColumn<String> farm = GeneratedColumn<String>(
    'farm',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _varietyMeta = const VerificationMeta(
    'variety',
  );
  @override
  late final GeneratedColumn<String> variety = GeneratedColumn<String>(
    'variety',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Process, int> process =
      GeneratedColumn<int>(
        'process',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<Process>($OriginComponentsTable.$converterprocess);
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<String> altitude = GeneratedColumn<String>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratioPercentMeta = const VerificationMeta(
    'ratioPercent',
  );
  @override
  late final GeneratedColumn<int> ratioPercent = GeneratedColumn<int>(
    'ratio_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    beanId,
    country,
    region,
    farm,
    variety,
    process,
    altitude,
    ratioPercent,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'origin_components';
  @override
  VerificationContext validateIntegrity(
    Insertable<OriginComponent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bean_id')) {
      context.handle(
        _beanIdMeta,
        beanId.isAcceptableOrUnknown(data['bean_id']!, _beanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_beanIdMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    } else if (isInserting) {
      context.missing(_countryMeta);
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('farm')) {
      context.handle(
        _farmMeta,
        farm.isAcceptableOrUnknown(data['farm']!, _farmMeta),
      );
    }
    if (data.containsKey('variety')) {
      context.handle(
        _varietyMeta,
        variety.isAcceptableOrUnknown(data['variety']!, _varietyMeta),
      );
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('ratio_percent')) {
      context.handle(
        _ratioPercentMeta,
        ratioPercent.isAcceptableOrUnknown(
          data['ratio_percent']!,
          _ratioPercentMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OriginComponent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OriginComponent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      beanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bean_id'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      )!,
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      farm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}farm'],
      ),
      variety: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variety'],
      ),
      process: $OriginComponentsTable.$converterprocess.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}process'],
        )!,
      ),
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}altitude'],
      ),
      ratioPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ratio_percent'],
      ),
    );
  }

  @override
  $OriginComponentsTable createAlias(String alias) {
    return $OriginComponentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Process, int, int> $converterprocess =
      const EnumIndexConverter<Process>(Process.values);
}

class OriginComponent extends DataClass implements Insertable<OriginComponent> {
  final int id;
  final int beanId;
  final String country;
  final String? region;
  final String? farm;
  final String? variety;
  final Process process;
  final String? altitude;
  final int? ratioPercent;
  const OriginComponent({
    required this.id,
    required this.beanId,
    required this.country,
    this.region,
    this.farm,
    this.variety,
    required this.process,
    this.altitude,
    this.ratioPercent,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bean_id'] = Variable<int>(beanId);
    map['country'] = Variable<String>(country);
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || farm != null) {
      map['farm'] = Variable<String>(farm);
    }
    if (!nullToAbsent || variety != null) {
      map['variety'] = Variable<String>(variety);
    }
    {
      map['process'] = Variable<int>(
        $OriginComponentsTable.$converterprocess.toSql(process),
      );
    }
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<String>(altitude);
    }
    if (!nullToAbsent || ratioPercent != null) {
      map['ratio_percent'] = Variable<int>(ratioPercent);
    }
    return map;
  }

  OriginComponentsCompanion toCompanion(bool nullToAbsent) {
    return OriginComponentsCompanion(
      id: Value(id),
      beanId: Value(beanId),
      country: Value(country),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      farm: farm == null && nullToAbsent ? const Value.absent() : Value(farm),
      variety: variety == null && nullToAbsent
          ? const Value.absent()
          : Value(variety),
      process: Value(process),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      ratioPercent: ratioPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(ratioPercent),
    );
  }

  factory OriginComponent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OriginComponent(
      id: serializer.fromJson<int>(json['id']),
      beanId: serializer.fromJson<int>(json['beanId']),
      country: serializer.fromJson<String>(json['country']),
      region: serializer.fromJson<String?>(json['region']),
      farm: serializer.fromJson<String?>(json['farm']),
      variety: serializer.fromJson<String?>(json['variety']),
      process: $OriginComponentsTable.$converterprocess.fromJson(
        serializer.fromJson<int>(json['process']),
      ),
      altitude: serializer.fromJson<String?>(json['altitude']),
      ratioPercent: serializer.fromJson<int?>(json['ratioPercent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'beanId': serializer.toJson<int>(beanId),
      'country': serializer.toJson<String>(country),
      'region': serializer.toJson<String?>(region),
      'farm': serializer.toJson<String?>(farm),
      'variety': serializer.toJson<String?>(variety),
      'process': serializer.toJson<int>(
        $OriginComponentsTable.$converterprocess.toJson(process),
      ),
      'altitude': serializer.toJson<String?>(altitude),
      'ratioPercent': serializer.toJson<int?>(ratioPercent),
    };
  }

  OriginComponent copyWith({
    int? id,
    int? beanId,
    String? country,
    Value<String?> region = const Value.absent(),
    Value<String?> farm = const Value.absent(),
    Value<String?> variety = const Value.absent(),
    Process? process,
    Value<String?> altitude = const Value.absent(),
    Value<int?> ratioPercent = const Value.absent(),
  }) => OriginComponent(
    id: id ?? this.id,
    beanId: beanId ?? this.beanId,
    country: country ?? this.country,
    region: region.present ? region.value : this.region,
    farm: farm.present ? farm.value : this.farm,
    variety: variety.present ? variety.value : this.variety,
    process: process ?? this.process,
    altitude: altitude.present ? altitude.value : this.altitude,
    ratioPercent: ratioPercent.present ? ratioPercent.value : this.ratioPercent,
  );
  OriginComponent copyWithCompanion(OriginComponentsCompanion data) {
    return OriginComponent(
      id: data.id.present ? data.id.value : this.id,
      beanId: data.beanId.present ? data.beanId.value : this.beanId,
      country: data.country.present ? data.country.value : this.country,
      region: data.region.present ? data.region.value : this.region,
      farm: data.farm.present ? data.farm.value : this.farm,
      variety: data.variety.present ? data.variety.value : this.variety,
      process: data.process.present ? data.process.value : this.process,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      ratioPercent: data.ratioPercent.present
          ? data.ratioPercent.value
          : this.ratioPercent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OriginComponent(')
          ..write('id: $id, ')
          ..write('beanId: $beanId, ')
          ..write('country: $country, ')
          ..write('region: $region, ')
          ..write('farm: $farm, ')
          ..write('variety: $variety, ')
          ..write('process: $process, ')
          ..write('altitude: $altitude, ')
          ..write('ratioPercent: $ratioPercent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    beanId,
    country,
    region,
    farm,
    variety,
    process,
    altitude,
    ratioPercent,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OriginComponent &&
          other.id == this.id &&
          other.beanId == this.beanId &&
          other.country == this.country &&
          other.region == this.region &&
          other.farm == this.farm &&
          other.variety == this.variety &&
          other.process == this.process &&
          other.altitude == this.altitude &&
          other.ratioPercent == this.ratioPercent);
}

class OriginComponentsCompanion extends UpdateCompanion<OriginComponent> {
  final Value<int> id;
  final Value<int> beanId;
  final Value<String> country;
  final Value<String?> region;
  final Value<String?> farm;
  final Value<String?> variety;
  final Value<Process> process;
  final Value<String?> altitude;
  final Value<int?> ratioPercent;
  const OriginComponentsCompanion({
    this.id = const Value.absent(),
    this.beanId = const Value.absent(),
    this.country = const Value.absent(),
    this.region = const Value.absent(),
    this.farm = const Value.absent(),
    this.variety = const Value.absent(),
    this.process = const Value.absent(),
    this.altitude = const Value.absent(),
    this.ratioPercent = const Value.absent(),
  });
  OriginComponentsCompanion.insert({
    this.id = const Value.absent(),
    required int beanId,
    required String country,
    this.region = const Value.absent(),
    this.farm = const Value.absent(),
    this.variety = const Value.absent(),
    this.process = const Value.absent(),
    this.altitude = const Value.absent(),
    this.ratioPercent = const Value.absent(),
  }) : beanId = Value(beanId),
       country = Value(country);
  static Insertable<OriginComponent> custom({
    Expression<int>? id,
    Expression<int>? beanId,
    Expression<String>? country,
    Expression<String>? region,
    Expression<String>? farm,
    Expression<String>? variety,
    Expression<int>? process,
    Expression<String>? altitude,
    Expression<int>? ratioPercent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (beanId != null) 'bean_id': beanId,
      if (country != null) 'country': country,
      if (region != null) 'region': region,
      if (farm != null) 'farm': farm,
      if (variety != null) 'variety': variety,
      if (process != null) 'process': process,
      if (altitude != null) 'altitude': altitude,
      if (ratioPercent != null) 'ratio_percent': ratioPercent,
    });
  }

  OriginComponentsCompanion copyWith({
    Value<int>? id,
    Value<int>? beanId,
    Value<String>? country,
    Value<String?>? region,
    Value<String?>? farm,
    Value<String?>? variety,
    Value<Process>? process,
    Value<String?>? altitude,
    Value<int?>? ratioPercent,
  }) {
    return OriginComponentsCompanion(
      id: id ?? this.id,
      beanId: beanId ?? this.beanId,
      country: country ?? this.country,
      region: region ?? this.region,
      farm: farm ?? this.farm,
      variety: variety ?? this.variety,
      process: process ?? this.process,
      altitude: altitude ?? this.altitude,
      ratioPercent: ratioPercent ?? this.ratioPercent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (beanId.present) {
      map['bean_id'] = Variable<int>(beanId.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (farm.present) {
      map['farm'] = Variable<String>(farm.value);
    }
    if (variety.present) {
      map['variety'] = Variable<String>(variety.value);
    }
    if (process.present) {
      map['process'] = Variable<int>(
        $OriginComponentsTable.$converterprocess.toSql(process.value),
      );
    }
    if (altitude.present) {
      map['altitude'] = Variable<String>(altitude.value);
    }
    if (ratioPercent.present) {
      map['ratio_percent'] = Variable<int>(ratioPercent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OriginComponentsCompanion(')
          ..write('id: $id, ')
          ..write('beanId: $beanId, ')
          ..write('country: $country, ')
          ..write('region: $region, ')
          ..write('farm: $farm, ')
          ..write('variety: $variety, ')
          ..write('process: $process, ')
          ..write('altitude: $altitude, ')
          ..write('ratioPercent: $ratioPercent')
          ..write(')'))
        .toString();
  }
}

class $TastingsTable extends Tastings with TableInfo<$TastingsTable, Tasting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TastingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _beanIdMeta = const VerificationMeta('beanId');
  @override
  late final GeneratedColumn<int> beanId = GeneratedColumn<int>(
    'bean_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES beans(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acidityMeta = const VerificationMeta(
    'acidity',
  );
  @override
  late final GeneratedColumn<int> acidity = GeneratedColumn<int>(
    'acidity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sweetnessMeta = const VerificationMeta(
    'sweetness',
  );
  @override
  late final GeneratedColumn<int> sweetness = GeneratedColumn<int>(
    'sweetness',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<int> body = GeneratedColumn<int>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bitternessMeta = const VerificationMeta(
    'bitterness',
  );
  @override
  late final GeneratedColumn<int> bitterness = GeneratedColumn<int>(
    'bitterness',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overallMeta = const VerificationMeta(
    'overall',
  );
  @override
  late final GeneratedColumn<int> overall = GeneratedColumn<int>(
    'overall',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    beanId,
    date,
    acidity,
    sweetness,
    body,
    bitterness,
    overall,
    comment,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tastings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tasting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bean_id')) {
      context.handle(
        _beanIdMeta,
        beanId.isAcceptableOrUnknown(data['bean_id']!, _beanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_beanIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('acidity')) {
      context.handle(
        _acidityMeta,
        acidity.isAcceptableOrUnknown(data['acidity']!, _acidityMeta),
      );
    } else if (isInserting) {
      context.missing(_acidityMeta);
    }
    if (data.containsKey('sweetness')) {
      context.handle(
        _sweetnessMeta,
        sweetness.isAcceptableOrUnknown(data['sweetness']!, _sweetnessMeta),
      );
    } else if (isInserting) {
      context.missing(_sweetnessMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('bitterness')) {
      context.handle(
        _bitternessMeta,
        bitterness.isAcceptableOrUnknown(data['bitterness']!, _bitternessMeta),
      );
    } else if (isInserting) {
      context.missing(_bitternessMeta);
    }
    if (data.containsKey('overall')) {
      context.handle(
        _overallMeta,
        overall.isAcceptableOrUnknown(data['overall']!, _overallMeta),
      );
    } else if (isInserting) {
      context.missing(_overallMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tasting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tasting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      beanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bean_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      acidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acidity'],
      )!,
      sweetness: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sweetness'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}body'],
      )!,
      bitterness: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitterness'],
      )!,
      overall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overall'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TastingsTable createAlias(String alias) {
    return $TastingsTable(attachedDatabase, alias);
  }
}

class Tasting extends DataClass implements Insertable<Tasting> {
  final int id;
  final int beanId;
  final DateTime date;
  final int acidity;
  final int sweetness;
  final int body;
  final int bitterness;
  final int overall;
  final String? comment;
  final DateTime createdAt;
  const Tasting({
    required this.id,
    required this.beanId,
    required this.date,
    required this.acidity,
    required this.sweetness,
    required this.body,
    required this.bitterness,
    required this.overall,
    this.comment,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bean_id'] = Variable<int>(beanId);
    map['date'] = Variable<DateTime>(date);
    map['acidity'] = Variable<int>(acidity);
    map['sweetness'] = Variable<int>(sweetness);
    map['body'] = Variable<int>(body);
    map['bitterness'] = Variable<int>(bitterness);
    map['overall'] = Variable<int>(overall);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TastingsCompanion toCompanion(bool nullToAbsent) {
    return TastingsCompanion(
      id: Value(id),
      beanId: Value(beanId),
      date: Value(date),
      acidity: Value(acidity),
      sweetness: Value(sweetness),
      body: Value(body),
      bitterness: Value(bitterness),
      overall: Value(overall),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      createdAt: Value(createdAt),
    );
  }

  factory Tasting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tasting(
      id: serializer.fromJson<int>(json['id']),
      beanId: serializer.fromJson<int>(json['beanId']),
      date: serializer.fromJson<DateTime>(json['date']),
      acidity: serializer.fromJson<int>(json['acidity']),
      sweetness: serializer.fromJson<int>(json['sweetness']),
      body: serializer.fromJson<int>(json['body']),
      bitterness: serializer.fromJson<int>(json['bitterness']),
      overall: serializer.fromJson<int>(json['overall']),
      comment: serializer.fromJson<String?>(json['comment']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'beanId': serializer.toJson<int>(beanId),
      'date': serializer.toJson<DateTime>(date),
      'acidity': serializer.toJson<int>(acidity),
      'sweetness': serializer.toJson<int>(sweetness),
      'body': serializer.toJson<int>(body),
      'bitterness': serializer.toJson<int>(bitterness),
      'overall': serializer.toJson<int>(overall),
      'comment': serializer.toJson<String?>(comment),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tasting copyWith({
    int? id,
    int? beanId,
    DateTime? date,
    int? acidity,
    int? sweetness,
    int? body,
    int? bitterness,
    int? overall,
    Value<String?> comment = const Value.absent(),
    DateTime? createdAt,
  }) => Tasting(
    id: id ?? this.id,
    beanId: beanId ?? this.beanId,
    date: date ?? this.date,
    acidity: acidity ?? this.acidity,
    sweetness: sweetness ?? this.sweetness,
    body: body ?? this.body,
    bitterness: bitterness ?? this.bitterness,
    overall: overall ?? this.overall,
    comment: comment.present ? comment.value : this.comment,
    createdAt: createdAt ?? this.createdAt,
  );
  Tasting copyWithCompanion(TastingsCompanion data) {
    return Tasting(
      id: data.id.present ? data.id.value : this.id,
      beanId: data.beanId.present ? data.beanId.value : this.beanId,
      date: data.date.present ? data.date.value : this.date,
      acidity: data.acidity.present ? data.acidity.value : this.acidity,
      sweetness: data.sweetness.present ? data.sweetness.value : this.sweetness,
      body: data.body.present ? data.body.value : this.body,
      bitterness: data.bitterness.present
          ? data.bitterness.value
          : this.bitterness,
      overall: data.overall.present ? data.overall.value : this.overall,
      comment: data.comment.present ? data.comment.value : this.comment,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tasting(')
          ..write('id: $id, ')
          ..write('beanId: $beanId, ')
          ..write('date: $date, ')
          ..write('acidity: $acidity, ')
          ..write('sweetness: $sweetness, ')
          ..write('body: $body, ')
          ..write('bitterness: $bitterness, ')
          ..write('overall: $overall, ')
          ..write('comment: $comment, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    beanId,
    date,
    acidity,
    sweetness,
    body,
    bitterness,
    overall,
    comment,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tasting &&
          other.id == this.id &&
          other.beanId == this.beanId &&
          other.date == this.date &&
          other.acidity == this.acidity &&
          other.sweetness == this.sweetness &&
          other.body == this.body &&
          other.bitterness == this.bitterness &&
          other.overall == this.overall &&
          other.comment == this.comment &&
          other.createdAt == this.createdAt);
}

class TastingsCompanion extends UpdateCompanion<Tasting> {
  final Value<int> id;
  final Value<int> beanId;
  final Value<DateTime> date;
  final Value<int> acidity;
  final Value<int> sweetness;
  final Value<int> body;
  final Value<int> bitterness;
  final Value<int> overall;
  final Value<String?> comment;
  final Value<DateTime> createdAt;
  const TastingsCompanion({
    this.id = const Value.absent(),
    this.beanId = const Value.absent(),
    this.date = const Value.absent(),
    this.acidity = const Value.absent(),
    this.sweetness = const Value.absent(),
    this.body = const Value.absent(),
    this.bitterness = const Value.absent(),
    this.overall = const Value.absent(),
    this.comment = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TastingsCompanion.insert({
    this.id = const Value.absent(),
    required int beanId,
    required DateTime date,
    required int acidity,
    required int sweetness,
    required int body,
    required int bitterness,
    required int overall,
    this.comment = const Value.absent(),
    required DateTime createdAt,
  }) : beanId = Value(beanId),
       date = Value(date),
       acidity = Value(acidity),
       sweetness = Value(sweetness),
       body = Value(body),
       bitterness = Value(bitterness),
       overall = Value(overall),
       createdAt = Value(createdAt);
  static Insertable<Tasting> custom({
    Expression<int>? id,
    Expression<int>? beanId,
    Expression<DateTime>? date,
    Expression<int>? acidity,
    Expression<int>? sweetness,
    Expression<int>? body,
    Expression<int>? bitterness,
    Expression<int>? overall,
    Expression<String>? comment,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (beanId != null) 'bean_id': beanId,
      if (date != null) 'date': date,
      if (acidity != null) 'acidity': acidity,
      if (sweetness != null) 'sweetness': sweetness,
      if (body != null) 'body': body,
      if (bitterness != null) 'bitterness': bitterness,
      if (overall != null) 'overall': overall,
      if (comment != null) 'comment': comment,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TastingsCompanion copyWith({
    Value<int>? id,
    Value<int>? beanId,
    Value<DateTime>? date,
    Value<int>? acidity,
    Value<int>? sweetness,
    Value<int>? body,
    Value<int>? bitterness,
    Value<int>? overall,
    Value<String?>? comment,
    Value<DateTime>? createdAt,
  }) {
    return TastingsCompanion(
      id: id ?? this.id,
      beanId: beanId ?? this.beanId,
      date: date ?? this.date,
      acidity: acidity ?? this.acidity,
      sweetness: sweetness ?? this.sweetness,
      body: body ?? this.body,
      bitterness: bitterness ?? this.bitterness,
      overall: overall ?? this.overall,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (beanId.present) {
      map['bean_id'] = Variable<int>(beanId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (acidity.present) {
      map['acidity'] = Variable<int>(acidity.value);
    }
    if (sweetness.present) {
      map['sweetness'] = Variable<int>(sweetness.value);
    }
    if (body.present) {
      map['body'] = Variable<int>(body.value);
    }
    if (bitterness.present) {
      map['bitterness'] = Variable<int>(bitterness.value);
    }
    if (overall.present) {
      map['overall'] = Variable<int>(overall.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TastingsCompanion(')
          ..write('id: $id, ')
          ..write('beanId: $beanId, ')
          ..write('date: $date, ')
          ..write('acidity: $acidity, ')
          ..write('sweetness: $sweetness, ')
          ..write('body: $body, ')
          ..write('bitterness: $bitterness, ')
          ..write('overall: $overall, ')
          ..write('comment: $comment, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BeansTable beans = $BeansTable(this);
  late final $OriginComponentsTable originComponents = $OriginComponentsTable(
    this,
  );
  late final $TastingsTable tastings = $TastingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    beans,
    originComponents,
    tastings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'beans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('origin_components', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'beans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tastings', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BeansTableCreateCompanionBuilder =
    BeansCompanion Function({
      Value<int> id,
      required String name,
      Value<String> roaster,
      required BeanType type,
      Value<RoastLevel?> roastLevel,
      Value<DateTime?> roastDate,
      Value<List<String>> cupNotes,
      Value<String?> photoPath,
      Value<double?> scaScore,
      Value<int?> weightGrams,
      Value<int?> price,
      Value<String?> shop,
      Value<String?> memo,
      required DateTime createdAt,
    });
typedef $$BeansTableUpdateCompanionBuilder =
    BeansCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> roaster,
      Value<BeanType> type,
      Value<RoastLevel?> roastLevel,
      Value<DateTime?> roastDate,
      Value<List<String>> cupNotes,
      Value<String?> photoPath,
      Value<double?> scaScore,
      Value<int?> weightGrams,
      Value<int?> price,
      Value<String?> shop,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });

final class $$BeansTableReferences
    extends BaseReferences<_$AppDatabase, $BeansTable, Bean> {
  $$BeansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OriginComponentsTable, List<OriginComponent>>
  _originComponentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.originComponents,
    aliasName: $_aliasNameGenerator(db.beans.id, db.originComponents.beanId),
  );

  $$OriginComponentsTableProcessedTableManager get originComponentsRefs {
    final manager = $$OriginComponentsTableTableManager(
      $_db,
      $_db.originComponents,
    ).filter((f) => f.beanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _originComponentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TastingsTable, List<Tasting>> _tastingsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tastings,
    aliasName: $_aliasNameGenerator(db.beans.id, db.tastings.beanId),
  );

  $$TastingsTableProcessedTableManager get tastingsRefs {
    final manager = $$TastingsTableTableManager(
      $_db,
      $_db.tastings,
    ).filter((f) => f.beanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tastingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BeansTableFilterComposer extends Composer<_$AppDatabase, $BeansTable> {
  $$BeansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roaster => $composableBuilder(
    column: $table.roaster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BeanType, BeanType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<RoastLevel?, RoastLevel, int> get roastLevel =>
      $composableBuilder(
        column: $table.roastLevel,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get roastDate => $composableBuilder(
    column: $table.roastDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get cupNotes => $composableBuilder(
    column: $table.cupNotes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scaScore => $composableBuilder(
    column: $table.scaScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> originComponentsRefs(
    Expression<bool> Function($$OriginComponentsTableFilterComposer f) f,
  ) {
    final $$OriginComponentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.originComponents,
      getReferencedColumn: (t) => t.beanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OriginComponentsTableFilterComposer(
            $db: $db,
            $table: $db.originComponents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tastingsRefs(
    Expression<bool> Function($$TastingsTableFilterComposer f) f,
  ) {
    final $$TastingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tastings,
      getReferencedColumn: (t) => t.beanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TastingsTableFilterComposer(
            $db: $db,
            $table: $db.tastings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BeansTableOrderingComposer
    extends Composer<_$AppDatabase, $BeansTable> {
  $$BeansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roaster => $composableBuilder(
    column: $table.roaster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roastLevel => $composableBuilder(
    column: $table.roastLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get roastDate => $composableBuilder(
    column: $table.roastDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cupNotes => $composableBuilder(
    column: $table.cupNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scaScore => $composableBuilder(
    column: $table.scaScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BeansTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeansTable> {
  $$BeansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get roaster =>
      $composableBuilder(column: $table.roaster, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BeanType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RoastLevel?, int> get roastLevel =>
      $composableBuilder(
        column: $table.roastLevel,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get roastDate =>
      $composableBuilder(column: $table.roastDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get cupNotes =>
      $composableBuilder(column: $table.cupNotes, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<double> get scaScore =>
      $composableBuilder(column: $table.scaScore, builder: (column) => column);

  GeneratedColumn<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> originComponentsRefs<T extends Object>(
    Expression<T> Function($$OriginComponentsTableAnnotationComposer a) f,
  ) {
    final $$OriginComponentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.originComponents,
      getReferencedColumn: (t) => t.beanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OriginComponentsTableAnnotationComposer(
            $db: $db,
            $table: $db.originComponents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tastingsRefs<T extends Object>(
    Expression<T> Function($$TastingsTableAnnotationComposer a) f,
  ) {
    final $$TastingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tastings,
      getReferencedColumn: (t) => t.beanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TastingsTableAnnotationComposer(
            $db: $db,
            $table: $db.tastings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BeansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BeansTable,
          Bean,
          $$BeansTableFilterComposer,
          $$BeansTableOrderingComposer,
          $$BeansTableAnnotationComposer,
          $$BeansTableCreateCompanionBuilder,
          $$BeansTableUpdateCompanionBuilder,
          (Bean, $$BeansTableReferences),
          Bean,
          PrefetchHooks Function({bool originComponentsRefs, bool tastingsRefs})
        > {
  $$BeansTableTableManager(_$AppDatabase db, $BeansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> roaster = const Value.absent(),
                Value<BeanType> type = const Value.absent(),
                Value<RoastLevel?> roastLevel = const Value.absent(),
                Value<DateTime?> roastDate = const Value.absent(),
                Value<List<String>> cupNotes = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<double?> scaScore = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String?> shop = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BeansCompanion(
                id: id,
                name: name,
                roaster: roaster,
                type: type,
                roastLevel: roastLevel,
                roastDate: roastDate,
                cupNotes: cupNotes,
                photoPath: photoPath,
                scaScore: scaScore,
                weightGrams: weightGrams,
                price: price,
                shop: shop,
                memo: memo,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> roaster = const Value.absent(),
                required BeanType type,
                Value<RoastLevel?> roastLevel = const Value.absent(),
                Value<DateTime?> roastDate = const Value.absent(),
                Value<List<String>> cupNotes = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<double?> scaScore = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String?> shop = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                required DateTime createdAt,
              }) => BeansCompanion.insert(
                id: id,
                name: name,
                roaster: roaster,
                type: type,
                roastLevel: roastLevel,
                roastDate: roastDate,
                cupNotes: cupNotes,
                photoPath: photoPath,
                scaScore: scaScore,
                weightGrams: weightGrams,
                price: price,
                shop: shop,
                memo: memo,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BeansTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({originComponentsRefs = false, tastingsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (originComponentsRefs) db.originComponents,
                    if (tastingsRefs) db.tastings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (originComponentsRefs)
                        await $_getPrefetchedData<
                          Bean,
                          $BeansTable,
                          OriginComponent
                        >(
                          currentTable: table,
                          referencedTable: $$BeansTableReferences
                              ._originComponentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BeansTableReferences(
                                db,
                                table,
                                p0,
                              ).originComponentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.beanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tastingsRefs)
                        await $_getPrefetchedData<Bean, $BeansTable, Tasting>(
                          currentTable: table,
                          referencedTable: $$BeansTableReferences
                              ._tastingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BeansTableReferences(
                                db,
                                table,
                                p0,
                              ).tastingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.beanId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BeansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BeansTable,
      Bean,
      $$BeansTableFilterComposer,
      $$BeansTableOrderingComposer,
      $$BeansTableAnnotationComposer,
      $$BeansTableCreateCompanionBuilder,
      $$BeansTableUpdateCompanionBuilder,
      (Bean, $$BeansTableReferences),
      Bean,
      PrefetchHooks Function({bool originComponentsRefs, bool tastingsRefs})
    >;
typedef $$OriginComponentsTableCreateCompanionBuilder =
    OriginComponentsCompanion Function({
      Value<int> id,
      required int beanId,
      required String country,
      Value<String?> region,
      Value<String?> farm,
      Value<String?> variety,
      Value<Process> process,
      Value<String?> altitude,
      Value<int?> ratioPercent,
    });
typedef $$OriginComponentsTableUpdateCompanionBuilder =
    OriginComponentsCompanion Function({
      Value<int> id,
      Value<int> beanId,
      Value<String> country,
      Value<String?> region,
      Value<String?> farm,
      Value<String?> variety,
      Value<Process> process,
      Value<String?> altitude,
      Value<int?> ratioPercent,
    });

final class $$OriginComponentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $OriginComponentsTable, OriginComponent> {
  $$OriginComponentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BeansTable _beanIdTable(_$AppDatabase db) => db.beans.createAlias(
    $_aliasNameGenerator(db.originComponents.beanId, db.beans.id),
  );

  $$BeansTableProcessedTableManager get beanId {
    final $_column = $_itemColumn<int>('bean_id')!;

    final manager = $$BeansTableTableManager(
      $_db,
      $_db.beans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_beanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OriginComponentsTableFilterComposer
    extends Composer<_$AppDatabase, $OriginComponentsTable> {
  $$OriginComponentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get farm => $composableBuilder(
    column: $table.farm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variety => $composableBuilder(
    column: $table.variety,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Process, Process, int> get process =>
      $composableBuilder(
        column: $table.process,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratioPercent => $composableBuilder(
    column: $table.ratioPercent,
    builder: (column) => ColumnFilters(column),
  );

  $$BeansTableFilterComposer get beanId {
    final $$BeansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableFilterComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OriginComponentsTableOrderingComposer
    extends Composer<_$AppDatabase, $OriginComponentsTable> {
  $$OriginComponentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get farm => $composableBuilder(
    column: $table.farm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variety => $composableBuilder(
    column: $table.variety,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get process => $composableBuilder(
    column: $table.process,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratioPercent => $composableBuilder(
    column: $table.ratioPercent,
    builder: (column) => ColumnOrderings(column),
  );

  $$BeansTableOrderingComposer get beanId {
    final $$BeansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableOrderingComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OriginComponentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OriginComponentsTable> {
  $$OriginComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get farm =>
      $composableBuilder(column: $table.farm, builder: (column) => column);

  GeneratedColumn<String> get variety =>
      $composableBuilder(column: $table.variety, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Process, int> get process =>
      $composableBuilder(column: $table.process, builder: (column) => column);

  GeneratedColumn<String> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<int> get ratioPercent => $composableBuilder(
    column: $table.ratioPercent,
    builder: (column) => column,
  );

  $$BeansTableAnnotationComposer get beanId {
    final $$BeansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableAnnotationComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OriginComponentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OriginComponentsTable,
          OriginComponent,
          $$OriginComponentsTableFilterComposer,
          $$OriginComponentsTableOrderingComposer,
          $$OriginComponentsTableAnnotationComposer,
          $$OriginComponentsTableCreateCompanionBuilder,
          $$OriginComponentsTableUpdateCompanionBuilder,
          (OriginComponent, $$OriginComponentsTableReferences),
          OriginComponent,
          PrefetchHooks Function({bool beanId})
        > {
  $$OriginComponentsTableTableManager(
    _$AppDatabase db,
    $OriginComponentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OriginComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OriginComponentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OriginComponentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> beanId = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> farm = const Value.absent(),
                Value<String?> variety = const Value.absent(),
                Value<Process> process = const Value.absent(),
                Value<String?> altitude = const Value.absent(),
                Value<int?> ratioPercent = const Value.absent(),
              }) => OriginComponentsCompanion(
                id: id,
                beanId: beanId,
                country: country,
                region: region,
                farm: farm,
                variety: variety,
                process: process,
                altitude: altitude,
                ratioPercent: ratioPercent,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int beanId,
                required String country,
                Value<String?> region = const Value.absent(),
                Value<String?> farm = const Value.absent(),
                Value<String?> variety = const Value.absent(),
                Value<Process> process = const Value.absent(),
                Value<String?> altitude = const Value.absent(),
                Value<int?> ratioPercent = const Value.absent(),
              }) => OriginComponentsCompanion.insert(
                id: id,
                beanId: beanId,
                country: country,
                region: region,
                farm: farm,
                variety: variety,
                process: process,
                altitude: altitude,
                ratioPercent: ratioPercent,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OriginComponentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({beanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (beanId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.beanId,
                                referencedTable:
                                    $$OriginComponentsTableReferences
                                        ._beanIdTable(db),
                                referencedColumn:
                                    $$OriginComponentsTableReferences
                                        ._beanIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OriginComponentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OriginComponentsTable,
      OriginComponent,
      $$OriginComponentsTableFilterComposer,
      $$OriginComponentsTableOrderingComposer,
      $$OriginComponentsTableAnnotationComposer,
      $$OriginComponentsTableCreateCompanionBuilder,
      $$OriginComponentsTableUpdateCompanionBuilder,
      (OriginComponent, $$OriginComponentsTableReferences),
      OriginComponent,
      PrefetchHooks Function({bool beanId})
    >;
typedef $$TastingsTableCreateCompanionBuilder =
    TastingsCompanion Function({
      Value<int> id,
      required int beanId,
      required DateTime date,
      required int acidity,
      required int sweetness,
      required int body,
      required int bitterness,
      required int overall,
      Value<String?> comment,
      required DateTime createdAt,
    });
typedef $$TastingsTableUpdateCompanionBuilder =
    TastingsCompanion Function({
      Value<int> id,
      Value<int> beanId,
      Value<DateTime> date,
      Value<int> acidity,
      Value<int> sweetness,
      Value<int> body,
      Value<int> bitterness,
      Value<int> overall,
      Value<String?> comment,
      Value<DateTime> createdAt,
    });

final class $$TastingsTableReferences
    extends BaseReferences<_$AppDatabase, $TastingsTable, Tasting> {
  $$TastingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BeansTable _beanIdTable(_$AppDatabase db) => db.beans.createAlias(
    $_aliasNameGenerator(db.tastings.beanId, db.beans.id),
  );

  $$BeansTableProcessedTableManager get beanId {
    final $_column = $_itemColumn<int>('bean_id')!;

    final manager = $$BeansTableTableManager(
      $_db,
      $_db.beans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_beanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TastingsTableFilterComposer
    extends Composer<_$AppDatabase, $TastingsTable> {
  $$TastingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acidity => $composableBuilder(
    column: $table.acidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sweetness => $composableBuilder(
    column: $table.sweetness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitterness => $composableBuilder(
    column: $table.bitterness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BeansTableFilterComposer get beanId {
    final $$BeansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableFilterComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TastingsTableOrderingComposer
    extends Composer<_$AppDatabase, $TastingsTable> {
  $$TastingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acidity => $composableBuilder(
    column: $table.acidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sweetness => $composableBuilder(
    column: $table.sweetness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitterness => $composableBuilder(
    column: $table.bitterness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BeansTableOrderingComposer get beanId {
    final $$BeansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableOrderingComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TastingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TastingsTable> {
  $$TastingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get acidity =>
      $composableBuilder(column: $table.acidity, builder: (column) => column);

  GeneratedColumn<int> get sweetness =>
      $composableBuilder(column: $table.sweetness, builder: (column) => column);

  GeneratedColumn<int> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get bitterness => $composableBuilder(
    column: $table.bitterness,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overall =>
      $composableBuilder(column: $table.overall, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BeansTableAnnotationComposer get beanId {
    final $$BeansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.beanId,
      referencedTable: $db.beans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BeansTableAnnotationComposer(
            $db: $db,
            $table: $db.beans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TastingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TastingsTable,
          Tasting,
          $$TastingsTableFilterComposer,
          $$TastingsTableOrderingComposer,
          $$TastingsTableAnnotationComposer,
          $$TastingsTableCreateCompanionBuilder,
          $$TastingsTableUpdateCompanionBuilder,
          (Tasting, $$TastingsTableReferences),
          Tasting,
          PrefetchHooks Function({bool beanId})
        > {
  $$TastingsTableTableManager(_$AppDatabase db, $TastingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TastingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TastingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TastingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> beanId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> acidity = const Value.absent(),
                Value<int> sweetness = const Value.absent(),
                Value<int> body = const Value.absent(),
                Value<int> bitterness = const Value.absent(),
                Value<int> overall = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TastingsCompanion(
                id: id,
                beanId: beanId,
                date: date,
                acidity: acidity,
                sweetness: sweetness,
                body: body,
                bitterness: bitterness,
                overall: overall,
                comment: comment,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int beanId,
                required DateTime date,
                required int acidity,
                required int sweetness,
                required int body,
                required int bitterness,
                required int overall,
                Value<String?> comment = const Value.absent(),
                required DateTime createdAt,
              }) => TastingsCompanion.insert(
                id: id,
                beanId: beanId,
                date: date,
                acidity: acidity,
                sweetness: sweetness,
                body: body,
                bitterness: bitterness,
                overall: overall,
                comment: comment,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TastingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({beanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (beanId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.beanId,
                                referencedTable: $$TastingsTableReferences
                                    ._beanIdTable(db),
                                referencedColumn: $$TastingsTableReferences
                                    ._beanIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TastingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TastingsTable,
      Tasting,
      $$TastingsTableFilterComposer,
      $$TastingsTableOrderingComposer,
      $$TastingsTableAnnotationComposer,
      $$TastingsTableCreateCompanionBuilder,
      $$TastingsTableUpdateCompanionBuilder,
      (Tasting, $$TastingsTableReferences),
      Tasting,
      PrefetchHooks Function({bool beanId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BeansTableTableManager get beans =>
      $$BeansTableTableManager(_db, _db.beans);
  $$OriginComponentsTableTableManager get originComponents =>
      $$OriginComponentsTableTableManager(_db, _db.originComponents);
  $$TastingsTableTableManager get tastings =>
      $$TastingsTableTableManager(_db, _db.tastings);
}
