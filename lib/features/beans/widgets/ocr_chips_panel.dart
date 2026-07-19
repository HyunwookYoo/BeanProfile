import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 인식된 텍스트 칩. 탭하면 '어디에 넣을지' 배정 시트가 열린다. 쓴 칩은 흐려짐.
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
        Text('인식된 텍스트 — 칩을 누르면 어디에 넣을지 물어봐요',
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
