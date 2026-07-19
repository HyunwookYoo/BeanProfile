import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import 'ocr/ocr_draft.dart';
import 'ocr/ocr_parser.dart';
import 'bean_form_screen.dart';

enum _AddChoice { camera, gallery, manual }

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

  final tempPath =
      await ref.read(photoServiceProvider).pick(fromCamera: choice == _AddChoice.camera);
  if (tempPath == null || !context.mounted) return;

  final draft = await _recognize(context, ref, tempPath);
  if (draft == null || !context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BeanFormScreen(draft: draft, photoTempPath: tempPath)));
}

Future<OcrDraft?> _recognize(BuildContext context, WidgetRef ref, String path) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final text = await ref.read(ocrServiceProvider).recognize(path);
    return parseOcrText(text);
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // 스피너 닫기
  }
}
