import '../../../services/image_quality_analyzer.dart';
import '../../../services/ocr_image_preprocessor.dart';
import '../../../services/ocr_service.dart';
import 'ocr_candidate.dart';
import 'ocr_draft.dart';

class OcrPipelineResult {
  final OcrDraft draft;
  final ImageQualityReport quality;
  final bool usedEnhanced;
  final bool shouldWarnQuality;
  const OcrPipelineResult({
    required this.draft,
    required this.quality,
    required this.usedEnhanced,
    required this.shouldWarnQuality,
  });
}

abstract interface class OcrPipeline {
  Future<OcrPipelineResult> analyze(String imagePath);
}

class DefaultOcrPipeline implements OcrPipeline {
  final OcrService ocr;
  final ImageQualityAnalyzer qualityAnalyzer;
  final OcrImagePreprocessor preprocessor;
  const DefaultOcrPipeline({
    required this.ocr,
    required this.qualityAnalyzer,
    required this.preprocessor,
  });

  @override
  Future<OcrPipelineResult> analyze(String imagePath) async {
    ImageQualityReport quality;
    try {
      quality = await qualityAnalyzer.analyze(imagePath);
    } catch (_) {
      quality = const ImageQualityReport();
    }

    final original = buildOcrCandidate(await ocr.recognize(imagePath), false);
    if (!quality.lowContrast && !isWeakOcr(original)) {
      return OcrPipelineResult(
        draft: original.draft,
        quality: quality,
        usedEnhanced: false,
        shouldWarnQuality: false,
      );
    }

    String? enhancedPath;
    OcrCandidate? enhanced;
    try {
      enhancedPath = await preprocessor.enhance(imagePath);
      enhanced = buildOcrCandidate(await ocr.recognize(enhancedPath), true);
    } catch (_) {
      enhanced = null;
    } finally {
      if (enhancedPath != null) {
        try {
          await preprocessor.delete(enhancedPath);
        } catch (_) {
          // Cleanup failure must not discard the usable OCR result.
        }
      }
    }

    final selection = selectOcrCandidates(original, enhanced);
    final finalCandidate = OcrCandidate(
      lines: selection.selected.lines,
      draft: selection.draft,
      knownLabelCount: selection.selected.knownLabelCount,
      fromEnhanced: selection.selected.fromEnhanced,
    );
    return OcrPipelineResult(
      draft: selection.draft,
      quality: quality,
      usedEnhanced: selection.usedEnhanced,
      shouldWarnQuality: quality.hasIssues && isWeakOcr(finalCandidate),
    );
  }
}
