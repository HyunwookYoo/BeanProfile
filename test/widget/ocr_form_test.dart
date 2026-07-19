import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/widgets/ocr_chips_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('draft 프리필 + OCR 자동 하이라이트 + 칩 렌더', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    // 폼이 길어져(OCR 칩 패널까지) 기본 800x600 테스트 뷰포트+캐시영역을 벗어나면
    // ListView가 하단 위젯(컵노트/메모/칩 패널)을 아예 마운트하지 않는다
    // (M1 Task 8에서 저장 버튼이 같은 이유로 누락됐던 것과 같은 구조).
    // 전체 폼이 들어가도록 세로로 넉넉한 뷰포트로 확장.
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(
          country: 'Ethiopia',
          process: Process.washed,
          cupNotes: ['블루베리'],
          chips: ['프릳츠', 'G1'],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.text('Ethiopia'), findsOneWidget);         // 국가 프리필
    expect(find.text('블루베리'), findsOneWidget);           // 컵노트 프리필
    expect(find.text('OCR 자동'), findsNWidgets(2));        // 하이라이트: 국가+컵노트 (로스팅단계·날짜는 null)
    expect(find.byType(OcrChipsPanel), findsOneWidget);
    expect(find.text('프릳츠'), findsOneWidget);
  });

  testWidgets('칩 탭 → 배정 시트가 대상 목록을 보여줌', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['Yirgacheffe'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-Yirgacheffe')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('assign-지역')), findsOneWidget);
    expect(find.byKey(const Key('assign-원산지 국가')), findsOneWidget);
    expect(find.byKey(const Key('assign-컵노트에 추가')), findsOneWidget);
  });

  testWidgets('시트에서 지역 선택 → 지역 칸에 채워지고 칩 흐려짐', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['Yirgacheffe'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-Yirgacheffe')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    expect(t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text, 'Yirgacheffe');
    expect(t.widget<ActionChip>(find.byKey(const Key('chip-Yirgacheffe'))).onPressed, isNull);
  });

  testWidgets('시트에서 컵노트에 추가 → 기존 값에 append', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(cupNotes: ['블루베리'], chips: ['홍차'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-홍차')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-컵노트에 추가')));
    await t.pumpAndSettle();

    expect(find.text('블루베리, 홍차'), findsOneWidget);
  });

  testWidgets('자동으로 찬 국가 칸도 시트에서 덮어쓸 수 있음', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(country: 'Ethiopia', chips: ['Colombia'])),
      db: db,
    ));
    await t.pump();

    expect(t.widget<TextField>(find.byKey(const Key('field-country-0'))).controller!.text, 'Ethiopia');

    await t.tap(find.byKey(const Key('chip-Colombia')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-원산지 국가')));
    await t.pumpAndSettle();

    expect(t.widget<TextField>(find.byKey(const Key('field-country-0'))).controller!.text, 'Colombia');
  });

  testWidgets('OCR 실패(빈 draft) → 안내 배너, 칩 패널 없음', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000); // 배너가 뷰포트 밖 → 마운트되도록 확장(위 테스트 주석 참고)
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(const BeanFormScreen(draft: OcrDraft()), db: db));
    await t.pump();

    expect(find.textContaining('자동 인식하지 못했'), findsOneWidget);
    expect(find.byType(OcrChipsPanel), findsNothing);
  });

  testWidgets('저장 시 photoTempPath를 persist해 photoPath로 저장', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(country: 'Ethiopia'),
        photoTempPath: '/tmp/pick.jpg',
      ),
      db: db,
      photo: FakePhotoService(persistResult: '/app/photos/saved.jpg'),
    ));
    await t.pump();

    await t.enterText(find.byKey(const Key('field-name')), '예가체프');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pumpAndSettle();

    final summaries = await repo.watchBeanSummaries().first;
    expect(summaries.single.bean.photoPath, '/app/photos/saved.jpg');

    // Explicit close before teardown: `.first` subscribes-then-cancels a live
    // drift stream, which schedules a zero-duration debounce Timer on cancel
    // (StreamQueryStore.markAsClosed) that the test binding's pending-timer
    // check runs before that Timer fires. Closing here makes drift skip it
    // (_isShuttingDown short-circuit) — same fix as test/widget/bean_form_test.dart.
    await db.close();
  });

  testWidgets('사진 저장(persist) 실패 시 폼에 머물고 에러 안내 (막다른 길 아님)', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(country: 'Ethiopia'),
        photoTempPath: '/tmp/pick.jpg',
      ),
      db: db,
      photo: FakePhotoService(throwOnPersist: true),
    ));
    await t.pump();

    await t.enterText(find.byKey(const Key('field-name')), '예가체프');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pump();                                   // _save 비동기 실행 시작
    await t.pump(const Duration(milliseconds: 300));  // catch→setState/SnackBar 반영
    // (pumpAndSettle는 SnackBar 자동 닫힘 타이머 때문에 멈출 수 있어 쓰지 않음)

    expect(find.byType(BeanFormScreen), findsOneWidget);       // 폼 유지(pop 안 됨)
    expect(find.textContaining('저장에 실패'), findsOneWidget);  // 에러 안내
    expect(t.widget<FilledButton>(find.byKey(const Key('save-bean'))).onPressed, isNotNull); // 재활성화
  });
}
