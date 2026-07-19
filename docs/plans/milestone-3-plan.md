# M3 사진 & OCR 반자동 입력 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커피 정보 사진(봉투·정보 카드)을 촬영/선택 → 온디바이스 OCR → 자동 채운 폼 + 인식 칩 리뷰 → 저장 → 카드·상세에 사진 표시.

**Architecture:** 플러그인(ML Kit·image_picker·path_provider) 호출은 `OcrService`/`PhotoService` 인터페이스 뒤로 격리(Riverpod 주입, 테스트에서 가짜 교체). 필드 추측은 순수 Dart `parseOcrText`로 분리(TDD 심장). 리뷰 화면은 기존 `bean_form_screen`을 확장. 사진은 저장 시에만 문서폴더로 복사(copy-on-save).

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2 · drift 2.31 · flutter_riverpod 3.3.2 · google_mlkit_text_recognition · image_picker · path_provider · 테스트 flutter_test(+ sqlite3.dll 호스트).

## Global Constraints

- **한국어 UI**: 사용자 노출 문자열은 모두 한국어.
- **오프라인·로컬 전용**: 네트워크 없음, 모든 데이터 기기 내 drift(SQLite). 사진은 앱 문서 디렉터리, 경로만 DB.
- **iOS 우선 배포**: AltStore. Android 코드는 유지하되 CI 검증은 iOS만. Bundle ID `com.hyunwook.beanprofile` 영구, repo public, 서명 시크릿 커밋 금지.
- **플러그인은 호스트 테스트 불가**: `image_picker`·ML Kit·`path_provider` 호출은 seam 뒤로 격리 → 테스트는 가짜 주입, 실검증은 기기. 파서는 순수 Dart.
- **테스트 규약**: docs/testing.md 3계층, 공유 `test/helpers.dart` 재사용, Windows sqlite3.dll, CI. `flutter analyze` 0 유지.
- **용어**: "촬영 / 커피 정보 사진 / 인식된 텍스트". "봉투" 단독 사용 금지(→ "봉투·정보 카드").
- **커밋 트레일러**: 매 커밋 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. main 직접 커밋(트렁크).
- **DRY · YAGNI · TDD · 잦은 커밋.**

---

## File Structure

**신규**
- `lib/services/ocr_service.dart` — `OcrService`(interface) + `MlkitOcrService`
- `lib/services/photo_service.dart` — `PhotoService`(interface) + `ImagePickerPhotoService`
- `lib/features/beans/ocr/ocr_draft.dart` — `OcrDraft` 값 객체
- `lib/features/beans/ocr/ocr_parser.dart` — `parseOcrText(String) → OcrDraft`
- `lib/features/beans/widgets/bean_thumbnail.dart` — 사진 썸네일(카드·상세 공용)
- `lib/features/beans/widgets/ocr_chips_panel.dart` — 인식 칩 패널
- `lib/features/beans/debug_ocr_screen.dart` — **임시** 스파이크 디버그 화면(Task 6에서 삭제)
- `lib/features/beans/add_bean_sheet.dart` — 추가 진입 바텀시트 + 촬영→OCR→폼 배선

**수정**
- `pubspec.yaml` · `ios/Runner/Info.plist` · `ios/Podfile` · `android/app/src/main/AndroidManifest.xml`
- `lib/providers.dart` — `ocrServiceProvider` · `photoServiceProvider`
- `lib/data/models.dart` — `BeanInput.photoPath`
- `lib/data/bean_repository.dart` — `createBean`/`updateBean`에 `photoPath`
- `lib/features/beans/widgets/bean_card.dart` — leading 썸네일
- `lib/features/beans/bean_detail_screen.dart` — 헤더 컴팩트 썸네일(탭→전체화면)
- `lib/features/beans/bean_form_screen.dart` — `draft`/`photoTempPath`, 프리필·하이라이트·칩·persist
- `lib/features/beans/bean_list_screen.dart` — FAB → 바텀시트(+Task1 임시 디버그 진입)
- `test/helpers.dart` — `FakeOcrService`/`FakePhotoService` + `wrapApp` override 확장

**태스크 순서:** 1(스파이크)→[체크포인트 C1: 기기검증]→2(파서)→3(photoPath 데이터)→4(사진 표시)→5(폼 확장)→6(진입 배선)→[최종 리뷰 + finishing].

---

### Task 1: 스파이크 — 플러그인 · 권한 · seam · 디버그 화면

**목적:** M0 이후 가장 무거운 iOS 빌드 변경(ML Kit)을 **먼저** 기기 검증한다. 파서·폼 없이, "사진 → OCR → 원문 표시"만 되는 최소 경로 + 격리 인터페이스를 세운다.

**Files:**
- Modify: `pubspec.yaml`, `ios/Runner/Info.plist`, `ios/Podfile`, `android/app/src/main/AndroidManifest.xml`, `lib/providers.dart`, `lib/features/beans/bean_list_screen.dart`
- Create: `lib/services/ocr_service.dart`, `lib/services/photo_service.dart`, `lib/features/beans/debug_ocr_screen.dart`, `test/unit/services_wiring_test.dart`

**Interfaces (Produces):**
- `abstract class OcrService { Future<String> recognize(String imagePath); }`
- `abstract class PhotoService { Future<String?> pick({required bool fromCamera}); Future<String> persist(String tempPath); }`
- `final ocrServiceProvider = Provider<OcrService>(...)`, `final photoServiceProvider = Provider<PhotoService>(...)`

- [ ] **Step 1: 플러그인 추가**

Run: `flutter pub add google_mlkit_text_recognition image_picker path_provider`
Expected: `pubspec.yaml` dependencies에 3종 추가, `flutter pub get` 성공. 결과 예시:

```yaml
  google_mlkit_text_recognition: ^0.15.0
  image_picker: ^1.1.2
  path_provider: ^2.1.5
```

- [ ] **Step 2: seam 인터페이스 + 구현 작성 (`lib/services/ocr_service.dart`)**

플러그인 객체는 **지연 생성**(생성자에서 네이티브 채널을 건드리지 않게) — 그래야 호스트에서 provider read가 안전하다.

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 온디바이스 OCR seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class OcrService {
  /// [imagePath] 이미지의 전체 인식 텍스트를 반환한다. 실패/빈 이미지면 ''.
  Future<String> recognize(String imagePath);
}

class MlkitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  @override
  Future<String> recognize(String imagePath) async {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    final result = await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
    return result.text;
  }
}
```

- [ ] **Step 3: seam 인터페이스 + 구현 작성 (`lib/services/photo_service.dart`)**

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 사진 선택/보관 seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class PhotoService {
  /// 카메라(fromCamera=true) 또는 갤러리에서 이미지를 고른다.
  /// 반환: 임시 파일 경로, 취소 시 null.
  Future<String?> pick({required bool fromCamera});

  /// 임시 이미지를 앱 문서 디렉터리(photos/)로 복사하고 영구 경로를 반환한다.
  Future<String> persist(String tempPath);
}

class ImagePickerPhotoService implements PhotoService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    return x?.path;
  }

  @override
  Future<String> persist(String tempPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
    final dest = '${photos.path}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(tempPath).copy(dest);
    return dest;
  }
}
```

