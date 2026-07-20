import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 막대 한 줄. 라벨 · 트랙(fraction만큼 채움) · 이미 포맷된 수치.
/// 기준값과 표기 규칙은 호출부가 정한다(평점은 5.0 고정·소수 1자리,
/// 빈도는 1위 기준 상대·정수).
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.text,
    this.soft = false,
  });

  final String label;
  final double fraction;
  final String text;

  /// 빈도 막대는 평점 막대와 구분되도록 옅은 그라데이션을 쓴다.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.espresso)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: c.oat,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: soft
                        ? LinearGradient(
                            colors: [c.crema, const Color(0xFFD3A862)])
                        : null,
                    color: soft ? null : c.crema,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 26,
            child: Text(text,
                textAlign: TextAlign.right,
                style: monoStyle(
                    size: 11, weight: FontWeight.w700, color: c.espresso)),
          ),
        ],
      ),
    );
  }
}
