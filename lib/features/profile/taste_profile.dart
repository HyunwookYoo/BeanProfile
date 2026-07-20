import '../../data/database.dart';
import '../../data/enums.dart';
import '../../data/models.dart';

/// 강도 4축 평균 (1~5).
class Intensity {
  final double acidity, sweetness, body, bitterness;
  const Intensity({
    required this.acidity,
    required this.sweetness,
    required this.body,
    required this.bitterness,
  });
}

/// 막대 한 줄. `value`의 의미(평점 0~5 / 빈도 정수)와 표기는 소비자가 정한다.
class Bar {
  final String label;
  final double value;
  const Bar(this.label, this.value);
}

/// 대시보드가 그리는 데 필요한 모든 값. 계산은 전부 `computeTasteProfile`에서 끝난다.
class TasteProfile {
  final int beanCount, tastingCount;
  final double? topBeanRating;
  final Intensity? intensity;
  final bool intensityHighRatedOnly;
  final List<Bar> byCountry, cupNotes, byProcess;
  final bool cupNotesHighRatedOnly;

  const TasteProfile({
    required this.beanCount,
    required this.tastingCount,
    required this.topBeanRating,
    required this.intensity,
    required this.intensityHighRatedOnly,
    required this.byCountry,
    required this.cupNotes,
    required this.byProcess,
    required this.cupNotesHighRatedOnly,
  });

  /// 시음이 0건이면 계산할 취향이 없다 — 원두만 등록된 경우도 포함.
  bool get isEmpty => tastingCount == 0;
}

/// 한 원두의 구성별 가중치.
///
/// 구성 **전부**에 비율이 있으면 `ratio/100`, **하나라도** 비어 있으면 전 구성이 `1/n`.
/// 부분적으로 채워진 비율을 추측해 메우지 않는다(원두 단위 all-or-nothing).
/// 싱글 오리진은 n=1이라 항상 1.0.
List<double> componentWeights(List<OriginComponent> comps) {
  if (comps.isEmpty) return const [];
  if (comps.any((c) => c.ratioPercent == null)) {
    return List.filled(comps.length, 1 / comps.length);
  }
  return [for (final c in comps) c.ratioPercent! / 100];
}

Intensity _meanIntensity(List<Tasting> ts) {
  double avg(int Function(Tasting) f) =>
      ts.map(f).reduce((a, b) => a + b) / ts.length;
  return Intensity(
    acidity: avg((t) => t.acidity),
    sweetness: avg((t) => t.sweetness),
    body: avg((t) => t.body),
    bitterness: avg((t) => t.bitterness),
  );
}

double _meanOverall(List<Tasting> ts) =>
    ts.map((t) => t.overall).reduce((a, b) => a + b) / ts.length;

class _WeightedMean {
  double _sum = 0, _weight = 0;
  void add(double value, double w) {
    _sum += value * w;
    _weight += w;
  }

  double get mean => _sum / _weight;
}

/// 값 내림차순, 동점이면 라벨 오름차순 — 순서를 결정적으로 만들어 테스트 가능하게 한다.
List<Bar> _sorted(Iterable<Bar> bars) {
  final list = bars.toList();
  list.sort((a, b) {
    final byValue = b.value.compareTo(a.value);
    return byValue != 0 ? byValue : a.label.compareTo(b.label);
  });
  return list;
}

/// 스냅샷 → 대시보드 값. 순수 함수(DB·Flutter 무관) — 예외를 던지지 않는다.
TasteProfile computeTasteProfile(TasteSnapshot snap) {
  final tastings = snap.tastings;

  if (tastings.isEmpty) {
    return TasteProfile(
      beanCount: snap.beans.length,
      tastingCount: 0,
      topBeanRating: null,
      intensity: null,
      intensityHighRatedOnly: false,
      byCountry: const [],
      cupNotes: const [],
      byProcess: const [],
      cupNotesHighRatedOnly: false,
    );
  }

  // ① 선호 강도 — ★4+ 우선, 0건이면 전체 시음으로 폴백(배지로 기준을 드러낸다).
  final highRated = tastings.where((t) => t.overall >= 4).toList();
  final intensityHighRatedOnly = highRated.isNotEmpty;
  final intensity =
      _meanIntensity(intensityHighRatedOnly ? highRated : tastings);

  // 원두별 시음 인덱스 — 요약과 ③컵노트가 함께 쓴다.
  final tastingsOf = <int, List<Tasting>>{};
  for (final t in tastings) {
    (tastingsOf[t.beanId] ??= []).add(t);
  }
  final topBeanRating = tastingsOf.values
      .map(_meanOverall)
      .reduce((a, b) => a > b ? a : b);

  // 원두별 구성 인덱스.
  final componentsOf = <int, List<OriginComponent>>{};
  for (final c in snap.components) {
    (componentsOf[c.beanId] ??= []).add(c);
  }

  // ②④ — 시음 × 그 원두의 각 구성으로 펼쳐 가중 평균.
  // 가중치는 평균의 분모·분자에 함께 들어가므로, 어떤 키가 항상 낮은 비중으로만
  // 등장해도 평균 자체는 왜곡되지 않는다.
  final countries = <String, _WeightedMean>{};
  final processes = <Process, _WeightedMean>{};
  for (final t in tastings) {
    final comps = componentsOf[t.beanId] ?? const <OriginComponent>[];
    final weights = componentWeights(comps);
    for (var i = 0; i < comps.length; i++) {
      // 0%(또는 음수) 비율 구성은 실제로 기여한 게 없으므로 집계 키를 만들지 않는다
      // — 안 그러면 이 키의 유일한 기여가 weight=0일 때 평균이 0/0 = NaN이 된다.
      if (weights[i] <= 0) continue;
      final overall = t.overall.toDouble();
      (countries[comps[i].country] ??= _WeightedMean()).add(overall, weights[i]);
      (processes[comps[i].process] ??= _WeightedMean()).add(overall, weights[i]);
    }
  }

  // ③ 컵노트 — 평균★ ≥ 4 인 원두 1표. 0개면 시음이 있는 전체 원두로 폴백.
  final ratedBeans =
      snap.beans.where((b) => tastingsOf.containsKey(b.id)).toList();
  final lovedBeans = ratedBeans
      .where((b) => _meanOverall(tastingsOf[b.id]!) >= 4)
      .toList();
  final cupNotesHighRatedOnly = lovedBeans.isNotEmpty;
  final noteCounts = <String, int>{};
  for (final b in (cupNotesHighRatedOnly ? lovedBeans : ratedBeans)) {
    for (final note in b.cupNotes.toSet()) {
      // 원두 안 중복 태그는 1회
      noteCounts[note] = (noteCounts[note] ?? 0) + 1;
    }
  }

  return TasteProfile(
    beanCount: snap.beans.length,
    tastingCount: tastings.length,
    topBeanRating: topBeanRating,
    intensity: intensity,
    intensityHighRatedOnly: intensityHighRatedOnly,
    byCountry: _sorted(
        countries.entries.map((e) => Bar(e.key, e.value.mean))),
    cupNotes: _sorted(
        noteCounts.entries.map((e) => Bar(e.key, e.value.toDouble()))),
    byProcess: _sorted(
        processes.entries.map((e) => Bar(e.key.label, e.value.mean))),
    cupNotesHighRatedOnly: cupNotesHighRatedOnly,
  );
}