- [ ] **Step 4: providers 추가 (`lib/providers.dart`)**

파일 끝에 추가하고 import 2줄을 상단에 추가:

```dart
import 'services/ocr_service.dart';
import 'services/photo_service.dart';
```

```dart
final ocrServiceProvider = Provider<OcrService>((ref) => MlkitOcrService());
final photoServiceProvider = Provider<PhotoService>((ref) => ImagePickerPhotoService());
```

- [ ] **Step 5: 실패하는 배선 스모크 테스트 (`test/unit/services_wiring_test.dart`)**

```dart
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:beanprofile/services/photo_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('providers가 실제 서비스 구현으로 해석되고 생성이 네이티브를 안 건드린다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(ocrServiceProvider), isA<MlkitOcrService>());
    expect(c.read(photoServiceProvider), isA<ImagePickerPhotoService>());
  });
}
```

- [ ] **Step 6: RED 확인**

Run: `flutter test test/unit/services_wiring_test.dart`
Expected: FAIL (컴파일 에러 — providers/서비스 미정의). Step 2–4가 이미 있으면 바로 PASS일 수 있음; 그 경우 이 태스크의 TDD는 Step 7 디버그 화면이 아니라 배선 확인이 목적이므로 PASS로 간주하고 진행.

- [ ] **Step 7: 임시 디버그 화면 (`lib/features/beans/debug_ocr_screen.dart`)** — Task 6에서 삭제

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

/// 스파이크 전용 임시 화면: 사진 → OCR → 원문 표시. Task 6에서 제거.
class DebugOcrScreen extends ConsumerStatefulWidget {
  const DebugOcrScreen({super.key});
  @override
  ConsumerState<DebugOcrScreen> createState() => _DebugOcrScreenState();
}

class _DebugOcrScreenState extends ConsumerState<DebugOcrScreen> {
  String _text = '아직 없음';
  bool _busy = false;

