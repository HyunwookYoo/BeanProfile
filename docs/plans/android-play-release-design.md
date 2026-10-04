# 🤖 BeanProfile — Android Play 출시 (내부 테스트) 설계

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-10-04 |
| 상태 | 설계 승인(브레인스토밍 2026-10-04) → 구현 계획 [`android-play-release-plan.md`](./android-play-release-plan.md) |
| 계기 | 사용자 — "android쪽도 출시를 해봐야 할 것 같아" |
| 상위 문서 | [`deployment.md`](../deployment.md) · [`store-listing.md`](../store-listing.md) · [`privacy.md`](../privacy.md) |
| 영향 범위 | Android 빌드 설정 · `release.yml` · release 스모크(테스트 전용 진입점 · 판정 스크립트) · 개인정보 고지 문서 · 배포 문서. **앱 Dart 코드(`lib/`) 무수정** |

---

## 1. 문제 — Android 릴리스 경로는 설계만 있고 실체가 없었다

`deployment.md` §2는 "태그 → Android APK → GitHub Release" 잡을 설계했고 CLAUDE.md도 그 경로를 배포 규약으로 적고 있다. 실측(2026-10-04)은 다르다.

| 확인 | 실제 |
|---|---|
| `release.yml` | Android 잡 **없음** — `test`·`ios`·`appstore-gate`·`appstore`뿐 |
| `android/app/build.gradle.kts` | release 빌드가 **debug 키로 서명**(Flutter 템플릿 TODO 그대로) |
| 키스토어·`key.properties` | 없음 |
| `android:label` | `beanprofile`(소문자) — iOS는 7월에 `BeanProfile`로 고침 |
| `flutter build appbundle --release` | **실패** — R8: `Missing class com.google.mlkit.vision.text.{chinese,devanagari,japanese}.*Options` |

마지막 줄이 이 설계의 첫 기술 과제다. `google_mlkit_text_recognition` 플러그인의 `TextRecognizer.initialize`가 네 문자 체계의 옵션 클래스를 모두 참조하는데, 앱은 한국어(`text-recognition-korean:16.0.1`)만 의존성으로 넣었다. 지금까지 에뮬레이터 검증은 전부 debug 빌드라 R8이 돈 적이 없어 드러나지 않았다.

이미 충족된 것도 실측했다.

- **target API** — `flutter.targetSdkVersion` = 36(Flutter 3.44.6). Play는 2026-08-31부터 신규 앱에 API 36을 요구한다.
- **16 KB 페이지** — 64비트 네 라이브러리(`libapp`·`libflutter`·`libmlkit_google_ocr_pipeline`·`libsqlite3`) 모두 ELF LOAD 정렬 ≥ 0x4000(arm64-v8a·x86_64). NDK r28.
- **권한** — 합쳐진 매니페스트에 `CAMERA`·`INTERNET`·`ACCESS_NETWORK_STATE`뿐. 저장소·미디어 권한 없음 → Play 사진 권한 정책에 걸리지 않는다. `INTERNET`은 ML Kit이 넣는다(§4.4).
- **뒤로 가기** — 앱은 `PopScope`만 쓰고 `WillPopScope`가 없다. API 36의 예측 뒤로 가기와 충돌할 코드 없음.

## 2. Play 요건 (2026-10 공식 문서로 확인)

| 요건 | 이 앱에 미치는 영향 |
|---|---|
| 2023-11-13 이후 개인 계정은 **테스터 12명이 14일 연속 참여한 비공개 테스트**를 거쳐야 프로덕션 메뉴가 열린다 | 프로덕션은 이번 범위 밖(결정 2) |
| 신규 앱은 AAB + **Play 앱 서명** | 업로드 키만 우리가 관리(결정 3) |
| Play Developer API는 **업로드가 한 번도 없는 앱에 올릴 수 없다** | 첫 AAB는 Console에서 손으로(§4.3) |
| 데이터 보안 양식 — SDK가 수집하는 데이터도 앱의 수집으로 신고 | ML Kit 진단 데이터 신고(§4.4) |

## 3. 확정 결정 (브레인스토밍 2026-10-04)

