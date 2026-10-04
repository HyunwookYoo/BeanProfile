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
| **스토어 배포 범위** | Android는 Play **내부 테스트**(심사 없음, 본인 기기). iOS는 TestFlight + AltStore 사이드로드. Play 프로덕션은 개인 계정의 테스터 12명 × 14일 요건 때문에 별도 작업(`plans/android-play-release-design.md` §7) |

여기서 핵심 인식 하나:

> **안드로이드에게 CI는 "편의"지만, iOS에게 CI는 "유일한 방법"이다.**
> 안드로이드는 Windows에서도 빌드된다(단, Play로 설치한 폰에는 로컬 빌드를 넣지 않는다 — §6-A).
> iOS는 맥이 없으면 아이폰에 앱을 넣을 수단 자체가 없다. **CI의 macOS 러너가 곧 빌린 맥이다.**

그래서 이 파이프라인이 안 뚫리면 iOS는 존재하지 않는다. 이게 M0를 최우선에 두는 이유다(§7).

---

## 2. 파이프라인 구조

```
git tag v1.0.3 && git push origin v1.0.3
        │
        ▼
   test (ubuntu) ─── analyze + flutter test       ← 게이트
        │ 통과해야만
        ├── ios (macos) ─────────────────────── 미서명 .ipa → GitHub Release (AltStore)
        ├── appstore-gate ── appstore (macos) ── 서명 .ipa → TestFlight
        ├── android-gate ──┐
        └── android-smoke ─┴─ android (ubuntu) ─ 서명 .aab → Play 내부 테스트
              (에뮬레이터 release 스모크 — 실패하면 android가 돌지 않는다)
```

- **테스트 게이트를 앞에 둔다.** 태그가 가리키는 커밋의 테스트가 통과했다는 보장이 없다. Linux 잡이라 공짜고 ~3분이다. 깨진 빌드를 폰에 올리는 것보다 압도적으로 싸다.
- **세 경로는 병렬이고 독립이다.** iOS 서명이 터져도 Android AAB는 정상 업로드되고, 그 반대도 같다.
- **`android-smoke`가 Play로 가는 문을 지킨다.** 에뮬레이터에서 release 빌드를 돌려 보고(§6-H) 실패하면 `android`가 아예 돌지 않는다 — 업로드도 아티팩트도 없다.
- **게이트 잡이 시크릿 유무를 출력으로 넘긴다.** `secrets`는 잡 수준 `if`에서 못 읽기 때문이다. 시크릿이 없으면 그 경로만 건너뛰고 `::notice::`를 남긴다 — 셋업 도중에 태그를 밀어도 나머지 경로는 돈다.
- **Android 잡은 Flutter를 3.44.6에 고정한다.** stable(3.47 이상)은 Gradle 8.14 미만을 거부하는데 이 프로젝트는 8.12다(2026-10-05 CI 실측). R8 빌드와 스모크를 로컬에서 검증한 버전과 같게 맞춘 것이다. `test`·iOS 잡은 stable 그대로다. **Flutter를 올리기 전에(로컬·CI 모두) Gradle·AGP·Kotlin 정비가 먼저다** — 정비가 끝나면 이 고정을 푼다.

### 버저닝

태그 `v1.2.3` → `--build-name=1.2.3`, `--build-number=<github.run_number>`.

빌드 번호는 **반드시 단조 증가**해야 한다. TestFlight는 중복 번호를 거부하고, Android `versionCode`도 역행할 수 없다. `run_number`는 워크플로 실행마다 증가하므로 조건을 만족한다.

> ⚠️ **함정:** 실패한 워크플로를 **re-run 하면 `run_number`가 유지**된다 → TestFlight가 중복으로 거부한다.
> 실패했으면 re-run 하지 말고 **태그를 올려서**(`v0.0.2`) 다시 밀 것.

설정 화면의 버전 표시도 **같은 `BUILD_NAME`에서 나온다** — 워크플로가
`--dart-define=APP_VERSION="$BUILD_NAME"`으로 주입하고, `kAppVersion`이
`String.fromEnvironment`로 읽는다. 릴리스 때 **손으로 올릴 상수는 없다.**
주입이 없는 로컬 빌드는 `dev`로 표시된다.

