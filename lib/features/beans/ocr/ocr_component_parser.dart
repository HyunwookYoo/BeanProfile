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
final componentContext = RegExp(
  r'blend|블렌드|origin|원산지|component|구성',
  caseSensitive: false,
);

final _explicitRepeatedContext = RegExp(
  r'blend|블렌드|component|구성',
  caseSensitive: false,
);
final _originLabel = RegExp(
  r'^(origin|원산지|생산지)\s*[:：]?$',
  caseSensitive: false,
);
final _regionLabelPrefix = RegExp(
  r'^(region|지역)\s*[:：]?\s*',
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
  final joined = lines.map((line) => line.text).join('\n');
  final admitted = <_CountryMention>[mentions.first];
  for (final mention in mentions.skip(1)) {
    final sharesLine = mentions.any(
      (other) =>
          !identical(other, mention) && other.lineIndex == mention.lineIndex,
    );
    final matchesRow = mentions.any(
      (other) =>
          !identical(other, mention) &&
          other.lineIndex != mention.lineIndex &&
          _rowsAlign(mention.line, other.line),
    );
    if (mention.ratio != null ||
        componentContext.hasMatch(joined) ||
        sharesLine ||
        matchesRow) {
      admitted.add(mention);
    }
  }

  return [
    for (var i = 0; i < admitted.length; i++) _componentFor(lines, admitted, i),
  ];
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
  final joined = lines.map((line) => line.text).join('\n');
  final hasExplicitRepeatedEvidence =
      _explicitRepeatedContext.hasMatch(joined) ||
      mentions.any((mention) => mention.ratio != null) ||
      mentions.any(
        (mention) =>
            mentions
                .where((other) => other.lineIndex == mention.lineIndex)
                .length >
            1,
      ) ||
      mentions.map((mention) => mention.country).toSet().length > 1;
  if (hasExplicitRepeatedEvidence) return mentions;

  final removed = <_CountryMention>{};
  for (var i = 0; i < mentions.length; i++) {
    final title = mentions[i];
    for (var j = i + 1; j < mentions.length; j++) {
      final structured = mentions[j];
      if (title.country == structured.country &&
          title.ratio == null &&
          structured.ratio == null &&
          _isDescriptiveBefore(title, structured) &&
          _isStructuredCountry(structured, lines)) {
        removed.add(title);
        break;
      }
    }
  }
  return mentions.where((mention) => !removed.contains(mention)).toList();
}

bool _isDescriptiveBefore(_CountryMention first, _CountryMention later) {
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
  return remainder.replaceAll(RegExp(r'[\s\-–—|/·:：]+'), '').isNotEmpty;
}

bool _hasGeometry(OcrLine line) =>
    line.height > 0 && line.right > line.left;

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

bool _rowsAlign(OcrLine a, OcrLine b) {
  if (a.height <= 0 ||
      b.height <= 0 ||
      a.right <= a.left ||
      b.right <= b.left) {
    return false;
  }
  final height = a.height > b.height ? a.height : b.height;
  final tolerance = 2 * (height > 20 ? height : 20);
  return (a.left - b.left).abs() <= tolerance;
}

OcrComponentDraft _componentFor(
  List<OcrLine> lines,
  List<_CountryMention> mentions,
  int index,
) {
  final mention = mentions[index];
  final segment = _segmentTexts(lines, mentions, index);
  final labeledProcess = _labeledProcess(segment);
  return OcrComponentDraft(
    country: mention.country,
    region: mentions.length == 1
        ? null
        : _firstRegion(
            segment,
            labeledProcess?.valueIndexes ?? const {},
          ),
    process:
        labeledProcess?.process ?? firstProcessMatch(segment.join('\n')),
    ratioPercent: mention.ratio,
  );
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
    for (var valueIndex = i + 1;
        valueIndex < segment.length;
        valueIndex++) {
      final value = segment[valueIndex].trim();
      if (value.isEmpty) continue;
      if (_nonRegionLabel.hasMatch(value) ||
          _regionLabelPrefix.hasMatch(value)) {
        break;
      }
      return (
        process: _labeledProcessValue(value),
        valueIndexes: {valueIndex},
      );
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
