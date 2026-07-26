# iOS OCR Diagnostics Copy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iPhone에서 현재 사진의 원본·대비 보정 OCR 텍스트와 좌표, 후보 판정, 최종 구성 결과를 한 번에 클립보드로 복사한다.

**Architecture:** 일반 OCR 파이프라인과 진단 서비스가 하나의 후보 선택 함수를 공유한다. 별도 `OcrDiagnosticsService`가 버튼 탭 시에만 원본과 보정본을 강제 분석해 경로가 제거된 일반 텍스트 보고서를 만들고, `BeanFormScreen`은 Provider로 서비스를 호출해 Flutter Clipboard에 복사한다.

**Tech Stack:** Flutter 3.44.6, Dart, Riverpod 3, `google_mlkit_text_recognition`, `image` 4.9.1, `flutter_test`

## Global Constraints

- 일반 사진 OCR은 원본이 충분히 강하면 보정 OCR을 생략하는 현재 동작을 유지한다.
- 진단 수집은 사용자가 `OCR 진단 복사`를 누를 때만 실행한다.
- 진단 결과는 DB, 원두 메모, 로그 파일에 저장하지 않는다.
- 보고서에는 사진 바이트, 로컬 파일 경로, 기기 식별자, 계정 정보를 넣지 않는다.
- 직접 입력과 기존 원두 편집 화면에는 진단 버튼을 표시하지 않는다.
- 진단 형식 버전은 `v1`, 버튼 문구는 `OCR 진단 복사`를 사용한다.
- 새 패키지를 추가하지 않는다. 이미지 메타데이터는 기존 `image` 4.9.1을 사용한다.
- `.claude/`와 `AGENTS.md`는 스테이징하거나 커밋하지 않는다.
- 모든 커밋 직전에 사용자에게 커밋 대상과 메시지를 알린다.

---

## File Map

- Create: `lib/features/beans/ocr/ocr_diagnostics.dart`
  - 진단 보고서 모델, 텍스트 포맷, 진단 서비스 인터페이스와 기본 구현을 담당한다.
- Modify: `lib/features/beans/ocr/ocr_candidate.dart`
  - 일반 파이프라인과 진단 서비스가 공유할 후보 선택·병합 함수를 제공한다.
- Modify: `lib/features/beans/ocr/ocr_pipeline.dart`
  - 기존 인라인 후보 선택을 공유 함수 호출로 교체한다.
- Modify: `lib/providers.dart`
  - `OcrDiagnosticsService` Provider를 연결한다.
- Modify: `lib/features/beans/bean_form_screen.dart`
  - 사진 OCR 폼의 진단 버튼, 진행 상태, Clipboard 복사, 성공·실패 안내를 담당한다.
- Modify: `test/helpers.dart`
  - 위젯 테스트에서 진단 서비스를 override할 수 있게 한다.
- Modify: `test/unit/ocr_candidate_test.dart`
  - 공유 후보 선택 규칙을 고정한다.
- Create: `test/unit/ocr_diagnostics_test.dart`
  - 강제 원본·보정 분석, 메타데이터, 정리, 보고서 형식과 개인정보 제외를 검증한다.
- Modify: `test/unit/ocr_pipeline_test.dart`
  - 공유 후보 선택으로 바꿔도 일반 파이프라인 동작이 유지되는지 검증한다.
- Modify: `test/widget/ocr_form_test.dart`
  - 버튼 노출, 중복 탭 방지, Clipboard 성공, 오류 UX를 검증한다.

---

### Task 1: 후보 선택 규칙 공유

**Files:**
- Modify: `lib/features/beans/ocr/ocr_candidate.dart`
- Modify: `lib/features/beans/ocr/ocr_pipeline.dart`
- Modify: `test/unit/ocr_candidate_test.dart`
- Test: `test/unit/ocr_pipeline_test.dart`

**Interfaces:**
- Produces:
  - `OcrCandidateSelection`
  - `OcrCandidateSelection selectOcrCandidates(OcrCandidate original, OcrCandidate? enhanced)`
- Consumes:
  - 기존 `compareOcrCandidates`
  - 기존 `mergeOcrCandidates`