| # | 결정 | 근거 |
|---|---|---|
| 1 | Play 개발자 계정을 **개인 계정으로 새로 만든다** | 사용자에게 계정 없음 |
| 2 | **내부 테스트 트랙까지만**. 프로덕션은 테스터 12명이 모이면 별도 작업 | 사용자가 테스터 확보가 어렵다고 답함. 내부 테스트는 심사 없이 본인 기기에 Play로 설치된다 |
| 3 | **Play 앱 서명 — Google 생성 앱 서명 키 + 우리 업로드 키** | 사용자 기기에 기존 설치본·기록이 없어 서명을 이어받을 이유가 없다. 업로드 키는 잃어도 Play 지원으로 재설정된다 |
| 4 | **접근 A — 태그 → CI가 AAB를 빌드해 내부 테스트에 자동 업로드** | iOS(TestFlight)와 대칭. 태그 하나가 두 스토어로 간다 |
| 5 | 사이드로드 APK(GitHub Release)는 **만들지 않는다** | Play 서명 앱과 서명이 달라 같은 기기에서 충돌한다. 실제로 쓴 적도 없다 |

## 4. 설계

### 4.1 서명

업로드 키는 PKCS12 하나, 별칭 `upload`, 유효기간 10000일. PKCS12는 저장소 비밀번호와 키 비밀번호를 따로 두지 않으므로 비밀번호는 하나다.

GitHub Secrets (4개):

| 이름 | 내용 |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `upload-keystore.p12`의 base64 |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `ANDROID_UPLOAD_KEY_ALIAS` | `upload` |
| `PLAY_SERVICE_ACCOUNT_JSON` | 서비스 계정 JSON 키 전문 |

`build.gradle.kts`는 `android/key.properties`가 있으면 그 값으로 `release` 서명 설정을 만들고, 없으면 지금처럼 debug 키로 서명한다. 로컬 `flutter run --release`가 키 없이도 계속 되게 하기 위해서다. 이 대체 경로가 CI에서 조용히 타면 debug 서명 AAB가 Play로 갈 수 있으므로 **CI는 빌드 직후 서명 인증서를 검사해 `CN=Android Debug`이면 실패한다**(§4.3).

업로드 키 파일과 비밀번호는 **최소 2곳**에 백업한다. 잃어도 복구는 되지만(Play 지원팀에 재설정 요청, 며칠 걸림) 그동안 업데이트가 멈춘다.

### 4.2 빌드 수정

- `android/app/proguard-rules.pro` 신규 — Flutter Gradle 플러그인이 이 파일이 있으면 release 빌드에 자동으로 더한다(`FlutterPlugin.kt`). 내용은 R8이 못 찾은 세 패키지의 `-dontwarn`. 앱은 한국어 인식기만 만들므로 런타임에 이 클래스들에 닿지 않는다.

```
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
```

- `android:label` → `BeanProfile`.
- 버전 — `versionName`은 태그(`v1.0.3` → `1.0.3`), `versionCode`는 `github.run_number`. iOS 잡과 같은 규칙이고 같은 실행 안에서 값이 같다.

### 4.3 CI — `android-gate` + `android` 잡

```
test ──┬── ios ─────────────────────────── (미서명 .ipa → GitHub Release)
       ├── appstore-gate ── appstore ────── (서명 .ipa → TestFlight)
       ├── android-gate ──┐
       └── android-smoke ─┴── android ───── (서명 .aab → Play 내부 테스트)
```

- **`android-gate`** — 시크릿 유무를 출력으로 넘긴다(`secrets`는 잡 수준 `if`에서 못 읽는다 — `appstore-gate`와 같은 이유). 출력 두 개: `sign_ready`(키스토어 3개 존재), `play_ready`(서비스 계정 존재). 태그·수동 실행 모두에서 돈다.
- **`android-smoke`** — 에뮬레이터에서 release 스모크(§4.6). 업로드 키가 필요 없어 시크릿과 무관하게 태그·수동 실행마다 돈다.
- **`android`** — `android-smoke` 성공 + `sign_ready`일 때만. 스모크가 실패하면 Play 업로드도 첫 업로드용 아티팩트도 생기지 않는다. iOS 잡들과 병렬·독립이다.
  1. 키스토어 복원 + `android/key.properties` 생성(러너 임시 파일, 로그에 비밀번호를 찍지 않는다)
  2. `flutter build appbundle --release --build-name --build-number --dart-define=APP_VERSION --dart-define=ENABLE_OCR_DIAGNOSTICS=false` — 진단 기능은 Play 빌드에 싣지 않는다(TestFlight와 같은 규칙)
  3. 서명 검사 — `keytool -printcert -jarfile`로 인증서를 읽어 `Android Debug`가 보이거나 인증서가 없으면 실패
  4. 태그 실행 + `play_ready`: `r0adkll/upload-google-play@v1`(node24)로 `internal` 트랙, `status: completed`, R8 매핑 파일 첨부
  5. 수동 실행(`workflow_dispatch`): 업로드하지 않고 AAB를 아티팩트로 남긴다 — **첫 수동 업로드용**
