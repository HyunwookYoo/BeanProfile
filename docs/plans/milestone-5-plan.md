# M5 백업 & 마무리 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로컬 전용 데이터를 사진까지 포함해 단일 JSON으로 내보내고 전체 교체로 복원하는 백업 기능 + 설정 화면 + 원두 검색/정렬을 추가해 v1을 마무리한다(릴리스 **v0.5.0**).

**Architecture:** 순수 코덱(`backup_codec.dart`, drift `toJson`/`fromJson` 재사용 + `photoBase64` 래핑)과 I/O 서비스(`backup_service.dart`, `share_plus`+`path_provider`, 기기 전용 seam)를 분리한다. 저장소는 읽기용 기존 `getTasteSnapshot()`을 재사용하고 쓰기용 `replaceAll()`(단일 트랜잭션) 하나만 추가한다. 검색/정렬은 스트림 리스트에 순수 함수 `sortFilterBeans()`를 적용한다. 신규 네이티브 플러그인은 `share_plus` 하나.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, drift 2.31, flutter_riverpod 3.3.2, share_plus(신규), path_provider(기존). 테스트는 `docs/testing.md` 3계층(인메모리 drift + `test/helpers.dart`).

## Global Constraints

- **한국어 UI:** 모든 사용자 노출 문자열은 한국어.
- **의존성 최소화:** 신규 네이티브 플러그인은 **`share_plus` 하나만**. `file_picker`·`archive`·`package_info_plus` 도입 금지.
- **커밋 전 초록불:** 각 태스크 커밋 직전 `flutter analyze`(0 issues) + `flutter test`(전부 통과).
- **커밋 트레일러(정확히):** `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` — 2번째 `-m`으로 첨부.
- **커밋 컨벤션:** `feat(m5): …` / `test(m5): …` / `chore(m5): …` (기존 저장소 스타일).
- **직커밋:** 트렁크 기반, `main`에 태스크 단위 직접 커밋.
- **스키마 무변경:** DB 테이블·마이그레이션을 바꾸지 않는다.
- **서비스 위치 규약:** I/O 서비스는 `lib/services/`(기존 `ocr_service.dart`·`photo_service.dart` 옆), 순수 로직은 피처 폴더 아래.
- **번들 ID 고정:** `com.hyunwook.beanprofile` (변경 금지).

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `lib/features/settings/backup_codec.dart` | **신규** · 순수. `encodeBackup`/`decodeBackup`/`DecodedBackup`. drift `toJson`/`fromJson` 위에 `schemaVersion`·`exportedAt`·`photoBase64`를 래핑. DB·파일·플러그인 무관 |
| `lib/services/backup_service.dart` | **신규** · I/O seam. `BackupService`(추상) + `BackupFile` + `SharePlusBackupService`(기기 전용). 사진 읽기/쓰기·공유·폴더 나열 |
| `lib/data/bean_repository.dart` | `replaceAll(TasteSnapshot)` 추가(단일 트랜잭션). 읽기는 기존 `getTasteSnapshot()` 재사용 |
| `lib/features/settings/settings_screen.dart` | 플레이스홀더 → 내보내기·가져오기(파일시트+확인다이얼로그)·앱 정보 |
| `lib/features/beans/bean_sort.dart` | **신규** · 순수. `BeanSort` enum + `sortFilterBeans()` |
| `lib/features/beans/bean_list_screen.dart` | 검색 필드 + 정렬 메뉴 + 검색 빈 상태 |
| `lib/providers.dart` | `backupServiceProvider` · `beanSortProvider` 추가 |
| `test/helpers.dart` | `beanRow`에 `roaster`/`photoPath`/`createdAt` 파라미터 추가 · `FakeBackupService` + `wrapApp`에 `backup` 파라미터 |
| `ios/Runner/Info.plist` | `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` = true |

---

## Task 1: 순수 백업 코덱 (`backup_codec.dart`)

**Files:**
- Create: `lib/features/settings/backup_codec.dart`
- Create: `test/unit/backup_codec_test.dart`
- Modify: `test/helpers.dart` (`beanRow`에 `roaster`/`photoPath`/`createdAt` 옵션 추가)

**Interfaces:**
- Consumes: `TasteSnapshot`(from `lib/data/models.dart`), `Bean`/`OriginComponent`/`Tasting`(from `lib/data/database.dart`, 각 `toJson()`/`fromJson()` 보유).
- Produces:
  - `String encodeBackup(TasteSnapshot snap, Map<String, Uint8List> photoBytes, {required DateTime exportedAt})`
  - `DecodedBackup decodeBackup(String jsonStr)` — 잘못된 JSON·미지 `schemaVersion`이면 `FormatException`
  - `class DecodedBackup { final TasteSnapshot snapshot; final Map<String, Uint8List> photoBytesByPath; }`

- [ ] **Step 1: `beanRow` 헬퍼에 옵션 파라미터 추가**

`test/helpers.dart`의 기존 `beanRow`를 아래로 교체(호출부 하위호환 — 전부 옵션):

```dart
Bean beanRow({
  int id = 1,
  String name = '원두',
  String roaster = '',
  List<String> cupNotes = const [],
  String? photoPath,
  DateTime? createdAt,
}) =>
    Bean(
      id: id, name: name, roaster: roaster, type: BeanType.singleOrigin,
      cupNotes: cupNotes, photoPath: photoPath,
      createdAt: createdAt ?? DateTime(2026, 7, 1),
    );
```

- [ ] **Step 2: 실패하는 코덱 테스트 작성**

`test/unit/backup_codec_test.dart`:

