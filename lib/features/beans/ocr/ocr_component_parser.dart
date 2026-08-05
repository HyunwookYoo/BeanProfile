import '../../../data/enums.dart';
import '../../../services/ocr_service.dart';
import 'ocr_draft.dart';

const countryKeywords = <String, String>{
  'costa rica': 'Costa Rica',
  '코스타리카': 'Costa Rica',
  'el salvador': 'El Salvador',
  '엘살바도르': 'El Salvador',
  'ethiopia': 'Ethiopia',
  '에티오피아': 'Ethiopia',
  'colombia': 'Colombia',
  '콜롬비아': 'Colombia',
  'kenya': 'Kenya',
  '케냐': 'Kenya',
  'brazil': 'Brazil',
  '브라질': 'Brazil',
  'guatemala': 'Guatemala',
  '과테말라': 'Guatemala',
  'panama': 'Panama',
  '파나마': 'Panama',
  'honduras': 'Honduras',
  '온두라스': 'Honduras',
  'indonesia': 'Indonesia',
  '인도네시아': 'Indonesia',
  'rwanda': 'Rwanda',
  '르완다': 'Rwanda',
  'burundi': 'Burundi',
  '부룬디': 'Burundi',
  'peru': 'Peru',
  '페루': 'Peru',
  'nicaragua': 'Nicaragua',
  '니카라과': 'Nicaragua',
  'yemen': 'Yemen',
  '예멘': 'Yemen',
  'tanzania': 'Tanzania',
  '탄자니아': 'Tanzania',
  'mexico': 'Mexico',
  '멕시코': 'Mexico',
  'uganda': 'Uganda',
  '우간다': 'Uganda',
  'bolivia': 'Bolivia',
  '볼리비아': 'Bolivia',
  'ecuador': 'Ecuador',
  '에콰도르': 'Ecuador',
  'thailand': 'Thailand',
  '태국': 'Thailand',
  'vietnam': 'Vietnam',
  '베트남': 'Vietnam',
  'india': 'India',
  '인도': 'India',
  'laos': 'Laos',
  '라오스': 'Laos',
  'myanmar': 'Myanmar',
  '미얀마': 'Myanmar',
  'papua new guinea': 'Papua New Guinea',
  '파푸아뉴기니': 'Papua New Guinea',
  'east timor': 'East Timor',
  '동티모르': 'East Timor',
  'jamaica': 'Jamaica',
  '자메이카': 'Jamaica',
  'hawaii': 'Hawaii',
  '하와이': 'Hawaii',
  // China는 넣지 않는다 — `_matchesIn`이 단어 경계 없는 부분 문자열 매칭이라
  // 니카라과 산지 `Chinandega`를 China로 오인한다. 같은 이유로 East Timor의
  // 영문 키도 축약형 `timor`가 아니라 전체 국가명을 쓴다 — `timor`만 쓰면
  // 커피 품종명 `Catimor`(카투라×티모르 교배종, 베트남·인도 등 실사용) 안의
  // `timor`를 오매칭한다.
  //
  // 나머지 신규 키의 부분 문자열 충돌도 훑었고, 남은 건 커피 카드에 실제로는
  // 안 적히는 문자열뿐이라 그대로 둔다 — `Indiana Farm 50%`가 `india`에,
  // `Laoshan Estate 50%`가 `laos`에 걸린다(둘 다 사전 확장 전에는 성분 0개).
  // 한글 `인도`는 `인도네시아`에 삼켜지지 않는다 — `_matchesIn`이 키를 길이
  // 내림차순으로 훑어 `인도네시아`를 먼저 잡고, 겹침 가드가 그 구간에 걸친
  // `인도`를 버린다.
};

const processKeywords = <String, Process>{
  '워시드': Process.washed,
  'washed': Process.washed,
  '수세식': Process.washed,
  '내추럴': Process.natural,
  'natural': Process.natural,
  '건식': Process.natural,
  '허니': Process.honey,
  'honey': Process.honey,
  '무산소': Process.anaerobic,
  'anaerobic': Process.anaerobic,
  '애너로빅': Process.anaerobic,
};

final ratioPattern = RegExp(r'\b(100|[1-9]?\d)\s*%');
final _bareLocalComponentLabel = RegExp(
  r'^(?:origin|원산지|생산지|component|구성)(?:\s*\d+)?'
  r'(?:\s*[·.\-–—]\s*'
  r'(?:origin|원산지|생산지|component|구성)(?:\s*\d+)?)?'
  r'\s*[:：]?$',
  caseSensitive: false,
);
final _numberedComponentSectionLabel = RegExp(
  r'^(?:origin|원산지|생산지|component|구성)\s*\d+'
  r'(?:\s*[·.\-–—]\s*'
  r'(?:origin|원산지|생산지|component|구성)\s*\d+)?'
  r'\s*[:：]?$',
  caseSensitive: false,
);
final _inlineLocalComponentGroupLabel = RegExp(
  r'^(?:origin|원산지|생산지|component|구성|blend|블렌드)'
  r'(?:\s*\d+)?\s*[:：]\s*',
  caseSensitive: false,
);
final _originLabel = RegExp(
  r'^(origin|원산지|생산지)\s*[:：]?$',
  caseSensitive: false,
);
final _regionLabelPrefix = RegExp(
  r'^(?:region|지역)(?:\s*[:：]\s*|\s+|$)',
  caseSensitive: false,
);
final _processLabelPrefix = RegExp(
  r'^(?:process|가공방식|가공)(?:\s*[:：]\s*|\s+|$)',
  caseSensitive: false,
);
final _inlineProcessLabel = RegExp(
  r'^(?:process|가공방식|가공)\s*(?:[:：]\s*|\s+)(.+)$',
  caseSensitive: false,
);
final _bareProcessLabel = RegExp(
  r'^(?:process|가공방식|가공)\s*[:：]?$',
  caseSensitive: false,
);
final _ratioLabelPrefix = RegExp(
  r'^(?:ratio|비율)(?:\s*[:：]\s*|\s+|$)',
  caseSensitive: false,
);
final _nonRegionLabel = RegExp(
  r'^(origin|원산지|생산지|process|가공|가공방식|ratio|비율|'
  r'roast|roasted|로스팅|로스팅일|notes?|cup\s*notes?|컵\s*노트|컵노트|'
  r'variety|varietal|품종|altitude|고도|name|product\s*name|제품명|상품명|'
  r'roaster|로스터리|로스터|weight|중량)(?:\s*[:：]\s*|\s+|$)',
  caseSensitive: false,
);

