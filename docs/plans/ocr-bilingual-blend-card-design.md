# ☕ BeanProfile — 한/영 병기 블렌드 카드 OCR 파싱 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-08-04 |
| 상태 | 설계 승인(브레인스토밍) → 구현 계획 대기 |
| 선행 | M3.3 좌표 OCR `v0.3.3` · 사진 OCR 신뢰성 `v0.6.x` · 칩 드래그 병합 `v0.7.0` |
| 상위 문서 | [`design.md`](../design.md) · [`testing.md`](../testing.md) |
| 계기 | 실기기 실패 카드 — UNSPECIALTY `RED CASCARA` (2026-08-04, 사용자 제보) |
| 영향 범위 | `ocr_parser.dart` · `ocr_component_parser.dart` (파서 전용, UI·스키마 변경 없음) |

---

## 1. 문제

사용자가 실제 원두 카드를 스캔했더니 **국가 `Ethiopia`와 가공 `내추럴`만** 채워졌다. 카드에는 블렌드 성분 3종, 컵노트 4개, 로스터리, 제품명이 다 적혀 있다.

사용자의 진단은 "카드가 너무 다양해서 규칙 기반 자동 인식에 한계가 있는 것 아니냐"였다. **측정 결과 그 진단이 맞았다.** 다만 원인은 인식이 아니라 파서에 있었다.

## 2. 측정 (2026-08-04)

### 2.1 기각된 가설 — 사진 회전

사진은 4032×3024에 **EXIF orientation 6**(표시하려면 90° 회전)이었다. 앱은 OCR을 `pick()`이 준 원본 임시 파일에 바로 돌리고(`add_bean_sheet.dart:88`), 좌표 기반 파서는 "가로로 읽히는 줄"을 전제한다(`_titleEyebrow`의 `width >= 1.2 * height` 필터, `_valueFor`의 "같은 행·오른쪽"). 그래서 **누운 좌표 탓에 좌표층이 통째로 죽었다**는 가설을 세웠다.

두 번 측정해서 두 번 다 기각됐다.

- **M1 (호스트)** — `DartOcrImagePreprocessor.enhance()`를 실사진에 직접 돌렸다. 던지지 않고 3.7초에 끝났고, `image` 패키지가 **디코드 단계에서 이미 EXIF를 적용**해 3024×4032를 돌려줬다(`bakeOrientation`은 무의미한 10ms no-op).
- **M2 (Android 에뮬레이터, 실제 ML Kit)** — 진단 서비스로 카드 전체를 돌렸다. `UNSPECIALTY BLEND`의 박스가 `[1191,191,2160,260]`, 즉 **969×69로 가로가 넓다**. ML Kit이 EXIF를 반영해 똑바른 좌표계(3024×4032)를 돌려준다. 회전은 범인이 아니다.

기록해 둘 값: `encodePng` 1234ms/6.7MB vs `encodeJpg` 409ms/1.7MB vs `2000px 리사이즈+JPEG` 153ms/548KB. `enhance()`가 12MP PNG를 쓰는 건 낭비지만 이번 문제와 무관하므로 스코프 밖(§7).

### 2.2 OCR은 거의 완벽했다

ML Kit이 18줄을 읽었고, 라벨 6개(`블렌딩:` `Blending Info` `노트:` `Notes` `로스터기:` `Roaster`), 제목 3개, 성분 3쌍, 컵노트 2줄을 전부 인식했다. 오독은 두 군데뿐이다 — `Citrus finish` → `Citrus fnish`, 그리고 `Natural 709 - 40%` → **`Natural 70940%`**(뒤에서 다룬다).

### 2.3 실제 파서 출력

| 필드 | 결과 | 정답 |
|---|---|---|
| 제품명 | `레드 카스카라` | ✅ |
| 로스터리 | `RED CASCARA` | ❌ `UNSPECIALTY` |
| 성분 | `Ethiopia / natural / 비율 null` **1개** | ❌ Thailand 40 · Ethiopia 40 · Colombia 20 **3개** |
| 컵노트 | `Complexity, Citrus fnish` | ❌ 앞줄 `Raspberrie, Sapphire Grape` 유실 |
| 타입 | `certainBlend` | ✅ |
| `filledFieldCount` | **4** | 목표 10 전후 |

