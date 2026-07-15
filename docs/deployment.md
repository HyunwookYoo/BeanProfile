# BeanProfile 배포 규약

목표: **`v*` 태그를 푸시하면 내 안드로이드 폰과 아이폰에 앱이 설치된다.**
관련: 설계 [`design.md`](design.md) · 로드맵 [`plans/roadmap.md`](plans/roadmap.md) · 테스트 [`testing.md`](testing.md)

---

## 1. 전제 — 왜 이런 모양인가

확정된 개발 환경이 설계를 강하게 제약한다.

| 조건 | 결과 |
|---|---|
| **개발 머신이 Windows** (맥 없음) | 로컬 iOS 빌드 **불가**. Xcode·시뮬레이터·핫리로드·브레이크포인트 전부 없음 |
| **Apple Developer Program 가입** ($99/년) | 유료 멤버십이라 App Store Connect API 사용 가능 → **iOS 자동 배포가 성립** |
| **GitHub 저장소 public** | macOS 러너 **무제한 무료** (private이면 10배 과금 → 실질 200분/월) |
| **스토어 출시 안 함** | Play Store/App Store 심사 없음. 사이드로드 APK + TestFlight 내부 테스트 |

여기서 핵심 인식 하나:

> **안드로이드에게 CI는 "편의"지만, iOS에게 CI는 "유일한 방법"이다.**
> 안드로이드는 Windows에서 `flutter build apk` 후 USB로 넣으면 그만이다.
> iOS는 맥이 없으면 아이폰에 앱을 넣을 수단 자체가 없다. **CI의 macOS 러너가 곧 빌린 맥이다.**

그래서 이 파이프라인이 안 뚫리면 iOS는 존재하지 않는다. 이게 M0를 최우선에 두는 이유다(§7).

---

## 2. 파이프라인 구조

```
git tag v0.0.1 && git push origin v0.0.1
        │
        ▼
   test (ubuntu) ─── analyze + flutter test    ← 게이트
        │ 통과해야만
        ├──────────────────┬──────────────────┐
        ▼                  ▼
   android (ubuntu)    ios (macos)             ← 병렬 · 서로 독립
   APK 빌드             IPA 빌드
   → GitHub Release    → TestFlight
```

- **테스트 게이트를 앞에 둔다.** 태그가 가리키는 커밋의 테스트가 통과했다는 보장이 없다. Linux 잡이라 공짜고 ~3분이다. 깨진 빌드를 폰에 올리는 것보다 압도적으로 싸다.
- **Android/iOS는 병렬이고 독립이다.** iOS 서명이 터져도 Android APK는 정상 릴리스된다. 초반에 iOS를 뚫는 동안 이게 실질적으로 도움이 된다.

### 버저닝

태그 `v1.2.3` → `--build-name=1.2.3`, `--build-number=<github.run_number>`.

빌드 번호는 **반드시 단조 증가**해야 한다. TestFlight는 중복 번호를 거부하고, Android `versionCode`도 역행할 수 없다. `run_number`는 워크플로 실행마다 증가하므로 조건을 만족한다.

> ⚠️ **함정:** 실패한 워크플로를 **re-run 하면 `run_number`가 유지**된다 → TestFlight가 중복으로 거부한다.
> 실패했으면 re-run 하지 말고 **태그를 올려서**(`v0.0.2`) 다시 밀 것.

---

## 3. 1회성 셋업 — Android (~10분)

> 이 문서의 셸 명령은 **Git Bash**(Git for Windows 동봉) 기준이다. `keytool`은 JDK, `base64`/`openssl`은 Git Bash에 들어 있다. PowerShell에는 `base64`가 없으므로 Git Bash에서 실행할 것.

```bash
keytool -genkey -v -keystore beanprofile.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias beanprofile
base64 -w 0 beanprofile.jks > beanprofile.jks.base64   # → Secret에 붙여넣기
```

`android/app/build.gradle`(또는 최신 Flutter가 생성하는 `.kts`)에 Flutter 공식 문서의 서명 설정을 넣어 `key.properties`를 읽게 한다. CI가 그 파일을 런타임에 만들어준다.

