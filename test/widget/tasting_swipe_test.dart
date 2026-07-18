import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('swiping a tasting deletes it and offers undo', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(id, sampleTasting());

    await tester.pumpWidget(wrapApp(BeanDetailScreen(beanId: id), db: db));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect((await repo.getBeanDetail(id))!.tastings, isEmpty); // deleted
    expect(find.text('실행취소'), findsOneWidget);               // undo offered

    await tester.tap(find.text('실행취소'));
    await tester.pumpAndSettle();
    expect((await repo.getBeanDetail(id))!.tastings, hasLength(1)); // restored

    await tester.pump(const Duration(milliseconds: 300));
    await db.close();
  });
}
