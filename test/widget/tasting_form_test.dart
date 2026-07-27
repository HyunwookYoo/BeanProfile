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
  });

  testWidgets('시음일을 바꾸면 표시된 일수가 따라 바뀐다', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final beanId = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: beanId, roastDate: DateTime(2026, 7, 19)),
        db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    // 날짜 선택기를 27일로 옮긴다 — 기본값이 오늘이라 직접 고른다.
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 8일'), findsOneWidget);
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
}
