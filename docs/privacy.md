# BeanProfile 개인정보처리방침

시행일: 2026년 10월 5일

## 한 줄 요약

**BeanProfile은 사진과 기록을 기기 밖으로 보내지 않습니다.** 기록한 내용은 전부 사용자의 기기 안에만 저장되며, 개발자를 포함한 누구에게도 전송되지 않습니다. 개발자는 어떤 개인정보도 수집하지 않습니다.

한 가지 알려 드릴 것이 있습니다. 글자 인식에 쓰는 Google ML Kit이 기기·앱 정보와 성능 진단 정보를 Google로 보냅니다. 사진과 인식된 글자는 여기에 들어가지 않습니다(아래 「Google ML Kit이 보내는 진단 정보」).

## 개발자가 수집하는 정보

없습니다.

이 앱에는 계정이 없고, 개발자가 운영하는 서버도 없습니다. 광고·추적·크래시 리포팅 도구를 쓰지 않습니다.

## Google ML Kit이 보내는 진단 정보

글자 인식에는 Google의 ML Kit을 씁니다. 인식은 기기 안에서 이루어지며, 사진과 인식된 글자는 Google로 전송되지 않습니다.

다만 ML Kit 자체가 진단과 사용 통계를 위해 다음 정보를 Google로 보냅니다.

- 기기 정보 — 제조사, 모델, 운영체제 버전과 빌드, 사용 가능한 머신러닝 하드웨어 가속기
- 앱 정보 — 패키지 이름(iOS는 번들 ID)과 앱 버전
- 설치 단위 식별자 — 앱 설치마다 만들어지며, 사용자나 실제 기기를 고유하게 식별하려는 용도가 아닙니다
- 성능 지표(처리 지연 시간 등)와 API 설정(이미지 형식·해상도 등). Android에서는 입력·출력 크기와 기능 버전도 함께 보냅니다
- 이벤트 종류(기능 초기화, 모델 다운로드, 인식, 자원 해제 등)와 그 오류 코드

Google은 이 정보를 HTTPS로 암호화해 전송하고 제3자에게 넘기지 않는다고 밝히고 있습니다(Android 공개 안내). 개발자는 이 정보를 받지도, 볼 수도 없습니다. 앱 안에서 이 전송을 끄는 설정은 없습니다.