  Future<void> _run(bool camera) async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(photoServiceProvider).pick(fromCamera: camera);
      if (path == null) { setState(() { _busy = false; _text = '취소됨'; }); return; }
      final text = await ref.read(ocrServiceProvider).recognize(path);
      setState(() { _busy = false; _text = text.isEmpty ? '(인식 텍스트 없음)' : text; });
    } catch (e) {
      setState(() { _busy = false; _text = '오류: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR 디버그(임시)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: _busy ? null : () => _run(true), child: const Text('촬영')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : () => _run(false), child: const Text('갤러리')),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          Expanded(child: SingleChildScrollView(child: SelectableText(_text))),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 8: bean_list에 임시 디버그 진입 추가 (`lib/features/beans/bean_list_screen.dart`)**

`import 'debug_ocr_screen.dart';` 추가하고, AppBar에 임시 액션을 단다(Task 6에서 제거):

```dart
      appBar: AppBar(
        title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            key: const Key('debug-ocr'),
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugOcrScreen())),
          ),
        ],
      ),
```

- [ ] **Step 9: iOS 권한 (`ios/Runner/Info.plist`)** — `<dict>` 안에 추가

```xml
	<key>NSCameraUsageDescription</key>
	<string>원두 봉투·정보 카드를 촬영해 정보를 자동으로 인식하는 데 사용해요.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>저장된 사진에서 원두 정보를 불러오는 데 사용해요.</string>
```

- [ ] **Step 10: iOS 최소 버전 (`ios/Podfile`)** — 최상단 platform 라인을 활성화

```ruby
platform :ios, '15.0'
```

주: `pod install`이 더 높은 최소버전(예: 15.5)을 요구하면 그 값으로 올린다(스파이크가 정확한 값을 노출). Xcode 프로젝트의 `IPHONEOS_DEPLOYMENT_TARGET`도 동일하게 맞춘다.

- [ ] **Step 11: Android 권한 (`android/app/src/main/AndroidManifest.xml`)** — `<manifest>` 안, `<application>` 위

```xml
    <uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 12: GREEN + analyze**

Run: `flutter test test/unit/services_wiring_test.dart`
Expected: PASS
Run: `flutter analyze`
Expected: No issues. (임시 디버그 화면·진입은 의도된 임시 코드로 남겨둔다.)

- [ ] **Step 13: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/ lib/features/beans/debug_ocr_screen.dart lib/features/beans/bean_list_screen.dart lib/providers.dart test/unit/services_wiring_test.dart ios/ android/
git commit -m "feat(m3): plugins + OCR/Photo service seams + spike debug screen"
```

---

### ✅ 체크포인트 C1 — 스파이크 기기 검증 (컨트롤러 + 사용자)

SDD 태스크가 아니라 **파이프라인 게이트**다. Task 1 커밋 후, 나머지 작업 전에:

1. 스파이크 pre-release 태그 푸시(예: `v0.3.0-spike.1`) → `release.yml`이 미서명 `.ipa` 빌드.
   - iOS 버전 문자열이 문제되면(비수치 접미사) 수치 임시 태그(예: `v0.2.9`)로 폴백.
2. CI가 **설치 가능한 `.ipa`를 성공적으로 만들었는지**(ML Kit 파드/최소버전 해소) 확인 — 실패 시 Podfile/deployment target을 고쳐 재빌드.
3. 사용자가 AltStore로 설치 → 디버그 화면에서 **촬영/갤러리 → OCR 원문 표시**가 기기에서 동작하는지 확인.
4. 통과해야 Task 2로 진행. 여기서 막히면 iOS 빌드 자체가 불가능하므로 **여기서 먼저 해결**한다.

---

### Task 2: OCR 파서 (순수 Dart · TDD 심장)

**Files:**
- Create: `lib/features/beans/ocr/ocr_draft.dart`, `lib/features/beans/ocr/ocr_parser.dart`, `test/unit/ocr_parser_test.dart`

**Interfaces:**
- Consumes: `RoastLevel`, `Process` (lib/data/enums.dart)
- Produces: `class OcrDraft { String? country; DateTime? roastDate; RoastLevel? roastLevel; Process? process; List<String> cupNotes; List<String> chips; bool get isEmpty; }` · `OcrDraft parseOcrText(String rawText)`

- [ ] **Step 1: 값 객체 (`lib/features/beans/ocr/ocr_draft.dart`)**

```dart
import '../../../data/enums.dart';

/// OCR 원문에서 추측한 필드 초안 + 배정 대기 칩.
class OcrDraft {
  final String? country;
  final DateTime? roastDate;
  final RoastLevel? roastLevel;
  final Process? process;
  final List<String> cupNotes;
  final List<String> chips;
  const OcrDraft({
    this.country,
    this.roastDate,
    this.roastLevel,
    this.process,
    this.cupNotes = const [],
    this.chips = const [],
  });

  /// 자동 채운 값도, 배정할 칩도 하나도 없음(= OCR 실패/빈 이미지).
  bool get isEmpty =>
      country == null &&
      roastDate == null &&
      roastLevel == null &&
      process == null &&
      cupNotes.isEmpty &&
      chips.isEmpty;
}
```

- [ ] **Step 2: 실패 테스트 (`test/unit/ocr_parser_test.dart`)**

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('country', () {
    test('영문/한글 원산지를 표준 표기로', () {
      expect(parseOcrText('Ethiopia Yirgacheffe G1').country, 'Ethiopia');
      expect(parseOcrText('에티오피아 예가체프').country, 'Ethiopia');
      expect(parseOcrText('Costa Rica Tarrazu').country, 'Costa Rica');
    });
    test('원산지 아니면 null', () {
      expect(parseOcrText('Fritz Coffee Company').country, isNull);
    });
  });

  group('roastDate', () {
    test('여러 포맷', () {
      expect(parseOcrText('Roasted: 2026-07-02').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('로스팅 2026.07.02').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('2026년 7월 2일 로스팅').roastDate, DateTime(2026, 7, 2));
      expect(parseOcrText('26/07/02').roastDate, DateTime(2026, 7, 2));
    });
    test('말이 안 되는 숫자는 무시', () {
      expect(parseOcrText('lot 99.99.99').roastDate, isNull);
    });
  });

  group('roastLevel', () {
    test('복합어가 단일어보다 우선', () {
      expect(parseOcrText('Light-Medium roast').roastLevel, RoastLevel.lightMedium);
      expect(parseOcrText('Full City').roastLevel, RoastLevel.mediumDark);
      expect(parseOcrText('미디엄 로스팅').roastLevel, RoastLevel.medium);
      expect(parseOcrText('다크').roastLevel, RoastLevel.dark);
    });
  });

  group('process', () {
    test('영/한 키워드', () {
      expect(parseOcrText('Washed').process, Process.washed);
      expect(parseOcrText('내추럴').process, Process.natural);
      expect(parseOcrText('Honey process').process, Process.honey);
      expect(parseOcrText('Anaerobic').process, Process.anaerobic);
    });
  });

  group('cupNotes', () {
    test('라벨 뒤를 구분자로 분리', () {
      expect(parseOcrText('Notes: Blueberry, Jasmine, Black Tea').cupNotes,
          ['Blueberry', 'Jasmine', 'Black Tea']);
      expect(parseOcrText('컵노트: 블루베리 · 자스민').cupNotes, ['블루베리', '자스민']);
    });
    test('라벨 없으면 빈 리스트', () {
      expect(parseOcrText('Ethiopia').cupNotes, isEmpty);
    });
  });

  group('chips & isEmpty', () {
    test('비어있지 않은 줄을 중복제거해 칩으로', () {
      final d = parseOcrText('프릳츠\n\nG1\n프릳츠');
      expect(d.chips, ['프릳츠', 'G1']);
    });
    test('빈 입력은 isEmpty', () {
      expect(parseOcrText('').isEmpty, isTrue);
      expect(parseOcrText('   \n  ').isEmpty, isTrue);
    });
    test('실제 라벨 종합', () {
      final d = parseOcrText(
          'Fritz Coffee\nEthiopia Yirgacheffe\nWashed\nRoasted 2026.07.02\nNotes: Blueberry, Jasmine');
      expect(d.country, 'Ethiopia');
      expect(d.process, Process.washed);
      expect(d.roastDate, DateTime(2026, 7, 2));
      expect(d.cupNotes, ['Blueberry', 'Jasmine']);
      expect(d.chips, contains('Fritz Coffee'));
    });
  });
}
```

- [ ] **Step 3: RED 확인**

Run: `flutter test test/unit/ocr_parser_test.dart`
Expected: FAIL (`parseOcrText` 미정의 — 컴파일 에러)

- [ ] **Step 4: 파서 구현 (`lib/features/beans/ocr/ocr_parser.dart`)**

키워드 맵은 **삽입 순서가 중요**(복합어를 단일어보다 먼저).

```dart
import '../../../data/enums.dart';
import 'ocr_draft.dart';

/// 원산지 사전: 소문자 키워드 → 표준 표기. 복합어(Costa Rica)를 먼저.
const Map<String, String> _countries = {
  'costa rica': 'Costa Rica', '코스타리카': 'Costa Rica',
  'el salvador': 'El Salvador', '엘살바도르': 'El Salvador',
  'ethiopia': 'Ethiopia', '에티오피아': 'Ethiopia',
  'colombia': 'Colombia', '콜롬비아': 'Colombia',
  'kenya': 'Kenya', '케냐': 'Kenya',
  'brazil': 'Brazil', '브라질': 'Brazil',
  'guatemala': 'Guatemala', '과테말라': 'Guatemala',
  'panama': 'Panama', '파나마': 'Panama',
  'honduras': 'Honduras', '온두라스': 'Honduras',
  'indonesia': 'Indonesia', '인도네시아': 'Indonesia',
  'rwanda': 'Rwanda', '르완다': 'Rwanda',
  'burundi': 'Burundi', '부룬디': 'Burundi',
  'peru': 'Peru', '페루': 'Peru',
  'nicaragua': 'Nicaragua', '니카라과': 'Nicaragua',
  'yemen': 'Yemen', '예멘': 'Yemen',
  'tanzania': 'Tanzania', '탄자니아': 'Tanzania',
  'mexico': 'Mexico', '멕시코': 'Mexico',
  'uganda': 'Uganda', '우간다': 'Uganda',
  'bolivia': 'Bolivia', '볼리비아': 'Bolivia',
  'ecuador': 'Ecuador', '에콰도르': 'Ecuador',
};

/// 복합어(라이트미디엄·미디엄다크·풀시티)를 단일어보다 먼저.
const Map<String, RoastLevel> _roastKeywords = {
  '라이트미디엄': RoastLevel.lightMedium, 'light medium': RoastLevel.lightMedium,
  'light-medium': RoastLevel.lightMedium, 'cinnamon': RoastLevel.lightMedium,
  '미디엄다크': RoastLevel.mediumDark, 'medium dark': RoastLevel.mediumDark,
  'medium-dark': RoastLevel.mediumDark, 'full city': RoastLevel.mediumDark, '풀시티': RoastLevel.mediumDark,
  '미디엄': RoastLevel.medium, 'medium': RoastLevel.medium, 'city': RoastLevel.medium, '시티': RoastLevel.medium,
  '라이트': RoastLevel.light, 'light': RoastLevel.light,
  '다크': RoastLevel.dark, 'dark': RoastLevel.dark, 'french': RoastLevel.dark, 'italian': RoastLevel.dark,
};

const Map<String, Process> _processKeywords = {
  '워시드': Process.washed, 'washed': Process.washed, '수세식': Process.washed,
  '내추럴': Process.natural, 'natural': Process.natural, '건식': Process.natural,
  '허니': Process.honey, 'honey': Process.honey,
  '무산소': Process.anaerobic, 'anaerobic': Process.anaerobic, '애너로빅': Process.anaerobic,
};

final List<RegExp> _datePatterns = [
  RegExp(r'(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),      // 2026-07-02
  RegExp(r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일'), // 2026년 7월 2일
  RegExp(r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),        // 26.07.02
];

final RegExp _noteLabel = RegExp(
  r'^(cup\s*notes?|tasting\s*notes?|notes?|컵\s*노트|노트|향미)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);

OcrDraft parseOcrText(String rawText) {
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final lower = rawText.toLowerCase();
  return OcrDraft(
    country: _firstMatch(lower, _countries),
    roastDate: _matchDate(rawText),
    roastLevel: _firstMatch(lower, _roastKeywords),
    process: _firstMatch(lower, _processKeywords),
    cupNotes: _matchCupNotes(lines),
    chips: _dedupe(lines),
  );
}

T? _firstMatch<T>(String lower, Map<String, T> table) {
  for (final e in table.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return null;
}

DateTime? _matchDate(String text) {
  for (final re in _datePatterns) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    var year = int.parse(m.group(1)!);
    if (year < 100) year += 2000;
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    return DateTime(year, month, day);
  }
  return null;
}

List<String> _matchCupNotes(List<String> lines) {
  for (final line in lines) {
    final m = _noteLabel.firstMatch(line);
    if (m != null) {
      return m.group(2)!
          .split(RegExp(r'[,/·、]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

List<String> _dedupe(List<String> lines) {
  final seen = <String>{};
  final out = <String>[];
  for (final l in lines) {
    if (seen.add(l)) out.add(l);
  }
  return out;
}
```

- [ ] **Step 5: GREEN 확인**

Run: `flutter test test/unit/ocr_parser_test.dart`
Expected: PASS (모든 그룹)

- [ ] **Step 6: Commit**

```bash
git add lib/features/beans/ocr/ test/unit/ocr_parser_test.dart
git commit -m "feat(m3): pure-Dart OCR field parser (country/date/roast/process/notes/chips)"
```

---

### Task 3: `BeanInput.photoPath` 데이터 왕복

**Files:**
- Modify: `lib/data/models.dart`, `lib/data/bean_repository.dart`
- Test: `test/unit/photo_path_repository_test.dart`

**Interfaces:**
- Produces: `BeanInput({..., String? photoPath})` (기존 필드 유지, 마지막에 optional 추가) — `Bean.photoPath` 컬럼은 이미 존재.

- [ ] **Step 1: 실패 테스트 (`test/unit/photo_path_repository_test.dart`)**

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('photoPath가 create/update/watchBeanDetail을 왕복한다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);

    final id = await repo.createBean(BeanInput(
      name: '예가체프', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const [], memo: null,
      components: [const ComponentInput(country: 'Ethiopia')],
      photoPath: '/app/photos/a.jpg',
    ));

    var detail = await repo.getBeanDetail(id);
    expect(detail!.bean.photoPath, '/app/photos/a.jpg');

    await repo.updateBean(id, BeanInput(
      name: '예가체프', roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: null, roastDate: null, cupNotes: const [], memo: null,
      components: [const ComponentInput(country: 'Ethiopia')],
      photoPath: '/app/photos/b.jpg',
    ));
    detail = await repo.getBeanDetail(id);
    expect(detail!.bean.photoPath, '/app/photos/b.jpg');
  });
}
```

- [ ] **Step 2: RED 확인**

Run: `flutter test test/unit/photo_path_repository_test.dart`
Expected: FAIL (`BeanInput`에 `photoPath` 이름 인자 없음 — 컴파일 에러)

- [ ] **Step 3: `BeanInput`에 필드 추가 (`lib/data/models.dart`)**

`class BeanInput`에 필드와 생성자 인자를 **마지막에 optional**로 추가(기존 호출부 유지):

```dart
class BeanInput {
  final String name;
  final String roaster;
  final BeanType type;
  final RoastLevel? roastLevel;
  final DateTime? roastDate;
  final List<String> cupNotes;
  final String? memo;
  final List<ComponentInput> components;
  final String? photoPath;
  const BeanInput({
    required this.name,
    required this.roaster,
    required this.type,
    required this.roastLevel,
    required this.roastDate,
    required this.cupNotes,
    required this.memo,
    required this.components,
    this.photoPath,
  });
}
```

- [ ] **Step 4: 저장소에 반영 (`lib/data/bean_repository.dart`)**

`createBean`의 `BeansCompanion.insert(...)`에 추가:

```dart
            memo: Value(input.memo),
            photoPath: Value(input.photoPath),
            createdAt: DateTime.now(),
```

`updateBean`의 `BeansCompanion(...)`에 추가:

```dart
          memo: Value(input.memo),
          photoPath: Value(input.photoPath),
```

- [ ] **Step 5: GREEN 확인**

Run: `flutter test test/unit/photo_path_repository_test.dart`
Expected: PASS
Run: `flutter test`
Expected: 전체 PASS(기존 39 + 신규). `BeanInput` 변경이 기존 호출부를 깨지 않음(optional).

- [ ] **Step 6: Commit**

```bash
git add lib/data/models.dart lib/data/bean_repository.dart test/unit/photo_path_repository_test.dart
git commit -m "feat(m3): persist BeanInput.photoPath through create/update"
```

---

### Task 4: 사진 표시 — 카드 썸네일 + 상세 컴팩트 썸네일

**Files:**
- Create: `lib/features/beans/widgets/bean_thumbnail.dart`, `test/widget/bean_thumbnail_test.dart`
- Modify: `lib/features/beans/widgets/bean_card.dart`, `lib/features/beans/bean_detail_screen.dart`
- Test: `test/widget/detail_photo_test.dart`

**Interfaces:**
- Produces: `class BeanThumbnail extends StatelessWidget { BeanThumbnail({String? photoPath, double width, double height}) }`

- [ ] **Step 1: 썸네일 위젯 (`lib/features/beans/widgets/bean_thumbnail.dart`)**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 원두 사진 썸네일. photoPath 없으면 문서 아이콘 플레이스홀더.
class BeanThumbnail extends StatelessWidget {
  const BeanThumbnail({super.key, required this.photoPath, this.width = 48, this.height = 60});
  final String? photoPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(10);
    Widget placeholder(IconData icon) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.oat, borderRadius: radius, border: Border.all(color: c.appLine)),
          child: Icon(icon, color: c.appMuted, size: width * 0.42),
        );
    if (photoPath == null) return placeholder(Icons.description_outlined);
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(photoPath!),
        width: width, height: height, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(Icons.broken_image_outlined),
      ),
    );
  }
}
```

- [ ] **Step 2: 썸네일 실패 테스트 (`test/widget/bean_thumbnail_test.dart`)**

```dart
import 'package:beanprofile/features/beans/widgets/bean_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('photoPath 없으면 아이콘 플레이스홀더, Image 없음', (t) async {
    await t.pumpWidget(wrapApp(const BeanThumbnail(photoPath: null)));
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('photoPath 있으면 Image.file 렌더', (t) async {
    await t.pumpWidget(wrapApp(const BeanThumbnail(photoPath: '/no/such/file.jpg')));
    expect(find.byType(Image), findsOneWidget);
  });
}
```

- [ ] **Step 3: RED 확인**

Run: `flutter test test/widget/bean_thumbnail_test.dart`
Expected: FAIL (`BeanThumbnail` 미정의). Step 1이 이미 있으면 PASS — 그대로 진행.

- [ ] **Step 4: 카드에 썸네일 (`lib/features/beans/widgets/bean_card.dart`)**

`import 'bean_thumbnail.dart';` 추가. 기존 `child: Column(...)`을 `Row`로 감싸 leading 썸네일을 둔다:

```dart
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BeanThumbnail(photoPath: bean.photoPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bean.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text([bean.roaster, summary.originLabel].where((e) => e != null && e.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: c.appMuted)),
              const SizedBox(height: 8),
              Row(children: [
                if (bean.type == BeanType.blend) ...[
                  _Badge(text: 'BLEND', color: c.cremaInk),
                  const SizedBox(width: 8),
                ],
                StarRating(value: summary.avgRating),
                const Spacer(),
                Text('시음 ${summary.tastingCount}', style: monoStyle(size: 11, color: c.appMuted)),
              ]),
              if (bean.cupNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 5, runSpacing: 5, children: [
                  for (final n in bean.cupNotes.take(4)) _Note(text: n, color: c),
                ]),
              ],
            ]),
          ),
        ]),
