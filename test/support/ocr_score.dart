// OCR 코퍼스 채점기 — 정답표 모델과 순수 채점 함수.
// 설계: docs/plans/ocr-corpus-design.md §4.3.
// 파서 코드를 import하지 않는다 — 채점 기준이 파서에 기대면 파서가 바뀔 때
// 기준도 같이 움직여 아무것도 재지 못한다.
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';

/// 칸 하나의 판정.
enum Verdict { correct, missing, wrong }

/// 채점된 칸.
class Cell {
  final String key;
  final Verdict verdict;

  /// 파서가 낸 값(정규화 전). 비었으면 null.
  final String? actual;

  /// 정답으로 받아주는 값들(정규화 전). 리포트의 파서/OCR 구분에 쓴다.
  final List<String> expected;

  const Cell(this.key, this.verdict, this.actual, this.expected);

  /// baseline.json에 적는 값. 틀린 칸은 무엇으로 틀렸는지까지 남긴다 —
  /// 오채움이 다른 오채움으로 바뀌는 것도 변화다(인라인 블렌드 브랜치에서
  /// 상한 하나를 조였더니 지역이 null이 아니라 `Designed for`로 바뀌었다).
  String get encoded => switch (verdict) {
        Verdict.correct => 'correct',
        Verdict.missing => 'missing',
        Verdict.wrong => 'wrong: $actual',
      };
}

/// 공백을 모두 지우고 소문자로. OCR 자간 오독(`베이스캠프 로스 터스`)을 흡수한다.
String normalize(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// JSON 객체의 키가 정확히 맞는지 본다. 정답표·픽스처는 손으로 쓰고 고치므로
/// 오타 난 키가 조용히 null로 읽히면 안 된다.
void requireKeys(
  Map<String, Object?> json,
  Set<String> required,
  String at, {
  Set<String> optional = const {},
}) {
  final keys = json.keys.toSet();
  final missing = required.difference(keys);
  final unknown = keys.difference(required).difference(optional);
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException('$at: 빠진 키 $missing, 모르는 키 $unknown');
  }
}

/// 정답 한 칸. 정답표 JSON의 값 하나에서 만든다.
///
/// - `null` — 카드에 없다. 비우면 correct, 채우면 wrong.
/// - `"값"` — 이 값이면 correct, 비우면 missing, 다른 값이면 wrong.
/// - `["값1", "값2", null]` — 목록 중 하나면 correct. 목록에 null이 있으면
///   비워도 correct(정답표 규칙 R3·R5, 설계 §4.2).
class Accept {
  final List<String> raw;
  final Set<String> _values;
  final bool allowsEmpty;

  Accept._(this.raw, this.allowsEmpty)
      : _values = {for (final value in raw) normalize(value)};

  factory Accept.fromJson(
    Object? json, {
    required String field,
    bool Function(String value)? valid,
  }) {
    final items = switch (json) {
      null => const <Object?>[null],
      List<Object?> list => list,
      _ => <Object?>[json],
    };
    final raw = <String>[];
    var allowsEmpty = false;
    for (final item in items) {
      if (item == null) {
        allowsEmpty = true;
        continue;
      }
      if (item is! String && item is! int) {
        throw FormatException('$field: 문자열·정수·null만 쓸 수 있다 — $item');
      }
      final text = '$item';
      if (valid != null && !valid(text)) {
        throw FormatException('$field: 쓸 수 없는 값 "$text"');
      }
      raw.add(text);
    }
    return Accept._(raw, allowsEmpty);
  }

  Verdict judge(String? actual) {
    if (actual == null) return allowsEmpty ? Verdict.correct : Verdict.missing;
    return _values.contains(normalize(actual)) ? Verdict.correct : Verdict.wrong;
  }
}

/// 성분 하나의 정답.
class ComponentTruth {
  final Accept country;
  final Accept region;
  final Accept process;
  final Accept ratioPercent;

  ComponentTruth._(this.country, this.region, this.process, this.ratioPercent);

  factory ComponentTruth.fromJson(Map<String, Object?> json, String at) {
    requireKeys(json, const {'country', 'region', 'process', 'ratioPercent'}, at);
    return ComponentTruth._(
      Accept.fromJson(json['country'], field: '$at.country'),
      Accept.fromJson(json['region'], field: '$at.region'),
      Accept.fromJson(
        json['process'],
        field: '$at.process',
        valid: {for (final process in Process.values) process.name}.contains,
      ),
      Accept.fromJson(json['ratioPercent'], field: '$at.ratioPercent'),
    );
  }
}