- 수동 실행은 기존처럼 `build_name`을 받는다. **`/`가 든 브랜치에서 돌리지 않는다** — iOS 잡의 `.ipa` 파일명이 `${GITHUB_REF_NAME}`이라 깨진다(2026-10-04 실측).

### 4.4 개인정보 고지 정정 — ML Kit 진단 데이터

ML Kit 공식 공개 문서에 따르면, 이미지·인식 결과는 기기에서만 처리되고 Google로 가지 않는다. 그러나 **SDK 자체가 Android·iOS 모두에서 다음을 Google로 보낸다**: 기기 정보, 앱 정보(패키지·버전), 설치 단위 식별자, 성능 지표, API 설정, 이벤트 종류, 오류 코드. 목적은 진단·사용 통계, 제3자 공유 없음, 전송 암호화, 끌 수 없음.

지금 공개된 문구가 이와 어긋난다.

| 위치 | 현재 | 문제 |
|---|---|---|
| `docs/privacy.md` 7행 | "어떤 개인정보도 수집하지 않습니다" | ML Kit이 진단 데이터를 보낸다 |
| `docs/privacy.md` 13행 | "네트워크 통신 기능 자체가 들어 있지 않습니다… 분석·추적… 일절 사용하지 않습니다" | `INTERNET` 권한이 있고 ML Kit이 통신한다 |
| `docs/privacy.md` 69행(영문) | "no networking code at all… no … analytics" | 같음 |
| `docs/store-listing.md` 설명 | "서버로 보내는 데이터가 없으며 광고나 분석 도구를 쓰지 않습니다" | 같음 |
| `docs/store-listing.md` 개인정보 절 | "데이터를 수집하지 않습니다"를 선택 | App Store 라벨이 틀리게 제출됨 |
| `docs/store-listing.md` 심사 메모 | "No data leaves the device… no analytics" | 같음 |

정정 원칙 — **사실을 좁게 쓴다.** "사진·기록·인식 결과는 기기를 벗어나지 않는다"는 여전히 참이고 이 앱의 핵심 약속이다. 거기에 "문자 인식에 쓰는 Google ML Kit이 기기·앱 정보와 성능 진단 데이터를 Google로 보낸다(사진·글자는 보내지 않는다), 개발자는 이 데이터를 받지 않는다"를 덧붙인다. "인터넷 없이 동작한다"도 참이므로 유지한다.

Play 데이터 보안 양식 답(ML Kit Android 공개 문서 기준):

| 질문 | 답 |
|---|---|
| 필수 사용자 데이터를 수집·공유하는가 | 예(수집) |
| 전송 중 암호화 | 예 |
| 삭제 요청 수단 | 아니요 |
| 수집 유형 | 앱 정보 및 성능 › 진단 · 기기 또는 기타 ID · 앱 활동 › 앱 상호작용 |
| 각 유형 — 공유 / 일시 처리 / 필수 여부 / 목적 | 공유 안 함 / 아니요 / 필수 / 분석 |

App Store 개인정보 라벨은 **사용자가 App Store Connect에서 직접 고친다**. ML Kit 공개 문서(iOS·Android)는 보내는 데이터만 나열하고 스토어 범주는 정해주지 않는다(2026-10-04 원문 확인). 매핑은 우리 판단이고 **애매하면 넓게 신고한다** — 식별자 › 기기 ID · 사용 데이터 › 제품 상호 작용 · 진단 › 성능 데이터·기타 진단 데이터, 목적 분석. 기능 이벤트(초기화·인식)를 사용 데이터로 보므로 Play에도 앱 상호작용을 신고한다(위 표). 라벨은 새 버전 없이 바로 고칠 수 있다. 스토어 설명 문구는 다음 버전 제출 때 함께 바뀐다.

### 4.5 1회성 셋업 안내서 (사용자)

구현 계획의 별도 문서로 쓴다(`deployment.md` §3 개정). 순서:

1. Play Console 개인 계정 가입($25, 신원 확인 수일)
2. 앱 만들기 — 이름 `BeanProfile`, 기본 언어 한국어, 앱, 무료
3. 업로드 키 생성(Git Bash + Android Studio 내장 `keytool`) → 2곳 백업 → 시크릿 3개 등록
4. `release.yml` 수동 실행 → AAB 아티팩트 다운로드 → Console **내부 테스트**에 업로드(이때 Play 앱 서명이 자동 적용) → 본인 Google 계정을 테스터로 추가 → 출시 → 초대 링크로 기기에 설치
5. 앱 콘텐츠 선언 — 개인정보처리방침 URL, 광고 없음, 앱 액세스(로그인 없음), 콘텐츠 등급(IARC), 대상 연령(13세 미만 제외), 데이터 보안(§4.4 표)
6. 서비스 계정 — Google Cloud 프로젝트 → Play Android Developer API 사용 설정 → 서비스 계정 + JSON 키 → Play Console 사용자로 초대(이 앱 출시 권한) → 시크릿 `PLAY_SERVICE_ACCOUNT_JSON`
7. 이후 `v*` 태그 → 자동 업로드

