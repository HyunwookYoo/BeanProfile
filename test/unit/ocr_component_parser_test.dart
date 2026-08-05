import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_component_parser.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

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

  test(
    'Origin label does not globally admit a later roasting-address country',
    () {
      final components = parseOcrComponents(const [
        OcrLine('Origin: Ethiopia'),
        OcrLine('Roasted in Colombia by Example Roasters'),
      ]);

      expect(components.map((component) => component.country), ['Ethiopia']);
    },
  );

  test(
    'address country before a structured Origin is not the fallback anchor',
    () {
      final components = parseOcrComponents(const [
        OcrLine('Roasted in Colombia by Example Roasters'),
        OcrLine('Origin: Ethiopia'),
      ]);

      expect(components.map((component) => component.country), ['Ethiopia']);
    },
  );

  test('descriptive country before a local Origin label is not admitted', () {
    final components = parseOcrComponents(const [
      OcrLine('Stories from Colombia'),
      OcrLine('Origin'),
      OcrLine('Ethiopia'),
    ]);

    expect(components.map((component) => component.country), ['Ethiopia']);
  });

  test('Origin story prefix is not a local component label', () {
    final components = parseOcrComponents(const [
      OcrLine('Ethiopia'),
      OcrLine('Origin story of Colombia'),
    ]);

    expect(components.map((component) => component.country), ['Ethiopia']);
  });

  test('descriptive same-line countries are not structural components', () {
    final components = parseOcrComponents(const [
      OcrLine('Inspired by Brazil and Colombia'),
    ]);

    expect(components.map((component) => component.country), ['Brazil']);
  });

  test('separator-only and ratio inline groups admit every country', () {
    final separator = parseOcrComponents(const [OcrLine('Brazil / Ethiopia')]);
    final ratios = parseOcrComponents(const [
      OcrLine('Brazil 60% Ethiopia 40%'),
    ]);

    expect(separator.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(ratios.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(ratios.map((component) => component.ratioPercent), [60, 40]);
  });

  const labeledInlineCases = <(String, String, List<int?>)>[
    ('English Origin without ratios', 'Origin: Brazil / Ethiopia', [null, null]),
    (
      'English Origin with ratios',
      'Origin: Brazil 60% / Ethiopia 40%',
      [60, 40],
    ),
    ('English Blend without ratios', 'Blend: Brazil / Ethiopia', [null, null]),
    (
      'English Blend with ratios',
      'Blend: Brazil 60% / Ethiopia 40%',
      [60, 40],
    ),
    ('Korean Origin without ratios', '원산지: 브라질 / 에티오피아', [null, null]),
    (
      'Korean Origin with ratios',
      '원산지: 브라질 60% / 에티오피아 40%',
      [60, 40],
    ),
    ('Korean Blend without ratios', '블렌드: 브라질 / 에티오피아', [null, null]),
    (
      'Korean Blend with ratios',
      '블렌드: 브라질 60% / 에티오피아 40%',
      [60, 40],
    ),
  ];
  for (final (name, text, ratios) in labeledInlineCases) {
    test('bounded local label admits $name', () {
      final components = parseOcrComponents([OcrLine(text)]);
      expect(
        components.map((component) => component.country),
        ['Brazil', 'Ethiopia'],
        reason: text,
      );
      expect(
        components.map((component) => component.ratioPercent),
        ratios,
        reason: text,
      );
    });
  }

  test('bilingual numbered labels admit geometry-less component sections', () {
    final components = parseOcrComponents(const [
      OcrLine('HOUSE BLEND'),
      OcrLine('ORIGIN 01 · 구성 1'),
      OcrLine('BRAZIL'),
      OcrLine('60%'),
      OcrLine('지역'),
      OcrLine('CERRADO'),
      OcrLine('가공'),
      OcrLine('NATURAL'),
      OcrLine('ORIGIN 02 · 구성 2'),
      OcrLine('ETHIOPIA'),
      OcrLine('40%'),
      OcrLine('지역'),
      OcrLine('GUJI'),
      OcrLine('가공'),
      OcrLine('WASHED'),
    ]);

    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
  });

  test('explicit component sections recover fields without value geometry', () {
    final components = parseOcrComponents(const [
      OcrLine('ORIGIN 01 · 구성 1'),
      OcrLine('BRAZIL', left: 100, top: 100, right: 180, bottom: 130),
      OcrLine('60%'),
      OcrLine('지역'),
      OcrLine('CERRADO'),
      OcrLine('가공'),
      OcrLine('NATURAL'),
      OcrLine('ORIGIN 02 · 구성 2'),
      OcrLine('ETHIOPIA', left: 300, top: 100, right: 400, bottom: 130),
      OcrLine('40%'),
      OcrLine('지역'),
      OcrLine('GUJI'),
      OcrLine('가공'),
      OcrLine('WASHED'),
    ]);

    expect(components.map((component) => component.region), [
      'CERRADO',
      'GUJI',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('explicit component columns ignore row-major OCR serialization', () {
    final components = parseOcrComponents(const [
      OcrLine(
        'ORIGIN 01 · 구성 1',
        left: 100,
        top: 100,
        right: 300,
        bottom: 125,
      ),
      OcrLine(
        'ORIGIN 02 · 구성 2',
        left: 600,
        top: 100,
        right: 800,
        bottom: 125,
      ),
      OcrLine('BRAZIL', left: 100, top: 160, right: 260, bottom: 210),
      OcrLine('ETHIOPIA', left: 600, top: 160, right: 800, bottom: 210),
      OcrLine('60%', left: 100, top: 220, right: 180, bottom: 255),
      OcrLine('40%', left: 600, top: 220, right: 680, bottom: 255),
      OcrLine('지역', left: 100, top: 500, right: 160, bottom: 530),
      OcrLine('지역', left: 600, top: 500, right: 660, bottom: 530),
      OcrLine('CERRADO', left: 260, top: 500, right: 410, bottom: 530),
      OcrLine('GUJI', left: 760, top: 500, right: 840, bottom: 530),
      OcrLine('가공', left: 100, top: 600, right: 160, bottom: 630),
      OcrLine('가공', left: 600, top: 600, right: 660, bottom: 630),
      OcrLine('NATURAL', left: 260, top: 600, right: 410, bottom: 630),
      OcrLine('WASHED', left: 760, top: 600, right: 900, bottom: 630),
    ]);

    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(components.map((component) => component.region), [
      'CERRADO',
      'GUJI',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('numbered section columns override shifted country bounding boxes', () {
    final components = parseOcrComponents(const [
      OcrLine(
        'ORIGIN 01 · 구성 1',
        left: 100,
        top: 100,
        right: 300,
        bottom: 125,
      ),
      OcrLine(
        'ORIGIN 02 · 구성 2',
        left: 600,
        top: 100,
        right: 800,
        bottom: 125,
      ),
      OcrLine('BRAZIL', left: 100, top: 160, right: 180, bottom: 210),
      OcrLine('ETHIOPIA', left: 400, top: 160, right: 520, bottom: 210),
      OcrLine('60%', left: 100, top: 220, right: 180, bottom: 255),
      OcrLine('40%', left: 600, top: 220, right: 680, bottom: 255),
      OcrLine('지역', left: 100, top: 500, right: 160, bottom: 530),
      OcrLine('지역', left: 600, top: 500, right: 660, bottom: 530),
      OcrLine('CERRADO', left: 300, top: 500, right: 380, bottom: 530),
      OcrLine('GUJI', left: 760, top: 500, right: 840, bottom: 530),
      OcrLine('가공', left: 100, top: 600, right: 160, bottom: 630),
      OcrLine('가공', left: 600, top: 600, right: 660, bottom: 630),
      OcrLine('NATURAL', left: 300, top: 600, right: 380, bottom: 630),
      OcrLine('WASHED', left: 760, top: 600, right: 840, bottom: 630),
    ]);

    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.region), [
      'CERRADO',
      'GUJI',
    ]);
  });

  test('single unmatched ratio fills the only component with no ratio', () {
    final components = parseOcrComponents(const [
      OcrLine('ORIGIN 01 · 구성 1', left: 100, top: 100, right: 300, bottom: 125),
      OcrLine('ORIGIN 02 · 구성 2', left: 600, top: 100, right: 800, bottom: 125),
      OcrLine('BRAZIL', left: 100, top: 160, right: 260, bottom: 210),
      OcrLine('ETHIOPIA', left: 600, top: 160, right: 800, bottom: 210),
      OcrLine('60%', left: 410, top: 220, right: 490, bottom: 255),
      OcrLine('40%', left: 600, top: 220, right: 680, bottom: 255),
      OcrLine('NATURAL', left: 100, top: 300, right: 250, bottom: 330),
      OcrLine('WASHED', left: 410, top: 300, right: 490, bottom: 330),
    ]);

    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('single unmatched process fills the only component with no process', () {
    final components = parseOcrComponents(const [
      OcrLine('ORIGIN 01 · 구성 1', left: 100, top: 100, right: 300, bottom: 125),
      OcrLine('ORIGIN 02 · 구성 2', left: 600, top: 100, right: 800, bottom: 125),
      OcrLine('BRAZIL', left: 100, top: 160, right: 260, bottom: 210),
      OcrLine('ETHIOPIA', left: 600, top: 160, right: 800, bottom: 210),
      OcrLine('60%', left: 410, top: 220, right: 490, bottom: 255),
      OcrLine('40%', left: 600, top: 220, right: 680, bottom: 255),
      OcrLine('NATURAL', left: 100, top: 300, right: 250, bottom: 330),
      OcrLine('WASHED', left: 410, top: 300, right: 490, bottom: 330),
    ]);

    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
  });

  test('single known process replaces the only unresolved other process', () {
    final components = parseOcrComponents(const [
      OcrLine('BLEND'),
      OcrLine('Brazil 60%'),
      OcrLine('Process: Natural'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Process: Experimental'),
      OcrLine('Washed'),
    ]);

    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
  });

  test('first country remains the sole fallback when no evidence exists', () {
    final components = parseOcrComponents(const [
      OcrLine('Ethiopia Guji'),
      OcrLine('Colombia is mentioned in a story'),
    ]);

    expect(components.map((component) => component.country), ['Ethiopia']);
  });

  test('Blend title does not globally admit a descriptive country', () {
    final components = parseOcrComponents(const [
      OcrLine('HOUSE BLEND'),
      OcrLine('Brazil'),
      OcrLine('Inspired by Colombia and our neighborhood'),
    ]);

    expect(components.map((component) => component.country), ['Brazil']);
  });

  test('far footer country is not repeated-anchor evidence', () {
    final components = parseOcrComponents(const [
      OcrLine(
        'Origin',
        left: 100,
        top: 60,
        right: 180,
        bottom: 90,
      ),
      OcrLine(
        'Ethiopia',
        left: 100,
        top: 100,
        right: 220,
        bottom: 130,
      ),
      OcrLine(
        'Colombia',
        left: 100,
        top: 1000,
        right: 210,
        bottom: 1030,
      ),
    ]);

    expect(components.map((component) => component.country), ['Ethiopia']);
  });

  test('far address country before Origin is not repeated-anchor evidence', () {
    final components = parseOcrComponents(const [
      OcrLine(
        'Colombia',
        left: 100,
        top: 20,
        right: 210,
        bottom: 50,
      ),
      OcrLine(
        'Origin',
        left: 100,
        top: 860,
        right: 180,
        bottom: 890,
      ),
      OcrLine(
        'Ethiopia',
        left: 100,
        top: 900,
        right: 220,
        bottom: 930,
      ),
    ]);

    expect(components.map((component) => component.country), ['Ethiopia']);
  });

  test('large country-only title collapses into same-country Origin', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 20, top: 20, right: 260, bottom: 100),
      OcrLine('Origin', left: 20, top: 150, right: 100, bottom: 180),
      OcrLine('Brazil', left: 20, top: 190, right: 140, bottom: 220),
    ]);

    expect(components, hasLength(1));
    expect(components.single.country, 'Brazil');
  });

  test('repeated OCR columns associate fields with their country anchor', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 100, top: 100, right: 180, bottom: 130),
      OcrLine('Ethiopia', left: 300, top: 100, right: 400, bottom: 130),
      OcrLine('Region', left: 20, top: 160, right: 80, bottom: 190),
      OcrLine('Cerrado', left: 100, top: 160, right: 190, bottom: 190),
      OcrLine('Guji', left: 300, top: 160, right: 360, bottom: 190),
      OcrLine('Process', left: 20, top: 220, right: 80, bottom: 250),
      OcrLine('Natural', left: 100, top: 220, right: 190, bottom: 250),
      OcrLine('Washed', left: 300, top: 220, right: 380, bottom: 250),
      OcrLine('Ratio', left: 20, top: 280, right: 70, bottom: 310),
      OcrLine('60%', left: 100, top: 280, right: 150, bottom: 310),
      OcrLine('40%', left: 300, top: 280, right: 350, bottom: 310),
    ]);

    expect(components, hasLength(2));
    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(components.map((component) => component.region), [
      'Cerrado',
      'Guji',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test(
    'unlabeled repeated columns associate region and process by geometry',
    () {
      final components = parseOcrComponents(const [
        OcrLine('Brazil', left: 100, top: 100, right: 180, bottom: 130),
        OcrLine('Ethiopia', left: 300, top: 100, right: 400, bottom: 130),
        OcrLine('Cerrado', left: 100, top: 160, right: 190, bottom: 190),
        OcrLine('Guji', left: 300, top: 160, right: 360, bottom: 190),
        OcrLine('Natural', left: 100, top: 220, right: 190, bottom: 250),
        OcrLine('Washed', left: 300, top: 220, right: 380, bottom: 250),
      ]);

      expect(components.map((component) => component.region), [
        'Cerrado',
        'Guji',
      ]);
      expect(components.map((component) => component.process), [
        Process.natural,
        Process.washed,
      ]);
    },
  );

  test('vertical component rows recover a distant metadata column', () {
    final components = parseOcrComponents(const [
      OcrLine('BRAZIL 60%', left: 600, top: 600, right: 860, bottom: 680),
      OcrLine('ETHIOPIA 40%', left: 600, top: 1500, right: 900, bottom: 1580),
      OcrLine('지역', left: 1400, top: 520, right: 1480, bottom: 560),
      OcrLine('CERRADO', left: 1600, top: 520, right: 1800, bottom: 570),
      OcrLine('NATURAL', left: 1600, top: 720, right: 1800, bottom: 770),
      OcrLine('GUJI', left: 1600, top: 1400, right: 1720, bottom: 1450),
      OcrLine('WASHED', left: 1600, top: 1610, right: 1780, bottom: 1660),
    ]);

    expect(components.map((component) => component.region), [
      'CERRADO',
      'GUJI',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
  });

  test('photographed C card uses standalone ratios as component evidence', () {
    final components = parseOcrComponents(const [
      OcrLine('ORIGIN @1 : 구', left: 870, top: 1604, right: 1217, bottom: 1650),
      OcrLine('성 1', left: 872, top: 1663, right: 972, bottom: 1704),
      OcrLine('성 2', left: 878, top: 2555, right: 980, bottom: 2600),
      OcrLine('ORIGIN e2구', left: 889, top: 2505, right: 1226, bottom: 2547),
      OcrLine('BRAZIL', left: 1361, top: 1544, right: 1696, bottom: 1646),
      OcrLine('60%', left: 1371, top: 1700, right: 1488, bottom: 1767),
      OcrLine('ETHIOPIA', left: 1368, top: 2445, right: 1789, bottom: 2550),
      OcrLine('40%', left: 1367, top: 2600, right: 1488, bottom: 2659),
      OcrLine('지역', left: 2143, top: 1272, right: 2222, bottom: 1311),
      OcrLine('가공', left: 2138, top: 1739, right: 2219, bottom: 1777),
      OcrLine('지역', left: 2132, top: 2193, right: 2210, bottom: 2232),
      OcrLine('가공', left: 2121, top: 2642, right: 2200, bottom: 2682),
      OcrLine('BLEND', left: 2625, top: 535, right: 2816, bottom: 580),
      OcrLine('CERRAD0', left: 2475, top: 1259, right: 2718, bottom: 1307),
      OcrLine('NATURAL', left: 2466, top: 1727, right: 2699, bottom: 1774),
      OcrLine('GUJI', left: 2457, top: 2180, right: 2563, bottom: 2230),
      OcrLine('WASHED', left: 2447, top: 2635, right: 2656, bottom: 2686),
    ]);

    expect(components, hasLength(2));
    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
    expect(components.map((component) => component.region), [
      'CERRAD0',
      'GUJI',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
  });

  test('repeated labeled rows map by layout order over anchor proximity', () {
    final components = parseOcrComponents(const [
      OcrLine('BRAZIL 60%', left: 600, top: 80, right: 900, bottom: 120),
      OcrLine('ETHIOPIA 40%', left: 600, top: 980, right: 960, bottom: 1020),
      OcrLine('지역', left: 1400, top: 180, right: 1480, bottom: 220),
      OcrLine('CERRADO', left: 1600, top: 180, right: 1800, bottom: 220),
      OcrLine('지역', left: 1400, top: 380, right: 1480, bottom: 420),
      OcrLine('GUJI', left: 1600, top: 380, right: 1720, bottom: 420),
      OcrLine('가공', left: 1400, top: 580, right: 1480, bottom: 620),
      OcrLine('NATURAL', left: 1600, top: 580, right: 1800, bottom: 620),
      OcrLine('가공', left: 1400, top: 680, right: 1480, bottom: 720),
      OcrLine('WASHED', left: 1600, top: 680, right: 1780, bottom: 720),
    ]);

    expect(components.map((component) => component.region), [
      'CERRADO',
      'GUJI',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
  });

  test('unlabeled percentages stay in their repeated country columns', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 100, top: 100, right: 180, bottom: 130),
      OcrLine('Ethiopia', left: 300, top: 100, right: 400, bottom: 130),
      OcrLine('60%', left: 100, top: 160, right: 150, bottom: 190),
      OcrLine('40%', left: 300, top: 160, right: 350, bottom: 190),
    ]);

    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('global Notes row values are not consumed as component regions', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 100, top: 100, right: 180, bottom: 130),
      OcrLine('Ethiopia', left: 300, top: 100, right: 400, bottom: 130),
      OcrLine('Notes', left: 20, top: 160, right: 80, bottom: 190),
      OcrLine('Blueberry', left: 100, top: 160, right: 190, bottom: 190),
      OcrLine('Jasmine', left: 300, top: 160, right: 380, bottom: 190),
    ]);

    expect(components.map((component) => component.region), [null, null]);
  });

  test('reversed OCR order preserves geometric field ownership', () {
    final components = parseOcrComponents(const [
      OcrLine('Ethiopia', left: 300, top: 100, right: 400, bottom: 130),
      OcrLine('Brazil', left: 100, top: 100, right: 180, bottom: 130),
      OcrLine('Guji', left: 300, top: 160, right: 360, bottom: 190),
      OcrLine('Cerrado', left: 100, top: 160, right: 190, bottom: 190),
      OcrLine('Washed', left: 300, top: 220, right: 380, bottom: 250),
      OcrLine('Natural', left: 100, top: 220, right: 190, bottom: 250),
      OcrLine('40%', left: 300, top: 280, right: 350, bottom: 310),
      OcrLine('60%', left: 100, top: 280, right: 150, bottom: 310),
    ]);

    expect(components.map((component) => component.country), [
      'Ethiopia',
      'Brazil',
    ]);
    expect(components.map((component) => component.region), [
      'Guji',
      'Cerrado',
    ]);
    expect(components.map((component) => component.process), [
      Process.washed,
      Process.natural,
    ]);
    expect(components.map((component) => component.ratioPercent), [40, 60]);
  });

  test('centered geometry candidate stays unowned in either OCR order', () {
    List<OcrComponentDraft> parse(bool reversed) {
      final anchors = reversed
          ? const [
              OcrLine(
                'Ethiopia',
                left: 300,
                top: 100,
                right: 400,
                bottom: 130,
              ),
              OcrLine(
                'Brazil',
                left: 100,
                top: 100,
                right: 180,
                bottom: 130,
              ),
            ]
          : const [
              OcrLine(
                'Brazil',
                left: 100,
                top: 100,
                right: 180,
                bottom: 130,
              ),
              OcrLine(
                'Ethiopia',
                left: 300,
                top: 100,
                right: 400,
                bottom: 130,
              ),
            ];
      return parseOcrComponents([
        ...anchors,
        const OcrLine(
          'Natural',
          left: 100,
          top: 160,
          right: 190,
          bottom: 190,
        ),
        const OcrLine(
          'Washed',
          left: 300,
          top: 160,
          right: 380,
          bottom: 190,
        ),
        const OcrLine(
          'Shared',
          left: 210,
          top: 220,
          right: 280,
          bottom: 250,
        ),
      ]);
    }

    final forward = parse(false);
    final reversed = parse(true);
    Map<String, String?> regions(List<OcrComponentDraft> components) => {
      for (final component in components)
        component.country!: component.region,
    };

    expect(regions(forward), {'Brazil': null, 'Ethiopia': null});
    expect(regions(reversed), regions(forward));
  });

  test('geometry-less vertical rows retain bounded sequential fallback', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil 60%'),
      OcrLine('Cerrado Natural'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Guji Washed'),
    ]);

    expect(components.map((component) => component.region), [
      'Cerrado',
      'Guji',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('field labels require a full token boundary', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil 60%'),
      OcrLine('Regional Select'),
      OcrLine('Processing Anaerobic'),
      OcrLine('Ethiopia 40%'),
      OcrLine('Guji Washed'),
    ]);

    expect(components.first.region, 'Regional Select');
    expect(components.first.process, Process.anaerobic);
  });

  test('space-delimited Region Process and Ratio labels remain valid', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil'),
      OcrLine('Region Cerrado'),
      OcrLine('Process Natural'),
      OcrLine('Ratio 60%'),
      OcrLine('Ethiopia'),
      OcrLine('Region Guji'),
      OcrLine('Process Washed'),
      OcrLine('Ratio 40%'),
    ]);

    expect(components.map((component) => component.region), [
      'Cerrado',
      'Guji',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('same-row label and value pairs stay with each component row', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 20, top: 100, right: 100, bottom: 130),
      OcrLine('Region', left: 130, top: 100, right: 190, bottom: 130),
      OcrLine('Cerrado', left: 210, top: 100, right: 290, bottom: 130),
      OcrLine('Process', left: 310, top: 100, right: 375, bottom: 130),
      OcrLine('Natural', left: 395, top: 100, right: 475, bottom: 130),
      OcrLine('Ratio', left: 495, top: 100, right: 545, bottom: 130),
      OcrLine('60%', left: 565, top: 100, right: 610, bottom: 130),
      OcrLine('Ethiopia', left: 20, top: 180, right: 115, bottom: 210),
      OcrLine('Region', left: 130, top: 180, right: 190, bottom: 210),
      OcrLine('Guji', left: 210, top: 180, right: 260, bottom: 210),
      OcrLine('Process', left: 310, top: 180, right: 375, bottom: 210),
      OcrLine('Washed', left: 395, top: 180, right: 475, bottom: 210),
      OcrLine('Ratio', left: 495, top: 180, right: 545, bottom: 210),
      OcrLine('40%', left: 565, top: 180, right: 610, bottom: 210),
    ]);

    expect(components.map((component) => component.region), [
      'Cerrado',
      'Guji',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('labeled inline ratios are associated within bounded components', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil'),
      OcrLine('Ratio: 60%'),
      OcrLine('Ethiopia'),
      OcrLine('Ratio: 40%'),
    ]);

    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('bare Ratio labels take the following percentage value', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil'),
      OcrLine('Ratio'),
      OcrLine('60%'),
      OcrLine('Ethiopia'),
      OcrLine('Ratio'),
      OcrLine('40%'),
    ]);

    expect(components.map((component) => component.country), [
      'Brazil',
      'Ethiopia',
    ]);
    expect(components.map((component) => component.ratioPercent), [60, 40]);
  });

  test('same country in separate component rows remains separate', () {
    final components = parseOcrComponents(const [
      OcrLine('Brazil', left: 20, top: 80, right: 110, bottom: 110),
      OcrLine('Cerrado Natural', left: 20, top: 120, right: 220, bottom: 150),
      OcrLine('Brazil', left: 20, top: 220, right: 110, bottom: 250),
      OcrLine('Mogiana Washed', left: 20, top: 260, right: 210, bottom: 290),
    ]);

    expect(components, hasLength(2));
    expect(components.map((component) => component.country), [
      'Brazil',
      'Brazil',
    ]);
    expect(components.map((component) => component.region), [
      'Cerrado',
      'Mogiana',
    ]);
    expect(components.map((component) => component.process), [
      Process.natural,
      Process.washed,
    ]);
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

  group('RED CASCARA 실기기 픽스처 — 줄머리 국가 앵커', () {
    test('국가 뒤에 농장/등급이 붙어도 성분으로 인정한다', () {
      final components = parseOcrComponents(redCascaraLines);

      expect(
        components.map((c) => c.country),
        ['Thailand', 'Ethiopia', 'Colombia'],
      );
      expect(components.map((c) => c.ratioPercent), [null, 40, 20]);
      expect(
        components.map((c) => c.process),
        [Process.natural, Process.natural, Process.natural],
      );
    });

    // `%`가 붙어야 오탐이 성분으로까지 승격돼 눈에 보인다 — 품종 줄에 비율이
    // 없으면 증거 규칙에서 걸러져 이 회귀를 관찰할 수 없다.
    test('Catimor 품종명이 East Timor 성분으로 잡히지 않는다', () {
      final components = parseOcrComponents(const [
        OcrLine('Ethiopia 70%', left: 20, top: 80, right: 240, bottom: 120),
        OcrLine('Catimor 30%', left: 20, top: 160, right: 240, bottom: 200),
      ]);

      expect(components.map((c) => c.country), ['Ethiopia']);
    });

    // 판별 테스트 — 산문 두 줄 아래에 평행한 값 줄을 깔아 앵커만 인정되면 반복
    // 토폴로지가 곧바로 성립하도록 짰다(값 offset +70/+70, 임계 1.5×60=90).
    // 그래서 `_isCountryAnchorText`의 줄머리 제한이 유일한 방어선이다. 값 줄이
    // 없으면 `_hasParallelComponentValues`가 앵커와 무관하게 실패해서 이 가드가
    // 살아 있는지 아닌지를 구별하지 못한다.
    test('줄 중간의 국가 언급만으로는 앵커가 되지 않는다', () {
      final components = parseOcrComponents(const [
        OcrLine('our Ethiopia roast',
            left: 100, top: 100, right: 700, bottom: 160),
        OcrLine('Natural 40%', left: 100, top: 170, right: 700, bottom: 230),
        OcrLine('our Colombia roast',
            left: 100, top: 300, right: 700, bottom: 360),
        OcrLine('Washed 60%', left: 100, top: 370, right: 700, bottom: 430),
      ]);

      expect(components, hasLength(1));
      expect(components.single.country, 'Ethiopia');
    });
  });
}