`certainBlend`로 판정해 놓고 성분은 1개다. 앱이 스스로 모순된 상태였다.

### 2.4 호스트 재현 확인

M2 덤프의 18줄을 좌표 그대로 `OcrLine` 리터럴로 굳혀 호스트에서 `parseOcr`을 돌린 결과가 **기기 출력과 완전히 일치**했다(제품명·로스터리·컵노트·성분 1개까지). 따라서 아래 수정은 전부 에뮬레이터·실기기 없이 호스트 TDD로 진행한다. 이는 M3.3에서 세운 관례(`ocr_parser_test.dart`의 "실기기 좌표 픽스처" 그룹)를 그대로 따른다.

## 3. 확정 결정 (브레인스토밍 2026-08-04)

- **회전 관련 코드는 건드리지 않는다.** 측정으로 무죄가 확인됐다. 추측으로 방어 코드를 넣으면 죽은 코드만 남는다.
- **이번 단계는 규칙 수정만 한다.** 사용자가 미지 라벨·미지 국가를 한 번 가르치면 기억하는 **범용 어휘 학습**은 2단계로 분리한다(§7). 이번 4건 중 3건이 어휘 문제라 학습의 가치는 확인됐지만, 지금 당장 고칠 수 있는 걸 학습으로 덮으면 학습층의 실효를 평가할 수 없다.
- **로스터리를 라벨 기반 공간 매칭으로 뽑지 않는다.** 이 카드의 `로스터기:/Roaster` 값은 **로스팅 기계**(`Stronghold S7X Ver.2`)다. `_otherLabelTokens`에 `roaster`가 이미 있는데도 사고가 안 난 건 `_roasterLabel`이 같은 줄의 `콜론+값`을 요구하기 때문이다. 여기에 공간 매칭을 붙이면 로스터리 칸에 기계 이름이 들어간다. 로스터리는 계속 타이포그래피(`_titleEyebrow`)로만 정한다.
- **여러 줄 값 수집은 컵노트에만 적용한다.** 컵노트는 원래 여러 항목의 나열이라 줄바꿈이 자연스럽다. 지역·제품명은 한 줄이 관례이고 과수집 위험이 크므로 현행 단일 줄을 유지한다.

## 4. 설계

네 가지 수정이 서로 독립이다. 각각 별도 태스크로 쪼갤 수 있다.

### 4.1 라벨 블록 — 한/영 2줄 라벨을 하나로 묶는다

이 카드의 라벨은 한글 위, 영문 아래로 **2줄 스택**이다. 그래서 `노트:`는 첫 값줄과, `Notes`는 둘째 값줄과 같은 행에 놓인다. 현행 `_spatialValue`는 `_cupTokens`에 `노트`가 없어 `Notes`로 매칭했고, `_valueFor`가 값을 한 줄만 가져와 **둘째 줄만** 살아남았다.

**신규 개념 — 라벨 블록.** `_isLabel`이 참인 줄들 중 아래 둘을 만족하면 한 블록으로 묶는다.

- x 구간이 겹친다: `a.left <= b.right && b.left <= a.right`
- 세로 간격이 가깝다: `0 <= b.top - a.bottom <= 1.5 * max(a.height, b.height)`

실측 검증:

| 블록 | 줄 | 세로 간격 | 임계 | 판정 |
|---|---|---|---|---|
| 블렌딩 | `블렌딩:`(2453–2520) + `Blending Info`(2559–2617) | 39 | 100.5 | 묶임 |
| 노트 | `노트:`(3349–3413) + `Notes`(3451–3501) | 38 | 96 | 묶임 |
| 로스터기 | `로스터기:`(3708–3781) + `Roaster`(3820–3874) | 39 | 109.5 | 묶임 |
| (노트↔로스터기) | `Notes`(–3501) → `로스터기:`(3708–) | 207 | 109.5 | **안 묶임** ✔ |

**값 수집(컵노트 전용).** 블록 오른쪽 열에서 다음 라벨 블록 직전까지 모은다.