**키스토어와 비밀번호는 최소 2곳에 백업한다. 이유는 §6.**

---

## 4. 1회성 셋업 — Apple (~1~2시간)

맥 없이 **브라우저 + 아이폰 + Windows의 OpenSSL**로 전부 가능하다.

| # | 할 일 | 어디서 |
|---|---|---|
| 1 | Developer Program 가입 ($99/년) | 아이폰 Apple Developer 앱 또는 웹 |
| 2 | App ID 생성 — **`com.hyunwook.beanprofile`** (확정, §4 하단 참고) | developer.apple.com |
| 3 | 배포 인증서 → `.p12` | **Windows / OpenSSL** (아래) |
| 4 | Provisioning Profile (App Store 배포용) | developer.apple.com |
| 5 | App Store Connect **API 키** (`.p8`, App Manager 역할) | App Store Connect → Users and Access → Integrations |
| 6 | 앱 레코드 생성 (App ID 연결) | App Store Connect |

> 🔒 **번들 ID `com.hyunwook.beanprofile`은 영구값이다.** Apple App ID이자 Android `applicationId`로 굳는다.
> 나중에 바꾸면 **양쪽 OS 모두 "다른 앱"으로 취급** → 기존 앱 위에 설치 불가 → 삭제 후 재설치 → **시음 기록 소실**. iOS는 App Store Connect 레코드도 새로 만들어야 한다.
> **2번을 하기 전에 확정할 것.** (`flutter create --org com.hyunwook --project-name beanprofile`과 반드시 일치)

### 3번 — 맥 없이 인증서 만들기

보통 Keychain Access(맥)로 하는 CSR 생성을 OpenSSL로 대체한다.

```bash
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=hyunwook5636@gmail.com/CN=hyunwook/C=KR"
# → developer.apple.com에 ios_dist.csr 업로드 → dist.cer 다운로드
openssl x509 -inform DER -in dist.cer -out dist.pem
openssl pkcs12 -export -inkey ios_dist.key -in dist.pem -out dist.p12
base64 -w 0 dist.p12 > dist.p12.base64
```

**인증서는 1년짜리다. 연 1회 갱신이 필요하다(§6).**

> **6번 주의:** App Store Connect의 앱 이름은 **App Store 전체에서 유일**해야 한다. `BeanProfile`이 선점돼 있으면 다른 이름으로 등록한다(앱 내 표시명과 무관).

### 대안 (지금은 채택 안 함)

- **`fastlane match`** — 인증서를 별도 private 저장소에 암호화 보관. 팀 협업용이라 1인 개발엔 오버킬.
- **Codemagic** — Flutter 특화 CI. API 키만 주면 인증서·프로파일을 **자동 관리**한다. 맥 없는 개발자에겐 확실히 편하다.

**GitHub Actions + 수동 1회 발급을 택한 이유:** 새 CI 플랫폼을 배우는 비용보다 "1년에 한 번 30분"이 싸고, 이미 `test.yml`이 Actions에 있어 한 곳에 모인다.
**단, 3번에서 며칠씩 늪에 빠지면 Codemagic으로 갈아타는 게 합리적인 탈출구다.** 매몰비용에 빠지지 말 것.

---

## 5. GitHub Secrets

