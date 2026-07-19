import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

/// 스파이크 전용 임시 화면: 사진 → OCR → 원문 표시. Task 6에서 제거.
class DebugOcrScreen extends ConsumerStatefulWidget {
  const DebugOcrScreen({super.key});
  @override
  ConsumerState<DebugOcrScreen> createState() => _DebugOcrScreenState();
}

class _DebugOcrScreenState extends ConsumerState<DebugOcrScreen> {
  String _text = '아직 없음';
  bool _busy = false;

  Future<void> _run(bool camera) async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(photoServiceProvider).pick(fromCamera: camera);
      if (path == null) { setState(() { _busy = false; _text = '취소됨'; }); return; }
      final text = await ref.read(ocrServiceProvider).recognize(path);
      setState(() { _busy = false; _text = text.isEmpty ? '(인식 텍스트 없음)' : text; });
    } catch (e) {
      setState(() { _busy = false; _text = '오류: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR 디버그(임시)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: _busy ? null : () => _run(true), child: const Text('촬영')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : () => _run(false), child: const Text('갤러리')),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          Expanded(child: SingleChildScrollView(child: SelectableText(_text))),
        ]),
      ),
    );
  }
}
