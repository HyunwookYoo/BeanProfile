# ☕ BeanProfile — OCR 카드 코퍼스 & 채점판 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-08-12 |
| 상태 | 설계 승인(브레인스토밍 2026-08-12) → 구현 계획 작성(2026-10-03, [`ocr-corpus-plan.md`](./ocr-corpus-plan.md)) |
| 선행 | 인라인 블렌드 행 카드 `v1.0.2` ([design](./ocr-inline-blend-card-design.md)) |
| 상위 문서 | [`design.md`](../design.md) · [`testing.md`](../testing.md) |
| 계기 | 사용자 제안 — "샘플 카드 20장을 주면 general한 판별 로직을 만들 수 있나" |
| 영향 범위 | **테스트 인프라 전용.** 파서·UI·스키마 무수정 |
| 코퍼스 규모 | **시작 11장** (사용자 7장 + 기존 4장, 2026-10-03 결정) — 이후 카드 단위로 추가 |

---

## 1. 문제 — 카드 한 장씩 고치는 방식이 한계에 왔다

`v0.6.1`~`v0.6.12`, 한/영 병기 블렌드, 인라인 블렌드 행. OCR 파서의 모든 변경이 **실카드 한 장**에서 출발했고, `CLAUDE.md`는 그 교훈을 이렇게 적어두었다:

> OCR은 계획 단위가 아니라 카드 한 장씩 고쳐지고, 그 사이클엔 설계 문서보다 진단 도구가 값지다.

이 방식이 실제로 작동했다. 문제는 **비용이 누적된다**는 것이다. 같은 실패가 두 번 기록돼 있다:

> 수정 라운드에서 추가한 더 넓은 가드가 먼저 발동해 앞서 만든 판별 테스트가 조용히 판별력을 잃는다

디개싱 마이그레이션에서 한 번, 한/영 병기 브랜치에서 한 번. 두 번 다 가드를 지워도 스위트가 초록이었고, **뮤테이션 프로브를 17개·14개씩 손으로 돌려서야** 드러났다.

구조적 원인은 명확하다. 지금 OCR 테스트는 4,576줄이지만 전부 **손으로 고른 단언**이다. 카드 하나에서 필드 몇 개만 본다. **"이 카드 전체가 몇 점인가"를 묻는 테스트가 하나도 없다.**

그래서 매 브랜치가 같은 자리에서 같은 값을 치른다: 카드 N을 고치고, 카드 N-1이 안 깨졌는지는 사람이 리뷰로 확인한다.

## 2. "20장 학습"의 세 가지 해석

### 2.1 ML 모델 학습 — 기각

20장은 학습 데이터가 아니다. 필드별로 쪼개면 "로스터리 예시 20개"이고, 이걸로 학습되는 건 없다. 게다가 이 프로젝트는 M4에서 `fl_chart` 하나도 iOS CI 리스크 때문에 넣지 않고 `CustomPainter`로 갔던 곳이다. 온디바이스 모델 런타임은 그보다 훨씬 무거운 결정이다.

### 2.2 20장을 보고 규칙을 쓴다 — 기각

지금까지의 방식을 **배치 크기만 20배로 키운 것**이다. 기제가 바뀌지 않으므로 결과도 바뀌지 않는다. 오히려 더 위험하다 — 한 번에 20장어치 규칙이 들어오는데 그걸 검증할 장치는 §1의 그 테스트들이다.

측정 없이 세운 가설의 수명은 이미 실측돼 있다. 한/영 병기 브랜치가 세운 문자열-필터 가설(`%`·숫자 과반 거부)은 다음 브랜치에서 **틀린 층을 겨냥한 것**으로 판명났다. 문제는 문자열이 아니라 공간 층이었다.

### 2.3 20장을 채점판으로 만든다 — 채택

파서는 한 줄도 고치지 않는다. 산출물은 **"지금 파서가 N장에서 몇 점인가"를 매번 자동으로 재는 장치**다.

두 가지가 즉시 따라온다.

**(a) §1의 실패 모드가 자동으로 보인다.** 카드 12를 고치다 카드 5를 깨면 그 자리에서 빨개진다. 뮤테이션 프로브를 손으로 돌릴 필요가 없다.

**(b) "틀린 값보다 빈 칸"이 슬로건에서 숫자가 된다.** 지금 `compareOcrCandidates`의 `filledFieldCount`는 **채우는 걸 보상한다.** 원칙과 정반대다. `CLAUDE.md`에 미해결로 적힌 그대로다:

> 성분 `region`에 `bio control 70940%`·`GI -`가 들어가고, 이게 `filledFieldCount`를 부풀려 `compareOcrCandidates` 타이브레이커를 뒤집을 수 있음

