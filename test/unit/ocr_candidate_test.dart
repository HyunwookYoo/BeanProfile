import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_candidate.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OcrCandidate candidate({
    OcrDraft draft = const OcrDraft(),
    List<OcrLine> lines = const [],
    int knownLabelCount = 0,
    bool fromEnhanced = true,
  }) => OcrCandidate(
    lines: lines,
    draft: draft,
    knownLabelCount: knownLabelCount,
    fromEnhanced: fromEnhanced,
  );

  test('required fields outrank line confidence', () {
    final complete = candidate(
      lines: const [
        OcrLine('Name: A', confidence: .7),
        OcrLine('Brazil', confidence: .7),
      ],
      draft: const OcrDraft(
        name: 'A',
        components: [OcrComponentDraft(country: 'Brazil')],
      ),
      knownLabelCount: 1,
    );
    final confidentButEmpty = candidate(
      lines: const [OcrLine('Decorative', confidence: .99)],
      fromEnhanced: false,
    );

    expect(compareOcrCandidates(complete, confidentButEmpty), greaterThan(0));
  });

  test('candidate ordering follows every lexicographic tie breaker', () {
    final oneCountry = candidate(
      draft: const OcrDraft(
        name: 'A',
        roaster: 'R',
        roastLevel: RoastLevel.medium,
        components: [
          OcrComponentDraft(
            country: 'Brazil',
            region: 'Cerrado',
            process: Process.natural,
            ratioPercent: 100,
          ),
        ],
      ),
    );
    final twoCountries = candidate(
      draft: const OcrDraft(
        name: 'A',
        components: [
          OcrComponentDraft(country: 'Brazil'),
          OcrComponentDraft(country: 'Ethiopia'),
        ],
      ),
    );
    expect(compareOcrCandidates(twoCountries, oneCountry), greaterThan(0));

    final fewerFields = candidate(
      draft: const OcrDraft(
        name: 'A',
        components: [OcrComponentDraft(country: 'Brazil')],
      ),
    );
    final moreFields = candidate(
      draft: const OcrDraft(
        name: 'A',
        roaster: 'R',
        components: [OcrComponentDraft(country: 'Brazil')],
      ),
    );
    expect(compareOcrCandidates(moreFields, fewerFields), greaterThan(0));

    final fewerLabels = candidate(draft: moreFields.draft);
    final moreLabels = candidate(draft: moreFields.draft, knownLabelCount: 1);
    expect(compareOcrCandidates(moreLabels, fewerLabels), greaterThan(0));

    final lowConfidence = candidate(
      draft: moreFields.draft,
      knownLabelCount: 1,
      lines: const [OcrLine('A', confidence: .7)],
    );
    final highConfidence = candidate(
      draft: moreFields.draft,
      knownLabelCount: 1,
      lines: const [OcrLine('A', confidence: .9)],
    );
    expect(compareOcrCandidates(highConfidence, lowConfidence), greaterThan(0));

    final original = candidate(
      draft: moreFields.draft,
      knownLabelCount: 1,
      lines: const [OcrLine('A', confidence: .9)],
      fromEnhanced: false,
    );
    expect(compareOcrCandidates(original, highConfidence), greaterThan(0));
  });

  test('cup notes and type metadata do not count as filled fields', () {
    final original = candidate(draft: const OcrDraft(), fromEnhanced: false);
    final enhanced = candidate(
      draft: const OcrDraft(
        cupNotes: ['Cocoa'],
        typeDecision: OcrTypeDecision.certainBlend,
        typeReasons: {OcrTypeReason.explicitBlend},
      ),
    );

    expect(compareOcrCandidates(original, enhanced), greaterThan(0));
  });

  test('confidence comparison is skipped when either mean is null', () {
    final original = candidate(
      lines: const [OcrLine('A')],
      fromEnhanced: false,
    );
    final enhanced = candidate(lines: const [OcrLine('A', confidence: .99)]);

    expect(original.meanConfidence, isNull);
    expect(compareOcrCandidates(original, enhanced), greaterThan(0));
  });

  test('merge fills blanks and cup notes but never overwrites conflicts', () {
    final merged = mergeOcrCandidates(
      candidate(
        draft: const OcrDraft(name: '', roastLevel: RoastLevel.light),
        fromEnhanced: false,
      ),
      candidate(
        draft: OcrDraft(
          name: 'Secondary',
          roaster: 'Roaster',
          roastDate: DateTime(2026, 7, 24),
          roastLevel: RoastLevel.dark,
          cupNotes: const ['Cocoa'],
        ),
      ),
    );

    expect(merged.name, 'Secondary');
    expect(merged.roaster, 'Roaster');
    expect(merged.roastDate, DateTime(2026, 7, 24));
    expect(merged.roastLevel, RoastLevel.light);
    expect(merged.cupNotes, ['Cocoa']);
  });

  test('merge chooses one component list and appends unique chips', () {
    final merged = mergeOcrCandidates(
      candidate(
        draft: const OcrDraft(
          components: [OcrComponentDraft(country: 'Brazil', region: 'Primary')],
          chips: ['Shared', 'Primary'],
        ),
        fromEnhanced: false,
      ),
      candidate(
        draft: const OcrDraft(
          components: [
            OcrComponentDraft(country: 'Brazil', region: 'Secondary'),
            OcrComponentDraft(country: 'Ethiopia'),
          ],
          chips: ['Shared', 'Secondary'],
        ),
      ),
    );

    expect(merged.components, hasLength(2));
    expect(merged.components.first.region, 'Secondary');
    expect(merged.chips, ['Shared', 'Primary', 'Secondary']);
  });

  test('merge fills matching component blanks from the other candidate', () {
    final merged = mergeOcrCandidates(
      candidate(
        draft: const OcrDraft(
          components: [
            OcrComponentDraft(
              country: 'Brazil',
              region: 'Cerrado',
              ratioPercent: 60,
            ),
            OcrComponentDraft(country: 'Ethiopia', ratioPercent: 40),
          ],
          chips: ['BRAZIL', '60%', 'ETHIOPIA', '40%'],
        ),
        fromEnhanced: false,
      ),
      candidate(
        draft: const OcrDraft(
          components: [
            OcrComponentDraft(
              country: 'Brazil',
              region: 'Conflicting region',
              process: Process.natural,
              ratioPercent: 55,
            ),
            OcrComponentDraft(
              country: 'Ethiopia',
              region: 'Guji',
              process: Process.washed,
              ratioPercent: 45,
            ),
          ],
          chips: ['NATURAL', 'GUJI', 'WASHED'],
        ),
      ),
    );

    expect(merged.components, [
      isA<OcrComponentDraft>()
          .having((component) => component.country, 'country', 'Brazil')
          .having((component) => component.region, 'region', 'Cerrado')
          .having((component) => component.process, 'process', Process.natural)
          .having((component) => component.ratioPercent, 'ratio', 60),
      isA<OcrComponentDraft>()
          .having((component) => component.country, 'country', 'Ethiopia')
          .having((component) => component.region, 'region', 'Guji')
          .having((component) => component.process, 'process', Process.washed)
          .having((component) => component.ratioPercent, 'ratio', 40),
    ]);
    expect(merged.chips, [
      'BRAZIL',
      '60%',
      'ETHIOPIA',
      '40%',
      'NATURAL',
      'GUJI',
      'WASHED',
    ]);
  });

  test(
    'merge recomputes type metadata from both candidates and components',
    () {
      final merged = mergeOcrCandidates(
        candidate(
          lines: const [OcrLine('Single Origin')],
          draft: const OcrDraft(
            components: [OcrComponentDraft(country: 'Brazil')],
            typeDecision: OcrTypeDecision.certainSingle,
            typeReasons: {OcrTypeReason.explicitSingle},
          ),
          fromEnhanced: false,
        ),
        candidate(
          draft: const OcrDraft(
            components: [
              OcrComponentDraft(country: 'Brazil'),
              OcrComponentDraft(country: 'Ethiopia'),
            ],
          ),
        ),
      );

      expect(merged.typeDecision, OcrTypeDecision.ambiguous);
      expect(merged.typeReasons, {OcrTypeReason.conflictingSignals});
    },
  );

  test('candidate builder parses lines and counts known labels', () {
    const lines = [
      OcrLine('Name: House Blend'),
      OcrLine('Origin'),
      OcrLine('Brazil'),
      OcrLine('Decorative'),
    ];

    final result = buildOcrCandidate(lines, false);

    expect(result.draft.name, 'House Blend');
    expect(result.knownLabelCount, 2);
    expect(isKnownOcrLabel('Notes: Cocoa'), isTrue);
    expect(isKnownOcrLabel('Origin: Brazil'), isTrue);
    expect(isKnownOcrLabel('Decorative'), isFalse);
  });
}
