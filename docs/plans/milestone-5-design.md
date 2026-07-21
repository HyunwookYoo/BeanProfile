# M5 — 백업 & 마무리 (설계)

> 상태: 승인됨(2026-07-22). 계획: `milestone-5-plan.md`. 목표 릴리스 **v0.5.0**.
> 목업: [`../mockups/m5-backup-settings.html`](../mockups/m5-backup-settings.html) · v1 원안: [`../mockups/ui-mockup-v1.html`](../mockups/ui-mockup-v1.html)

## 1. 배경 & 목표

탭 3 「설정」은 아직 `'설정은 곧 추가됩니다'` 한 줄짜리 플레이스홀더다(`lib/features/settings/settings_screen.dart`). 탭 1 「원두」 리스트에는 검색·정렬이 없다. M5는 **v1의 마지막 마일스톤** — 백업(JSON 내보내기/가져오기) · 설정 화면 · 원두 검색/정렬 · 빈 상태 점검.

**설계 전제:** 데이터는 로컬 전용이고 앱은 AltStore 사이드로드(7일 갱신)다. CLAUDE.md 배포 제약이 명시하듯 **서명 불일치나 재설치로 앱 컨테이너가 지워지면 DB와 사진이 통째로 사라진다.** 백업은 그 소실에 대한 **유일한 안전망**이다. 그래서 M5의 헤드라인은 백업이고, 데이터뿐 아니라 **사진까지 포함해 완전 복원**되는 것이 요구사항이다.

## 2. 목표 & 범위

**범위 내:**
- `backup_codec.dart` — 순수 인코드/디코드 (사진 base64 포함, DB·파일 무관)
- `backup_service.dart` — I/O 경계 (`share_plus` + `path_provider`), 인터페이스 + Fake
- `BeanRepository.replaceAll()` — 단일 트랜잭션 전체 교체 (읽기는 기존 `getTasteSnapshot()` 재사용)
- `SettingsScreen` 교체 — 내보내기 · 가져오기 · 앱 정보
- 원두 리스트 검색 + 정렬(최근/평점/이름) + 검색-결과-없음 빈 상태
- iOS `Info.plist` 파일공유 키

**범위 밖(무변경):** DB 스키마·마이그레이션, 원두/시음 CRUD·폼·OCR, 취향 대시보드(M4), **병합 import**, **file_picker**, 브루잉 파라미터 등 설계 §8 스코프 밖.

## 3. 확정된 결정 (브레인스토밍 2026-07-22)

이 4건이 M5의 approach를 정하며, 설계 §7 원안(`share_plus + file_picker` 나열)을 근거를 갖고 조정한다.

### 3.1 내보내기 = 공유 시트 / 가져오기 = 무플러그인

설계 §7은 `share_plus + file_picker`를 나열했으나 둘 다 아직 `pubspec.yaml`에 없다. **배포 제약이 지배적이다** — 개발 머신은 Windows, Mac이 없어 iOS 빌드는 CI macOS 러너가 전부다. 네이티브 플러그인이 iOS 빌드를 깨면 "iOS는 존재하지 않는다"(M4가 의존성 0을 택한 이유와 동일).

→ **내보내기만 `share_plus`**(저위험, Flutter 팀 계열, 공유 시트로 메일·iCloud·Files 저장 → Mac 없는 Windows PC로 빼내기에 필수), **가져오기는 `file_picker` 없이** iOS `Info.plist` 파일공유 노출 폴더 + 이미 있는 `path_provider`로 읽는다. `file_picker`(iOS 포드스펙·권한 이력이 가장 까다로운 플러그인)를 회피해 CI 리스크를 최소화한다. 신규 네이티브 플러그인은 **`share_plus` 하나뿐.**

### 3.2 가져오기 의미 = 전체 교체 (restore)

백업은 **sync가 아니라 restore**다. 가져오면 기존 3테이블을 전부 지우고 백업 내용으로 대체한다. 실수 방지로 **확인 다이얼로그 + "먼저 현재 데이터 내보내기" 안내**를 둔다. 병합은 같은 백업 재적용 시 중복, autoincrement id 재매핑, 1인용 앱에서 두 데이터셋 병합의 의미 모호 — 채택하지 않는다.

### 3.3 사진 = base64 내장 (self-contained)

