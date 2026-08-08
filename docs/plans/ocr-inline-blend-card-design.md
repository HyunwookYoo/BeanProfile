# ☕ BeanProfile — 인라인 블렌드 행 카드 OCR 파싱 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-08-08 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획 대기 |
| 선행 | 한/영 병기 블렌드 카드 `v1.0.1` ([design](./ocr-bilingual-blend-card-design.md)) |
| 상위 문서 | [`design.md`](../design.md) · [`testing.md`](../testing.md) |
| 계기 | 실기기 실패 카드 — One Half Coffee Roastery `HWACHAE BLEND` (2026-08-08, 사용자 제보) |
| 영향 범위 | `ocr_parser.dart` · `ocr_component_parser.dart` (파서 전용, UI·스키마 변경 없음) |

---

## 1. 문제

`v1.0.1` 설치 직후 사용자가 다른 카드를 스캔했다. 3-오리진 블렌드인데 **성분이 Panama 하나만** 채워졌고, 로스팅 날짜·제품명·컵노트는 비었다.

이 카드는 앞선 RED CASCARA와 배치가 정반대다. 라벨/값을 두 열로 나누지 않고 **한 줄에 성분 하나를 통째로** 적는다. 그리고 비율이 국가 **앞**에 온다.

```
info. 10% panama blackmoon, geisha, anaerobic n
      45% ecuador meridiano, typica mejorado, washed
      45% ethiopia gute mini, 74110 peaberry, washed
flavour. berry bomb, tropical fruits,
         light milk tea, plum sorbet
13 JUL 2026 · Roasted in Malaysia · One Half Coffee Roastery
```

## 2. 측정 (2026-08-08, Android 에뮬레이터 실 ML Kit)

### 2.1 OCR 원문 — 품질이 눈에 띄게 나쁘다

평균 신뢰도 0.754, `weak=true`. 다섯 줄이 뭉개졌다.

```
info. 109% panama blackmoon, geisha, anaerobic n   ← 10% 가 109%
45% ecuador meridiano, typica mejorado, washed
45% ethiopia gute mini, 74110 peaberry, washed
avour berry bomb, tropicalfruits,                  ← flavour 의 "fl" 유실
igtlk tea, plun sorbet                             ← light milk tea, plum sorbet
Alt 한/영                                           ← 사진에 찍힌 키보드
a Cotee Roastery                                   ← One Half Coffee Roastery
NSI or quaity, seasonality, and harmony.
HWACHAE BLEND / Designed for / UNSPECIALTY
13 JUL 2026 / Roasted in Malaysia
```

호스트 픽스처(부록 A)가 이 결과를 그대로 재현한다:

```
name=null  roaster=a Cotee Roastery  date=null  notes=[]
components=(Panama/null/anaerobic)
```

### 2.2 성분이 하나만 남은 경로

세 줄 모두 비율이 국가 **앞**에 있는데, `_countryMentions`는 비율을 국가 **뒤** 구간에서만 찾는다 → `mention.ratio`가 셋 다 `null`.

그리고 `_isCountryAnchorText`의 접두 제거 문자군 `[\s\-–—|/·,:：()\[\]#\d]+`에 **`%`와 `.`이 없다**:

| 줄 | 접두 | 제거 후 | 앵커 |
|---|---|---|---|
| `45% ecuador …` | `45% ` | `%` | ❌ |
| `45% ethiopia …` | `45% ` | `%` | ❌ |
| `info. 109% panama …` | `info. 109% ` | `info.` | ❌ |

앵커가 없으니 `_anchorsRepeat` → `_hasRepeatedTopology`가 죽고, 다른 증거 경로도 전부 false → `hasStructuredEvidence == false` → `admitted = [mentions.first]` → **Panama 하나**.

가공이 `anaerobic`으로 채워진 건 성분이 1개일 때 `parseOcr`이 전체 텍스트의 가공 키워드로 덮어쓰기 때문이고, Panama가 실제로 anaerobic이라 **우연히 맞았다**.

### 2.3 기각된 수정 — "제목 후보에서 날짜 줄 제외" (중요)

제품명이 비는 원인은 `_titleEyebrow`가 최대 높이 줄을 제목으로 보는데 이 카드에서 가장 큰 줄이 `13 JUL 2026`(h=142)이고, 그게 하단이라 "제목은 상위 45%" 검사에 걸려 `(null, null)`을 반환하기 때문이다.

