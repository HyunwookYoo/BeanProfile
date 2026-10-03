# OCR 코퍼스 원본

`cards/`에 원두 카드 사진을 넣는다. **이 폴더는 `.gitignore`에 있다** — 저장소가 공개라
실카드 사진을 올리지 않는다. 커밋되는 건 여기서 뽑아낸 좌표 픽스처뿐이다
(`test/fixtures/ocr_corpus/`).

설계: [`docs/plans/ocr-corpus-design.md`](../docs/plans/ocr-corpus-design.md)

## 무엇을 넣나

- **서식이 서로 다른** 카드. 같은 로스터리의 같은 서식 5장은 1장과 정보량이 거의 같다.
  지금까지 파서가 깨진 건 전부 서식 차이였다 — 콜론형 / 2열형(라벨 열 │ 값 열) /
  한·영 병기 2줄 스택 / 인라인 블렌드 행.
- **실제로 앱에서 찍듯이** 찍은 사진. 스캔본이나 웹 이미지는 실사용 조건을 안 담는다.
  기울기·그림자·반사·EXIF 회전이 있는 게 정상 표본이다(`v0.6.x`의 EXIF 회전 재시도는
  실촬영에서만 드러난 문제였다).
- **잘 되는 카드도 함께.** 채점판의 첫 임무는 회귀 감지이고, 실패 카드만 있으면
  "카드 12를 고치다 카드 5를 깼다"를 잡을 수 없다.

파일명은 자유. 카드에서 읽어 코퍼스 id를 붙인다.

## 실패 카드 메모 (선택)

어떤 칸이 틀렸는지 아는 카드가 있으면 `cards/NOTES.md`에 한 줄씩 적어둔다.
정답표를 쓸 때 참고한다. 없어도 진행된다.

```
IMG_4821.jpg  지역에 엉뚱한 문구가 들어감
IMG_4830.jpg  블렌드인데 성분이 하나만 잡힘
```

## 카드를 추가하는 법

**파서를 고치기 전에** 새 카드부터 넣는다 — 그래야 그 카드가 파서가 본 적 없는 시험지가 된다(설계 §5).

1. 사진을 `cards/`에 넣고 `test/fixtures/ocr_corpus/sources.json`에 `"<id>": "samples/cards/<파일명>"` 한 줄을 더한다.
2. **정답표부터 쓴다** — `test/fixtures/ocr_corpus/<id>.truth.json`. 사진만 보고 쓴다(규칙: 설계 §4.2 R1–R8). OCR 결과를 보고 쓰면 채점판이 눈이 먼다.
3. 에뮬레이터를 띄우고(`flutter emulators --launch flutter_emulator`) 아래 덤프 명령을 돌린다. 출력의 `덤프 <id>: 원본 N줄`을 확인한다 — **0줄이면 인식이 실패한 것이다**(`MlkitOcrService`는 오류를 빈 목록으로 삼킨다). 그 픽스처는 옮기지 말고 환경(에뮬레이터·ML Kit 모델 다운로드)을 고쳐 다시 덤프한다.
4. `build/ocr_corpus/<id>.ocr.json`을 `test/fixtures/ocr_corpus/`로 옮긴다. 덤프는 목록 전체를 다시 뽑으므로, 이미 있는 카드 파일은 diff를 보고 판단한다.
5. **갱신하기 전에** 아래 게이트 명령을 UPDATE 없이 돌린다. 새 카드가 베이스라인에 없어서 실패하는 게 정상이다 — 출력된 바뀐 칸이 전부 `<새 id>  <칸>  (없음) → …` 모양인지 본다. 기존 카드의 줄이 하나라도 있으면 다른 무언가가 바뀐 것이니 멈추고 원인부터 찾는다.
6. 아래 갱신 명령으로 베이스라인을 다시 쓰고 `baseline.json` diff를 함께 커밋한다.

덤프:

    flutter drive --driver=test_driver/ocr_corpus_driver.dart --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554

게이트(UPDATE 없이):

    flutter test test/unit/ocr_corpus_test.dart

베이스라인 갱신:

    flutter test --dart-define=UPDATE_OCR_BASELINE=true test/unit/ocr_corpus_test.dart

## 원본을 잃어버리면

좌표 픽스처가 유일본이 된다. 픽스처는 텍스트라 리뷰·diff가 되므로 실질 손실은
크지 않지만, ML Kit 버전이 바뀌어 좌표를 다시 뽑아야 할 때는 원본이 필요하다.
따로 백업해 두면 좋다.

사진을 잃어버렸다면 `test/fixtures/ocr_corpus/sources.json`에서 그 id를 지운다.
드라이버는 목록에 적힌 사진이 하나라도 없으면 덤프를 시작하지 않고 종료한다
(`원본 사진이 없다`) — 지우지 않으면 나머지 카드도 다시 뽑을 수 없다. 커밋된
픽스처와 정답표는 그대로 둔다. 게이트는 계속 그 카드를 채점한다.
