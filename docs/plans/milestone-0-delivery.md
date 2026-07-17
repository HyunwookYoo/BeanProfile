# M0 — 배포 파이프라인 (Delivery) 실행 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `v0.0.1` 태그 하나를 push하면 CI(macOS 러너)가 Flutter 앱을 **미서명 `.ipa`** 로 빌드해 GitHub Release에 첨부하고, 그걸 **무료 Apple ID + AltStore**로 아이폰에 설치해 hello‑world 앱이 실제로 실행되게 한다 — 앱이 아직 사소할 때(변수 1개) 전달 경로 전체를 증명한다.

**Architecture:** `flutter create`로 스캐폴드를 만들고(영구 번들 ID `com.hyunwook.beanprofile` 고정), `.github/workflows/release.yml`이 `v*` 태그에서 **test 게이트 → iOS 미서명 `.ipa` 빌드 → GitHub Release 첨부**를 수행한다. CI에는 **Apple 서명 비밀이 하나도 없다** — 서명은 로컬 AltStore(윈도우 PC의 AltServer)가 무료 Apple ID로 담당한다. 사람이 하는 일은 (a) 공개 GitHub 레포 생성/push, (b) 1회성 AltStore 셋업, (c) 릴리스마다 `.ipa` 내려받아 AltStore 설치, (d) 7일마다 갱신.

**Tech Stack:** Flutter (stable), GitHub Actions (`subosito/flutter-action@v2`, `softprops/action-gh-release@v2`), AltStore/AltServer(Windows) + 무료 Apple ID.

## Global Constraints

프로젝트 전역 요구 — 모든 태스크의 요구사항에 암묵적으로 포함된다.

- **개발 머신은 Windows, Mac 없음.** iOS 컴파일은 오직 CI의 macOS 러너에서만 가능. (`docs/deployment.md` §1)
- **번들 ID `com.hyunwook.beanprofile`는 영구.** Task 1의 `flutter create`에서 고정되며 이후 변경 시 양 OS의 앱 데이터가 고아가 됨.
- **GitHub 레포는 반드시 공개(public).** 공개 레포여야 macOS 러너 분(minutes)이 무료.
- **무료 Apple ID 경로: CI에 iOS 서명 비밀 0개.** App Store Connect / TestFlight / `APPSTORE_*` 시크릿 / 배포 인증서(`.p12`) **전부 M0에서 불필요.** 서명은 AltStore가 로컬에서 수행.
- **무료 서명은 7일마다 만료.** 만료 시 앱은 실행 불가(아이콘·데이터는 유지) → AltStore "Refresh All"로 갱신(윈도우 PC + 같은 WiFi 필요). 무료 계정 동시 사이드로드 **최대 3앱**.
- **M0는 iOS 전용.** Android 폴더는 스캐폴드하되 CI/서명/전달에는 연결하지 않음(별도 마일스톤으로 이관 — Android 서명은 Mac 게이트가 아니라 윈도우에서 로컬 디버깅 가능하므로 지금 급할 이유가 없음).
- **서명 비밀은 절대 커밋/대화 붙여넣기 금지.** (M0 무료‑iOS 경로엔 시크릿이 없지만, 향후 Android/유료 경로 대비 원칙 유지.) `.gitignore`가 이미 `*.jks *.p12 *.key ...` 차단 중.
- **스토어 미출시, 완전 오프라인, 로컬 전용.**

## 결정 근거 (요약)

무료(Free Apple ID + AltStore) 경로 확정 — 사유: 아이폰만 보유(Android 기기 없음), 혼자 사용, 개발 지속 불확실 → $99/년 커밋 연기. 자세한 내용·마이그레이션 비용은 agentmemory `BeanProfile` 태그의 2026‑07‑17 결정 및 `docs/deployment.md`(유료/TestFlight 경로의 참조 스펙) 참고. 유료 전환은 **지연이지 중복 아님**이며, 1회성 비용은 서명자 교체 시 아이폰 삭제‑재설치로 로컬 DB가 지워지는 것뿐(§6‑A와 동일 실패 모드).

## File Structure

