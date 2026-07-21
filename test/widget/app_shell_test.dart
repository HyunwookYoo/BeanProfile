import 'package:beanprofile/app.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows 3 tabs and switches to 취향', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const BeanProfileApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('원두'), findsWidgets);
    expect(find.text('취향'), findsWidgets);
    expect(find.text('설정'), findsWidgets);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);

    await tester.tap(find.text('취향'));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(find.text('내 취향'), findsOneWidget);

    // Close explicitly before the widget tree is torn down: drift schedules a
    // zero-duration Timer when a stream loses its last listener (see
    // StreamQueryStore.markAsClosed), and Flutter's test binding checks for
    // pending timers immediately after auto-disposing the tree — too soon for
    // that timer to fire. Closing here first makes drift skip the timer
    // entirely (_isShuttingDown short-circuit). Now that BeanListScreen (Task
    // 7) really watches beanListProvider, this app-shell test exercises a
    // live drift stream for the first time. addTearDown(db.close) above stays
    // as a safety net for early test failures; closing twice is a no-op.
    await db.close();
  });
}
