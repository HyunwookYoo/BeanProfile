import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_sort.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

BeanSummary _s(String name, {String roaster = '', double? rating, int day = 1}) => BeanSummary(
      bean: beanRow(name: name, roaster: roaster, createdAt: DateTime(2026, 7, day)),
      originLabel: null,
      avgRating: rating,
      tastingCount: rating == null ? 0 : 1,
    );

void main() {
  final beans = [
    _s('예가체프', roaster: '프릳츠', rating: 4.2, day: 1),
    _s('수프리모', roaster: '테라로사', rating: 4.8, day: 3),
    _s('하우스 블렌드', roaster: '프릳츠', rating: null, day: 2),
  ];

  test('검색은 이름·로스터리 부분일치(대소문자 무시)', () {
    expect(sortFilterBeans(beans, '예가', BeanSort.recent).map((b) => b.bean.name), ['예가체프']);
    expect(sortFilterBeans(beans, '프릳츠', BeanSort.recent).map((b) => b.bean.name).toSet(),
        {'예가체프', '하우스 블렌드'});
    expect(sortFilterBeans(beans, '없음', BeanSort.recent), isEmpty);
  });

  test('최근순 = createdAt 내림차순', () {
    expect(sortFilterBeans(beans, '', BeanSort.recent).map((b) => b.bean.name),
        ['수프리모', '하우스 블렌드', '예가체프']);
  });

  test('평점순 = 평점 내림차순, 평점 없는 원두는 뒤로', () {
    expect(sortFilterBeans(beans, '', BeanSort.rating).map((b) => b.bean.name),
        ['수프리모', '예가체프', '하우스 블렌드']);
  });

  test('이름순 = 가나다', () {
    expect(sortFilterBeans(beans, '', BeanSort.name).map((b) => b.bean.name),
        ['수프리모', '예가체프', '하우스 블렌드']);
  });

  test('원본 리스트를 변형하지 않는다', () {
    final original = [...beans];
    sortFilterBeans(beans, '', BeanSort.name);
    expect(beans, original); // 순서 그대로
  });
}