채점판은 이걸 논쟁이 아니라 측정으로 만든다.

## 3. 확정 결정 (브레인스토밍 2026-08-12)

| # | 결정 | 근거 |
|---|---|---|
| 1 | **파서 무수정** | 채점판이 자기가 유도한 수정을 채점하면 기준선이 사라진다 |
| 2 | **칸 단위 베이스라인** (총점 아님) | 총점이면 "한 칸 고치고 한 칸 깨서 동점"이 통과한다 |
| 3 | 채점 대상은 **파이프라인 전체** (`parseOcr` 아님) | 알려진 타이브레이커 결함이 `selectOcrCandidates` 단계에 있다 |
| 4 | 정답표는 **사진에서만** 온다 (OCR 덤프 참조 금지) | 파서 문제와 OCR 문제가 공짜로 분리된다 (§4.2) |
| 5 | 코퍼스 구성 = 실패 + 성공 혼합 | 실패만 있으면 회귀를 못 잡는다 |
| 6 | 원본 사진은 `samples/cards/` (gitignore), **픽스처만 커밋** | 저장소가 공개여야 한다(macOS 러너) |
| 7 | 일반화(파서 정리)는 **다음 스펙** | 코퍼스 점수를 보기 전에는 모양을 정할 수 없다 |
| 8 | **11장으로 시작**, 장수 고정 안 함 (2026-10-03) | 인프라 비용은 장수와 무관하다. 카드 추가 = 사진 + 덤프 1회 + 정답표 1장. 대량 라벨링 전에 인프라 결함을 잡는 편이 싸다 |

## 4. 설계

```
samples/cards/*.jpg                         (gitignore, 원본)
        │  ① 카드당 1회, Android 에뮬레이터
        ▼
test/fixtures/ocr_corpus/<id>.ocr.json      ← ML Kit 출력 (커밋)
test/fixtures/ocr_corpus/<id>.truth.json    ← 사람이 쓴 정답 (커밋)
test/fixtures/ocr_corpus/baseline.json      ← 현재 판정표 (커밋)
        │  ② 매 테스트, 기기 없이 호스트에서
        ▼
test/unit/ocr_corpus_test.dart              ← 채점 + 회귀 게이트
```

①은 카드당 한 번뿐이다. 그 뒤로는 전부 Windows·CI에서 돈다.

### 4.1 픽스처 — 무엇을 기록하나

`DefaultOcrPipeline.analyze`는 **ML Kit을 최대 두 번** 돈다. 원본을 읽고, `quality.lowContrast || isWeakOcr(original)`이면 보정본을 다시 읽어 `selectOcrCandidates`로 고른다. 결정 3에 따라 채점 대상이 파이프라인 전체이므로, 호스트에서 **어느 분기든 재현**되도록 양쪽을 다 기록한다.

```json
{
  "id": "ethiopia_worka",
  "source": "samples/cards/KakaoTalk_20260825_232315388.jpg",
  "quality": ["blurry"],
  "original": [
    {"text": "Ethiopia Worka", "l": 812.0, "t": 640.0, "r": 2870.0, "b": 830.0, "conf": 0.95}
  ],
  "enhanced": [ … ]
}
```

`quality`는 `ImageQualityIssue` 이름 목록이고 `null`이면 기록이 없다는 뜻이다(빈 보고서로 재생). `enhanced`가 `null`이면 보정 패스가 없거나 실패한 것으로 재생한다 — 기기에서 보정이 실패했을 때 파이프라인이 원본만으로 고르는 것과 같은 경로다. 줄 순서는 ML Kit이 준 그대로다. 파서에 순서 의존 경로가 있으므로 재정렬하지 않는다.

주입은 기존 seam 세 개를 그대로 쓴다 — `OcrService` · `ImageQualityAnalyzer` · `OcrImagePreprocessor`. **새 추상화를 만들지 않는다.**

덤프는 분기 조건과 무관하게 항상 양쪽을 계산한다. 조건부로 기록하면 나중에 파서가 분기를 바꿨을 때 픽스처를 다시 뽑아야 한다.

### 4.2 정답표 — 사진에서만 온다

정답은 **카드에 인쇄된 것**이다. OCR이 무엇을 읽었는지는 참조하지 않는다.

이 규칙이 없으면 흔한 골든 파일 함정에 빠진다 — 파서 출력을 정답으로 삼으면 채점판이 첫날 100점으로 시작하고 아무것도 측정하지 않는다. §1이 기록한 "테스트가 눈이 먼" 상태를 코퍼스 규모로 재현하는 것이다.

