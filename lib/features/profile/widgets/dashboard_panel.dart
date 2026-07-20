import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 대시보드 위젯 하나를 감싸는 카드. `badge`는 계산 기준 표시(예: '★4+ 기준').
/// `badgeHighlighted`가 true면 폴백 중임을 강조한다.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    this.badge,
    this.badgeHighlighted = false,
    required this.child,
  });

  final String title;
  final String? badge;
  final bool badgeHighlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: c.cup,
        border: Border.all(color: c.appLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.espresso)),
              if (badge != null)
                Container(
                  key: const Key('panel-badge'),
                  padding: badgeHighlighted
                      ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: badgeHighlighted
                      ? BoxDecoration(
                          color: const Color(0xFFEAD9BE),
                          border: Border.all(color: c.crema),
                          borderRadius: BorderRadius.circular(7),
                        )
                      : null,
                  child: Text(badge!,
                      style: monoStyle(
                        size: 10,
                        weight:
                            badgeHighlighted ? FontWeight.w700 : FontWeight.w600,
                        color: badgeHighlighted ? c.cremaInk : c.appMuted,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
