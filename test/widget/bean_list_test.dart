import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Bean _bean(String name) => Bean(
      id: 1, name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const ['블루베리'],
      photoPath: null, scaScore: null, weightGrams: null, price: null,
      shop: null, memo: null, createdAt: DateTime(2026));

Widget _host(List<BeanSummary> data) => ProviderScope(
      overrides: [
        beanListProvider.overrideWith((ref) => Stream.value(data)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const BeanListScreen()),
    );

void main() {
  testWidgets('renders bean cards', (tester) async {
    await tester.pumpWidget(_host([
      BeanSummary(bean: _bean('예가체프 코체레'), originLabel: 'Ethiopia', avgRating: 4.5, tastingCount: 6),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('블루베리'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 기록한 원두가 없어요'), findsOneWidget);
  });
}
