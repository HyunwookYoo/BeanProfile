import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/enums.dart';
import '../../providers.dart';
import 'bean_form_screen.dart';
import 'ocr/ocr_pipeline.dart';

enum _AddChoice { camera, gallery, manual }
enum _QualityChoice { continueWithResult, retake }

/// FAB에서 호출: 촬영/갤러리 → OCR → 폼, 또는 직접 입력.
Future<void> showAddBeanSheet(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: const Key('add-camera'),
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('촬영'),
          subtitle: const Text('봉투·정보 카드를 찍어 자동 인식'),
          onTap: () => Navigator.pop(context, _AddChoice.camera),
        ),
        ListTile(
          key: const Key('add-gallery'),
          leading: const Icon(Icons.image_outlined),
          title: const Text('갤러리에서 선택'),
          subtitle: const Text('저장된 사진에서'),
          onTap: () => Navigator.pop(context, _AddChoice.gallery),
        ),
        ListTile(
          key: const Key('add-manual'),
          leading: const Icon(Icons.edit_outlined),
          title: const Text('직접 입력'),
          subtitle: const Text('사진 없이 수동으로'),
          onTap: () => Navigator.pop(context, _AddChoice.manual),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == _AddChoice.manual) {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BeanFormScreen()));
    return;
  }

  while (context.mounted) {
    final tempPath = await ref
        .read(photoServiceProvider)
        .pick(fromCamera: choice == _AddChoice.camera);
    if (tempPath == null || !context.mounted) return;

    final result = await _analyze(context, ref, tempPath);
    if (result == null || !context.mounted) return;

    if (result.shouldWarnQuality) {
      final qualityChoice = await _showQualityWarning(context);
      if (!context.mounted || qualityChoice == null) return;
      if (qualityChoice == _QualityChoice.retake) continue;
    }

    var type = result.draft.inferredType;
    type ??= await _confirmBeanType(context);
    if (type == null || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BeanFormScreen(
        draft: result.draft,
        initialType: type,
        photoTempPath: tempPath,
      ),
    ));
    return;
  }
}

Future<OcrPipelineResult?> _analyze(
    BuildContext context, WidgetRef ref, String path) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator())));
  try {
    return await ref.read(ocrPipelineProvider).analyze(path);
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // 스피너 닫기
  }
}

Future<_QualityChoice?> _showQualityWarning(BuildContext context) {
  return showDialog<_QualityChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('사진을 충분히 읽지 못했어요'),
      content: const Text('사진이 어둡거나 흐리거나 빛이 반사됐을 수 있어요.'),
      actions: [
        TextButton(
          key: const Key('quality-retake'),
          onPressed: () => Navigator.pop(dialogContext, _QualityChoice.retake),
          child: const Text('다시 촬영'),
        ),
        FilledButton(
          key: const Key('quality-continue'),
          onPressed: () =>
              Navigator.pop(dialogContext, _QualityChoice.continueWithResult),
          child: const Text('인식 결과로 계속'),
        ),
      ],
    ),
  );
}

Future<BeanType?> _confirmBeanType(BuildContext context) {
  return showDialog<BeanType>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('원두 유형을 확인해 주세요'),
      actions: [
        TextButton(
          key: const Key('confirm-type-single'),
          onPressed: () => Navigator.pop(dialogContext, BeanType.singleOrigin),
          child: const Text('싱글 오리진'),
        ),
        FilledButton(
          key: const Key('confirm-type-blend'),
          onPressed: () => Navigator.pop(dialogContext, BeanType.blend),
          child: const Text('블렌드'),
        ),
      ],
    ),
  );
}
