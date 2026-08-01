// App Store 제출용 스크린샷을 iOS 시뮬레이터에서 촬영한다.
//
// 실행(맥/CI 전용 — 개발 머신이 Windows라 로컬 실행 불가):
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <ios-simulator-udid>
//
// 위젯 테스트와 달리 여기서는 앱이 자기 실제 DB를 연다. 빈 앱은 스토어
// 스크린샷으로 쓸 수 없으므로 app.main() 전에 보여줄 데이터를 직접 넣는다.
//
// 시딩 데이터는 "그럴듯한 값"이 아니라 **화면이 잘 나오는 값**으로 고른다.
// 1차 촬영에서 드러난 것:
//  - 컵노트를 원두마다 겹치지 않게 넣었더니 선호 컵노트 막대가 전부 1이라
//    차트가 고장 난 것처럼 보였다 → 아래에서 의도적으로 겹치게 배치한다.
//  - 사진이 없어 목록 카드가 전부 회색 플레이스홀더였다 → 번들된 OCR 테스트
//    카드를 사진으로 넣는다(이 앱의 실제 용례가 '봉투·카드 촬영'이라 잘 맞는다).
import 'dart:io';

import 'package:drift/drift.dart' as drift;

import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Store 스크린샷', (tester) async {
    final heroBeanId = await _seed();

    app.main();
    await tester.pumpAndSettle();

    // ① 원두 목록
    await binding.takeScreenshot('01_beans');

    // ② 취향 대시보드 — 탭 전환만 쓴다. 뒤로가기를 쓰지 않으면 화면 스택
    //    상태에 의존하지 않아 순서가 바뀌어도 깨지지 않는다.
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02_taste');

    // ③ 원두 상세 — 시딩이 createdAt을 명시해 주인공 원두가 목록 맨 위에 오지만,
    //    레이아웃에 기대지 않도록 탭 전에 화면 안으로 끌어온다. 2차 촬영에서
    //    이 원두가 화면 밖(y=900)에 있어 탭이 내비게이션 바를 때렸다.
    await tester.tap(find.byIcon(Icons.coffee_outlined));
    await tester.pumpAndSettle();
    final hero = find.byKey(ValueKey('bean-$heroBeanId'));
    await tester.ensureVisible(hero);
    await tester.pumpAndSettle();
    await tester.tap(hero);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_detail');

    // ④ 시음 입력 — 강도 4축·별점·코멘트를 모두 채운다. 빈 폼은 하단이 통째로
    //    비어 스토어 스크린샷으로 설득력이 없었다.
    await tester.tap(find.byKey(const Key('add-tasting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.tap(find.byKey(const Key('intensity-단맛-4')));
    await tester.tap(find.byKey(const Key('intensity-바디-3')));
    await tester.tap(find.byKey(const Key('intensity-쓴맛-2')));
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.enterText(
        find.byKey(const Key('tasting-comment')), '자몽 같은 산미에 꽃향이 길게 남는다.');
    // 입력 후 포커스를 놓아 커서·키보드가 화면을 가리지 않게 한다.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04_tasting');
  });
}

/// 번들 에셋을 앱 문서 디렉터리의 photos/로 복사하고 절대 경로를 돌려준다.
/// 앱의 PhotoService.persist가 쓰는 위치와 같게 맞춘다(BeanThumbnail은
/// Image.file로 이 경로를 그대로 읽는다).
Future<String> _seedPhoto(String assetPath, String fileName) async {
  final bytes = await rootBundle.load(assetPath);
  final dir = await getApplicationDocumentsDirectory();
  final photos = Directory('${dir.path}/photos');
  if (!await photos.exists()) await photos.create(recursive: true);
  final file = File('${photos.path}/$fileName');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return file.path;
}