### 4.6 release 스모크 — 에뮬레이터 자동 검증 (2026-10-05 추가)

사용자 요청 — "에뮬레이터로 테스트를 자동화에서 검증하는 것도". Play로 가는 건 R8을 거친 release 빌드인데, 기존 에뮬레이터 테스트로는 그 빌드를 볼 수 없다(실측).

- `flutter drive`는 release 모드를 거부한다 — `drive_service.dart`: "Flutter Driver (non-web) does not support running in release mode".
- profile 빌드는 `initWith(debug)`라 R8을 돌리지 않는다 — Flutter Gradle 플러그인은 release 빌드 타입만 축소한다(`FlutterPlugin.kt`).

그래서 **진입점만 바꾼 release APK**를 에뮬레이터에서 돌린다. R8은 Java/Kotlin 바이트코드만 다루고 Dart 진입점은 `libapp.so`만 바꾸므로, 플러그인·ML Kit의 R8 결과는 배포 빌드와 같다.

| 구성 | 역할 |
|---|---|
| `integration_test/release_smoke.dart` | 테스트 전용 진입점. 번들 테스트 카드 5장을 실제 ML Kit으로 읽어 기대값과 대조하고, drift를 배포 앱처럼 백그라운드 isolate + 파일 DB로 열어 쓰고 읽는다(앱의 실제 DB는 건드리지 않는다). 결과를 logcat에 `BEANPROFILE_SMOKE` 줄로 남긴다 |
| `integration_test/support/bundled_card_checks.dart` | 카드 5장의 기대값 — `ocr_probe_test.dart`(debug)와 스모크(release)가 공유한다. 한쪽만 고쳐져 "release에서만 깨짐"을 못 가리는 일을 막는다 |
| `scripts/release_smoke.py` | 설치 → 실행 → 결과·크래시·시간 초과 판정. **에뮬레이터가 아니면 거부한다** — 같은 applicationId라 Play 설치본이 있는 폰에서는 서명이 충돌하고, 그걸 풀려고 앱을 지우면 기록이 사라진다(§4.1) |
| CI `android-smoke` 잡 | KVM 에뮬레이터(`reactivecircus/android-emulator-runner@v2`, node24 · API 36 x86_64)에서 스모크. `android` 잡의 `needs`에 들어간다(§4.3) |

로컬에서도 같은 스크립트를 쓴다(AVD `flutter_emulator`, API 36 x86_64). 한계 — 카메라·사진 선택기·화면 흐름은 자동화하지 않는다. 온디바이스 확인(§6의 4)은 남지만 R8 문제는 그 전에 에뮬레이터에서 잡힌다.

## 5. 기각한 대안

| 대안 | 기각 이유 |
|---|---|
| B. CI는 AAB만, 업로드는 손으로 | 매 릴리스 손이 간다. 서비스 계정 설정 20~30분이 아깝지 않다 |
| C. 로컬 빌드 + 수동 업로드 | "태그 하나로 배포" 원칙이 깨지고 키가 한 PC에만 있다 |
| 자체 앱 서명 키를 Play에 업로드(PEPK) | 이어받을 기존 설치본이 없다. Google 생성 키가 분실 위험이 더 작다 |
| 나머지 문자 체계 의존성 추가로 R8 해결 | 쓰지 않는 인식 모델로 앱이 수 MB씩 커진다 |
| R8 끄기 | 앱이 커지고 Flutter 기본값을 거스른다. 문제는 경고 세 줄이다 |
| 조직 계정(테스터 요건 면제) | D-U-N-S·법적 실체가 필요하다. 사용자가 고르지 않음 |
| profile 빌드에 R8을 켜서 기존 `flutter drive` 테스트 재사용 | profile은 debuggable이라 R8이 다른 모드로 돈다 — 배포 빌드와 같다고 볼 수 없다. Flutter의 R8 규칙 파일도 손으로 끌어와야 한다 |
| UI 자동화(Maestro·uiautomator) | 시스템 사진 선택기 화면이 깨지기 쉽고 새 도구가 필요하다 |
| Firebase Test Lab | 계정·결제가 필요하다 |
| 스모크를 로컬에서만 | 태그 전에 사람이 기억해야 한다. 사용자가 CI 게이트를 고름(2026-10-05) |

