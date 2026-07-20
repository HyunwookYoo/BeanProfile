import '../../data/database.dart';
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

  return TasteProfile(
    beanCount: snap.beans.length,
    tastingCount: tastings.length,
    topBeanRating: topBeanRating,
    intensity: intensity,
    intensityHighRatedOnly: intensityHighRatedOnly,
    byCountry: const [], // Task 3에서 채운다
    cupNotes: const [], // Task 3에서 채운다
    byProcess: const [], // Task 3에서 채운다
    cupNotesHighRatedOnly: false, // Task 3에서 채운다
  );
}
