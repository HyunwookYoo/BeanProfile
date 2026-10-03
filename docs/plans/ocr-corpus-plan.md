# OCR 카드 코퍼스 & 채점판 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드 11장의 ML Kit 출력을 호스트 픽스처로 고정하고, 사진에서 쓴 정답표와 칸 단위로 대조해 파서 회귀를 자동으로 잡는 채점판을 만든다.

**Architecture:** 테스트 인프라 전용이다. `test/support/`에 순수 채점기(`ocr_score.dart`)와 코퍼스 도구(`ocr_corpus.dart` — 픽스처 모델, 기존 seam 세 개를 가짜로 바꿔 `DefaultOcrPipeline`을 그대로 재생, 베이스라인, 리포트)를 두고, `test/unit/ocr_corpus_test.dart`가 칸 단위 베이스라인과 대조하는 회귀 게이트가 된다. 픽스처 원료는 `flutter drive` 한 번으로 만든다 — 호스트 드라이버가 사진을 루프백 HTTP로 서빙하고, 기기 테스트가 실제 ML Kit 결과를 `reportData`로 돌려준다. `lib/`은 한 줄도 바꾸지 않는다.

**Tech Stack:** Flutter 3.44.6 / Dart, `flutter_test`, `integration_test` + `flutter drive`(기존 `test_driver/screenshot_driver.dart`와 같은 채널), `dart:io` `HttpServer`/`HttpClient`. 새 패키지 없음.

**Spec:** [`ocr-corpus-design.md`](./ocr-corpus-design.md) — 왜 ML 학습도 "20장 보고 규칙 쓰기"도 아닌지(§2), 판정 표와 정답 목록(§4.3), 정답표 규칙 R1–R8(§4.2), 덤프 경로를 adb·assets 대신 HTTP로 고른 이유(§4.6)가 거기 있다.

## Global Constraints

- **`lib/` 무수정.** Task 5의 게이트 변이 확인은 `lib/`을 잠깐 바꿨다가 `git checkout`으로 되돌린다. 브랜치 끝에서 `git diff --stat main -- lib/`이 비어 있어야 한다.
- **`pubspec.yaml` 무수정, 새 의존성 금지.** `package:path`도 쓰지 않는다(직접 의존이 아니라 `depend_on_referenced_packages`에 걸린다).
- **정답표는 사진에서만 온다(설계 §4.2).** 정답표 내용은 이 계획서에 이미 고정돼 있다. 덤프된 OCR 출력이나 채점 결과를 보고 정답표를 고치지 않는다 — 고칠 수 있는 근거는 사용자 검수뿐이다. 이걸 어기면 채점판이 첫날부터 눈이 먼다.
- **기존 377개 테스트 그대로 green, `flutter analyze` 0.** 총계 숫자를 목표로 삼지 않는다(신규 테스트만큼 늘어난다). `prefer_const_*` 린트도 issue로 센다 — 리터럴 선언은 `const`로 쓴다.
- **테스트 실행은 Windows 관례:** `flutter test --concurrency=1 -r expanded <경로>`.
- **`dart format`을 돌리지 않는다.** 기존 포맷 드리프트가 있어 무관한 잡음이 생긴다.
- **주석은 한국어, "무엇"이 아니라 "왜".** 기존 OCR 파일의 밀도·어투를 따른다.
- **브랜치 `ocr-corpus`.** `main`에서 판다.
- **`git add`는 태스크에 적힌 경로만.** `git add -A`·`git add .` 금지. 루트의 `AGENTS.md`·`data/`는 untracked로 두고, 작업 트리의 무관한 미커밋 변경(`docs/store-listing.md`·`docs/store-listing.html`·`scripts/check_store_listing.py`)은 건드리지도 커밋하지도 않는다.
- **`samples/cards/`의 사진은 커밋 금지.** 저장소가 공개다(macOS 러너). `.gitignore`가 막고 있다.
- **덤프는 Android 에뮬레이터 ML Kit이다.** 사용자 앱은 iOS라 줄 나눔·좌표가 다를 수 있다(설계 §5). 결과를 "Android ML Kit 기준 파서 점수"로 기록한다.
- **커밋 메시지 끝에 두 줄을 붙인다:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`과 `Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec`. 각 태스크의 커밋 명령에 이미 들어 있다.
- **문서에 목록 안 들여쓴 코드 펜스를 쓰지 않는다.** `scripts/md2html.py`가 그 모양에서 멈춘다(계획 작성 중 실측 — 메모리 2.9GB까지 늘다 끝나지 않음).

## Review Focus

1. **저장소 루트가 아닌 곳에서 `flutter test`를 돌림** — 코퍼스 폴더를 못 찾으면 0장으로 조용히 통과하지 말고 경로를 알려주며 실패해야 한다. → Task 2 `폴더가 없으면 0장으로 조용히 넘어가지 않고 실패한다`, Task 3 게이트의 `isNotEmpty` 단언.
2. **정답표 열거형·날짜 오타(`washd`, `lightmedium`, `2026-7-13`)** — 영원한 wrong 한 칸으로 숨지 말고 로드 단계에서 실패해야 한다. → Task 1 `정답표 형식 검사` 그룹.
3. **OCR이 한 줄도 못 읽은 카드(`"original": []`)** — 재생·채점이 죽지 않고 정답 칸이 전부 missing이 돼야 한다. → Task 1 `빈 초안`, Task 2 `OCR이 한 줄도 못 읽은 픽스처도 재생된다`.
4. **기기가 호스트에 못 닿음(실기기, 잘못된 주소)** — 무한 대기하지 말고 90초 안에 `OCR_CORPUS_HOST`를 안내하며 실패해야 한다. → Task 4 Step 8(일부러 틀린 포트로 실행).
5. **재덤프가 커밋된 픽스처를 조용히 덮어씀** — 드라이버는 `build/ocr_corpus/`에만 쓴다. → Task 4 Step 7(`git status --short test/fixtures`가 비어 있음).

---

## Task 1: 채점기 — 정답표 모델과 순수 채점 함수

**Files:**
- Create: `test/support/ocr_score.dart`
- Create: `test/unit/ocr_score_test.dart`
- Commit (Step 1, 문서): `docs/plans/ocr-corpus-design.{md,html}`, `docs/plans/ocr-corpus-plan.{md,html}`, `.gitignore`, `samples/README.md`

**Interfaces:**
- Consumes: `OcrDraft`·`OcrComponentDraft`·`OcrTypeDecision`(`lib/features/beans/ocr/ocr_draft.dart`), `RoastLevel`·`Process`(`lib/data/enums.dart`).
- Produces (Task 2·3·5가 쓴다):
  - `enum Verdict { correct, missing, wrong }`
  - `class Cell { final String key; final Verdict verdict; final String? actual; final List<String> expected; const Cell(this.key, this.verdict, this.actual, this.expected); String get encoded; }` — `encoded`는 `'correct'` / `'missing'` / `'wrong: <actual>'`.
  - `String normalize(String text)` — 공백 전부 제거 + 소문자.
  - `void requireKeys(Map<String, Object?> json, Set<String> required, String at, {Set<String> optional = const {}})` — 빠진 키·모르는 키면 `FormatException`.
  - `class Truth { final String id; ... factory Truth.fromJson(Map<String, Object?> json); }`
  - `List<Cell> scoreDraft(Truth truth, OcrDraft draft)`

- [ ] **Step 1: 브랜치를 파고 설계·계획 문서를 먼저 커밋한다**

```bash
git switch -c ocr-corpus
python scripts/md2html.py docs/plans/ocr-corpus-plan.md
git add docs/plans/ocr-corpus-design.md docs/plans/ocr-corpus-design.html docs/plans/ocr-corpus-plan.md docs/plans/ocr-corpus-plan.html .gitignore samples/README.md
git status --short
```

Expected: 스테이징된 6개 외에 `docs/store-listing.*`·`scripts/check_store_listing.py`는 ` M`(미스테이징), `AGENTS.md`·`data/`는 `??`로 남는다. `samples/cards/`는 목록에 없다(무시됨).

```bash
git commit -m "docs(ocr): design and plan the OCR card corpus

Twenty sample cards cannot train a model and hand-written rules per
card are what keep regressing, so the cards become a scored corpus
instead: device OCR frozen as host fixtures, truth tables written from
the photos, and a per-cell baseline that fails on any changed cell.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test/unit/ocr_score_test.dart`:

```dart
// 채점기 자체 테스트. 채점기가 조용히 고장나면 리포트가 그럴듯한 숫자를 내면서
// 아무것도 재지 않는다 — 이 프로젝트가 두 번 만난 실패 모드다(설계 §4.5).
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ocr_score.dart';

Map<String, Object?> comp({
  Object? country,
  Object? region,
  Object? process,
  Object? ratioPercent,
}) =>
    {
      'country': country,
      'region': region,
      'process': process,
      'ratioPercent': ratioPercent,
    };

/// 최소 정답표. 시험하는 칸만 넘긴다.
Truth truth({
  Object? name,
  Object? roaster,
  Object? roastDate,
  Object? roastLevel,
  Object? type = 'single',
  List<String> cupNotes = const [],
  List<Map<String, Object?>> components = const [],
}) =>
    Truth.fromJson({
      'id': 't',
      'name': name,
      'roaster': roaster,
      'roastDate': roastDate,
      'roastLevel': roastLevel,
      'type': type,
      'cupNotes': cupNotes,
      'components': components,
    });

Map<String, Cell> score(Truth truth, OcrDraft draft) =>
    {for (final cell in scoreDraft(truth, draft)) cell.key: cell};