class _CountryMention {
  final int lineIndex;
  final int textOffset;
  final int matchLength;
  final String country;
  final int? ratio;
  final OcrLine line;

  const _CountryMention({
    required this.lineIndex,
    required this.textOffset,
    required this.matchLength,
    required this.country,
    required this.ratio,
    required this.line,
  });
}

class _CountryMatch {
  final int offset;
  final int length;
  final String country;

  const _CountryMatch(this.offset, this.length, this.country);
}

Process? firstProcessMatch(String text) {
  final lower = text.toLowerCase();
  MapEntry<String, Process>? best;
  var bestIndex = lower.length;
  for (final entry in processKeywords.entries) {
    final index = lower.indexOf(entry.key);
    if (index >= 0 &&
        (index < bestIndex ||
            (index == bestIndex &&
                entry.key.length > (best?.key.length ?? 0)))) {
      best = entry;
      bestIndex = index;
    }
  }
  return best?.value;
}

List<OcrComponentDraft> parseOcrComponents(List<OcrLine> lines) {
  var mentions = _countryMentions(lines);
  if (mentions.isEmpty) return const [];

  mentions = _collapseTitleDuplicates(mentions, lines);
  final evidence = [
    for (final mention in mentions)
      _hasComponentEvidence(mention, mentions, lines),
  ];
  final hasStructuredEvidence = evidence.any((value) => value);
  final admitted = hasStructuredEvidence
      ? [
          for (var i = 0; i < mentions.length; i++)
            if (evidence[i]) mentions[i],
        ]
      : [mentions.first];

  final components = [
    for (var i = 0; i < admitted.length; i++) _componentFor(lines, admitted, i),
  ];
  return _fillSingleUnmatchedFields(lines, components);
}

List<OcrComponentDraft> _fillSingleUnmatchedFields(
  List<OcrLine> lines,
  List<OcrComponentDraft> components,
) {
  if (components.length < 2) return components;

  final missingRatio = [
    for (var i = 0; i < components.length; i++)
      if (components[i].ratioPercent == null) i,
  ];
  int? ratioIndex;
  int? ratio;
  if (missingRatio.length == 1) {
    final remaining = [
      for (final line in lines)
        for (final match in ratioPattern.allMatches(line.text))
          int.parse(match.group(1)!),
    ];
    for (final component in components) {
      final assigned = component.ratioPercent;
      if (assigned != null) remaining.remove(assigned);
    }
    final assignedTotal = components.fold(
      0,
      (total, component) => total + (component.ratioPercent ?? 0),
    );
    if (remaining.length == 1 && assignedTotal + remaining.single == 100) {
      ratioIndex = missingRatio.single;
      ratio = remaining.single;
    }
  }

  final unresolvedProcess = [
    for (var i = 0; i < components.length; i++)
      if (components[i].process == null ||
          components[i].process == Process.other)
        i,
  ];
  int? processIndex;
  Process? process;
  if (unresolvedProcess.length == 1) {
    final remaining = [
      for (final line in lines)
        if (_standaloneProcess(line.text) case final value?) value,
    ];
    for (final component in components) {
      final assigned = component.process;
      if (assigned != null && assigned != Process.other) {
        remaining.remove(assigned);
      }
    }
    if (remaining.length == 1) {
      processIndex = unresolvedProcess.single;
      process = remaining.single;
    }
  }

  if (ratioIndex == null && processIndex == null) return components;
  return [
    for (var i = 0; i < components.length; i++)
      OcrComponentDraft(
        country: components[i].country,
        region: components[i].region,
        process: i == processIndex ? process : components[i].process,
        ratioPercent:
            components[i].ratioPercent ?? (i == ratioIndex ? ratio : null),
      ),
  ];
}

Process? _standaloneProcess(String text) {
  final process = firstProcessMatch(text);
  if (process == null) return null;

  var remainder = text.trim().replaceFirst(_processLabelPrefix, '');
  for (final keyword in processKeywords.keys) {
    remainder = remainder.replaceAll(
      RegExp(RegExp.escape(keyword), caseSensitive: false),
      ' ',
    );
  }
  remainder = remainder.replaceAll(RegExp(r'[\s:/|·,;：\-–—]+'), '');
  return remainder.isEmpty ? process : null;
}

bool _hasComponentEvidence(
  _CountryMention mention,
  List<_CountryMention> mentions,
  List<OcrLine> lines,
) =>
    mention.ratio != null ||
    _nearbyStandaloneRatio(mention, mentions, lines) != null ||
    _isStructuredInlineGroup(mention, mentions) ||
    _hasRepeatedTopology(mention, mentions, lines) ||
    _hasLocalComponentLabel(mention, lines) ||
    _hasLocalLabeledRatio(mention, mentions, lines);

int? _nearbyStandaloneRatio(
  _CountryMention mention,
  List<_CountryMention> mentions,
  List<OcrLine> lines,
) {
  if (!_hasGeometry(mention.line)) return null;
  final ownerIndex = mentions.indexOf(mention);
  for (final line in lines) {
    final ratio = _standaloneRatioValue(line.text);
    if (ratio == null ||
        !_hasGeometry(line) ||
        _ownerForLine(line, mentions) != ownerIndex ||
        !_isNearCountryAnchor(mention.line, line)) {
      continue;
    }
    return ratio;
  }
  return null;
}

