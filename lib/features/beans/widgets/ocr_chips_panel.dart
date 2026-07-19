import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 인식된 텍스트 칩. 활성(포커스) 텍스트 필드에 탭으로 배정. 쓴 칩은 흐려짐.
class OcrChipsPanel extends StatelessWidget {
  const OcrChipsPanel({super.key, required this.chips, required this.used, required this.onTap});
  final List<String> chips;
  final Set<String> used;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.crema, style: BorderStyle.solid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('인식된 텍스트 — 채울 칸을 탭한 뒤 칩을 누르세요',
            style: TextStyle(fontSize: 11, color: c.cremaInk, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final chip in chips)
            ActionChip(
              key: Key('chip-$chip'),
              label: Text(chip),
              onPressed: used.contains(chip) ? null : () => onTap(chip),
              backgroundColor: used.contains(chip) ? c.oat : c.crema,
            ),
        ]),
      ]),
    );
  }
}
