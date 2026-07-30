// App Store 제출용 스크린샷을 iOS 시뮬레이터에서 촬영한다.
//
// 실행(맥/CI 전용 — 개발 머신이 Windows라 로컬 실행 불가):
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <ios-simulator-udid>
//
// 위젯 테스트와 달리 여기서는 앱이 자기 실제 DB를 연다. 빈 앱은 스토어
// 스크린샷으로 쓸 수 없으므로 app.main() 전에 보여줄 데이터를 직접 넣는다.
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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

    // ③ 원두 상세 — 시딩에서 마지막에 만든 원두가 목록 맨 위라 스크롤이 필요 없다.
    await tester.tap(find.byIcon(Icons.coffee_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('bean-$heroBeanId')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_detail');

    // ④ 시음 입력 — 빈 폼은 밋밋하니 강도 한 축과 별점만 눌러둔다.
    //    텍스트 입력은 키보드가 화면을 가리므로 하지 않는다.
    await tester.tap(find.byKey(const Key('add-tasting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intensity-산미-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04_tasting');
  });
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

  // 목록은 createdAt 내림차순이라 나중에 만든 원두가 위로 온다.
  // 상세 화면에 쓸 원두를 맨 마지막에 만들어 목록 최상단에 놓는다.

  final kenya = await repo.createBean(BeanInput(
    name: '케냐 니에리 AA',
    roaster: '모모스커피',
    type: BeanType.singleOrigin,
    roastLevel: RoastLevel.light,
    roastDate: daysAgo(30),
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
    roastDate: daysAgo(20),
    cupNotes: const ['카라멜', '오렌지', '아몬드'],
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

  final blend = await repo.createBean(BeanInput(
    name: '하우스 블렌드',
    roaster: '테라로사',
    type: BeanType.blend,
    roastLevel: RoastLevel.mediumDark,
    roastDate: daysAgo(5),
    cupNotes: const ['다크초콜릿', '헤이즐넛'],
    memo: '우유랑 섞었을 때 제일 좋다.',
    components: const [
      ComponentInput(
          country: 'Brazil', process: Process.natural, ratioPercent: 60),
      ComponentInput(
          country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
    ],
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
  ));

  await repo.createTasting(
      yirgacheffe,
      TastingInput(
          date: daysAgo(5),
          acidity: 5,
          sweetness: 4,
          body: 2,
          bitterness: 1,
          overall: 5,
          comment: '식으니까 블루베리가 확 올라온다. 지금까지 중 최고.'));
  await repo.createTasting(
      yirgacheffe,
      TastingInput(
          date: daysAgo(2),
          acidity: 4,
          sweetness: 4,
          body: 3,
          bitterness: 2,
          overall: 4,
          comment: '조금 진하게 내렸더니 단맛이 더 붙었다.'));
  await repo.createTasting(
      blend,
      TastingInput(
          date: daysAgo(1),
          acidity: 2,
          sweetness: 3,
          body: 5,
          bitterness: 4,
          overall: 4,
          comment: '라떼로 마시기 딱 좋은 바디.'));
  await repo.createTasting(
      colombia,
      TastingInput(
          date: daysAgo(8),
          acidity: 3,
          sweetness: 5,
          body: 4,
          bitterness: 2,
          overall: 5,
          comment: '카라멜 단맛이 길게 남는다.'));
  await repo.createTasting(
      colombia,
      TastingInput(
          date: daysAgo(3),
          acidity: 3,
          sweetness: 4,
          body: 4,
          bitterness: 2,
          overall: 4));
  await repo.createTasting(
      kenya,
      TastingInput(
          date: daysAgo(15),
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
