import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

// 리스트 UI(검색/정렬)만 검증하므로 실제 drift 스트림 대신 beanListProvider를
// Stream.value로 주입한다(M1 bean_list_test·M2 bean_detail_average_test와 동일 패턴).
// 실제 watch 스트림을 위젯 테스트에서 돌리면 drift가 취소 시 debounce 타이머를
// 남겨 'A Timer is still pending' assert로 깨진다. 정렬/검색 순수 로직은
// bean_sort_filter_test.dart(유닛)에서 이미 판별 검증됨.
BeanSummary _sum(int id, String name, {String roaster = '프릳츠', int day = 1, double? rating}) =>
    BeanSummary(
      bean: beanRow(id: id, name: name, roaster: roaster, createdAt: DateTime(2026, 7, day)),
      originLabel: null,
      avgRating: rating,
      tastingCount: rating == null ? 0 : 1,
    );

Widget _host(List<BeanSummary> data) => ProviderScope(
      overrides: [beanListProvider.overrideWith((ref) => Stream.value(data))],
      child: MaterialApp(theme: AppTheme.light, home: const BeanListScreen()),
    );

void main() {
  testWidgets('검색어로 이름·로스터리를 필터링한다', (t) async {
    await t.pumpWidget(_host([
      _sum(1, '예가체프 코체레', roaster: '프릳츠'),
      _sum(2, '수프리모', roaster: '테라로사'),
    ]));
    await t.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('수프리모'), findsOneWidget);

    // 이름 부분일치
    await t.enterText(find.byType(TextField), '예가');
    await t.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('수프리모'), findsNothing);

    // 로스터리로도 검색된다
    await t.enterText(find.byType(TextField), '테라로사');
    await t.pumpAndSettle();
    expect(find.text('수프리모'), findsOneWidget);
    expect(find.text('예가체프 코체레'), findsNothing);
  });

  testWidgets('검색 결과가 없으면 안내한다', (t) async {
    await t.pumpWidget(_host([_sum(1, '예가체프')]));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pumpAndSettle();
    expect(find.textContaining('맞는 원두가 없어요'), findsOneWidget);
  });

  testWidgets('이름순 정렬로 전환하면 순서가 뒤집힌다', (t) async {
    // 하우스=최신(day2), 가나다=오래됨(day1) → 최근순은 하우스가 위,
    // 이름순은 가나다(ㄱ)가 위 → 두 정렬의 순서가 실제로 달라 판별력이 있다.
    await t.pumpWidget(_host([
      _sum(1, '하우스', day: 2),
      _sum(2, '가나다', day: 1),
    ]));
    await t.pumpAndSettle();
    // 기본 최근순: 하우스(최신)가 위
    expect(t.getTopLeft(find.text('하우스')).dy < t.getTopLeft(find.text('가나다')).dy, isTrue);

    await t.tap(find.byIcon(Icons.sort));
    await t.pumpAndSettle();
    await t.tap(find.text('이름순').last);
    await t.pumpAndSettle();

    // 이름순: 가나다(ㄱ<ㅎ)가 위 — 순서가 뒤집혔다
    expect(t.getTopLeft(find.text('가나다')).dy < t.getTopLeft(find.text('하우스')).dy, isTrue);
  });
}
