import 'package:beanprofile/features/tasting/tasting_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('editing a tasting prefills and updates', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());
    await repo.createTasting(
        id, sampleTasting(overall: 2, comment: '초안', degassingDays: 8));
    final tasting = (await repo.getBeanDetail(id))!.tastings.first;

    await tester.pumpWidget(wrapApp(
        TastingFormScreen(beanId: id, roastDate: null, existing: tasting),
        db: db));
    await tester.pumpAndSettle();

    expect(find.text('초안'), findsOneWidget); // 프리필된 코멘트
    expect(find.text('8'), findsOneWidget); // 프리필된 디개싱 일수
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.tastings.first.overall, 5);
    expect(updated.tastings.first.degassingDays, 8,
        reason: '건드리지 않은 일수가 저장에서 지워지면 안 된다');
  });
}
