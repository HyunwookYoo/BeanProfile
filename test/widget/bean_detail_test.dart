import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
