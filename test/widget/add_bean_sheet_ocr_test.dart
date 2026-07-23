import 'dart:async';

import 'package:beanprofile/features/beans/add_bean_sheet.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class AddHarness extends ConsumerWidget {
  const AddHarness({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: FilledButton(
      key: const Key('open-add'),
      onPressed: () => showAddBeanSheet(context, ref),
      child: const Text('add'),
    ),
  );
}

class ControllableOcrPipeline implements OcrPipeline {
  final result = Completer<OcrPipelineResult>();

  @override
  Future<OcrPipelineResult> analyze(String imagePath) => result.future;
}

Future<void> openCamera(WidgetTester t) async {
  await t.tap(find.byKey(const Key('open-add')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('add-camera')));
  await t.pump();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('certain blend opens form without type dialog', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final pipeline = FakeOcrPipeline([
      const OcrPipelineResult(
        draft: OcrDraft(
          name: 'House Blend',
          typeDecision: OcrTypeDecision.certainBlend,
          typeReasons: {OcrTypeReason.explicitBlend},
          components: [
            OcrComponentDraft(country: 'Brazil'),
            OcrComponentDraft(country: 'Ethiopia'),
          ],
        ),
        quality: ImageQualityReport(),
        usedEnhanced: false,
        shouldWarnQuality: false,
      ),
    ]);
    await t.pumpWidget(
      wrapApp(
        const AddHarness(),
        db: db,
        photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
        pipeline: pipeline,
      ),
    );

    await openCamera(t);

    expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(find.text('OCR 자동'), findsWidgets);
  });

  testWidgets('ambiguous result asks type exactly once', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(
      wrapApp(
        const AddHarness(),
        db: db,
        photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
        pipeline: FakeOcrPipeline([
          const OcrPipelineResult(
            draft: OcrDraft(name: 'Mystery Coffee'),
            quality: ImageQualityReport(),
            usedEnhanced: false,
            shouldWarnQuality: false,
          ),
        ]),
      ),
    );

    await openCamera(t);
    expect(find.text('원두 유형을 확인해 주세요'), findsOneWidget);
    await t.tap(find.byKey(const Key('confirm-type-blend')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
  });

  testWidgets('quality warning precedes ambiguous type confirmation', (
    t,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(
      wrapApp(
        const AddHarness(),
        db: db,
        photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
        pipeline: FakeOcrPipeline([
          const OcrPipelineResult(
            draft: OcrDraft(name: 'Weak Mystery'),
            quality: ImageQualityReport({ImageQualityIssue.blurry}),
            usedEnhanced: true,
            shouldWarnQuality: true,
          ),
        ]),
      ),
    );
    await openCamera(t);

    expect(find.text('사진을 충분히 읽지 못했어요'), findsOneWidget);
    expect(find.text('원두 유형을 확인해 주세요'), findsNothing);
    await t.tap(find.byKey(const Key('quality-continue')));
    await t.pumpAndSettle();
    expect(find.text('원두 유형을 확인해 주세요'), findsOneWidget);
  });

  testWidgets('retake discards first draft and uses second photo result', (
    t,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final photo = FakePhotoService(
      pickResults: const ['/tmp/first.jpg', '/tmp/second.jpg'],
    );
    final pipeline = FakeOcrPipeline([
      const OcrPipelineResult(
        draft: OcrDraft(name: 'Discard Me'),
        quality: ImageQualityReport({ImageQualityIssue.blurry}),
        usedEnhanced: false,
        shouldWarnQuality: true,
      ),
      const OcrPipelineResult(
        draft: OcrDraft(
          name: 'Keep Me',
          typeDecision: OcrTypeDecision.certainSingle,
          typeReasons: {OcrTypeReason.explicitSingle},
          components: [OcrComponentDraft(country: 'Kenya')],
        ),
        quality: ImageQualityReport(),
        usedEnhanced: false,
        shouldWarnQuality: false,
      ),
    ]);
    await t.pumpWidget(
      wrapApp(const AddHarness(), db: db, photo: photo, pipeline: pipeline),
    );
    await openCamera(t);
    await t.tap(find.byKey(const Key('quality-retake')));
    await t.pumpAndSettle();

    expect(photo.pickCalls, 2);
    expect(pipeline.paths, ['/tmp/first.jpg', '/tmp/second.jpg']);
    expect(find.text('Keep Me'), findsOneWidget);
    expect(find.text('Discard Me'), findsNothing);
  });

  testWidgets(
    'back during analysis keeps spinner and completion proceeds to form',
    (t) async {
      final db = testDatabase();
      addTearDown(db.close);
      final pipeline = ControllableOcrPipeline();
      await t.pumpWidget(
        wrapApp(
          const AddHarness(),
          db: db,
          photo: FakePhotoService(pickResult: '/tmp/a.jpg'),
          pipeline: pipeline,
        ),
      );

      await t.tap(find.byKey(const Key('open-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('add-camera')));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('open-add')), findsOneWidget);

      pipeline.result.complete(
        const OcrPipelineResult(
          draft: OcrDraft(
            name: 'Delayed Single',
            typeDecision: OcrTypeDecision.certainSingle,
            typeReasons: {OcrTypeReason.explicitSingle},
            components: [OcrComponentDraft(country: 'Kenya')],
          ),
          quality: ImageQualityReport(),
          usedEnhanced: false,
          shouldWarnQuality: false,
        ),
      );
      await t.pump();
      await t.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BeanFormScreen), findsOneWidget);
      expect(find.text('Delayed Single'), findsOneWidget);
    },
  );
}