**부수효과가 이 설계에서 제일 큰 수확이다.** 정답이 이미지에서 오면 채점판이 두 실패를 자동으로 구분한다:

| 관찰 | 뜻 |
|---|---|
| OCR 줄에 값이 있는데 판정이 missing/wrong | **파서 문제** — 고칠 수 있다 |
| OCR 줄에 값이 아예 없는데 판정이 missing | **OCR 문제** — 파서를 고쳐도 못 닿는다 |

지금 이 비율을 아무도 모른다. 지난 브랜치들은 전부 파서라고 가정하고 시작했고, 한/영 병기 건은 실제로 맞았다("병목은 전부 파서였다"). 그게 매번 맞으리란 근거는 없다.

정답표는 사진을 읽어 초안을 만들고 사용자가 검수한다. 판단이 갈리는 칸(지역인지 농장인지, 비율이 없는 건지 못 읽은 건지)만 목록으로 올린다.

**구분은 문자열 칸(제품명·로스터리·지역·컵노트)에 한한다.** 정답 값의 단어가 전부 OCR 텍스트(원본+보정본)에 있으면 파서 문제, 하나라도 없으면 OCR 문제로 센다. 줄 단위가 아니라 단어 단위로 보는 건 ML Kit이 한 값을 두 줄로 쪼개거나 순서를 바꿔 내기 때문이다. 열거형·국가·날짜·비율은 카드 표기와 앱 표기가 달라(`에티오피아` ↔ `Ethiopia`, `내추럴` ↔ `natural`) 구분하지 않는다. 근사치다 — 짧은 단어가 엉뚱한 줄에 우연히 있으면 파서 문제로 잘못 센다.

정답표 작성 규칙:

| # | 규칙 |
|---|---|
| R1 | 값은 카드에 인쇄된 그대로 — 카드 자체의 오타도 그대로(`High Rost`, `에디오피아`). 라벨은 뺀다. 여러 줄에 걸친 값은 공백 하나로 잇는다 |
| R2 | 같은 값이 두 언어로 병기되면 각 언어판 단독도 정답으로 받는다 |
| R3 | 라벨 없이 제목·산문에만 있는 값은 비워도 정답이다(목록에 `null`) |
| R4 | 카드에 없는 필드는 `null` — 무엇을 채우든 wrong |
| R5 | 가공·로스팅은 앱 enum으로 옮긴다. 둘에 걸치면 둘 다 받는다(`Anaerobic Natural` → anaerobic·natural). 대응하는 게 없으면 비워도 정답 |
| R6 | 국가는 앱 표준 영문명(`Ethiopia`, `Costa Rica`) |
| R7 | 컵노트는 목록으로 인쇄된 것만. 산문 속 묘사어는 넣지 않는다. `#`은 뗀다 |
| R8 | 유형은 카드가 실제로 싱글인지 블렌드인지(`single`/`blend`) |

### 4.3 채점 — 세 갈래 판정

칸마다 correct / **wrong** / missing 중 하나다.

| 정답 | 실제 | 판정 |
|---|---|---|
| 값 있음 | 같음 | correct |
| 값 있음 | null | missing |
| 값 있음 | 다름 | **wrong** |
| **없음** | null | correct |
| **없음** | 값 있음 | **wrong** |

마지막 줄이 요점이다. "정답이 없는데 뭔가 채웠다" — §2.3(b)의 `region` 결함이 정확히 이 모양이고, 지금 어떤 테스트도 이 형태를 재지 않는다.

**문자열 비교**는 공백 제거 + 소문자화 후 일치로 본다. 기존 테스트가 `contains('베이스캠프')`로 허용하던 자간 오독(`베이스캠프 로스 터스` vs `베이스캠프 로스터스`)이 이 정규화만으로 흡수되므로 별도 문법을 두지 않는다.

**성분 리스트**는 index로 비교한다. 카드에 적힌 순서가 자연 순서이고 파서도 그 순서를 유지한다. 국가로 짝지어 비교하는 대안은 기각했다 — 국가 자체가 채점 대상이라 순환이고, 순서가 흐트러지면 비율도 함께 어긋붙는 게 보통이라 순서는 지킬 값어치가 있다. 다만 **내용이 맞는데 순서만 뒤집힌 경우 실제보다 크게 실점한다**는 걸 감수한다. 결함을 과소보고하는 것보다 낫다.

개수가 다르면 §4.3 표를 그대로 따른다. 정답 3개·실제 1개면 index 1·2의 모든 칸이 missing. 정답 3개·실제 5개면 index 3·4는 정답이 없는 칸이므로, 값이 들어 있으면 wrong(지어냄)이고 비어 있으면 correct다.