> M5는 `package_info_plus`를 피하려고 버전을 손으로 관리하는 상수로 뒀는데,
> 태그와 아무 연결이 없어 `v0.6.1`~`v0.6.12`가 **12번 연속** `v0.6.0`으로 표시됐다.
> 사람이 기억해야 하는 릴리스 단계는 만들지 않는다.

### OCR 개발자 진단 빌드

`OCR 진단 복사`는 일반 release 빌드에서 숨긴다. 로컬 debug 빌드에서는 자동으로
표시되고, iPhone에서 다시 필요할 때만 GitHub Actions의 **release → Run workflow**를
수동 실행한다.

1. 실행할 브랜치를 선택한다.
2. `build_name`에 현재 앱 버전(예: `0.6.11`)을 입력한다.
3. 완료 후 실행 결과의 Artifacts에서 `beanprofile-diagnostic-*`를 내려받는다.
4. 압축 안의 미서명 IPA를 AltStore로 설치한다.

수동 실행은 `ENABLE_OCR_DIAGNOSTICS=true`를 전달하며 Artifact를 7일 보관한다.
일반 `v*` 태그 실행은 같은 플래그를 `false`로 고정하고 기존 GitHub Release만 만든다.
진단 IPA를 일반 릴리스 자산으로 게시하지 않는다.

같은 수동 실행이 Android AAB도 만든다. 진단 기능은 **꺼진 채로**(Play로 갈 수 있는 빌드이므로) `beanprofile-aab-<실행 번호>` 아티팩트로 남는다. 첫 Play 업로드(§3-4)가 이 경로를 쓴다.

---

## 3. 1회성 셋업 — Android / Google Play

> 이 문서의 셸 명령은 **Git Bash**(Git for Windows 동봉) 기준이다. `base64`는 Git Bash에 들어 있고, `keytool`은 PATH에 없으므로 Android Studio 내장 JDK의 것을 경로째 쓴다.

순서가 중요하다. **첫 AAB는 Play Console에서 손으로 올린다** — Play Developer API는 업로드가 한 번도 없는 앱에 올리지 못한다. **서비스 계정 시크릿은 맨 마지막에 넣는다** — 그 시크릿이 들어가는 순간부터 태그가 자동 업로드를 시도하는데, 앱이 아직 '초안'이면 `Only releases with status draft may be created on draft app`으로 거부된다.

### 3-1. Play Console 개인 계정

play.google.com/console에서 **개인** 계정으로 가입한다(등록비 $25). 신원 확인이 끝나야 앱을 만들 수 있다(수일). Play Console 앱으로 Android 기기 접근 확인을 요구할 수 있다.

### 3-2. 앱 만들기

앱 이름 `BeanProfile` · 기본 언어 한국어 · 앱 · 무료. 패키지 이름은 첫 AAB가 정한다 — `com.hyunwook.beanprofile`(영구값, §4 하단).

### 3-3. 업로드 키 → 시크릿 3개

키는 **저장소 밖**에 만든다. `.gitignore`가 `*.p12`를 막지만 거기에 기대지 않는다.

```bash
KEYTOOL="C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe"
mkdir -p ~/beanprofile-keys && cd ~/beanprofile-keys
"$KEYTOOL" -genkeypair -v -keystore upload-keystore.p12 -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -dname "CN=BeanProfile Upload"
# 비밀번호를 두 번 묻는다. PKCS12는 키 비밀번호가 저장소 비밀번호와 같다.
```