```dart
import 'dart:typed_data';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/settings/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

TasteSnapshot _sample() => TasteSnapshot(
      beans: [
        beanRow(id: 1, name: '예가체프', roaster: '프릳츠',
            cupNotes: const ['블루베리', '자스민'], photoPath: '/p/a.jpg'),
        beanRow(id: 2, name: '수프리모', roaster: '테라로사', cupNotes: const []),
      ],
      components: [
        compRow(id: 1, beanId: 1, country: 'Ethiopia', process: Process.washed),
        compRow(id: 2, beanId: 2, country: 'Colombia', process: Process.natural, ratioPercent: 100),
      ],
      tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
    );

void main() {
  final when = DateTime.utc(2026, 7, 22, 9, 41);

  test('encode→decode→encode 라운드트립 JSON이 동일하다', () {
    final photos = {'/p/a.jpg': Uint8List.fromList([10, 20, 30])};
    final json1 = encodeBackup(_sample(), photos, exportedAt: when);
    final decoded = decodeBackup(json1);
    final json2 = encodeBackup(decoded.snapshot, decoded.photoBytesByPath, exportedAt: when);
    expect(json2, json1);
  });

  test('컵노트·enum·사진 바이트가 보존된다', () {
    final photos = {'/p/a.jpg': Uint8List.fromList([10, 20, 30])};
    final decoded = decodeBackup(encodeBackup(_sample(), photos, exportedAt: when));
    final bean = decoded.snapshot.beans.firstWhere((b) => b.id == 1);
    expect(bean.cupNotes, ['블루베리', '자스민']);
    expect(bean.roaster, '프릳츠');
    expect(decoded.photoBytesByPath['/p/a.jpg'], [10, 20, 30]);
    expect(decoded.snapshot.components.first.process, Process.washed);
    expect(decoded.snapshot.tastings.single.overall, 5);
  });

  test('사진 없는 원두는 photoBase64 없이 왕복된다', () {
    final decoded = decodeBackup(encodeBackup(_sample(), const {}, exportedAt: when));
    expect(decoded.photoBytesByPath, isEmpty);
    expect(decoded.snapshot.beans, hasLength(2));
  });

  test('빈 스냅샷도 왕복된다', () {
    const empty = TasteSnapshot(beans: [], components: [], tastings: []);
    final decoded = decodeBackup(encodeBackup(empty, const {}, exportedAt: when));
    expect(decoded.snapshot.beans, isEmpty);
    expect(decoded.photoBytesByPath, isEmpty);
  });

  test('미지 schemaVersion은 FormatException', () {
    expect(
      () => decodeBackup('{"schemaVersion":999,"beans":[],"components":[],"tastings":[]}'),
      throwsFormatException,
    );
  });

  test('깨진 JSON은 FormatException', () {
    expect(() => decodeBackup('not json at all'), throwsFormatException);
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/unit/backup_codec_test.dart`
Expected: FAIL — `backup_codec.dart`가 없어 컴파일 에러(`encodeBackup`/`decodeBackup` undefined).

- [ ] **Step 4: 코덱 구현**

`lib/features/settings/backup_codec.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import '../../data/database.dart';
import '../../data/models.dart';

const _schemaVersion = 1;

/// 사진 base64를 포함한 단일 JSON 문자열. 순수 함수 — DB·파일·플러그인 무관.
/// [photoBytes]는 bean.photoPath → 파일 bytes 맵(서비스가 채워 넘긴다).
String encodeBackup(
  TasteSnapshot snap,
  Map<String, Uint8List> photoBytes, {
  required DateTime exportedAt,
}) {
  final beans = [
    for (final b in snap.beans)
      {
        ...b.toJson(),
        'photoBase64':
            (b.photoPath != null && photoBytes.containsKey(b.photoPath))
                ? base64Encode(photoBytes[b.photoPath]!)
                : null,
      },
  ];
  return jsonEncode({
    'schemaVersion': _schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'beans': beans,
    'components': [for (final c in snap.components) c.toJson()],
    'tastings': [for (final t in snap.tastings) t.toJson()],
  });
}

class DecodedBackup {
  final TasteSnapshot snapshot;
  final Map<String, Uint8List> photoBytesByPath;
  const DecodedBackup(this.snapshot, this.photoBytesByPath);
}

/// 잘못된 JSON·미지 버전·해석 실패는 모두 [FormatException].
DecodedBackup decodeBackup(String jsonStr) {
  final dynamic root = jsonDecode(jsonStr); // 깨진 JSON → FormatException 전파
  if (root is! Map || root['schemaVersion'] != _schemaVersion) {
    throw const FormatException('지원하지 않는 백업 형식 또는 버전입니다');
  }
  try {
    final photoBytes = <String, Uint8List>{};
    final beans = <Bean>[];
    for (final raw in (root['beans'] as List)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final b64 = m.remove('photoBase64') as String?;
      final bean = Bean.fromJson(m);
      beans.add(bean);
      if (b64 != null && bean.photoPath != null) {
        photoBytes[bean.photoPath!] = base64Decode(b64);
      }
    }
    final components = [
      for (final raw in (root['components'] as List))
        OriginComponent.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    final tastings = [
      for (final raw in (root['tastings'] as List))
        Tasting.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    return DecodedBackup(
      TasteSnapshot(beans: beans, components: components, tastings: tastings),
      photoBytes,
    );
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('백업 파일을 해석할 수 없습니다: $e');
  }
}
```

- [ ] **Step 5: 통과 확인 + analyze**