/// 스크린샷용 데이터를 실제 DB에 넣고, 상세 화면에 쓸 원두 id를 돌려준다.
Future<int> _seed() async {
  final db = AppDatabase();
  final repo = BeanRepository(db);

  // 시뮬레이터가 재사용돼도 결과가 같도록 먼저 비운다.
  await repo.replaceAll(
      const TasteSnapshot(beans: [], components: [], tastings: []));

  final today = DateTime.now();
  DateTime daysAgo(int d) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: d));

  // 사진은 목록 상단 4개에 간다(아래 stamp가 순서를 확정한다).
  final photoCard = await _seedPhoto('assets/test/ocr_card_ko.png', 'a.png');
  final photoOrig = await _seedPhoto('assets/test/ocr_card_orig.png', 'b.png');
  final photoBlend = await _seedPhoto('assets/test/ocr_blend_en.png', 'c.png');
  final photoDark =
      await _seedPhoto('assets/test/ocr_dark_blend_en.png', 'd.png');

  // 컵노트는 의도적으로 겹치게 둔다. 선호 컵노트는 '원두 1표'로 세므로
  // 겹치지 않으면 모든 막대가 1이 되어 차트가 무의미해 보인다.
  // 목표 빈도: 카라멜 4 · 블루베리 3 · 다크초콜릿 3 · 자스민 2 · 나머지 1.

  final kenya = await repo.createBean(BeanInput(
    name: '케냐 니에리 AA',
    roaster: '모모스커피',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.light,
    roastDate: daysAgo(34),
    cupNotes: const ['자몽', '블랙커런트'],
    memo: null,
    components: const [
      ComponentInput(
          country: 'Kenya',
          region: 'Nyeri',
          process: Process.washed,
          altitude: '1750m'),
    ],
  ));

  final colombia = await repo.createBean(BeanInput(
    name: '콜롬비아 라 팔마',
    roaster: '커피리브레',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.medium,
    roastDate: daysAgo(26),
    cupNotes: const ['카라멜', '오렌지', '다크초콜릿'],
    memo: null,
    components: const [
      ComponentInput(
          country: 'Colombia',
          region: 'Huila',
          variety: 'Caturra',
          process: Process.honey,
          altitude: '1600m'),
    ],
  ));

  final guatemala = await repo.createBean(BeanInput(
    name: '과테말라 안티구아',
    roaster: '나무사이로',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.medium,
    roastDate: daysAgo(18),
    cupNotes: const ['블루베리', '다크초콜릿', '카라멜'],
    memo: null,
    components: const [
      ComponentInput(
          country: 'Guatemala',
          region: 'Antigua',
          variety: 'Bourbon',
          process: Process.washed,
          altitude: '1550m'),
    ],
    photoPath: photoOrig,
  ));

  final blend = await repo.createBean(BeanInput(
    name: '하우스 블렌드',
    roaster: '테라로사',
    type: BeanType.blend,
    roastLevel: RoastLevel.mediumDark,
    roastDate: daysAgo(6),
    cupNotes: const ['다크초콜릿', '헤이즐넛', '카라멜'],
    memo: '우유랑 섞었을 때 제일 좋다.',
    components: const [
      ComponentInput(
          country: 'Brazil', process: Process.natural, ratioPercent: 60),
      ComponentInput(
          country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
    ],
    photoPath: photoDark,
  ));

  final costarica = await repo.createBean(BeanInput(
    name: '코스타리카 따라주',
    roaster: '앤트러사이트',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.lightMedium,
    roastDate: daysAgo(9),
    cupNotes: const ['블루베리', '카라멜', '자스민'],
    memo: null,
    components: const [
      ComponentInput(
          country: 'Costa Rica',
          region: 'Tarrazú',
          process: Process.honey,
          altitude: '1700m'),
    ],
    photoPath: photoBlend,
  ));

  final yirgacheffe = await repo.createBean(BeanInput(
    name: '예가체프 코체레',
    roaster: '프릳츠커피',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.lightMedium,
    roastDate: daysAgo(12),
    cupNotes: const ['블루베리', '자스민', '홍차'],
    memo: '뜨거울 때보다 조금 식었을 때 산미가 또렷하다.',
    components: const [
      ComponentInput(
          country: 'Ethiopia',
          region: 'Yirgacheffe',
          farm: 'Kochere',
          variety: 'Heirloom',
          process: Process.washed,
          altitude: '1900m'),
    ],
    photoPath: photoCard,
  ));

  // 목록 정렬(createdAt 내림차순)을 확정한다.
  // createBean은 createdAt에 DateTime.now()를 넣는데, 6건이 같은 초에 들어가면
  // 정렬이 동률이 되고 SQLite가 삽입 순서로 돌려준다. 2차 촬영에서 주인공 원두가
  // 맨 아래(화면 밖)로 밀려 탭이 내비게이션 바를 때린 원인이 이것이다.
  // "나중에 만든 게 위로 온다"에 기대지 말고 값을 직접 박는다.
  final base = DateTime.now();
  Future<void> stamp(int beanId, int minutesAgo) =>
      (db.update(db.beans)..where((b) => b.id.equals(beanId))).write(
        BeansCompanion(
            createdAt: drift.Value(base.subtract(Duration(minutes: minutesAgo)))),
      );
  await stamp(yirgacheffe, 1); // 목록 최상단 = 상세 화면 주인공
  await stamp(costarica, 2);
  await stamp(blend, 3);
  await stamp(guatemala, 4); // 여기까지 사진 있음
  await stamp(colombia, 5);
  await stamp(kenya, 6);

  // 예가체프는 상세 화면 주인공이라 기록을 3건 둔다(1차 촬영에선 2건이라
  // 화면 아래쪽이 비어 보였다).
  await repo.createTasting(
      yirgacheffe,
      TastingInput(
          date: daysAgo(6),
          acidity: 5,
          sweetness: 4,
          body: 2,
          bitterness: 1,
          overall: 5,
          comment: '식으니까 블루베리가 확 올라온다. 지금까지 중 최고.'));
  await repo.createTasting(
      yirgacheffe,
      TastingInput(
          date: daysAgo(3),
          acidity: 4,
          sweetness: 4,
          body: 3,
          bitterness: 2,
          overall: 4,
          comment: '조금 진하게 내렸더니 단맛이 더 붙었다.'));
  await repo.createTasting(
      yirgacheffe,
      TastingInput(
          date: daysAgo(1),
          acidity: 4,
          sweetness: 5,
          body: 3,
          bitterness: 1,
          overall: 5,
          comment: '물온도를 92도로 낮추니 자스민 향이 또렷해졌다.'));

  await repo.createTasting(
      costarica,
      TastingInput(
          date: daysAgo(4),
          acidity: 4,
          sweetness: 5,
          body: 3,
          bitterness: 2,
          overall: 5,
          comment: '꿀 같은 단맛이 오래 남는다.'));
  await repo.createTasting(
      blend,
      TastingInput(
          date: daysAgo(2),
          acidity: 2,
          sweetness: 3,
          body: 5,
          bitterness: 4,
          overall: 4,
          comment: '라떼로 마시기 딱 좋은 바디.'));
  await repo.createTasting(
      guatemala,
      TastingInput(
          date: daysAgo(10),
          acidity: 3,
          sweetness: 4,
          body: 4,
          bitterness: 3,
          overall: 4,
          comment: '균형이 좋아서 매일 마시기 편하다.'));
  await repo.createTasting(
      colombia,
      TastingInput(
          date: daysAgo(14),
          acidity: 3,
          sweetness: 5,
          body: 4,
          bitterness: 2,
          overall: 5,
          comment: '카라멜 단맛이 길게 남는다.'));
  await repo.createTasting(
      colombia,
      TastingInput(
          date: daysAgo(8),
          acidity: 3,
          sweetness: 4,
          body: 4,
          bitterness: 2,
          overall: 4));
  await repo.createTasting(
      kenya,
      TastingInput(
          date: daysAgo(19),
          acidity: 5,
          sweetness: 3,
          body: 3,
          bitterness: 3,
          overall: 3,
          comment: '자몽 같은 산미가 강해서 호불호가 갈릴 듯.'));

  // 앱이 같은 파일을 다시 열기 전에 닫는다.
  await db.close();
  return yirgacheffe;
}