비밀번호는 ASCII 문자(영문·숫자·기호)로만 만들고 `\`와 앞뒤 공백은 쓰지 않는다 — CI가 만드는 `key.properties`는 Java properties 형식이라 ISO-8859-1로 읽혀 한글 같은 문자는 깨지고, `\`는 이스케이프로 읽히며, 값 앞의 공백은 버려진다. 어긋나면 서명 단계에서 비밀번호 오류로 멈춘다(debug 키로 새지는 않는다).

시크릿 세 개를 등록한다. 비밀번호는 `gh`가 프롬프트로 받으므로 셸 기록에 남지 않는다.

```bash
cd ~/beanprofile-keys
base64 -w 0 upload-keystore.p12 | gh secret set ANDROID_UPLOAD_KEYSTORE_BASE64 -R HyunwookYoo/BeanProfile
gh secret set ANDROID_UPLOAD_KEYSTORE_PASSWORD -R HyunwookYoo/BeanProfile
gh secret set ANDROID_UPLOAD_KEY_ALIAS -R HyunwookYoo/BeanProfile --body upload
```

`upload-keystore.p12`와 비밀번호를 **최소 2곳**에 백업한다(비밀번호 관리자 + 외장/클라우드). 잃어도 기록은 무사하지만(§6-A) Play 지원팀의 업로드 키 재설정(수일)을 기다리는 동안 업데이트가 멈춘다.

### 3-4. 첫 AAB — 수동 실행 → Console 내부 테스트

`build_name`에는 다음 태그로 낼 버전을 넣는다. 아티팩트의 AAB는 에뮬레이터 스모크(§6-H)와 서명 검사를 통과한 것이다. 같은 폴더에 R8 매핑 파일(`mapping.txt`)도 함께 내려받아진다 — 크래시 스택을 풀 때 쓴다.

> ⚠️ **로컬에서 만든 AAB를 올리지 않는다.** 처음 올린 AAB에 서명한 키가 그대로 업로드 키로 등록된다. 로컬 빌드는 `key.properties`가 없으면 debug 키로 서명되고, Play는 debug 서명을 받지 않는다.

```bash
cd /c/BeanProfile
gh workflow run release.yml --ref main -f build_name=1.0.3
gh run list --workflow release.yml --event workflow_dispatch --limit 1 --json databaseId,status,createdAt   # 방금 만든 실행인지 createdAt·status로 확인(나타나기까지 몇 초 걸린다)
gh run watch <실행 ID> --exit-status
gh run download <실행 ID> --pattern 'beanprofile-aab-*' --dir build/play-first-upload
find build/play-first-upload -name '*.aab'
```

1. Play Console → 테스트 및 출시 → 테스트 → **내부 테스트** → 새 버전 만들기
2. 앱 서명 키 선택이 나오면 **Google에서 생성한 키**(기본값)를 고른다 — Play 앱 서명
3. 위에서 찾은 `app-release.aab`를 올린다 → 출시 노트 → 다음 → 저장 → **내부 테스트로 출시 시작**
4. 테스터 탭 → 이메일 목록 만들기 → 폰에 로그인된 본인 Google 계정 추가 → 저장
5. 테스터 탭의 **참여 링크**를 폰에서 열어 테스터로 참여 → Play 스토어에서 설치

### 3-5. 앱 콘텐츠 선언

Play Console → 정책 및 프로그램 → 앱 콘텐츠. 대시보드의 '앱 설정' 할 일이 남아 있으면 앱이 '초안'에서 벗어나지 못한다.

| 항목 | 답 |
|---|---|
| 개인정보처리방침 | `https://hyunwookyoo.github.io/BeanProfile/privacy.html` |
| 광고 | 광고 없음 |
| 광고 ID(Advertising ID) | 사용 안 함 — 합쳐진 매니페스트에 `com.google.android.gms.permission.AD_ID` 권한이 없다 |
| 앱 액세스 | 제한 없이 모든 기능 사용 가능(로그인 없음) |
| 콘텐츠 등급 | IARC 설문 — 폭력·성적 콘텐츠·약물·도박·사용자 간 상호작용 전부 "아니요" |
| 타겟층 | 13세 이상 연령대만 선택(13세 미만을 고르면 가족 정책 대상이 된다) |
| 데이터 보안 | [`store-listing.md`](store-listing.md) 「Google Play 데이터 보안 (Data safety)」 표 그대로 |
| 그 밖의 선언(정부 앱·금융 기능·건강 등) | 해당 없음 |

### 3-6. 서비스 계정 → 시크릿 `PLAY_SERVICE_ACCOUNT_JSON` (마지막)

1. Google Cloud Console → 새 프로젝트(예: `beanprofile-play`) → API 및 서비스 → 라이브러리 → **Google Play Android Developer API** 사용 설정
2. IAM 및 관리자 → 서비스 계정 → 만들기(역할 부여 없이) → 만든 계정 → 키 → 키 추가 → **JSON** → 내려받기
3. Play Console → 사용자 및 권한 → 새 사용자 초대 → 서비스 계정 이메일 → 앱 권한에 BeanProfile 추가 → **테스트 트랙에 앱 출시** 권한 → 초대
4. 아래 명령으로 시크릿을 등록한 뒤 내려받은 JSON을 지운다 — GitHub Secret에만 남긴다. 다시 필요하면 키를 새로 만든다.