void main() {
  group('판정 다섯 갈래 (설계 §4.3 표)', () {
    test('정답 있음 + 같은 값이면 correct', () {
      final cells = score(
          truth(name: '예가체프 코체레'), const OcrDraft(name: '예가체프 코체레'));
      expect(cells['name']!.verdict, Verdict.correct);
    });

    test('정답 있음 + 비우면 missing', () {
      final cells = score(truth(name: '예가체프 코체레'), const OcrDraft());
      expect(cells['name']!.verdict, Verdict.missing);
    });

    test('정답 있음 + 다른 값이면 wrong이고 그 값을 남긴다', () {
      final cells =
          score(truth(name: 'HWACHAE BLEND'), const OcrDraft(name: 'Alt 한/영'));
      expect(cells['name']!.verdict, Verdict.wrong);
      expect(cells['name']!.encoded, 'wrong: Alt 한/영');
    });

    test('정답 없음 + 비우면 correct', () {
      final cells = score(truth(roaster: null), const OcrDraft());
      expect(cells['roaster']!.verdict, Verdict.correct);
    });

    test('정답 없음 + 채우면 wrong — 지어낸 값', () {
      final cells =
          score(truth(roaster: null), const OcrDraft(roaster: 'KWAMI'));
      expect(cells['roaster']!.verdict, Verdict.wrong);
    });
  });

  group('정답 목록', () {
    test('목록 중 아무 값이나 correct, 목록 밖은 wrong', () {
      final t = truth(name: ['Ethiopia Worka', '에티오피아 웨스트 알시 넨세보 워르카']);
      expect(score(t, const OcrDraft(name: '에티오피아 웨스트 알시 넨세보 워르카'))['name']!
          .verdict, Verdict.correct);
      expect(score(t, const OcrDraft(name: 'Ethiopia Worka'))['name']!.verdict,
          Verdict.correct);
      expect(score(t, const OcrDraft(name: '#요거트 #황도'))['name']!.verdict,
          Verdict.wrong);
    });

    test('목록에 null이 있으면 비워도 correct, 없으면 missing', () {
      final optional =
          truth(components: [comp(country: 'Ethiopia', region: [null, '벤치마지'])]);
      final required =
          truth(components: [comp(country: 'Ethiopia', region: ['벤치마지'])]);
      const empty = OcrDraft(components: [OcrComponentDraft(country: 'Ethiopia')]);
      expect(score(optional, empty)['components[0].region']!.verdict,
          Verdict.correct);
      expect(score(required, empty)['components[0].region']!.verdict,
          Verdict.missing);
    });
  });

  group('정규화', () {
    test('공백과 대소문자 차이는 같은 값으로 본다 — OCR 자간 오독', () {
      expect(
          score(truth(roaster: '베이스캠프 로스터스'),
                  const OcrDraft(roaster: '베이스캠프 로스 터스'))['roaster']!
              .verdict,
          Verdict.correct);
      expect(
          score(truth(roaster: 'UNSPECIALTY'),
                  const OcrDraft(roaster: 'Unspecialty'))['roaster']!
              .verdict,
          Verdict.correct);
    });

    test('부분 일치는 받지 않는다', () {
      expect(
          score(truth(roaster: '베이스캠프 로스터스'),
                  const OcrDraft(roaster: '베이스캠프'))['roaster']!
              .verdict,
          Verdict.wrong);
    });
  });

  group('필드별 변환', () {
    test('유형: ambiguous는 빈칸, 반대 유형은 wrong', () {
      final t = truth(type: 'single');
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.certainSingle))[
                  'type']!
              .verdict,
          Verdict.correct);
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.ambiguous))[
                  'type']!
              .verdict,
          Verdict.missing);
      expect(
          score(t, const OcrDraft(typeDecision: OcrTypeDecision.certainBlend))[
                  'type']!
              .verdict,
          Verdict.wrong);
    });

    test('로스팅 날짜는 날짜만 비교한다', () {
      final t = truth(roastDate: '2026-07-13');
      expect(score(t, OcrDraft(roastDate: DateTime(2026, 7, 13)))['roastDate']!
          .verdict, Verdict.correct);
      expect(
          score(t, OcrDraft(roastDate: DateTime(2026, 7, 13, 9, 30)))[
                  'roastDate']!
              .verdict,
          Verdict.correct);
      expect(score(t, OcrDraft(roastDate: DateTime(2026, 7, 31)))['roastDate']!
          .verdict, Verdict.wrong);
    });

    test('열거형은 이름으로 비교한다', () {
      final t = truth(
        roastLevel: 'lightMedium',
        components: [comp(country: 'Ethiopia', process: 'washed')],
      );
      final cells = score(
        t,
        const OcrDraft(
          roastLevel: RoastLevel.lightMedium,
          components: [
            OcrComponentDraft(country: 'Ethiopia', process: Process.washed),
          ],
        ),
      );
      expect(cells['roastLevel']!.verdict, Verdict.correct);
      expect(cells['components[0].process']!.verdict, Verdict.correct);
    });

    test('비율은 정수로 비교한다', () {
      final t = truth(components: [comp(country: 'Panama', ratioPercent: 10)]);
      expect(
          score(t, const OcrDraft(components: [
            OcrComponentDraft(country: 'Panama', ratioPercent: 10),
          ]))['components[0].ratioPercent']!
              .verdict,
          Verdict.correct);
      expect(
          score(t, const OcrDraft(components: [
            OcrComponentDraft(country: 'Panama', ratioPercent: 109),
          ]))['components[0].ratioPercent']!
              .encoded,
          'wrong: 109');
    });
  });

  group('컵노트 — 노트 하나가 한 칸', () {
    test('순서와 무관하게 맞추고, 빠진 노트는 missing, 지어낸 노트는 wrong', () {
      final cells = score(
        truth(cupNotes: ['자스민', '사과', '귤']),
        const OcrDraft(cupNotes: ['사과', '#자스민', '녹차']),
      );
      expect(cells['cupNotes[사과]']!.verdict, Verdict.correct);
      expect(cells['cupNotes[자스민]']!.verdict, Verdict.missing);
      expect(cells['cupNotes[귤]']!.verdict, Verdict.missing);
      expect(cells['cupNotes[+#자스민]']!.verdict, Verdict.wrong);
      expect(cells['cupNotes[+녹차]']!.verdict, Verdict.wrong);
      expect(cells.keys.where((key) => key.startsWith('cupNotes')), hasLength(5));
    });
  });

  group('성분 — index로 짝짓기', () {
    test('정답보다 적으면 모자란 성분의 칸이 missing', () {
      final t = truth(type: 'blend', components: [
        comp(country: 'Panama', ratioPercent: 10),
        comp(country: 'Ecuador', ratioPercent: 45),
        comp(country: 'Ethiopia', ratioPercent: 45),
      ]);
      final cells = score(
          t, const OcrDraft(components: [OcrComponentDraft(country: 'Panama')]));
      expect(cells['components[0].country']!.verdict, Verdict.correct);
      expect(cells['components[1].country']!.verdict, Verdict.missing);
      expect(cells['components[2].ratioPercent']!.verdict, Verdict.missing);
      // 정답이 null인 칸은 성분이 통째로 없어도 correct다.
      expect(cells['components[1].region']!.verdict, Verdict.correct);
    });

    test('정답보다 많으면 채운 값마다 wrong, 빈 칸은 칸을 만들지 않는다', () {
      final t = truth(components: [comp(country: 'Ethiopia')]);
      final cells = score(
        t,
        const OcrDraft(components: [
          OcrComponentDraft(country: 'Ethiopia'),
          OcrComponentDraft(country: 'Ethiopia', ratioPercent: 100),
        ]),
      );
      expect(cells['components[1].country']!.encoded, 'wrong: Ethiopia');
      expect(cells['components[1].ratioPercent']!.encoded, 'wrong: 100');
      expect(cells.containsKey('components[1].region'), isFalse);
    });

    test('정답보다 많은 성분이 비어 있으면 칸이 하나도 없다', () {
      final t = truth(components: [comp(country: 'Ethiopia')]);
      final cells = score(
        t,
        const OcrDraft(components: [
          OcrComponentDraft(country: 'Ethiopia'),
          OcrComponentDraft(),
        ]),
      );
      expect(cells.keys.where((key) => key.startsWith('components[1]')), isEmpty);
    });
  });

  test('OCR이 한 줄도 못 읽은 빈 초안도 채점된다 — 정답 칸은 missing, wrong은 없다', () {
    final t = truth(
      name: 'Ethiopia Worka',
      cupNotes: ['요거트'],
      components: [comp(country: 'Ethiopia', process: 'natural')],
    );
    final cells = scoreDraft(t, const OcrDraft());
    expect(cells.where((cell) => cell.verdict == Verdict.wrong), isEmpty);
    expect(
      {
        for (final cell in cells)
          if (cell.verdict == Verdict.missing) cell.key,
      },
      {
        'name',
        'type',
        'cupNotes[요거트]',
        'components[0].country',
        'components[0].process',
      },
    );
  });

  group('정답표 형식 검사 — 오타는 영구 wrong으로 숨지 말고 로드에서 실패', () {
    Map<String, Object?> valid() => {
          'id': 't',
          'name': null,
          'roaster': null,
          'roastDate': null,
          'roastLevel': null,
          'type': 'single',
          'cupNotes': <Object?>[],
          'components': <Object?>[],
        };

    test('정상 정답표와 notes는 통과', () {
      expect(() => Truth.fromJson({...valid(), 'notes': '근거'}), returnsNormally);
    });

    test('모르는 키', () {
      expect(() => Truth.fromJson({...valid(), 'roastlevel': 'light'}),
          throwsFormatException);
    });

    test('빠진 키', () {
      expect(() => Truth.fromJson(valid()..remove('type')), throwsFormatException);
    });

    test('열거형 오타', () {
      expect(() => Truth.fromJson({...valid(), 'roastLevel': 'lightmedium'}),
          throwsFormatException);
      expect(() => Truth.fromJson({...valid(), 'type': 'blended'}),
          throwsFormatException);
      expect(
          () => Truth.fromJson({
                ...valid(),
                'components': [comp(country: 'Ethiopia', process: 'washd')],
              }),
          throwsFormatException);
    });

    test('날짜 형식', () {
      expect(() => Truth.fromJson({...valid(), 'roastDate': '2026-7-13'}),
          throwsFormatException);
    });

    test('컵노트 중복(정규화 기준)', () {
      expect(
          () => Truth.fromJson({
                ...valid(),
                'cupNotes': ['자스민', '자 스민'],
              }),
          throwsFormatException);
    });

    test('값 자리에 문자열·정수·null 말고 다른 것', () {
      expect(() => Truth.fromJson({...valid(), 'name': true}),
          throwsFormatException);
    });
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_score_test.dart`
Expected: 컴파일 실패 — `Error: Error when reading 'test/support/ocr_score.dart'` (파일 없음).

- [ ] **Step 4: 채점기를 쓴다**

`test/support/ocr_score.dart`:

```dart
// OCR 코퍼스 채점기 — 정답표 모델과 순수 채점 함수.
// 설계: docs/plans/ocr-corpus-design.md §4.3.
// 파서 코드를 import하지 않는다 — 채점 기준이 파서에 기대면 파서가 바뀔 때
// 기준도 같이 움직여 아무것도 재지 못한다.
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';

/// 칸 하나의 판정.
enum Verdict { correct, missing, wrong }

/// 채점된 칸.
class Cell {
  final String key;
  final Verdict verdict;

  /// 파서가 낸 값(정규화 전). 비었으면 null.
  final String? actual;

  /// 정답으로 받아주는 값들(정규화 전). 리포트의 파서/OCR 구분에 쓴다.
  final List<String> expected;

  const Cell(this.key, this.verdict, this.actual, this.expected);

  /// baseline.json에 적는 값. 틀린 칸은 무엇으로 틀렸는지까지 남긴다 —
  /// 오채움이 다른 오채움으로 바뀌는 것도 변화다(인라인 블렌드 브랜치에서
  /// 상한 하나를 조였더니 지역이 null이 아니라 `Designed for`로 바뀌었다).
  String get encoded => switch (verdict) {
        Verdict.correct => 'correct',
        Verdict.missing => 'missing',
        Verdict.wrong => 'wrong: $actual',
      };
}

/// 공백을 모두 지우고 소문자로. OCR 자간 오독(`베이스캠프 로스 터스`)을 흡수한다.
String normalize(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// JSON 객체의 키가 정확히 맞는지 본다. 정답표·픽스처는 손으로 쓰고 고치므로
/// 오타 난 키가 조용히 null로 읽히면 안 된다.
void requireKeys(
  Map<String, Object?> json,
  Set<String> required,
  String at, {
  Set<String> optional = const {},
}) {
  final keys = json.keys.toSet();
  final missing = required.difference(keys);
  final unknown = keys.difference(required).difference(optional);
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException('$at: 빠진 키 $missing, 모르는 키 $unknown');
  }
}

/// 정답 한 칸. 정답표 JSON의 값 하나에서 만든다.
///
/// - `null` — 카드에 없다. 비우면 correct, 채우면 wrong.
/// - `"값"` — 이 값이면 correct, 비우면 missing, 다른 값이면 wrong.
/// - `["값1", "값2", null]` — 목록 중 하나면 correct. 목록에 null이 있으면
///   비워도 correct(정답표 규칙 R3·R5, 설계 §4.2).
class Accept {
  final List<String> raw;
  final Set<String> _values;
  final bool allowsEmpty;

  Accept._(this.raw, this.allowsEmpty)
      : _values = {for (final value in raw) normalize(value)};

  factory Accept.fromJson(
    Object? json, {
    required String field,
    bool Function(String value)? valid,
  }) {
    final items = switch (json) {
      null => const <Object?>[null],
      List<Object?> list => list,
      _ => <Object?>[json],
    };
    final raw = <String>[];
    var allowsEmpty = false;
    for (final item in items) {
      if (item == null) {
        allowsEmpty = true;
        continue;
      }
      if (item is! String && item is! int) {
        throw FormatException('$field: 문자열·정수·null만 쓸 수 있다 — $item');
      }
      final text = '$item';
      if (valid != null && !valid(text)) {
        throw FormatException('$field: 쓸 수 없는 값 "$text"');
      }
      raw.add(text);
    }
    return Accept._(raw, allowsEmpty);
  }

  Verdict judge(String? actual) {
    if (actual == null) return allowsEmpty ? Verdict.correct : Verdict.missing;
    return _values.contains(normalize(actual)) ? Verdict.correct : Verdict.wrong;
  }
}

/// 성분 하나의 정답.
class ComponentTruth {
  final Accept country;
  final Accept region;
  final Accept process;
  final Accept ratioPercent;

  ComponentTruth._(this.country, this.region, this.process, this.ratioPercent);

  factory ComponentTruth.fromJson(Map<String, Object?> json, String at) {
    requireKeys(json, const {'country', 'region', 'process', 'ratioPercent'}, at);
    return ComponentTruth._(
      Accept.fromJson(json['country'], field: '$at.country'),
      Accept.fromJson(json['region'], field: '$at.region'),
      Accept.fromJson(
        json['process'],
        field: '$at.process',
        valid: {for (final process in Process.values) process.name}.contains,
      ),
      Accept.fromJson(json['ratioPercent'], field: '$at.ratioPercent'),
    );
  }
}

/// 카드 한 장의 정답표(`<id>.truth.json`). 사진에서만 쓴다(설계 §4.2).
class Truth {
  final String id;
  final Accept name;
  final Accept roaster;
  final Accept roastDate;
  final Accept roastLevel;
  final Accept type;
  final List<String> cupNotes;
  final List<ComponentTruth> components;

  Truth._({
    required this.id,
    required this.name,
    required this.roaster,
    required this.roastDate,
    required this.roastLevel,
    required this.type,
    required this.cupNotes,
    required this.components,
  });

  factory Truth.fromJson(Map<String, Object?> json) {
    requireKeys(
      json,
      const {
        'id',
        'name',
        'roaster',
        'roastDate',
        'roastLevel',
        'type',
        'cupNotes',
        'components',
      },
      'truth',
      optional: const {'notes'},
    );
    final cupNotes = [for (final note in json['cupNotes']! as List) note as String];
    final seen = <String>{};
    for (final note in cupNotes) {
      if (!seen.add(normalize(note))) {
        throw FormatException('truth.cupNotes: 중복 "$note"');
      }
    }
    return Truth._(
      id: json['id']! as String,
      name: Accept.fromJson(json['name'], field: 'name'),
      roaster: Accept.fromJson(json['roaster'], field: 'roaster'),
      roastDate: Accept.fromJson(
        json['roastDate'],
        field: 'roastDate',
        valid: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch,
      ),
      roastLevel: Accept.fromJson(
        json['roastLevel'],
        field: 'roastLevel',
        valid: {for (final level in RoastLevel.values) level.name}.contains,
      ),
      type: Accept.fromJson(
        json['type'],
        field: 'type',
        valid: const {'single', 'blend'}.contains,
      ),
      cupNotes: cupNotes,
      components: [
        for (final (i, component) in (json['components']! as List).indexed)
          ComponentTruth.fromJson(
            (component as Map).cast<String, Object?>(),
            'components[$i]',
          ),
      ],
    );
  }
}

/// 초안 하나를 정답표와 맞춰 칸 목록을 낸다.
List<Cell> scoreDraft(Truth truth, OcrDraft draft) {
  final cells = <Cell>[
    _cell('name', truth.name, draft.name),
    _cell('roaster', truth.roaster, draft.roaster),
    _cell('roastDate', truth.roastDate,
        draft.roastDate?.toIso8601String().substring(0, 10)),
    _cell('roastLevel', truth.roastLevel, draft.roastLevel?.name),
    _cell('type', truth.type, switch (draft.typeDecision) {
      // 앱은 ambiguous일 때 사용자에게 유형을 묻는다 — 그게 이 앱의 빈칸이다.
      OcrTypeDecision.certainSingle => 'single',
      OcrTypeDecision.certainBlend => 'blend',
      OcrTypeDecision.ambiguous => null,
    }),
  ];

  // 컵노트는 노트 하나가 한 칸이다. 정답에 없는 실제 노트는 하나마다 wrong.
  final actualNotes = {for (final note in draft.cupNotes) normalize(note): note};
  final truthNotes = {for (final note in truth.cupNotes) normalize(note)};
  for (final note in truth.cupNotes) {
    final hit = actualNotes[normalize(note)];
    cells.add(Cell('cupNotes[$note]',
        hit == null ? Verdict.missing : Verdict.correct, hit, [note]));
  }
  for (final MapEntry(:key, :value) in actualNotes.entries) {
    if (!truthNotes.contains(key)) {
      cells.add(Cell('cupNotes[+$value]', Verdict.wrong, value, const []));
    }
  }

  // 성분은 index로 짝짓는다. 국가로 짝지으면 채점 대상(국가)에 기대는 순환이다.
  for (final (i, expected) in truth.components.indexed) {
    final actual = i < draft.components.length ? draft.components[i] : null;
    cells.addAll([
      _cell('components[$i].country', expected.country, actual?.country),
      _cell('components[$i].region', expected.region, actual?.region),
      _cell('components[$i].process', expected.process, actual?.process?.name),
      _cell('components[$i].ratioPercent', expected.ratioPercent,
          actual?.ratioPercent?.toString()),
    ]);
  }
  // 정답보다 많은 성분은 정답이 없는 칸이다 — 채운 값마다 wrong.
  for (var i = truth.components.length; i < draft.components.length; i++) {
    final extra = draft.components[i];
    for (final (field, value) in [
      ('country', extra.country),
      ('region', extra.region),
      ('process', extra.process?.name),
      ('ratioPercent', extra.ratioPercent?.toString()),
    ]) {
      if (value != null) {
        cells.add(Cell('components[$i].$field', Verdict.wrong, value, const []));
      }
    }
  }
  return cells;
}

Cell _cell(String key, Accept accept, String? actual) =>
    Cell(key, accept.judge(actual), actual, accept.raw);
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_score_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: analyze**

Run: `flutter analyze`
Expected: `No issues found!` — `prefer_const_*` 정보가 나오면 해당 리터럴에 `const`를 붙인다.

- [ ] **Step 7: 커밋**

```bash
git add test/support/ocr_score.dart test/unit/ocr_score_test.dart
git commit -m "test(ocr): add the corpus scorer

Each truth cell is judged correct, missing or wrong, where filling a
field the card does not have is wrong — the shape of the region
defect no existing test measures. Truth values may list alternatives
and null so judgement calls live in reviewed data, not fuzzy code.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```

- [ ] **Step 8: 변이로 판별력을 증명한다**

변이마다 파일을 고치고 `flutter test --concurrency=1 -r expanded test/unit/ocr_score_test.dart`를 돌린 뒤 **`git checkout -- test/support/ocr_score.dart`로 되돌린다.** 빨개진 테스트 이름과 실패 출력 한 줄을 보고서에 적는다. 하나라도 초록이면 그 갈래를 지키는 테스트가 없는 것이다 — 멈추고 보고한다.

| # | 변이 | 빨개져야 하는 테스트 | 초록이어야 하는 테스트 |
|---|---|---|---|
| M1 | `judge`의 `return allowsEmpty ? Verdict.correct : Verdict.missing;` → `return Verdict.correct;` | `정답 있음 + 비우면 missing`, `목록에 null이 있으면…`, `유형: ambiguous는 빈칸…`, `정답보다 적으면…`, `빈 초안…` | `정답 없음 + 비우면 correct`, `정답 없음 + 채우면 wrong` |
| M2 | `judge`의 `? Verdict.correct : Verdict.wrong` → `? Verdict.correct : Verdict.correct` | `다른 값이면 wrong…`, `정답 없음 + 채우면 wrong`, `목록 중 아무 값이나…`, `부분 일치는 받지 않는다`, `로스팅 날짜는…`, `비율은 정수로…` | `정답 있음 + 비우면 missing` |
| M3 | `Accept.fromJson`의 `null => const <Object?>[null],` → `null => const <Object?>[],` | `정답 없음 + 비우면 correct`, `정답보다 적으면…`, `빈 초안…` | `정답 있음 + 비우면 missing` |
| M4 | `normalize`를 `text.toLowerCase()`로 | `공백과 대소문자 차이는…`, `컵노트 중복(정규화 기준)` | `부분 일치는 받지 않는다` |
| M5 | 정답에 없는 실제 노트를 wrong으로 넣는 `for` 루프 삭제 | `순서와 무관하게 맞추고…` | 성분 그룹 전체 |
| M6 | 정답보다 많은 성분의 `for` 루프 삭제 | `정답보다 많으면 채운 값마다 wrong…` | `정답보다 적으면…` |

마지막에 `git status --short test/`가 비어 있는지 확인한다.

---

## Task 2: 코퍼스 도구 — 픽스처 모델, 파이프라인 재생, 베이스라인

**Files:**
- Create: `test/support/ocr_corpus.dart`
- Create: `test/unit/ocr_corpus_support_test.dart`

**Interfaces:**
- Consumes (Task 1): `Truth.fromJson`, `Truth.id`, `requireKeys`.
- Consumes (lib): `DefaultOcrPipeline`(`ocr_pipeline.dart`), `OcrService`·`OcrLine`(`ocr_service.dart`), `ImageQualityAnalyzer`·`ImageQualityReport`·`ImageQualityIssue`(`image_quality_analyzer.dart`), `OcrImagePreprocessor`(`ocr_image_preprocessor.dart`).
- Produces (Task 3·5가 쓴다):
  - `class CorpusFixture { final String id; final String source; final Set<ImageQualityIssue>? quality; final List<OcrLine> original; final List<OcrLine>? enhanced; factory CorpusFixture.fromJson(Map<String, Object?> json); }`
  - `Future<OcrDraft> replayPipeline(CorpusFixture fixture)`
  - `class CorpusCard { final CorpusFixture fixture; final Truth truth; String get id; }`
  - `List<CorpusCard> loadCorpus(Directory dir)` — 짝 없는 파일·폴더 없음은 `StateError`, 형식 오류·id 불일치는 `FormatException`.
  - `typedef Baseline = Map<String, Map<String, String>>;` · `Baseline toBaseline(Map<String, List<Cell>> scored)` · `String encodeBaseline(Baseline baseline)` · `Baseline decodeBaseline(String text)` · `List<String> diffBaseline(Baseline before, Baseline after)` — 줄 형식 `'<card>  <cell>  <before> → <after>'`, 없는 쪽은 `(없음)`.

**왜 이 재생 방식인가:** 채점 대상은 `parseOcr`이 아니라 파이프라인 전체다(설계 결정 3) — 알려진 타이브레이커 결함이 `selectOcrCandidates` 단계에 있다. `DefaultOcrPipeline`을 그대로 쓰고 seam 세 개만 기록된 값으로 바꾸면, 파이프라인이 나중에 바뀌어도 재생이 따라간다. 아래 테스트의 분기 기대값은 계획 단계에서 임시 프로브로 실측했다(2026-10-03): 콜론 라벨 4줄(제품명·원산지·가공·로스팅)은 약하지 않고, 제품명이 빠지면 약하다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/unit/ocr_corpus_support_test.dart`:

```dart
import 'dart:io';

import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ocr_corpus.dart';

// 같은 높이·같은 열의 콜론 라벨 줄 — 타이포그래피 경로를 타지 않고 라벨로만 읽힌다.
Map<String, Object?> _row(String text, int index) => {
      'text': text,
      'l': 10,
      't': index * 40,
      'r': 400,
      'b': index * 40 + 30,
      'conf': null,
    };

CorpusFixture fixture({
  required List<String> original,
  List<String>? enhanced,
  List<String>? quality,
}) =>
    CorpusFixture.fromJson({
      'id': 'f',
      'source': 'test',
      'quality': quality,
      'original': [for (final (i, text) in original.indexed) _row(text, i)],
      'enhanced': enhanced == null
          ? null
          : [for (final (i, text) in enhanced.indexed) _row(text, i)],
    });

// 계획 단계 실측(2026-10-03): strong은 약하지 않고(isWeakOcr false), weak는
// 제품명이 없어 약하다.
const strong = ['제품명: 테스트 원두', '원산지: 에티오피아', '가공: 워시드', '로스팅: 미디엄'];
const strongPlusRoaster = [...strong, '로스터리: 보정 로스터'];
const weak = ['원산지: 에티오피아', '가공: 워시드', '로스팅: 미디엄', '고도: 1,800m'];
const weakPlusName = ['제품명: 보정 원두', ...weak];

void main() {
  group('파이프라인 재생', () {
    test('원본이 약하지 않고 품질 문제도 없으면 보정 패스를 보지 않는다', () async {
      final draft = await replayPipeline(
          fixture(original: strong, enhanced: strongPlusRoaster, quality: []));
      expect(draft.name, '테스트 원두');
      expect(draft.roaster, isNull);
    });

    test('저대비면 원본이 멀쩡해도 보정 패스를 본다', () async {
      final draft = await replayPipeline(fixture(
          original: strong,
          enhanced: strongPlusRoaster,
          quality: ['lowContrast']));
      expect(draft.roaster, '보정 로스터');
    });

    test('원본이 약하면 보정 패스로 메운다', () async {
      final draft = await replayPipeline(
          fixture(original: weak, enhanced: weakPlusName, quality: []));
      expect(draft.name, '보정 원두');
    });

    test('보정 패스 기록이 없으면 기기에서 보정이 실패한 것처럼 원본만 쓴다', () async {
      final draft = await replayPipeline(fixture(original: weak, quality: []));
      expect(draft.name, isNull);
      expect(draft.components.single.country, 'Ethiopia');
    });

    test('품질 기록이 없으면 빈 보고서로 재생한다', () async {
      final draft = await replayPipeline(
          fixture(original: strong, enhanced: strongPlusRoaster));
      expect(draft.roaster, isNull);
    });

    test('OCR이 한 줄도 못 읽은 픽스처도 재생된다', () async {
      final draft = await replayPipeline(
          fixture(original: const [], enhanced: const [], quality: []));
      expect(draft.isEmpty, isTrue);
    });
  });

  group('픽스처 형식', () {
    test('좌표·confidence·품질을 그대로 읽는다', () {
      final f = CorpusFixture.fromJson({
        'id': 'x',
        'source': 's',
        'quality': ['blurry', 'strongHighlights'],
        'original': [
          {'text': 'RED CASCARA', 'l': 1137, 't': 511.5, 'r': 2303, 'b': 610, 'conf': 0.91},
        ],
        'enhanced': null,
      });
      final line = f.original.single;
      expect(
        [line.text, line.left, line.top, line.right, line.bottom, line.confidence],
        ['RED CASCARA', 1137.0, 511.5, 2303.0, 610.0, 0.91],
      );
      expect(f.quality,
          {ImageQualityIssue.blurry, ImageQualityIssue.strongHighlights});
      expect(f.enhanced, isNull);
    });

    test('키가 빠지면 실패한다', () {
      expect(
          () => CorpusFixture.fromJson(
              {'id': 'x', 'source': 's', 'quality': null, 'original': []}),
          throwsFormatException);
    });
  });

  group('코퍼스 폴더 읽기', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ocr_corpus_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String name, String body) =>
        File('${dir.path}/$name').writeAsStringSync(body);
    const ocr =
        '{"id": "a", "source": "s", "quality": [], "original": [], "enhanced": null}';
    const truth = '{"id": "a", "name": null, "roaster": null, "roastDate": null, '
        '"roastLevel": null, "type": "single", "cupNotes": [], "components": []}';

    test('픽스처와 정답표를 id로 짝짓고 다른 파일은 무시한다', () {
      write('a.ocr.json', ocr);
      write('a.truth.json', truth);
      write('baseline.json', '{}');
      write('sources.json', '{}');
      expect(loadCorpus(dir).map((card) => card.id), ['a']);
    });

    test('짝 없는 파일이 있으면 실패한다', () {
      write('a.ocr.json', ocr);
      expect(() => loadCorpus(dir), throwsStateError);
    });

    test('파일 이름과 id가 다르면 실패한다', () {
      write('b.ocr.json', ocr);
      write('b.truth.json', truth.replaceFirst('"a"', '"b"'));
      expect(() => loadCorpus(dir), throwsFormatException);
    });

    test('폴더가 없으면 0장으로 조용히 넘어가지 않고 실패한다', () {
      expect(() => loadCorpus(Directory('${dir.path}/없음')), throwsStateError);
    });
  });

  group('베이스라인', () {
    test('정렬된 JSON으로 쓰고 그대로 읽는다', () {
      const baseline = {
        'b': {'name': 'correct'},
        'a': {'roaster': 'wrong: KWAMI', 'name': 'missing'},
      };
      final text = encodeBaseline(baseline);
      expect(text.indexOf('"a"'), lessThan(text.indexOf('"b"')));
      expect(text.indexOf('"name"'), lessThan(text.indexOf('"roaster"')));
      expect(decodeBaseline(text), baseline);
    });

    test('바뀐 칸만 보고한다 — 한 칸 고치고 한 칸 깨도 상쇄되지 않는다', () {
      const before = {
        'hwachae': {
          'name': 'missing',
          'roaster': 'correct',
          'components[2].region': 'wrong: avour berry bomb tropicalfruits',
        },
      };
      const after = {
        'hwachae': {
          'name': 'correct',
          'roaster': 'missing',
          'components[2].region': 'wrong: Designed for',
        },
      };
      expect(diffBaseline(before, after), [
        'hwachae  components[2].region  wrong: avour berry bomb tropicalfruits → wrong: Designed for',
        'hwachae  name  missing → correct',
        'hwachae  roaster  correct → missing',
      ]);
    });

    test('생기거나 사라진 카드·칸도 보고한다', () {
      expect(
        diffBaseline(
          const {'a': {'name': 'correct'}},
          const {'b': {'name': 'correct'}},
        ),
        ['a  name  correct → (없음)', 'b  name  (없음) → correct'],
      );
    });

    test('같으면 빈 목록', () {
      expect(
        diffBaseline(
          const {'a': {'name': 'correct'}},
          const {'a': {'name': 'correct'}},
        ),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_support_test.dart`
Expected: 컴파일 실패 — `test/support/ocr_corpus.dart` 없음.

- [ ] **Step 3: 코퍼스 도구를 쓴다**

`test/support/ocr_corpus.dart`:

```dart
// OCR 코퍼스 — 픽스처 모델, 파이프라인 재생, 베이스라인.
// 설계: docs/plans/ocr-corpus-design.md §4.1·§4.4.
import 'dart:convert';
import 'dart:io';

import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';

import 'ocr_score.dart';

/// 카드 한 장의 ML Kit 출력(`<id>.ocr.json`). 형식은 설계 §4.1.
class CorpusFixture {
  final String id;
  final String source;

  /// null이면 기록이 없다 — 빈 보고서로 재생한다.
  final Set<ImageQualityIssue>? quality;

  /// ML Kit이 준 순서 그대로다. 파서에 순서 의존 경로가 있어 재정렬하면 안 된다.
  final List<OcrLine> original;

  /// null이면 보정 패스가 없다 — 기기에서 보정이 실패한 것처럼 재생한다.
  final List<OcrLine>? enhanced;

  const CorpusFixture({
    required this.id,
    required this.source,
    required this.quality,
    required this.original,
    required this.enhanced,
  });

  factory CorpusFixture.fromJson(Map<String, Object?> json) {
    requireKeys(
        json, const {'id', 'source', 'quality', 'original', 'enhanced'}, 'fixture');
    List<OcrLine> lines(Object? raw) => [
          for (final item in raw! as List) _line((item as Map).cast<String, Object?>()),
        ];
    final quality = json['quality'] as List?;
    final enhanced = json['enhanced'];
    return CorpusFixture(
      id: json['id']! as String,
      source: json['source']! as String,
      quality: quality == null
          ? null
          : {
              for (final name in quality)
                ImageQualityIssue.values.byName(name as String),
            },
      original: lines(json['original']),
      enhanced: enhanced == null ? null : lines(enhanced),
    );
  }

  static OcrLine _line(Map<String, Object?> json) => OcrLine(
        json['text']! as String,
        left: (json['l']! as num).toDouble(),
        top: (json['t']! as num).toDouble(),
        right: (json['r']! as num).toDouble(),
        bottom: (json['b']! as num).toDouble(),
        confidence: (json['conf'] as num?)?.toDouble(),
      );
}

const _originalPath = 'corpus/original';
const _enhancedPath = 'corpus/enhanced';

/// 기록된 ML Kit 출력으로 실제 [DefaultOcrPipeline]을 돌린다. seam 세 개만
/// 바꾸므로 분기·후보 선택·병합이 기기와 같은 코드로 돈다.
Future<OcrDraft> replayPipeline(CorpusFixture fixture) async {
  final pipeline = DefaultOcrPipeline(
    ocr: _ReplayOcr(fixture),
    qualityAnalyzer: _ReplayQuality(ImageQualityReport(fixture.quality ?? const {})),
    preprocessor: _ReplayPreprocessor(hasEnhanced: fixture.enhanced != null),
  );
  return (await pipeline.analyze(_originalPath)).draft;
}

class _ReplayOcr implements OcrService {
  _ReplayOcr(this.fixture);
  final CorpusFixture fixture;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async =>
      imagePath == _enhancedPath ? fixture.enhanced! : fixture.original;
}

class _ReplayQuality implements ImageQualityAnalyzer {
  _ReplayQuality(this.report);
  final ImageQualityReport report;

  @override
  Future<ImageQualityReport> analyze(String imagePath) async => report;
}

class _ReplayPreprocessor implements OcrImagePreprocessor {
  _ReplayPreprocessor({required this.hasEnhanced});
  final bool hasEnhanced;

  @override
  Future<String> enhance(String imagePath) async {
    // 기록이 없으면 보정 실패로 재생한다 — 파이프라인은 그때 원본 후보만으로 고른다.
    if (!hasEnhanced) throw StateError('보정 패스 기록 없음');
    return _enhancedPath;
  }

  @override
  Future<void> delete(String imagePath) async {}
}

/// 픽스처와 정답표 한 쌍.
class CorpusCard {
  final CorpusFixture fixture;
  final Truth truth;
  const CorpusCard(this.fixture, this.truth);

  String get id => fixture.id;
}

/// `<id>.ocr.json`과 `<id>.truth.json`을 짝지어 읽는다. 다른 파일(baseline.json,
/// sources.json)은 무시한다.
List<CorpusCard> loadCorpus(Directory dir) {
  if (!dir.existsSync()) {
    // 0장으로 조용히 통과하면 게이트가 아무것도 지키지 않는다.
    throw StateError('코퍼스 폴더가 없다: ${dir.absolute.path} — 저장소 루트에서 '
        'flutter test를 실행했는지 확인');
  }
  final ocrFiles = <String, File>{};
  final truthFiles = <String, File>{};
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.endsWith('.ocr.json')) {
      ocrFiles[name.substring(0, name.length - '.ocr.json'.length)] = file;
    } else if (name.endsWith('.truth.json')) {
      truthFiles[name.substring(0, name.length - '.truth.json'.length)] = file;
    }
  }
  final orphans = [
    for (final id in ocrFiles.keys)
      if (!truthFiles.containsKey(id)) '$id.ocr.json (정답표 없음)',
    for (final id in truthFiles.keys)
      if (!ocrFiles.containsKey(id)) '$id.truth.json (픽스처 없음)',
  ];
  if (orphans.isNotEmpty) {
    throw StateError('짝이 없는 파일:\n${orphans.join('\n')}');
  }
  return [
    for (final id in ocrFiles.keys.toList()..sort())
      _card(id, ocrFiles[id]!, truthFiles[id]!),
  ];
}

CorpusCard _card(String id, File ocrFile, File truthFile) {
  final fixture = _read(ocrFile, CorpusFixture.fromJson);
  final truth = _read(truthFile, Truth.fromJson);
  if (fixture.id != id || truth.id != id) {
    throw FormatException(
        '$id: 파일 이름과 id가 다르다 (픽스처 ${fixture.id}, 정답표 ${truth.id})');
  }
  return CorpusCard(fixture, truth);
}

T _read<T>(File file, T Function(Map<String, Object?> json) parse) {
  try {
    return parse(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
  } on FormatException catch (error) {
    throw FormatException('${file.path}: ${error.message}');
  } catch (error) {
    throw FormatException('${file.path}: $error');
  }
}

/// card → cell → [Cell.encoded].
typedef Baseline = Map<String, Map<String, String>>;

Baseline toBaseline(Map<String, List<Cell>> scored) => {
      for (final MapEntry(:key, :value) in scored.entries)
        key: {for (final cell in value) cell.key: cell.encoded},
    };

/// 카드·칸을 정렬해 쓴다 — 갱신 diff가 바뀐 칸만 보이게.
String encodeBaseline(Baseline baseline) {
  final sorted = {
    for (final card in baseline.keys.toList()..sort())
      card: {
        for (final cell in baseline[card]!.keys.toList()..sort())
          cell: baseline[card]![cell]!,
      },
  };
  return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
}

Baseline decodeBaseline(String text) => {
      for (final MapEntry(:key, :value)
          in (jsonDecode(text) as Map<String, Object?>).entries)
        key: Map<String, String>.from(value! as Map),
    };

/// 바뀐 칸만 낸다. 총점이 아니라 칸 단위라서, 한 칸 고치고 한 칸 깨도
/// 상쇄되지 않는다(설계 §4.4).
List<String> diffBaseline(Baseline before, Baseline after) {
  final lines = <String>[];
  for (final card in {...before.keys, ...after.keys}.toList()..sort()) {
    final was = before[card] ?? const <String, String>{};
    final now = after[card] ?? const <String, String>{};
    for (final cell in {...was.keys, ...now.keys}.toList()..sort()) {
      if (was[cell] != now[cell]) {
        lines.add('$card  $cell  ${was[cell] ?? '(없음)'} → ${now[cell] ?? '(없음)'}');
      }
    }
  }
  return lines;
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_support_test.dart`
Expected: `All tests passed!`

재생 그룹 중 하나라도 실패하면 **테스트 기대값을 고치지 말고 멈춰서 보고한다** — 계획 단계 실측과 다르다는 뜻이고, 파이프라인 분기를 잘못 이해한 것이다.

- [ ] **Step 5: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded` 그리고 `flutter analyze`
Expected: 기존 377개 + Task 1·2 신규 전부 통과, `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add test/support/ocr_corpus.dart test/unit/ocr_corpus_support_test.dart
git commit -m "test(ocr): replay recorded OCR through the real pipeline

Fixtures hold both ML Kit passes and the quality report, and replay
swaps only the three existing seams, so candidate selection and merge
run the same code as on device. The baseline is per cell, so fixing
one cell while breaking another cannot cancel out.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```

- [ ] **Step 7: 변이로 재생 분기를 증명한다**

커밋한 뒤에 한다. 변이마다 고치고 `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_support_test.dart`를 돌린 뒤 `git checkout -- test/support/ocr_corpus.dart`로 되돌린다. 빨개진 테스트 이름을 보고서에 적고, 하나라도 초록이면 멈추고 보고한다. 마지막에 `git status --short test/`가 비어 있는지 확인한다.

| 변이 | 빨개져야 하는 테스트 |
|---|---|
| `_ReplayQuality(ImageQualityReport(fixture.quality ?? const {}))` → `_ReplayQuality(const ImageQualityReport())` | `저대비면 원본이 멀쩡해도 보정 패스를 본다` |
| `_ReplayOcr.recognize`가 항상 `fixture.original`을 돌려줌 | `원본이 약하면 보정 패스로 메운다`, `저대비면…` |
| `loadCorpus`의 `if (!dir.existsSync())` 블록 삭제 | `폴더가 없으면…` (`listSync`가 던지는 `PathNotFoundException`은 `StateError`가 아니다) |
| `diffBaseline`의 비교를 `was[cell] != now[cell]` → `false` | `바뀐 칸만 보고한다…`, `생기거나 사라진…` |

---

## Task 3: 첫 코퍼스 2장(이관) + 회귀 게이트 + 리포트

RED CASCARA와 HWACHAE는 원본 사진이 없다. `test/helpers.dart`의 실측 좌표(2026-08-04·08-08 Android 에뮬레이터 ORIGINAL 패스)를 JSON으로 옮기고, 정답은 각 설계 문서의 판독 기록에서 복원한다(설계 §5의 예외). 두 장은 원본 패스만 있으므로 `quality`·`enhanced`가 `null`이다.

**Files:**
- Create: `test/fixtures/ocr_corpus/red_cascara.ocr.json`
- Create: `test/fixtures/ocr_corpus/red_cascara.truth.json`
- Create: `test/fixtures/ocr_corpus/hwachae.ocr.json`
- Create: `test/fixtures/ocr_corpus/hwachae.truth.json`
- Create: `test/fixtures/ocr_corpus/baseline.json` (생성 — Step 7)
- Create: `test/unit/ocr_corpus_test.dart`
- Modify: `test/support/ocr_corpus.dart` (리포트 추가)
- Modify: `test/unit/ocr_corpus_support_test.dart` (리포트 테스트 추가)

**Interfaces:**
- Consumes: Task 1 전부, Task 2 전부, `redCascaraLines`·`hwachaeLines`(`test/helpers.dart`).
- Produces: `enum Cause { parser, ocr, unclassified }` · `Cause causeOf(Cell cell, String normalizedOcrText)` · `String corpusReport(List<CorpusCard> cards, Map<String, List<Cell>> scored)` (Task 5가 쓴다). 게이트 실행법: `flutter test --dart-define=UPDATE_OCR_BASELINE=true test/unit/ocr_corpus_test.dart`로 베이스라인 재작성 + 리포트 출력.

- [ ] **Step 1: 리포트 테스트를 추가한다 (실패)**

`test/unit/ocr_corpus_support_test.dart` 상단 import에 한 줄을 더한다:

```dart
import '../support/ocr_score.dart';
```

`main()`의 마지막 `group('베이스라인', …)` 다음에 추가한다:

```dart
  group('원인 구분 (근사 — 설계 §4.2)', () {
    final ocrText = normalize(
        'Oromia, West Guji Hambella Wamena, Danse Saysa Tacet Coffee Roasters');

    test('정답 단어가 OCR에 다 있으면 파서 문제', () {
      const cell =
          Cell('roaster', Verdict.missing, null, ['Tacet Coffee Roasters']);
      expect(causeOf(cell, ocrText), Cause.parser);
    });

    test('한 값이 두 줄로 쪼개지고 순서가 바뀌어도 단어로 본다', () {
      final text = normalize('Hambella Wamena, Danse Saysa\nOromia, West Guji');
      const cell = Cell('components[0].region', Verdict.wrong,
          'Oromia, West Guji', ['Oromia, West Guji Hambella Wamena, Danse Saysa']);
      expect(causeOf(cell, text), Cause.parser);
    });

    test('정답 단어가 OCR에 없으면 OCR 문제', () {
      const cell = Cell('roaster', Verdict.wrong, 'a Cotee Roastery',
          ['One Half Coffee Roastery']);
      expect(causeOf(cell, normalize('a Cotee Roastery Roasted in Malaysia')),
          Cause.ocr);
    });

    test('정답이 없는 칸을 채웠으면 파서 문제', () {
      const cell = Cell('cupNotes[+열대과일]', Verdict.wrong, '열대과일', []);
      expect(causeOf(cell, ocrText), Cause.parser);
    });

    test('열거형·국가·날짜·비율은 가리지 않는다', () {
      for (final key in [
        'type',
        'roastLevel',
        'roastDate',
        'components[0].country',
        'components[0].process',
        'components[0].ratioPercent',
      ]) {
        expect(causeOf(Cell(key, Verdict.missing, null, const ['x']), ocrText),
            Cause.unclassified,
            reason: key);
      }
    });
  });

  test('리포트는 카드별·합계 개수, 원인별 개수, 문제 칸 목록을 낸다', () async {
    final card = CorpusCard(
      fixture(original: strong, quality: []),
      Truth.fromJson({
        'id': 'f',
        'name': '테스트 원두',
        'roaster': '없는 로스터',
        'roastDate': null,
        'roastLevel': 'medium',
        'type': 'single',
        'cupNotes': <Object?>[],
        'components': [
          {'country': 'Ethiopia', 'region': null, 'process': 'washed', 'ratioPercent': null},
        ],
      }),
    );
    final scored = {
      'f': scoreDraft(card.truth, await replayPipeline(card.fixture)),
    };
    final report = corpusReport([card], scored);
    // 채움 정답 4(name·roastLevel·country·process), 비움 정답 3(roastDate·
    // region·ratioPercent), 빈칸 2(roaster·type — strong은 유형이 ambiguous).
    expect(report, contains('1장, 칸 9개'));
    expect(report, contains('  f  정답 7 (채움 4 / 비움 3)  빈칸 2  틀림 0'));
    expect(report, contains('합계  정답 7 (채움 4 / 비움 3)  빈칸 2  틀림 0'));
    expect(report, contains('  파서 0칸'));
    expect(report, contains('  OCR 1칸'));
    expect(report, contains('  미분류 1칸'));
    expect(report, contains('  f  roaster  missing  [OCR]'));
    expect(report, contains('  f  type  missing  [미분류]'));
  });
```

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_support_test.dart`
Expected: 컴파일 실패 — `causeOf`·`Cause`·`corpusReport` 없음.

- [ ] **Step 2: 리포트를 쓴다**

`test/support/ocr_corpus.dart` 끝에 추가한다:

```dart
/// 빈칸·틀림 칸의 원인(근사, 설계 §4.2).
enum Cause { parser, ocr, unclassified }

const _causeLabels = {
  Cause.parser: '파서',
  Cause.ocr: 'OCR',
  Cause.unclassified: '미분류',
};

/// 빈칸·틀림 칸이 파서 탓인지 OCR 탓인지 가린다. 문자열 칸만 본다 —
/// 열거형·국가·날짜·비율은 카드 표기와 앱 표기가 달라(`에티오피아` ↔ `Ethiopia`)
/// 텍스트로 찾을 수 없다.
Cause causeOf(Cell cell, String normalizedOcrText) {
  final key = cell.key;
  final textual = key == 'name' ||
      key == 'roaster' ||
      key.startsWith('cupNotes[') ||
      key.endsWith('.region');
  if (!textual) return Cause.unclassified;
  // 정답이 없는 칸을 채웠다 — OCR은 무언가를 읽었고 파서가 엉뚱한 칸에 넣었다.
  if (cell.expected.isEmpty) return Cause.parser;
  // 줄이 아니라 단어로 본다. ML Kit은 한 값을 두 줄로 쪼개거나 순서를 바꿔 낸다.
  final seen = cell.expected.any((value) => value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .every((word) => normalizedOcrText.contains(normalize(word))));
  return seen ? Cause.parser : Cause.ocr;
}

/// 사람이 읽는 채점 요약. 베이스라인을 갱신할 때 출력한다.
String corpusReport(List<CorpusCard> cards, Map<String, List<Cell>> scored) {
  final rows = <String>[];
  final problems = <String>[];
  final causes = {for (final cause in Cause.values) cause: 0};
  var filled = 0, empty = 0, missing = 0, wrong = 0;
  for (final card in cards) {
    final lines = [...card.fixture.original, ...?card.fixture.enhanced];
    final ocrText = normalize(lines.map((line) => line.text).join(' '));
    var f = 0, e = 0, m = 0, w = 0;
    for (final cell in scored[card.id]!) {
      switch (cell.verdict) {
        case Verdict.correct:
          if (cell.actual == null) {
            e++;
          } else {
            f++;
          }
          continue;
        case Verdict.missing:
          m++;
        case Verdict.wrong:
          w++;
      }
      final cause = causeOf(cell, ocrText);
      causes[cause] = causes[cause]! + 1;
      problems.add('  ${card.id}  ${cell.key}  ${cell.encoded}  '
          '[${_causeLabels[cause]}]');
    }
    rows.add('  ${card.id}  ${_counts(f, e, m, w)}');
    filled += f;
    empty += e;
    missing += m;
    wrong += w;
  }
  return [
    'OCR 코퍼스 채점 — ${cards.length}장, 칸 ${filled + empty + missing + wrong}개',
    '',
    '카드별',
    ...rows,
    '합계  ${_counts(filled, empty, missing, wrong)}',
    '',
    '빈칸·틀림 ${missing + wrong}칸의 원인 (근사 — 설계 §4.2)',
    '  파서 ${causes[Cause.parser]}칸 — OCR이 읽은 값을 못 뽑았거나 엉뚱한 칸에 넣었다',
    '  OCR ${causes[Cause.ocr]}칸 — 정답 단어가 OCR 텍스트에 없다',
    '  미분류 ${causes[Cause.unclassified]}칸 — 열거형·국가·날짜·비율',
    '',
    '빈칸·틀림 목록',
    ...problems,
  ].join('\n');
}

String _counts(int filled, int empty, int missing, int wrong) =>
    '정답 ${filled + empty} (채움 $filled / 비움 $empty)  빈칸 $missing  틀림 $wrong';
```

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_support_test.dart`
Expected: `All tests passed!`

- [ ] **Step 3: 두 카드의 픽스처를 이관한다**

`test/fixtures/ocr_corpus/red_cascara.ocr.json` — `test/helpers.dart:236-263`의 `redCascaraLines`를 **순서 그대로** 옮긴 것이다:

```json
{
  "id": "red_cascara",
  "source": "test/helpers.dart redCascaraLines — 2026-08-04 Android 에뮬레이터 ML Kit(korean) ORIGINAL 패스. 원본 사진 없음",
  "quality": null,
  "original": [
    {"text": "블렌딩:", "l": 876, "t": 2453, "r": 1095, "b": 2520, "conf": null},
    {"text": "노트:", "l": 839, "t": 3349, "r": 1046, "b": 3413, "conf": null},
    {"text": "Blending Info", "l": 876, "t": 2559, "r": 1218, "b": 2617, "conf": null},
    {"text": "Notes", "l": 875, "t": 3451, "r": 1034, "b": 3501, "conf": null},
    {"text": "UNSPECIALTY BLEND", "l": 1191, "t": 191, "r": 2160, "b": 260, "conf": null},
    {"text": "RED CASCARA", "l": 1137, "t": 511, "r": 2303, "b": 610, "conf": null},
    {"text": "로스터기:", "l": 873, "t": 3708, "r": 1159, "b": 3781, "conf": null},
    {"text": "Roaster", "l": 864, "t": 3820, "r": 1073, "b": 3874, "conf": null},
    {"text": "레드 카스카라", "l": 1312, "t": 773, "r": 2127, "b": 895, "conf": null},
    {"text": "Thailand Phupanna coffee", "l": 1329, "t": 2465, "r": 2096, "b": 2536, "conf": null},
    {"text": "bio control Natural 70940%", "l": 1352, "t": 2563, "r": 2236, "b": 2622, "conf": null},
    {"text": "Ethiopia Sidama Bensa Keramo Ako", "l": 1327, "t": 2745, "r": 2394, "b": 2807, "conf": null},
    {"text": "GI Natural- 40%", "l": 1366, "t": 2836, "r": 1846, "b": 2901, "conf": null},
    {"text": "Colombia Inmaculada Fellow Farnms", "l": 1327, "t": 3017, "r": 2393, "b": 3078, "conf": null},
    {"text": "Papayo Natural 20%", "l": 1345, "t": 3102, "r": 1973, "b": 3176, "conf": null},
    {"text": "Raspberrie, Sapphire Grape,", "l": 1328, "t": 3351, "r": 2318, "b": 3443, "conf": null},
    {"text": "Complexity, Citrus fnish", "l": 1328, "t": 3450, "r": 2197, "b": 3527, "conf": null},
    {"text": "Stronghold S7X Ver.2", "l": 1326, "t": 3704, "r": 2065, "b": 3780, "conf": null}
  ],
  "enhanced": null
}
```

`test/fixtures/ocr_corpus/hwachae.ocr.json` — `test/helpers.dart:269-290`의 `hwachaeLines`:

```json
{
  "id": "hwachae",
  "source": "test/helpers.dart hwachaeLines — 2026-08-08 Android 에뮬레이터 ML Kit(korean) ORIGINAL 패스. 원본 사진 없음",
  "quality": null,
  "original": [
    {"text": "info. 109% panama blackmoon, geisha, anaerobic n", "l": 157, "t": 1376, "r": 1672, "b": 1442, "conf": null},
    {"text": "45% ecuador meridiano, typica mejorado, washed", "l": 301, "t": 1450, "r": 1818, "b": 1520, "conf": null},
    {"text": "45% ethiopia gute mini, 74110 peaberry, washed", "l": 302, "t": 1521, "r": 1769, "b": 1598, "conf": null},
    {"text": "avour berry bomb, tropicalfruits,", "l": 155, "t": 1743, "r": 1196, "b": 1828, "conf": null},
    {"text": "igtlk tea, plun sorbet", "l": 159, "t": 1847, "r": 954, "b": 1915, "conf": null},
    {"text": "Alt 한/영", "l": 1244, "t": 202, "r": 1661, "b": 311, "conf": null},
    {"text": "a Cotee Roastery", "l": 366, "t": 2260, "r": 885, "b": 2328, "conf": null},
    {"text": "NSI or quaity, seasonality, and harmony.", "l": 229, "t": 2344, "r": 1455, "b": 2407, "conf": null},
    {"text": "HWACHAE BLEND", "l": 2173, "t": 1377, "r": 2979, "b": 1452, "conf": null},
    {"text": "Designed for", "l": 2172, "t": 1495, "r": 2737, "b": 1593, "conf": null},
    {"text": "UNSPECIALTY", "l": 2171, "t": 1616, "r": 2800, "b": 1697, "conf": null},
    {"text": "13 JUL 2026", "l": 2353, "t": 2198, "r": 2956, "b": 2340, "conf": null},
    {"text": "Roasted in Malaysia", "l": 2162, "t": 2347, "r": 2727, "b": 2406, "conf": null}
  ],
  "enhanced": null
}
```

옮겨 적은 값이 원본과 같은지는 Step 5의 테스트가 지킨다.

- [ ] **Step 4: 두 카드의 정답표를 쓴다**

`test/fixtures/ocr_corpus/red_cascara.truth.json`:

```json
{
  "id": "red_cascara",
  "notes": "원본 사진 없음 — ocr-bilingual-blend-card-design.md §2.2·§2.3의 판독 기록과 좌표에서 복원(설계 §5 예외). OCR 오독은 두 군데뿐이라 기록됐다: `Citrus finish`→`fnish`, `Natural 709 - 40%`→`70940%`. 그래서 Thailand 비율 40, `Raspberrie`는 카드 표기 그대로. 카드에 지역 라벨이 없다 — 국가 뒤 말 중 지역 경로는 Ethiopia의 `Sidama Bensa Keramo Ako`뿐이고(R3), `Phupanna coffee`·`Inmaculada Fellow Farms`는 생산자 이름이라 받지 않는다. `로스터기: Stronghold S7X Ver.2`는 로스팅 기계다.",
  "name": ["레드 카스카라", "RED CASCARA"],
  "roaster": "UNSPECIALTY",
  "roastDate": null,
  "roastLevel": null,
  "type": "blend",
  "cupNotes": ["Raspberrie", "Sapphire Grape", "Complexity", "Citrus finish"],
  "components": [
    {"country": "Thailand", "region": null, "process": "natural", "ratioPercent": 40},
    {"country": "Ethiopia", "region": [null, "Sidama Bensa Keramo Ako", "Sidama"], "process": "natural", "ratioPercent": 40},
    {"country": "Colombia", "region": null, "process": "natural", "ratioPercent": 20}
  ]
}
```

`test/fixtures/ocr_corpus/hwachae.truth.json`:

```json
{
  "id": "hwachae",
  "notes": "원본 사진 없음 — ocr-inline-blend-card-design.md §1의 카드 전사에서 복원(설계 §5 예외). 로스터리는 하단 `13 JUL 2026 · Roasted in Malaysia · One Half Coffee Roastery`. `Designed for UNSPECIALTY`는 블렌드를 의뢰한 곳이다. 지역 라벨이 없고 국가 뒤 말(`blackmoon`, `meridiano`, `gute mini`)이 지역인지 농장인지 카드만으로 알 수 없어 비우는 것을 정답으로 둔다. Panama의 `anaerobic n`은 무산소 내추럴(R5). Panama 비율은 카드에 10%(OCR이 `109%`로 읽음).",
  "name": "HWACHAE BLEND",
  "roaster": "One Half Coffee Roastery",
  "roastDate": "2026-07-13",
  "roastLevel": null,
  "type": "blend",
  "cupNotes": ["berry bomb", "tropical fruits", "light milk tea", "plum sorbet"],
  "components": [
    {"country": "Panama", "region": null, "process": ["anaerobic", "natural"], "ratioPercent": 10},
    {"country": "Ecuador", "region": null, "process": "washed", "ratioPercent": 45},
    {"country": "Ethiopia", "region": null, "process": "washed", "ratioPercent": 45}
  ]
}
```

- [ ] **Step 5: 게이트 테스트를 쓴다**

`test/unit/ocr_corpus_test.dart`:

```dart
// OCR 코퍼스 회귀 게이트. 카드마다 기록된 ML Kit 출력을 실제 파이프라인에
// 태우고, 사진에서 쓴 정답표와 칸 단위로 대조해 베이스라인과 비교한다.
// 설계: docs/plans/ocr-corpus-design.md
//
// 베이스라인 갱신(의도한 변화일 때만):
//   flutter test --dart-define=UPDATE_OCR_BASELINE=true test/unit/ocr_corpus_test.dart
// 갱신하면 리포트가 출력된다. baseline.json diff를 같은 커밋에 남긴다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/ocr_corpus.dart';
import '../support/ocr_score.dart';

const _update = bool.fromEnvironment('UPDATE_OCR_BASELINE');
final _dir = Directory('test/fixtures/ocr_corpus');

void main() {
  test('코퍼스 채점이 베이스라인과 칸 단위로 같다', () async {
    final cards = loadCorpus(_dir);
    expect(cards, isNotEmpty, reason: '코퍼스가 비었다 — ${_dir.absolute.path}');
    final scored = {
      for (final card in cards)
        card.id: scoreDraft(card.truth, await replayPipeline(card.fixture)),
    };
    final current = toBaseline(scored);
    final file = File('${_dir.path}/baseline.json');

    if (_update) {
      file.writeAsStringSync(encodeBaseline(current));
      // ignore: avoid_print
      print(corpusReport(cards, scored));
      return;
    }

    expect(file.existsSync(), isTrue,
        reason: '베이스라인이 없다 — --dart-define=UPDATE_OCR_BASELINE=true 로 만든다');
    final changed = diffBaseline(decodeBaseline(file.readAsStringSync()), current);
    expect(changed, isEmpty,
        reason: '채점이 바뀐 칸 ${changed.length}개:\n${changed.join('\n')}\n\n'
            '의도한 변화면 --dart-define=UPDATE_OCR_BASELINE=true 로 갱신하고 '
            'baseline.json diff를 커밋에 남긴다.');
  });

  test('이관한 실측 픽스처가 test/helpers.dart 원본과 같다', () {
    // 두 카드는 원본 사진이 없어 이 좌표가 유일본이다. 한쪽만 고쳐지면 안 된다.
    for (final (id, lines) in [
      ('red_cascara', redCascaraLines),
      ('hwachae', hwachaeLines),
    ]) {
      final fixture = CorpusFixture.fromJson(jsonDecode(
              File('${_dir.path}/$id.ocr.json').readAsStringSync())
          as Map<String, Object?>);
      expect(
        [
          for (final line in fixture.original)
            [line.text, line.left, line.top, line.right, line.bottom],
        ],
        [
          for (final line in lines)
            [line.text, line.left, line.top, line.right, line.bottom],
        ],
        reason: id,
      );
    }
  });
}
```

- [ ] **Step 6: 베이스라인 없이 실패를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: 첫 테스트 FAIL — `베이스라인이 없다`. 두 번째 테스트(이관 일치)는 PASS. 두 번째가 실패하면 Step 3의 JSON 옮겨 적기가 틀렸다 — 실패 메시지의 칸을 고친다.

- [ ] **Step 7: 베이스라인을 만들고 리포트를 확인한다**

Run: `flutter test --dart-define=UPDATE_OCR_BASELINE=true --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: PASS, 리포트가 출력되고 `test/fixtures/ocr_corpus/baseline.json`이 생긴다.

`baseline.json`에서 기존 테스트가 이미 문서로 남긴 사실과 맞는지 확인한다. **하나라도 다르면 멈추고 보고한다** — 재생이 `parseOcr`과 다르게 돌고 있다는 뜻이다(두 카드는 원본 패스만 있어 재생 결과가 `parseOcr(lines)`와 같아야 한다).

| 카드 | 칸 | 기대 | 근거 |
|---|---|---|---|
| hwachae | `name` | `missing` | `ocr_parser_test.dart` "제품명은 비운다" |
| hwachae | `roaster` | `wrong: a Cotee Roastery` | "로스터리는 OCR이 읽은 그대로다" |
| hwachae | `roastDate` | `correct` | "성분 3개와 로스팅 날짜가 채워진다" |
| hwachae | `components[0].ratioPercent` | `missing` | 같은 테스트의 `[null, 45, 45]` |
| hwachae | `components[0].process` | `missing` | "알려진 결함: 가공이 … 셋 다 null" |
| hwachae | `components[2].region` | `wrong: avour berry bomb tropicalfruits` | "알려진 결함: 표-폴백이 …" |
| hwachae | `cupNotes[berry bomb]` | `missing` | "컵노트는 비어 있고" |
| red_cascara | `roaster` | `correct` | 한/영 병기 브랜치 수정 (a) |
| red_cascara | `components[0].ratioPercent` | `missing` | "비율 불명은 null로 남긴다" `[null, 40, 20]` |
| red_cascara | `components[0].region` | `wrong: bio control 70940%` | 같은 테스트의 region 고정값 |
| red_cascara | `components[1].region` | `wrong: GI -` | 〃 |
| red_cascara | `cupNotes[Citrus finish]` | `missing` | OCR `fnish` 오독 |
| red_cascara | `cupNotes[+Citrus fnish]` | `wrong: Citrus fnish` | 〃 |

- [ ] **Step 8: 게이트를 다시 돌려 통과를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: `All tests passed!`

- [ ] **Step 9: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded` 그리고 `flutter analyze`
Expected: 전부 통과, `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add test/fixtures/ocr_corpus/red_cascara.ocr.json test/fixtures/ocr_corpus/red_cascara.truth.json test/fixtures/ocr_corpus/hwachae.ocr.json test/fixtures/ocr_corpus/hwachae.truth.json test/fixtures/ocr_corpus/baseline.json test/unit/ocr_corpus_test.dart test/support/ocr_corpus.dart test/unit/ocr_corpus_support_test.dart
git commit -m "test(ocr): gate parser changes on a per-cell corpus baseline

Seed the corpus with the two device-recorded blend cards whose photos
are gone; their coordinates move to JSON with a test pinning them to
the helpers.dart originals. The baseline matches every defect the
existing tests already document, and the report splits missing and
wrong cells into parser or OCR causes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```

---

## Task 4: 덤프 도구 — 호스트 드라이버와 기기 테스트

**Files:**
- Create: `test/fixtures/ocr_corpus/sources.json`
- Create: `test_driver/ocr_corpus_driver.dart`
- Create: `integration_test/ocr_corpus_dump_test.dart`
- Output (커밋 안 함): `build/ocr_corpus/<id>.ocr.json` × 9

**Interfaces:**
- Consumes (lib): `MlkitOcrService`·`OcrLine`, `DartImageQualityAnalyzer`, `DartOcrImagePreprocessor`.
- Produces: 픽스처 9장 원료(Task 5가 `test/fixtures/ocr_corpus/`로 옮긴다). 형식은 Task 2의 `CorpusFixture.fromJson`이 읽는 그대로.
- 드라이버 ↔ 기기 계약: `GET /index.json` → `{"<id>": "<원본 경로>"}`, `GET /card/<id>` → 사진 바이트. 기기는 `binding.reportData = {'cards': [ {id, source, quality, original, enhanced} ]}`로 돌려준다.

**왜 이 경로인가(설계 §4.6):** adb push는 앱 설치가 `flutter drive` 안에서 일어나 실행 전에 앱 폴더가 없고, assets는 릴리스 앱에 실리며 gitignore된 폴더를 선언하면 CI 빌드가 깨진다. 결과 채널 `reportData`는 기존 스크린샷 드라이버가 쓰는 것과 같다.

- [ ] **Step 1: 코퍼스 목록을 쓴다**

`test/fixtures/ocr_corpus/sources.json`:

```json
{
  "ocr_card_ko": "assets/test/ocr_card_ko.png",
  "ocr_card_orig": "assets/test/ocr_card_orig.png",
  "ethiopia_worka": "samples/cards/KakaoTalk_20260825_232315388.jpg",
  "kwami_gesha_honey": "samples/cards/KakaoTalk_20260825_232315388_01.jpg",
  "sol_de_la_manana": "samples/cards/KakaoTalk_20260825_232315388_02.jpg",
  "bench_maji_gesha": "samples/cards/KakaoTalk_20260825_232315388_03.jpg",
  "tacet_guji_hambella": "samples/cards/KakaoTalk_20260825_232315388_04.jpg",
  "archers_sidama": "samples/cards/KakaoTalk_20260825_232315388_05.jpg",
  "costa_rica_copey_52": "samples/cards/KakaoTalk_20260829_003811592.jpg"
}
```

RED CASCARA·HWACHAE는 사진이 없어 목록에 없다. 이 파일은 `loadCorpus`가 무시한다(Task 2 테스트로 확인됨).

- [ ] **Step 2: 호스트 드라이버를 쓴다**

`test_driver/ocr_corpus_driver.dart`:

```dart
// OCR 코퍼스 덤프용 호스트 드라이버.
// sources.json의 사진을 루프백 HTTP로 서빙하고, 기기가 reportData로 돌려준
// ML Kit 출력을 build/ocr_corpus/<id>.ocr.json에 쓴다.
// 커밋된 픽스처(test/fixtures/ocr_corpus/)는 건드리지 않는다 — 재덤프 결과는
// 사람이 diff를 보고 옮긴다(설계 §4.6).
//
// 실행:
//   flutter drive --driver=test_driver/ocr_corpus_driver.dart \
//     --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

const _sources = 'test/fixtures/ocr_corpus/sources.json';
const _output = 'build/ocr_corpus';
// integration_test/ocr_corpus_dump_test.dart의 OCR_CORPUS_HOST 기본값과 짝이다.
const _port = 8765;

Future<void> main() async {
  final sources =
      (jsonDecode(File(_sources).readAsStringSync()) as Map).cast<String, String>();
  final missing = [
    for (final MapEntry(:key, :value) in sources.entries)
      if (!File(value).existsSync()) '$key → $value',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('원본 사진이 없다(samples/README.md 참고):\n${missing.join('\n')}');
    exit(2);
  }

  final HttpServer server;
  try {
    // 루프백에만 연다 — 사진을 LAN에 내놓지 않고, Windows 방화벽도 묻지 않는다.
    // 에뮬레이터는 호스트 루프백을 10.0.2.2로 본다.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  } on SocketException catch (error) {
    stderr.writeln('포트 $_port를 열 수 없다 — 다른 프로세스가 쓰는지 확인 ($error)');
    exit(2);
  }
  server.listen((request) async {
    final path = request.uri.pathSegments;
    final response = request.response;
    if (path.length == 1 && path.single == 'index.json') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(sources));
    } else if (path.length == 2 &&
        path.first == 'card' &&
        sources.containsKey(path.last)) {
      response.add(await File(sources[path.last]!).readAsBytes());
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });

  await integrationDriver(
    responseDataCallback: (data) async {
      final dir = await Directory(_output).create(recursive: true);
      for (final card in (data!['cards'] as List).cast<Map<String, dynamic>>()) {
        final file = File('${dir.path}/${card['id']}.ocr.json');
        await file.writeAsString(_format(card));
        stdout.writeln('saved ${file.path}');
      }
    },
  );
}

/// OCR 줄 하나를 한 줄에 쓴다 — 재덤프 diff에서 바뀐 줄만 보이게.
String _format(Map<String, dynamic> card) {
  final out = StringBuffer('{\n');
  for (final key in ['id', 'source', 'quality']) {
    out.writeln('  "$key": ${jsonEncode(card[key])},');
  }
  for (final key in ['original', 'enhanced']) {
    final lines = card[key] as List?;
    final comma = key == 'original' ? ',' : '';
    if (lines == null) {
      out.writeln('  "$key": null$comma');
      continue;
    }
    out.writeln('  "$key": [');
    for (var i = 0; i < lines.length; i++) {
      out.writeln('    ${jsonEncode(lines[i])}${i < lines.length - 1 ? ',' : ''}');
    }
    out.writeln('  ]$comma');
  }
  out.write('}\n');
  return out.toString();
}
```

- [ ] **Step 3: 기기 테스트를 쓴다**

`integration_test/ocr_corpus_dump_test.dart`:

```dart
// OCR 코퍼스 덤프 — 기기에서 실제 ML Kit을 돌려 픽스처 원료를 만든다.
// 혼자 돌리지 않는다. 호스트 드라이버가 사진을 서빙하고 결과를 받는다:
//   flutter drive --driver=test_driver/ocr_corpus_driver.dart \
//     --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554
// 설계: docs/plans/ocr-corpus-design.md §4.6
import 'dart:convert';
import 'dart:io';

import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// 에뮬레이터에서 호스트 루프백은 10.0.2.2다. 실기기는 `adb reverse tcp:8765
// tcp:8765` 후 --dart-define=OCR_CORPUS_HOST=http://127.0.0.1:8765 로 바꾼다.
const _host = String.fromEnvironment(
  'OCR_CORPUS_HOST',
  defaultValue: 'http://10.0.2.2:8765',
);

Future<List<int>> _get(String path) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse('$_host/$path'))).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('${response.statusCode} $_host/$path');
    }
    return await consolidateHttpClientResponseBytes(response);
  } finally {
    client.close();
  }
}

/// 드라이버가 테스트보다 늦게 뜰 수 있어 잠깐 기다린다. 끝내 못 닿으면 무한
/// 대기하지 않고 주소를 알려주며 실패한다.
Future<Map<String, String>> _index() async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (true) {
    try {
      final json = jsonDecode(utf8.decode(await _get('index.json')));
      return (json as Map).cast<String, String>();
    } on SocketException catch (error) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('$_host 에 닿지 못했다 ($error). 드라이버가 떠 있는지, '
            '실기기라면 OCR_CORPUS_HOST를 바꿨는지 확인');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}

Map<String, Object?> _line(OcrLine line) => {
      'text': line.text,
      'l': line.left,
      't': line.top,
      'r': line.right,
      'b': line.bottom,
      'conf': line.confidence,
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR 코퍼스 덤프', (tester) async {
    final index = await _index();
    final ocr = MlkitOcrService();
    final quality = DartImageQualityAnalyzer();
    final preprocessor = DartOcrImagePreprocessor();
    final temp = await getTemporaryDirectory();
    final cards = <Map<String, Object?>>[];

    for (final MapEntry(key: id, value: source) in index.entries) {
      final image = File('${temp.path}/ocr_corpus_$id.${source.split('.').last}');
      await image.writeAsBytes(await _get('card/$id'));

      // DefaultOcrDiagnosticsService.collect(ocr_diagnostics.dart)와 같은 순서다.
      // 다만 조건과 무관하게 보정 패스를 항상 돌린다 — 재생 쪽에서 파이프라인이
      // 어느 분기를 타든 재현할 수 있게(설계 §4.1).
      final issues = [
        for (final issue in (await quality.analyze(image.path)).issues) issue.name,
      ];
      final original = await ocr.recognize(image.path);
      List<OcrLine>? enhanced;
      String? enhancedPath;
      try {
        enhancedPath = await preprocessor.enhance(image.path);
        enhanced = await ocr.recognize(enhancedPath);
      } catch (_) {
        // 보정 실패는 null로 남긴다 — 재생이 기기의 보정 실패 경로를 그대로 탄다.
      } finally {
        if (enhancedPath != null) await preprocessor.delete(enhancedPath);
      }
      await image.delete();

      cards.add({
        'id': id,
        'source': source,
        'quality': issues,
        'original': [for (final line in original) _line(line)],
        'enhanced':
            enhanced == null ? null : [for (final line in enhanced) _line(line)],
      });
      // ignore: avoid_print
      print('덤프 $id: 원본 ${original.length}줄, '
          '보정 ${enhanced?.length ?? '없음'}, 품질 $issues');
    }
    binding.reportData = {'cards': cards};
  }, timeout: const Timeout(Duration(minutes: 30)));
}
```

- [ ] **Step 4: analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: 에뮬레이터를 띄운다**

```bash
flutter emulators --launch flutter_emulator
flutter devices
```

Expected: 1–2분 안에 `flutter devices`에 `emulator-5554`(이름은 다를 수 있다 — 이후 명령의 `-d`에 그 id를 쓴다)가 보인다. 안 보이면 `flutter_emulator_2`로 다시 시도한다.

- [ ] **Step 6: 덤프한다**

```bash
flutter drive --driver=test_driver/ocr_corpus_driver.dart --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554
```

Expected (빌드 포함 수 분 — 12MP 사진의 보정이 순수 Dart라 카드당 수십 초 걸릴 수 있다): 카드마다 `덤프 <id>: 원본 N줄, 보정 M줄, 품질 [...]`이 찍히고, `All tests passed!` 뒤에 `saved build/ocr_corpus/<id>.ocr.json`이 9줄 나온다.

결과를 훑어본다:

```bash
python - <<'EOF'
import json, glob
for p in sorted(glob.glob('build/ocr_corpus/*.ocr.json')):
    d = json.load(open(p, encoding='utf-8'))
    e = d['enhanced']
    print(f"{d['id']:22s} 원본 {len(d['original']):3d}줄  보정 {('없음' if e is None else len(e)):>3}  품질 {d['quality']}")
