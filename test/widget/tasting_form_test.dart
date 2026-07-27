import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('filling and saving a tasting persists it', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byKey(const Key('tasting-comment')), '초콜릿, 견과');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.acidity, 5);
    expect(detail.tastings.first.overall, 4);
    expect(detail.tastings.first.comment, '초콜릿, 견과');
  });

  testWidgets('로스팅 날짜가 있으면 자동 계산해서 읽기 전용으로 보여준다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: beanId, roastDate: DateTime(2026, 7, 19)),
        db: db));
    await tester.pumpAndSettle();

    expect(find.textContaining('로스팅 2026-07-19'), findsOneWidget,
        reason: '숫자의 출처를 감추지 않는다');
    expect(find.byKey(const Key('degassing-input')), findsNothing,
        reason: '계산되는 값이라 입력칸이 없어야 한다');
    expect(find.textContaining('디개싱'), findsOneWidget,
        reason: '별도 라벨과 계산된 텍스트가 겹쳐 두 번 나오면 안 된다');
  });

  testWidgets('시음일을 바꾸면 표시된 일수가 따라 바뀐다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());
    // 시음일을 고정해야 날짜 선택기의 initialDate(=_date)가 항상 같은 달로 열리고,
    // DateTime.now()에 얹혀 있던 흔들리는 값(달 경계 넘으면 실패)이 사라진다.
    await repo.createTasting(beanId, sampleTasting(date: DateTime(2026, 7, 20)));
    final tasting = (await repo.getBeanDetail(beanId))!.tastings.first;

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(
            beanId: beanId,
            roastDate: DateTime(2026, 7, 19),
            existing: tasting),
        db: db));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 1일'), findsOneWidget); // 2026-07-20 기준, 바뀌기 전

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    // 날짜 선택기가 시음일(2026-07-20)이 속한 7월로 열리므로 27을 눌러 같은 달 안에서 옮긴다.
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 8일'), findsOneWidget); // 2026-07-27로 바뀐 뒤
  });

  testWidgets('로스팅 날짜가 없으면 직접 입력해서 저장한다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    expect(find.text('로스팅 날짜 없음'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('degassing-input')), '12');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings.single.degassingDays, 12);
  });

  testWidgets('입력칸은 숫자만 받는다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(
        wrapApp(TastingFormScreen(beanId: beanId, roastDate: null), db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('degassing-input')), '-8일');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings.single.degassingDays, 8,
        reason: '부호와 문자는 formatter가 걸러 8만 남는다');
  });

  testWidgets('로스팅 날짜와 시음일이 같으면 당일로 보여준다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());
    // 시음일을 고정해야 roastDate를 같은 날로 맞춰 값을 결정적으로 만들 수 있다.
    await repo.createTasting(beanId, sampleTasting(date: DateTime(2026, 7, 20)));
    final tasting = (await repo.getBeanDetail(beanId))!.tastings.first;

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(
            beanId: beanId,
            roastDate: DateTime(2026, 7, 20),
            existing: tasting),
        db: db));
    await tester.pumpAndSettle();

    expect(find.text('당일'), findsOneWidget);
  });

  testWidgets('로스팅 날짜가 시음일보다 늦으면 날짜 확인으로 보여준다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());
    await repo.createTasting(beanId, sampleTasting(date: DateTime(2026, 7, 20)));
    final tasting = (await repo.getBeanDetail(beanId))!.tastings.first;

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(
            beanId: beanId,
            roastDate: DateTime(2026, 7, 25),
            existing: tasting),
        db: db));
    await tester.pumpAndSettle();

    expect(find.text('날짜 확인'), findsOneWidget);
  });
}