그래서 "날짜로 파싱되는 줄은 제목 후보에서 뺀다"를 제안했다가 **픽스처로 계산해 기각했다**:

| 변형 | 중앙값 | 임계 | 최대 줄 | 결과 |
|---|---|---|---|---|
| 현행 | 75.0 | 97.5 | `13 JUL 2026` (142) | **null** ← 기기와 일치 |
| 날짜 줄 제외 | 72.5 | 94.25 | `Alt 한/영` (109) | **`Alt 한/영`** ← 키보드가 제품명 |
| 날짜 + 키보드 제외 | 70.0 | 91.0 | `Designed for` (98) | **`Designed for`** ← 여전히 오답 |
| 키보드만 제외 | 72.5 | 94.25 | `13 JUL 2026` (142) | null |

제외 규칙으로는 못 고친다. **`HWACHAE BLEND`의 높이가 75로 정확히 중앙값**이기 때문이다 — 제품명이 본문과 같은 크기로 찍혀 있어 "제품명 = 가장 큰 글자"라는 전제 자체가 성립하지 않는다.

그리고 현행 `null`은 **설계 원칙상 옳은 동작**이다. 틀린 값을 넣느니 비운다는 원칙대로 휴리스틱이 제대로 포기했고, 제안한 수정은 그 포기를 깨서 키보드를 제품명으로 만들 뻔했다. **다시 시도하지 말 것.**

## 3. 확정 결정 (브레인스토밍 2026-08-08)

- **제품명은 손대지 않는다.** §2.3에서 측정으로 기각.
- **컵노트도 손대지 않는다.** 라벨이 `flavour.`인데 어휘에 없고, 더 근본적으로 OCR이 `fl`을 날려 `avour …`로 읽었다. 어휘를 추가해도 이 카드는 안 된다. 값을 라벨과 같은 줄에 `.`로 구분해 적는 것도 별개 문제다.
- **Panama의 비율은 복구하지 않는다.** OCR이 `10%`를 `109%`로 읽어 `ratioPattern`의 단어 경계가 깨졌다. RED CASCARA의 `70940%`와 같은 현상이고, 같은 이유로 추측해 채우지 않는다.
- **`_anchorsRepeat`의 같은 열 임계(`2 * scale`)는 건드리지 않는다.** panama(left 157)↔ecuador(left 301)가 144 vs 140으로 4픽셀 차 탈락하지만, panama↔ethiopia가 145 vs 154로 통과해 실제로는 아무것도 막지 않는다. 임계를 넓히면 다른 열의 무관한 국가끼리 짝이 맺어질 위험만 생긴다. 취약점으로 기록만 한다(§8).
- **로스터리 오독은 파서 문제가 아니다.** `Roastery`로 끝나는 유일한 줄을 잡는 규칙은 정상 동작했고 텍스트 자체가 OCR 오독이다.

## 4. 설계

### 4.1 성분 앵커 — 접두에 붙는 것들을 걷어낸다

`_isCountryAnchorText`의 ① 갈래(줄머리 국가)를 두 단계로 만든다.

1. **선행 라벨 토큰 제거** — 접두 문자열 앞에서 `^(?:info|origin|원산지|생산지|component|구성|blend|블렌드)\s*[.:：·\-]?\s*` 를 한 번 제거한다. 대소문자 무시. `_bareLocalComponentLabel`의 어휘에 `info`를 더한 것이며, 그쪽은 `^…$`로 줄 전체를 보는 반면 이건 접두만 본다.
2. **문자군 제거** — 기존 `[\s\-–—|/·,:：()\[\]#\d]+`에 **`%`와 `.`** 을 더한다.

남은 문자열이 비면 앵커다.

| 접두 | 1단계 후 | 2단계 후 | 앵커 |
|---|---|---|---|
| `45% ` | `45% ` | `` | ✅ |
| `info. 109% ` | `109% ` | `` | ✅ |
| `Info about our ` | `about our ` | `aboutour` | ❌ 오탐 가드 유지 |

**② 갈래는 그대로 둔다.** 지금 두 갈래가 같은 문자군 리터럴을 공유하므로, ①에는 **별도의 확장 문자군**을 두고 ②는 기존 것을 계속 쓴다. ②는 이미 `ratioPattern`으로 `NN%`를 통째로 지우므로 `%`를 더해도 중복이고, `.`을 더하면 `Ethiopia.` 같은 줄까지 앵커로 넓히게 되는데 이 카드에 필요하지 않다. 넓히지 않는 쪽이 오탐이 적다.