단일 `.json`에 사진까지 담아 파일 하나로 완결한다. **재난 복구(§1)에서 사진도 살아남아야 백업의 존재 이유에 부합**한다. `dart:convert`만 쓰므로 신규 플러그인이 없다. 대가는 파일 크기(개인 규모 수 MB — 공유·파싱에 문제 없음)와 가져오기 시 디코드→파일 쓰기→경로 재작성 로직.

### 3.4 zip 도입 안 함

self-contained 압축 번들(`archive` 패키지, 순수 Dart라 네이티브 리스크는 없음)은 base64 대비 이득이 marginal하고 복잡도만 는다. **base64로 충분. YAGNI.** 신규 의존성은 `share_plus`로 끝낸다.

## 4. 데이터 흐름 & 타입

```
[내보내기]
BeanRepository.getTasteSnapshot()   →  TasteSnapshot (3테이블 행, Bean.photoPath 포함)
        +  각 bean.photoPath 파일 → bytes                    ← 서비스가 읽음
        ↓  encodeBackup(snapshot, photoBytesByPath)          ← 순수, dart:convert
   JSON String  →  문서 폴더에 timestamped 파일  →  share_plus 공유 시트

[가져오기]
listImportable()  →  노출(문서) 폴더의 *.json 목록
   선택 → 파일 읽기 → decodeBackup(json)                     ← 순수 (throws FormatException)
        →  DecodedBackup {snapshot, photoBytesByOldPath}
        →  사진 bytes를 새 기기 문서 폴더에 쓰기 · Bean.photoPath 재작성
        →  BeanRepository.replaceAll(snapshot)                ← 단일 트랜잭션
        (drift watch 스트림이 테이블 쓰기에 자동 반응 → 리스트·상세·대시보드 갱신, 수동 invalidate 불필요)
```

`getTasteSnapshot()`은 M4에서 이미 3테이블 전체 행(Bean은 `photoPath` 컬럼 포함)을 반환하므로 **내보내기 읽기에 그대로 재사용**한다. 저장소에 새로 추가되는 건 `replaceAll()` 하나뿐.

```dart
// backup_codec.dart — 순수 (drift 생성 toJson/fromJson 재사용)
String encodeBackup(TasteSnapshot snap, Map<String, Uint8List> photoBytes, {required DateTime exportedAt});

class DecodedBackup {
  final TasteSnapshot snapshot;                 // photoPath = 백업 당시의 옛 경로
  final Map<String, Uint8List> photoBytesByPath; // 옛 경로 → 디코드된 bytes
}
DecodedBackup decodeBackup(String json);        // 잘못된 JSON·미지 버전 → FormatException
```

`TasteSnapshot`(M4의 `{beans, components, tastings}`)을 백업에도 재사용한다 — 구조가 동일하고 사진 bytes는 스냅샷 밖에서 맵으로 따로 나른다. 경로 재작성·파일 I/O는 **순수 코덱 밖**(서비스)에 둔다. 코덱은 drift가 각 행에 생성한 `toJson`/`fromJson`을 재사용해(**31필드 수기 매핑을 피해** 오타 버그류를 없애고, encode↔decode 대칭이 라운드트립을 보장) 그 위에 `schemaVersion`·`exportedAt`·`photoBase64`만 래핑한다. DB·파일·플러그인 없이 유닛 테스트된다(M4 `taste_profile.dart`, M3.3 `parseOcr`와 같은 이유).

## 5. 백업 포맷 규칙 (`schemaVersion: 1`)

단일 JSON 객체:

```json
{ "schemaVersion": 1, "exportedAt": "2026-07-22T09:41:00.000Z",
  "beans":      [ { "id":1, "name":"…", "type":0, "roastLevel":1, "roastDate":"…"|null,
                    "cupNotes":["블루베리"], "photoBase64":"…"|null, "createdAt":"…", … } ],
  "components": [ { "id":1, "beanId":1, "country":"…", "process":0, "ratioPercent":null, … } ],
  "tastings":   [ { "id":1, "beanId":1, "date":"…", "acidity":4, …, "overall":4, "comment":null, "createdAt":"…" } ] }
```

