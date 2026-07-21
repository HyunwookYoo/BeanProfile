import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/profile/profile_screen.dart';
import 'package:beanprofile/features/profile/widgets/bar_row.dart';
import 'package:beanprofile/features/profile/widgets/intensity_radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  // 패널 4개 + 요약이 기본 800x600 뷰포트를 넘어가면 ListView가 하단 패널을
  // 마운트하지 않는다(M3 ocr_form_test와 같은 이유). 세로로 넉넉히 확장한다.
  void expandViewport(WidgetTester t) {
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
  }

  testWidgets('시음 0건 → 요약은 남기고 빈 상태 안내', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    await testRepository(db).createBean(sampleSingle());

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);        // 기록한 원두
    expect(find.text('—'), findsOneWidget);         // 최고 평점 원두
    expect(find.textContaining('아직 시음 기록이 없어요'), findsOneWidget);
    expect(find.byType(IntensityRadar), findsNothing);
    await db.close();
  });

  testWidgets('시음이 있으면 패널 4개와 막대가 그려진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle()); // Ethiopia, 워시드, 컵노트 2개
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('선호 강도'), findsOneWidget);
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    expect(find.text('선호 컵노트'), findsOneWidget);
    expect(find.text('가공방식별 평점'), findsOneWidget);
    expect(find.byType(IntensityRadar), findsOneWidget);
    expect(find.byType(BarRow), findsNWidgets(4)); // 국가1 + 컵노트2 + 가공1
    await db.close();
  });

  testWidgets('★4+가 있으면 배지는 ★4+ 기준', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('★4+ 기준'), findsOneWidget);
    expect(find.text('★4+ 빈도'), findsOneWidget);
    await db.close();
  });

  testWidgets('★4+가 0건이면 배지가 전체 기준으로 바뀐다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting(overall: 2));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.text('전체 기준'), findsOneWidget);
    expect(find.text('전체 빈도'), findsOneWidget);
    expect(find.text('★4+ 기준'), findsNothing);
    await db.close();
  });

  testWidgets('컵노트가 없으면 그 패널만 안내를 띄운다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    expandViewport(t);
    final repo = testRepository(db);
    final id = await repo.createBean(const BeanInput(
      name: '무노트', roaster: '', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: [], memo: null,
      components: [ComponentInput(country: 'Kenya')],
    ));
    await repo.createTasting(id, sampleTasting(overall: 5));

    await t.pumpWidget(wrapApp(const ProfileScreen(), db: db));
    await t.pumpAndSettle();

    expect(find.textContaining('컵노트가 기록된 원두가 없어요'), findsOneWidget);
    expect(find.text('선호 컵노트'), findsOneWidget); // 패널 자체는 남는다
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    await db.close();
  });
}