```bash
gh secret set PLAY_SERVICE_ACCOUNT_JSON -R HyunwookYoo/BeanProfile < ~/Downloads/<내려받은-키>.json
```

권한이 반영되기까지 시간이 걸릴 수 있다. 첫 태그가 권한 오류로 실패하면 몇 시간 뒤 **태그를 올려서** 다시 민다(re-run 금지 — §2 함정).

### 3-7. 이후

`v*` 태그 → `android-smoke`가 통과하면 `android` 잡이 내부 테스트에 바로 출시한다(`status: completed`). 폰의 Play 스토어가 업데이트를 받는다. 태그 실행이 `Only releases with status draft may be created on draft app`으로 실패하면 앱이 아직 '초안'이다 — 3-4의 출시가 끝났는지, 3-5의 할 일이 남았는지 확인하고 태그를 올려 다시 민다.

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

> **Team ID = `9J2FNH63M2`** (2026-07-28 확보). 비밀값이 아니다 — `project.pbxproj`의
> `DEVELOPMENT_TEAM`에 커밋돼 있고, CI가 만드는 `ExportOptions.plist`에도 들어간다.

> 🔒 **번들 ID `com.hyunwook.beanprofile`은 영구값이다.** Apple App ID이자 Android `applicationId`로 굳는다.
> 나중에 바꾸면 **양쪽 OS 모두 "다른 앱"으로 취급** → 기존 앱 위에 설치 불가 → 삭제 후 재설치 → **시음 기록 소실**. iOS는 App Store Connect 레코드도 새로 만들어야 한다.
> **2번을 하기 전에 확정할 것.** (`flutter create --org com.hyunwook --project-name beanprofile`과 반드시 일치)

### 3번 — 맥 없이 인증서 만들기

보통 Keychain Access(맥)로 하는 CSR 생성을 OpenSSL로 대체한다.

```bash
openssl genrsa -out ios_dist.key 2048
# MSYS_NO_PATHCONV=1 필수 — 없으면 Git Bash가 "/emailAddress=..."를 Windows 경로로
# 변환해 'C:/Program Files/Git/emailAddress=...'가 되고 req가 형식 오류로 죽는다.
MSYS_NO_PATHCONV=1 openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=hyunwook5636@gmail.com/CN=hyunwook/C=KR"
# → developer.apple.com에 ios_dist.csr 업로드 → dist.cer 다운로드
openssl x509 -inform DER -in dist.cer -out dist.pem
openssl pkcs12 -export -inkey ios_dist.key -in dist.pem -out dist.p12
base64 -w 0 dist.p12 > dist.p12.base64
```

> 실제 산출물은 저장소 밖 **`C:\Users\hyunw\BeanProfile-signing\`** 에 둔다(2026-07-28 생성).

> ⚠️ CI의 `import-codesign-certs` 스텝이 `.p12`를 못 읽고 죽으면 **OpenSSL 3.x의 PKCS12
> 기본 알고리즘**을 의심할 것. 3.0부터 기본이 AES-256/PBKDF2로 바뀌어 macOS `security import`가
> 거부하는 경우가 있다. 그때는 `-export`에 `-legacy`를 붙여 다시 만든다.

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
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | 업로드 키 `upload-keystore.p12`의 base64 |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | 키스토어 비밀번호(PKCS12라 키 비밀번호도 같다) |
| `ANDROID_UPLOAD_KEY_ALIAS` | 키 별칭 (`upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play 서비스 계정 JSON 키 **내용 전체** |
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

### A. Play로 설치한 폰에 다른 서명의 빌드를 넣으면 기록이 지워진다 🔑

안드로이드는 **서명이 다른 빌드를 기존 앱 위에 설치하지 못한다.** 설치하려면 앱을 지워야 하고, **지우는 순간 로컬 전용 DB와 사진이 사라진다.**

Play 앱 서명(2026-10 도입) 이후 폰의 앱은 **Google이 보관하는 앱 서명 키**로 서명돼 있어서 위험의 모양이 바뀌었다.