Run: `flutter test test/unit/backup_codec_test.dart && flutter analyze lib/features/settings/backup_codec.dart test/unit/backup_codec_test.dart`
Expected: 모든 테스트 PASS · analyze `No issues found!`

> 만약 `Bean.toJson()`의 날짜 표현이 예상과 달라도 라운드트립 테스트는 통과한다(encode↔decode 대칭). 실패한다면 drift 직렬화 대칭이 깨진 것이니 `toJson()`/`fromJson()` 호출부의 오타부터 확인.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/settings/backup_codec.dart test/unit/backup_codec_test.dart test/helpers.dart
git commit -m "feat(m5): 순수 백업 코덱 — drift toJson/fromJson + 사진 base64 래핑" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 저장소 `replaceAll` (전체 교체 복원)

**Files:**
- Modify: `lib/data/bean_repository.dart` (`replaceAll` 추가)
- Create: `test/unit/backup_repo_test.dart`

**Interfaces:**
- Consumes: `TasteSnapshot`, `AppDatabase`(기존 `db.transaction`/`db.batch`/`db.delete`), 행의 `toCompanion(false)`.
- Produces: `Future<void> BeanRepository.replaceAll(TasteSnapshot snap)` — 3테이블을 지우고 스냅샷으로 대체(id 보존, 단일 트랜잭션).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/backup_repo_test.dart`:

```dart
import 'package:beanprofile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('replaceAll이 기존을 지우고 스냅샷으로 교체한다(id 보존)', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);

    await repo.createBean(sampleSingle(name: '기존 원두')); // id 1 + 구성 1개

    final snap = TasteSnapshot(
      beans: [beanRow(id: 42, name: '복원된 원두', cupNotes: const ['자몽'])],
      components: [compRow(id: 7, beanId: 42, country: 'Kenya')],
      tastings: [tastingRow(id: 3, beanId: 42, overall: 5)],
    );

    await repo.replaceAll(snap);

    final after = await repo.getTasteSnapshot();
    expect(after.beans.map((b) => b.name), ['복원된 원두']);
    expect(after.beans.single.id, 42); // id 보존
    expect(after.components.single.country, 'Kenya');
    expect(after.tastings.single.overall, 5);
  });

  test('replaceAll에 빈 스냅샷을 주면 전부 비운다', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleBlend());

    await repo.replaceAll(const TasteSnapshot(beans: [], components: [], tastings: []));

    final after = await repo.getTasteSnapshot();
    expect(after.beans, isEmpty);
    expect(after.components, isEmpty);
    expect(after.tastings, isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/unit/backup_repo_test.dart`
Expected: FAIL — `replaceAll` undefined.

- [ ] **Step 3: `replaceAll` 구현**

`lib/data/bean_repository.dart`의 `getTasteSnapshot()`와 `watchTasteSnapshot()` 사이(파일 끝 `}` 직전)에 추가:

```dart
  /// 3테이블을 전부 지우고 스냅샷으로 대체한다(백업 복원). 단일 트랜잭션이라
  /// 전부 성공 또는 전부 롤백. 행의 id를 그대로 삽입해 백업 값을 보존한다.
  Future<void> replaceAll(TasteSnapshot snap) {
    return db.transaction(() async {
      await db.delete(db.tastings).go();
      await db.delete(db.originComponents).go();
      await db.delete(db.beans).go();
      await db.batch((b) {
        b.insertAll(db.beans, snap.beans.map((e) => e.toCompanion(false)));
        b.insertAll(
            db.originComponents, snap.components.map((e) => e.toCompanion(false)));
        b.insertAll(db.tastings, snap.tastings.map((e) => e.toCompanion(false)));
      });
    });
  }
```

> `toCompanion(false)`는 모든 컬럼(id 포함)을 `Value`로 채운다 → 명시적 id 삽입으로 백업 값이 보존된다. batch가 beans → components → tastings 순서로 실행하므로 FK가 만족된다.

- [ ] **Step 4: 통과 확인 + analyze**

Run: `flutter test test/unit/backup_repo_test.dart && flutter analyze lib/data/bean_repository.dart`
Expected: PASS · `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/data/bean_repository.dart test/unit/backup_repo_test.dart
git commit -m "feat(m5): BeanRepository.replaceAll — 단일 트랜잭션 전체 교체 복원" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 백업 서비스 seam + 의존성 + Fake

**Files:**
- Create: `lib/services/backup_service.dart` (추상 + `BackupFile` + 기기 전용 구현)
- Modify: `lib/providers.dart` (`backupServiceProvider`)
- Modify: `test/helpers.dart` (`FakeBackupService` + `wrapApp`에 `backup` 파라미터)
- Create: `test/unit/backup_service_test.dart` (Fake 계약 검증)
- Modify: `pubspec.yaml` (`share_plus`)
- Modify: `ios/Runner/Info.plist` (파일공유 키)

**Interfaces:**
- Consumes: `TasteSnapshot`, `encodeBackup`/`decodeBackup`(Task 1), `getApplicationDocumentsDirectory`(path_provider), `share_plus`.
- Produces:
  - `class BackupFile { final String path; final String name; final DateTime modified; }`
  - `abstract class BackupService { Future<void> exportBackup(TasteSnapshot snap); Future<List<BackupFile>> listBackups(); Future<TasteSnapshot> readBackup(BackupFile file); }`
  - `SharePlusBackupService`(기기 전용 구현), `backupServiceProvider`, `FakeBackupService`(테스트).