### 4.2 국가 **앞**의 비율 읽기

`_countryMentions`는 지금 국가 매치 뒤부터 다음 국가 매치 전까지에서만 비율을 찾는다. **그 줄의 첫 번째 국가 언급에 한해**, 뒤 구간에서 못 찾으면 `[0, match.offset)` 구간도 본다.

**첫 번째로 제한하는 것이 이 설계의 핵심 안전장치다.** `Ethiopia 60% Brazil` 같은 줄에서 Brazil의 "앞 구간"은 Ethiopia의 "뒤 구간"과 **같은 span**이라, 제한이 없으면 Brazil이 Ethiopia의 60%를 그대로 훔친다. 첫 번째로 묶으면 다중 국가 한 줄 카드의 동작은 **하나도 바뀌지 않는다**.

| 줄 | 앞 구간 | 결과 |
|---|---|---|
| `45% ecuador meridiano, …` | `45% ` | 45 |
| `45% ethiopia gute mini, …` | `45% ` | 45 |
| `info. 109% panama …` | `info. 109% ` | null — `109%`는 `ratioPattern` 불일치 |

### 4.3 인라인 성분 행 토폴로지

`_hasRepeatedTopologyPair`는 `_anchorsRepeat` 통과 후 ⓐ 같은 행 ⓑ 둘 다 로컬 라벨 보유 ⓒ `_hasParallelComponentValues` 중 하나를 요구한다. ⓒ는 값이 **별도 줄**로 평행하게 놓일 때만 성립하는데, 이 카드는 값이 전부 앵커 줄에 인라인이라 성립하지 않는다.

**네 번째 갈래를 더한다** — 두 앵커가 각자 자기 줄에서 국가 이름을 뺀 나머지에 비율이나 가공 키워드를 품고 있으면, 그 둘은 한 묶음의 성분 행이다.

```
국가 이름을 제거한 나머지에 ratioPattern 매치 또는 firstProcessMatch 결과가 있으면 인라인 성분 데이터 보유.
두 앵커가 모두 보유하면 반복 토폴로지 성립.
```

| 줄 | 국가 제거 후 나머지 | 근거 |
|---|---|---|
| panama | `info. 109% blackmoon, geisha, anaerobic n` | 가공 `anaerobic` |
| ecuador | `45% meridiano, typica mejorado, washed` | 비율 `45%` + 가공 `washed` |
| ethiopia | `45% gute mini, 74110 peaberry, washed` | 비율 `45%` + 가공 `washed` |

`_anchorsRepeat`가 먼저 걸러주지만 **그것만으로는 무관한 두 줄이 붙는 걸 못 막는다** — 요구하는 것이 같은 열과 줄머리 국가뿐이고, 산문도 그 둘을 쉽게 만족한다. 실제로 막아주는 건 가공 키워드를 **단어 경계로** 세는 것이다. `indexOf`로 부분 문자열을 세면 `naturally`가 `natural`로, `honeyed`가 `honey`로 잡혀 아래 두 줄이 그대로 블렌드가 된다(구현 후 리뷰가 측정):

```
Ethiopia Yirgacheffe naturally sweet and floral
Colombia Huila honeyed body with cocoa
```

실측 짝짓기:

| 짝 | left 차 | 임계 | 판정 |
|---|---|---|---|
| panama ↔ ecuador | 144 | 140 | ❌ (4px 차) |
| panama ↔ ethiopia | 145 | 154 | ✅ |
| ecuador ↔ ethiopia | 1 | 154 | ✅ |

panama는 ethiopia와 짝이 맺어져 증거를 얻는다. 셋 다 채택된다.

### 4.4 `DD MMM YYYY` 날짜

`_datePatterns`에 항목을 더하는 것으로는 안 된다 — `_dateIn`이 그룹 순서를 (연, 월, 일)로 고정하고 월을 `int.parse`한다. **영문 월 이름 전용 매처**를 따로 두고, 숫자 패턴들이 모두 실패한 뒤에 시도한다.

- 형식: `<일> <월이름> <연도>` (예: `13 JUL 2026`, `13 July 2026`). 대소문자 무시, 월 이름은 앞 세 글자로 판정.
- 연도는 `20\d{2}`로 제한한다. 커피 카드에 1900년대 날짜는 없고, 넓히면 오탐만 는다.
- 일·월 유효성 검사는 기존 `_dateIn`과 같은 기준(월 1–12, 일 1–31).
- `JUL 13 2026` 같은 미국식 순서는 **넣지 않는다** — 관측된 적 없다.