- [ ] **Step 1: 공유 선택 함수의 실패 테스트 작성**

`test/unit/ocr_candidate_test.dart`에 다음 테스트를 추가한다.

```dart
test('selection chooses the stronger candidate and merges the other', () {
  final original = candidate(
    draft: const OcrDraft(
      name: 'House Blend',
      components: [
        OcrComponentDraft(country: 'Brazil', ratioPercent: 60),
        OcrComponentDraft(country: 'Ethiopia', ratioPercent: 40),
      ],
    ),
    fromEnhanced: false,
  );
  final enhanced = candidate(
    draft: const OcrDraft(
      name: 'House Blend',
      components: [
        OcrComponentDraft(country: 'Brazil', process: Process.natural),
        OcrComponentDraft(
          country: 'Ethiopia',
          region: 'Guji',
          process: Process.washed,
        ),
      ],
    ),
  );

  final result = selectOcrCandidates(original, enhanced);

  expect(result.selected, same(enhanced));
  expect(result.other, same(original));
  expect(result.usedEnhanced, isTrue);
  expect(result.draft.components[0].ratioPercent, 60);
  expect(result.draft.components[1].ratioPercent, 40);
  expect(result.draft.components[1].region, 'Guji');
});

test('selection keeps original when enhanced is unavailable', () {
  final original = candidate(
    draft: const OcrDraft(name: 'Original'),
    fromEnhanced: false,
  );

  final result = selectOcrCandidates(original, null);

  expect(result.selected, same(original));
  expect(result.other, isNull);
  expect(result.draft, same(original.draft));
  expect(result.usedEnhanced, isFalse);
});
```

- [ ] **Step 2: 테스트가 정의되지 않은 API로 실패하는지 확인**

Run:

```powershell
flutter test test/unit/ocr_candidate_test.dart --plain-name "selection chooses the stronger candidate and merges the other"
```

Expected: `selectOcrCandidates` 또는 `OcrCandidateSelection`이 정의되지 않아 FAIL.

- [ ] **Step 3: 최소 공유 선택 타입과 함수 구현**

`lib/features/beans/ocr/ocr_candidate.dart`에 추가한다.

```dart
class OcrCandidateSelection {
  final OcrCandidate selected;
  final OcrCandidate? other;
  final OcrDraft draft;

  const OcrCandidateSelection({
    required this.selected,
    required this.other,
    required this.draft,
  });

  bool get usedEnhanced => selected.fromEnhanced;
}

OcrCandidateSelection selectOcrCandidates(
  OcrCandidate original,
  OcrCandidate? enhanced,
) {
  final selected = enhanced == null ||
          compareOcrCandidates(original, enhanced) >= 0
      ? original
      : enhanced;
  final other = enhanced == null
      ? null
      : identical(selected, original)
          ? enhanced
          : original;
  return OcrCandidateSelection(
    selected: selected,
    other: other,
    draft: other == null
        ? selected.draft
        : mergeOcrCandidates(selected, other),
  );
}
```

- [ ] **Step 4: 일반 파이프라인을 공유 함수로 교체**

`lib/features/beans/ocr/ocr_pipeline.dart`의 보정 후보 선택 블록을 다음 형태로 바꾼다.

```dart
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
```

- [ ] **Step 5: 후보와 파이프라인 단위 테스트 실행**

Run:

```powershell
flutter test test/unit/ocr_candidate_test.dart test/unit/ocr_pipeline_test.dart
```

Expected: 두 파일의 모든 테스트 PASS.

- [ ] **Step 6: 커밋 전 사용자에게 알리고 Task 1 커밋**

Stage only:

```powershell
git -c safe.directory=C:/BeanProfile add -- `
  lib/features/beans/ocr/ocr_candidate.dart `
  lib/features/beans/ocr/ocr_pipeline.dart `
  test/unit/ocr_candidate_test.dart
