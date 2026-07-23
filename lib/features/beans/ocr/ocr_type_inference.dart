import '../../../services/ocr_service.dart';
import 'ocr_draft.dart';

class OcrTypeInference {
  final OcrTypeDecision decision;
  final Set<OcrTypeReason> reasons;
  const OcrTypeInference(this.decision, this.reasons);
}

String _normalizedText(List<OcrLine> lines) => lines
    .map((line) => line.text.toLowerCase())
    .join(' ')
    .replaceAll(RegExp(r'[-_]'), ' ')
    .replaceAll(RegExp(r'[^a-z0-9가-힣]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _hasEnglishPhrase(String text, String phrase) =>
    RegExp('(^| )${RegExp.escape(phrase)}( |\$)').hasMatch(text);

OcrTypeInference inferBeanType(
  List<OcrLine> lines,
  List<OcrComponentDraft> components,
) {
  final text = _normalizedText(lines);
  final explicitBlend =
      _hasEnglishPhrase(text, 'blend') ||
      _hasEnglishPhrase(text, 'house blend') ||
      text.split(' ').contains('블렌드');
  final explicitSingle =
      _hasEnglishPhrase(text, 'single origin') || text.contains('싱글 오리진');
  final multiple = components.where((component) => component.country != null).length >= 2;

  if ((explicitBlend && explicitSingle) || (explicitSingle && multiple)) {
    return const OcrTypeInference(
      OcrTypeDecision.ambiguous,
      {OcrTypeReason.conflictingSignals},
    );
  }
  if (explicitBlend || multiple) {
    return OcrTypeInference(OcrTypeDecision.certainBlend, {
      if (explicitBlend) OcrTypeReason.explicitBlend,
      if (multiple) OcrTypeReason.multipleComponents,
    });
  }
  if (explicitSingle) {
    return const OcrTypeInference(
      OcrTypeDecision.certainSingle,
      {OcrTypeReason.explicitSingle},
    );
  }
  return const OcrTypeInference(
    OcrTypeDecision.ambiguous,
    {OcrTypeReason.insufficientEvidence},
  );
}