**`typeDecision`은 `ambiguous`를 빈칸으로 센다.** 앱은 `ambiguous`일 때 사용자에게 유형을 묻는다 — 모르면 묻는 것이 이 앱의 빈칸이다. 그래서 정답 `single`에 `ambiguous`는 missing, `certainBlend`는 wrong이다. 채점 대상에 넣는 이유는 지난 브랜치가 실제로 `100% Ethiopia` 제목에서 타입을 블렌드로 반전시킨 적이 있기 때문이다. (계획 단계 측정: 콜론 라벨만 있는 싱글 카드는 `ambiguous`가 나온다 — 싱글 카드의 유형 칸은 대부분 missing으로 시작할 것이다.)

**정답은 값 하나가 아니라 목록일 수 있다.** R2·R3·R5의 경우다. 정답표는 `["값1", "값2", null]`처럼 받아줄 값을 나열하고, `null`이 있으면 비워도 correct다. 판정 규칙은 위 표 그대로다 — 비었으면 `null`이 목록에 있는지, 채웠으면 그 값이 목록에 있는지만 본다. 퍼지 매칭 대신 받아줄 값을 데이터로 적는 이유는, 판단이 갈리는 칸의 결정을 코드가 아니라 **사람이 검수하는 정답표**에 남기기 위해서다. 부분값은 받지 않는다 — 여러 줄 제목의 첫 줄만 뽑으면 wrong이다(지어낸 값과 잘린 값은 리포트의 실제값으로 구분한다).

**컵노트**는 순서가 의미 없으므로 집합으로 비교하되, **노트 하나가 한 칸**이다. 정답에만 있으면 missing, 실제에만 있으면 wrong. 지난 브랜치들이 겪은 "날짜/구조화 값이 컵노트를 오염시킨다", "푸터 열을 통째로 흡수한다"가 정확히 wrong으로 잡힌다.

**`chips`는 채점하지 않는다.** 배정 대기 목록이라 정답을 정의할 수 없다. 자동채움에 실패해 칩으로만 남으면 해당 필드가 missing으로 잡히므로, 실패 자체는 이미 반영된다.

**스칼라 점수를 만들지 않는다.** 세 개수를 그대로 보고한다. 가중 합은 최적화 대상이 되면 게이밍당하고, wrong 1건과 missing 3건 중 뭐가 나쁜지는 이 프로젝트에서 이미 답이 나와 있다.

### 4.4 회귀 게이트 — 칸 단위 베이스라인

`baseline.json`은 `card × field → 판정`이다. 틀린 칸은 실제값도 함께 남긴다(진단용).

테스트는 재계산해 베이스라인과 비교하고, 다르면 **바뀐 칸만** 표로 찍고 실패한다:

```
HWACHAE      component[1].region   correct → wrong    ("Designed for")
RED_CASCARA  cupNotes[자스민]       correct → missing
```

총점 비교였다면 위 두 줄이 상쇄돼 통과한다. 칸 단위여야 §1의 실패가 눈에 보인다.

베이스라인 갱신은 명시적 커밋이라, 좋아진 것도 나빠진 것도 diff에 남고 전체-브랜치 리뷰가 읽을 수 있다.

### 4.5 채점기 자신의 테스트

채점 로직은 순수 함수로 분리하고(`test/support/ocr_score.dart`) 자체 단위 테스트를 붙인다.

형식적 절차가 아니다. 채점기가 조용히 고장나면 — 예컨대 "정답 없음 + 실제 값 있음"을 correct로 세면 — 리포트가 그럴듯한 숫자를 내면서 아무것도 측정하지 않는다. **이 프로젝트가 두 번 만난 실패 모드가 정확히 그것**이다. §4.3 표의 다섯 분기를 각각 고정한다.

### 4.6 덤프 도구

`flutter drive` 한 번으로 돈다 — 호스트 드라이버와 기기 테스트 한 쌍.

1. 드라이버(`test_driver/ocr_corpus_driver.dart`)가 `test/fixtures/ocr_corpus/sources.json`(코퍼스 id → 원본 경로)에 적힌 사진을 루프백 HTTP로 서빙한다. 포트 8765, 에뮬레이터에서 보면 `10.0.2.2:8765`.
2. 기기 테스트(`integration_test/ocr_corpus_dump_test.dart`)가 카드마다 사진을 받아 quality → ML Kit(원본) → enhance → ML Kit(보정본)을 돌리고 결과를 `reportData`로 돌려준다. 스크린샷 드라이버(`test_driver/screenshot_driver.dart`)가 쓰는 것과 같은 채널이다.
3. 드라이버가 결과를 `build/ocr_corpus/<id>.ocr.json`에 쓴다. **커밋된 픽스처를 직접 덮어쓰지 않는다** — 재덤프 결과는 사람이 diff를 보고 `test/fixtures/ocr_corpus/`로 옮긴다.

