// 번들 테스트 카드 5장(assets/test/)의 기대값 — 이 파일 한 곳에만 둔다.
// debug 프로브(ocr_probe_test.dart)와 release 스모크(release_smoke.dart)가 같은 기대값으로
// 검사해야 "release 빌드에서만 깨짐"을 가려낼 수 있다. release 스모크는 flutter_test 없이
// 돌므로 expect 대신 실패 사유 목록을 돌려준다 — 빈 목록이면 통과.
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/foundation.dart';

List<String> _eq(String field, Object? actual, Object? expected) =>
    actual == expected ? const [] : ['$field: $actual != $expected'];

List<String> _eqList(
  String field,
  List<Object?> actual,
  List<Object?> expected,
) =>
    listEquals(actual, expected) ? const [] : ['$field: $actual != $expected'];

/// 콜론 라벨 카드(ocr_card_ko.png) — 파서가 8개 필드를 모두 채운다.
List<String> koreanCardFailures(List<OcrLine> lines, OcrDraft draft) {
  final components = draft.components;
  final component = components.length == 1 ? components.single : null;
  return [
    if (lines.isEmpty) 'lines: empty',
    if (component == null) 'components: ${components.length} != 1',
    ..._eq('name', draft.name, '예가체프 코체레'),
    ..._eq('roaster', draft.roaster, '아우어사이드'),
    if (component != null) ...[
      ..._eq('country', component.country, 'Ethiopia'),
      ..._eq('region', component.region, '예가체프 코체레'),
      ..._eq('process', component.process, Process.washed),
    ],
    ..._eq('roastLevel', draft.roastLevel, RoastLevel.lightMedium),
    ..._eq('roastDate', draft.roastDate, DateTime(2026, 7, 10)),
    ..._eqList('cupNotes', draft.cupNotes, const ['블루베리', '자스민', '홍차']),
  ];
}

/// 콜론 없는 2열 카드(ocr_card_orig.png) — 지역·컵노트·제품명·로스터리는 좌표 기반으로 채운다.
/// 로스터리는 자간 오독('베이스캠프 로스 터스')을 허용한다.
List<String> originalCardFailures(List<OcrLine> lines, OcrDraft draft) {
  final components = draft.components;
  final component = components.length == 1 ? components.single : null;
  final roaster = draft.roaster;
  return [
    if (lines.isEmpty) 'lines: empty',
    if (component == null) 'components: ${components.length} != 1',
    if (component != null) ...[
      ..._eq('country', component.country, 'Colombia'),
      ..._eq('process', component.process, Process.natural),
      ..._eq('region', component.region, '후일라'),
    ],
    ..._eq('roastLevel', draft.roastLevel, RoastLevel.medium),
    ..._eq('roastDate', draft.roastDate, DateTime(2026, 7, 5)),
    ..._eqList('cupNotes', draft.cupNotes, const ['딸기', '복숭아', '레드와인']),
    ..._eq('name', draft.name, '콜롬비아 핑크버번 내추럴'),
    if (roaster == null || !roaster.contains('베이스캠프'))
      'roaster: $roaster !~ 베이스캠프',
  ];
}

/// 밝은 블렌드 카드(ocr_blend_en.png) — 블렌드 확정, 성분 둘(60/40).
List<String> brightBlendFailures(OcrDraft draft) => [
      ..._eq('typeDecision', draft.typeDecision, OcrTypeDecision.certainBlend),
      ..._eqList(
        'countries',
        draft.components.map((c) => c.country).toList(),
        const ['Brazil', 'Ethiopia'],
      ),
      ..._eqList(
        'ratios',
        draft.components.map((c) => c.ratioPercent).toList(),
        const [60, 40],
      ),
    ];

/// 어두운 블렌드 카드(ocr_dark_blend_en.png) — 보정본 후보가 골라져 필수 데이터를 되찾는다.
List<String> darkBlendFailures(OcrPipelineResult result) {
  final withCountry =
      result.draft.components.where((c) => c.country != null).length;
  return [
    ..._eq('usedEnhanced', result.usedEnhanced, true),
    if (result.draft.name == null) 'name: null',
    ..._eq('componentsWithCountry', withCountry, 2),
  ];
}

/// 흐림·반사 카드(ocr_bad_quality_en.png) — 막지 않는 품질 경고가 뜬다.
List<String> badQualityFailures(OcrPipelineResult result) => [
      ..._eq('quality.hasIssues', result.quality.hasIssues, true),
      ..._eq('shouldWarnQuality', result.shouldWarnQuality, true),
    ];
