import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('shows a zero-component blend detail without origin rows',
      (tester) async {
    final bean = Bean(
      id: 8, name: '비공개 블렌드', roaster: '프릳츠', type: BeanType.blend,
      roastLevel: null, roastDate: null, cupNotes: const [],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));
    final detail =
        BeanDetail(bean: bean, components: const [], tastings: const []);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        beanDetailProvider(8).overrideWith((ref) => Stream.value(detail)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BeanDetailScreen(beanId: 8),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('비공개 블렌드'), findsOneWidget);
    expect(find.textContaining('블렌드'), findsWidgets);
    expect(find.text('원산지'), findsNothing);
    expect(find.textContaining('아직 시음 기록이 없어요'), findsOneWidget);
  });

  testWidgets('shows profile spec and empty tasting state', (tester) async {
    final bean = Bean(
      id: 7, name: '예가체프 코체레', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null, cupNotes: const ['블루베리'],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));
    final comp = OriginComponent(
      id: 1, beanId: 7, country: 'Ethiopia', region: 'Yirgacheffe',
      farm: null, variety: 'Heirloom', process: Process.washed,
      altitude: '1900m', ratioPercent: null);
    final detail = BeanDetail(bean: bean, components: [comp], tastings: const []);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(7).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 7)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.textContaining('Ethiopia'), findsWidgets);
    expect(find.textContaining('아직 시음 기록이 없어요'), findsOneWidget);
  });

  testWidgets('시음 카드가 계산·수동·없음·음수를 한 목록에서 각각 맞게 그린다', (tester) async {
    final bean = beanRow(id: 9, name: '구지', roastDate: DateTime(2026, 7, 19));
    final detail = BeanDetail(bean: bean, components: const [], tastings: [
      tastingRow(id: 1, beanId: 9, date: DateTime(2026, 7, 27)), // 계산 → 8일
      tastingRow(id: 2, beanId: 9, date: DateTime(2026, 7, 19)), // 계산 → 당일
      tastingRow(id: 3, beanId: 9, date: DateTime(2026, 7, 15)), // 계산 → 음수
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(9).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 9)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 8일'), findsOneWidget);
    expect(find.text('당일'), findsOneWidget);
    expect(find.text('날짜 확인'), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-1')), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-3')), findsOneWidget);
  });

  testWidgets('로스팅 날짜가 없으면 입력값을 쓰고, 그것도 없으면 알약이 없다', (tester) async {
    final bean = beanRow(id: 10, name: '무명', roastDate: null);
    final detail = BeanDetail(bean: bean, components: const [], tastings: [
      tastingRow(id: 4, beanId: 10, degassingDays: 12),
      tastingRow(id: 5, beanId: 10), // 로스팅 날짜도 입력값도 없음
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(10).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 10)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('디개싱 12일'), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-4')), findsOneWidget);
    expect(find.byKey(const Key('degassing-pill-5')), findsNothing,
        reason: '보여줄 게 없으면 알약 자체가 없어야 한다');
  });
}
