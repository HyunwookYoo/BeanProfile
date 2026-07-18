import 'package:beanprofile/app.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/providers.dart';
import 'package:drift/native.dart';
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

    await tester.tap(find.text('취향'));
    await tester.pumpAndSettle();
    expect(find.text('취향 분석은 곧 추가됩니다'), findsOneWidget);
  });
}