기각한 입력 경로 두 가지:

- **adb push** — 앱 설치가 `flutter drive` 안에서 일어나므로, 실행 전에 앱 전용 폴더에 밀어 넣을 수 없다. 공용 저장소는 Android 11+에서 런타임 권한이 필요하다.
- **assets 번들** — `pubspec.yaml`의 `assets:`는 릴리스 앱에 실린다. 게다가 gitignore된 폴더를 선언하면 그 폴더가 없는 CI 빌드가 실패한다.

평문 HTTP는 막히지 않는다. Dart SDK 3.x의 `dart:io`에는 Android 평문 정책 검사가 없다(SDK `embedder_config.dart`에 `_mayExit`만 남아 있음, 2026-10-03 확인).

기존 `ocr_probe_test.dart`는 그대로 둔다. 두 카드에 대한 회귀 가드로 여전히 유효하고, 코퍼스와 목적이 다르다(하나는 실 ML Kit 연결 확인, 하나는 파서 채점).

## 5. 기대 결과

첫 실행에서 나올 숫자:

- **코퍼스 11장** — 사용자 제공 7장 + 기존 4장. 기존분은 `ocr_card_ko.png`·`ocr_card_orig.png`(이미지 있음, 덤프 파이프라인 태움)와 `redCascaraLines`(18줄)·`hwachaeLines`(13줄)(`test/helpers.dart`의 실측 좌표를 JSON으로 이관). 후자 둘은 원본 사진이 없으므로 **정답표를 좌표에서 복원해야 하고**, 그 두 장에 한해 §4.2의 "사진에서만" 규칙이 성립하지 않는다. 카드 전체인지 발췌인지도 이관 시 확인이 필요하다.
- **사용자 7장은 서식이 전부 다르다** — 한글 콜론 라벨 + 해시태그 컵노트 / 슬래시로 짝지은 라벨 줄 아래 값 줄 / 영문 대문자 불릿 라벨 + 산문 FLAVOR / 콜론 없는 2열 격자 두 벌 / 인라인·세로 2줄 값·라벨 아래 값 혼합 / 라벨 없는 삼각 카드(야외, 손에 듦) / 한 줄에 콜론 쌍 2개 + 마침표 구분 무라벨 컵노트. 전부 iPhone 14 Pro 원본(4032×3024, EXIF orientation 6).
- **커버리지 공백 두 곳.** (a) 사용자 7장이 전부 싱글 오리진이라 블렌드는 RED CASCARA·HWACHAE 2장뿐이다 — 최근 파서 복잡도 대부분이 블렌드 쪽이므로 블렌드 카드가 생기면 1순위로 추가한다. (b) 로스팅 날짜가 인쇄된 카드가 없다. 대신 날짜처럼 보이는 함정(`1990년대`·`2019년에`·`1,945~ 2,150m`·`74158`·`19일간`)이 많아 "정답 null + 값을 채움 = wrong" 방향은 잘 시험된다.
- **과적합 대책.** 일반화 단계에서 11장에 맞춰 고칠 위험이 있다. 실사용에서 새 카드를 만나면 **고치기 전에** 코퍼스에 먼저 넣는다 — 그 카드가 파서가 본 적 없는 시험지가 된다.
- **픽스처는 Android ML Kit 출력이다.** 사용자 앱은 iOS다. 두 ML Kit은 같은 사진에서도 줄 나눔·좌표가 다를 수 있다(`v0.6.x`에서 iOS 좌표 편차로 2열 블렌드 카드가 깨진 전례). 맥이 없어 iOS 대량 덤프는 불가능하므로, 코퍼스 점수는 **"Android ML Kit 기준 파서 점수"**로 읽는다. 특정 카드의 iOS 출력이 필요하면 진단 클립보드(AltStore 빌드)로 한 장씩 받는다.
- **파서 문제 대 OCR 문제의 비율** — §4.2. 이 프로젝트가 한 번도 측정한 적 없는 숫자다.
- **`region` 결함의 실제 크기** — 지금은 두 사례만 알려져 있다. wrong으로 몇 칸인지 나온다.

## 6. 파일 영향