- **업로드 키를 잃어도 기록은 무사하다.** Play 지원팀에 업로드 키 재설정을 요청하면 되고(수일), 그동안 업데이트만 멈춘다. 그래도 키 파일과 비밀번호는 2곳에 백업한다(§3-3).
- **진짜 위험은 로컬 빌드다.** Windows에서 만든 빌드는 `key.properties`가 없으면 debug 키로 서명된다. 그걸 Play 설치본이 있는 폰에 넣으면 — `flutter install`은 **항상 기존 앱을 먼저 지우고**, `flutter run`은 설치가 거부되면 **묻지 않고 지운 뒤 다시 깐다**(`Uninstalling old version...`). 시음 기록이 경고 없이 사라진다. release 스모크 APK(§6-H)도 같은 applicationId라 같은 위험이 있어서, 스모크 스크립트는 에뮬레이터가 아니면 설치를 거부한다.

> **Play로 설치한 폰에는 `flutter run`·`flutter install`을 하지 않는다 — 예외 없이.** 개발·검증은 에뮬레이터에서 한다. 백업 내보내기는 이 사고를 되돌려 주지 못한다: Android의 가져오기는 앱 자신의 문서 폴더(내보낼 때 파일을 쓰는 곳)만 보는데, 앱을 지우면 그 폴더도 함께 지워지고 Play 빌드에는 바깥 파일을 그 폴더에 넣을 길이 없다. 그래서 **Android에서는 재설치 뒤 백업 복원이 지금은 불가능하다**(iOS는 Files 앱으로 된다). Android 가져오기 경로는 후속 작업이다(설계 §7).

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

### D. 마이그레이션 이후로 다운그레이드하면 DB가 안 열린다 ⬇️

`v0.8.0`부터 `Tastings`에 이 프로젝트 첫 drift 마이그레이션(`schemaVersion` 1→2)이 들어갔다. 한 번 v2로 연 폰에 **그보다 오래된 빌드**(마이그레이션이 없는 버전)를 다시 설치하면, drift가 자신이 모르는 스키마 버전을 만나 "마이그레이션 전략이 없다"는 예외를 던지며 **DB 자체를 못 연다** — 앱이 뜨지 않는다.

AltStore 사이드로드는 "일단 이전 빌드로 되돌려보자"가 흔한 트러블슈팅이라 특히 걸리기 쉽다. **해결책은 v0.8.0 이상 빌드를 다시 설치하는 것** — 실패한 다운그레이드 자체가 데이터를 지우진 않는다(DB 파일은 그대로 남고, 여는 데만 실패한다).

### E. iOS를 빌드하는 잡은 SPM을 꺼야 한다 📦

**iOS를 빌드하는 모든 CI 잡은 `flutter config --no-enable-swift-package-manager`를 먼저 실행해야 한다.**

`flutter config`의 `enable-swift-package-manager`는 **기본값이 on**이라, 러너의 Flutter가 빌드 도중 이 CocoaPods 프로젝트를 Swift Package Manager로 자동 마이그레이션한다. 그런데 `google_mlkit_commons`·`google_mlkit_text_recognition`이 SPM을 지원하지 않아 CocoaPods와 섞이고, 링커가 이렇게 죽는다:

```
Adding Swift Package Manager integration...
The following plugins do not support Swift Package Manager for ios:
  - google_mlkit_commons
  - google_mlkit_text_recognition
Error (Xcode): Framework 'Pods_Runner' not found
Error (Xcode): Linker command failed with exit code 1
```

플러그인 두 개가 SPM을 못 쓰는 이상 이 프로젝트는 CocoaPods가 정답이므로, 이건 임시방편이 아니라 올바른 설정이다. 적용 대상: `release.yml`의 `ios`·`appstore`, `screenshots.yml`의 `screenshots`. (`test` 잡은 ubuntu라 해당 없음.)

> **주의 — 이건 아래 F의 원인이 아니다.** SPM을 끈 뒤에도 시뮬레이터 빌드는 같은
> `Pods_Runner not found`로 계속 실패했다. 두 로그를 비교해 확인한 사실이다.
> SPM 비활성화는 빌드를 결정적으로 만드는 별개의 옳은 설정일 뿐,
> 기기(릴리스) 빌드가 이것 때문에 깨진 적은 없다 — `v0.8.0`은 정상 출시됐다.

### F. ML Kit은 arm64 시뮬레이터 슬라이스가 없다 🏗️

**증상은 E와 똑같지만 원인이 다르다.** Apple Silicon 러너(`macos-26-arm64`)에서 시뮬레이터로 빌드하면:

```
Could not build the application for the simulator.
Error (Xcode): Framework 'Pods_Runner' not found
```