/// 카드 한 장의 정답표(`<id>.truth.json`). 사진에서만 쓴다(설계 §4.2).
class Truth {
  final String id;
  final Accept name;
  final Accept roaster;
  final Accept roastDate;
  final Accept roastLevel;
  final Accept type;
  final List<String> cupNotes;
  final List<ComponentTruth> components;

  Truth._({
    required this.id,
    required this.name,
    required this.roaster,
    required this.roastDate,
    required this.roastLevel,
    required this.type,
    required this.cupNotes,
    required this.components,
  });

  factory Truth.fromJson(Map<String, Object?> json) {
    requireKeys(
      json,
      const {
        'id',
        'name',
        'roaster',
        'roastDate',
        'roastLevel',
        'type',
        'cupNotes',
        'components',
      },
      'truth',
      optional: const {'notes'},
    );
    final cupNotes = [for (final note in json['cupNotes']! as List) note as String];
    final seen = <String>{};
    for (final note in cupNotes) {
      if (!seen.add(normalize(note))) {
        throw FormatException('truth.cupNotes: 중복 "$note"');
      }
    }
    return Truth._(
      id: json['id']! as String,
      name: Accept.fromJson(json['name'], field: 'name'),
      roaster: Accept.fromJson(json['roaster'], field: 'roaster'),
      roastDate: Accept.fromJson(
        json['roastDate'],
        field: 'roastDate',
        valid: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch,
      ),
      roastLevel: Accept.fromJson(
        json['roastLevel'],
        field: 'roastLevel',
        valid: {for (final level in RoastLevel.values) level.name}.contains,
      ),
      type: Accept.fromJson(
        json['type'],
        field: 'type',
        valid: const {'single', 'blend'}.contains,
      ),
      cupNotes: cupNotes,
      components: [
        for (final (i, component) in (json['components']! as List).indexed)
          ComponentTruth.fromJson(
            (component as Map).cast<String, Object?>(),
            'components[$i]',
          ),
      ],
    );
  }
}

/// 초안 하나를 정답표와 맞춰 칸 목록을 낸다.
List<Cell> scoreDraft(Truth truth, OcrDraft draft) {
  final cells = <Cell>[
    _cell('name', truth.name, draft.name),
    _cell('roaster', truth.roaster, draft.roaster),
    _cell('roastDate', truth.roastDate,
        draft.roastDate?.toIso8601String().substring(0, 10)),
    _cell('roastLevel', truth.roastLevel, draft.roastLevel?.name),
    _cell('type', truth.type, switch (draft.typeDecision) {
      // 앱은 ambiguous일 때 사용자에게 유형을 묻는다 — 그게 이 앱의 빈칸이다.
      OcrTypeDecision.certainSingle => 'single',
      OcrTypeDecision.certainBlend => 'blend',
      OcrTypeDecision.ambiguous => null,
    }),
  ];

  // 컵노트는 노트 하나가 한 칸이다. 정답에 없는 실제 노트는 하나마다 wrong.
  final actualNotes = {for (final note in draft.cupNotes) normalize(note): note};
  final truthNotes = {for (final note in truth.cupNotes) normalize(note)};
  for (final note in truth.cupNotes) {
    final hit = actualNotes[normalize(note)];
    cells.add(Cell('cupNotes[$note]',
        hit == null ? Verdict.missing : Verdict.correct, hit, [note]));
  }
  for (final MapEntry(:key, :value) in actualNotes.entries) {
    if (!truthNotes.contains(key)) {
      cells.add(Cell('cupNotes[+$value]', Verdict.wrong, value, const []));
    }
  }

  // 성분은 index로 짝짓는다. 국가로 짝지으면 채점 대상(국가)에 기대는 순환이다.
  for (final (i, expected) in truth.components.indexed) {
    final actual = i < draft.components.length ? draft.components[i] : null;
    cells.addAll([
      _cell('components[$i].country', expected.country, actual?.country),
      _cell('components[$i].region', expected.region, actual?.region),
      _cell('components[$i].process', expected.process, actual?.process?.name),
      _cell('components[$i].ratioPercent', expected.ratioPercent,
          actual?.ratioPercent?.toString()),
    ]);
  }
  // 정답보다 많은 성분은 정답이 없는 칸이다 — 채운 값마다 wrong.
  for (var i = truth.components.length; i < draft.components.length; i++) {
    final extra = draft.components[i];
    for (final (field, value) in [
      ('country', extra.country),
      ('region', extra.region),
      ('process', extra.process?.name),
      ('ratioPercent', extra.ratioPercent?.toString()),
    ]) {
      if (value != null) {
        cells.add(Cell('components[$i].$field', Verdict.wrong, value, const []));
      }
    }
  }
  return cells;
}

Cell _cell(String key, Accept accept, String? actual) =>
    Cell(key, accept.judge(actual), actual, accept.raw);
