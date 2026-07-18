import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Dismissible 스와이프-삭제의 빨간 배경 (trailing 정렬). 시음·원두 공용.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: c.cherry,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_outline, color: Colors.white, size: 20),
        SizedBox(width: 6),
        Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
