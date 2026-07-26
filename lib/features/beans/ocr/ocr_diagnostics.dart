import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;

import '../../../services/image_quality_analyzer.dart';
import '../../../services/ocr_image_preprocessor.dart';
import '../../../services/ocr_service.dart';
import 'ocr_candidate.dart';
import 'ocr_draft.dart';

abstract interface class OcrDiagnosticsService {
  Future<String> collect(String imagePath);
}

class OcrImageMetadata {
  final int width;
  final int height;
  final int? exifOrientation;

  const OcrImageMetadata({
    required this.width,
    required this.height,
    required this.exifOrientation,
  });
}

class OcrDiagnosticAttempt {
  final OcrCandidate candidate;
  final String? errorType;

  const OcrDiagnosticAttempt(this.candidate, {this.errorType});
}

class OcrDiagnosticsReport {
  final String platform;
  final OcrImageMetadata? image;
  final String? imageErrorType;
  final ImageQualityReport quality;
  final String? qualityErrorType;
  final OcrDiagnosticAttempt original;
  final OcrDiagnosticAttempt? enhanced;
  final String? enhancementErrorType;
  final String? cleanupErrorType;
  final OcrCandidateSelection selection;

  const OcrDiagnosticsReport({
    required this.platform,
    required this.image,
    required this.imageErrorType,
    required this.quality,
    required this.qualityErrorType,
    required this.original,
    required this.enhanced,
    required this.enhancementErrorType,
    required this.cleanupErrorType,
    required this.selection,
  });

  String toClipboardText() {
    final output = StringBuffer()
      ..writeln('=== BEANPROFILE OCR DIAGNOSTICS v1 ===')
      ..writeln('platform: ${_oneLine(platform)}')
      ..writeln(
        image == null
            ? 'image: unavailable'
            : 'image: ${image!.width}x${image!.height}, '
                  'exifOrientation=${image!.exifOrientation ?? 'null'}',
      )
      ..writeln('imageError: ${imageErrorType ?? 'none'}')
      ..writeln(
        'quality: ${quality.issues.isEmpty ? 'none' : quality.issues.map((issue) => issue.name).join(',')}',
      )
      ..writeln('qualityError: ${qualityErrorType ?? 'none'}');
    _writeAttempt(output, 'ORIGINAL', original);
    if (enhanced == null) {
      output
        ..writeln()
        ..writeln('--- ENHANCED ---')
        ..writeln('unavailable');
    } else {
      _writeAttempt(output, 'ENHANCED', enhanced!);
    }
    output
      ..writeln('enhancementError: ${enhancementErrorType ?? 'none'}')
      ..writeln('cleanupError: ${cleanupErrorType ?? 'none'}')
      ..writeln()
      ..writeln('--- FINAL ---')
      ..writeln(
        'selected: ${selection.usedEnhanced ? 'enhanced' : 'original'}',
      );
    _writeDraft(output, selection.draft);
    return output.toString().trimRight();
  }
}

class DefaultOcrDiagnosticsService implements OcrDiagnosticsService {
  final OcrService ocr;
  final ImageQualityAnalyzer qualityAnalyzer;
  final OcrImagePreprocessor preprocessor;
  final String platform;

  const DefaultOcrDiagnosticsService({
    required this.ocr,
    required this.qualityAnalyzer,
    required this.preprocessor,
    required this.platform,
  });

