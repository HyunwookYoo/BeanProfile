import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 1–5 종합 별점 입력. 별을 탭하면 그 값으로 설정한다.
class StarInput extends StatelessWidget {
  const StarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 32,
  });
  final int value; // 1–5
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crema = context.colors.crema;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          key: Key('star-$i'),
          onPressed: () => onChanged(i),
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(i <= value ? Icons.star : Icons.star_border, color: crema),
        ),
    ]);
  }
}
