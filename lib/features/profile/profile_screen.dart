import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'taste_profile.dart';
import 'widgets/bar_row.dart';
import 'widgets/dashboard_panel.dart';
import 'widgets/intensity_radar.dart';
import 'widgets/summary_row.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(tasteProfileProvider);
    return Scaffold(
      appBar: AppBar(
          title: const Text('내 취향',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SummaryRow(
              beanCount: p.beanCount,
              tastingCount: p.tastingCount,
              topRating: p.topBeanRating,
            ),
            const SizedBox(height: 14),
            if (p.isEmpty)
              const _EmptyAll()
            else ...[
              DashboardPanel(
                title: '선호 강도',
                badge: p.intensityHighRatedOnly ? '★4+ 기준' : '전체 기준',
                badgeHighlighted: !p.intensityHighRatedOnly,
                child: IntensityRadar(intensity: p.intensity!),
              ),
              DashboardPanel(
                title: '원산지별 평균 평점',
                child: _RatingBars(bars: p.byCountry, empty: '원산지 정보가 없어요'),
              ),
              DashboardPanel(
                title: '선호 컵노트',
                badge: p.cupNotesHighRatedOnly ? '★4+ 빈도' : '전체 빈도',
                badgeHighlighted: !p.cupNotesHighRatedOnly,
                child: _CountBars(bars: p.cupNotes),
              ),
              DashboardPanel(
                title: '가공방식별 평점',
                child: _RatingBars(bars: p.byProcess, empty: '가공방식 정보가 없어요'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 평점 막대 — 트랙 100%는 별점 만점(5.0) 고정, 수치는 소수점 1자리.
class _RatingBars extends StatelessWidget {
  const _RatingBars({required this.bars, required this.empty});
  final List<Bar> bars;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return _PanelEmpty(message: empty);
    return Column(
      children: [
        for (final b in bars)
          BarRow(
            label: b.label,
            fraction: b.value / 5.0,
            text: b.value.toStringAsFixed(1),
          ),
      ],
    );
  }
}

/// 빈도 막대 — 트랙 100%는 1위 값 기준 상대, 수치는 정수.
class _CountBars extends StatelessWidget {
  const _CountBars({required this.bars});
  final List<Bar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const _PanelEmpty(
          message: '컵노트가 기록된 원두가 없어요\n원두를 편집해 컵노트를 추가해 보세요');
    }
    final top = bars.first.value; // 정렬이 값 내림차순이라 첫 항목이 최댓값
    return Column(
      children: [
        for (final b in bars)
          BarRow(
            label: b.label,
            fraction: b.value / top,
            text: b.value.toStringAsFixed(0),
            soft: true,
          ),
      ],
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5, height: 1.55, color: context.colors.appMuted)),
      );
}

class _EmptyAll extends StatelessWidget {
  const _EmptyAll();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: c.cup,
        border: Border.all(color: c.appLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(Icons.coffee_outlined, size: 34, color: c.appLine),
          const SizedBox(height: 10),
          Text('아직 시음 기록이 없어요',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.espresso)),
          const SizedBox(height: 6),
          Text('원두를 열고 시음을 추가하면\n취향 분석이 여기에 나타납니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.7, color: c.appMuted)),
        ],
      ),
    );
  }
}
