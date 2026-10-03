// OCR 코퍼스 — 픽스처 모델, 파이프라인 재생, 베이스라인.
// 설계: docs/plans/ocr-corpus-design.md §4.1·§4.4.
import 'dart:convert';
import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';

import 'ocr_score.dart';

/// 카드 한 장의 ML Kit 출력(`<id>.ocr.json`). 형식은 설계 §4.1.
class CorpusFixture {
  final String id;
  final String source;

  /// null이면 기록이 없다 — 빈 보고서로 재생한다.
  final Set<ImageQualityIssue>? quality;

  /// ML Kit이 준 순서 그대로다. 파서에 순서 의존 경로가 있어 재정렬하면 안 된다.
  final List<OcrLine> original;

  /// null이면 보정 패스가 없다 — 기기에서 보정이 실패한 것처럼 재생한다.
  final List<OcrLine>? enhanced;

  const CorpusFixture({
    required this.id,
    required this.source,
    required this.quality,
    required this.original,
    required this.enhanced,
  });

  factory CorpusFixture.fromJson(Map<String, Object?> json) {
    requireKeys(
        json, const {'id', 'source', 'quality', 'original', 'enhanced'}, 'fixture');
    List<OcrLine> lines(Object? raw) => [
          for (final item in raw! as List) _line((item as Map).cast<String, Object?>()),
        ];
    final quality = json['quality'] as List?;
    final enhanced = json['enhanced'];
    return CorpusFixture(
      id: json['id']! as String,
      source: json['source']! as String,
      quality: quality == null
          ? null
          : {
              for (final name in quality)
                ImageQualityIssue.values.byName(name as String),
            },
      original: lines(json['original']),
      enhanced: enhanced == null ? null : lines(enhanced),
    );
  }

  static OcrLine _line(Map<String, Object?> json) => OcrLine(
        json['text']! as String,
        left: (json['l']! as num).toDouble(),
        top: (json['t']! as num).toDouble(),
        right: (json['r']! as num).toDouble(),
        bottom: (json['b']! as num).toDouble(),
        confidence: (json['conf'] as num?)?.toDouble(),
      );
}

const _originalPath = 'corpus/original';
const _enhancedPath = 'corpus/enhanced';

/// 기록된 ML Kit 출력으로 실제 [DefaultOcrPipeline]을 돌린다. seam 세 개만
/// 바꾸므로 분기·후보 선택·병합이 기기와 같은 코드로 돈다.
Future<OcrDraft> replayPipeline(CorpusFixture fixture) async {
  final pipeline = DefaultOcrPipeline(
    ocr: _ReplayOcr(fixture),
    qualityAnalyzer: _ReplayQuality(ImageQualityReport(fixture.quality ?? const {})),
    preprocessor: _ReplayPreprocessor(hasEnhanced: fixture.enhanced != null),
  );
  return (await pipeline.analyze(_originalPath)).draft;
}

class _ReplayOcr implements OcrService {
  _ReplayOcr(this.fixture);
  final CorpusFixture fixture;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async =>
      imagePath == _enhancedPath ? fixture.enhanced! : fixture.original;
}

class _ReplayQuality implements ImageQualityAnalyzer {
  _ReplayQuality(this.report);
  final ImageQualityReport report;

  @override
  Future<ImageQualityReport> analyze(String imagePath) async => report;
}

class _ReplayPreprocessor implements OcrImagePreprocessor {
  _ReplayPreprocessor({required this.hasEnhanced});
  final bool hasEnhanced;

  @override
  Future<String> enhance(String imagePath) async {
    // 기록이 없으면 보정 실패로 재생한다 — 파이프라인은 그때 원본 후보만으로 고른다.
    if (!hasEnhanced) throw StateError('보정 패스 기록 없음');
    return _enhancedPath;
  }

  @override
  Future<void> delete(String imagePath) async {}
}

/// 픽스처와 정답표 한 쌍.
class CorpusCard {
  final CorpusFixture fixture;
  final Truth truth;
  const CorpusCard(this.fixture, this.truth);

