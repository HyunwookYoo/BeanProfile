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

  testWidgets('칩이 포커스된 칸으로 라우팅됨 (하드코딩 아님)', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000); // 칩 패널이 뷰포트 밖 → 마운트되도록 확장(위 테스트 주석 참고)
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['프릳츠', '블루보틀'])),
      db: db,
    ));
    await t.pump();

    // 로스터리 포커스 → 첫 칩
    await t.tap(find.byKey(const Key('field-roaster')));
    await t.pump();
    await t.tap(find.byKey(const Key('chip-프릳츠')));
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('field-roaster'))).controller!.text, '프릳츠');

    // 제품명 포커스 → 둘째 칩 → 제품명에만, 로스터리는 그대로
    await t.tap(find.byKey(const Key('field-name')));
    await t.pump();
    await t.tap(find.byKey(const Key('chip-블루보틀')));
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('field-name'))).controller!.text, '블루보틀');
    expect(t.widget<TextField>(find.byKey(const Key('field-roaster'))).controller!.text, '프릳츠'); // 라우팅 증명
    expect(t.widget<ActionChip>(find.byKey(const Key('chip-블루보틀'))).onPressed, isNull); // used
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
}
