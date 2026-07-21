import '../../data/models.dart';

enum BeanSort { recent, rating, name }

extension BeanSortLabel on BeanSort {
  String get label => switch (this) {
        BeanSort.recent => '최근순',
        BeanSort.rating => '평점순',
        BeanSort.name => '이름순',
      };
}

/// 스트림 리스트에 검색어 필터 + 정렬을 적용한다. 원본은 변형하지 않는다.
/// 검색 = 이름·로스터리 부분일치(대소문자 무시). 동점은 최근순으로 깬다.
List<BeanSummary> sortFilterBeans(List<BeanSummary> beans, String query, BeanSort sort) {
  final q = query.trim().toLowerCase();
  final list = q.isEmpty
      ? [...beans]
      : beans
          .where((b) =>
              b.bean.name.toLowerCase().contains(q) ||
              b.bean.roaster.toLowerCase().contains(q))
          .toList();

  int recent(BeanSummary a, BeanSummary b) => b.bean.createdAt.compareTo(a.bean.createdAt);

  switch (sort) {
    case BeanSort.recent:
      list.sort(recent);
    case BeanSort.rating:
      list.sort((a, b) {
        final ar = a.avgRating, br = b.avgRating;
        if (ar == null && br == null) return recent(a, b);
        if (ar == null) return 1; // 평점 없는 원두는 뒤로
        if (br == null) return -1;
        final c = br.compareTo(ar);
        return c != 0 ? c : recent(a, b);
      });
    case BeanSort.name:
      list.sort((a, b) {
        final c = a.bean.name.toLowerCase().compareTo(b.bean.name.toLowerCase());
        return c != 0 ? c : recent(a, b);
      });
  }
  return list;
}
