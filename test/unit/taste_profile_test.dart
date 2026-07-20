import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/profile/taste_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

TasteSnapshot snap({
  List<Bean> beans = const [],
  List<OriginComponent> components = const [],
  List<Tasting> tastings = const [],
}) =>
    TasteSnapshot(beans: beans, components: components, tastings: tastings);

void main() {
  group('빈 상태', () {
    test('완전히 빈 스냅샷 → isEmpty', () {
      final p = computeTasteProfile(snap());
      expect(p.isEmpty, isTrue);
      expect(p.beanCount, 0);
      expect(p.tastingCount, 0);
      expect(p.topBeanRating, isNull);
      expect(p.intensity, isNull);
    });

    test('원두만 있고 시음 0건 → isEmpty지만 beanCount는 센다', () {
      final p = computeTasteProfile(snap(beans: [beanRow(id: 1), beanRow(id: 2)]));
      expect(p.isEmpty, isTrue);
      expect(p.beanCount, 2);
      expect(p.topBeanRating, isNull);
      expect(p.intensity, isNull);
    });
  });

  group('구성 가중치 — 원두 단위 all-or-nothing', () {
    test('구성 전부에 비율이 있으면 ratio/100', () {
      final w = componentWeights([
        compRow(id: 1, country: 'Brazil', ratioPercent: 60),
        compRow(id: 2, country: 'Ethiopia', ratioPercent: 40),
      ]);
      expect(w, [0.6, 0.4]);
    });

    test('하나라도 null이면 전 구성이 1/n', () {
      final w = componentWeights([
        compRow(id: 1, country: 'Brazil', ratioPercent: 60),
        compRow(id: 2, country: 'Ethiopia'), // null
      ]);
      expect(w, [0.5, 0.5]);
    });

    test('싱글 오리진은 비율 유무와 무관하게 1.0', () {
      expect(componentWeights([compRow()]), [1.0]);
      expect(componentWeights([compRow(ratioPercent: 100)]), [1.0]);
    });

    test('구성이 없으면 빈 리스트', () {
      expect(componentWeights(const []), isEmpty);
    });
  });

  group('요약 3숫자', () {
    test('최고 평점 원두 = 시음이 있는 원두별 평균★의 최댓값', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2), beanRow(id: 3)], // 3번은 시음 없음
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 1, overall: 3), // 1번 평균 4.0
          tastingRow(id: 3, beanId: 2, overall: 5), // 2번 평균 5.0
        ],
      ));
      expect(p.beanCount, 3);
      expect(p.tastingCount, 3);
      expect(p.topBeanRating, 5.0);
      expect(p.isEmpty, isFalse);
    });
  });

  group('① 선호 강도', () {
    test('★4+가 있으면 그 시음들만 평균내고 배지는 ★4+ 기준', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 5, acidity: 4, sweetness: 4, body: 2, bitterness: 2),
          tastingRow(id: 2, overall: 4, acidity: 2, sweetness: 2, body: 4, bitterness: 4),
          tastingRow(id: 3, overall: 1, acidity: 5, sweetness: 5, body: 5, bitterness: 5), // 제외
        ],
      ));
      expect(p.intensityHighRatedOnly, isTrue);
      expect(p.intensity!.acidity, 3.0);    // (4+2)/2
      expect(p.intensity!.sweetness, 3.0);
      expect(p.intensity!.body, 3.0);
      expect(p.intensity!.bitterness, 3.0);
    });

    test('★4+가 0건이면 전체 시음으로 폴백하고 배지는 전체 기준', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 3, acidity: 2, sweetness: 2, body: 2, bitterness: 2),
          tastingRow(id: 2, overall: 2, acidity: 4, sweetness: 4, body: 4, bitterness: 4),
        ],
      ));
      expect(p.intensityHighRatedOnly, isFalse);
      expect(p.intensity!.acidity, 3.0);    // (2+4)/2
      expect(p.intensity!.bitterness, 3.0);
    });

    test('★4는 경계값으로 포함된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow()],
        tastings: [
          tastingRow(id: 1, overall: 4, acidity: 5),
          tastingRow(id: 2, overall: 3, acidity: 1), // 제외돼야 함
        ],
      ));
      expect(p.intensityHighRatedOnly, isTrue);
      expect(p.intensity!.acidity, 5.0);
    });
  });
}