```

- [ ] **Step 5: 상세 헤더 썸네일 실패 테스트 (`test/widget/detail_photo_test.dart`)**

```dart
import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:beanprofile/features/beans/widgets/bean_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('사진 있는 원두 상세: 헤더 썸네일 탭 → 전체화면 Image', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle().copyWithPhoto('/no/such/file.jpg'));

    await t.pumpWidget(wrapApp(BeanDetailScreen(beanId: id), db: db));
    await t.pump(); // 스트림 첫 방출
    await t.pump();

    expect(find.byType(BeanThumbnail), findsOneWidget);
    await t.tap(find.byType(BeanThumbnail));
    await t.pumpAndSettle();
    // 전체화면 다이얼로그의 Image
    expect(find.byType(Image), findsWidgets);
    await t.pump(const Duration(milliseconds: 200)); // autoDispose-pop 데드락 회피
  });
}
```

`sampleSingle().copyWithPhoto(...)` 헬퍼가 필요하므로 Step 6에서 `test/helpers.dart`에 확장 메서드를 추가한다.

- [ ] **Step 6: 헬퍼에 photo 확장 (`test/helpers.dart`)**

파일 끝에 추가:

```dart
extension BeanInputPhoto on BeanInput {
  BeanInput copyWithPhoto(String path) => BeanInput(
        name: name, roaster: roaster, type: type, roastLevel: roastLevel,
        roastDate: roastDate, cupNotes: cupNotes, memo: memo, components: components,
        photoPath: path,
      );
}
```

- [ ] **Step 7: 상세 헤더에 썸네일 (`lib/features/beans/bean_detail_screen.dart`)**

`import 'widgets/bean_thumbnail.dart';` 추가. `_DetailBody.build`의 상단(이름/로스터리/평점) 블록을 Row로 감싸 썸네일을 왼쪽에 둔다. 기존:

```dart
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(bean.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text([bean.roaster, bean.type.label].where((e) => e.isNotEmpty).join(' · '),
          style: TextStyle(color: c.appMuted)),
      const SizedBox(height: 8),
      Row(children: [
        StarRating(value: detail.avgRating),
        const SizedBox(width: 10),
        Text('시음 ${detail.tastingCount}회',
            style: TextStyle(color: c.appMuted, fontSize: 12)),
      ]),
      const SizedBox(height: 14),
```

를 아래로 교체:

```dart
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: bean.photoPath == null ? null : () => _showFullPhoto(context, bean.photoPath!),
          child: BeanThumbnail(photoPath: bean.photoPath, width: 56, height: 70),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bean.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text([bean.roaster, bean.type.label].where((e) => e.isNotEmpty).join(' · '),
                style: TextStyle(color: c.appMuted)),
            const SizedBox(height: 8),
            Row(children: [
              StarRating(value: detail.avgRating),
              const SizedBox(width: 10),
              Text('시음 ${detail.tastingCount}회',
                  style: TextStyle(color: c.appMuted, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
```

그리고 `_DetailBody`에 전체화면 뷰어 메서드를 추가(`dart:io` import 필요):

```dart
  void _showFullPhoto(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.file(File(path), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54)))),
        ),
      ),
    );
  }