git -c safe.directory=C:/BeanProfile diff --cached --check
git -c safe.directory=C:/BeanProfile commit -m "refactor(ocr): share candidate selection"
```

Expected: 공유 후보 선택 변경만 커밋되고 `AGENTS.md`는 untracked 상태 유지.

---

### Task 2: 강제 원본·보정 진단 보고서

**Files:**
- Create: `lib/features/beans/ocr/ocr_diagnostics.dart`
- Create: `test/unit/ocr_diagnostics_test.dart`

**Interfaces:**
- Consumes:
  - `OcrCandidateSelection selectOcrCandidates(OcrCandidate original, OcrCandidate? enhanced)`
  - `OcrService`
  - `ImageQualityAnalyzer`
  - `OcrImagePreprocessor`
- Produces:
  - `abstract interface class OcrDiagnosticsService`
  - `Future<String> OcrDiagnosticsService.collect(String imagePath)`
  - `DefaultOcrDiagnosticsService`

- [ ] **Step 1: 서비스 동작 실패 테스트 작성**

`test/unit/ocr_diagnostics_test.dart`를 다음 import로 만들고 기록 가능한 가짜 서비스를 정의한다.

```dart
import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_diagnostics.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
```

```dart
class RecordingOcrService implements OcrService {
  RecordingOcrService(this.results, {this.throwOnCall});

  final List<List<OcrLine>> results;
  final int? throwOnCall;
  final paths = <String>[];
  var index = 0;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    paths.add(imagePath);
    if (paths.length == throwOnCall) throw StateError('OCR failed');
    return results[index++];
  }
}

class RecordingPreprocessor implements OcrImagePreprocessor {
  final enhancedPath = '/tmp/enhanced.png';
  final deleted = <String>[];

  @override
  Future<String> enhance(String imagePath) async => enhancedPath;

  @override
  Future<void> delete(String imagePath) async => deleted.add(imagePath);
}

class FakeQualityAnalyzer implements ImageQualityAnalyzer {
  FakeQualityAnalyzer(this.report);

  final ImageQualityReport report;

  @override
  Future<ImageQualityReport> analyze(String imagePath) async => report;
}

class ThrowingQualityAnalyzer implements ImageQualityAnalyzer {
  @override
  Future<ImageQualityReport> analyze(String imagePath) async {
    throw StateError('quality failed');
  }
}

class ThrowingPreprocessor implements OcrImagePreprocessor {
  @override
  Future<String> enhance(String imagePath) async {
    throw StateError('enhance failed');
  }

  @override
  Future<void> delete(String imagePath) async {}
}

