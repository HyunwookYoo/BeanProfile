import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('swiping a bean confirms then deletes', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle(name: '삭제될 원두'));

    await tester.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('삭제될 원두'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('원두 삭제'), findsOneWidget); // confirm dialog
    // SwipeDeleteBackground도 '삭제' 텍스트를 그리므로(스와이프 완료 후에도 트리에 남음),
    // 다이얼로그의 확인 버튼(TextButton)으로 특정해 모호성 회피.
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(await repo.getBeanDetail(id), isNull);
    expect(find.text('삭제될 원두'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('cancelling the swipe keeps the bean', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '남는 원두'));

    await tester.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('남는 원두'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });
}