```

파일 상단에 `import 'dart:io';` 추가.

- [ ] **Step 8: GREEN + analyze**

Run: `flutter test test/widget/bean_thumbnail_test.dart test/widget/detail_photo_test.dart`
Expected: PASS
Run: `flutter test`
Expected: 전체 PASS (기존 카드/상세 위젯 테스트가 Row 재구성에도 통과 — 텍스트 finder 유지)
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/beans/widgets/bean_thumbnail.dart lib/features/beans/widgets/bean_card.dart lib/features/beans/bean_detail_screen.dart test/helpers.dart test/widget/bean_thumbnail_test.dart test/widget/detail_photo_test.dart
git commit -m "feat(m3): show bean photo thumbnail on card + detail (tap to fullscreen)"
```

---

### Task 5: 폼 확장 — draft 프리필 · 하이라이트 · 칩 배정 · persist

**Files:**
- Create: `lib/features/beans/widgets/ocr_chips_panel.dart`, `test/widget/ocr_form_test.dart`
- Modify: `lib/features/beans/bean_form_screen.dart`, `test/helpers.dart`

**Interfaces:**
- Consumes: `OcrDraft`, `parseOcrText`(Task 2) · `photoServiceProvider.persist`(Task 1) · `BeanInput.photoPath`(Task 3)
- Produces: `BeanFormScreen({BeanDetail? existing, OcrDraft? draft, String? photoTempPath})` · `class OcrChipsPanel`