오탐 확인: 같은 카드의 `74110 peaberry, …`는 `<숫자> <단어>` 뒤에 연도가 오지 않아 매치되지 않는다.

`_matchDate`의 1단계(로스팅 라벨이 있는 줄 우선)에서 `Roasted in Malaysia`가 `_roastLabel`에 걸리지만 그 줄에 날짜가 없어 null이 되고, 2단계 전체 텍스트 탐색에서 `13 JUL 2026`을 잡는다.

## 5. 기대 결과

| 필드 | 현재 | 목표 | 확신도 |
|---|---|---|---|
| 성분 국가 | `[Panama]` | `[Panama, Ecuador, Ethiopia]` | 앵커·토폴로지까지 실측 검증 |
| 성분 비율 | `[null]` | `[null, 45, 45]` | §4.2로 도출 |
| 로스팅 날짜 | null | **2026-07-13** | §4.4로 도출 |
| 제품명 | null | null (유지) | §2.3에서 측정으로 확정 |
| 컵노트 | `[]` | `[]` (유지) | 스코프 밖 |
| 로스터리 | `a Cotee Roastery` | 그대로 | OCR 오독 |

**미검증**: 성분이 3개가 됐을 때 가공이 성분별로 제대로 붙는지, 지역에 무엇이 들어가는지는 코드로 확인하지 않았다. 구현 계획의 첫 RED가 이를 드러내야 한다. 지역이 오염되면 지난 브랜치에서 미룬 "모르면 null" 후속(직전 설계 §8)과 합칠지 그 시점에 판단한다.

## 6. 파일 영향

| 파일 | 변경 |
|---|---|
| `lib/features/beans/ocr/ocr_component_parser.dart` | `_isCountryAnchorText` 접두 처리(§4.1) · `_countryMentions` 앞 구간 비율(§4.2) · `_hasRepeatedTopologyPair` 인라인 갈래(§4.3) |
| `lib/features/beans/ocr/ocr_parser.dart` | 영문 월 날짜 매처(§4.4) |
| `test/helpers.dart` | `hwachaeLines` 픽스처 추가 |
| `test/unit/ocr_component_parser_test.dart` | 앵커·비율·토폴로지 테스트 |
| `test/unit/ocr_parser_test.dart` | 카드 전체 통합 단언 · 날짜 테스트 |

UI·스키마·백업·프로바이더 변경 없음. 마이그레이션 없음. 새 의존성 없음.

## 7. 테스트 전략 (`docs/testing.md` 3계층)

호스트 픽스처가 기기 출력을 재현하므로(§2.1) 에뮬레이터·실기기 사이클은 필요 없다.

**모든 새 가드는 뮤테이션으로 판별력을 증명한다** — 직전 브랜치에서 태스크 리뷰 4개를 통과한 테스트 3개가 무력했고, 원인은 나중에 추가된 넓은 가드가 먼저 발동해 앞선 판별 테스트를 조용히 무력화한 것이었다. 가드를 지웠을 때 실제로 빨개지는지 확인하고 그 증거를 남긴다.

### 단위 — `ocr_component_parser_test.dart`

- HWACHAE 픽스처 → 성분 3개와 비율 `[null, 45, 45]`. Panama 비율이 `null`로 남는 것을 고정한다(추측 채움 금지).
- 접두 라벨 제거: `info. 45% ethiopia …`는 앵커, `Info about our Ethiopia trip`은 앵커 아님(오탐 가드).
- 앞 구간 비율이 **첫 번째 국가에만** 적용되는 것: `Ethiopia 60% Brazil` 한 줄에서 Brazil이 60을 가져가지 않는다. 이게 §4.2 제한의 판별 테스트다.
- 인라인 토폴로지: 인라인 데이터가 없는 두 앵커는 이 갈래로 붙지 않는다.

### 단위 — `ocr_parser_test.dart`

- HWACHAE 픽스처 → 카드 전체(§5 표) 단언. `Alt 한/영`이 제품명이 되지 않는 것과 `name`이 `null`인 것을 함께 고정한다 — §2.3의 기각을 코드로 못박는다.
- 날짜: `13 JUL 2026` → 2026-07-13 · `13 July 2026` → 동일 · `74110 peaberry`는 날짜 아님 · 기존 숫자 형식 비회귀.

