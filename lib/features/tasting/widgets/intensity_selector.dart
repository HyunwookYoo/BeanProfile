import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 1–5 강도 도트 선택기. 도트를 탭하면 그 값으로 설정한다.
class IntensitySelector extends StatelessWidget {
  const IntensitySelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: TextStyle(color: c.espresso))),
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            key: Key('intensity-$label-$i'),
            onTap: () => onChanged(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= value ? c.crema : c.oat,
                border: Border.all(color: c.appLine),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text('$value', style: monoStyle(size: 12, color: c.appMuted)),
      ]),
    );
  }
}