> **주의:** 실 구현 `SharePlusBackupService`는 `dart:io`/`path_provider`/`share_plus`를 쓰는 **기기 전용 코드**로, 기존 `MlkitOcrService`/`ImagePickerPhotoService`처럼 **호스트 테스트 대상이 아니다**. 호스트 테스트는 전부 `FakeBackupService`로 돈다. 이 태스크의 게이트는 "analyze 0 + 기존 테스트 전부 통과 + Fake 계약 테스트 통과"다.

- [ ] **Step 1: `share_plus` 추가**

Run: `flutter pub add share_plus`
Expected: `pubspec.yaml`에 `share_plus: ^<현재버전>`이 추가되고 `flutter pub get` 성공.

- [ ] **Step 2: iOS 파일공유 키 추가**

`ios/Runner/Info.plist`의 최상위 `<dict>` 안(다른 `<key>`들과 같은 레벨)에 추가:

```xml
	<key>UIFileSharingEnabled</key>
	<true/>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
```

> 이 두 키로 앱 문서 폴더가 iOS Files 앱(내 iPhone → BeanProfile)에 노출되어, 내보낸 `.json`을 꺼내고 새 백업을 넣을 수 있다. 호스트 테스트로는 검증 불가(기기/시뮬레이터 확인 사항).

- [ ] **Step 3: 서비스 seam 작성**

`lib/services/backup_service.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../features/settings/backup_codec.dart';

/// 노출 폴더에서 발견된 백업 파일 한 건.
class BackupFile {
  final String path;
  final String name;
  final DateTime modified;
  const BackupFile({required this.path, required this.name, required this.modified});
}

/// 백업 I/O seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class BackupService {
  /// 스냅샷을 사진 포함 JSON으로 문서 폴더에 쓰고 공유 시트를 띄운다.
  Future<void> exportBackup(TasteSnapshot snap);

  /// 노출(문서) 폴더의 백업 `.json` 목록(최신 먼저).
  Future<List<BackupFile>> listBackups();

  /// 파일을 읽어 디코드하고, 사진을 새 기기에 기록한 뒤
  /// photoPath를 재작성한 스냅샷을 돌려준다(DB 교체는 호출부가 수행).
  Future<TasteSnapshot> readBackup(BackupFile file);
}

class SharePlusBackupService implements BackupService {
  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  String _stamp(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}';
  }

  @override
  Future<void> exportBackup(TasteSnapshot snap) async {
    final photoBytes = <String, Uint8List>{};
    for (final b in snap.beans) {
      final p = b.photoPath;
      if (p != null && await File(p).exists()) {
        photoBytes[p] = await File(p).readAsBytes();
      }
    }
    final json = encodeBackup(snap, photoBytes, exportedAt: DateTime.now());
    final dir = await _docs();
    final name = 'beanprofile-backup-${_stamp(DateTime.now())}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json);
    // share_plus: 설치된 버전 API에 맞춘다. (v9+는 SharePlus.instance.share 형태)
    await Share.shareXFiles([XFile(file.path)], subject: name);
  }

  @override
  Future<List<BackupFile>> listBackups() async {
    final dir = await _docs();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    final result = [
      for (final f in files)
        BackupFile(
          path: f.path,
          name: f.uri.pathSegments.last,
          modified: f.statSync().modified,
        ),
    ];
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  @override
  Future<TasteSnapshot> readBackup(BackupFile file) async {
    final decoded = decodeBackup(await File(file.path).readAsString());
    final dir = await _docs();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);

    final rewritten = <Bean>[];
    var i = 0;
    for (final b in decoded.snapshot.beans) {
      final bytes = b.photoPath != null ? decoded.photoBytesByPath[b.photoPath] : null;
      if (bytes != null) {
        final dest =
            '${photos.path}/${DateTime.now().microsecondsSinceEpoch}_${i++}.jpg';
        await File(dest).writeAsBytes(bytes);
        rewritten.add(b.copyWith(photoPath: Value(dest)));
      } else {
        // 사진 없음/소실 → 깨진 옛 경로를 남기지 않고 null로.
        rewritten.add(b.copyWith(photoPath: const Value(null)));
      }
    }
    return TasteSnapshot(
      beans: rewritten,
      components: decoded.snapshot.components,
      tastings: decoded.snapshot.tastings,
    );
  }
}
```

> `Share.shareXFiles`가 설치된 share_plus 버전에서 이름이 다르면(예: `SharePlus.instance.share(ShareParams(files: [XFile(file.path)]))`) 그 API로 바꾼다. 이 파일은 기기 전용이라 호스트 테스트가 없으니, **`flutter analyze`가 통과하는 형태**로 맞추면 된다.

- [ ] **Step 4: provider 등록**

`lib/providers.dart` 상단 import에 추가:

```dart
import 'services/backup_service.dart';
```

`photoServiceProvider` 줄 아래에 추가:

```dart
final backupServiceProvider = Provider<BackupService>((ref) => SharePlusBackupService());
```

- [ ] **Step 5: `FakeBackupService` + `wrapApp` 확장**

`test/helpers.dart`의 import에 추가:

```dart
import 'package:beanprofile/services/backup_service.dart';
```

`wrapApp`을 아래로 교체(파라미터 `backup` 추가):

```dart
Widget wrapApp(Widget child,
        {AppDatabase? db, OcrService? ocr, PhotoService? photo, BackupService? backup}) =>
    ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
        if (ocr != null) ocrServiceProvider.overrideWithValue(ocr),
        if (photo != null) photoServiceProvider.overrideWithValue(photo),
        if (backup != null) backupServiceProvider.overrideWithValue(backup),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
```

`FakePhotoService` 아래(파일 끝)에 추가:

