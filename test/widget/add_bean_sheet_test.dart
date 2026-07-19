import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('FAB → 시트 3옵션', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('add-camera')), findsOneWidget);
    expect(find.byKey(const Key('add-gallery')), findsOneWidget);
    expect(find.byKey(const Key('add-manual')), findsOneWidget);

    // drift 스트림(beanListProvider)이 살아있는 채로 트리가 해제되면 markAsClosed가 예약하는
    // 0-duration Timer가 테스트 바인딩의 pending-timer assert보다 늦게 처리됨(M2 T6 교훈).
    // db.close()를 먼저 호출해 drift의 _isShuttingDown 단락으로 타이머 예약 자체를 건너뛴다.
    await t.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('직접 입력 → 빈 폼', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-manual')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(find.text('원두 추가'), findsWidgets); // AppBar 타이틀

    await t.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('촬영 → OCR(가짜) → 폼 프리필', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanListScreen(),
      db: db,
      ocr: FakeOcrService('Ethiopia\nWashed\nNotes: 블루베리'),
      photo: FakePhotoService(pickResult: '/tmp/pick.jpg'),
    ));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-camera')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('field-country-0')),
        matching: find.text('Ethiopia'),
      ),
      findsOneWidget,
    );

    await t.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('촬영 취소(pick=null) → 폼 안 열림', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanListScreen(),
      db: db,
      photo: FakePhotoService(pickResult: null),
    ));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-camera')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsNothing);

    await t.pump(const Duration(milliseconds: 300));
    await db.close();
  });

  testWidgets('OCR 빈 결과여도 폼이 열려 수동 입력으로 이어진다 (실패 폴백)', (t) async {
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanListScreen(),
      db: db,
      ocr: FakeOcrService(''), // 인식 실패 → 빈 텍스트
      photo: FakePhotoService(pickResult: '/tmp/pick.jpg'),
    ));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-camera')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget); // 막다른 길 아님
    expect(find.textContaining('자동 인식하지 못'), findsOneWidget); // 실패 배너

    await t.pump(const Duration(milliseconds: 300));
    await db.close();
  });
}