int? _standaloneRatioValue(String text) {
  final match = ratioPattern.firstMatch(text);
  if (match == null) return null;
  final remainder = text
      .replaceRange(match.start, match.end, ' ')
      .replaceAll(RegExp(r'[\s:/|·,;：\-–—]+'), '');
  return remainder.isEmpty ? int.parse(match.group(1)!) : null;
}

bool _isNearCountryAnchor(OcrLine country, OcrLine value) {
  final height = country.height > value.height ? country.height : value.height;
  final scale = height > 20 ? height : 20.0;
  final horizontalOverlap =
      (country.right < value.right ? country.right : value.right) -
      (country.left > value.left ? country.left : value.left);
  final below =
      value.centerY >= country.centerY &&
      value.centerY - country.centerY <= 2.5 * scale;
  final right =
      _sameVisualRow(country, value) &&
      value.left >= country.right &&
      value.left - country.right <= 4 * scale;
  return (horizontalOverlap > 0 && below) || right;
}

bool _isStructuredInlineGroup(
  _CountryMention mention,
  List<_CountryMention> mentions,
) {
  final sameLine = mentions
      .where((other) => other.lineIndex == mention.lineIndex)
      .toList();
  if (sameLine.length < 2) return false;
  var remainder = mention.line.text;
  final matches = _matchesIn(remainder)
    ..sort((a, b) => b.offset.compareTo(a.offset));
  for (final match in matches) {
    remainder = remainder.replaceRange(
      match.offset,
      match.offset + match.length,
      ' ',
    );
  }
  remainder = remainder.replaceAll(ratioPattern, ' ');
  remainder = remainder.replaceFirst(_inlineLocalComponentGroupLabel, ' ');
  return RegExp(r'^[\s\d/|·,;:+\-–—()\[\]#]*$').hasMatch(remainder);
}

List<_CountryMention> _countryMentions(List<OcrLine> lines) {
  final mentions = <_CountryMention>[];
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final line = lines[lineIndex];
    final matches = _matchesIn(line.text);
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final end = i + 1 < matches.length
          ? matches[i + 1].offset
          : line.text.length;
      final ratioMatch = ratioPattern.firstMatch(
        line.text.substring(match.offset + match.length, end),
      );
      final mention = _CountryMention(
        lineIndex: lineIndex,
        textOffset: match.offset,
        matchLength: match.length,
        country: match.country,
        ratio: ratioMatch == null ? null : int.parse(ratioMatch.group(1)!),
        line: line,
      );
      final duplicate = mentions.any(
        (existing) =>
            existing.country == mention.country &&
            existing.textOffset == mention.textOffset &&
            existing.line.text == mention.line.text &&
            existing.line.left == mention.line.left &&
            existing.line.top == mention.line.top &&
            existing.line.right == mention.line.right &&
            existing.line.bottom == mention.line.bottom,
      );
      if (!duplicate) mentions.add(mention);
    }
  }
  mentions.sort((a, b) {
    final lineOrder = a.lineIndex.compareTo(b.lineIndex);
    return lineOrder != 0 ? lineOrder : a.textOffset.compareTo(b.textOffset);
  });
  return mentions;
}

List<_CountryMatch> _matchesIn(String text) {
  final lower = text.toLowerCase();
  final entries = countryKeywords.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  final matches = <_CountryMatch>[];
  for (final entry in entries) {
    var start = 0;
    while (start < lower.length) {
      final offset = lower.indexOf(entry.key, start);
      if (offset < 0) break;
      final end = offset + entry.key.length;
      final overlaps = matches.any(
        (match) => offset < match.offset + match.length && end > match.offset,
      );
      if (!overlaps) {
        matches.add(_CountryMatch(offset, entry.key.length, entry.value));
      }
      start = offset + entry.key.length;
    }
  }
  matches.sort((a, b) => a.offset.compareTo(b.offset));
  return matches;
}

List<_CountryMention> _collapseTitleDuplicates(
  List<_CountryMention> mentions,
  List<OcrLine> lines,
) {
  final removed = <_CountryMention>{};
  for (var i = 0; i < mentions.length; i++) {
    final title = mentions[i];
    for (var j = i + 1; j < mentions.length; j++) {
      final structured = mentions[j];
      if (title.country == structured.country &&
          title.ratio == null &&
          structured.ratio == null &&
          title.lineIndex != structured.lineIndex &&
          !_hasRepeatedTopologyPair(title, structured, lines) &&
          _isTitleBefore(title, structured, lines) &&
          _isStructuredCountry(structured, lines)) {
        removed.add(title);
        break;
      }
    }
  }
  return mentions.where((mention) => !removed.contains(mention)).toList();
}

bool _isTitleBefore(
  _CountryMention first,
  _CountryMention later,
  List<OcrLine> lines,
) {
  if (first.lineIndex >= later.lineIndex) {
    return false;
  }
  if (_hasGeometry(first.line) &&
      _hasGeometry(later.line) &&
      first.line.top >= later.line.top) {
    return false;
  }
  final remainder = first.line.text.replaceRange(
    first.textOffset,
    first.textOffset + first.matchLength,
    '',
  );
  final hasDescription = remainder
      .replaceAll(RegExp(r'[\s\-–—|/·:：]+'), '')
      .isNotEmpty;
  final isLargerTitle =
      _hasGeometry(first.line) &&
      _hasGeometry(later.line) &&
      first.line.height >= 1.5 * later.line.height;
  return hasDescription ||
      isLargerTitle ||
      _hasLocalComponentLabel(later, lines);
}

