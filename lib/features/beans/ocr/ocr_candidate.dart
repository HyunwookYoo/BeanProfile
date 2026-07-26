import '../../../services/ocr_service.dart';
import 'ocr_draft.dart';
import 'ocr_parser.dart';
import 'ocr_type_inference.dart';

class OcrCandidate {
  final List<OcrLine> lines;
  final OcrDraft draft;
  final int knownLabelCount;
  final bool fromEnhanced;
  const OcrCandidate({
    required this.lines,
    required this.draft,
    required this.knownLabelCount,
    required this.fromEnhanced,
  });

  int get requiredCount =>
      (draft.name == null ? 0 : 1) + (countryComponentCount == 0 ? 0 : 1);

  int get countryComponentCount =>
      draft.components.where((component) => component.country != null).length;

  int get filledFieldCount =>
      (draft.name == null ? 0 : 1) +
      (draft.roaster == null ? 0 : 1) +
      (draft.roastDate == null ? 0 : 1) +
      (draft.roastLevel == null ? 0 : 1) +
      draft.components.fold(
        0,
        (count, component) =>
            count +
            (component.country == null ? 0 : 1) +
            (component.region == null ? 0 : 1) +
            (component.process == null ? 0 : 1) +
            (component.ratioPercent == null ? 0 : 1),
      );

  double? get meanConfidence {
    final values = lines
        .map((line) => line.confidence)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((sum, value) => sum + value) / values.length;
  }
}

OcrCandidate buildOcrCandidate(List<OcrLine> lines, bool fromEnhanced) =>
    OcrCandidate(
      lines: lines,
      draft: parseOcr(lines),
      knownLabelCount: lines.where((line) => isKnownOcrLabel(line.text)).length,
      fromEnhanced: fromEnhanced,
    );

bool isWeakOcr(OcrCandidate candidate) {
  final confidence = candidate.meanConfidence;
  return candidate.draft.name == null ||
      candidate.countryComponentCount == 0 ||
      candidate.lines.where((line) => line.text.trim().isNotEmpty).length < 4 ||
      (confidence != null && confidence < .65);
}

int compareOcrCandidates(OcrCandidate first, OcrCandidate second) {
  var comparison = first.requiredCount.compareTo(second.requiredCount);
  if (comparison != 0) return comparison;

  comparison = first.countryComponentCount.compareTo(
    second.countryComponentCount,
  );
  if (comparison != 0) return comparison;

  comparison = first.filledFieldCount.compareTo(second.filledFieldCount);
  if (comparison != 0) return comparison;

  comparison = first.knownLabelCount.compareTo(second.knownLabelCount);
  if (comparison != 0) return comparison;

  final firstConfidence = first.meanConfidence;
  final secondConfidence = second.meanConfidence;
  if (firstConfidence != null && secondConfidence != null) {
    comparison = firstConfidence.compareTo(secondConfidence);
    if (comparison != 0) return comparison;
  }

  if (first.fromEnhanced == second.fromEnhanced) return 0;
  return first.fromEnhanced ? -1 : 1;
}

OcrDraft mergeOcrCandidates(OcrCandidate primary, OcrCandidate secondary) {
  final components = _mergeComponents(primary, secondary);
  final type = inferBeanType([
    ...primary.lines,
    ...secondary.lines,
  ], components);
  final chips = <String>[];
  for (final chip in [...primary.draft.chips, ...secondary.draft.chips]) {
    if (!chips.contains(chip)) chips.add(chip);
  }

  return OcrDraft(
    name: _preferNonEmpty(primary.draft.name, secondary.draft.name),
    roaster: _preferNonEmpty(primary.draft.roaster, secondary.draft.roaster),
    roastDate: primary.draft.roastDate ?? secondary.draft.roastDate,
    roastLevel: primary.draft.roastLevel ?? secondary.draft.roastLevel,
    components: components,
    cupNotes: primary.draft.cupNotes.isNotEmpty
        ? primary.draft.cupNotes
        : secondary.draft.cupNotes,
    chips: chips,
    typeDecision: type.decision,
    typeReasons: type.reasons,
  );
}

String? _preferNonEmpty(String? primary, String? secondary) =>
    primary == null || primary.trim().isEmpty ? secondary : primary;

List<OcrComponentDraft> _mergeComponents(
  OcrCandidate primary,
  OcrCandidate secondary,
) {
  final useSecondary =
      secondary.countryComponentCount > primary.countryComponentCount;
  final base = useSecondary
      ? secondary.draft.components
      : primary.draft.components;
  final fallback = useSecondary
      ? primary.draft.components
      : secondary.draft.components;
  final usedFallbackIndexes = <int>{};
  final merged = <OcrComponentDraft>[];

  for (final component in base) {
    final country = component.country;
    int? matchIndex;
    if (country != null) {
      for (var i = 0; i < fallback.length; i++) {
        if (!usedFallbackIndexes.contains(i) &&
            fallback[i].country == country) {
          matchIndex = i;
          break;
        }
      }
    }
    if (matchIndex == null) {
      merged.add(component);
      continue;
    }

    usedFallbackIndexes.add(matchIndex);
    final other = fallback[matchIndex];
    merged.add(
      OcrComponentDraft(
        country: _preferNonEmpty(component.country, other.country),
        region: _preferNonEmpty(component.region, other.region),
        process: component.process ?? other.process,
        ratioPercent: component.ratioPercent ?? other.ratioPercent,
      ),
    );
  }
  return merged;
}