EOF
```

Expected: 9줄. **원본이 0줄인 카드가 있으면 멈추고 보고한다** — ML Kit 모델 미다운로드 등 환경 문제일 수 있다(`MlkitOcrService`는 실패를 빈 목록으로 삼킨다). `ocr_card_ko`는 기존 프로브 기준 10줄 안팎이어야 한다.

- [ ] **Step 7: 커밋된 픽스처를 건드리지 않았는지 확인한다 (Review Focus 5)**

Run: `git status --short test/fixtures`
Expected: `?? test/fixtures/ocr_corpus/sources.json` 한 줄뿐이다. 다른 줄이 있으면 드라이버가 잘못된 곳에 썼다.

- [ ] **Step 8: 호스트에 못 닿을 때 무한 대기하지 않는지 확인한다 (Review Focus 4)**

```bash
flutter drive --driver=test_driver/ocr_corpus_driver.dart --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554 --dart-define=OCR_CORPUS_HOST=http://10.0.2.2:1
```

Expected: 약 90초 뒤 테스트 실패 — 출력에 `닿지 못했다`와 `OCR_CORPUS_HOST`가 보이고, `build/ocr_corpus/`의 파일 시각이 바뀌지 않는다(실패 시 `responseDataCallback`이 불리지 않는다).

- [ ] **Step 9: 커밋**

```bash
git add test/fixtures/ocr_corpus/sources.json test_driver/ocr_corpus_driver.dart integration_test/ocr_corpus_dump_test.dart
git commit -m "test(ocr): dump device OCR for the corpus over loopback HTTP