| Secret | 내용 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `.jks`의 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `ANDROID_KEY_ALIAS` | 키 별칭 (`beanprofile`) |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 |
| `IOS_DIST_CERT_P12_BASE64` | `.p12`의 base64 |
| `IOS_DIST_CERT_PASSWORD` | `.p12` export 시 지정한 암호 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`의 base64 |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| `APPSTORE_KEY_ID` | API 키 ID |
| `APPSTORE_PRIVATE_KEY` | `.p8` 파일 **내용 전체** |

**저장소에 절대 커밋되면 안 되는 것** — `.gitignore`에 추가:

```
*.jks
*.p12
*.p8
*.mobileprovision
*.csr
*.key
android/key.properties
```

---

## 6. 운영 리스크 — 이 앱에 특유한 것

### A. 키스토어가 곧 시음 기록이다 🔑

안드로이드는 **서명이 다르면 기존 앱 위에 설치가 안 된다** → 삭제 후 재설치 → **삭제하는 순간 앱 데이터가 지워진다**. 그런데 이 앱은 설계상 **로컬 전용 + 클라우드 백업 없음**이고, JSON 내보내기는 **M5**(마지막)다.

> **키스토어 분실 = 그때까지 쌓은 시음 기록 전부 소실. 복구 수단 없음.**
> **M1~M4 동안에는 백업 수단이 아예 없다.**

- **필수(지금):** `.jks` + 비밀번호를 **최소 2곳**에 백업(비밀번호 관리자 + 외장/클라우드). 이거 하나로 실질 리스크가 거의 사라진다.
- **재판단(M2):** M5의 JSON export 앞당기기. **지금 결정하지 않는다** — M2에서 시음 기록이 실제로 쌓이기 시작할 때 다시 본다. 지금 당기면 스코프 크리프다.

### B. TestFlight는 90일마다 만료된다 ⏳

TestFlight 빌드는 **업로드 90일 후 만료**되고, 만료되면 아이폰에서 **앱이 열리지 않는다**. 새 빌드를 올리면 되살아나고 **데이터는 유지**된다(앱을 삭제하지만 않으면).

| 시기 | 부담 |
|---|---|
| **개발 중(M0~M5)** | 무해. 어차피 90일보다 훨씬 자주 태그를 민다 |
| **개발 종료 후** | **3개월마다 태그 한 번** (`git tag v1.0.1 && git push --tags`, 20분 대기). 앱이 안 열리는 게 알람 역할 |
| **매년** | 배포 인증서 갱신(§4-3). 안 하면 태그를 밀어도 빌드가 실패한다 |

**탈출구(지금은 안 만듦):** ad-hoc 배포는 프로파일이 **1년**이라 세금이 1/4로 준다. 대신 UDID 등록 + `manifest.plist`를 HTTPS에 호스팅해 OTA 링크를 만들어야 해서 설치 경로가 훨씬 번거롭다. **90일 세금이 실제로 거슬릴 때** 꺼내 쓸 것(YAGNI).

### C. 자동화를 진짜 무인으로 만들려면

`ios/Runner/Info.plist`에 다음을 넣는다:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

없으면 **빌드마다 App Store Connect 웹에서 수출 규정 질문에 손으로 답해야** 테스터에게 풀린다. 태그 자동화가 거기서 멈추므로 반드시 넣는다.

---

## 7. 로드맵 편입 — M0 신설

파이프라인은 `flutter create` 직후에 뚫는다. 이유:

> **서명을 뚫는 난이도는 앱이 hello world든 완성품이든 똑같다**(서명은 앱 코드와 무관하니까).
> 그런데 **실패 원인을 분리하는 난이도는 앱이 복잡할수록 폭증한다.**
> 맥이 없어서 **빨간 CI 로그만 보고** 뚫어야 하므로, 변수가 1개일 때(=hello world) 뚫는 게 압도적으로 유리하다.

덤으로 "iOS가 예상 못한 이유로 막힌다"를 **M1 이전에** 알게 된다. 5개 마일스톤을 다 만들고 나서 iOS가 안 되는 게 최악의 시나리오다.

| | 완료 시 동작하는 것 | 검증 |
|---|---|---|
| **M0** | GitHub public 저장소 · `flutter create` · 서명 셋업 · `release.yml` | **`v0.0.1` 태그 → 안드로이드 폰 + 아이폰에 hello world가 설치되어 실행됨** |

`flutter create`는 원래 M1 Task 1이었으나 **M0로 이관**한다. M1 한복판에 배포를 끼우면 *"각 마일스톤은 그 자체로 동작하고 검증 가능한 증분"* 원칙이 깨진다. M0도 그 기준을 정확히 만족한다.

이후 **M1~M5는 태그만 밀면 폰에 뜬다.**

---

## 8. `release.yml` 참고 구현

> **아직 저장소에 넣지 않는다.** `android/`·`ios/` 디렉터리가 없어서(=`flutter create` 미실행) 지금 넣으면 죽은 코드다. **M0에서 실물로 만든다.**
> 아래는 검증된 참고 구현이며, 패키지·액션 최신 API에 맞춰 사소한 조정이 필요할 수 있다(M1 계획서와 같은 규약).

```yaml
name: release

