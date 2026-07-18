import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 인메모리 테스트 DB (FK on). 반드시 addTearDown(db.close).
AppDatabase testDatabase() => AppDatabase.forTesting(NativeDatabase.memory());

/// DB를 주입한 저장소.
BeanRepository testRepository(AppDatabase db) => BeanRepository(db);

/// DB를 override한 ProviderContainer. addTearDown(container.dispose).
ProviderContainer testContainer(AppDatabase db) =>
    ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

/// 위젯 테스트용: 테마 + (선택) DB override로 화면을 감싼다.
Widget wrapApp(Widget child, {AppDatabase? db}) => ProviderScope(
      overrides: [if (db != null) databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

/// 샘플 싱글 오리진.
BeanInput sampleSingle({String name = '예가체프 코체레', String country = 'Ethiopia'}) =>
    BeanInput(
      name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null,
      cupNotes: const ['블루베리', '자스민'], memo: null,
      components: [ComponentInput(country: country, process: Process.washed)],
    );

/// 샘플 블렌드 (구성 2개 + 비율).
BeanInput sampleBlend({String name = '하우스 블렌드'}) => BeanInput(
      name: name, roaster: '테라로사', type: BeanType.blend,
      roastLevel: RoastLevel.medium, roastDate: null,
      cupNotes: const ['다크초콜릿'], memo: null,
      components: const [
        ComponentInput(country: 'Brazil', process: Process.natural, ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
      ],
    );

/// 샘플 시음 (강도 4축 + 종합 + 코멘트).
TastingInput sampleTasting({
  int acidity = 4,
  int sweetness = 3,
  int body = 3,
  int bitterness = 2,
  int overall = 4,
  String? comment = '균형이 좋다',
  DateTime? date,
}) =>
    TastingInput(
      date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall, comment: comment,
    );