- [ ] **Step 1: 칩 패널 위젯 (`lib/features/beans/widgets/ocr_chips_panel.dart`)**

```dart
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 인식된 텍스트 칩. 활성(포커스) 텍스트 필드에 탭으로 배정. 쓴 칩은 흐려짐.
class OcrChipsPanel extends StatelessWidget {
  const OcrChipsPanel({super.key, required this.chips, required this.used, required this.onTap});
  final List<String> chips;
  final Set<String> used;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.crema, style: BorderStyle.solid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('인식된 텍스트 — 채울 칸을 탭한 뒤 칩을 누르세요',
            style: TextStyle(fontSize: 11, color: c.cremaInk, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final chip in chips)
            ActionChip(
              key: Key('chip-$chip'),
              label: Text(chip),
              onPressed: used.contains(chip) ? null : () => onTap(chip),
              backgroundColor: used.contains(chip) ? c.oat : c.cup2,
            ),
        ]),
      ]),
    );
  }
}
```

- [ ] **Step 2: 헬퍼 확장 — 가짜 서비스 + wrapApp override (`test/helpers.dart`)**

상단 import에 추가:

```dart
import 'package:beanprofile/services/ocr_service.dart';
import 'package:beanprofile/services/photo_service.dart';
```

`wrapApp`을 교체(ocr/photo override 추가 — optional이라 기존 호출 호환):

```dart
Widget wrapApp(Widget child, {AppDatabase? db, OcrService? ocr, PhotoService? photo}) => ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
        if (ocr != null) ocrServiceProvider.overrideWithValue(ocr),
        if (photo != null) photoServiceProvider.overrideWithValue(photo),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
```

파일 끝에 가짜 추가:

```dart
class FakeOcrService implements OcrService {
  FakeOcrService(this.text);
  final String text;
  @override
  Future<String> recognize(String imagePath) async => text;
}

class FakePhotoService implements PhotoService {
  FakePhotoService({this.pickResult, this.persistResult = '/app/photos/persisted.jpg'});
  final String? pickResult;
  final String persistResult;
  @override
  Future<String?> pick({required bool fromCamera}) async => pickResult;
  @override
  Future<String> persist(String tempPath) async => persistResult;
}
```

- [ ] **Step 3: 폼 확장 실패 테스트 (`test/widget/ocr_form_test.dart`)**

```dart
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/ocr/ocr_draft.dart';
import 'package:beanprofile/features/beans/widgets/ocr_chips_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('draft 프리필 + OCR 자동 하이라이트 + 칩 렌더', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(
          country: 'Ethiopia',
          process: Process.washed,
          cupNotes: ['블루베리'],
          chips: ['프릳츠', 'G1'],
        ),
      ),
      db: db,
    ));
    await t.pump();

    expect(find.text('Ethiopia'), findsOneWidget);         // 국가 프리필
    expect(find.text('블루베리'), findsOneWidget);           // 컵노트 프리필
    expect(find.text('OCR 자동'), findsWidgets);            // 하이라이트
    expect(find.byType(OcrChipsPanel), findsOneWidget);
    expect(find.text('프릳츠'), findsOneWidget);
  });

  testWidgets('칸 포커스 후 칩 탭 → 그 칸에 채워지고 칩은 비활성', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(draft: OcrDraft(chips: ['프릳츠'])),
      db: db,
    ));
    await t.pump();

    await t.tap(find.byKey(const Key('field-roaster')));   // 로스터리 포커스
    await t.pump();
    await t.tap(find.byKey(const Key('chip-프릳츠')));
    await t.pump();

    expect(find.widgetWithText(TextField, '프릳츠'), findsOneWidget); // 로스터리에 채워짐
    final chip = t.widget<ActionChip>(find.byKey(const Key('chip-프릳츠')));
    expect(chip.onPressed, isNull);                        // used → 비활성
  });

  testWidgets('OCR 실패(빈 draft) → 안내 배너, 칩 패널 없음', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(const BeanFormScreen(draft: OcrDraft()), db: db));
    await t.pump();

    expect(find.textContaining('자동 인식하지 못했'), findsOneWidget);
    expect(find.byType(OcrChipsPanel), findsNothing);
  });

  testWidgets('저장 시 photoTempPath를 persist해 photoPath로 저장', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await t.pumpWidget(wrapApp(
      const BeanFormScreen(
        draft: OcrDraft(country: 'Ethiopia'),
        photoTempPath: '/tmp/pick.jpg',
      ),
      db: db,
      photo: FakePhotoService(persistResult: '/app/photos/saved.jpg'),
    ));
    await t.pump();

    await t.enterText(find.byKey(const Key('field-name')), '예가체프');
    await t.tap(find.byKey(const Key('save-bean')));
    await t.pumpAndSettle();

    final summaries = await repo.watchBeanSummaries().first;
    expect(summaries.single.bean.photoPath, '/app/photos/saved.jpg');
  });
}
```

- [ ] **Step 4: RED 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: FAIL (`draft`/`photoTempPath` 인자 없음, 배너/칩 미구현)

- [ ] **Step 5: 폼 확장 구현 (`lib/features/beans/bean_form_screen.dart`)**

상단 import에 추가:

```dart
import 'ocr/ocr_draft.dart';
import 'widgets/ocr_chips_panel.dart';
```

생성자·필드 교체:

```dart
class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({super.key, this.existing, this.draft, this.photoTempPath});
  final BeanDetail? existing;
  final OcrDraft? draft;
  final String? photoTempPath;
  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}
```

State에 필드 추가(기존 필드 아래):

```dart
  final _nameFocus = FocusNode();
  final _roasterFocus = FocusNode();
  final _cupNotesFocus = FocusNode();
  final _memoFocus = FocusNode();
  TextEditingController? _activeField;
  final _usedChips = <String>{};
```

`initState`의 `if (e != null) {...}` 블록 **뒤에**(닫는 `}` 다음) 프리필 + 포커스 배선 추가:

```dart
    final d = widget.draft;
    if (e == null && d != null) {
      if (d.country != null) _components.first.country.text = d.country!;
      if (d.process != null) _components.first.process = d.process!;
      _roast = d.roastLevel;
      _roastDate = d.roastDate;
      if (d.cupNotes.isNotEmpty) _cupNotes.text = d.cupNotes.join(', ');
    }
    _nameFocus.addListener(() { if (_nameFocus.hasFocus) _activeField = _name; });
    _roasterFocus.addListener(() { if (_roasterFocus.hasFocus) _activeField = _roaster; });
    _cupNotesFocus.addListener(() { if (_cupNotesFocus.hasFocus) _activeField = _cupNotes; });
    _memoFocus.addListener(() { if (_memoFocus.hasFocus) _activeField = _memo; });
```

`dispose`에 focus node 해제 추가:

```dart
    _nameFocus.dispose(); _roasterFocus.dispose();
    _cupNotesFocus.dispose(); _memoFocus.dispose();
```