bool _hasGeometry(OcrLine line) => line.height > 0 && line.right > line.left;

bool _isStructuredCountry(_CountryMention mention, List<OcrLine> lines) {
  final remainder = mention.line.text.replaceRange(
    mention.textOffset,
    mention.textOffset + mention.matchLength,
    '',
  );
  if (remainder.replaceAll(RegExp(r'[\s\-–—|/·:：]+'), '').isEmpty) {
    return true;
  }
  final prefix = mention.line.text.substring(0, mention.textOffset).trim();
  if (_originLabel.hasMatch(prefix)) return true;
  return lines.any((label) {
    if (!_originLabel.hasMatch(label.text.trim()) ||
        label.height <= 0 ||
        mention.line.height <= 0) {
      return false;
    }
    final height = label.height > mention.line.height
        ? label.height
        : mention.line.height;
    return (label.centerY - mention.line.centerY).abs() <= 0.6 * height &&
        label.right <= mention.line.left;
  });
}

bool _hasLocalComponentLabel(_CountryMention mention, List<OcrLine> lines) {
  final prefix = mention.line.text.substring(0, mention.textOffset).trim();
  if (_bareLocalComponentLabel.hasMatch(prefix)) return true;
  for (var i = mention.lineIndex - 1; i >= 0; i--) {
    final label = lines[i];
    if (label.text.trim().isEmpty) continue;
    if (!_bareLocalComponentLabel.hasMatch(label.text.trim())) return false;
    if (!_hasGeometry(label) || !_hasGeometry(mention.line)) return true;
    final height = label.height > mention.line.height
        ? label.height
        : mention.line.height;
    final directlyAbove =
        mention.line.top >= label.bottom &&
        mention.line.top - label.bottom <= 2 * (height > 20 ? height : 20);
    final sameRow =
        (label.centerY - mention.line.centerY).abs() <= 0.6 * height &&
        label.right <= mention.line.left;
    return directlyAbove || sameRow;
  }
  return false;
}

bool _hasLocalLabeledRatio(
  _CountryMention mention,
  List<_CountryMention> mentions,
  List<OcrLine> lines,
) {
  final nextIndexes = mentions
      .where((other) => other.lineIndex > mention.lineIndex)
      .map((other) => other.lineIndex);
  final end = nextIndexes.isEmpty
      ? lines.length
      : nextIndexes.reduce((a, b) => a < b ? a : b);
  var sawBareLabel = false;
  for (var i = mention.lineIndex; i < end; i++) {
    final text = i == mention.lineIndex
        ? lines[i].text.substring(mention.textOffset + mention.matchLength)
        : lines[i].text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;
    if (_ratioLabelPrefix.hasMatch(trimmed)) {
      final value = trimmed.replaceFirst(_ratioLabelPrefix, '');
      if (ratioPattern.hasMatch(value)) return true;
      sawBareLabel = value.isEmpty;
      continue;
    }
    if (sawBareLabel) return ratioPattern.hasMatch(trimmed);
  }
  return false;
}

bool _anchorsRepeat(_CountryMention a, _CountryMention b) {
  if (!_hasGeometry(a.line) ||
      !_hasGeometry(b.line) ||
      !_isCountryAnchorText(a) ||
      !_isCountryAnchorText(b)) {
    return false;
  }
  final height = a.line.height > b.line.height ? a.line.height : b.line.height;
  final widthA = a.line.right - a.line.left;
  final widthB = b.line.right - b.line.left;
  final width = widthA > widthB ? widthA : widthB;
  final scale = height > 20 ? height : 20.0;
  final sameColumn =
      (a.line.left - b.line.left).abs() <= 2 * scale &&
      (a.line.centerY - b.line.centerY).abs() <= 6 * scale;
  final sameRow =
      _sameRepeatedRow(a, b) &&
      (((a.line.left + a.line.right) / 2) - ((b.line.left + b.line.right) / 2))
              .abs() <=
          6 * (width > scale ? width : scale);
  return sameColumn || sameRow;
}

bool _sameRepeatedRow(_CountryMention a, _CountryMention b) {
  final height = a.line.height > b.line.height ? a.line.height : b.line.height;
  return (a.line.centerY - b.line.centerY).abs() <= 0.6 * height;
}

bool _hasRepeatedTopology(
  _CountryMention mention,
  List<_CountryMention> mentions,
  List<OcrLine> lines,
) => mentions.any(
  (other) =>
      !identical(other, mention) &&
      other.lineIndex != mention.lineIndex &&
      _hasRepeatedTopologyPair(mention, other, lines),
);

bool _hasRepeatedTopologyPair(
  _CountryMention a,
  _CountryMention b,
  List<OcrLine> lines,
) {
  if (!_anchorsRepeat(a, b)) return false;
  if (_sameRepeatedRow(a, b)) return true;
  final bothLocallyLabeled =
      _hasLocalComponentLabel(a, lines) && _hasLocalComponentLabel(b, lines);
  return bothLocallyLabeled || _hasParallelComponentValues(a, b, lines);
}

bool _hasParallelComponentValues(
  _CountryMention a,
  _CountryMention b,
  List<OcrLine> lines,
) {
  final height = a.line.height > b.line.height ? a.line.height : b.line.height;
  final scale = height > 20 ? height : 20.0;
  final offsets = <List<double>>[<double>[], <double>[]];
  for (final line in lines) {
    if (!_isTopologyValue(line, lines, a, b)) continue;
    final owner = _ownerForLine(line, [a, b], lines);
    if (owner == null) continue;
    final anchor = owner == 0 ? a : b;
    final offset = line.centerY - anchor.line.centerY;
    if (offset < -scale || offset > 6 * scale) continue;
    offsets[owner].add(offset);
  }
  return offsets[0].any(
    (first) =>
        offsets[1].any((second) => (first - second).abs() <= 1.5 * scale),
  );
}

