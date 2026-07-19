import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('editing a bean prefills the form and updates', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle(name: '원본'));
    final detail = await repo.getBeanDetail(id);

    await tester.pumpWidget(wrapApp(BeanFormScreen(existing: detail), db: db));
    await tester.pumpAndSettle();

    expect(find.text('원본'), findsOneWidget); // 프리필된 제품명
    await tester.enterText(find.byKey(const Key('field-name')), '변경됨');
    await tester.tap(find.byKey(const Key('save-bean')));
    await tester.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.bean.name, '변경됨');
  });

  testWidgets('편집 시 기존 사진이 유지된다 (photoPath 미덮어씀)', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle().copyWithPhoto('/existing/photo.jpg'));
    final detail = await repo.getBeanDetail(id);

    await t.pumpWidget(wrapApp(BeanFormScreen(existing: detail), db: db));
    await t.pump();
    await t.enterText(find.byKey(const Key('field-name')), '수정된 이름');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pumpAndSettle();

    final updated = await repo.getBeanDetail(id);
    expect(updated!.bean.name, '수정된 이름');       // 편집이 실제로 저장됨
    expect(updated.bean.photoPath, '/existing/photo.jpg'); // 사진이 보존됨(널로 안 덮음)
    await db.close();
  });
}