```dart
class FakeBackupService implements BackupService {
  FakeBackupService({this.backups = const [], TasteSnapshot? readResult, this.throwOnRead = false})
      : _readResult = readResult;
  final List<BackupFile> backups;
  final TasteSnapshot? _readResult;
  final bool throwOnRead;

  int exportCalls = 0;
  int readCalls = 0;
  TasteSnapshot? lastExported;

  @override
  Future<void> exportBackup(TasteSnapshot snap) async {
    exportCalls++;
    lastExported = snap;
  }

  @override
  Future<List<BackupFile>> listBackups() async => backups;

  @override
  Future<TasteSnapshot> readBackup(BackupFile file) async {
    readCalls++;
    if (throwOnRead) throw const FormatException('bad backup');
    return _readResult ?? const TasteSnapshot(beans: [], components: [], tastings: []);
  }
}
```

- [ ] **Step 6: Fake 계약 테스트 작성**

`test/unit/backup_service_test.dart`:

```dart
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('FakeBackupService가 export 호출을 기록한다', () async {
    final fake = FakeBackupService();
    await fake.exportBackup(const TasteSnapshot(beans: [], components: [], tastings: []));
    expect(fake.exportCalls, 1);
  });

  test('FakeBackupService.readBackup이 주입한 스냅샷을 돌려준다', () async {
    final snap = TasteSnapshot(beans: [beanRow(id: 9, name: '복원됨')], components: const [], tastings: const []);
    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      readResult: snap,
    );
    final files = await fake.listBackups();
    expect(files.single.name, 'x.json');
    final got = await fake.readBackup(files.single);
    expect(got.beans.single.name, '복원됨');
  });
}
```

- [ ] **Step 7: 전체 초록불 확인**

Run: `flutter analyze && flutter test`
Expected: analyze `No issues found!` · 기존 테스트 전부 + 신규 Fake 테스트 PASS.

- [ ] **Step 8: 커밋**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist lib/services/backup_service.dart lib/providers.dart test/helpers.dart test/unit/backup_service_test.dart
git commit -m "feat(m5): 백업 서비스 seam + share_plus + Files 노출 키 + Fake" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 설정 화면 (내보내기·가져오기·앱 정보)

**Files:**
- Modify: `lib/features/settings/settings_screen.dart` (플레이스홀더 → 실제 화면)
- Create: `test/widget/settings_screen_test.dart`