Google의 `GoogleMLKit/*` 팟은 **`arm64-iphoneos`와 `x86_64-iphonesimulator`만** 배포하고 시뮬레이터 빌드에서 arm64를 제외한다. iOS 26부터 시뮬레이터가 Rosetta를 기본으로 쓰지 않으므로, Apple Silicon에서는 arm64 시뮬레이터가 필수인데 그 슬라이스가 없다. 그래서 Pods 우산 프레임워크가 만들어지지 못한다. (업스트림: `issuetracker.google.com/issues/178965151`)

`google_mlkit_commons` 0.12.0이 옵트인 Podfile 헬퍼를 제공한다. `ios/Podfile`에서 **`MLKIT_SIM_PATCH=true`일 때만** 켜지게 해뒀다.

| 빌드 | 환경변수 | 헬퍼 |
|---|---|---|
| `screenshots.yml` (시뮬레이터) | `MLKIT_SIM_PATCH=true` | 적용 |
| `release.yml` (기기 → App Store) | 설정 안 함 | **`require`조차 안 함** |

기기 빌드는 이 코드 경로를 로드하지도 않으므로, 바이너리 재라벨링이 출시본에 닿을 수 없다. **이 구분을 없애지 말 것** — 스크린샷은 있으면 좋은 것이고 출시 바이너리는 그렇지 않다.

> **이 계열 고장은 CI에서만 드러난다.** Windows에는 Xcode도 CocoaPods도 없어
> `flutter build ios`를 로컬에서 돌려볼 수 없다. 시뮬레이터 경로가 막혀도
> 기기 경로는 멀쩡할 수 있으니, 둘을 같은 고장으로 묶어 판단하지 말 것.

### G. Release 설정에 `CODE_SIGN_STYLE = Manual`이 있어야 한다 ✍️

`DEVELOPMENT_TEAM`만 넣고 `CODE_SIGN_STYLE`을 비워두면 **자동 서명**으로 빠진다. 자동 서명은 Apple 계정에 로그인해 **개발용** 프로파일을 받아오려 하는데, CI에는 로그인된 계정이 없다:

```
Automatically signing iOS for device deployment using specified development team: 9J2FNH63M2
Error (Xcode): No Accounts: Add a new account in Accounts settings.
Error (Xcode): No profiles for 'com.hyunwook.beanprofile' were found:
  Xcode couldn't find any iOS App Development provisioning profiles
```

키체인에 배포 인증서를 넣고 App Store 프로파일을 설치해도 소용없다 — **자동 서명은 그걸 아예 쳐다보지 않는다.** 인증서·프로파일 스텝이 초록불이라 원인을 엉뚱한 곳에서 찾기 쉽다.

Flutter 소스가 근거다(`ios/code_signing.dart`): `CODE_SIGN_STYLE`이 `Automatic`이거나 **비어 있을 때만** 자동 서명 경로를 탄다. `Manual`이면 `PROVISIONING_PROFILE_SPECIFIER`와 `DEVELOPMENT_TEAM`을 읽어 수동 서명으로 간다(`commands/build_ios.dart`).

**Runner 타깃의 Release 설정에만** 넣는다:

```
CODE_SIGN_IDENTITY = "Apple Distribution";
CODE_SIGN_STYLE = Manual;
PROVISIONING_PROFILE_SPECIFIER = "BeanProfile App Store";
```

> **Debug·Profile에는 넣지 말 것.** 스크린샷 워크플로의 `flutter drive`는 Debug로 시뮬레이터를 빌드하는데, 시뮬레이터는 서명이 필요 없고 수동 서명을 강제하면 맞는 프로파일이 없어 막힌다.

여기서만 프로파일 **이름**을 하드코딩한다(§8의 ExportOptions는 여전히 UUID를 런타임에 읽는다). 이름이 어긋나면 `No profiles for ... were found`가 그 이름을 그대로 찍어주므로 진단이 즉시 되기 때문이다. **프로파일을 재발급할 때 이름을 같게 유지하면** 이 줄을 고칠 일이 없다.

### H. release 빌드는 에뮬레이터 스모크로만 자동 검증된다 🧪

