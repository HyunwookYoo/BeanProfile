import 'dart:async';

import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/ocr/ocr_diagnostics.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/widgets/ocr_chips_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

/// 칩 `from`을 길게 눌러 집은 뒤 칩 `onto` 위에 떨군다.
Future<void> dragChipOnto(WidgetTester t, String from, String onto) async {
  final gesture = await t.startGesture(t.getCenter(find.byKey(Key('chip-$from'))));
  // LongPressDraggable은 길게 누르는 시간이 지나야 집힌다.
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(t.getCenter(find.byKey(Key('chip-$onto'))));
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('diagnostic button requires an enabled photo OCR form', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnosticsEnabled: false,
      ),
    );
    await t.pump();

    expect(find.byKey(const Key('copy-ocr-diagnostics')), findsNothing);

    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnosticsEnabled: true,
      ),
    );
    await t.pump();

    expect(find.byKey(const Key('copy-ocr-diagnostics')), findsOneWidget);

    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(),
        db: db,
        diagnosticsEnabled: true,
      ),
    );
    await t.pump();

    expect(find.byKey(const Key('copy-ocr-diagnostics')), findsNothing);
  });

  testWidgets('diagnostic button copies the report and shows success', (
    t,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final diagnostics = FakeDiagnosticsService();
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnostics: diagnostics,
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const Key('copy-ocr-diagnostics')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(diagnostics.paths, ['/tmp/pick.jpg']);
    expect(copied, 'diagnostic text');
    expect(find.text('OCR 진단 정보가 복사됐어요'), findsOneWidget);
  });

  testWidgets('diagnostic collection blocks duplicate taps while running', (
    t,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final diagnostics = FakeDiagnosticsService()
      ..pending = Completer<String>();
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnostics: diagnostics,
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const Key('copy-ocr-diagnostics')));
    await t.pump();

    expect(diagnostics.paths, ['/tmp/pick.jpg']);
    expect(find.text('진단 정보 생성 중…'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const Key('copy-ocr-diagnostics')),
          )
          .onPressed,
      isNull,
    );

    await t.tap(find.byKey(const Key('copy-ocr-diagnostics')));
    expect(diagnostics.paths, ['/tmp/pick.jpg']);

    diagnostics.pending!.complete('diagnostic text');
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const Key('copy-ocr-diagnostics')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('diagnostic service failure shows an error and allows retry', (
    t,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final diagnostics = FakeDiagnosticsService(error: StateError('failed'));
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnostics: diagnostics,
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const Key('copy-ocr-diagnostics')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('OCR 진단 정보를 만들지 못했어요'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const Key('copy-ocr-diagnostics')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('clipboard failure shows an error and allows retry', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final diagnostics = FakeDiagnosticsService();
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-failed');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await t.pumpWidget(
      wrapApp(
        const BeanFormScreen(
          draft: OcrDraft(chips: ['Brazil']),
          photoTempPath: '/tmp/pick.jpg',
        ),
        db: db,
        diagnostics: diagnostics,
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const Key('copy-ocr-diagnostics')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('OCR 진단 정보를 만들지 못했어요'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const Key('copy-ocr-diagnostics')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('certain OCR type, process, and ratio show field provenance',
      (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        initialType: BeanType.blend,
        draft: OcrDraft(
          typeDecision: OcrTypeDecision.certainBlend,
          components: [
            OcrComponentDraft(
              country: 'Brazil',
              process: Process.natural,
              ratioPercent: 60,
            ),
          ],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.byKey(const Key('ocr-auto-type')), findsOneWidget);
    expect(find.byKey(const Key('ocr-auto-process-0')), findsOneWidget);
    expect(find.byKey(const Key('ocr-auto-ratio-0')), findsOneWidget);
    expect(find.byKey(const Key('ocr-auto-process-1')), findsNothing);
    expect(find.byKey(const Key('ocr-auto-ratio-1')), findsNothing);
  });

  testWidgets('user-confirmed ambiguous type is not labeled OCR automatic',
      (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        initialType: BeanType.blend,
        draft: OcrDraft(typeDecision: OcrTypeDecision.ambiguous),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.byKey(const Key('ocr-auto-type')), findsNothing);
  });

  testWidgets('blend draft prefills two component rows and ratios', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        initialType: BeanType.blend,
        draft: OcrDraft(
          typeDecision: OcrTypeDecision.certainBlend,
          components: [
            OcrComponentDraft(
              country: 'Brazil',
              region: 'Cerrado',
              process: Process.natural,
              ratioPercent: 60,
            ),
            OcrComponentDraft(
              country: 'Ethiopia',
              region: 'Guji',
              process: Process.washed,
              ratioPercent: 40,
            ),
          ],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsOneWidget);
    expect(find.text('Brazil'), findsOneWidget);
    expect(find.text('Ethiopia'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('field-region-0')))
        .controller!.text, 'Cerrado');
    expect(t.widget<TextField>(find.byKey(const Key('field-region-1')))
        .controller!.text, 'Guji');
    final processes = t.widgetList<DropdownButtonFormField<Process>>(
        find.byType(DropdownButtonFormField<Process>)).toList();
    expect(processes[0].initialValue, Process.natural);
    expect(processes[1].initialValue, Process.washed);
    expect(t.widget<TextField>(find.byKey(const Key('field-ratio-0')))
        .controller!.text, '60');
    expect(t.widget<TextField>(find.byKey(const Key('field-ratio-1')))
        .controller!.text, '40');
    expect(find.textContaining('충분히 읽지 못했어요'), findsNothing);
  });

  testWidgets('incomplete blend warns but saves with zero components', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        initialType: BeanType.blend,
        draft: OcrDraft(typeDecision: OcrTypeDecision.certainBlend),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.textContaining('아는 내용만 입력해도 저장할 수 있어요'),
        findsOneWidget);
    await t.enterText(find.byKey(const Key('field-name')), '비공개 블렌드');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pump();

    final beans = await db.select(db.beans).get();
    final detail = await repo.getBeanDetail(beans.single.id);
    expect(beans.single.type, BeanType.blend);
    expect(detail!.components, isEmpty);
  });

  testWidgets('single type keeps and saves only the first OCR component', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        initialType: BeanType.singleOrigin,
        draft: OcrDraft(
          typeDecision: OcrTypeDecision.ambiguous,
          components: [
            OcrComponentDraft(
              country: 'Kenya',
              region: 'Nyeri',
              process: Process.washed,
            ),
            OcrComponentDraft(
              country: 'Ethiopia',
              region: 'Guji',
              process: Process.natural,
            ),
          ],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.byKey(const Key('field-country-0')), findsOneWidget);
    expect(find.byKey(const Key('field-country-1')), findsNothing);
    expect(find.text('Kenya'), findsOneWidget);
    expect(find.text('Ethiopia'), findsNothing);

    await t.enterText(find.byKey(const Key('field-name')), '싱글 초안');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pump();

    final beans = await db.select(db.beans).get();
    final detail = await repo.getBeanDetail(beans.single.id);
    expect(detail!.components, hasLength(1));
    expect(detail.components.single.country, 'Kenya');
  });

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
          components: [OcrComponentDraft(country: 'Ethiopia', process: Process.washed)],
          cupNotes: ['블루베리'],
          chips: ['프릳츠', 'G1'],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.text('Ethiopia'), findsOneWidget);         // 국가 프리필
    expect(find.text('블루베리'), findsOneWidget);           // 컵노트 프리필
    expect(find.text('OCR 자동'), findsNWidgets(3));        // 하이라이트: 국가+가공+컵노트 (로스팅단계·날짜는 null)
    expect(find.byType(OcrChipsPanel), findsOneWidget);
    expect(find.text('프릳츠'), findsOneWidget);
  });

  testWidgets('OCR 가공 미인식 구성은 other로 프리필', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(components: [OcrComponentDraft(country: 'Ethiopia')]),
      ),
      db: db,
    ));
    await t.pump();

    expect(
      t.widget<DropdownButtonFormField<Process>>(
        find.byType(DropdownButtonFormField<Process>),
      ).initialValue,
      Process.other,
    );
  });

  testWidgets('draft.name/roaster → 제품명·로스터리 프리필 + OCR 자동', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
          draft: OcrDraft(
            name: '예가체프',
            roaster: '아우어사이드',
            components: [OcrComponentDraft(country: 'Ethiopia')],
          )),
      db: db,
    ));
    await t.pump();

    expect(t.widget<TextField>(find.byKey(const Key('field-name'))).controller!.text, '예가체프');
    expect(t.widget<TextField>(find.byKey(const Key('field-roaster'))).controller!.text, '아우어사이드');
    expect(find.text('OCR 자동'), findsNWidgets(3)); // 제품명 + 로스터리 + 국가
  });

  testWidgets('draft.components[0].region → 지역 칸 프리필 + OCR 자동', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(
          components: [OcrComponentDraft(country: 'Ethiopia', region: '예가체프')],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text, '예가체프');
    expect(find.text('OCR 자동'), findsNWidgets(2)); // 국가 + 지역
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
      const BeanFormScreen(
        draft: OcrDraft(
          components: [OcrComponentDraft(country: 'Ethiopia')],
          chips: ['Colombia'],
        ),
      ),
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
        draft: OcrDraft(components: [OcrComponentDraft(country: 'Ethiopia')]),
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
        draft: OcrDraft(components: [OcrComponentDraft(country: 'Ethiopia')]),
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

  group('지역·가공 밑줄 정렬', () {
    // Row 기본 정렬은 center라, 지역에 'OCR 자동' helperText가 붙어 키가 커지면
    // helper가 없는 가공 드롭다운이 아래로 밀려 두 필드의 밑줄이 어긋난다.
    // (M3.3로 지역 자동채움이 실제 동작하면서 helper가 뜨게 돼 드러난 문제)
    Future<void> pumpForm(WidgetTester t, {String? region}) async {
      final db = testDatabase();
      addTearDown(db.close);
      t.view.physicalSize = const Size(2400, 4000);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(wrapApp(
        BeanFormScreen(
          draft: OcrDraft(
            components: [OcrComponentDraft(country: 'Ethiopia', region: region)],
          ),
        ),
        db: db,
      ));
      await t.pump();
    }

    testWidgets('helper 없으면 두 필드 높이가 같다(입력 영역이 원래 일치함)', (t) async {
      await pumpForm(t); // region 없음 → 지역에 helper 안 뜸
      final region = t.getSize(find.byKey(const Key('field-region-0')));
      final process = t.getSize(find.byType(DropdownButtonFormField<Process>));
      expect(region.height, process.height);
    });

    testWidgets('OCR 자동 helper가 붙어도 두 필드가 같은 y에서 시작한다', (t) async {
      await pumpForm(t, region: '예가체프'); // 지역에 'OCR 자동' helper 뜸
      final regionTop = t.getTopLeft(find.byKey(const Key('field-region-0'))).dy;
      final processTop = t.getTopLeft(find.byType(DropdownButtonFormField<Process>)).dy;
      // 위가 맞고 입력 영역 높이가 같으므로(위 테스트) 밑줄도 맞는다.
      expect(processTop, regionTop);
    });
  });

  testWidgets('칩을 다른 칩 위로 끌면 하나로 합쳐진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '구지', '에티오피아');

    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsNothing);
  });

  testWidgets('드래그 방향이 병합 순서를 정한다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '에티오피아', '구지'); // 반대 방향

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsNothing);
  });

  testWidgets('병합 칩을 지역에 배정하면 공백으로 이어진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '구지', '에티오피아');
    await t.tap(find.byKey(const Key('chip-에티오피아 · 구지')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    expect(
      t.widget<TextField>(find.byKey(const Key('field-region-0'))).controller!.text,
      '에티오피아 구지',
    );
  });

  testWidgets('병합 칩을 컵노트에 추가하면 쉼표로 이어진다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['자몽', '초콜릿'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '초콜릿', '자몽');
    await t.tap(find.byKey(const Key('chip-자몽 · 초콜릿')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-컵노트에 추가')));
    await t.pumpAndSettle();

    expect(find.text('자몽, 초콜릿'), findsOneWidget);
  });

  testWidgets('병합 칩의 ✕를 누르면 원래 칩들로 나뉜다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '에티오피아', '구지'); // 일부러 거꾸로: 구지 · 에티오피아
    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsOneWidget);

    await t.tap(find.descendant(
      of: find.byKey(const Key('chip-구지 · 에티오피아')),
      matching: find.byIcon(Icons.close),
    ));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아')), findsOneWidget);
  });

  testWidgets('병합 칩의 ✕에는 영어 Delete 툴팁이 없다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '구지', '에티오피아');

    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets('칩을 자기 자신 위로 끌면 그대로 남는다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await dragChipOnto(t, '에티오피아', '에티오피아');

    expect(find.byKey(const Key('chip-에티오피아')), findsOneWidget);
    expect(find.byKey(const Key('chip-구지')), findsOneWidget);
    expect(find.byKey(const Key('chip-에티오피아 · 에티오피아')), findsNothing);
  });

  testWidgets('배정된 칩은 드롭 대상이 되지 않는다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-에티오피아')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    await dragChipOnto(t, '구지', '에티오피아');

    expect(find.byKey(const Key('chip-에티오피아 · 구지')), findsNothing);
    expect(find.byKey(const Key('chip-구지')), findsOneWidget);
  });

  testWidgets('배정된 칩은 끌 수 없다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    t.view.physicalSize = const Size(2400, 4000);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['에티오피아', '구지'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('chip-에티오피아')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assign-지역')));
    await t.pumpAndSettle();

    await dragChipOnto(t, '에티오피아', '구지'); // 배정된 칩을 끌어본다

    expect(find.byKey(const Key('chip-구지 · 에티오피아')), findsNothing);
    expect(find.byKey(const Key('chip-에티오피아')), findsOneWidget);
  });
}

class FakeDiagnosticsService implements OcrDiagnosticsService {
  FakeDiagnosticsService({this.result = 'diagnostic text', this.error});

  final String result;
  final Object? error;
  final paths = <String>[];
  Completer<String>? pending;

  @override
  Future<String> collect(String imagePath) {
    paths.add(imagePath);
    if (error != null) return Future<String>.error(error!);
    return pending?.future ?? Future.value(result);
  }
}