**Interfaces:**
- Consumes: `backupServiceProvider`/`beanRepositoryProvider`(providers), `BackupFile`/`BackupService`(Task 3), `replaceAll`(Task 2), `context.colors`(theme).
- Produces: 사용자 노출 화면. 위젯 테스트가 찾는 문자열: `'데이터 내보내기'`, `'데이터 가져오기'`, `'복원'`, `'가져올 백업 파일이 없어요'`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/widget/settings_screen_test.dart`:

```dart
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/settings/settings_screen.dart';
import 'package:beanprofile/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('내보내기 탭 → 서비스가 호출된다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeBackupService();
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 내보내기'));
    await t.pumpAndSettle();

    expect(fake.exportCalls, 1);
  });

  testWidgets('가져오기 → 파일 선택 → 확인 → replaceAll로 교체', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '기존'));

    final restore = TasteSnapshot(
      beans: [beanRow(id: 99, name: '복원됨')],
      components: [compRow(id: 5, beanId: 99, country: 'Kenya')],
      tastings: const [],
    );
    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      readResult: restore,
    );
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();
    await t.tap(find.text('x.json')); // 파일 시트 항목
    await t.pumpAndSettle();
    await t.tap(find.text('복원')); // 확인 다이얼로그
    await t.pumpAndSettle();

    final after = await repo.getTasteSnapshot();
    expect(after.beans.map((b) => b.name), ['복원됨']);
  });

  testWidgets('백업 파일이 없으면 안내한다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeBackupService(backups: const []);
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();

    expect(find.textContaining('가져올 백업 파일이 없어요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/settings_screen_test.dart`
Expected: FAIL — 현재 화면은 `'설정은 곧 추가됩니다'`뿐이라 `'데이터 내보내기'`를 못 찾음.

- [ ] **Step 3: 설정 화면 구현**

`lib/features/settings/settings_screen.dart` 전체를 아래로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/backup_service.dart';
import '../../theme.dart';

const kAppVersion = 'v0.5.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('설정', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionLabel(context, '데이터'),
          _tile(
            context,
            icon: Icons.ios_share,
            title: '데이터 내보내기',
            subtitle: '사진 포함 JSON 백업 · 공유 시트',
            onTap: () => _export(context, ref),
          ),
          const SizedBox(height: 9),
          _tile(
            context,
            icon: Icons.download,
            title: '데이터 가져오기',
            subtitle: '백업에서 복원 · 현재 데이터를 대체',
            onTap: () => _import(context, ref),
          ),
          _sectionLabel(context, '정보'),
          _tile(
            context,
            icon: Icons.info_outline,
            title: '버전',
            trailing: Text(kAppVersion, style: monoStyle(size: 13, weight: FontWeight.w700, color: c.espresso)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('모든 데이터는 이 기기에만 저장됩니다 · 오프라인 전용',
                style: TextStyle(fontSize: 11, color: c.appMuted)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: monoStyle(size: 10.5, weight: FontWeight.w700, color: context.colors.appMuted)),
      );

  Widget _tile(BuildContext context,
      {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    final c = context.colors;
    return Material(
      color: c.cup,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.appLine),
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.cremaInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: TextStyle(fontSize: 11, color: c.appMuted)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
                Icon(Icons.chevron_right, color: c.appMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(beanRepositoryProvider);
    final service = ref.read(backupServiceProvider);
    try {
      final snap = await repo.getTasteSnapshot();
      await service.exportBackup(snap);
    } catch (e) {
      if (context.mounted) _snack(context, '내보내기에 실패했어요: $e');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    final repo = ref.read(beanRepositoryProvider);

    List<BackupFile> files;
    try {
      files = await service.listBackups();
    } catch (e) {
      if (context.mounted) _snack(context, '백업 폴더를 열 수 없어요: $e');
      return;
    }
    if (!context.mounted) return;
    if (files.isEmpty) {
      _snack(context, '가져올 백업 파일이 없어요 — Files 앱의 이 폴더에 .json을 넣어 주세요');
      return;
    }

    final picked = await showModalBottomSheet<BackupFile>(
      context: context,
      builder: (_) => _FileSheet(files: files),
    );
    if (picked == null || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ReplaceConfirmDialog(),
    );
    if (ok != true || !context.mounted) return;

    try {
      final snap = await service.readBackup(picked);
      await repo.replaceAll(snap);
      if (context.mounted) _snack(context, '복원했어요 · 원두 ${snap.beans.length}개');
    } catch (e) {
      if (context.mounted) _snack(context, '백업 파일을 읽을 수 없어요: $e');
    }
  }
}

class _FileSheet extends StatelessWidget {
  const _FileSheet({required this.files});
  final List<BackupFile> files;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: c.appLine, borderRadius: BorderRadius.circular(3)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('백업 파일 선택', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            for (final f in files)
              ListTile(
                leading: Icon(Icons.description_outlined, color: c.cremaInk),
                title: Text(f.name, style: monoStyle(size: 12, weight: FontWeight.w700, color: c.espresso)),
                subtitle: Text(_fmt(f.modified), style: TextStyle(fontSize: 11, color: c.appMuted)),
                onTap: () => Navigator.of(context).pop(f),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }
}

class _ReplaceConfirmDialog extends StatelessWidget {
  const _ReplaceConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: Text('현재 데이터가 모두 대체됩니다', style: TextStyle(color: c.cherry, fontWeight: FontWeight.w800, fontSize: 17)),
      content: const Text('가져오기는 지금 기록을 백업 내용으로 완전히 교체합니다. 되돌릴 수 없으니, 먼저 내보내기로 현재 상태를 백업해 두는 것을 권장합니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.cherry),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('복원'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 통과 확인 + analyze**

Run: `flutter test test/widget/settings_screen_test.dart && flutter analyze lib/features/settings/settings_screen.dart`
Expected: 3개 테스트 PASS · `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/features/settings/settings_screen.dart test/widget/settings_screen_test.dart
git commit -m "feat(m5): 설정 화면 — 내보내기·가져오기(파일시트+교체확인)·버전" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 검색/정렬 순수 함수 (`bean_sort.dart`)

**Files:**
- Create: `lib/features/beans/bean_sort.dart`
- Create: `test/unit/bean_sort_filter_test.dart`
- Modify: `lib/providers.dart` (`beanSortProvider`)

**Interfaces:**
- Consumes: `BeanSummary`(models), `beanRow`(helpers, Task 1에서 `roaster`/`createdAt` 추가됨).
- Produces:
  - `enum BeanSort { recent, rating, name }` + `String get label`
  - `List<BeanSummary> sortFilterBeans(List<BeanSummary> beans, String query, BeanSort sort)`
  - `beanSortProvider`(NotifierProvider<…, BeanSort>, 기본 `recent`).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/unit/bean_sort_filter_test.dart`:

```dart
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/beans/bean_sort.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

BeanSummary _s(String name, {String roaster = '', double? rating, int day = 1}) => BeanSummary(
      bean: beanRow(name: name, roaster: roaster, createdAt: DateTime(2026, 7, day)),
      originLabel: null,
      avgRating: rating,
      tastingCount: rating == null ? 0 : 1,
    );

void main() {
  final beans = [
    _s('예가체프', roaster: '프릳츠', rating: 4.2, day: 1),
    _s('수프리모', roaster: '테라로사', rating: 4.8, day: 3),
    _s('하우스 블렌드', roaster: '프릳츠', rating: null, day: 2),
  ];

  test('검색은 이름·로스터리 부분일치(대소문자 무시)', () {
    expect(sortFilterBeans(beans, '예가', BeanSort.recent).map((b) => b.bean.name), ['예가체프']);
    expect(sortFilterBeans(beans, '프릳츠', BeanSort.recent).map((b) => b.bean.name).toSet(),
        {'예가체프', '하우스 블렌드'});
    expect(sortFilterBeans(beans, '없음', BeanSort.recent), isEmpty);
  });

  test('최근순 = createdAt 내림차순', () {
    expect(sortFilterBeans(beans, '', BeanSort.recent).map((b) => b.bean.name),
        ['수프리모', '하우스 블렌드', '예가체프']);
  });

  test('평점순 = 평점 내림차순, 평점 없는 원두는 뒤로', () {
    expect(sortFilterBeans(beans, '', BeanSort.rating).map((b) => b.bean.name),
        ['수프리모', '예가체프', '하우스 블렌드']);
  });

  test('이름순 = 가나다', () {
    expect(sortFilterBeans(beans, '', BeanSort.name).map((b) => b.bean.name),
        ['수프리모', '예가체프', '하우스 블렌드']);
  });

  test('원본 리스트를 변형하지 않는다', () {
    final original = [...beans];
    sortFilterBeans(beans, '', BeanSort.name);
    expect(beans, original); // 순서 그대로
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/unit/bean_sort_filter_test.dart`
Expected: FAIL — `bean_sort.dart` 없음.

- [ ] **Step 3: 순수 함수 구현**

`lib/features/beans/bean_sort.dart`:

```dart
import '../../data/models.dart';

enum BeanSort { recent, rating, name }

extension BeanSortLabel on BeanSort {
  String get label => switch (this) {
        BeanSort.recent => '최근순',
        BeanSort.rating => '평점순',
        BeanSort.name => '이름순',
      };
}

/// 스트림 리스트에 검색어 필터 + 정렬을 적용한다. 원본은 변형하지 않는다.
/// 검색 = 이름·로스터리 부분일치(대소문자 무시). 동점은 최근순으로 깬다.
List<BeanSummary> sortFilterBeans(List<BeanSummary> beans, String query, BeanSort sort) {
  final q = query.trim().toLowerCase();
  final list = q.isEmpty
      ? [...beans]
      : beans
          .where((b) =>
              b.bean.name.toLowerCase().contains(q) ||
              b.bean.roaster.toLowerCase().contains(q))
          .toList();

  int recent(BeanSummary a, BeanSummary b) => b.bean.createdAt.compareTo(a.bean.createdAt);

  switch (sort) {
    case BeanSort.recent:
      list.sort(recent);
    case BeanSort.rating:
      list.sort((a, b) {
        final ar = a.avgRating, br = b.avgRating;
        if (ar == null && br == null) return recent(a, b);
        if (ar == null) return 1; // 평점 없는 원두는 뒤로
        if (br == null) return -1;
        final c = br.compareTo(ar);
        return c != 0 ? c : recent(a, b);
      });
    case BeanSort.name:
      list.sort((a, b) {
        final c = a.bean.name.toLowerCase().compareTo(b.bean.name.toLowerCase());
        return c != 0 ? c : recent(a, b);
      });
  }
  return list;
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/unit/bean_sort_filter_test.dart`
Expected: 5개 테스트 PASS.

- [ ] **Step 5: `beanSortProvider` 등록**

`lib/providers.dart` 상단 import에 추가:

```dart
import 'features/beans/bean_sort.dart';
```

파일 끝에 추가:

```dart
class BeanSortNotifier extends Notifier<BeanSort> {
  @override
  BeanSort build() => BeanSort.recent;
  void set(BeanSort sort) => state = sort;
}

final beanSortProvider = NotifierProvider<BeanSortNotifier, BeanSort>(BeanSortNotifier.new);
```

- [ ] **Step 6: analyze + 커밋**

Run: `flutter analyze lib/features/beans/bean_sort.dart lib/providers.dart test/unit/bean_sort_filter_test.dart`
Expected: `No issues found!`

```bash
git add lib/features/beans/bean_sort.dart lib/providers.dart test/unit/bean_sort_filter_test.dart
git commit -m "feat(m5): sortFilterBeans 순수 함수 + beanSortProvider" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 원두 리스트 검색/정렬 UI + 검색 빈 상태

**Files:**
- Modify: `lib/features/beans/bean_list_screen.dart`
- Create: `test/widget/bean_list_search_test.dart`

**Interfaces:**
- Consumes: `beanListProvider`(기존), `beanSortProvider`(Task 5), `sortFilterBeans`/`BeanSort`(Task 5), 기존 `BeanCard`/`showAddBeanSheet`/`BeanDetailScreen`/`SwipeDeleteBackground`/`confirmDeleteBeanDialog`.
- Produces: 검색·정렬이 적용된 리스트 화면. 테스트가 쓰는 것: `find.byType(TextField)`, `find.byIcon(Icons.sort)`, 정렬 메뉴 텍스트(`'이름순'` 등), 검색 빈 상태 `'맞는 원두가 없어요'`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/widget/bean_list_search_test.dart`:

```dart
import 'package:beanprofile/features/beans/bean_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('검색어로 필터링된다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '예가체프 코체레'));
    await repo.createBean(sampleSingle(name: '수프리모', country: 'Colombia'));

    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('수프리모'), findsOneWidget);

    await t.enterText(find.byType(TextField), '예가');
    await t.pumpAndSettle();
    expect(find.text('예가체프 코체레'), findsOneWidget);
    expect(find.text('수프리모'), findsNothing);
  });

  testWidgets('검색 결과가 없으면 안내한다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '예가체프'));

    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pumpAndSettle();

    expect(find.textContaining('맞는 원두가 없어요'), findsOneWidget);
  });

  testWidgets('이름순 정렬로 전환하면 순서가 바뀐다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '하우스')); // 먼저 생성(오래됨)
    await repo.createBean(sampleSingle(name: '가나다')); // 나중 생성(최신)

    await t.pumpWidget(wrapApp(const BeanListScreen(), db: db));
    await t.pumpAndSettle();
    // 기본 최근순: '가나다'(최신)가 위
    expect(t.getTopLeft(find.text('가나다')).dy < t.getTopLeft(find.text('하우스')).dy, isTrue);

    await t.tap(find.byIcon(Icons.sort));
    await t.pumpAndSettle();
    await t.tap(find.text('이름순').last);
    await t.pumpAndSettle();

    // 이름순: '가나다'가 '하우스'보다 위(가나다 정렬상 앞)
    expect(t.getTopLeft(find.text('가나다')).dy < t.getTopLeft(find.text('하우스')).dy, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/widget/bean_list_search_test.dart`
Expected: FAIL — 현재 리스트에 `TextField`/`Icons.sort`가 없다.

- [ ] **Step 3: 리스트 화면 개조**

`lib/features/beans/bean_list_screen.dart` 전체를 아래로 교체(FAB·Dismissible·네비게이션은 그대로 유지):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'add_bean_sheet.dart';
import 'bean_detail_screen.dart';
import 'bean_sort.dart';
import 'widgets/bean_card.dart';
import 'widgets/delete_ux.dart';

class BeanListScreen extends ConsumerStatefulWidget {
  const BeanListScreen({super.key});

  @override
  ConsumerState<BeanListScreen> createState() => _BeanListScreenState();
}

class _BeanListScreenState extends ConsumerState<BeanListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beans = ref.watch(beanListProvider);
    final sort = ref.watch(beanSortProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<BeanSort>(
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (s) => ref.read(beanSortProvider.notifier).set(s),
            itemBuilder: (_) => [
              for (final s in BeanSort.values) PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddBeanSheet(context, ref),
        backgroundColor: context.colors.crema,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: beans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('아직 기록한 원두가 없어요\n＋ 로 첫 원두를 추가해 보세요',
                  textAlign: TextAlign.center, style: TextStyle(color: context.colors.appMuted)),
            );
          }
          final shown = sortFilterBeans(list, _query, sort);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text("'$_query'에 맞는 원두가 없어요",
                            style: TextStyle(color: context.colors.appMuted)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = shown[i];
                          return Dismissible(
                            key: ValueKey('bean-${s.bean.id}'),
                            direction: DismissDirection.endToStart,
                            background: const SwipeDeleteBackground(),
                            confirmDismiss: (_) async {
                              final ok = await confirmDeleteBeanDialog(context);
                              if (ok) await ref.read(beanRepositoryProvider).deleteBean(s.bean.id);
                              return false; // 반응형 리빌드가 삭제된 카드 제거(assert 회피)
                            },
                            child: BeanCard(
                              summary: s,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => BeanDetailScreen(beanId: s.bean.id))),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: '이름 · 로스터리 검색',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: c.cup,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.appLine)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.appLine)),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인 + analyze**

Run: `flutter test test/widget/bean_list_search_test.dart && flutter analyze lib/features/beans/bean_list_screen.dart`
Expected: 3개 테스트 PASS · `No issues found!`

> `_SearchField`의 `suffixIcon`이 `controller.text`에 반응하려면 `onChanged`가 `setState`를 부르므로 리빌드되어 갱신된다(부모 `_query` 갱신 시 함께 리빌드).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/beans/bean_list_screen.dart test/widget/bean_list_search_test.dart
git commit -m "feat(m5): 원두 리스트 검색 필드 + 정렬 메뉴 + 검색 빈 상태" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 최종 검증 (전체 태스크 후)

- [ ] **전체 스위트 초록불**

Run: `flutter analyze && flutter test`
Expected: analyze `No issues found!` · 기존 137 + 신규(코덱 6 · repo 2 · 서비스 2 · 설정 3 · 정렬 5 · 리스트 3 ≈ **+21**) 전부 통과.

> Windows 호스트에서 `flutter test`가 파일별 출력을 드물게 누락/중복하면 `flutter test --concurrency=1 -r expanded`로 재확인.

- [ ] **whole-branch opus 리뷰** — SDD 관례. 커밋 범위 `git log`로 확인 후 `scripts/review-package <base> HEAD`.

- [ ] **문서/상태 갱신** — `CLAUDE.md` Status에 M5 항목 추가, `docs/plans/roadmap.md`의 M5 행 완료 표기. (릴리스 커밋과 함께)

- [ ] **릴리스** — `v0.5.0` 태그 푸시 → CI `.ipa` → AltStore. (사용자 확인 후)

---

## Self-Review (계획 ↔ 설계 대조)

**커버리지:** 설계 §2 범위 내 항목 전부 태스크 존재 — 코덱(T1)·replaceAll(T2)·서비스+deps+Info.plist(T3)·설정화면(T4)·검색정렬 순수(T5)·리스트 UI+검색빈상태(T6). 설계 §8 테스트 표의 파일 6종 모두 계획에 포함(`backup_codec`·`bean_sort_filter`·`backup_repo`·`settings_screen`·`bean_list_search` + Fake 계약 `backup_service_test`). 선택적 통합 테스트(`backup_roundtrip`)는 YAGNI로 v1 제외(코덱 라운드트립 유닛 + 설정 위젯이 왕복을 실질 커버).

**설계 대비 조정 2건(문서에 반영 필요):** ① 코덱이 hand-rolled ISO 포맷 대신 **drift `toJson`/`fromJson` 재사용**(31필드 수기 매핑의 오타 버그류 제거, 대칭성으로 라운드트립 보장) → 설계 §5 갱신. ② import 후 **프로바이더 invalidate 불필요**(drift `watch` 스트림이 `replaceAll` 쓰기에 자동 반응) → 설계 §4 흐름의 마지막 줄 삭제.

**타입 일관성:** `TasteSnapshot`(재사용)·`BackupFile`·`DecodedBackup`·`BeanSort`·`sortFilterBeans`·`replaceAll`·`backupServiceProvider`·`beanSortProvider` 시그니처가 태스크 간 일치. `beanSortProvider.notifier).set(...)` 호출부(T6)와 정의(T5) 일치. `wrapApp(backup:)`(T3 정의) ↔ 사용(T4).

**플레이스홀더 스캔:** 없음. share_plus 실호출은 기기 전용 seam이라 "설치 버전 API에 맞춘다"는 지시가 유일한 열린 항목 — 의도된 것(호스트 테스트 무관, analyze로 검증).
