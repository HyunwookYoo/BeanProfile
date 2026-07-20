import 'package:beanprofile/features/profile/widgets/bar_row.dart';
import 'package:beanprofile/features/profile/widgets/dashboard_panel.dart';
import 'package:beanprofile/features/profile/widgets/summary_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('SummaryRow는 3개 수치와 라벨을 보여준다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: SummaryRow(beanCount: 6, tastingCount: 14, topRating: 4.65),
    )));
    expect(find.text('6'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget); // 소수점 1자리
    expect(find.text('기록한 원두'), findsOneWidget);
    expect(find.text('누적 시음'), findsOneWidget);
    expect(find.text('최고 평점 원두'), findsOneWidget);
  });

  testWidgets('SummaryRow는 topRating이 null이면 —', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: SummaryRow(beanCount: 3, tastingCount: 0, topRating: null),
    )));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('DashboardPanel은 제목과 배지를 보여준다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: DashboardPanel(
          title: '선호 강도', badge: '★4+ 기준', child: Text('내용')),
    )));
    expect(find.text('선호 강도'), findsOneWidget);
    expect(find.text('★4+ 기준'), findsOneWidget);
    expect(find.text('내용'), findsOneWidget);
  });

  testWidgets('DashboardPanel은 배지가 없으면 제목만', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: DashboardPanel(title: '원산지별 평균 평점', child: Text('내용')),
    )));
    expect(find.text('원산지별 평균 평점'), findsOneWidget);
    expect(find.byKey(const Key('panel-badge')), findsNothing);
  });

  testWidgets('BarRow는 fraction만큼 트랙을 채운다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: '에티오피아', fraction: 0.92, text: '4.6'),
    )));
    expect(find.text('에티오피아'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 0.92);
  });

  testWidgets('BarRow는 fraction을 0~1로 클램프한다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: '초과', fraction: 1.8, text: '9.0'),
    )));
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 1.0);
  });

  testWidgets('BarRow는 fraction이 NaN이면 빈 막대로 그린다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: 'NaN', fraction: double.nan, text: '-'),
    )));
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 0.0);
  });

  testWidgets('BarRow는 fraction이 음수면 0으로 클램프한다', (t) async {
    await t.pumpWidget(wrapApp(const Scaffold(
      body: BarRow(label: '음수', fraction: -0.5, text: '0.0'),
    )));
    final fill = t.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 0.0);
  });
}