칩 배정 메서드 추가(예: `_save` 위):

```dart
  void _assignChip(String text) {
    final target = _activeField;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 채울 칸을 탭해서 선택하세요')));
      return;
    }
    setState(() {
      if (target == _cupNotes) {
        final cur = _cupNotes.text.trim();
        _cupNotes.text = cur.isEmpty ? text : '$cur, $text';
      } else {
        target.text = text;
      }
      _usedChips.add(text);
    });
  }

  bool get _auto => widget.existing == null && widget.draft != null;
```

`_save`에서 사진 경로를 해석해 `BeanInput`에 넣는다. 기존 `setState(() => _saving = true);` 다음에:

```dart
    String? photoPath = widget.existing?.bean.photoPath; // 편집 시 기존 사진 유지
    if (widget.photoTempPath != null) {
      photoPath = await ref.read(photoServiceProvider).persist(widget.photoTempPath!);
    }
```

그리고 `BeanInput(...)`의 `components: [...]` 다음에 `photoPath: photoPath,` 추가.

폼 필드에 key/focus/하이라이트를 단다. `_name` TextField에 focusNode:

```dart
        TextField(key: const Key('field-name'), controller: _name, focusNode: _nameFocus,
            decoration: const InputDecoration(labelText: '제품명 *')),
```

`_roaster` TextField:

```dart
        TextField(key: const Key('field-roaster'), controller: _roaster, focusNode: _roasterFocus,
            decoration: const InputDecoration(labelText: '로스터리')),
```

로스팅 단계 Dropdown에 하이라이트 helper:

```dart
        DropdownButtonFormField<RoastLevel>(
          initialValue: _roast,
          decoration: InputDecoration(
              labelText: '로스팅 단계',
              helperText: _auto && widget.draft!.roastLevel != null ? 'OCR 자동' : null),
          items: [for (final r in RoastLevel.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (v) => setState(() => _roast = v),
        ),
```

로스팅 날짜 Row의 Expanded 텍스트 옆에 자동 표시(있을 때):

```dart
        Row(children: [
          Expanded(child: Text(_roastDate == null ? '로스팅 날짜 없음'
              : '로스팅 ${_roastDate!.toIso8601String().substring(0, 10)}'
                  '${_auto && widget.draft!.roastDate != null ? '  · OCR 자동' : ''}')),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context,
                  firstDate: DateTime(2015), lastDate: DateTime(2100),
                  initialDate: DateTime.now());
              if (picked != null) setState(() => _roastDate = picked);
            },
            child: const Text('날짜 선택'),
          ),
        ]),
```

컵노트 TextField에 focusNode + 하이라이트:

```dart
        TextField(controller: _cupNotes, focusNode: _cupNotesFocus,
            decoration: InputDecoration(
                labelText: '컵노트 (쉼표로 구분)', hintText: '블루베리, 자스민, 홍차',
                helperText: _auto && widget.draft!.cupNotes.isNotEmpty ? 'OCR 자동' : null)),
```

메모 TextField에 focusNode:

```dart
        TextField(controller: _memo, focusNode: _memoFocus, maxLines: 3,
            decoration: const InputDecoration(labelText: '메모')),
```

메모 필드 **다음에**(ListView children 끝 부분) 칩 패널/배너를 추가:

```dart
        if (widget.draft != null) ...[
          const SizedBox(height: 14),
          if (widget.draft!.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.cup2, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.appLine)),
              child: Text('글자를 자동 인식하지 못했어요. 아래 항목을 직접 입력하거나 다시 촬영해 주세요.',
                  style: TextStyle(fontSize: 12, color: c.espresso)),
            )
          else if (widget.draft!.chips.isNotEmpty)
            OcrChipsPanel(chips: widget.draft!.chips, used: _usedChips, onTap: _assignChip),
        ],
```

첫 원산지 국가 필드(`_componentEditor`의 country TextField)에 하이라이트를 달려면 `i == 0`일 때 helperText:

```dart
            child: TextField(
              key: Key('field-country-$i'),
              controller: comp.country,
              decoration: InputDecoration(
                  labelText: i == 0 ? '원산지 국가 *' : '국가',
                  helperText: i == 0 && _auto && widget.draft!.country != null ? 'OCR 자동' : null),
            ),
```

주: `context.colors`의 `cup2`가 없으면 테마에 있는 대응 토큰(예: `c.cup`)으로 대체. 배너 배경은 시각적 강조가 목적이므로 팀 토큰에 맞춘다.

- [ ] **Step 6: GREEN 확인**

Run: `flutter test test/widget/ocr_form_test.dart`
Expected: PASS (4개)
Run: `flutter test`
Expected: 전체 PASS(기존 폼 테스트 포함 — key/focus 추가는 비파괴적)
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/beans/bean_form_screen.dart lib/features/beans/widgets/ocr_chips_panel.dart test/helpers.dart test/widget/ocr_form_test.dart
git commit -m "feat(m3): OCR draft prefill + highlight + chip-assign + copy-on-save in bean form"
```

---

### Task 6: 진입 바텀시트 + 실플로우 배선 (디버그 화면 제거)

**Files:**
- Create: `lib/features/beans/add_bean_sheet.dart`, `test/widget/add_bean_sheet_test.dart`
- Modify: `lib/features/beans/bean_list_screen.dart`
- Delete: `lib/features/beans/debug_ocr_screen.dart`

**Interfaces:**
- Consumes: `photoServiceProvider.pick`, `ocrServiceProvider.recognize`(Task 1) · `parseOcrText`(Task 2) · `BeanFormScreen(draft:, photoTempPath:)`(Task 5)
- Produces: `Future<void> showAddBeanSheet(BuildContext context, WidgetRef ref)`

- [ ] **Step 1: 바텀시트 + 배선 (`lib/features/beans/add_bean_sheet.dart`)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import 'ocr/ocr_draft.dart';
import 'ocr/ocr_parser.dart';
import 'bean_form_screen.dart';

enum _AddChoice { camera, gallery, manual }

/// FAB에서 호출: 촬영/갤러리 → OCR → 폼, 또는 직접 입력.
Future<void> showAddBeanSheet(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: const Key('add-camera'),
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('촬영'),
          subtitle: const Text('봉투·정보 카드를 찍어 자동 인식'),
          onTap: () => Navigator.pop(context, _AddChoice.camera),
        ),
        ListTile(
          key: const Key('add-gallery'),
          leading: const Icon(Icons.image_outlined),
          title: const Text('갤러리에서 선택'),
          subtitle: const Text('저장된 사진에서'),
          onTap: () => Navigator.pop(context, _AddChoice.gallery),
        ),
        ListTile(
          key: const Key('add-manual'),
          leading: const Icon(Icons.edit_outlined),
          title: const Text('직접 입력'),
          subtitle: const Text('사진 없이 수동으로'),
          onTap: () => Navigator.pop(context, _AddChoice.manual),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == _AddChoice.manual) {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BeanFormScreen()));
    return;
  }

  final tempPath =
      await ref.read(photoServiceProvider).pick(fromCamera: choice == _AddChoice.camera);
  if (tempPath == null || !context.mounted) return;

  final draft = await _recognize(context, ref, tempPath);
  if (draft == null || !context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BeanFormScreen(draft: draft, photoTempPath: tempPath)));
}

Future<OcrDraft?> _recognize(BuildContext context, WidgetRef ref, String path) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final text = await ref.read(ocrServiceProvider).recognize(path);
    return parseOcrText(text);
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // 스피너 닫기
  }
}
```