### 비회귀

- 기존 실기기 픽스처 3종(`ocr_card_ko` · `ocr_card_orig` · `redCascaraLines`)이 그대로 통과.
- 기존 356개 테스트가 하나도 깨지지 않을 것. (신규 테스트만큼 총계는 늘어난다 — 총계 숫자를 목표로 삼지 않는다.)
- `flutter analyze` 0.

## 8. 스코프 밖

- **제품명 자동 채움.** §2.3에서 측정으로 기각. 타이포그래피 휴리스틱이 통하지 않는 카드류가 존재한다는 사실 자체를 기록으로 남긴다.
- **컵노트.** `flavour` 어휘를 넣어도 이 카드는 OCR이 라벨을 뭉개서 안 된다. 다른 카드에서 `flavour.`가 온전히 읽힌 사례가 나오면 그때 어휘를 넓힌다.
- **Panama 비율 추측 채움.** §3에서 기각.
- **`_anchorsRepeat` 같은 열 임계.** §3에서 기각 — 실제로 막고 있는 것이 없다. 다만 취약점으로 남는다: 이 카드에서 panama↔ecuador는 4픽셀 차로 탈락하고 panama↔ethiopia가 대신 짝을 맺어주고 있어, 세 번째 줄이 없거나 높이가 달랐다면 panama가 고아가 됐을 것이다.
- **성분 `region`의 "모르면 null" 규칙 — 다음 브랜치의 머리 항목.** 재발했고, 이번엔 이 브랜치가 **새로 만든** 값이다. 기준선에서는 성분이 하나만 채택돼 `_repeatedLayout`이 null이었고 지역 경로 자체가 돌지 않았다 — 성분 셋을 채택한 것이 이 경로를 연다. 측정값: Ethiopia의 지역이 `avour berry bomb tropicalfruits`, 카드의 **다른 블록**에 있는 컵노트 줄 조각이다.

  **직전 설계 §8의 시작 가설(`%`나 숫자 과반 잔여를 거부)은 층을 잘못 짚었다.** 이번 값은 깨끗한 산문이라 문자열 필터로 안 걸린다. 두 사례 모두 원인은 **공간 층**이다 — `_isUnlabeledTableCandidate`의 세로 창이 너무 멀리 뻗고(`maxBottom + 4 * maxHeight` = 1598 + 4×77 = **1906**, 컵노트 조각의 bottom 1828은 그 안쪽 78px), `_ownerForLine`이 "같은 블록인가"라는 개념 없이 중심 최근접으로 배정한다.

  현재 출력은 **두 우연**이 만든다: 둘째 컵노트 줄(bottom 1915)이 창을 9px 차로 벗어나고, `_unlabeledRegion`의 4단어 상한을 이 조각이 정확히 채운다. 안정적인 상태가 아니다.

  **부분 수정은 통하지 않는다 — 측정으로 확인했다.** 4단어 상한을 3으로 조이면 null이 되는 게 아니라 `Designed for`로 **바뀐다**. 창만 조여도 마찬가지다. 창·소유자 배정·잔여 필터를 한 묶음으로 봐야 한다.

  **부수 효과**(직전 설계에서 이월): 쓰레기 지역이 `filledFieldCount`를 부풀리고, 그 값이 `compareOcrCandidates`의 타이브레이커라 2패스 스캔의 ORIGINAL/ENHANCED 선택을 뒤집을 수 있다.

  현재 값들은 `알려진 결함:`으로 시작하는 테스트에 고정돼 있다. 고치면 시끄럽게 깨지면서 의식적 결정을 강제한다. **세 번째로 조용히 미루지 말 것** — 그게 안 되면 대안은 표-폴백에서 `region` 자동채움을 아예 끄고 사용자가 칩으로 배정하게 하는 것이고, 그건 "틀린 값보다 빈 칸"이라는 이 설계의 원칙이 지지하는 선택이다.
