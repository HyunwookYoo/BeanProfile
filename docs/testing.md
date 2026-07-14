# BeanProfile 테스트 규약

목표: **기능을 추가할 때 `flutter test` 한 번으로 기존 기능이 깨졌는지 즉시 확인**한다.
모든 마일스톤(M1~M5)이 이 규약을 따른다. 관련: 로드맵 [`plans/roadmap.md`](plans/roadmap.md) · M1 [`plans/milestone-1-foundation.md`](plans/milestone-1-foundation.md)

---

## 1. 3계층 전략

| 계층 | 대상 | 방식 | 속도 |
|---|---|---|---|
| **유닛/데이터** | 컨버터·DB·저장소·분석 쿼리 | **인메모리 drift DB** (`NativeDatabase.memory()`) | 매우 빠름 |
| **위젯/UI** | 화면·위젯 | `flutter_test` + **Riverpod provider override** | 빠름 |
| **스모크** | 앱 부팅 | 최소 pump | 즉시 |

원칙: **TDD**(실패 테스트 → 최소 구현 → 통과 → 커밋) · 기기/네트워크 없이 호스트에서 실행 · 커밋 전 `flutter analyze && flutter test` 초록불.

---

## 2. 공유 헬퍼 — `test/helpers.dart`

각 테스트가 인메모리 DB·샘플 데이터를 반복하지 않도록 공통 헬퍼로 모은다. **M2부터는 기본 사용**하고, M1의 반복 셋업도 이걸로 대체할 수 있다.

```dart
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 인메모리 테스트 DB (FK on). 반드시 addTearDown(db.close).
AppDatabase testDatabase() => AppDatabase.forTesting(NativeDatabase.memory());

/// DB를 주입한 저장소.
BeanRepository testRepository(AppDatabase db) => BeanRepository(db);

/// DB를 override한 ProviderContainer. addTearDown(container.dispose).
ProviderContainer testContainer(AppDatabase db) =>
    ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

/// 위젯 테스트용: 테마 + (선택) DB override로 화면을 감싼다.
Widget wrapApp(Widget child, {AppDatabase? db}) => ProviderScope(
      overrides: [if (db != null) databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

/// 샘플 싱글 오리진.
BeanInput sampleSingle({String name = '예가체프 코체레', String country = 'Ethiopia'}) =>
    BeanInput(
      name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null,
      cupNotes: const ['블루베리', '자스민'], memo: null,
      components: [ComponentInput(country: country, process: Process.washed)],
    );

/// 샘플 블렌드 (구성 2개 + 비율).
BeanInput sampleBlend({String name = '하우스 블렌드'}) => BeanInput(
      name: name, roaster: '테라로사', type: BeanType.blend,
      roastLevel: RoastLevel.medium, roastDate: null,
      cupNotes: const ['다크초콜릿'], memo: null,
      components: const [
        ComponentInput(country: 'Brazil', process: Process.natural, ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
      ],
    );
```

### 사용 예 (반복 → 헬퍼)

```dart
// 유닛 테스트
final db = testDatabase();
addTearDown(db.close);
final repo = testRepository(db);
final id = await repo.createBean(sampleSingle());
expect((await repo.getBeanDetail(id))!.bean.name, '예가체프 코체레');

// 위젯 테스트
await tester.pumpWidget(wrapApp(const BeanListScreen(), db: testDatabase()));
await tester.pumpAndSettle();
expect(find.byType(BeanCard), findsWidgets);
```

> `sampleXxx()` 팩토리는 새 기능이 생길 때마다 여기 추가한다(예: `sampleTasting()`). 그러면 M2~M5 테스트를 빠르게 작성·유지할 수 있다.

---

## 3. Windows에서 `flutter test` 초록불 (sqlite3)

`flutter test`는 기기가 아니라 **호스트(Dart VM)** 에서 돈다 → `NativeDatabase.memory()`가 **sqlite3 네이티브 라이브러리**를 필요로 한다.

- **Linux / macOS:** 대개 시스템에 이미 있음 → 별도 작업 불필요. (CI를 Linux에서 돌리는 이유)
- **Windows:** 기본 미포함. 아래 중 하나로 해결.
  1. https://sqlite.org/download.html → *Precompiled Binaries for Windows* 의 `sqlite-dll-win-x64-*.zip` 다운로드 → `sqlite3.dll` 추출.
  2. `sqlite3.dll`을 **프로젝트 루트**(=`flutter test` 실행 위치)에 두거나 시스템 **PATH**에 추가.
  3. 확인: `flutter test` 재실행 → drift 관련 테스트 통과.
- **기기/에뮬레이터 실행**(`flutter run`, integration_test)에는 `sqlite3_flutter_libs`가 네이티브를 제공하므로 DLL 불필요. (drift_flutter 사용 시 앱 런타임은 이미 처리됨.)
- **가장 깔끔한 회피:** CI를 **Linux**에서 돌리면 이 문제 자체가 없다(§4). 로컬 Windows에서 위 셋업이 번거로우면, 로컬은 위젯/유닛 일부만 돌리고 전체 회귀는 CI에 맡겨도 된다.

---

## 4. CI — GitHub Actions (`.github/workflows/test.yml`)

push / PR마다 **Linux 러너**에서 `analyze` + `test`를 자동 실행한다(리눅스라 sqlite3 문제 없음). 개인·오프라인 앱이지만 GitHub에 올려 두면 회귀 안전망이 된다.

```yaml
name: test
on:
  push:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest   # Linux엔 sqlite3 기본 존재 → 인메모리 테스트 OK
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
```

> GitHub 원격을 안 쓰면 이 파일은 그대로 잠자며 아무 영향 없다. 원격에 push하는 순간부터 동작한다.

---

## 5. 실행 명령

```bash
flutter test                                   # 전체
flutter test test/data/bean_repository_test.dart   # 특정 파일
flutter test --name '외 N'                      # 이름으로 필터
flutter analyze                                # 정적 분석
flutter test --coverage                        # (선택) coverage/lcov.info 생성
```

---

## 6. 새 기능 추가 시 체크리스트

- [ ] 데이터 로직이면 **유닛 테스트**(인메모리 DB + `testDatabase()`), 화면이면 **위젯 테스트**(`wrapApp`).
- [ ] 필요한 샘플은 `test/helpers.dart`에 `sampleXxx()`로 추가(재사용).
- [ ] 실패 → 구현 → 통과 순서(TDD).
- [ ] 커밋 전 `flutter analyze && flutter test` 초록불 확인.