자세한 내용은 Google의 ML Kit 데이터 공개 안내([Android](https://developers.google.com/ml-kit/android-data-disclosure) · [iOS](https://developers.google.com/ml-kit/ios-data-disclosure))를 참고해 주세요.

## 기기에 저장되는 것

앱을 쓰면서 직접 입력하신 내용이 기기 안의 저장 공간에 보관됩니다.

- 원두 정보 — 이름, 로스터리, 원산지, 가공 방식, 로스팅 날짜, 컵노트, 메모
- 시음 기록 — 날짜, 산미·단맛·바디·쓴맛 강도, 종합 평점, 코멘트
- 원두 봉투나 정보 카드를 촬영·선택한 사진

이 데이터는 기기를 벗어나지 않습니다. 앱은 이 데이터를 어디로도 전송하지 않습니다.

## 카메라와 사진 접근 권한

원두 봉투나 정보 카드에 적힌 글자를 자동으로 읽어 입력을 줄이는 데에만 사용합니다.

**문자 인식은 전적으로 기기 안에서 이루어집니다.** 사진도, 인식된 글자도 외부 서버로 전송되지 않습니다. 선택하신 사진은 앱의 저장 공간에 복사되어 해당 원두의 기록으로만 쓰입니다.

권한을 허용하지 않아도 앱의 모든 기능을 직접 입력으로 사용할 수 있습니다.

## 백업 내보내기

설정 화면에서 기록을 JSON 파일로 내보낼 수 있습니다. 이 동작은 **사용자가 직접 실행할 때만** 일어나며, 파일을 어디에 저장하거나 누구에게 보낼지도 사용자가 고릅니다.

내보낸 파일에는 시음 기록과 사진이 함께 들어 있습니다. 기기를 떠난 뒤의 그 파일은 사용자의 관리 아래에 있으며, 개발자는 접근할 수 없습니다.

## 제3자 제공

개발자는 데이터를 판매하거나 누구와도 공유하지 않습니다. 위의 ML Kit 진단 정보는 Google이 직접 받으며, 사진·기록·인식된 글자는 들어 있지 않습니다.

## 데이터 삭제

앱 안에서 개별 원두와 시음 기록을 언제든 삭제할 수 있습니다. 앱을 기기에서 삭제하면 저장된 모든 데이터가 함께 사라집니다.

> 데이터가 기기에만 있으므로 **삭제하면 복구할 수 없습니다.** 기록을 남기고 싶다면 삭제 전에 백업을 내보내 주세요.

## 아동의 개인정보

이 앱은 아동을 대상으로 만들지 않았습니다. 개발자는 아동을 포함해 누구의 개인정보도 수집하지 않습니다.

## 방침 변경

이 방침이 바뀌면 이 페이지를 갱신하고 시행일을 함께 고칩니다.

## 문의

[GitHub 저장소 이슈](https://github.com/HyunwookYoo/BeanProfile/issues)로 문의해 주세요.

---

# Privacy Policy (English)

Effective: October 5, 2026

**BeanProfile never sends your photos or records off your device.** Everything you record stays on your device and is never transmitted to anyone, including the developer. The developer collects no personal data.

One thing to know: Google ML Kit, which the app uses for text recognition, sends device and app information and performance diagnostics to Google. Your photos and recognized text are not part of it (see "Google ML Kit diagnostics" below).

**What the developer collects.** Nothing. The app has no accounts and no developer-run server. It uses no advertising, tracking, or crash-reporting SDKs.

**Google ML Kit diagnostics.** Text recognition uses Google's ML Kit and runs on the device; neither the photo nor the recognized text is sent to Google. ML Kit itself sends the following to Google for diagnostics and usage analytics: device information (manufacturer, model, OS version and build, available ML hardware accelerators); app information (package name or bundle ID, and app version); per-installation identifiers that are not intended to uniquely identify a user or physical device; performance metrics (such as latency) and API configuration (such as image format and resolution), plus input and output size and feature version on Android; and event types (such as feature initializations, model downloads, detection, and resource releases) with their error codes. Google states that this data is encrypted in transit using HTTPS and is not transferred to third parties (Android disclosure). The developer does not receive or see it, and the app has no setting to turn it off. See Google's ML Kit data disclosure for [Android](https://developers.google.com/ml-kit/android-data-disclosure) and [iOS](https://developers.google.com/ml-kit/ios-data-disclosure).

**Stored on your device.** Coffee bean details (name, roaster, origin, process, roast date, cup notes, memo), tasting records (date, acidity/sweetness/body/bitterness intensities, overall rating, comments), and any photos you take or choose. This data never leaves the device.

**Camera and photo access.** Used only to read text printed on coffee bags and information cards so you type less. Text recognition runs entirely on the device — neither the photo nor the recognized text is sent to any server. Photos you select are copied into the app's own storage and used only for that bean's record. The app is fully usable by manual entry if you decline these permissions.

**Backup export.** You can export your records to a JSON file from the Settings screen. This happens only when you initiate it, and you choose where the file goes. The exported file contains your tasting records and photos; once it leaves the device it is under your control, and the developer has no access to it.

**No third-party sharing.** The developer never sells or shares your data. The ML Kit diagnostics above go directly to Google and contain none of your photos, records, or recognized text.

**Deletion.** You can delete individual beans and tastings at any time. Deleting the app removes all stored data. Because the data exists only on your device, deletion is permanent — export a backup first if you want to keep your records.

**Children.** The app is not directed at children. The developer collects no personal data from anyone, including children.

**Changes.** If this policy changes, this page and its effective date will be updated.

**Contact.** Please reach out via [GitHub Issues](https://github.com/HyunwookYoo/BeanProfile/issues).