| 항목 | 규칙 |
|---|---|
| `schemaVersion` | `1`. decode가 모르는 버전이면 `FormatException`(향후 포맷 변경 대비) |
| per-row 필드 | 각 행 = drift 생성 `toJson()` 출력 그대로(enum=int 인덱스, `cupNotes`=배열, nullable=`null`, 날짜=drift 기본 포맷). 수기 매핑 없음 → 대칭성으로 왕복 보장 |
| `exportedAt` | 최상위 한 곳만 명시적 ISO-8601 UTC |
| `photoBase64` | bean별로 `toJson` 출력에 추가. 사진 파일 bytes의 base64, 사진 없음/파일 소실이면 `null` |

**핵심 불변식:** `encodeBackup(decodeBackup(encodeBackup(x))) == encodeBackup(x)` (JSON 문자열 동일) — 모든 행·사진 바이트가 왕복에서 보존된다. drift 행의 `==`는 `cupNotes` 리스트를 **참조 비교**하므로 행 `==`가 아니라 **JSON 문자열 멱등성**으로 검증한다. 이 라운드트립이 코덱 유닛 테스트의 중심이다.

## 6. 화면 & 컴포넌트

### 6.1 설정 화면 (`settings_screen.dart`)

```
AppBar '설정'
ListView
  섹션 '데이터'
    ListTile  데이터 내보내기   부제: 사진 포함 JSON 백업 · 공유 시트
    ListTile  데이터 가져오기   부제: 백업에서 복원 · 현재 데이터를 대체
  섹션 '정보'
    ListTile  버전            trailing: v0.5.0 (모노)
    안내 한 줄  모든 데이터는 이 기기에만 저장됩니다 · 오프라인 전용
```

- **내보내기** 탭 → 진행 표시 → `share_plus` 공유 시트. 실패 시 SnackBar.
- **가져오기** 탭 → `listImportable()` → **파일 목록 바텀시트**(파일명 + 저장 시각). 항목 탭 → **확인 다이얼로그**(체리색 강조 "현재 데이터가 모두 대체됩니다" + "먼저 내보내기를 권장") → 복원 → 완료 SnackBar → 프로바이더 invalidate.
- 파일이 없으면 목록 대신 안내: "가져올 백업 파일이 없어요 — Files 앱의 이 폴더에 `.json`을 넣어 주세요."
- **앱 버전**은 신규 플러그인(`package_info_plus`)을 피하려고 코드 상수 `kAppVersion`으로 표기하고 릴리스 태그와 함께 올린다. (현재 `pubspec` `version:`은 `flutter create` 기본값 `1.0.0`이라 오히려 실제 태그와 어긋나므로, 상수가 더 정직하다.)

### 6.2 원두 검색/정렬 (`bean_list_screen.dart`)

```
AppBar '내 원두'                         trailing: 정렬 PopupMenu(최근/평점/이름)
  검색 필드   돋보기 · '이름 · 로스터리 검색' · 지우기(x)
  리스트      필터 + 정렬 적용
```

- **검색:** `name`·`roaster` 부분일치(소문자 비교).
- **정렬:** **최근**(`createdAt` desc, 기본) / **평점**(평균★ desc, 시음 없는 원두는 뒤) / **이름**(가나다 `compareTo`).
- **구현:** 필터·정렬은 이미 스트림에 있는 `List<BeanSummary>`에 적용하는 **순수 함수** `sortFilterBeans(list, query, sort)`로 분리(개인 규모라 DB 재쿼리 불필요, 유닛 테스트 가능). 정렬 상태 = 작은 `StateProvider<BeanSort>`, 검색어 = 로컬 위젯 상태.

### 6.3 빈 상태

| 조건 | 표시 |
|---|---|
| 원두 0개 (기존) | 기존 안내 유지 — "아직 기록한 원두가 없어요 …" |
| 검색 결과 0 (신규) | "'{검색어}'에 맞는 원두가 없어요" — 원본이 비지 않았을 때만 |

대시보드 2층 빈 상태는 M4에서 완료 — 손대지 않는다. ~~앱 아이콘~~은 M3.3에서 교체 완료 — **M5 제외**.

## 7. 오류 처리 & 원자성