아래에서 `h` = 블록 최상단 줄의 높이, `블록.top`/`블록.right` = 블록에 속한 줄들의 최소 top / 최대 right.

1. 하한 = `블록.top - 0.5 * h`, 상한 = 다음 라벨 블록의 `top`(없으면 무한)
2. 값 후보는 `left >= 블록.right - 0.5 * h` 이고 **centerY**가 `[하한, 상한)` 안
3. `_valueFor`와 같은 `isUsable` 조건(빈 줄·라벨·`acceptsValue` 실패 제외)
4. `top` 오름차순으로 텍스트를 모아 `_splitNotes`에 넘긴다

실측 검증(노트 블록, 상한 3708):

| 줄 | centerY | 판정 |
|---|---|---|
| `Papayo Natural 20%` | 3139 | 하한 3317 미만 → 제외 ✔ |
| `Raspberrie, Sapphire Grape,` | 3397 | 수집 ✔ |
| `Complexity, Citrus fnish` | 3488 | 수집 ✔ |
| `Stronghold S7X Ver.2` | 3742 | 상한 3708 이상 → 제외 ✔ |

결과: `[Raspberrie, Sapphire Grape, Complexity, Citrus fnish]` 4개.

**상한이 왜 load-bearing인가.** `로스터기`를 라벨 어휘에 넣지 않으면 다음 라벨 블록이 `Roaster`(top 3820)가 되고, 그러면 `Stronghold S7X Ver.2`(centerY 3742)가 컵노트로 딸려 들어온다. 어휘 추가는 장식이 아니라 이 규칙의 전제다.

**폴백(비회귀 필수).** 블록 오른쪽에서 아무것도 못 모으면 현행 `_valueFor` 단일 결과를 그대로 쓴다. 기존 `ocr_card_orig` 픽스처는 컵노트 값이 라벨의 **아래**에 있고(`컵노트` left 78 vs 값 left 62) 오른쪽 조건을 통과하지 못하므로, 이 폴백이 없으면 회귀한다.

**어휘 추가.**

- `_cupTokens` ← `노트`
- `_otherLabelTokens` ← `블렌딩`, `blending info`, `로스터기`

`_otherLabelTokens`의 셋은 "값으로 오채움하면 안 되는 줄" + "값 블록 종료자" 역할만 한다. 어떤 필드에도 매핑하지 않는다.

### 4.2 이브로우가 제목급이면 건너뛴다

`_titleEyebrow`는 제목(최대 높이 줄) 바로 위의 작은 줄을 로스터리로 본다. 이 카드는 제목이 한/영 병기라 바로 위 줄이 **같은 제품명의 영문판**이다.

실측 — 18줄의 높이 중앙값 68, 제목 임계 `1.3 × 68 = 88.4`.

| 줄 | 높이 | 현행 | 수정 후 |
|---|---|---|---|
| `레드 카스카라` | 122 | 제목 | 제목 |
| `RED CASCARA` | 99 | **이브로우**(bottom 610으로 최근접) | 제목급(≥88.4) → 후보 제외 |
| `UNSPECIALTY BLEND` | 69 | 밀림 | **이브로우** |

**규칙.** 이브로우 후보에 `height < 1.3 * medianH` 조건을 추가한다. 임계값은 제목 판정에 이미 쓰는 상수를 재사용한다(새 상수 없음).

**접미 정리.** 이브로우 끝의 원두 타입 토큰(`blend` / `블렌드` / `single origin` / `싱글 오리진`)을 앞에 다른 글자가 있을 때만 떼어낸다. `UNSPECIALTY BLEND` → `UNSPECIALTY`. 토큰만 남으면(=`_beanTypeOnly` 단독) 현행대로 `null`.

### 4.3 성분 앵커 완화 — 줄머리 국가

가장 큰 손실이고, 원인이 한 줄에 있다.

`_hasComponentEvidence`의 여러 경로 중 이 카드의 배치를 알아볼 수 있는 건 `_hasRepeatedTopology`뿐인데, 그 입구인 `_anchorsRepeat`가 `_isCountryAnchorText`를 요구한다. 이 함수는 **국가·비율·라벨을 빼고 남은 글자가 없어야** 앵커로 인정한다.