bool _isTopologyValue(
  OcrLine line,
  List<OcrLine> lines,
  _CountryMention a,
  _CountryMention b,
) {
  if (!_hasGeometry(line) ||
      identical(line, a.line) ||
      identical(line, b.line)) {
    return false;
  }
  final text = line.text.trim();
  if (text.isEmpty ||
      _matchesIn(text).isNotEmpty ||
      _isAnyFieldLabel(text) ||
      _nonRegionLabel.hasMatch(text) ||
      _nonComponentTableText.hasMatch(text) ||
      text.contains(':') ||
      _isClaimedByGlobalLabel(line, lines)) {
    return false;
  }
  return firstProcessMatch(text) != null ||
      ratioPattern.hasMatch(text) ||
      _unlabeledRegion(text) != null;
}

bool _isCountryAnchorText(_CountryMention mention) {
  // ① 국가가 줄 머리에 오면 앵커 — `Ethiopia Sidama Bensa Keramo Ako`처럼 국가
  //    뒤에 농장·지역·등급이 붙는 성분 줄을 살린다. 앵커가 됐다고 성분이 되는
  //    건 아니다. `_hasComponentEvidence`가 여전히 비율이나 반복 토폴로지를
  //    요구하고, 반복 토폴로지는 같은 열의 앵커가 둘 이상이어야 성립한다.
  final prefix = mention.line.text.substring(0, mention.textOffset);
  if (prefix.replaceAll(RegExp(r'[\s\-–—|/·,:：()\[\]#\d]+'), '').isEmpty) {
    return true;
  }
  // ② 기존: 국가·비율·라벨을 빼고 남은 글자가 없으면 앵커.
  var remainder = mention.line.text.replaceRange(
    mention.textOffset,
    mention.textOffset + mention.matchLength,
    ' ',
  );
  remainder = remainder
      .replaceAll(ratioPattern, ' ')
      .replaceFirst(_bareLocalComponentLabel, ' ')
      .replaceAll(RegExp(r'[\s\-–—|/·,:：()\[\]#\d]+'), '');
  return remainder.isEmpty;
}

OcrComponentDraft _componentFor(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int index,
) {
  final mention = mentions[index];
  final segment = _segmentTexts(lines, mentions, index);
  final labeledProcess = _labeledProcess(segment);
  final hasLocalSection = _hasLocalComponentLabel(mention, lines);
  final sequentialRegion = _firstRegion(
    segment,
    labeledProcess?.valueIndexes ?? const {},
  );
  final sequentialProcess =
      labeledProcess?.process ?? firstProcessMatch(segment.join('\n'));
  final spatialRegion = _spatialFieldValue(
    lines,
    mentions,
    index,
    _ComponentField.region,
  );
  final spatialProcess = _spatialFieldValue(
    lines,
    mentions,
    index,
    _ComponentField.process,
  );
  final spatialRatio = _spatialFieldValue(
    lines,
    mentions,
    index,
    _ComponentField.ratio,
  );
  final nearbyRatio = _nearbyStandaloneRatio(mention, mentions, lines);
  final unlabeled = _unlabeledSpatialFields(lines, mentions, index);
  final useSequentialFields = hasLocalSection || !unlabeled.hasLayout;
  final useSequentialRegion =
      hasLocalSection || (!unlabeled.hasLayout && mentions.length > 1);
  final sequentialRatio = hasLocalSection
      ? _leadingRatio(segment) ?? _labeledRatio(segment)
      : _labeledRatio(segment);
  return OcrComponentDraft(
    country: mention.country,
    region: spatialRegion != null
        ? _cleanRegion(spatialRegion)
        : unlabeled.region ?? (useSequentialRegion ? sequentialRegion : null),
    process: spatialProcess == null
        ? unlabeled.process ?? (useSequentialFields ? sequentialProcess : null)
        : _labeledProcessValue(spatialProcess),
    ratioPercent:
        mention.ratio ??
        nearbyRatio ??
        (spatialRatio == null
            ? unlabeled.ratioPercent ??
                  (useSequentialFields ? sequentialRatio : null)
            : _ratioFrom(spatialRatio)),
  );
}

enum _ComponentField { region, process, ratio }

class _RepeatedLayout {
  final bool horizontal;
  final double minTop;
  final double maxBottom;
  final double maxHeight;
  final double maxWidth;

  const _RepeatedLayout({
    required this.horizontal,
    required this.minTop,
    required this.maxBottom,
    required this.maxHeight,
    required this.maxWidth,
  });
}

({bool hasLayout, String? region, Process? process, int? ratioPercent})
_unlabeledSpatialFields(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int ownerIndex,
) {
  final layout = _repeatedLayout(mentions);
  if (layout == null) {
    return (hasLayout: false, region: null, process: null, ratioPercent: null);
  }
  final candidates = <OcrLine>[
    for (final line in lines)
      if (_isUnlabeledTableCandidate(line, lines, mentions, layout) &&
          _ownerForLine(line, mentions, lines) == ownerIndex)
        line,
  ];

  Process? process;
  for (final candidate in candidates) {
    process ??= firstProcessMatch(candidate.text);
  }
  int? ratio;
  for (final candidate in candidates) {
    ratio ??= _ratioFrom(candidate.text);
  }
  String? region;
  for (final candidate in candidates) {
    region ??= _unlabeledRegion(candidate.text);
  }
  return (
    hasLayout: true,
    region: region,
    process: process,
    ratioPercent: ratio,
  );
}