## 6. 검증 · 완료 기준(DoD)

1. Windows에서 `flutter build appbundle --release` 성공(R8 규칙), `flutter analyze` 0, 기존 테스트 전부 green(`lib/` 무수정)
2. **release 스모크** — 로컬 에뮬레이터에서 6/6 통과(카드 5장 + sqlite), 변이 3개(기대값 틀림 · 프로세스 종료 · 멈춤)는 전부 실패로 판정. 공유 기대값으로 옮긴 `ocr_probe_test`도 debug에서 통과
3. `release.yml` 수동 실행 → `android-smoke` 통과 → `android` 잡이 서명 검사를 통과한 AAB 아티팩트를 남김(업로드 단계는 건너뜀)
4. 사용자가 첫 AAB를 내부 테스트에 올리고 기기에 설치 → **release 빌드에서 카드 스캔 OCR이 동작**(온디바이스 확인 — 카메라·사진 선택기·화면 흐름까지 보는 유일한 방법. R8 문제는 2·3이 먼저 잡는다)
5. 다음 `v*` 태그 → `android-smoke` 통과 후 `android` 잡이 내부 테스트에 자동 업로드(`completed`), 같은 실행에서 iOS 두 경로도 성공 — 2026-10-04에 올린 태그 전용 액션 두 개(`action-gh-release@v3`·`import-codesign-certs@v6`)도 이때 처음 검증된다
6. §4.4 문서 정정 반영, Play 데이터 보안 양식 작성, App Store 라벨 수정(사용자)
7. `deployment.md`(§1 전제, §2 구조, §3 Android 셋업, §5 시크릿, §6-A 키 위험, §6-H release 스모크, §9 체크리스트)와 CLAUDE.md의 배포 규약 정정

## 7. 스코프 밖

- **프로덕션 출시** — 비공개 테스트(12명 × 14일), Play 스토어 등록정보(짧은 설명 80자·전체 설명), 512 아이콘, 1024×500 대표 이미지, 휴대전화 스크린샷. 테스터가 모이면 별도 설계
- **Gradle 8.12 · AGP 8.9.1 · Kotlin 2.1.0 업그레이드** — 지금은 "곧 지원 중단" 경고뿐. 별도 정비 작업
- **네이티브 디버그 기호 업로드** — Play가 경고만 한다
- **Android 16 edge-to-edge 시각 점검** — 내부 테스트 설치 후 화면을 보고 문제가 있으면 별도 수정
- **UI 흐름 자동화**(카메라·사진 선택기·화면 이동) — §4.6 한계. 시스템 UI라 깨지기 쉽다
- **debug 통합 테스트(`ocr_probe_test` 등)를 CI에서 돌리기** — 릴리스 게이트는 release 스모크가 맡는다

## 8. 파일 영향

| 파일 | 변경 |
|---|---|
| `android/app/proguard-rules.pro` | 신규 — `-dontwarn` 3줄 |
| `android/app/build.gradle.kts` | `key.properties`가 있으면 release 서명, 없으면 debug |
| `android/app/src/main/AndroidManifest.xml` | `android:label` → `BeanProfile` |
| `.gitignore` | `android/key.properties`는 이미 있음, 업로드 키 확장자 `*.p12`도 이미 있음 — 확인만 |
| `.github/workflows/release.yml` | `android-gate` · `android-smoke` · `android` 잡 추가, 머리 주석 갱신 |
| `integration_test/release_smoke.dart` | 신규 — release 스모크 진입점(§4.6) |
| `integration_test/support/bundled_card_checks.dart` | 신규 — 번들 카드 5장 기대값(debug 프로브와 공유) |
| `integration_test/ocr_probe_test.dart` | 기대값을 공유 모듈로 옮김(출력 줄은 그대로) |
| `scripts/release_smoke.py` | 신규 — 에뮬레이터 설치·실행·판정, 실기기 거부 |
| `docs/privacy.md` / `.html` | §4.4 정정 |
| `docs/store-listing.md` / `.html` | §4.4 정정 |
| `docs/deployment.md` / `.html` | §6 항목 |
| `CLAUDE.md` | 배포 규약 문장 정정 |

## 출처

- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
- [ML Kit — Prepare for Google Play's data disclosure requirements](https://developers.google.com/ml-kit/android-data-disclosure)
- [ML Kit — Prepare for Apple's App Store data disclosure requirements](https://developers.google.com/ml-kit/ios-data-disclosure)