class ThrowingDeletePreprocessor extends RecordingPreprocessor {
  @override
  Future<void> delete(String imagePath) async {
    throw StateError('delete failed');
  }
}
```

원본이 강한 후보여도 보정본을 강제 실행하는 테스트를 추가한다.

```dart
test('collect always analyzes original and enhanced images', () async {
  final ocr = RecordingOcrService([
    const [
      OcrLine('Name: House Blend', left: 1, top: 2, right: 3, bottom: 4),
      OcrLine('Brazil 60%'),
      OcrLine('Ethiopia 40%'),
    ],
    const [
      OcrLine('Brazil 60%'),
      OcrLine('Natural'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Guji'),
      OcrLine('Washed'),
    ],
  ]);
  final preprocessor = RecordingPreprocessor();
  final service = DefaultOcrDiagnosticsService(
    ocr: ocr,
    qualityAnalyzer: FakeQualityAnalyzer(
      const ImageQualityReport({ImageQualityIssue.lowContrast}),
    ),
    preprocessor: preprocessor,
    platform: 'ios',
  );

  final text = await service.collect('/tmp/source.jpg');

  expect(ocr.paths, ['/tmp/source.jpg', '/tmp/enhanced.png']);
  expect(preprocessor.deleted, ['/tmp/enhanced.png']);
  expect(text, contains('--- ORIGINAL ---'));
  expect(text, contains('--- ENHANCED ---'));
  expect(text, contains('--- FINAL ---'));
  expect(text, isNot(contains('/tmp/source.jpg')));
  expect(text, isNot(contains('/tmp/enhanced.png')));
});
```

- [ ] **Step 2: 보고서 형식과 오류 경로 실패 테스트 작성**

다음 검증을 같은 파일에 추가한다.

```dart
test('report includes safe metadata, coordinates, confidence and components',
    () async {
  final temp = await Directory.systemTemp.createTemp('beanprofile-diagnostic-');
  addTearDown(() => temp.delete(recursive: true));
  final source = File('${temp.path}/source.jpg');
  final image = img.Image(width: 32, height: 48);
  image.exif.imageIfd.orientation = 6;
  await source.writeAsBytes(img.encodeJpg(image));

  final service = DefaultOcrDiagnosticsService(
    ocr: RecordingOcrService([
      const [
        OcrLine(
          'Brazil 100%',
          left: 1,
          top: 2,
          right: 3,
          bottom: 4,
          confidence: .875,
        ),
      ],
      const [OcrLine('Brazil 100%')],
    ]),
    qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
    preprocessor: RecordingPreprocessor(),
    platform: 'ios',
  );

  final text = await service.collect(source.path);

  expect(text, startsWith('=== BEANPROFILE OCR DIAGNOSTICS v1 ==='));
  expect(text, contains('platform: ios'));
  expect(text, contains('image: 32x48'));
  expect(text, contains('exifOrientation=6'));
  expect(text, contains('[1.0,2.0,3.0,4.0]'));
  expect(text, contains('confidence='));
  expect(text, contains('component[0]:'));
  expect(text, isNot(contains(source.path)));
});

test('enhancement failure still returns the original diagnostic', () async {
  final service = DefaultOcrDiagnosticsService(
    ocr: RecordingOcrService([const [OcrLine('Brazil 100%')]]),
    qualityAnalyzer: FakeQualityAnalyzer(const ImageQualityReport()),
    preprocessor: ThrowingPreprocessor(),
    platform: 'ios',
  );

  final text = await service.collect('/tmp/source.jpg');

  expect(text, contains('--- ORIGINAL ---'));
  expect(text, contains('enhancementError:'));
  expect(text, contains('selected: original'));
  expect(text, isNot(contains('/tmp/source.jpg')));
});

test('quality and cleanup failures are recorded without losing the result',
    () async {
  final service = DefaultOcrDiagnosticsService(
    ocr: RecordingOcrService([
      const [OcrLine('Brazil 100%')],
      const [OcrLine('Brazil 100%')],
    ]),
    qualityAnalyzer: ThrowingQualityAnalyzer(),
    preprocessor: ThrowingDeletePreprocessor(),
    platform: 'ios',
  );

  final text = await service.collect('/tmp/source.jpg');

  expect(text, contains('qualityError: StateError'));
  expect(text, contains('cleanupError: StateError'));
  expect(text, contains('selected: original'));
  expect(text, isNot(contains('/tmp/source.jpg')));
  expect(text, isNot(contains('/tmp/enhanced.png')));
});
```

오류 문자열은 `runtimeType`만 기록해 예외 메시지에 섞일 수 있는 경로를 차단한다.

- [ ] **Step 3: 새 테스트가 구현 부재로 실패하는지 확인**

Run:

```powershell
flutter test test/unit/ocr_diagnostics_test.dart
```

Expected: `OcrDiagnosticsService`와 `DefaultOcrDiagnosticsService`가 없어 FAIL.

- [ ] **Step 4: 진단 모델과 고정 텍스트 포맷 구현**

`lib/features/beans/ocr/ocr_diagnostics.dart`는 다음 import로 시작한다.

```dart
import 'dart:isolate';

import 'package:image/image.dart' as img;

import '../../../services/image_quality_analyzer.dart';
import '../../../services/ocr_image_preprocessor.dart';
import '../../../services/ocr_service.dart';
import 'ocr_candidate.dart';
import 'ocr_draft.dart';
```

이 파일에 다음 공개 경계를 만든다.

```dart
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
      ..writeln('selected: ${selection.usedEnhanced ? 'enhanced' : 'original'}');
    _writeDraft(output, selection.draft);
    return output.toString().trimRight();
  }
}
```

같은 파일에 후보·라인·draft 포맷 함수를 구현한다.

```dart
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
    ..writeln(
      'draft.cupNotes: ${draft.cupNotes.map(_oneLine).join(' | ')}',
    )
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

String _nullableText(String? value) =>
    value == null ? 'null' : _oneLine(value);
