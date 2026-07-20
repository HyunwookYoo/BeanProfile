import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
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

  group('②원산지 · ④가공방식 — 가중 평균', () {
    test('싱글 오리진 여러 개는 국가별 산술평균', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Ethiopia'),
          compRow(id: 2, beanId: 2, country: 'Ethiopia'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 3),
        ],
      ));
      expect(p.byCountry.single.label, 'Ethiopia');
      expect(p.byCountry.single.value, 4.0);
    });

    test('블렌드 60/40 비율이 국가별 가중평균에 반영된다', () {
      // 블렌드1(Brazil 60 / Ethiopia 40) ★5, 싱글2(Ethiopia) ★1
      // Ethiopia = (5*0.4 + 1*1.0) / (0.4 + 1.0) = 3.0 / 1.4 ≈ 2.142857
      // Brazil    = (5*0.6) / 0.6 = 5.0
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Brazil', ratioPercent: 60),
          compRow(id: 2, beanId: 1, country: 'Ethiopia', ratioPercent: 40),
          compRow(id: 3, beanId: 2, country: 'Ethiopia'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 1),
        ],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Ethiopia']);
      expect(p.byCountry[0].value, 5.0);
      expect(p.byCountry[1].value, closeTo(3.0 / 1.4, 1e-9));
    });

    test('비율이 하나라도 비면 그 원두는 균등(1/n)으로 계산된다', () {
      // 블렌드(Brazil 60 / Ethiopia null) ★5 → 둘 다 w=0.5 → 각각 평균 5.0
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Brazil', ratioPercent: 60),
          compRow(id: 2, beanId: 1, country: 'Ethiopia'),
        ],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Ethiopia']);
      expect(p.byCountry[0].value, 5.0);
      expect(p.byCountry[1].value, 5.0);
    });

    test('가공방식은 한국어 라벨로 집계된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, process: Process.natural),
          compRow(id: 2, beanId: 2, process: Process.washed),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 2, overall: 3),
        ],
      ));
      expect(p.byProcess.map((b) => b.label), ['내추럴', '워시드']);
      expect(p.byProcess[0].value, 5.0);
      expect(p.byProcess[1].value, 3.0);
    });

    test('동점이면 라벨 오름차순으로 정렬된다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1), beanRow(id: 2)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Kenya'),
          compRow(id: 2, beanId: 2, country: 'Brazil'),
        ],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 4),
          tastingRow(id: 2, beanId: 2, overall: 4),
        ],
      ));
      expect(p.byCountry.map((b) => b.label), ['Brazil', 'Kenya']);
    });

    test('비율 0%인 구성은 국가·가공 집계에서 제외된다 (0/0 = NaN 방지)', () {
      // 블렌드(Brazil 0%/내추럴, Ethiopia 100%/워시드) ★5.
      // Brazil·내추럴은 weight=0이고 다른 기여가 없으므로 키 자체가 생기면 안 된다.
      // Ethiopia·워시드는 100%라 진짜 평균(5.0)이 그대로 나와야 한다.
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1)],
        components: [
          compRow(id: 1, beanId: 1, country: 'Brazil', process: Process.natural, ratioPercent: 0),
          compRow(id: 2, beanId: 1, country: 'Ethiopia', process: Process.washed, ratioPercent: 100),
        ],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.byCountry.map((b) => b.value).toList(), [5.0]);
      expect(p.byCountry.map((b) => b.label).toList(), ['Ethiopia']);
      expect(p.byProcess.map((b) => b.value).toList(), [5.0]);
      expect(p.byProcess.map((b) => b.label).toList(), ['워시드']);
    });
  });

  group('③ 선호 컵노트 — 원두 1표', () {
    test('평균★ 4 이상 원두의 태그만 세고 원두당 1표', () {
      // 원두1(평균 4.5, 블루베리·자스민) 시음 2회 / 원두2(평균 2.0, 초콜릿)
      final p = computeTasteProfile(snap(
        beans: [
          beanRow(id: 1, cupNotes: ['블루베리', '자스민']),
          beanRow(id: 2, cupNotes: ['초콜릿']),
        ],
        components: [compRow(id: 1, beanId: 1), compRow(id: 2, beanId: 2)],
        tastings: [
          tastingRow(id: 1, beanId: 1, overall: 5),
          tastingRow(id: 2, beanId: 1, overall: 4),
          tastingRow(id: 3, beanId: 2, overall: 2),
        ],
      ));
      expect(p.cupNotesHighRatedOnly, isTrue);
      // 2회 마셨어도 원두 1표 → 각 1. 동점이라 라벨 오름차순(블 < 자).
      expect(p.cupNotes.map((b) => b.label), ['블루베리', '자스민']);
      expect(p.cupNotes.every((b) => b.value == 1.0), isTrue);
    });

    test('한 원두 안의 중복 태그는 1회만 센다', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1, cupNotes: ['블루베리', '블루베리'])],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes.single.value, 1.0);
    });

    test('평균★ 4 이상 원두가 없으면 시음이 있는 전체 원두로 폴백', () {
      final p = computeTasteProfile(snap(
        beans: [
          beanRow(id: 1, cupNotes: ['초콜릿']),
          beanRow(id: 2, cupNotes: ['견과']), // 시음 없음 → 폴백 대상 아님
        ],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 2)],
      ));
      expect(p.cupNotesHighRatedOnly, isFalse);
      expect(p.cupNotes.map((b) => b.label), ['초콜릿']);
    });

    test('컵노트가 하나도 없으면 빈 리스트(패널만 빈다)', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1)],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes, isEmpty);
      expect(p.byCountry, isNotEmpty); // 다른 패널은 정상
    });

    test('빈도 동점이면 라벨 오름차순', () {
      final p = computeTasteProfile(snap(
        beans: [beanRow(id: 1, cupNotes: ['자스민', '감귤'])],
        components: [compRow(id: 1, beanId: 1)],
        tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
      ));
      expect(p.cupNotes.map((b) => b.label), ['감귤', '자스민']);
    });
  });
}