  @override
  Future<String> collect(String imagePath) async {
    OcrImageMetadata? image;
    String? imageErrorType;
    try {
      image = await _readImageMetadata(imagePath);
    } catch (error) {
      imageErrorType = _errorType(error);
    }

    var quality = const ImageQualityReport();
    String? qualityErrorType;
    try {
      quality = await qualityAnalyzer.analyze(imagePath);
    } catch (error) {
      qualityErrorType = _errorType(error);
    }

    late final OcrDiagnosticAttempt original;
    try {
      original = OcrDiagnosticAttempt(
        buildOcrCandidate(await ocr.recognize(imagePath), false),
      );
    } catch (error) {
      original = OcrDiagnosticAttempt(
        buildOcrCandidate(const [], false),
        errorType: _errorType(error),
      );
    }

    String? enhancedPath;
    OcrDiagnosticAttempt? enhanced;
    String? enhancementErrorType;
    String? cleanupErrorType;
    try {
      enhancedPath = await preprocessor.enhance(imagePath);
      enhanced = OcrDiagnosticAttempt(
        buildOcrCandidate(await ocr.recognize(enhancedPath), true),
      );
    } catch (error) {
      enhancementErrorType = _errorType(error);
    } finally {
      if (enhancedPath != null) {
        try {
          await preprocessor.delete(enhancedPath);
        } catch (error) {
          cleanupErrorType = _errorType(error);
        }
      }
    }

    final selection = selectOcrCandidates(
      original.candidate,
      enhanced?.candidate,
    );
    return OcrDiagnosticsReport(
      platform: platform,
      image: image,
      imageErrorType: imageErrorType,
      quality: quality,
      qualityErrorType: qualityErrorType,
      original: original,
      enhanced: enhanced,
      enhancementErrorType: enhancementErrorType,
      cleanupErrorType: cleanupErrorType,
      selection: selection,
    ).toClipboardText();
  }
}

Future<OcrImageMetadata?> _readImageMetadata(String imagePath) {
  return Isolate.run(() async {
    final bytes = await File(imagePath).readAsBytes();
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder == null || info == null) return null;
    final exif = decoder.format == img.ImageFormat.jpg
        ? img.decodeJpgExif(bytes)
        : null;
    return OcrImageMetadata(
      width: info.width,
      height: info.height,
      exifOrientation: exif?.imageIfd.orientation,
    );
  });
}

String _oneLine(String value) =>
    value.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

String _coordinate(double value) => value.toStringAsFixed(1);

String _errorType(Object error) => error.runtimeType.toString();

void _writeAttempt(
  StringBuffer output,
  String title,
  OcrDiagnosticAttempt attempt,
) {
  final candidate = attempt.candidate;
  output
    ..writeln()
    ..writeln('--- $title ---')
    ..writeln('error: ${attempt.errorType ?? 'none'}')
    ..writeln(
      'candidate: required=${candidate.requiredCount}, '
      'countries=${candidate.countryComponentCount}, '
      'filled=${candidate.filledFieldCount}, '
      'labels=${candidate.knownLabelCount}, '
      'meanConfidence=${candidate.meanConfidence?.toStringAsFixed(3) ?? 'null'}, '
      'weak=${isWeakOcr(candidate)}',
    );
  for (final line in candidate.lines) {
    output.writeln(
      '[${_coordinate(line.left)},${_coordinate(line.top)},'
      '${_coordinate(line.right)},${_coordinate(line.bottom)}] '
      'confidence=${line.confidence?.toStringAsFixed(3) ?? 'null'} | '
      '${_oneLine(line.text)}',
    );
  }
  _writeDraft(output, candidate.draft);
}

void _writeDraft(StringBuffer output, OcrDraft draft) {
  output
    ..writeln('draft.name: ${_nullableText(draft.name)}')
    ..writeln('draft.roaster: ${_nullableText(draft.roaster)}')
    ..writeln(
      'draft.roastDate: ${draft.roastDate?.toIso8601String() ?? 'null'}',
    )
    ..writeln('draft.roastLevel: ${draft.roastLevel?.name ?? 'null'}')
    ..writeln('draft.type: ${draft.typeDecision.name}')
    ..writeln(
      'draft.typeReasons: '
      '${draft.typeReasons.map((reason) => reason.name).join(',')}',
    )
    ..writeln('draft.cupNotes: ${draft.cupNotes.map(_oneLine).join(' | ')}')
    ..writeln('draft.chips: ${draft.chips.map(_oneLine).join(' | ')}');
  for (final (index, component) in draft.components.indexed) {
    output.writeln(
      'component[$index]: country=${_nullableText(component.country)} '
      'ratio=${component.ratioPercent ?? 'null'} '
      'region=${_nullableText(component.region)} '
      'process=${component.process?.name ?? 'null'}',
    );
  }
}

String _nullableText(String? value) => value == null ? 'null' : _oneLine(value);