```

각 후보에는 `requiredCount`, `countryComponentCount`, `filledFieldCount`, `knownLabelCount`, `meanConfidence`, `isWeakOcr`가 출력된다. 각 draft에는 이름, 로스터리, 날짜, 로스팅 단계, 유형 판정·이유, 컵노트, 칩, 모든 component가 출력된다.

- [ ] **Step 5: 강제 분석과 안전한 정리를 구현**

`DefaultOcrDiagnosticsService.collect`은 다음 순서를 사용한다.

```dart
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
```

메타데이터는 UI isolate를 막지 않게 `Isolate.run`에서 읽는다.

```dart
Future<OcrImageMetadata?> _readImageMetadata(String imagePath) =>
    Isolate.run(() async {
      final decoded = await img.decodeImageFile(imagePath);
      if (decoded == null) return null;
      return OcrImageMetadata(
        width: decoded.width,
        height: decoded.height,
        exifOrientation: decoded.exif.imageIfd.orientation,
      );
    });
```

- [ ] **Step 6: 진단 단위 테스트와 기존 OCR 테스트 실행**

Run:

```powershell
flutter test `
  test/unit/ocr_diagnostics_test.dart `
  test/unit/ocr_candidate_test.dart `
  test/unit/ocr_pipeline_test.dart
```

Expected: 모든 테스트 PASS. 보고서 문자열 어디에도 테스트 원본·보정 경로가 없어야 한다.

- [ ] **Step 7: 커밋 전 사용자에게 알리고 Task 2 커밋**

Stage only:

```powershell
git -c safe.directory=C:/BeanProfile add -- `
  lib/features/beans/ocr/ocr_diagnostics.dart `
  test/unit/ocr_diagnostics_test.dart
git -c safe.directory=C:/BeanProfile diff --cached --check
git -c safe.directory=C:/BeanProfile commit -m "feat(ocr): collect clipboard diagnostics"
```

Expected: 진단 서비스와 단위 테스트만 커밋.

---

### Task 3: Provider와 폼의 진단 복사 UX

**Files:**
- Modify: `lib/providers.dart`
- Modify: `lib/features/beans/bean_form_screen.dart`
- Modify: `test/helpers.dart`
- Modify: `test/widget/ocr_form_test.dart`

**Interfaces:**
- Consumes:
  - `OcrDiagnosticsService.collect(String imagePath) -> Future<String>`
- Produces:
  - `ocrDiagnosticsServiceProvider`
  - `Key('copy-ocr-diagnostics')`

- [ ] **Step 1: 버튼 노출과 Clipboard 성공 실패 테스트 작성**

`test/helpers.dart`의 `wrapApp`에 선택적 진단 서비스 override를 추가한다.

```dart
Widget wrapApp(
  Widget child, {
  AppDatabase? db,
  OcrService? ocr,
  OcrPipeline? pipeline,
  OcrDiagnosticsService? diagnostics,
  PhotoService? photo,
  BackupService? backup,
}) =>
    ProviderScope(
      overrides: [
        if (diagnostics != null)
          ocrDiagnosticsServiceProvider.overrideWithValue(diagnostics),
        if (db != null) databaseProvider.overrideWithValue(db),
        if (ocr != null) ocrServiceProvider.overrideWithValue(ocr),
        if (pipeline != null) ocrPipelineProvider.overrideWithValue(pipeline),
        if (photo != null) photoServiceProvider.overrideWithValue(photo),
        if (backup != null) backupServiceProvider.overrideWithValue(backup),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
```

테스트용 서비스를 `test/widget/ocr_form_test.dart` 하단에 정의한다.

```dart
class FakeDiagnosticsService implements OcrDiagnosticsService {
  FakeDiagnosticsService({this.result = 'diagnostic text', this.error});

  final String result;
  final Object? error;
  final paths = <String>[];
  Completer<String>? pending;

  @override
  Future<String> collect(String imagePath) {
    paths.add(imagePath);
    if (error != null) return Future.error(error!);
    return pending?.future ?? Future.value(result);
  }
}
```

다음 위젯 테스트를 추가한다.

