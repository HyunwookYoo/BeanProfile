import 'package:beanprofile/features/beans/bean_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('deleting a bean from detail removes it', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    final id = await repo.createBean(sampleSingle());

    await tester.pumpWidget(wrapApp(BeanDetailScreen(beanId: id), db: db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-bean')), findsOneWidget);
    expect(find.byKey(const Key('delete-bean')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-bean')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제')); // 확인
    await tester.pumpAndSettle();

    expect(await repo.getBeanDetail(id), isNull);

    // 삭제 후 detail screen이 pop되면 beanDetailProvider(autoDispose)가 정리되며
    // drift가 스트림 구독 취소 시 디바운스 타이머를 예약한다(helpers/Global
    // Constraints의 "teardown 전 명시 close" 메모와 같은 근본 원인). 그 정리가
    // 완전히 끝나기 전에 바로 db.close()를 호출하면 아직 끝나지 않은 스트림
    // 정리와 경합해 close()가 결코 완료되지 않고 멈춘다(실측: pumpAndSettle
    // 직후 바로 close()하면 수 분간 응답 없음). 짧은 pump로 그 정리가
    // 실제로 끝나도록 한 뒤에 닫는다.
    await tester.pump(const Duration(milliseconds: 200));

    // 상세가 live drift 스트림을 watch → teardown 전 명시 close(Global Constraints).
    await db.close();
  });
}
