import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single to blend preserves first row and adds a second', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(
          draft: OcrDraft(
            components: [OcrComponentDraft(country: 'Kenya')],
          ),
          initialType: BeanType.singleOrigin,
        ),
      ),
    ));
    await t.pump();

    await t.tap(find.text('블렌드'));
    await t.pump();

    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
    expect(find.text('Kenya'), findsOneWidget);
  });

  testWidgets('blend to single can cancel or confirm component removal', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(
          initialType: BeanType.blend,
          draft: OcrDraft(components: [
            OcrComponentDraft(country: 'Brazil'),
            OcrComponentDraft(country: 'Ethiopia'),
          ]),
        ),
      ),
    ));
    await t.pump();

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
    await t.tap(find.byKey(const Key('keep-blend')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-single')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsNothing);
  });

  testWidgets('blend to single protects meaningful later row on cancel back and confirm',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(
          initialType: BeanType.blend,
          draft: OcrDraft(components: [
            OcrComponentDraft(),
            OcrComponentDraft(region: 'Guji', ratioPercent: 40),
          ]),
        ),
      ),
    ));
    await t.pump();

    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
    expect(find.text('Guji'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
    await t.tap(find.byKey(const Key('keep-blend')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
    expect(find.text('Guji'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
    expect(find.text('Guji'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-single')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsNothing);
  });

  testWidgets('initial blend without OCR draft renders at least two rows', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(initialType: BeanType.blend),
      ),
    ));
    await t.pump();

    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
  });

  testWidgets('later OCR process-only row is protected on cancel and back',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(
          initialType: BeanType.blend,
          draft: OcrDraft(components: [
            OcrComponentDraft(),
            OcrComponentDraft(process: Process.natural),
          ]),
        ),
      ),
    ));
    await t.pump();

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
    await t.tap(find.byKey(const Key('keep-blend')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
  });

  testWidgets('later user-edited process-only row requires confirmation',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(initialType: BeanType.blend),
      ),
    ));
    await t.pump();

    await t.tap(find.byType(DropdownButtonFormField<Process>).at(1));
    await t.pumpAndSettle();
    await t.tap(find.text(Process.natural.label).last);
    await t.pumpAndSettle();

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsOneWidget);
  });

  testWidgets('untouched manual process defaults do not require confirmation',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(initialType: BeanType.blend),
      ),
    ));
    await t.pump();

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsNothing);
    expect(find.byKey(const Key('field-country-1')), findsNothing);
  });

  testWidgets('untouched padded OCR other does not require confirmation',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(
          initialType: BeanType.blend,
          draft: OcrDraft(),
        ),
      ),
    ));
    await t.pump();

    final processes = t.widgetList<DropdownButtonFormField<Process>>(
        find.byType(DropdownButtonFormField<Process>)).toList();
    expect(processes[1].initialValue, Process.other);

    await t.tap(find.text('싱글'));
    await t.pumpAndSettle();
    expect(find.text('첫 번째 구성만 남아요.'), findsNothing);
    expect(find.byKey(const Key('field-country-1')), findsNothing);
  });

  testWidgets('single still requires first country', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanFormScreen(initialType: BeanType.singleOrigin),
      ),
    ));
    await t.pump();

    await t.enterText(find.byKey(const Key('field-name')), 'Missing Origin');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pump();

    expect(find.text('제품명과 첫 원산지 국가는 필수예요'), findsOneWidget);
  });

  testWidgets('manual entry process still defaults to washed', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const BeanFormScreen()),
    ));
    await t.pump();

    expect(t.widget<DropdownButtonFormField<Process>>(
      find.byType(DropdownButtonFormField<Process>).first,
    ).initialValue, Process.washed);
  });

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
