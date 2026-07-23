import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_component_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated rows become two ordered components', () {
    final components = parseOcrComponents(const [
      OcrLine('BLEND', left: 20, top: 10, right: 140, bottom: 40),
      OcrLine('Brazil 60%', left: 20, top: 80, right: 240, bottom: 120),
      OcrLine('Cerrado Natural', left: 20, top: 130, right: 300, bottom: 170),
      OcrLine('Ethiopia 40%', left: 20, top: 220, right: 270, bottom: 260),
      OcrLine('Guji Washed', left: 20, top: 270, right: 260, bottom: 310),
    ]);
    expect(components, hasLength(2));
    expect(components[0].country, 'Brazil');
    expect(components[0].region, 'Cerrado');
    expect(components[0].process, Process.natural);
    expect(components[0].ratioPercent, 60);
    expect(components[1].country, 'Ethiopia');
    expect(components[1].region, 'Guji');
    expect(components[1].process, Process.washed);
    expect(components[1].ratioPercent, 40);
  });

  test('inline country ratios preserve textual order', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil 60% / Ethiopia 40%'),
    ]);
    expect(components.map((c) => c.country), ['Brazil', 'Ethiopia']);
    expect(components.map((c) => c.ratioPercent), [60, 40]);
  });

  test('country in unrelated description does not create second component', () {
    final components = parseOcrComponents(const [
      OcrLine('Ethiopia Guji'),
      OcrLine('Roasted in Colombia by Example Roasters'),
    ]);
    expect(components, hasLength(1));
    expect(components.single.country, 'Ethiopia');
  });

  test('structured country replaces a duplicate country in the title', () {
    final components = parseOcrComponents(const [
      OcrLine('콜롬비아 핑크버번 내추럴', left: 81, top: 121, right: 939, bottom: 194),
      OcrLine('원산지', left: 77, top: 302, right: 155, bottom: 328),
      OcrLine('콜롬비아', left: 345, top: 283, right: 519, bottom: 333),
    ]);
    expect(components, hasLength(1));
    expect(components.single.country, 'Colombia');
  });

  test('known labels are not parsed as component regions', () {
    final components = parseOcrComponents(const [
      OcrLine('BLEND'),
      OcrLine('Brazil 60%'),
      OcrLine('가공'),
      OcrLine('Natural'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Guji Washed'),
    ]);
    expect(components[0].region, isNull);
    expect(components[0].process, Process.natural);
  });

  test('inline unknown English process value maps to other, not region', () {
    final components = parseOcrComponents(const [
      OcrLine('BLEND'),
      OcrLine('Brazil 60%'),
      OcrLine('Process: Experimental'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Guji Washed'),
    ]);
    expect(components[0].process, Process.other);
    expect(components[0].region, isNot('Experimental'));
  });

  test('following unknown Korean process value maps to other, not region', () {
    final components = parseOcrComponents(const [
      OcrLine('블렌드'),
      OcrLine('브라질 60%'),
      OcrLine('가공'),
      OcrLine('무산소 발효'),
      OcrLine('에티오피아 40%'),
      OcrLine('구지 워시드'),
    ]);
    expect(components[0].process, Process.other);
    expect(components[0].region, isNot('무산소 발효'));
  });
}