| 경로 | 동작 | 책임 |
|---|---|---|
| `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`, `ios/`, `android/`, `analysis_options.yaml`, `.metadata` | **생성**(`flutter create` 기본 스캐폴드, 손으로 안 씀) | 실행 가능한 hello‑world(기본 카운터) 앱 + 기본 위젯 테스트 |
| `.github/workflows/release.yml` | **생성** | `v*` 태그 → test 게이트 → iOS 미서명 `.ipa` → GitHub Release |
| `.github/workflows/test.yml` | **수정** | codegen 스텝을 "build_runner 있을 때만"으로 가드(스캐폴드에서 초록 유지) |
| `.gitignore` | **변경 없음** | 이미 Flutter 무시 규칙 + 서명 비밀 차단 완비 |

**M0가 포함하지 않는 것(명시):** Android 빌드/서명 job, TestFlight 업로드, Apple 인증서(`.p12`)·CSR, `APPSTORE_*` 시크릿, `ios/ExportOptions.plist`, `Info.plist`의 `ITSAppUsesNonExemptEncryption`(App Store Connect 업로드가 없으므로 불필요) — 전부 유료 경로 전환 시점으로 이관.

**성격상 주의:** M0는 **기능 코드**가 아니라 **인프라**다. 따라서 기능 단위 TDD(실패 테스트 먼저)가 없다. M0의 "테스트"는 **태그 → 빌드 → 설치 → 실행**의 엔드‑투‑엔드 전달 루프 그 자체다. 각 태스크는 그에 맞는 구체적 검증으로 끝난다. 첫 태그 push가 한 번에 성공하지 않는 것은 **정상이자 M0의 목적**이다(앱이 사소할 때 실패 원인을 격리) — 아래 Troubleshooting 참고.

---