- **성분 줄에 적힌 `process`를 값으로 못 쓰는 것.** 이 카드는 성분 줄마다 `anaerobic`·`washed`·`washed`를 적어두는데 셋 다 `null`이다. `_componentFor`가 `sequentialProcess`를 제대로 계산해 놓고, `_repeatedLayout`이 존재하면 `useSequentialFields`가 false가 되어 버린다. **내부 모순** — `_hasInlineComponentData`는 바로 그 키워드를 성분 채택의 증거로 쓰면서 값으로는 거부한다. 이 카드에서 필드 3개가 더 맞아진다. 지역 후속과 같은 브랜치에서 다루는 게 자연스럽다.
- **`firstProcessMatch`의 무경계 `indexOf`.** 이번 브랜치는 `_hasInlineComponentData` 안에서만 단어 경계를 세웠다. 다른 소비자(`_componentFor`·`_isUnlabeledTableCandidate`·`_standaloneProcess`·`ocr_parser.dart` 세 곳)는 그대로라, 산문 `naturally`가 여전히 `Process.natural`이 된다. 이 브랜치가 만든 것도 넓힌 것도 아닌 기존 결함이지만, 위 두 항목과 뿌리가 같다.
- **사진에 찍힌 주변 물체.** 키보드 `Alt 한/영`이 OCR돼 칩으로 남고 제목 판정의 세로 범위를 넓힌다. 파서로 일반해를 만들 수 없다 — 카드만 채워 찍는 촬영 쪽 문제다.
- **`.`을 지우면서 딸려온 넓히기.** §4.1은 `info.`의 마침표만 노렸지만, `_anchorPrefixNoise`에 `.`이 들어가면 번호 목록 `1. Ethiopia Guji washed`와 날짜 접두 `2026.07.10 Ethiopia washed`도 앵커가 된다(둘 다 접두가 숫자·마침표·공백뿐이라 통째로 지워진다). 원하던 방향의 넓히기라 되돌리지 않지만 **의도한 범위 밖이고 지금 테스트가 없다** — 이 두 모양이 실카드에서 나오면 그때 픽스처로 고정한다.

## 9. 완료 기준 (DoD)

1. HWACHAE 픽스처가 §5 기대 결과를 만족한다.
2. 기존 실기기 픽스처 3종이 회귀하지 않는다.
3. 새 가드마다 뮤테이션 증거(가드 제거 → 해당 테스트 실패)가 보고서에 남는다.
4. `flutter test` 전체 green, `flutter analyze` 0.
5. 사용자가 실기기에서 같은 카드를 스캔해 성분 3개와 로스팅 날짜를 확인한다.

## 부록 A — HWACHAE BLEND 실측 좌표 픽스처

2026-08-08 Android 에뮬레이터 ML Kit(`TextRecognitionScript.korean`) ORIGINAL 패스 출력. 원본 4032×3024 / EXIF orientation 6. **줄 순서를 유지할 것** — `admitted = [mentions.first]` 등 순서 의존 경로가 있다. `Alt 한/영`은 사진에 찍힌 키보드이며, 파서가 실제로 견뎌야 하는 입력이라 **일부러 남긴다**.

```dart
const [
  OcrLine('info. 109% panama blackmoon, geisha, anaerobic n',
      left: 157, top: 1376, right: 1672, bottom: 1442),
  OcrLine('45% ecuador meridiano, typica mejorado, washed',
      left: 301, top: 1450, right: 1818, bottom: 1520),
  OcrLine('45% ethiopia gute mini, 74110 peaberry, washed',
      left: 302, top: 1521, right: 1769, bottom: 1598),
  OcrLine('avour berry bomb, tropicalfruits,',
      left: 155, top: 1743, right: 1196, bottom: 1828),
  OcrLine('igtlk tea, plun sorbet',
      left: 159, top: 1847, right: 954, bottom: 1915),
  OcrLine('Alt 한/영', left: 1244, top: 202, right: 1661, bottom: 311),
  OcrLine('a Cotee Roastery', left: 366, top: 2260, right: 885, bottom: 2328),
  OcrLine('NSI or quaity, seasonality, and harmony.',
      left: 229, top: 2344, right: 1455, bottom: 2407),
  OcrLine('HWACHAE BLEND', left: 2173, top: 1377, right: 2979, bottom: 1452),
  OcrLine('Designed for', left: 2172, top: 1495, right: 2737, bottom: 1593),
  OcrLine('UNSPECIALTY', left: 2171, top: 1616, right: 2800, bottom: 1697),
  OcrLine('13 JUL 2026', left: 2353, top: 2198, right: 2956, bottom: 2340),
  OcrLine('Roasted in Malaysia',
      left: 2162, top: 2347, right: 2727, bottom: 2406),
];
```

원본 사진은 개인 사진(책상·키보드 포함)이라 public 레포에 커밋하지 않는다.