# BeanProfile 배포 — v* 태그 → Android APK(GitHub Release) + iOS(TestFlight).
# 설계/셋업: docs/deployment.md
on:
  push:
    tags: ['v*']

permissions:
  contents: write        # GitHub Release 생성용

jobs:
  test:                  # 게이트 — 깨진 빌드를 폰에 올리지 않는다
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test

  android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs

      - name: 키스토어 복원
        env:
          KEYSTORE_B64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: echo "$KEYSTORE_B64" | base64 -d > android/app/beanprofile.jks

      - name: key.properties 작성
        env:
          STORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          cat > android/key.properties <<EOF
          storeFile=beanprofile.jks
          storePassword=$STORE_PASSWORD
          keyAlias=$KEY_ALIAS
          keyPassword=$KEY_PASSWORD
          EOF

      - name: APK 빌드
        run: |
          flutter build apk --release \
            --build-name=${GITHUB_REF_NAME#v} \
            --build-number=${{ github.run_number }}

      - uses: softprops/action-gh-release@v2
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
          generate_release_notes: true

  ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs

      - uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.IOS_DIST_CERT_P12_BASE64 }}
          p12-password: ${{ secrets.IOS_DIST_CERT_PASSWORD }}

      - name: 프로비저닝 프로파일 설치
        env:
          PROFILE_B64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROFILE_B64" | base64 -d \
            > ~/Library/MobileDevice/Provisioning\ Profiles/beanprofile.mobileprovision

      - name: IPA 빌드
        run: |
          flutter build ipa --release \
            --build-name=${GITHUB_REF_NAME#v} \
            --build-number=${{ github.run_number }} \
            --export-options-plist=ios/ExportOptions.plist

      # IPA 파일명은 Xcode 제품명을 따라가므로 하드코딩하지 않는다 (§8 주의)
      - name: IPA 경로 확인
        run: echo "IPA_PATH=$(ls build/ios/ipa/*.ipa | head -1)" >> "$GITHUB_ENV"

      - uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: ${{ env.IPA_PATH }}
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
```

> ⚠️ **IPA 이름을 하드코딩하지 말 것.** `flutter build ipa`는 Xcode 제품명으로 파일명을 짓는다(`beanprofile.ipa` 등). 하드코딩하면 업로드 스텝에서 파일을 못 찾고 실패하는데, 맥이 없으면 이걸 CI 로그로만 진단해야 해서 시간을 크게 잡아먹는다. 위처럼 `ls`로 찾아서 넘긴다.

### `ios/ExportOptions.plist` (커밋함 — 비밀 아님)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>          <string>app-store</string>
  <key>teamID</key>          <string>TEAM_ID</string>
  <key>signingStyle</key>    <string>manual</string>
  <key>uploadSymbols</key>   <true/>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.hyunwook.beanprofile</key>
    <string>PROFILE_NAME</string>
  </dict>
</dict>
</plist>
```

`TEAM_ID`·`PROFILE_NAME`·번들 ID는 M0에서 실제 값으로 채운다. 최신 Xcode는 `method`로 `app-store-connect`를 선호하므로 경고가 뜨면 교체한다.

---

## 9. 릴리스 체크리스트

- [ ] `flutter analyze && flutter test` 로컬 초록불
- [ ] 커밋 & 푸시 (main)
- [ ] `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] Actions에서 `test` → `android`/`ios` 초록불 확인
- [ ] 안드로이드: GitHub Release에서 APK 받아 설치
- [ ] iOS: TestFlight 앱에서 업데이트 확인 (업로드 후 처리에 5~15분)
- [ ] 실패 시 **re-run 하지 말고** 태그를 올려서 다시 푸시 (§2 함정)