```
Ethiopia Sidama Bensa Keramo Ako  →  "SidamaBensaKeramoAko"  → 앵커 아님
Colombia Inmaculada Fellow Farnms →  "InmaculadaFellowFarnms" → 앵커 아님
```

즉 "국가 + 농장/지역/등급"이 한 줄에 오는 흔한 스페셜티 표기가 통째로 앵커에서 탈락한다. 앵커가 없으니 `_anchorsRepeat` → `_hasRepeatedTopology` → 증거가 전부 false, `hasStructuredEvidence`가 false가 되어 `admitted = [mentions.first]`(`ocr_component_parser.dart:172`)로 **첫 언급 하나만** 남았다. 그게 Ethiopia다.

**규칙.** `_isCountryAnchorText`가 다음 중 하나면 참을 반환한다.

- (기존) 국가·비율·라벨을 뺀 나머지가 비어 있다
- (신규) **국가 언급이 줄 머리에 있다** — `line.text.substring(0, mention.textOffset)`이 공백·구분자뿐

세 성분 모두 국가가 줄 첫머리다. 완화 후 기존 기계가 이어받는 걸 실측으로 확인했다.

| 검사 | 값 | 임계 | 판정 |
|---|---|---|---|
| `_anchorsRepeat` sameColumn — left 차 (Ethiopia↔Colombia) | 0 | 2×62=124 | ✔ |
| 〃 centerY 차 | 271.5 | 6×62=372 | ✔ |
| `_hasParallelComponentValues` — Ethiopia 앵커→`GI Natural- 40%` offset | +92.5 | [−62, 372] | ✔ |
| 〃 Colombia 앵커→`Papayo Natural 20%` offset | +91.5 | 〃 | ✔ |
| 〃 두 offset 차 | 1.0 | 1.5×62=93 | **평행 성립** ✔ |
| 〃 Thailand 앵커→`bio control Natural 70940%` offset | +92.0 | 〃 | ✔ |

세 성분이 "국가 줄 + 92px 아래 연속행"이라는 동일 토폴로지를 이루므로 셋 다 증거를 얻는다.

**소유권 확인(계획 작성 중 해소).** `_ownerForLine`은 앵커 분포가 세로로 넓으면(`xSpread 148 < ySpread 547`) centerY 최근접으로 배정한다. 세 연속행의 최근접 거리는 92.0 / 92.5 / 91.5, 차순위는 183.5 / 179 / 363으로 모두 87px 이상 벌어져 있고 동점 가드는 0.5px다. 배정은 안전하다.

**남은 불확실.** 비율·가공을 실제로 채우는 건 `_unlabeledSpatialFields` → `_isUnlabeledTableCandidate` 경로다. `_ratioFrom('GI Natural- 40%')` = 40, `firstProcessMatch` = natural로 값 자체는 읽히고, 값 줄 셋 다 `_nonComponentTableText`(`blend|roast*|notes?|coffee|variety|altitude|product|name`)에 걸리지 않는다. 후보 판정만 통과하면 채워진다 — 계획의 RED가 이걸 증명한다.

**복구 불가 항목.** Thailand의 비율은 살릴 수 없다. OCR이 `Natural 709 - 40%`를 `Natural 70940%`로 붙여 읽었고, `ratioPattern`(`\b(100|[1-9]?\d)\s*%`)은 `70940%` 안에서 단어 경계를 찾지 못한다. `_fillSingleUnmatchedFields`의 "나머지 합이 100" 규칙도 남은 후보가 없어 못 채운다. **의도적으로 미해결로 둔다** — 숫자를 추측해 채우면 조용히 틀린 데이터가 저장된다. 사용자가 칩으로 배정하면 된다.

### 4.4 국가 사전 확장

`countryKeywords`는 24개국 하드코딩이고 **Thailand가 없다**. 없으면 `_countryMentions`에 후보로도 안 오른다.

추가: `thailand/태국`, `vietnam/베트남`, `india/인도`, `laos/라오스`, `myanmar/미얀마`, `papua new guinea/파푸아뉴기니`, `timor/동티모르`, `jamaica/자메이카`, `hawaii/하와이`.

