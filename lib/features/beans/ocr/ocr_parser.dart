import '../../../data/enums.dart';
import '../../../services/ocr_service.dart';
import 'ocr_draft.dart';

/// 원산지 사전: 소문자 키워드 → 표준 표기. 복합어(Costa Rica)를 먼저.
const Map<String, String> _countries = {
  'costa rica': 'Costa Rica', '코스타리카': 'Costa Rica',
  'el salvador': 'El Salvador', '엘살바도르': 'El Salvador',
  'ethiopia': 'Ethiopia', '에티오피아': 'Ethiopia',
  'colombia': 'Colombia', '콜롬비아': 'Colombia',
  'kenya': 'Kenya', '케냐': 'Kenya',
  'brazil': 'Brazil', '브라질': 'Brazil',
  'guatemala': 'Guatemala', '과테말라': 'Guatemala',
  'panama': 'Panama', '파나마': 'Panama',
  'honduras': 'Honduras', '온두라스': 'Honduras',
  'indonesia': 'Indonesia', '인도네시아': 'Indonesia',
  'rwanda': 'Rwanda', '르완다': 'Rwanda',
  'burundi': 'Burundi', '부룬디': 'Burundi',
  'peru': 'Peru', '페루': 'Peru',
  'nicaragua': 'Nicaragua', '니카라과': 'Nicaragua',
  'yemen': 'Yemen', '예멘': 'Yemen',
  'tanzania': 'Tanzania', '탄자니아': 'Tanzania',
  'mexico': 'Mexico', '멕시코': 'Mexico',
  'uganda': 'Uganda', '우간다': 'Uganda',
  'bolivia': 'Bolivia', '볼리비아': 'Bolivia',
  'ecuador': 'Ecuador', '에콰도르': 'Ecuador',
};

/// 복합어(라이트미디엄·미디엄다크·풀시티)를 단일어보다 먼저.
const Map<String, RoastLevel> _roastKeywords = {
  '라이트미디엄': RoastLevel.lightMedium, 'light medium': RoastLevel.lightMedium,
  'light-medium': RoastLevel.lightMedium, 'cinnamon': RoastLevel.lightMedium,
  '미디엄다크': RoastLevel.mediumDark, 'medium dark': RoastLevel.mediumDark,
  'medium-dark': RoastLevel.mediumDark, 'full city': RoastLevel.mediumDark, '풀시티': RoastLevel.mediumDark,
  '미디엄': RoastLevel.medium, 'medium': RoastLevel.medium, 'city': RoastLevel.medium, '시티': RoastLevel.medium,
  '라이트': RoastLevel.light, 'light': RoastLevel.light,
  '다크': RoastLevel.dark, 'dark': RoastLevel.dark, 'french': RoastLevel.dark, 'italian': RoastLevel.dark,
};

const Map<String, Process> _processKeywords = {
  '워시드': Process.washed, 'washed': Process.washed, '수세식': Process.washed,
  '내추럴': Process.natural, 'natural': Process.natural, '건식': Process.natural,
  '허니': Process.honey, 'honey': Process.honey,
  '무산소': Process.anaerobic, 'anaerobic': Process.anaerobic, '애너로빅': Process.anaerobic,
};