The host driver serves the photos listed in sources.json and writes
what the device reports to build/, never over committed fixtures.
adb push cannot reach an app that flutter drive has not installed yet,
and assets would ship in the release app and break CI on a gitignored
folder.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```

---

## Task 5: 9장 정답표 + 픽스처 설치 + 베이스라인 + 첫 리포트

**Files:**
- Create: `test/fixtures/ocr_corpus/{ocr_card_ko,ocr_card_orig,ethiopia_worka,kwami_gesha_honey,sol_de_la_manana,bench_maji_gesha,tacet_guji_hambella,archers_sidama,costa_rica_copey_52}.truth.json`
- Create: 같은 9개 id의 `.ocr.json` (Task 4의 `build/ocr_corpus/`에서 복사)
- Modify: `test/fixtures/ocr_corpus/baseline.json`
- Modify: `docs/plans/ocr-corpus-design.md` (+ `.html`) — 부록 A 첫 채점
- Modify: `samples/README.md` — 카드 추가 절차

**Interfaces:**
- Consumes: Task 3의 게이트·`corpusReport`, Task 4의 덤프 결과.

**정답표는 아래 내용 그대로 쓴다.** 계획 단계에서 원본 사진(크롭 확대 포함)만 보고 썼고, OCR 출력은 아직 존재하지도 않았다. 사용자 검수에서 바뀐 칸만 고친다. **덤프 결과나 채점 결과를 보고 고치지 않는다**(Global Constraints).

정답표 검수 항목 — 판단이 갈린 칸:

| 카드 | 칸 | 정답 | 판단 |
|---|---|---|---|
| ethiopia_worka | name | `Ethiopia Worka` 또는 한글 부제 | 제목 아래 한글 줄이 더 긴 한글 제품명이라 함께 받음 |
| ethiopia_worka | roastLevel | 비움 또는 medium | `High Rost`(카드 오타) = 일본식 8단계 High — 앱 enum에 꼭 맞는 게 없음 |
| kwami_gesha_honey | roaster | 없음 | 산문의 `세웅지씨`는 생두 회사, `KWAMI`는 생두 브랜드 |
| sol_de_la_manana | name | 비움 또는 농장명 | 제품명 표기가 없음 |
| sol_de_la_manana | country | Bolivia | 산문(`볼리비아 커피를…`)에만 있음 — 비우면 missing |
| sol_de_la_manana | process | natural 또는 other | `Coco Natural`은 내추럴 변형 시그니처 가공 |
| sol_de_la_manana | cupNotes | 없음 | FLAVOR가 산문 — 묘사어를 뽑으면 wrong |
| bench_maji_gesha | region | 비움 또는 `벤치마지` | 지역 라벨 없음, 제목·산문에만 |
| tacet_guji_hambella | region | 두 줄 전체 | 첫 줄 `Oromia, West Guji`만 뽑으면 wrong |
| archers_sidama | region·process | 비움 허용 | 라벨이 전혀 없고 제품명 속에만 있음 |
| costa_rica_copey_52 · hwachae | process | anaerobic 또는 natural | `Anaerobic Natural`은 둘에 걸침(R5) |
| 여러 줄 제목 4장 | name | 이은 전체만 | 첫 줄만은 wrong — 잘린 값과 지어낸 값은 리포트의 실제값으로 구분 |
| 싱글 7장 | ratioPercent | 없음 | 카드에 100%가 없으니 채우면 wrong |

- [ ] **Step 1: 정답표 9장을 쓴다**

`test/fixtures/ocr_corpus/ocr_card_ko.truth.json`:

```json
{
  "id": "ocr_card_ko",
  "notes": "테스트용 콜론 카드(assets/test/ocr_card_ko.png). 모든 필드에 라벨이 있다.",
  "name": "예가체프 코체레",
  "roaster": "아우어사이드",
  "roastDate": "2026-07-10",
  "roastLevel": "lightMedium",
  "type": "single",
  "cupNotes": ["블루베리", "자스민", "홍차"],
  "components": [
    {"country": "Ethiopia", "region": "예가체프 코체레", "process": "washed", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/ocr_card_orig.truth.json`:

```json
{
  "id": "ocr_card_orig",
  "notes": "테스트용 2열 카드(assets/test/ocr_card_orig.png). 콜론 없음, 제목 위 이브로우가 로스터리.",
  "name": "콜롬비아 핑크버번 내추럴",
  "roaster": "베이스캠프 로스터스",
  "roastDate": "2026-07-05",
  "roastLevel": "medium",
  "type": "single",
  "cupNotes": ["딸기", "복숭아", "레드와인"],
  "components": [
    {"country": "Colombia", "region": "후일라", "process": "natural", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/ethiopia_worka.truth.json`:

```json
{
  "id": "ethiopia_worka",
  "notes": "한글 콜론 라벨 + 해시태그 컵노트. 로스터리 표기 없음. 제목 아래 한글 줄은 더 긴 한글 제품명이라 함께 받는다. `High Rost`(카드 오타)는 일본식 8단계의 High — 앱 enum에 꼭 맞는 게 없어 비우거나 medium을 받는다(R5). 지역은 한·영 병기(R2).",
  "name": ["Ethiopia Worka", "에티오피아 웨스트 알시 넨세보 워르카"],
  "roaster": null,
  "roastDate": null,
  "roastLevel": [null, "medium"],
  "type": "single",
  "cupNotes": ["요거트", "황도", "허니콤", "패션프루트"],
  "components": [
    {"country": "Ethiopia", "region": ["웨스트 알씨 West arsi", "웨스트 알씨", "West arsi"], "process": "natural", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/kwami_gesha_honey.truth.json`:

```json
{
  "id": "kwami_gesha_honey",
  "notes": "슬래시로 짝지은 라벨 줄(`생산지역 / 고도`, `품종 / 가공방식`) 아래 값 줄(`Benchi Maji / 1,830m - 2,000m`, `Gesha / Honey`). 컵노트는 라벨 없이 슬래시 구분. 로스터리 표기 없음 — 하단 산문의 `세웅지씨`는 생두 회사, `KWAMI`는 생두 브랜드다.",
  "name": "Ethiopia - KWAMI Gesha Honey",
  "roaster": null,
  "roastDate": null,
  "roastLevel": null,
  "type": "single",
  "cupNotes": ["자스민", "사과", "귤"],
  "components": [
    {"country": "Ethiopia", "region": "Benchi Maji", "process": "honey", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/sol_de_la_manana.truth.json`:

```json
{
  "id": "sol_de_la_manana",
  "notes": "영문 대문자 불릿 라벨 + 한글 산문. 제품명 표기가 없어 농장명(`NAME OF FARM`)을 받되 비워도 정답. 국가는 산문(`볼리비아 커피를…`)에만 있다. `Coco Natural`은 내추럴 변형 시그니처 가공이라 natural·other 둘 다 받는다(R5). FLAVOR는 산문이라 컵노트 목록이 없다(R7) — 산문에서 묘사어를 뽑으면 wrong.",
  "name": [null, "Sol de La Mañana"],
  "roaster": null,
  "roastDate": null,
  "roastLevel": null,
  "type": "single",
  "cupNotes": [],
  "components": [
    {"country": "Bolivia", "region": "Caranavi", "process": ["natural", "other"], "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/bench_maji_gesha.truth.json`:

```json
{
  "id": "bench_maji_gesha",
  "notes": "주황 띠 위 흰 글씨 2줄 제목 + 주황 산문 + 콜론 없는 2열 격자 두 벌. 컵노트는 두 줄에 걸친다. 지역 라벨이 없고 지역은 제목·산문에만 있다(R3). 로스터리 표기 없음(QR만). 산문의 `2019년`·`1,000헥타르`는 날짜가 아니다.",
  "name": "에티오피아 벤치마지 게샤",
  "roaster": null,
  "roastDate": null,
  "roastLevel": "light",
  "type": "single",
  "cupNotes": ["오렌지블라썸", "자스민", "살구", "베르가못", "녹차"],
  "components": [
    {"country": "Ethiopia", "region": [null, "벤치마지"], "process": "washed", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/tacet_guji_hambella.truth.json`:

```json
{
  "id": "tacet_guji_hambella",
  "notes": "인라인 라벨(고도·품종·가공) + 라벨 옆 세로 2줄 값(지역) + 라벨 아래 값(Cup Note·Roast Point) 혼합, 2열. 한글 제목의 `에디오피아`는 카드 오타(R1). 지역은 두 줄을 이은 전체만 정답 — 첫 줄만은 wrong. 로스터리는 하단 푸터.",
  "name": ["에디오피아 구지 함벨라 단세 세이사", "Ethiopia Guji Hambella Danse Saysa"],
  "roaster": "Tacet Coffee Roasters",
  "roastDate": null,
  "roastLevel": "light",
  "type": "single",
  "cupNotes": ["베르가못", "자두", "블루베리", "살구"],
  "components": [
    {"country": "Ethiopia", "region": "Oromia, West Guji Hambella Wamena, Danse Saysa", "process": "natural", "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/archers_sidama.truth.json`:

```json
{
  "id": "archers_sidama",
  "notes": "라벨이 전혀 없는 삼각 카드, 야외에서 손에 들고 찍음(배경에 바닥 타일·원통). 제품명이 한·영 각 2줄. 지역·가공은 제품명 속에만 있다(R3) — 비워도 정답. `74158`은 품종 번호로 날짜가 아니다.",
  "name": ["에티오피아 시다마 벤사 하마쇼 코코세 74158 내추럴", "Ethiopia Sidama Bensa Hamasho Kokose 74158 Natural"],
  "roaster": "ARCHERS",
  "roastDate": null,
  "roastLevel": null,
  "type": "single",
  "cupNotes": [],
  "components": [
    {"country": "Ethiopia", "region": [null, "Sidama Bensa Hamasho", "시다마 벤사 하마쇼", "Sidama", "시다마"], "process": [null, "natural"], "ratioPercent": null}
  ]
}
```

`test/fixtures/ocr_corpus/costa_rica_copey_52.truth.json`:

```json
{
  "id": "costa_rica_copey_52",
  "notes": "영문 3줄 굵은 제목 + 한글 2줄. 한 줄에 콜론 쌍 두 개(`농장: … 고도: …`, `로트: … 품종: …`). 컵노트는 라벨 없이 마침표 구분. 로스터리 표기 없음. 산문의 `120시간`·`19일간`은 날짜가 아니다. `Anaerobic Natural`은 둘에 걸친다(R5).",
  "name": ["Costa Rica Hacienda Copey Don Kazu Red Catuai Anaerobic Natural #52", "코스타 리카 하시엔다 코페이 돈 카주 레드 카투아이 무산소 내추럴 #52"],
  "roaster": null,
  "roastDate": null,
  "roastLevel": null,
  "type": "single",
  "cupNotes": ["럼 레이즌", "포도 사탕", "자두", "카카오닙스"],
  "components": [
    {"country": "Costa Rica", "region": "Copey, Dota", "process": ["anaerobic", "natural"], "ratioPercent": null}
  ]
}
```

- [ ] **Step 2: 덤프한 픽스처를 옮긴다**

```bash
cp build/ocr_corpus/*.ocr.json test/fixtures/ocr_corpus/
ls test/fixtures/ocr_corpus/
```

Expected: `.ocr.json` 11개, `.truth.json` 11개, `baseline.json`, `sources.json`.

- [ ] **Step 3: 게이트가 새 카드를 변화로 잡는지 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: FAIL — 바뀐 칸 목록이 전부 `<새 카드 id>  <칸>  (없음) → …` 형태이고, `red_cascara`·`hwachae` 줄은 하나도 없다. 기존 두 카드 줄이 섞여 있으면 멈추고 보고한다.

- [ ] **Step 4: 베이스라인을 갱신하고 리포트를 받아 둔다**

Run: `flutter test --dart-define=UPDATE_OCR_BASELINE=true --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: PASS. 출력된 리포트 전체를 보고서에 붙인다(Step 8에서 문서로 옮긴다).

- [ ] **Step 5: 게이트를 다시 돌려 통과를 확인한다**

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: 게이트가 파서 변화를 실제로 잡는지 변이로 확인한다**

`lib/features/beans/ocr/ocr_candidate.dart`의 `buildOcrCandidate`에서 `draft: parseOcr(lines),`를 `draft: parseOcr(lines.skip(1).toList()),`로 바꾸고(OCR 첫 줄을 버리는 변이) 게이트를 돌린다.

Run: `flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart`
Expected: FAIL, 바뀐 칸이 여러 카드에 걸쳐 나온다. 출력 앞 다섯 줄을 보고서에 적는다.

되돌리고 확인한다:

```bash
git checkout -- lib/features/beans/ocr/ocr_candidate.dart
git diff --stat main -- lib/
flutter test --concurrency=1 -r expanded test/unit/ocr_corpus_test.dart
```

Expected: `git diff`는 아무것도 출력하지 않고, 게이트는 PASS.

- [ ] **Step 7: 비회귀 — 전체 테스트와 analyze**

Run: `flutter test --concurrency=1 -r expanded` 그리고 `flutter analyze`
Expected: 전부 통과, `No issues found!`

- [ ] **Step 8: 첫 리포트를 설계 문서에 남기고 카드 추가 절차를 쓴다**

`docs/plans/ocr-corpus-design.md` 맨 끝에 `## 부록 A — 첫 채점 (<실행 날짜>, Android 에뮬레이터 ML Kit)` 절을 추가한다. 순서:

1. Step 4 리포트 전문을 코드 펜스(```)로 감싸 그대로 붙인다.
2. 그 아래 `관찰:`과 세 줄을 쓴다. 리포트에 있는 숫자로만 쓴다 — 리포트에 없는 말은 쓰지 않는다.
    - **파서 대 OCR** — 문자열 칸의 빈칸·틀림 중 파서 N칸, OCR M칸. 어느 쪽이 큰지 한 문장.
    - **`region` 오채움** — `.region` 칸 중 wrong이 몇 칸이고 어느 카드인지.
    - **가장 많이 빈 필드** — 필드 이름과 칸 수. `type` 칸이 싱글 카드에서 missing으로 몰리는지, 설계 §4.3의 계획 단계 측정과 맞는지 한 문장.

`samples/README.md`의 `## 원본을 잃어버리면` 앞에 아래 절을 추가한다. README 안의 명령은 4칸 들여쓰기 코드 블록으로 쓴다 — 이 계획서를 렌더하는 `md2html.py`가 펜스 중첩에서 멈추기 때문이다(GitHub은 들여쓰기 블록을 그대로 코드로 보여준다).

```markdown
## 카드를 추가하는 법

**파서를 고치기 전에** 새 카드부터 넣는다 — 그래야 그 카드가 파서가 본 적 없는 시험지가 된다(설계 §5).

1. 사진을 `cards/`에 넣고 `test/fixtures/ocr_corpus/sources.json`에 `"<id>": "samples/cards/<파일명>"` 한 줄을 더한다.
2. **정답표부터 쓴다** — `test/fixtures/ocr_corpus/<id>.truth.json`. 사진만 보고 쓴다(규칙: 설계 §4.2 R1–R8). OCR 결과를 보고 쓰면 채점판이 눈이 먼다.
3. 에뮬레이터를 띄우고(`flutter emulators --launch flutter_emulator`) 아래 덤프 명령을 돌린다.
4. `build/ocr_corpus/<id>.ocr.json`을 `test/fixtures/ocr_corpus/`로 옮긴다. 덤프는 목록 전체를 다시 뽑으므로, 이미 있는 카드 파일은 diff를 보고 판단한다.
5. 아래 갱신 명령으로 베이스라인을 다시 쓰고 `baseline.json` diff를 함께 커밋한다.

덤프:

    flutter drive --driver=test_driver/ocr_corpus_driver.dart --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554

베이스라인 갱신:

    flutter test --dart-define=UPDATE_OCR_BASELINE=true test/unit/ocr_corpus_test.dart
```

렌더한다:

```bash
python scripts/md2html.py docs/plans/ocr-corpus-design.md
```

- [ ] **Step 9: 커밋**

```bash
git add test/fixtures/ocr_corpus/ocr_card_ko.ocr.json test/fixtures/ocr_corpus/ocr_card_ko.truth.json test/fixtures/ocr_corpus/ocr_card_orig.ocr.json test/fixtures/ocr_corpus/ocr_card_orig.truth.json test/fixtures/ocr_corpus/ethiopia_worka.ocr.json test/fixtures/ocr_corpus/ethiopia_worka.truth.json test/fixtures/ocr_corpus/kwami_gesha_honey.ocr.json test/fixtures/ocr_corpus/kwami_gesha_honey.truth.json test/fixtures/ocr_corpus/sol_de_la_manana.ocr.json test/fixtures/ocr_corpus/sol_de_la_manana.truth.json test/fixtures/ocr_corpus/bench_maji_gesha.ocr.json test/fixtures/ocr_corpus/bench_maji_gesha.truth.json test/fixtures/ocr_corpus/tacet_guji_hambella.ocr.json test/fixtures/ocr_corpus/tacet_guji_hambella.truth.json test/fixtures/ocr_corpus/archers_sidama.ocr.json test/fixtures/ocr_corpus/archers_sidama.truth.json test/fixtures/ocr_corpus/costa_rica_copey_52.ocr.json test/fixtures/ocr_corpus/costa_rica_copey_52.truth.json test/fixtures/ocr_corpus/baseline.json docs/plans/ocr-corpus-design.md docs/plans/ocr-corpus-design.html samples/README.md
git status --short
```

Expected: `samples/cards/` 사진이 스테이징 목록에 없다.

```bash
git commit -m "test(ocr): score nine more cards and record the first report

Seven real cards in seven different layouts plus the two rendered test
cards join the corpus. Truth tables were written from the photos
before any OCR output existed. The first report goes into the design
doc, and samples/README now says to add a failing card to the corpus
before fixing the parser for it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RSnfDi7WDeKq9sg1LWJLec"
```
