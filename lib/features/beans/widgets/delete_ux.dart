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

/// 원두 삭제 확인 다이얼로그. 사용자가 '삭제'를 누르면 true.
Future<bool> confirmDeleteBeanDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('원두 삭제'),
      content: const Text('이 원두와 모든 시음 기록이 삭제됩니다. 되돌릴 수 없어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
      ],
    ),
  );
  return ok == true;
}