final List<RegExp> _datePatterns = [
  RegExp(r'(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),      // 2026-07-02
  RegExp(r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일'), // 2026년 7월 2일
  RegExp(r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),        // 26.07.02
];

final RegExp _noteLabel = RegExp(
  r'^(cup\s*notes?|tasting\s*notes?|notes?|컵\s*노트|노트|향미)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);

final RegExp _regionLabel = RegExp(
  r'^(region|지역)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);

final RegExp _nameLabel = RegExp(
  r'^(제품명|상품명|product\s*name|name)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);

final RegExp _roasterLabel = RegExp(
  r'^(로스터리|로스터|roaster)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);

const Set<String> _regionTokens = {'지역', 'region'};
const Set<String> _cupTokens = {
  '컵노트', '컵 노트', 'notes', 'cup notes', 'cup note', 'tasting notes', '향미',
};
const Set<String> _otherLabelTokens = {
  '원산지','생산지','품종','가공','가공방식','로스팅','로스팅일','고도','제품명','상품명','로스터리','로스터','중량',
  'origin','variety','varietal','process','roast','roast date','roasted','altitude','name','product name','roaster',
};

final RegExp _trailingColon = RegExp(r'[:：]\s*$');

/// 트림·소문자·후행 콜론 제거 정규화.
String _norm(String text) => text.trim().toLowerCase().replaceAll(_trailingColon, '').trim();

/// 값 줄이 라벨로 오인되지 않도록: 정규화 텍스트가 region/cupNotes 토큰과 정확히 일치.
bool _isBareLabel(String text) {
  final t = _norm(text);
  return _regionTokens.contains(t) || _cupTokens.contains(t);
}

/// 알려진 모든 라벨(지역·컵노트 + 그 외 카드 라벨). `_isBareLabel`이 찾는 "공간 매칭 대상
/// 라벨"보다 넓게, "값으로 오채움하면 안 되는 줄"을 가르는 데 쓴다(값 후보 제외 + 아래-폴백 차단).
bool _isLabel(String text) => _isBareLabel(text) || _otherLabelTokens.contains(_norm(text));

/// 토큰의 바레-라벨 줄을 찾아 공간적으로 값을 매칭.
String? _spatialValue(List<OcrLine> lines, Set<String> tokens) {
  for (final label in lines) {
    final t = _norm(label.text);
    if (!tokens.contains(t)) continue;
    final v = _valueFor(lines, label);
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// 라벨 줄의 값: ① 같은 행·오른쪽 → 없으면 ② 바로 아래(최근접). 두 탐색 모두 다른 라벨
/// 줄은 값 후보에서 제외하고, ②는 추가로 라벨과 후보 사이에 다른 라벨이 끼어 있으면
/// 차단해 인접 라벨을 값으로 오채움하지 않는다.
String? _valueFor(List<OcrLine> lines, OcrLine label) {
  final h = label.height <= 0 ? 1.0 : label.height;
  OcrLine? best;
  for (final v in lines) {
    if (identical(v, label) || v.text.trim().isEmpty || _isLabel(v.text)) continue;
    final aligned = (v.centerY - label.centerY).abs() <= 0.6 * h;
    if (aligned && v.left >= label.right - 0.5 * h) {
      if (best == null || v.left < best.left) best = v;
    }
  }
  if (best != null) return best.text.trim();
  for (final v in lines) {
    if (identical(v, label) || v.text.trim().isEmpty || _isLabel(v.text)) continue;
    final below = v.top >= label.bottom - 0.5 * h;
    final xOverlap = v.left <= label.right && v.right >= label.left;
    final sameCol = (v.left - label.left).abs() <= 1.5 * h;
    final blocked = lines.any((m) =>
        !identical(m, label) && _isLabel(m.text) && m.top > label.top && m.top < v.top);
    if (below && !blocked && (xOverlap || sameCol)) {
      if (best == null || v.top < best.top) best = v;
    }
  }
  return best?.text.trim();
}

/// 제품명=상단 최대폰트 줄, 로스터리=그 위 작은 줄. 균일 텍스트면 (null,null)로 오채움 회피.
(String?, String?) _titleEyebrow(List<OcrLine> lines) {
  final real = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (real.length < 2) return (null, null);
  final hs = real.map((l) => l.height).toList()..sort();
  final n = hs.length;
  final medianH = n.isOdd ? hs[n ~/ 2] : (hs[n ~/ 2 - 1] + hs[n ~/ 2]) / 2;
  if (medianH <= 0) return (null, null);
  var title = real.first;
  for (final l in real) {
    if (l.height > title.height) title = l;
  }
  if (title.height < 1.3 * medianH) return (null, null);
  final minTop = real.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final maxBottom = real.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
  if (title.top > minTop + 0.45 * (maxBottom - minTop)) return (null, null);
  OcrLine? eyebrow;
  for (final l in real) {
    if (identical(l, title)) continue;
    final above = l.bottom <= title.top + 0.3 * title.height;
    final xOverlap = l.left <= title.right && l.right >= title.left;
    if (above && xOverlap && l.height < title.height) {
      if (eyebrow == null || l.bottom > eyebrow.bottom) eyebrow = l;
    }
  }
  return (title.text.trim(), eyebrow?.text.trim());
}

List<String> _splitNotes(String s) => s
    .split(RegExp(r'[,/·、]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

OcrDraft parseOcr(List<OcrLine> lines) {
  final texts = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).toList();
  final joined = texts.join('\n');
  final lower = joined.toLowerCase();

  // 4.1 좌표 라벨→값
  String? region = _spatialValue(lines, _regionTokens);
  final cupSpatial = _spatialValue(lines, _cupTokens);
  var cupNotes = cupSpatial == null ? const <String>[] : _splitNotes(cupSpatial);

  // 4.2 타이포 제목/이브로우
  final te = _titleEyebrow(lines);
  String? name = te.$1;
  String? roaster = te.$2;

  // 4.3 콜론/키워드 폴백
  name ??= _firstLabel(texts, _nameLabel);
  roaster ??= _firstLabel(texts, _roasterLabel);
  region ??= _firstLabel(texts, _regionLabel);
  if (cupNotes.isEmpty) cupNotes = _matchCupNotes(texts);

  return OcrDraft(
    name: name,
    roaster: roaster,
    country: _firstMatch(lower, _countries),
    region: region,
    roastDate: _matchDate(joined),
    roastLevel: _firstMatch(lower, _roastKeywords),
    process: _firstMatch(lower, _processKeywords),
    cupNotes: cupNotes,
    chips: _dedupe(texts),
  );
}

/// 문자열 하위호환: 줄을 세로로 쌓은 합성 라인으로 감싸 parseOcr에 위임.
/// 프로덕션 호출부 없음 — 문자열 코퍼스/비회귀 테스트 진입점으로 의도적으로 유지.
OcrDraft parseOcrText(String rawText) {
  final texts = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final lines = [
    for (final (i, t) in texts.indexed)
      OcrLine(t, left: 0, top: i * 10.0, right: 100, bottom: i * 10.0 + 10),
  ];
  return parseOcr(lines);
}

T? _firstMatch<T>(String lower, Map<String, T> table) {
  for (final e in table.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return null;
}

final RegExp _roastLabel = RegExp(r'roast|로스팅|볶은', caseSensitive: false);

DateTime? _matchDate(String text) {
  // 1) 로스팅 라벨이 있는 줄에서 먼저 찾는다(유통기한 등 다른 날짜에 밀리지 않게).
  for (final line in text.split('\n')) {
    if (_roastLabel.hasMatch(line)) {
      final d = _dateIn(line);
      if (d != null) return d;
    }
  }
  // 2) 없으면 전체 텍스트에서 첫 유효 날짜.
  return _dateIn(text);
}

DateTime? _dateIn(String s) {
  for (final re in _datePatterns) {
    final m = re.firstMatch(s);
    if (m == null) continue;
    var year = int.parse(m.group(1)!);
    if (year < 100) year += 2000;
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    return DateTime(year, month, day);
  }
  return null;
}

List<String> _matchCupNotes(List<String> lines) {
  for (final line in lines) {
    final m = _noteLabel.firstMatch(line);
    if (m != null) return _splitNotes(m.group(2)!);
  }
  return const [];
}

String? _firstLabel(List<String> lines, RegExp label) {
  for (final line in lines) {
    final m = label.firstMatch(line);
    if (m != null) {
      final v = m.group(2)!.trim();
      if (v.isNotEmpty) return v;
    }
  }
  return null;
}

List<String> _dedupe(List<String> lines) {
  final seen = <String>{};
  final out = <String>[];
  for (final l in lines) {
    if (seen.add(l)) out.add(l);
  }
  return out;
}