_RepeatedLayout? _repeatedLayout(List<_CountryMention> mentions) {
  final geometric = mentions.where((mention) => _hasGeometry(mention.line));
  if (geometric.length < 2) return null;
  final xs = geometric.map(
    (mention) => (mention.line.left + mention.line.right) / 2,
  );
  final ys = geometric.map((mention) => mention.line.centerY);
  final minX = xs.reduce((a, b) => a < b ? a : b);
  final maxX = xs.reduce((a, b) => a > b ? a : b);
  final minY = ys.reduce((a, b) => a < b ? a : b);
  final maxY = ys.reduce((a, b) => a > b ? a : b);
  return _RepeatedLayout(
    horizontal: maxX - minX > maxY - minY,
    minTop: geometric
        .map((mention) => mention.line.top)
        .reduce((a, b) => a < b ? a : b),
    maxBottom: geometric
        .map((mention) => mention.line.bottom)
        .reduce((a, b) => a > b ? a : b),
    maxHeight: geometric
        .map((mention) => mention.line.height)
        .reduce((a, b) => a > b ? a : b),
    maxWidth: geometric
        .map((mention) => mention.line.right - mention.line.left)
        .reduce((a, b) => a > b ? a : b),
  );
}

final _nonComponentTableText = RegExp(
  r'\b(?:blend(?:ing)?|roast(?:ed|er|ing)?|notes?|coffee|variety|altitude|'
  r'product|name)\b',
  caseSensitive: false,
);

bool _isUnlabeledTableCandidate(
  OcrLine line,
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  _RepeatedLayout layout,
) {
  final text = line.text.trim();
  if (!_hasGeometry(line) ||
      text.isEmpty ||
      _matchesIn(text).isNotEmpty ||
      _isAnyFieldLabel(text) ||
      _nonRegionLabel.hasMatch(text) ||
      _nonComponentTableText.hasMatch(text) ||
      text.contains(':') ||
      _isClaimedByFieldLabel(line, lines)) {
    return false;
  }
  if (mentions.any((mention) => identical(mention.line, line))) return false;

  if (layout.horizontal) {
    if (line.top < layout.minTop - layout.maxHeight ||
        line.bottom > layout.maxBottom + 8 * layout.maxHeight) {
      return false;
    }
    final centerX = (line.left + line.right) / 2;
    final nearest = mentions
        .where((mention) => _hasGeometry(mention.line))
        .map(
          (mention) =>
              (centerX - (mention.line.left + mention.line.right) / 2).abs(),
        )
        .reduce((a, b) => a < b ? a : b);
    final tolerance = layout.maxWidth * 1.5 > 3 * layout.maxHeight
        ? layout.maxWidth * 1.5
        : 3 * layout.maxHeight;
    return nearest <= tolerance;
  }
  return line.top >= layout.minTop - layout.maxHeight &&
      line.bottom <= layout.maxBottom + 4 * layout.maxHeight;
}

bool _isClaimedByFieldLabel(OcrLine candidate, List<OcrLine> lines) {
  for (final label in lines) {
    final text = label.text.trim();
    if (identical(label, candidate) ||
        !_hasGeometry(label) ||
        _bareLocalComponentLabel.hasMatch(text) ||
        (!_isAnyFieldLabel(text) && !_nonRegionLabel.hasMatch(text))) {
      continue;
    }
    if (_sameVisualRow(label, candidate) && candidate.left >= label.right) {
      return true;
    }
    if (_sameVisualColumn(label, candidate) &&
        candidate.top >= label.bottom &&
        candidate.top - label.bottom <= 4 * label.height) {
      return true;
    }
  }
  return false;
}

bool _isClaimedByGlobalLabel(OcrLine candidate, List<OcrLine> lines) {
  for (final label in lines) {
    final text = label.text.trim();
    if (identical(label, candidate) ||
        !_hasGeometry(label) ||
        !_nonRegionLabel.hasMatch(text) ||
        _isAnyFieldLabel(text) ||
        _bareLocalComponentLabel.hasMatch(text)) {
      continue;
    }
    if (_sameVisualRow(label, candidate) && candidate.left >= label.right) {
      return true;
    }
    if (_sameVisualColumn(label, candidate) &&
        candidate.top >= label.bottom &&
        candidate.top - label.bottom <= 4 * label.height) {
      return true;
    }
  }
  return false;
}