- **decode 실패**(잘못된 JSON·미지 `schemaVersion`) → `FormatException` → UI SnackBar "백업 파일을 읽을 수 없어요". DB는 손대지 않는다.
- **가져오기 순서 = 디코드 → 사진 쓰기 → DB 교체.** `replaceAll()`은 **단일 트랜잭션**(FK 순서로 delete → insert, 전부 성공 또는 전부 롤백)이라 부분 적용이 없다. 트랜잭션이 실패해도 먼저 쓴 사진 파일은 고아로 남을 뿐 무해(다음 성공 import가 덮음).
- **내보내기 중 사진 파일 소실** → 그 bean만 `photoBase64: null`로 계속 진행(전체 실패 아님).
- **프로바이더 레벨:** 설정 화면의 비동기 동작은 로딩/에러를 SnackBar로 노출. 리스트 검색/정렬은 동기라 예외 경로 없음.

## 8. 테스트 ([`../testing.md`](../testing.md) 3계층)

| 계층 | 파일 | 내용 |
|---|---|---|
| 유닛 (DB 없음) | `test/unit/backup_codec_test.dart` | **encode→decode 라운드트립 동일성** · **사진 base64 bytes 왕복** · `schemaVersion` 미지 → `FormatException` · 잘못된 JSON 거부 · 빈 스냅샷 · 날짜·enum·nullable 보존 |
| 유닛 (DB 없음) | `test/unit/bean_sort_filter_test.dart` | `sortFilterBeans` — 검색 부분일치·대소문자 무시 · 최근/평점/이름 3정렬 · 동점 순서 · 평점 없는 원두 뒤로 |
| 유닛 (인메모리 DB) | `test/unit/backup_repo_test.dart` | `replaceAll()`이 기존을 전부 지우고 백업으로 교체(FK 순서·id 보존) · `getTasteSnapshot()` 왕복 |
| 위젯 | `test/widget/settings_screen_test.dart` | 내보내기 탭 → Fake 서비스 호출 · 가져오기 → 목록 → **확인 다이얼로그** → import 호출 · 파일 없음 안내 |
| 위젯 | `test/widget/bean_list_search_test.dart` | 검색 입력 → 필터 · 정렬 전환 · **검색 결과 없음** 안내 |
| 통합 (선택) | `integration_test/backup_roundtrip_test.dart` | export→import 실제 왕복(인메모리 DB + 임시 디렉터리 + Fake 공유) |

`test/helpers.dart`의 기존 팩토리(`beanRow`/`compRow`/`tastingRow`/`sampleSingle`/`sampleBlend`)를 재사용하고, `FakeBackupService`를 `FakeOcrService`/`FakePhotoService` 옆에 추가한다.

## 9. 실행 규약

M2~M4와 동일: **SDD**(태스크별 구현 서브에이전트 + 태스크 리뷰, 마지막에 opus 전체-브랜치 리뷰) · TDD(실패 테스트 → 최소 구현 → 통과 → 커밋) · 태스크 단위 main 직커밋 · 커밋 전 `flutter analyze && flutter test` 초록불.

## 10. 파일 영향

| 파일 | 변경 |
|---|---|
| `pubspec.yaml` | `share_plus` 추가 (신규 네이티브 플러그인 — iOS 포드는 CI가 해결) |
| `ios/Runner/Info.plist` | `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` = YES |
| `lib/features/settings/backup_codec.dart` | **신규** — `encodeBackup` · `decodeBackup` · `DecodedBackup` (순수, 피처-로컬) |
| `lib/services/backup_service.dart` | **신규** — `BackupService` 인터페이스 + 구현(`share_plus`/`path_provider`), 기존 `ocr_service`·`photo_service` 옆 |
| `lib/data/bean_repository.dart` | `replaceAll(TasteSnapshot)` 추가 |
| `lib/providers.dart` | `backupServiceProvider` · `beanSortProvider` 추가 |
| `lib/features/settings/settings_screen.dart` | 플레이스홀더 → 내보내기·가져오기·앱 정보 |
| `lib/features/beans/bean_list_screen.dart` | 검색 필드 + 정렬 메뉴 + 검색 빈 상태 |
| `lib/features/beans/bean_sort.dart` | **신규** — `BeanSort` enum + `sortFilterBeans()` 순수 함수 |
| `test/helpers.dart` | `FakeBackupService` 추가 |
| `test/unit/backup_codec_test.dart` · `bean_sort_filter_test.dart` · `backup_repo_test.dart` | **신규** |
| `test/widget/settings_screen_test.dart` · `bean_list_search_test.dart` | **신규** |

DB 스키마·마이그레이션 변경 없음. 신규 패키지 의존성은 `share_plus` 하나.
