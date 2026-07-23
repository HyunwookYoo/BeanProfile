import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_type_inference.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OcrLine line(String text) => OcrLine(text);

  test('explicit Blend is certain without two components', () {
    final result = inferBeanType([line('House Blend')], const []);
    expect(result.decision, OcrTypeDecision.certainBlend);
    expect(result.reasons, contains(OcrTypeReason.explicitBlend));
  });

  test('two structural components are certain blend', () {
    final result = inferBeanType(const [], const [
      OcrComponentDraft(country: 'Brazil'),
      OcrComponentDraft(country: 'Ethiopia'),
    ]);
    expect(result.decision, OcrTypeDecision.certainBlend);
    expect(result.reasons, contains(OcrTypeReason.multipleComponents));
  });

  test('explicit single with one component is certain single', () {
    final result = inferBeanType(
      [line('Single-Origin')],
      const [OcrComponentDraft(country: 'Kenya')],
    );
    expect(result.decision, OcrTypeDecision.certainSingle);
  });

  test('conflicting text or no evidence is ambiguous', () {
    expect(
      inferBeanType([line('Single Origin Blend')], const []).decision,
      OcrTypeDecision.ambiguous,
    );
    expect(
      inferBeanType([line('Ethiopia')], const [
        OcrComponentDraft(country: 'Ethiopia'),
      ]).decision,
      OcrTypeDecision.ambiguous,
    );
    expect(
      inferBeanType([line('Single Estate')], const []).decision,
      OcrTypeDecision.ambiguous,
    );
  });
}
