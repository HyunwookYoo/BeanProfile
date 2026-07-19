import '../../../data/enums.dart';

/// OCR 원문에서 추측한 필드 초안 + 배정 대기 칩.
class OcrDraft {
  final String? name;
  final String? roaster;
  final String? country;
  final String? region;
  final DateTime? roastDate;
  final RoastLevel? roastLevel;
  final Process? process;
  final List<String> cupNotes;
  final List<String> chips;
  const OcrDraft({
    this.name,
    this.roaster,
    this.country,
    this.region,
    this.roastDate,
    this.roastLevel,
    this.process,
    this.cupNotes = const [],
    this.chips = const [],
  });

  /// 자동 채운 값도, 배정할 칩도 하나도 없음(= OCR 실패/빈 이미지).
  bool get isEmpty =>
      name == null &&
      roaster == null &&
      country == null &&
      region == null &&
      roastDate == null &&
      roastLevel == null &&
      process == null &&
      cupNotes.isEmpty &&
      chips.isEmpty;
}
