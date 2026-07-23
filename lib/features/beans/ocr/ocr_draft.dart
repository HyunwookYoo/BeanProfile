import '../../../data/enums.dart';

enum OcrTypeDecision { certainSingle, certainBlend, ambiguous }

enum OcrTypeReason {
  explicitSingle,
  explicitBlend,
  multipleComponents,
  conflictingSignals,
  insufficientEvidence,
}

class OcrComponentDraft {
  final String? country;
  final String? region;
  final Process? process;
  final int? ratioPercent;
  const OcrComponentDraft({
    this.country,
    this.region,
    this.process,
    this.ratioPercent,
  });

  bool get isEmpty =>
      country == null && region == null && process == null && ratioPercent == null;
}

/// OCR 원문에서 추측한 필드 초안 + 배정 대기 칩.
class OcrDraft {
  final String? name;
  final String? roaster;
  final DateTime? roastDate;
  final RoastLevel? roastLevel;
  final List<OcrComponentDraft> components;
  final List<String> cupNotes;
  final List<String> chips;
  final OcrTypeDecision typeDecision;
  final Set<OcrTypeReason> typeReasons;
  const OcrDraft({
    this.name,
    this.roaster,
    this.roastDate,
    this.roastLevel,
    this.components = const [],
    this.cupNotes = const [],
    this.chips = const [],
    this.typeDecision = OcrTypeDecision.ambiguous,
    this.typeReasons = const {OcrTypeReason.insufficientEvidence},
  });

  BeanType? get inferredType => switch (typeDecision) {
        OcrTypeDecision.certainSingle => BeanType.singleOrigin,
        OcrTypeDecision.certainBlend => BeanType.blend,
        OcrTypeDecision.ambiguous => null,
      };

  /// 자동 채운 값도, 배정할 칩도 하나도 없음(= OCR 실패/빈 이미지).
  bool get isEmpty =>
      name == null &&
      roaster == null &&
      roastDate == null &&
      roastLevel == null &&
      components.every((c) => c.isEmpty) &&
      cupNotes.isEmpty &&
      chips.isEmpty;
}