## Task 1: Flutter 앱 스캐폴드 (영구 번들 ID 고정) — [CLAUDE, 실행 전 사용자 확인 필수]

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`, `ios/**`, `android/**`, `analysis_options.yaml`, `.metadata`, `README.md`
- Unchanged: `.gitignore`(기존 유지 확인), `docs/**`, `CLAUDE.md`

**Interfaces:**
- Produces: 루트에 `pubspec.yaml`(name: `beanprofile`), 번들 ID `com.hyunwook.beanprofile`가 `ios/Runner.xcodeproj/project.pbxproj`의 `PRODUCT_BUNDLE_IDENTIFIER`와 `android/app/build.gradle`(또는 `build.gradle.kts`)의 `applicationId`에 박힘. Task 3(release.yml)이 이 스캐폴드를 빌드.

> ⚠️ **이 태스크는 영구 번들 ID를 고정한다.** 실행 직전 사용자에게 `com.hyunwook.beanprofile` 확정을 재확인한다.

- [ ] **Step 1: 번들 ID 확정 재확인**

사용자에게 확인: 번들 ID = `com.hyunwook.beanprofile` (영구, 변경 불가). 확정되면 다음 단계.

- [ ] **Step 2: 스캐폴드 생성**

기존 레포 루트(`C:\BeanProfile`)에서 실행. `docs/`, `CLAUDE.md`, `.gitignore`, `.github/`는 보존됨(flutter create는 기존 파일을 덮지 않음).

```bash
flutter create --org com.hyunwook --project-name beanprofile --platforms=ios,android .
```

- [ ] **Step 3: 기존 `.gitignore` 보존 확인 (방어)**

`flutter create`가 기존 `.gitignore`를 남겨두는지 확인. 서명 비밀 차단 블록이 그대로 있어야 함.

Run: `grep -n "서명 비밀" .gitignore`
Expected: `27:# 서명 비밀 — 절대 커밋 금지 ...` 한 줄 매치. (없으면 `.gitignore`가 덮인 것 → 이전 버전을 git으로 복원: `git checkout -- .gitignore` 후 Flutter 무시 규칙이 이미 있는지 확인 — 원래 파일에 `.dart_tool/ build/` 등 이미 포함됨.)

- [ ] **Step 4: 번들 ID가 양쪽에 정확히 박혔는지 확인**

Run: `grep -rn "com.hyunwook.beanprofile" ios/Runner.xcodeproj/project.pbxproj android/app/`
Expected: iOS `PRODUCT_BUNDLE_IDENTIFIER = com.hyunwook.beanprofile;` (3곳: Debug/Release/Profile), Android `applicationId "com.hyunwook.beanprofile"` (1곳) 매치.

- [ ] **Step 5: 스캐폴드가 정적분석·테스트 통과하는지 확인**

```bash
flutter pub get
flutter analyze
flutter test
```
Expected: analyze `No issues found!`, test `All tests passed!` (기본 `widget_test.dart`의 카운터 증가 테스트).

- [ ] **Step 6: 커밋**

```bash
git add -A
git commit -m "feat(m0): scaffold Flutter app (bundle id com.hyunwook.beanprofile, iOS+Android)"
```

---

## Task 2: `test.yml` codegen 스텝 가드 (스캐폴드에서 초록 유지) — [CLAUDE]

**Files:**
- Modify: `.github/workflows/test.yml:18`

**이유:** 현재 `test.yml`은 `dart run build_runner build`를 무조건 실행하는데, M0 스캐폴드에는 `build_runner` 의존성이 없어(→ drift는 M1) 이 스텝이 "package build_runner not found"로 실패한다. Task 1이 유발하는 이 파손을 정리한다(내가 만든 것만 정리 — CLAUDE.md §3). M1에서 `build_runner`가 들어오면 가드가 자동으로 통과시킨다.

- [ ] **Step 1: 무조건 실행되던 codegen 스텝을 "있을 때만"으로 교체**

`.github/workflows/test.yml`에서 아래 한 줄

```yaml
      - run: dart run build_runner build --delete-conflicting-outputs
```

을 다음으로 교체:

```yaml
      - name: Codegen (drift 등) — 있을 때만
        run: |
          if grep -q "build_runner" pubspec.yaml; then
            dart run build_runner build --delete-conflicting-outputs
          else
            echo "build_runner 미설치 — codegen 건너뜀 (M1에서 활성화)"
          fi
```

- [ ] **Step 2: 가드 로직 로컬 검증(스캐폴드에는 build_runner 없음)**

Run: `grep -q "build_runner" pubspec.yaml && echo RUN || echo SKIP`
Expected: `SKIP` (M0 스캐폴드 기준 — 즉 CI에서 codegen을 건너뛰어 초록 유지). M1에서 build_runner 추가 후엔 `RUN`이 되어 codegen 수행.

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/test.yml
git commit -m "ci(m0): run build_runner only when present (keep test green on bare scaffold)"
```

---

## Task 3: `release.yml` 추가 (test 게이트 → iOS 미서명 .ipa → GitHub Release) — [CLAUDE]

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: Task 1의 스캐폴드(`flutter build ios`가 빌드할 `ios/`), Task 2와 동일한 가드된 codegen 패턴.
- Produces: `v*` 태그 push 시 GitHub Release에 `beanprofile-<tag>.ipa`(미서명) 자산. Task 6/7이 이 자산을 사용.

- [ ] **Step 1: 워크플로 파일 작성**

`.github/workflows/release.yml`:

```yaml
name: release

# BeanProfile 배포 파이프라인 — v* 태그 push 시 실행.
# 무료 Apple ID 경로: CI(macOS 러너)가 "미서명" .ipa를 만들어 GitHub Release에 첨부.
# 서명·설치는 로컬 AltStore가 담당 (CI에 Apple 서명 비밀 없음).
# 규약: docs/deployment.md · 계획: docs/plans/milestone-0-delivery.md
on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write   # GitHub Release 생성/자산 업로드에 필요

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - name: Codegen (drift 등) — 있을 때만
        run: |
          if grep -q "build_runner" pubspec.yaml; then
            dart run build_runner build --delete-conflicting-outputs
          else
            echo "build_runner 미설치 — codegen 건너뜀 (M1에서 활성화)"
          fi
      - run: flutter analyze
      - run: flutter test

  ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - name: Build unsigned iOS app
        run: flutter build ios --release --no-codesign --build-name="${GITHUB_REF_NAME#v}" --build-number="${{ github.run_number }}"
      - name: Package unsigned .ipa
        run: |
          cd build/ios/iphoneos
          mkdir Payload
          cp -r Runner.app Payload/
          zip -qq -r -9 "$GITHUB_WORKSPACE/beanprofile-${GITHUB_REF_NAME}.ipa" Payload
      - name: Publish GitHub Release (+.ipa 자산)
        uses: softprops/action-gh-release@v2
        with:
          name: BeanProfile ${{ github.ref_name }}
          tag_name: ${{ github.ref_name }}
          body: |
            무료 Apple ID(AltStore) 경로용 **미서명** iOS 빌드.
            설치: 아이폰에서 이 .ipa를 내려받아 AltStore → My Apps → + 로 선택하면
            AltStore가 서명해 설치합니다. (PC에서 AltServer 실행 + 같은 WiFi 필요)
          files: beanprofile-${{ github.ref_name }}.ipa
```

> **미서명 .ipa 레시피 근거:** `flutter build ipa --no-codesign`은 xcarchive만 만들고 teamID 없이는 IPA를 못 뽑는다. 신뢰 경로는 `flutter build ios --release --no-codesign`(→ `build/ios/iphoneos/Runner.app`)을 `Payload/`로 감싸 zip하는 것. AltStore가 이 미서명 .ipa를 받아 무료 Apple ID로 재서명한다.
>
> **버전 규약:** `--build-name`=태그에서 `v` 제거(`v0.0.1`→`0.0.1`), `--build-number`=`github.run_number`. ⚠️ **같은 태그로 워크플로를 재실행하면 run_number가 재사용**되니, 새 빌드가 필요하면 태그를 올려라(`v0.0.2`).

- [ ] **Step 2: YAML 유효성 확인**

Run: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml',encoding='utf-8')); print('OK')"`
Expected: `OK`

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/release.yml
git commit -m "ci(m0): add release pipeline (tag -> unsigned iOS .ipa -> GitHub Release)"
```

---

## Task 4: 공개 GitHub 레포 생성 + main push — [HUMAN]

> 브라우저/계정/인증이 필요해 사람만 가능. `gh` CLI가 로그인돼 있으면 아래 명령을, 아니면 GitHub 웹에서 레포 생성 후 remote만 연결.

- [ ] **Step 1: 공개 레포 생성 & push**

`gh` 로그인돼 있으면(세션에서 직접 로그인하려면 프롬프트에 `! gh auth login`):

```bash
gh repo create beanprofile --public --source=. --remote=origin --push
```

또는 웹에서 `beanprofile`(Public) 생성 후:

```bash
git remote add origin https://github.com/<your-username>/beanprofile.git
git push -u origin main
```

- [ ] **Step 2: 확인**

- 레포가 **Public**인지 확인(Settings에서 확인 — macOS 러너 무료 조건).
- **Actions** 탭에 `test` 워크플로가 push로 실행되어 **초록**인지 확인(Task 2 가드 덕에 codegen 건너뛰고 통과). `release` 워크플로는 목록엔 보이되 아직 실행 안 됨(태그 전용).

---

## Task 5: 1회성 AltStore 셋업 (Windows + iPhone) — [HUMAN, 병렬 가능 — 지금 시작해도 됨]

> 레포/CI와 의존성 없음. 다운로드·설치가 있어 시간이 걸리니 일찍 시작 권장. 공식 가이드: <https://faq.altstore.io> (UI가 버전마다 바뀌므로 공식 절차를 최종 기준으로).

- [ ] **Step 1: Apple 사이트판(apple.com) iTunes + iCloud 설치**

⚠️ **반드시 apple.com 다운로드판** — Microsoft Store판 iCloud는 AltServer가 못 찾아 "AltServer couldn't find iCloud" 오류가 난다.
- iTunes: <https://www.apple.com/itunes/download/win64>
- iCloud for Windows: apple.com 지원 페이지의 데스크톱 다운로드판.

- [ ] **Step 2: AltServer 설치 & 관리자 실행**

- <https://altstore.io> 에서 AltServer for Windows 설치.
- **관리자 권한으로 실행** → 시스템 트레이에 AltServer 아이콘.

- [ ] **Step 3: 아이폰 연결 & AltStore 설치**

- USB로 아이폰 연결 → 아이폰에서 "이 컴퓨터를 신뢰" 승인.
- iTunes에서 이 기기의 **"Wi‑Fi 동기화" 활성화**(이후 무선 갱신용).
- 트레이 AltServer 아이콘 → **Install AltStore → (기기 선택)** → **무료 Apple ID** 로그인.

- [ ] **Step 4: 개발자 프로파일 신뢰**

아이폰: 설정 → 일반 → **VPN 및 기기 관리** → 본인 Apple ID 개발자 앱 → **신뢰**.

- [ ] **Step 5: 확인**

아이폰에서 **AltStore 앱이 열리고**, 로그인된 Apple ID가 표시되는지 확인.

---

## Task 6: 첫 릴리스 — `v0.0.1` 태그 → CI 빌드 → Release에 .ipa — [CLAUDE 태그 생성 + HUMAN CI 관찰]

**의존:** Task 3(release.yml) + Task 4(레포 push) 완료 후.

- [ ] **Step 1: 태그 생성 & push**

```bash
git tag v0.0.1
git push origin v0.0.1
```

- [ ] **Step 2: CI 확인**

- Actions → `release` 실행에서 `test` → `ios` job이 **초록**.
- Releases 페이지에 **`BeanProfile v0.0.1`** 릴리스와 **`beanprofile-v0.0.1.ipa`** 자산이 있는지 확인.
- 실패 시 Troubleshooting 참고 후 태그를 올려(`v0.0.2`) 재시도.

---

## Task 7: 아이폰에 AltStore로 설치 → 앱 실행 (M0 완료조건) — [HUMAN]

**의존:** Task 5(AltStore 셋업) + Task 6(.ipa 자산) 완료. **PC에서 AltServer 실행 중 + 아이폰과 같은 WiFi.**

- [ ] **Step 1: 아이폰에서 .ipa 내려받기**

아이폰 Safari로 GitHub Release 페이지 → `beanprofile-v0.0.1.ipa` 다운로드 → "파일"앱에 저장.

- [ ] **Step 2: AltStore로 설치**

AltStore 앱 → **My Apps** 탭 → 좌상단 **`+`** → 방금 받은 `.ipa` 선택 → AltStore가 무료 Apple ID로 **서명·설치**(App ID 자동 등록; 무료 계정은 7일당 App ID 10개 한도).

- [ ] **Step 3: (필요 시) 프로파일 신뢰 후 실행**

설정 → 일반 → VPN 및 기기 관리에서 신뢰(이미 Task 5에서 했으면 생략) → 홈 화면에서 **BeanProfile 앱 실행**.

- [ ] **Step 4: 확인 (✅ M0 DoD)**

아이폰에서 **BeanProfile(기본 카운터) 앱이 실행**되면 M0 완료 — 태그 push → CI 빌드 → 아이폰 설치·실행의 전달 경로 전체가 증명됨.

---

## Task 8: 7일 갱신 (상시) — [HUMAN, 반복]

- [ ] **매 ≤7일마다:** 아이폰을 PC와 같은 WiFi에 두고(AltServer 실행 중) AltStore → **Refresh All**. 놓쳐서 만료되면 앱이 안 열릴 뿐 데이터는 유지 — 갱신하면 되살아남. (삭제‑재설치는 로컬 DB를 지우므로 지양.)

---

## Troubleshooting (첫 태그가 한 번에 안 될 때 — 정상)

| 증상 | 원인/조치 |
|---|---|
| `ios` job이 `flutter build ios`에서 실패 | macos 러너 Xcode/Flutter 조합 문제. `subosito/flutter-action@v2`에 `flutter-version` 핀 고정을 검토(재현성). CocoaPods 관련이면 로그의 `pod install` 구간 확인. |
| `.ipa` 첨부는 됐는데 AltStore가 설치 거부 | (a) PC에서 AltServer 미실행 또는 다른 WiFi, (b) 무료 App ID 주간 10개 한도 소진, (c) iCloud가 MS Store판(→ Apple 사이트판 재설치), (d) 아이폰 미신뢰. |
| 설치는 됐는데 7일 뒤 안 열림 | **정상**(무료 서명 만료). AltStore Refresh All. 데이터는 보존. |
| Package 스텝에서 `Runner.app` 못 찾음 | 경로 확인: `find build/ios -name Runner.app`. 표준 위치는 `build/ios/iphoneos/Runner.app`(본 레시피 기준). 다른 위치면 zip 대상 경로만 조정. |
| `test` job이 codegen에서 실패 | Task 2 가드가 적용됐는지 확인(`build_runner` 없을 때 건너뜀). |
| 같은 태그 재실행인데 버전이 그대로 | `github.run_number` 재사용. 새 태그(`v0.0.2`)로 올릴 것. |

## 향후(유료 전환 시) 추가될 것 — M0 범위 밖

`docs/deployment.md` §4/§5/§8이 참조 스펙: Apple 배포 인증서(`.p12`, OpenSSL 경로) + `APPSTORE_*` 시크릿 + `ios/ExportOptions.plist` + `Info.plist`의 `ITSAppUsesNonExemptEncryption=false`, 그리고 `release.yml`의 `ios` job을 TestFlight 업로드로 교체. Android는 keystore + 4개 시크릿 + APK 서명 job을 별도 마일스톤에서.