  String get id => fixture.id;
}

/// `<id>.ocr.json`과 `<id>.truth.json`을 짝지어 읽는다. 다른 파일(baseline.json,
/// sources.json)은 무시한다.
List<CorpusCard> loadCorpus(Directory dir) {
  if (!dir.existsSync()) {
    // 0장으로 조용히 통과하면 게이트가 아무것도 지키지 않는다.
    throw StateError('코퍼스 폴더가 없다: ${dir.absolute.path} — 저장소 루트에서 '
        'flutter test를 실행했는지 확인');
  }
  final ocrFiles = <String, File>{};
  final truthFiles = <String, File>{};
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.endsWith('.ocr.json')) {
      ocrFiles[name.substring(0, name.length - '.ocr.json'.length)] = file;
    } else if (name.endsWith('.truth.json')) {
      truthFiles[name.substring(0, name.length - '.truth.json'.length)] = file;
    }
  }
  final orphans = [
    for (final id in ocrFiles.keys)
      if (!truthFiles.containsKey(id)) '$id.ocr.json (정답표 없음)',
    for (final id in truthFiles.keys)
      if (!ocrFiles.containsKey(id)) '$id.truth.json (픽스처 없음)',
  ];
  if (orphans.isNotEmpty) {
    throw StateError('짝이 없는 파일:\n${orphans.join('\n')}');
  }
  return [
    for (final id in ocrFiles.keys.toList()..sort())
      _card(id, ocrFiles[id]!, truthFiles[id]!),
  ];
}

CorpusCard _card(String id, File ocrFile, File truthFile) {
  final fixture = _read(ocrFile, CorpusFixture.fromJson);
  final truth = _read(truthFile, Truth.fromJson);
  if (fixture.id != id || truth.id != id) {
    throw FormatException(
        '$id: 파일 이름과 id가 다르다 (픽스처 ${fixture.id}, 정답표 ${truth.id})');
  }
  return CorpusCard(fixture, truth);
}

T _read<T>(File file, T Function(Map<String, Object?> json) parse) {
  try {
    return parse(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
  } on FormatException catch (error) {
    throw FormatException('${file.path}: ${error.message}');
  } catch (error) {
    throw FormatException('${file.path}: $error');
  }
}

/// card → cell → [Cell.encoded].
typedef Baseline = Map<String, Map<String, String>>;

Baseline toBaseline(Map<String, List<Cell>> scored) => {
      for (final MapEntry(:key, :value) in scored.entries)
        key: {for (final cell in value) cell.key: cell.encoded},
    };

/// 카드·칸을 정렬해 쓴다 — 갱신 diff가 바뀐 칸만 보이게.
String encodeBaseline(Baseline baseline) {
  final sorted = {
    for (final card in baseline.keys.toList()..sort())
      card: {
        for (final cell in baseline[card]!.keys.toList()..sort())
          cell: baseline[card]![cell]!,
      },
  };
  return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
}

Baseline decodeBaseline(String text) => {
      for (final MapEntry(:key, :value)
          in (jsonDecode(text) as Map<String, Object?>).entries)
        key: Map<String, String>.from(value! as Map),
    };

/// 바뀐 칸만 낸다. 총점이 아니라 칸 단위라서, 한 칸 고치고 한 칸 깨도
/// 상쇄되지 않는다(설계 §4.4).
List<String> diffBaseline(Baseline before, Baseline after) {
  final lines = <String>[];
  for (final card in {...before.keys, ...after.keys}.toList()..sort()) {
    final was = before[card] ?? const <String, String>{};
    final now = after[card] ?? const <String, String>{};
    for (final cell in {...was.keys, ...now.keys}.toList()..sort()) {
      if (was[cell] != now[cell]) {
        lines.add('$card  $cell  ${was[cell] ?? '(없음)'} → ${now[cell] ?? '(없음)'}');
      }
    }
  }
  return lines;
}