```dart
testWidgets('diagnostic button only appears for a photo OCR form', (tester) async {
  await tester.pumpWidget(wrapApp(
    const BeanFormScreen(
      draft: OcrDraft(chips: ['Brazil']),
      photoTempPath: '/tmp/pick.jpg',
    ),
    db: db,
    diagnostics: FakeDiagnosticsService(),
  ));
  expect(find.byKey(const Key('copy-ocr-diagnostics')), findsOneWidget);

  await tester.pumpWidget(wrapApp(const BeanFormScreen(), db: db));
  expect(find.byKey(const Key('copy-ocr-diagnostics')), findsNothing);
});
```

Clipboard 테스트는 `SystemChannels.platform`을 가로챈다.

```dart
String? copied;
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(SystemChannels.platform, (call) async {
  if (call.method == 'Clipboard.setData') {
    copied = (call.arguments as Map)['text'] as String?;
  }
  return null;
});
addTearDown(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
});

await tester.tap(find.byKey(const Key('copy-ocr-diagnostics')));
await tester.pumpAndSettle();

expect(fake.paths, ['/tmp/pick.jpg']);
expect(copied, 'diagnostic text');
expect(find.text('OCR 진단 정보가 복사됐어요'), findsOneWidget);
```

Completer를 사용해 실행 중 버튼 `onPressed == null`과 중복 호출 1회를 검증한다. 오류 fake를 사용해 `OCR 진단 정보를 만들지 못했어요` 안내와 버튼 재활성화를 검증한다.

Clipboard 자체 실패도 별도로 고정한다.

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(SystemChannels.platform, (call) async {
  if (call.method == 'Clipboard.setData') {
    throw PlatformException(code: 'clipboard-failed');
  }
  return null;
});

await tester.tap(find.byKey(const Key('copy-ocr-diagnostics')));
await tester.pumpAndSettle();

expect(find.text('OCR 진단 정보를 만들지 못했어요'), findsOneWidget);
expect(
  tester
      .widget<OutlinedButton>(
        find.byKey(const Key('copy-ocr-diagnostics')),
      )
      .onPressed,
  isNotNull,
);
```

- [ ] **Step 2: 새 위젯 테스트가 버튼 부재로 실패하는지 확인**

Run:

```powershell
flutter test test/widget/ocr_form_test.dart --plain-name "diagnostic button only appears for a photo OCR form"
```

Expected: `copy-ocr-diagnostics` 버튼을 찾지 못해 FAIL.

- [ ] **Step 3: 진단 Provider 연결**

`lib/providers.dart`에 추가한다.

```dart
import 'dart:io';
import 'features/beans/ocr/ocr_diagnostics.dart';

final ocrDiagnosticsServiceProvider = Provider<OcrDiagnosticsService>(
  (ref) => DefaultOcrDiagnosticsService(
    ocr: ref.watch(ocrServiceProvider),
    qualityAnalyzer: ref.watch(imageQualityAnalyzerProvider),
    preprocessor: ref.watch(ocrImagePreprocessorProvider),
    platform: Platform.operatingSystem,
  ),
);
```

Provider는 기존 OCR·품질·보정 Provider를 재사용하고 새 네이티브 객체나 패키지를 만들지 않는다.

- [ ] **Step 4: 폼의 버튼과 비동기 Clipboard 흐름 구현**

`lib/features/beans/bean_form_screen.dart`에 `package:flutter/services.dart`를 import하고 상태를 추가한다.

```dart
bool _copyingDiagnostics = false;

Future<void> _copyOcrDiagnostics() async {
  final path = widget.photoTempPath;
  if (path == null || _copyingDiagnostics) return;
  setState(() => _copyingDiagnostics = true);
  try {
    final text = await ref.read(ocrDiagnosticsServiceProvider).collect(path);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR 진단 정보가 복사됐어요')),
    );
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR 진단 정보를 만들지 못했어요')),
    );
  } finally {
    if (mounted) setState(() => _copyingDiagnostics = false);
  }
}
```

기존 OCR 안내·칩 패널 아래에 버튼을 추가한다. `_auto`는 신규 OCR 폼만 참이므로 기존 편집 화면을 자동으로 제외한다.

```dart
if (_auto && widget.photoTempPath != null) ...[
  const SizedBox(height: 10),
  OutlinedButton.icon(
    key: const Key('copy-ocr-diagnostics'),
    onPressed: _copyingDiagnostics ? null : _copyOcrDiagnostics,
    icon: _copyingDiagnostics
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.content_copy_outlined),
    label: Text(_copyingDiagnostics ? '진단 정보 생성 중…' : 'OCR 진단 복사'),
  ),
],
```

- [ ] **Step 5: 위젯 테스트와 관련 OCR 테스트 실행**

Run:

```powershell
flutter test `
  test/widget/ocr_form_test.dart `
  test/widget/add_bean_sheet_ocr_test.dart `
  test/unit/ocr_diagnostics_test.dart
```