| 파일 | 변경 |
|---|---|
| `samples/README.md` | 신규 (커밋) |
| `samples/cards/` | 신규 (gitignore) |
| `.gitignore` | `samples/cards/` 추가 |
| `test/fixtures/ocr_corpus/*.json` | 신규 — 픽스처·정답표·베이스라인·`sources.json` |
| `test/support/ocr_score.dart` | 신규 — 정답표 모델 + 순수 채점 함수 |
| `test/support/ocr_corpus.dart` | 신규 — 픽스처 모델·파이프라인 재생·베이스라인·리포트 |
| `test/unit/ocr_score_test.dart` | 신규 — 채점기 자체 테스트 |
| `test/unit/ocr_corpus_support_test.dart` | 신규 — 재생·베이스라인·리포트 테스트 |
| `test/unit/ocr_corpus_test.dart` | 신규 — 채점 + 회귀 게이트 |
| `integration_test/ocr_corpus_dump_test.dart` | 신규 — 좌표 덤프 (기기 전용) |
| `test_driver/ocr_corpus_driver.dart` | 신규 — 사진 서빙 + 덤프 회수 (호스트) |

**앱 코드(`lib/`) 변경 없음.** 채점 로직을 `test/`에 두므로 앱 크기에도 영향이 없다.

## 7. 테스트 전략 (`docs/testing.md` 3계층)

- **단위** — `ocr_score_test.dart`: §4.3의 다섯 판정 분기 각각. 성분 개수 불일치(부족/초과). 컵노트 집합 차이 양방향. 문자열 정규화(자간 오독 흡수, 다른 값은 흡수하지 않음).
- **단위** — `ocr_corpus_test.dart`: 픽스처 전량을 파이프라인에 태워 베이스라인과 대조. 픽스처/정답표 짝이 맞는지(고아 파일 없음).
- **통합(기기)** — `ocr_corpus_dump_test.dart`: 수동 실행. CI에 넣지 않는다(에뮬레이터가 필요하고 카드당 1회면 충분).
- **비회귀** — 기존 377 tests 그대로 green. 이번 작업은 `lib/`을 건드리지 않으므로 하나도 바뀌면 안 된다.

## 8. 스코프 밖

- **파서 수정 일체.** 채점판이 무엇을 가리키든 이번 브랜치에서는 고치지 않는다(결정 1).
- **일반화 설계.** 다음 스펙(결정 7).
- **기존 OCR 테스트 정리.** 코퍼스와 중복되는 단언이 생기겠지만 그대로 둔다. 지우는 판단은 코퍼스가 실제로 그 역할을 하는 걸 확인한 뒤에 한다.
- **CI 통합.** 채점 테스트는 `flutter test`에 포함되므로 자동으로 돈다. 별도 워크플로를 만들지 않는다.
- **정답표 작성 도구.** 11장은 손으로 쓸 수 있는 규모다. 도구를 만들 근거가 아직 없다.

## 9. 완료 기준 (DoD)

1. `samples/README.md`·`.gitignore` 커밋, `samples/cards/`에 원본 7장 (로컬)
2. `test/fixtures/ocr_corpus/`에 픽스처 11장 커밋
3. 정답표 11장 커밋 — **사용자 검수 완료**
4. `flutter test test/unit/ocr_score_test.dart` green — 다섯 분기 각각이 자기 테스트만 빨갛게 만드는 걸 변이로 확인
5. `flutter test test/unit/ocr_corpus_test.dart`가 현재 점수를 리포트하고 베이스라인을 고정
6. 첫 점수 리포트가 문서에 기록됨 — 파서 문제 대 OCR 문제 비율 포함
7. 기존 377 tests 그대로 green, `flutter analyze` 0

## 부록 A — 첫 채점 (2026-10-04, Android 에뮬레이터 ML Kit)

베이스라인을 처음 쓸 때(`--dart-define=UPDATE_OCR_BASELINE=true`) 출력된 리포트 전문이다. 채점 대상은 `main`(`2ef2f36`)의 파서 그대로다 — 이 브랜치는 `lib/`을 건드리지 않았다.