- [ ] **Step 2: 실패 테스트 (`test/widget/add_bean_sheet_test.dart`)**

```dart
import 'package:beanprofile/features/beans/bean_form_screen.dart';
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('FAB → 시트 3옵션', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('add-camera')), findsOneWidget);
    expect(find.byKey(const Key('add-gallery')), findsOneWidget);
    expect(find.byKey(const Key('add-manual')), findsOneWidget);
  });

  testWidgets('직접 입력 → 빈 폼', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-manual')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(find.text('원두 추가'), findsWidgets); // AppBar 타이틀
  });

  testWidgets('촬영 → OCR(가짜) → 폼 프리필', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanListScreen(),
      db: db,
      ocr: FakeOcrService('Ethiopia\nWashed\nNotes: 블루베리'),
      photo: FakePhotoService(pickResult: '/tmp/pick.jpg'),
    ));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-camera')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsOneWidget);
    expect(find.text('Ethiopia'), findsOneWidget);
  });

  testWidgets('촬영 취소(pick=null) → 폼 안 열림', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    await t.pumpWidget(wrapApp(
      const BeanListScreen(),
      db: db,
      photo: FakePhotoService(pickResult: null),
    ));
    await t.pump();
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add-camera')));
    await t.pumpAndSettle();
    expect(find.byType(BeanFormScreen), findsNothing);
  });
}
```

- [ ] **Step 3: RED 확인**

Run: `flutter test test/widget/add_bean_sheet_test.dart`
Expected: FAIL (`showAddBeanSheet` 미배선 — FAB가 아직 폼으로 직행, 시트 key 없음)

- [ ] **Step 4: bean_list 배선 교체 + 디버그 제거 (`lib/features/beans/bean_list_screen.dart`)**

`import 'debug_ocr_screen.dart';` 제거, `import 'add_bean_sheet.dart';` 추가. AppBar의 임시 `debug-ocr` 액션(Task 1 Step 8) 제거 → 원래 AppBar로:

```dart
      appBar: AppBar(title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800))),
```

FAB onPressed 교체:

```dart
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddBeanSheet(context, ref),
        backgroundColor: context.colors.crema,
        child: const Icon(Icons.add, color: Colors.white),
      ),
```

- [ ] **Step 5: 디버그 화면 파일 삭제**

```bash
git rm lib/features/beans/debug_ocr_screen.dart
```

- [ ] **Step 6: GREEN + analyze + 전체**

Run: `flutter test test/widget/add_bean_sheet_test.dart`
Expected: PASS (4개)
Run: `flutter analyze`
Expected: No issues (디버그 화면 참조 제거 확인).
Run: `flutter test`
Expected: 전체 PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/beans/add_bean_sheet.dart lib/features/beans/bean_list_screen.dart test/widget/add_bean_sheet_test.dart
git commit -m "feat(m3): add-bean sheet (camera/gallery/manual) wired to OCR flow; drop debug screen"
```

---

### 최종: 전체 브랜치 리뷰 + finishing

- [ ] **opus 최종 리뷰**: `scripts/review-package <M3 BASE> HEAD`로 패키지 생성 → superpowers:requesting-code-review의 code-reviewer(opus)로 전체 diff 리뷰. BASE = Task 1 직전 커밋(= `cf841f9` 다음). Global Constraints + 누적 Minor를 렌즈로 전달.
- [ ] **Critical/Important 수정**: 단일 fix 서브에이전트에 전체 findings 전달 → 재리뷰.
- [ ] **finishing-a-development-branch**: `flutter test` 전체 green 확인 → main 유지(트렁크) → 사용자에게 `push + v0.3.0 태그` 확인.
- [ ] **DoD 기기 검증**: `v0.3.0` 태그 → CI `.ipa` → AltStore 설치 → 촬영/갤러리→OCR→칩 배정→저장→카드·상세 사진, OCR 실패 폴백까지 기기에서 확인.

---

## Self-Review (계획 작성자 체크)

**Spec coverage** (milestone-3-design.md 대비):
- §3 아키텍처/테스트 경계 → Task 1(seams·providers), Task 2(파서). ✅
- §4 데이터 흐름 → Task 6(진입→pick→recognize→parse→form), Task 5(persist-on-save). ✅
- §5 파서 5종 + 칩 → Task 2. ✅
- §6 폼 확장(프리필·하이라이트·칩·경계·실패배너) → Task 5. ✅
- §7 사진 저장·표시(photoPath·카드·상세) → Task 3 + Task 4. ✅
- §8 진입/상태(시트·성공·실패) → Task 6 + Task 5. ✅
- §9 권한·CI 스파이크 → Task 1 + 체크포인트 C1. ✅
- §11 3계층 테스트 → 각 Task 테스트(유닛/데이터/위젯) + 기기 전용 명시. ✅

**Placeholder scan:** TBD/TODO 없음. 모든 코드 단계에 실제 코드. ✅

**Type consistency:** `OcrDraft` 필드·`parseOcrText` 시그니처가 Task 2 정의와 Task 5/6 사용에서 일치. `BeanInput.photoPath`(Task 3) → Task 5 save·Task 4 표시에서 일관. `OcrService`/`PhotoService` 메서드명(`recognize`/`pick`/`persist`)이 Task 1 정의와 Task 5/6·헬퍼 가짜에서 일치. `BeanFormScreen({existing, draft, photoTempPath})`가 Task 5 정의와 Task 6 사용에서 일치. ✅

**주의 노트(구현 시):**
- 파서 키워드 맵은 **삽입 순서 의존**(복합어 먼저). 리뷰어에게 순서가 스펙임을 전달.
- `c.cup2` 등 테마 토큰명이 실제와 다르면 존재하는 토큰으로 대체(하이라이트/배너 배경은 시각 목적).
- 위젯 테스트에서 drift 스트림 watch → teardown 전 `db.close`/`pump` 주의(M2 T6 교훈): 상세/리스트 pump 테스트는 마지막에 `await t.pump(Duration(milliseconds:200))`.
- 스파이크 태그 버전 문자열이 iOS에서 거부되면 수치 임시 태그로 폴백(C1).