Expected: 버튼 노출·중복 방지·Clipboard·오류 테스트와 기존 사진 OCR 진입 테스트 모두 PASS.

- [ ] **Step 6: 커밋 전 사용자에게 알리고 Task 3 커밋**

Stage only:

```powershell
git -c safe.directory=C:/BeanProfile add -- `
  lib/providers.dart `
  lib/features/beans/bean_form_screen.dart `
  test/helpers.dart `
  test/widget/ocr_form_test.dart
git -c safe.directory=C:/BeanProfile diff --cached --check
git -c safe.directory=C:/BeanProfile commit -m "feat(ocr): copy iOS diagnostics from form"
```

Expected: UI·Provider·위젯 테스트만 커밋.

---

### Task 4: 전체 검증과 v0.6.10 배포

**Files:**
- Verify only; 기능 파일 추가 변경 없음

**Interfaces:**
- Consumes:
  - `OcrDiagnosticsService`
  - `ocrDiagnosticsServiceProvider`
  - `Key('copy-ocr-diagnostics')`
- Produces:
  - 원격 `main`
  - 태그 `v0.6.10`

- [ ] **Step 1: 정적 분석과 전체 테스트**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analyze `No issues found`, 전체 테스트 PASS.

- [ ] **Step 2: Android 에뮬레이터 OCR 통합 비회귀**

연결 상태를 확인한 후 기존 통합 프로브를 실행한다.

```powershell
flutter devices
flutter test integration_test/ocr_probe_test.dart -d emulator-5554
```

Expected: 기존 싱글·블렌드·저대비·품질 경고 통합 테스트 모두 PASS.

- [ ] **Step 3: 최종 변경 범위 확인**

Run:

```powershell
git -c safe.directory=C:/BeanProfile diff --check
git -c safe.directory=C:/BeanProfile status --short --branch
git -c safe.directory=C:/BeanProfile log -4 --oneline --decorate
```

Expected: `AGENTS.md` 외 기능 관련 미커밋 파일이 없고 `main`이 `origin/main`보다 구현 커밋만큼 ahead.

- [ ] **Step 4: 사용자에게 푸시와 태그 생성을 알린 뒤 원격 충돌 확인**

Run:

```powershell
git -c safe.directory=C:/BeanProfile ls-remote --tags origin refs/tags/v0.6.10
```

Expected: 출력 없음.

- [ ] **Step 5: v0.6.10 태그와 main을 원자적으로 푸시**

Run:

```powershell
git -c safe.directory=C:/BeanProfile tag -a v0.6.10 -m "v0.6.10"
git -c safe.directory=C:/BeanProfile push --atomic origin main v0.6.10
```

Expected: `main -> main`, `[new tag] v0.6.10 -> v0.6.10`.

- [ ] **Step 6: 원격 커밋과 Actions 확인**

Run:

```powershell
git -c safe.directory=C:/BeanProfile ls-remote origin `
  'refs/heads/main' `
  'refs/tags/v0.6.10' `
  'refs/tags/v0.6.10^{}'
```

Expected: `main`과 역참조된 `v0.6.10^{}`가 같은 구현 커밋 SHA.

GitHub API에서 해당 SHA의 `test`와 `release` workflow가 시작됐는지 확인한다. iPhone 설치 후 C 카드를 촬영하고 `OCR 진단 복사`를 눌러 이 대화에 결과를 붙여넣는 것이 최종 실기기 확인 단계다.