```
OCR 코퍼스 채점 — 11장, 칸 155개

카드별
  archers_sidama  정답 5 (채움 2 / 비움 3)  빈칸 2  틀림 5
  bench_maji_gesha  정답 9 (채움 5 / 비움 4)  빈칸 4  틀림 2
  costa_rica_copey_52  정답 7 (채움 3 / 비움 4)  빈칸 5  틀림 1
  ethiopia_worka  정답 7 (채움 3 / 비움 4)  빈칸 5  틀림 1
  hwachae  정답 10 (채움 7 / 비움 3)  빈칸 9  틀림 2
  kwami_gesha_honey  정답 6 (채움 2 / 비움 4)  빈칸 6  틀림 0
  ocr_card_ko  정답 11 (채움 10 / 비움 1)  빈칸 1  틀림 0
  ocr_card_orig  정답 11 (채움 10 / 비움 1)  빈칸 1  틀림 0
  red_cascara  정답 16 (채움 14 / 비움 2)  빈칸 2  틀림 4
  sol_de_la_manana  정답 5 (채움 2 / 비움 3)  빈칸 2  틀림 2
  tacet_guji_hambella  정답 5 (채움 3 / 비움 2)  빈칸 5  틀림 4
합계  정답 92 (채움 61 / 비움 31)  빈칸 42  틀림 21

빈칸·틀림 63칸의 원인 (근사 — 설계 §4.2)
  파서 40칸 — OCR이 읽은 값을 못 뽑았거나 엉뚱한 칸에 넣었다
  OCR 6칸 — 정답 단어가 OCR 텍스트에 없다
  미분류 17칸 — 열거형·국가·날짜·비율

빈칸·틀림 목록
  archers_sidama  name  missing  [파서]
  archers_sidama  roaster  missing  [파서]
  archers_sidama  type  wrong: blend  [미분류]
  archers_sidama  components[0].region  wrong: 코코세 74158  [파서]
  archers_sidama  components[1].country  wrong: Ethiopia  [미분류]
  archers_sidama  components[1].region  wrong: Kokose 74158  [파서]
  archers_sidama  components[1].process  wrong: natural  [미분류]
  bench_maji_gesha  name  wrong: 벤치마지 게샤  [파서]
  bench_maji_gesha  type  missing  [미분류]
  bench_maji_gesha  cupNotes[살구]  missing  [파서]
  bench_maji_gesha  cupNotes[베르가못]  missing  [파서]
  bench_maji_gesha  cupNotes[녹차]  missing  [파서]
  bench_maji_gesha  cupNotes[+살구.]  wrong: 살구.  [파서]
  costa_rica_copey_52  name  wrong: Costa Rica Hacienda Copey  [파서]
  costa_rica_copey_52  type  missing  [미분류]
  costa_rica_copey_52  cupNotes[럼 레이즌]  missing  [파서]
  costa_rica_copey_52  cupNotes[포도 사탕]  missing  [파서]
  costa_rica_copey_52  cupNotes[자두]  missing  [파서]
  costa_rica_copey_52  cupNotes[카카오닙스]  missing  [파서]
  ethiopia_worka  type  missing  [미분류]
  ethiopia_worka  cupNotes[요거트]  missing  [파서]
  ethiopia_worka  cupNotes[황도]  missing  [파서]
  ethiopia_worka  cupNotes[허니콤]  missing  [파서]
  ethiopia_worka  cupNotes[패션프루트]  missing  [파서]
  ethiopia_worka  components[0].process  wrong: other  [미분류]
  hwachae  name  missing  [파서]
  hwachae  roaster  wrong: a Cotee Roastery  [OCR]
  hwachae  cupNotes[berry bomb]  missing  [파서]
  hwachae  cupNotes[tropical fruits]  missing  [파서]
  hwachae  cupNotes[light milk tea]  missing  [OCR]
  hwachae  cupNotes[plum sorbet]  missing  [OCR]
  hwachae  components[0].process  missing  [미분류]
  hwachae  components[0].ratioPercent  missing  [미분류]
  hwachae  components[1].process  missing  [미분류]
  hwachae  components[2].region  wrong: avour berry bomb tropicalfruits  [파서]
  hwachae  components[2].process  missing  [미분류]
  kwami_gesha_honey  name  missing  [파서]
  kwami_gesha_honey  type  missing  [미분류]
  kwami_gesha_honey  cupNotes[자스민]  missing  [파서]
  kwami_gesha_honey  cupNotes[사과]  missing  [파서]
  kwami_gesha_honey  cupNotes[귤]  missing  [파서]
  kwami_gesha_honey  components[0].region  missing  [파서]
  ocr_card_ko  type  missing  [미분류]
  ocr_card_orig  type  missing  [미분류]
  red_cascara  cupNotes[Citrus finish]  missing  [OCR]
  red_cascara  cupNotes[+Citrus fnish]  wrong: Citrus fnish  [파서]
  red_cascara  components[0].region  wrong: bio control 70940%  [파서]
  red_cascara  components[0].ratioPercent  missing  [미분류]
  red_cascara  components[1].region  wrong: GI -  [파서]
  red_cascara  components[2].region  wrong: Papayo  [파서]
  sol_de_la_manana  name  wrong: 볼리비아 커피를 다시 살리고자 Agricafe의 Rodriguez 가족들이 시작한  [파서]
  sol_de_la_manana  roaster  wrong: 이NAME OF FARM: Sol de La Maiana  [파서]
  sol_de_la_manana  type  missing  [미분류]
  sol_de_la_manana  components[0].region  missing  [파서]
  tacet_guji_hambella  name  wrong: 시 Hombeia Wamena, Danse Saysa 가공 Natural  [파서]
  tacet_guji_hambella  roaster  wrong: 품종 Heirtoom  [파서]
  tacet_guji_hambella  type  missing  [미분류]
  tacet_guji_hambella  cupNotes[베르가못]  missing  [OCR]
  tacet_guji_hambella  cupNotes[자두]  missing  [파서]
  tacet_guji_hambella  cupNotes[블루베리]  missing  [파서]
  tacet_guji_hambella  cupNotes[살구]  missing  [파서]
  tacet_guji_hambella  cupNotes[+Roast Point]  wrong: Roast Point  [파서]
  tacet_guji_hambella  components[0].region  wrong: Oronia. West Gui  [OCR]
```