String? _unlabeledRegion(String text) {
  var value = text.trim();
  for (final process in processKeywords.keys) {
    value = value.replaceAll(
      RegExp(RegExp.escape(process), caseSensitive: false),
      ' ',
    );
  }
  value = value
      .replaceAll(ratioPattern, ' ')
      .replaceAll(RegExp(r'[/|·,;:：()\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value.isEmpty || value.split(' ').length > 4) return null;
  return value;
}

RegExp _fieldLabel(_ComponentField field) => switch (field) {
  _ComponentField.region => _regionLabelPrefix,
  _ComponentField.process => _processLabelPrefix,
  _ComponentField.ratio => _ratioLabelPrefix,
};

String? _spatialFieldValue(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int ownerIndex,
  _ComponentField field,
) {
  final ordered = _orderedRepeatedFieldValue(
    lines,
    mentions,
    ownerIndex,
    field,
  );
  if (ordered != null) return ordered;

  final labelPattern = _fieldLabel(field);
  for (final label in lines) {
    if (labelPattern.firstMatch(label.text.trim()) == null) continue;
    for (final value in _fieldValuesForLabel(lines, label, field)) {
      if (_ownerForLine(value.ownerLine, mentions, lines) == ownerIndex) {
        return value.text;
      }
    }
  }
  return null;
}

String? _orderedRepeatedFieldValue(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int ownerIndex,
  _ComponentField field,
) {
  final layout = _repeatedLayout(mentions);
  if (layout == null ||
      mentions.any((mention) => !_hasGeometry(mention.line))) {
    return null;
  }

  final entries = <({OcrLine label, OcrLine ownerLine, String text})>[];
  final valueLines = <OcrLine>{};
  final labelPattern = _fieldLabel(field);
  for (final label in lines) {
    if (labelPattern.firstMatch(label.text.trim()) == null) continue;
    final values = _fieldValuesForLabel(lines, label, field);
    if (values.length != 1) return null;
    final value = values.single;
    if (!valueLines.add(value.ownerLine)) return null;
    entries.add((label: label, ownerLine: value.ownerLine, text: value.text));
  }
  if (entries.length != mentions.length) return null;

  double axis(OcrLine line) =>
      layout.horizontal ? (line.left + line.right) / 2 : line.centerY;
  final orderedOwners = [
    for (var i = 0; i < mentions.length; i++)
      (index: i, line: mentions[i].line),
  ]..sort((a, b) => axis(a.line).compareTo(axis(b.line)));
  entries.sort((a, b) => axis(a.label).compareTo(axis(b.label)));

  final position = orderedOwners.indexWhere(
    (entry) => entry.index == ownerIndex,
  );
  return position < 0 ? null : entries[position].text;
}

List<({OcrLine ownerLine, String text})> _fieldValuesForLabel(
  List<OcrLine> lines,
  OcrLine label,
  _ComponentField field,
) {
  if (!_hasGeometry(label)) return const [];
  final match = _fieldLabel(field).firstMatch(label.text.trim());
  if (match == null) return const [];
  final inlineValue = label.text.trim().substring(match.end).trim();
  if (inlineValue.isNotEmpty && _isFieldValue(inlineValue, field)) {
    return [(ownerLine: label, text: inlineValue)];
  }

  final rowLabels = lines.where(
    (other) =>
        !identical(other, label) &&
        _hasGeometry(other) &&
        _sameVisualRow(label, other) &&
        _isAnyFieldLabel(other.text),
  );
  var rightBoundary = double.infinity;
  for (final other in rowLabels) {
    if (other.left >= label.right && other.left < rightBoundary) {
      rightBoundary = other.left;
    }
  }
  final rowValues = [
    for (final candidate in lines)
      if (!identical(candidate, label) &&
          _hasGeometry(candidate) &&
          _sameVisualRow(label, candidate) &&
          candidate.left >= label.right &&
          candidate.left < rightBoundary &&
          _isFieldValue(candidate.text, field))
        (ownerLine: candidate, text: candidate.text.trim()),
  ];
  if (rowValues.isNotEmpty) return rowValues;

  var bottomBoundary = double.infinity;
  for (final other in lines) {
    if (identical(other, label) ||
        !_hasGeometry(other) ||
        !_isAnyFieldLabel(other.text) ||
        other.top < label.bottom ||
        !_sameVisualColumn(label, other)) {
      continue;
    }
    if (other.top < bottomBoundary) bottomBoundary = other.top;
  }
  return [
    for (final candidate in lines)
      if (!identical(candidate, label) &&
          _hasGeometry(candidate) &&
          candidate.top >= label.bottom &&
          candidate.top < bottomBoundary &&
          _sameVisualColumn(label, candidate) &&
          _isFieldValue(candidate.text, field))
        (ownerLine: candidate, text: candidate.text.trim()),
  ];
}

bool _sameVisualRow(OcrLine a, OcrLine b) {
  final height = a.height > b.height ? a.height : b.height;
  return height > 0 && (a.centerY - b.centerY).abs() <= 0.6 * height;
}

bool _sameVisualColumn(OcrLine a, OcrLine b) {
  final widthA = a.right - a.left;
  final widthB = b.right - b.left;
  final tolerance = (widthA > widthB ? widthA : widthB).clamp(20, 120);
  return (((a.left + a.right) / 2) - ((b.left + b.right) / 2)).abs() <=
      tolerance;
}

int? _ownerForLine(
  OcrLine value,
  List<_CountryMention> mentions, [
  List<OcrLine>? lines,
]) {
  final explicit = lines == null
      ? null
      : _numberedSectionAnchors(lines, mentions);
  final geometric =
      explicit ??
      <(int, OcrLine)>[
        for (var i = 0; i < mentions.length; i++)
          if (_hasGeometry(mentions[i].line)) (i, mentions[i].line),
      ];
  if (_hasGeometry(value) && geometric.isNotEmpty) {
    final xs = geometric.map((entry) => (entry.$2.left + entry.$2.right) / 2);
    final ys = geometric.map((entry) => entry.$2.centerY);
    final xSpread = xs.reduce((a, b) => a < b ? a : b);
    final xMax = xs.reduce((a, b) => a > b ? a : b);
    final ySpread = ys.reduce((a, b) => a < b ? a : b);
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final horizontal = xMax - xSpread > yMax - ySpread;
    final valueAxis = horizontal
        ? (value.left + value.right) / 2
        : value.centerY;
    int? best;
    var bestDistance = double.infinity;
    var secondDistance = double.infinity;
    for (final entry in geometric) {
      final anchorAxis = horizontal
          ? (entry.$2.left + entry.$2.right) / 2
          : entry.$2.centerY;
      final distance = (valueAxis - anchorAxis).abs();
      if (distance < bestDistance) {
        secondDistance = bestDistance;
        best = entry.$1;
        bestDistance = distance;
      } else if (distance < secondDistance) {
        secondDistance = distance;
      }
    }
    // ML Kit coordinates are fractional; sub-pixel distance differences do
    // not establish ownership and must not depend on OCR serialization order.
    if ((secondDistance - bestDistance).abs() <= 0.5) return null;
    return best;
  }
  return null;
}

List<(int, OcrLine)>? _numberedSectionAnchors(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
) {
  final headers = <OcrLine>[
    for (final line in lines)
      if (_hasGeometry(line) &&
          _numberedComponentSectionLabel.hasMatch(line.text.trim()))
        line,
  ];
  final countries = <(int, OcrLine)>[
    for (var i = 0; i < mentions.length; i++)
      if (_hasGeometry(mentions[i].line)) (i, mentions[i].line),
  ];
  if (headers.length < 2 || countries.length < 2) return null;

  final xs = headers.map((line) => (line.left + line.right) / 2);
  final ys = headers.map((line) => line.centerY);
  final horizontal = _axisRange(xs) > _axisRange(ys);
  double axis(OcrLine line) =>
      horizontal ? (line.left + line.right) / 2 : line.centerY;
  headers.sort((a, b) => axis(a).compareTo(axis(b)));
  countries.sort((a, b) => axis(a.$2).compareTo(axis(b.$2)));

  final count = headers.length < countries.length
      ? headers.length
      : countries.length;
  return [for (var i = 0; i < count; i++) (countries[i].$1, headers[i])];
}

double _axisRange(Iterable<double> values) {
  final iterator = values.iterator;
  if (!iterator.moveNext()) return 0;
  var min = iterator.current;
  var max = iterator.current;
  while (iterator.moveNext()) {
    final value = iterator.current;
    if (value < min) min = value;
    if (value > max) max = value;
  }
  return max - min;
}

bool _isAnyFieldLabel(String text) => _ComponentField.values.any(
  (field) => _fieldLabel(field).hasMatch(text.trim()),
);

bool _isFieldValue(String text, _ComponentField field) {
  final trimmed = text.trim();
  if (trimmed.isEmpty ||
      _isAnyFieldLabel(trimmed) ||
      _matchesIn(trimmed).isNotEmpty) {
    return false;
  }
  return switch (field) {
    _ComponentField.region =>
      !_nonRegionLabel.hasMatch(trimmed) &&
          firstProcessMatch(trimmed) == null &&
          !ratioPattern.hasMatch(trimmed),
    _ComponentField.process => !_nonRegionLabel.hasMatch(trimmed),
    _ComponentField.ratio => ratioPattern.hasMatch(trimmed),
  };
}

int? _ratioFrom(String text) {
  final match = ratioPattern.firstMatch(text);
  return match == null ? null : int.parse(match.group(1)!);
}

int? _leadingRatio(List<String> segment) {
  for (final text in segment) {
    final value = text.trim();
    if (value.isEmpty) continue;
    return _ratioFrom(value);
  }
  return null;
}

int? _labeledRatio(List<String> segment) {
  for (var i = 0; i < segment.length; i++) {
    final text = segment[i].trim();
    if (!_ratioLabelPrefix.hasMatch(text)) continue;
    final inline = text.replaceFirst(_ratioLabelPrefix, '');
    final inlineRatio = _ratioFrom(inline);
    if (inlineRatio != null) return inlineRatio;
    if (inline.isNotEmpty) continue;
    for (var valueIndex = i + 1; valueIndex < segment.length; valueIndex++) {
      final value = segment[valueIndex].trim();
      if (value.isEmpty) continue;
      return _ratioFrom(value);
    }
  }
  return null;
}

String? _cleanRegion(String text) {
  var cleaned = text.trim().replaceFirst(_regionLabelPrefix, '').trim();
  return cleaned.isEmpty ? null : cleaned;
}

List<String> _segmentTexts(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int index,
) {
  final current = mentions[index];
  final next = index + 1 < mentions.length ? mentions[index + 1] : null;
  final endOnAnchorLine = next != null && next.lineIndex == current.lineIndex
      ? next.textOffset
      : current.line.text.length;
  final texts = <String>[
    current.line.text.substring(
      current.textOffset + current.matchLength,
      endOnAnchorLine,
    ),
  ];
  if (next?.lineIndex == current.lineIndex) return texts;

  final endLine = next?.lineIndex ?? lines.length;
  for (
    var lineIndex = current.lineIndex + 1;
    lineIndex < endLine;
    lineIndex++
  ) {
    texts.add(lines[lineIndex].text);
  }
  return texts;
}

({Process process, Set<int> valueIndexes})? _labeledProcess(
  List<String> segment,
) {
  for (var i = 0; i < segment.length; i++) {
    final text = segment[i].trim();
    final inline = _inlineProcessLabel.firstMatch(text);
    if (inline != null) {
      return (
        process: _labeledProcessValue(inline.group(1)!),
        valueIndexes: {i},
      );
    }
    if (!_bareProcessLabel.hasMatch(text)) continue;
    for (var valueIndex = i + 1; valueIndex < segment.length; valueIndex++) {
      final value = segment[valueIndex].trim();
      if (value.isEmpty) continue;
      if (_nonRegionLabel.hasMatch(value) ||
          _regionLabelPrefix.hasMatch(value)) {
        break;
      }
      return (process: _labeledProcessValue(value), valueIndexes: {valueIndex});
    }
  }
  return null;
}

Process _labeledProcessValue(String value) {
  final normalized = value.toLowerCase().trim();
  for (final entry in processKeywords.entries) {
    if (normalized == entry.key) return entry.value;
  }
  return Process.other;
}

String? _firstRegion(List<String> segment, Set<int> excludedIndexes) {
  for (var i = 0; i < segment.length; i++) {
    if (excludedIndexes.contains(i)) continue;
    var text = segment[i];
    text = text.trim();
    if (text.isEmpty || _nonRegionLabel.hasMatch(text)) continue;
    text = text.replaceFirst(_regionLabelPrefix, '');
    for (final country in countryKeywords.keys) {
      text = text.replaceAll(
        RegExp(RegExp.escape(country), caseSensitive: false),
        ' ',
      );
    }
    for (final process in processKeywords.keys) {
      text = text.replaceAll(
        RegExp(RegExp.escape(process), caseSensitive: false),
        ' ',
      );
    }
    text = text
        .replaceAll(ratioPattern, ' ')
        .replaceAll(RegExp(r'[/|·,;:：()\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isNotEmpty && !_nonRegionLabel.hasMatch(text)) return text;
  }
  return null;
}
