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

    await tester.pumpWidget(wrapApp(TastingFormScreen(beanId: beanId), db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byType(TextField), '초콜릿, 견과');
    await tester.tap(find.byKey(const Key('save-tasting')));
    await tester.pumpAndSettle();

    final detail = await repo.getBeanDetail(beanId);
    expect(detail!.tastings, hasLength(1));
    expect(detail.tastings.first.acidity, 5);
    expect(detail.tastings.first.overall, 4);
    expect(detail.tastings.first.comment, '초콜릿, 견과');
  });
}