관찰:

- **파서 대 OCR** — 문자열 칸(제품명·로스터리·지역·컵노트)의 빈칸·틀림 중 파서 40칸, OCR 6칸이다. 파서 쪽이 더 크다. 열거형·국가·날짜·비율 17칸은 구분하지 않았다(미분류).
- **`region` 오채움** — `.region` 칸의 wrong은 7칸, 4장이다. archers_sidama 2칸(`components[0]`·`components[1]`), hwachae 1칸(`components[2]`), red_cascara 3칸(`components[0]`·`components[1]`·`components[2]`), tacet_guji_hambella 1칸(`components[0]`). 7칸 중 6칸이 `[파서]`, 1칸(tacet_guji_hambella)이 `[OCR]`이다.
- **가장 많이 빈 필드** — `cupNotes` 23칸(노트 하나가 한 칸, 7장, `[파서]` 19칸·`[OCR]` 4칸). 그다음이 `type` 8칸이다. `type`은 싱글 카드 9장 모두에서 빈칸·틀림이고(missing 8, wrong 1 — archers_sidama `wrong: blend`) 블렌드 2장(red_cascara·hwachae)의 `type`은 목록에 없으니, 싱글 카드의 유형 칸은 대부분 missing으로 시작할 것이라는 §4.3의 계획 단계 측정과 맞는다.
- **이중 계산** — OCR 오독 하나가 두 칸으로 센다. 오독된 정답 노트는 `missing [OCR]`이 되고, 오독된 글자가 컵노트로 뽑히면 정답이 없는 칸을 채운 것이라 `wrong [파서]`가 된다. 목록에서 보이는 이 쌍은 1개다 — red_cascara `cupNotes[Citrus finish]`(`[OCR]`) + `cupNotes[+Citrus fnish]`(`[파서]`). 그러므로 파서 40칸에는 OCR 오독에서 온 1칸이 들어 있다. 같은 두 칸 모양이 파서 쪽에 1쌍 더 있다 — bench_maji_gesha `cupNotes[살구]` + `cupNotes[+살구.]`(둘 다 `[파서]`, 점이 붙은 `살구.`가 정답 `살구`와 달라서 두 칸이 된다).
- **품질 분기는 시험되지 않는다** — 새로 덤프한 9장은 모두 `quality: []`이고 이관한 2장은 `quality`를 기록하지 않았다(`null` → 빈 보고서로 재생). 11장 전부 품질 이슈가 없는 카드라서 `lowContrast`로 보정 패스를 타는 분기와 `shouldWarnQuality`가 참이 되는 경우는 이 코퍼스에 없다. 약한 OCR(`isWeakOcr`)은 품질 이슈 없이도 보정 패스를 부르므로 그 분기는 여전히 재생된다(보정본이 기록된 9장).
- **Android ML Kit 기준** — 픽스처는 Android 에뮬레이터 ML Kit 출력이다. 새로 덤프한 9장은 `emulator-5554`(AVD `flutter_emulator`, x86_64, Android 16)이고, 이관한 2장도 각 설계 문서(`ocr-bilingual-blend-card-design.md` §2.1, `ocr-inline-blend-card-design.md` §2)에 에뮬레이터 실측으로 적혀 있다. 사용자 앱은 iOS라 같은 사진도 줄 나눔·좌표가 다를 수 있다(§5) — 이 점수는 "Android ML Kit 기준 파서 점수"로 읽는다.
