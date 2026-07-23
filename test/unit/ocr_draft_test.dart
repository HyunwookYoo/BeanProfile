import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('certain type exposes inferredType', () {
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.certainBlend).inferredType,
      BeanType.blend,
    );
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.certainSingle).inferredType,
      BeanType.singleOrigin,
    );
    expect(
      const OcrDraft(typeDecision: OcrTypeDecision.ambiguous).inferredType,
      isNull,
    );
  });

  test('component list is part of non-empty draft', () {
    const draft = OcrDraft(
      components: [OcrComponentDraft(country: 'Ethiopia')],
    );
    expect(draft.isEmpty, isFalse);
    expect(draft.components.single.process, isNull);
  });
}