**China는 넣지 않는다.** `_matchesIn`은 단어 경계 없는 부분 문자열 매칭(`lower.indexOf`)이라 니카라과의 산지 `Chinandega`를 China로 오인한다. 길이 내림차순 정렬은 같은 텍스트에 더 긴 후보가 있을 때만 방어가 되므로 이 경우를 막지 못한다.

이 사전은 2단계 어휘 학습이 대체할 자리다. 지금은 최소한만 넣는다.

## 5. 기대 결과

| 필드 | 현재 | 목표 | 근거 |
|---|---|---|---|
| 제품명 | `레드 카스카라` | 유지 | — |
| 로스터리 | `RED CASCARA` | `UNSPECIALTY` | §4.2, 실측 수치로 검증 |
| 컵노트 | 2개 | 4개 | §4.1, 실측 수치로 검증 |
| 성분 | 1개 | 3개 (Ethiopia 40 · Colombia 20 · Thailand 비율 null) | §4.3, 토폴로지까지 검증 / 필드 채움은 계획이 증명 |
| `filledFieldCount` | 4 | 10 전후 | 위 합산, 정확한 값은 TDD가 확정 |

## 6. 파일 영향

| 파일 | 변경 |
|---|---|
| `lib/features/beans/ocr/ocr_parser.dart` | 라벨 블록 + 컵노트 여러 줄 수집(§4.1) · `_titleEyebrow` 이브로우 조건·접미 정리(§4.2) · `_cupTokens`/`_otherLabelTokens` 어휘 |
| `lib/features/beans/ocr/ocr_component_parser.dart` | `_isCountryAnchorText` 완화(§4.3) · `countryKeywords` 확장(§4.4) |
| `test/unit/ocr_parser_test.dart` | 실기기 좌표 픽스처 그룹에 RED CASCARA 18줄 추가 |
| `test/unit/ocr_component_parser_test.dart` | 앵커 완화 단위 테스트 |

UI·스키마·백업·프로바이더 변경 없음. 마이그레이션 없음.

## 7. 테스트 전략 (`docs/testing.md` 3계층)

### 단위 — `test/unit/ocr_parser_test.dart`

- **RED CASCARA 실기기 픽스처**(18줄, 좌표 그대로) → §5 기대 결과 전부 단언. 이게 이 작업의 회귀 가드다.
- 라벨 블록 묶기: 한/영 2줄이 묶이고, 간격이 먼 다른 라벨과는 안 묶인다.
- 컵노트 상한: `로스터기` 어휘를 뺀 상태에서 `Stronghold S7X Ver.2`가 컵노트로 새어 들어오는지 확인하는 **판별 테스트**(어휘 추가가 load-bearing임을 증명).
- 이브로우: 제목급 줄이 후보에서 빠지는지 · 접미 `BLEND` 제거 · 타입 토큰 단독이면 여전히 `null`.

### 단위 — `test/unit/ocr_component_parser_test.dart`

- 줄머리 국가 앵커 인정 / 줄 중간 국가 언급은 여전히 앵커 아님(오탐 가드).
- 세 성분 토폴로지 → 3개 admitted.
- Thailand 비율이 `null`로 남는다(추측 채움 금지를 고정).

### 비회귀

- 기존 실기기 픽스처 2종(`ocr_card_ko` 콜론 카드 8필드, `ocr_card_orig` 콜론없음 카드 8필드)이 그대로 통과.
- 컵노트 아래-폴백 경로(§4.1)가 `ocr_card_orig`에서 살아 있는지 명시적으로 단언.
- 기존 346개 테스트가 하나도 깨지지 않고 `flutter test` 전체 green, `flutter analyze` 0. (신규 테스트만큼 총계는 늘어난다 — 총계 숫자를 목표로 삼지 않는다.)

### 기기 검증

호스트 픽스처가 기기 출력을 재현하므로(§2.4) 이번 작업에 에뮬레이터·실기기 사이클은 **필요 없다**. 배포 후 사용자가 실제 카드로 확인하는 것이 DoD.

## 8. 스코프 밖