Play로 가는 건 R8을 거친 release 빌드다. `flutter drive`는 release 모드를 거부하고 profile 빌드는 R8을 돌리지 않아서, 기존 통합 테스트(`ocr_probe_test` 등)로는 이 빌드를 볼 수 없다. 그래서 진입점만 바꾼 release APK(`integration_test/release_smoke.dart`)를 에뮬레이터에서 돌린다 — Gradle·R8 설정은 배포 빌드와 같다. 번들 테스트 카드 5장을 실제 ML Kit으로 읽고 drift를 백그라운드 isolate로 열어 쓰고 읽는다.

- **CI** — `android-smoke` 잡이 태그·수동 실행마다 돈다. 실패하면 `android` 잡이 돌지 않아 Play 업로드도 아티팩트도 없다. 에뮬레이터 부팅이 흔들려 실패했다면 그 실행의 **실패한 잡만 다시 실행**해도 된다 — Android 쪽은 아무것도 올리지 않았으므로 그 `versionCode`는 처음 쓰이고, 이미 성공한 iOS 잡은 다시 돌지 않는다.
- **로컬** — 에뮬레이터(`flutter_emulator`)를 띄운 뒤 아래를 돌린다. 스크립트는 **에뮬레이터가 아니면 설치를 거부한다**(§6-A). 스모크 APK는 applicationId가 같아 에뮬레이터의 개발용 앱을 덮어쓴다 — 다음 `flutter run`이 되돌린다.

```bash
flutter build apk --release --target-platform android-x64 \
  -t integration_test/release_smoke.dart --dart-define=ENABLE_OCR_DIAGNOSTICS=false
python scripts/release_smoke.py
```

카드 5장의 기대값은 `integration_test/support/bundled_card_checks.dart` 한 곳에 있다. 파서를 고쳐 이 카드들의 결과가 바뀌면 거기만 고친다 — debug 프로브와 release 스모크가 함께 따라간다. 검사를 더하거나 빼면 `integration_test/release_smoke.dart`의 검사 목록과 `scripts/release_smoke.py`의 `CHECKS`를 함께 고친다 — 판정은 고정된 여섯 이름이 모두 PASS이고 `DONE 6/6`일 때만 통과한다(남은 로그 줄이나 빠진 검사로는 통과하지 못하게). 카메라·사진 선택기·화면 흐름은 자동화하지 않는다(폰에서 확인).

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

> 📜 **역사 기록이다.** 실제 파이프라인은 `.github/workflows/release.yml`이고 구조는 §2에 있다. 아래의 Android APK → GitHub Release 잡은 만들지 않았고, Android는 Play 내부 테스트 경로(§3)로 대체됐다.

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

### `ios/ExportOptions.plist` (커밋하지 않음 — CI가 매 빌드 생성)

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

**실제 구현은 이 파일을 커밋하지 않는다.** `appstore` 잡이 프로비저닝 프로파일을 복호화해
`Name`·`UUID`·`TeamIdentifier`를 읽어낸 뒤 위 형태로 생성한다(`method`는 `app-store-connect`,
프로파일은 이름 대신 **UUID**로 지정).

이유는 `.ipa` 파일명을 `ls`로 찾는 것과 같다 — **프로파일 이름을 하드코딩하면 오타나 프로파일
재발급으로 이름이 바뀌었을 때 맥 없이 CI 로그만 보고 진단해야 한다.** 프로파일 자신에게서 읽으면
그 실패 경로가 아예 없어지고, 매년 인증서·프로파일을 갱신해도 워크플로를 고칠 필요가 없다.

> ⚠️ §2의 "re-run 하면 `run_number`가 유지된다" 함정이 **이제 실제로 문제가 된다.** 미서명
> AltStore 빌드만 있던 동안엔 빌드 번호 중복이 무해했지만, App Store Connect는 중복 번호를
> 거부한다. 실패했으면 re-run 하지 말고 태그를 올려서 다시 밀 것.

---

## 9. 릴리스 체크리스트

- [ ] `flutter analyze && flutter test` 로컬 초록불
- [ ] 커밋 & 푸시 (main)
- [ ] `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] Actions에서 `test` → `ios`·`appstore`·`android-smoke`·`android` 초록불 확인
- [ ] 안드로이드: 폰의 Play 스토어에서 업데이트 확인(내부 테스트, 수 분). **폰에 로컬 빌드를 넣지 않는다**(§6-A)
- [ ] iOS: TestFlight 앱에서 업데이트 확인 (업로드 후 처리에 5~15분)
- [ ] 실패 시 **re-run 하지 말고** 태그를 올려서 다시 푸시 (§2 함정)
