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
  testWidgets('detail shows average rating and tasting count', (tester) async {
    final bean = Bean(
        id: 7, name: '예가체프 코체레', roaster: '프릳츠', type: BeanType.singleOrigin,
        roastLevel: RoastLevel.lightMedium, roastDate: null, cupNotes: const [],
        photoPath: null, scaScore: null, weightGrams: null, price: null,
        shop: null, memo: null, createdAt: DateTime(2026));
    Tasting t(int id, int overall) => Tasting(
        id: id, beanId: 7, date: DateTime(2026, 7, id),
        acidity: 4, sweetness: 3, body: 3, bitterness: 2, overall: overall,
        comment: null, createdAt: DateTime(2026));
    final detail = BeanDetail(bean: bean, components: const [], tastings: [t(1, 4), t(2, 2)]);

    await tester.pumpWidget(ProviderScope(
      overrides: [beanDetailProvider(7).overrideWith((ref) => Stream.value(detail))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanDetailScreen(beanId: 7)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('시음 2회'), findsOneWidget);
    expect(find.text('3.0'), findsWidgets); // 평균 (4+2)/2 = 3.0, StarRating이 렌더
  });
}