- **2단계 — 범용 어휘 학습.** 칩 배정(칩 텍스트 → 필드)이 이미 정답 라벨링이므로, 이를 적립해 미지 라벨(`블렌딩`/`Blending Info`)과 미지 값(미등록 국가)을 사용자가 한 번 가르치면 기억하게 한다. 라벨 학습은 `OcrChip`에 좌표를 실어 날라야 해서(`ocr_chip.dart`는 현재 `parts` 텍스트만 보유) 별도 설계가 필요하다. 배치·기하 학습은 카드 지문(≈로스터리)이 있어야 성립하므로 "범용"에서 제외한다.
- **`enhance()`의 12MP PNG 비용.** 리사이즈+JPEG로 8배 빨라지지만(§2.1) 이번 실패와 무관하다.
- **`로스터기`/`Roaster` → 로스터리 매핑.** §3에서 기각.
- **Thailand 비율 추측 채움.** §4.3에서 기각.
- **폼 블렌드 `%` 입력 검증 부재.** M4에서 이월된 별건.

## 9. 완료 기준 (DoD)

1. RED CASCARA 픽스처가 §5 기대 결과를 만족한다.
2. 기존 실기기 픽스처 2종이 회귀하지 않는다.
3. `flutter test` 전체 green, `flutter analyze` 0.
4. 사용자가 실기기에서 같은 카드를 스캔해 성분 3개·컵노트 4개·로스터리 `UNSPECIALTY`를 확인한다.

## 부록 A — RED CASCARA 실측 좌표 픽스처

2026-08-04 Android 에뮬레이터 ML Kit(`TextRecognitionScript.korean`) ORIGINAL 패스 출력. 원본 사진 4032×3024 / EXIF orientation 6, ML Kit이 방향을 반영해 3024×4032 좌표계로 돌려준 값이다. **줄 순서까지 그대로 유지해야 한다** — `admitted = [mentions.first]` 등 순서 의존 경로가 있다.

```dart
const [
  OcrLine('블렌딩:', left: 876, top: 2453, right: 1095, bottom: 2520),
  OcrLine('노트:', left: 839, top: 3349, right: 1046, bottom: 3413),
  OcrLine('Blending Info', left: 876, top: 2559, right: 1218, bottom: 2617),
  OcrLine('Notes', left: 875, top: 3451, right: 1034, bottom: 3501),
  OcrLine('UNSPECIALTY BLEND', left: 1191, top: 191, right: 2160, bottom: 260),
  OcrLine('RED CASCARA', left: 1137, top: 511, right: 2303, bottom: 610),
  OcrLine('로스터기:', left: 873, top: 3708, right: 1159, bottom: 3781),
  OcrLine('Roaster', left: 864, top: 3820, right: 1073, bottom: 3874),
  OcrLine('레드 카스카라', left: 1312, top: 773, right: 2127, bottom: 895),
  OcrLine('Thailand Phupanna coffee',
      left: 1329, top: 2465, right: 2096, bottom: 2536),
  OcrLine('bio control Natural 70940%',
      left: 1352, top: 2563, right: 2236, bottom: 2622),
  OcrLine('Ethiopia Sidama Bensa Keramo Ako',
      left: 1327, top: 2745, right: 2394, bottom: 2807),
  OcrLine('GI Natural- 40%', left: 1366, top: 2836, right: 1846, bottom: 2901),
  OcrLine('Colombia Inmaculada Fellow Farnms',
      left: 1327, top: 3017, right: 2393, bottom: 3078),
  OcrLine('Papayo Natural 20%',
      left: 1345, top: 3102, right: 1973, bottom: 3176),
  OcrLine('Raspberrie, Sapphire Grape,',
      left: 1328, top: 3351, right: 2318, bottom: 3443),
  OcrLine('Complexity, Citrus fnish',
      left: 1328, top: 3450, right: 2197, bottom: 3527),
  OcrLine('Stronghold S7X Ver.2',
      left: 1326, top: 3704, right: 2065, bottom: 3780),
]
```

이 픽스처로 호스트에서 `parseOcr`을 돌린 결과가 기기 출력과 일치함을 확인했다(§2.4). 원본 사진은 개인 사진이라 public 레포에 커밋하지 않는다.
