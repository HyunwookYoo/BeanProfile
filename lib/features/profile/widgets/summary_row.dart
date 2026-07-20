import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 대시보드 상단 요약 3칸.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.beanCount,
    required this.tastingCount,
    required this.topRating,
  });

  final int beanCount, tastingCount;
  final double? topRating;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Stat(value: '$beanCount', label: '기록한 원두'),
          const SizedBox(width: 10),
          _Stat(value: '$tastingCount', label: '누적 시음'),
          const SizedBox(width: 10),
          _Stat(
            value: topRating == null ? '—' : topRating!.toStringAsFixed(1),
            label: '최고 평점 원두',
            muted: topRating == null,
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.muted = false});
  final String value, label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.cup,
          border: Border.all(color: c.appLine),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: monoStyle(
                    size: 22,
                    weight: FontWeight.w800,
                    color: muted ? c.appMuted : c.espresso)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.appMuted)),
          ],
        ),
      ),
    );
  }
}
