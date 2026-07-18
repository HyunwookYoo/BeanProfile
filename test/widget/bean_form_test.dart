import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entering name + country and saving persists a bean', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = () {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      return container.read(beanRepositoryProvider);
    }();

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const BeanFormScreen()),
    ));

    await tester.enterText(find.byKey(const Key('field-name')), '수프리모');
    await tester.enterText(find.byKey(const Key('field-country-0')), 'Colombia');
    await tester.tap(find.byKey(const Key('save-bean')));
    await tester.pumpAndSettle();

    final list = await repo.watchBeanSummaries().first;
    expect(list, hasLength(1));
    expect(list.first.bean.name, '수프리모');
    expect(list.first.originLabel, 'Colombia');

    // Close explicitly before the widget tree is torn down: drift schedules a
    // zero-duration Timer when a stream loses its last listener (see
    // StreamQueryStore.markAsClosed), and Flutter's test binding checks for
    // pending timers immediately after auto-disposing the tree — too soon for
    // that timer to fire. Closing here first makes drift skip the timer
    // entirely (_isShuttingDown short-circuit). Same fix as
    // test/widget/app_shell_test.dart (Task 7); `repo.watchBeanSummaries().first`
    // above subscribes-then-cancels a live drift stream, triggering the same
    // debounce timer. addTearDown(db.close) above stays as a safety net for
    // early test failures; closing twice is a no-op.
    await db.close();
  });
}
