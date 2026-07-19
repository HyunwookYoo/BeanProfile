import '../../../data/enums.dart';
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

OcrDraft parseOcrText(String rawText) {
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final lower = rawText.toLowerCase();
  return OcrDraft(
    country: _firstMatch(lower, _countries),
    region: _matchRegion(lines),
    roastDate: _matchDate(rawText),
    roastLevel: _firstMatch(lower, _roastKeywords),
    process: _firstMatch(lower, _processKeywords),
    cupNotes: _matchCupNotes(lines),
    chips: _dedupe(lines),
  );
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
    if (m != null) {
      return m.group(2)!
          .split(RegExp(r'[,/·、]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

String? _matchRegion(List<String> lines) {
  for (final line in lines) {
    final m = _regionLabel.firstMatch(line);
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
