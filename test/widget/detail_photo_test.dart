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
    expect(find.byType(InteractiveViewer), findsOneWidget); // 전체화면 뷰어가 실제로 열렸는지 판별
    await t.pump(const Duration(milliseconds: 200)); // autoDispose-pop 데드락 회피

    // 상세가 live drift 스트림을 watch → teardown 전 명시 close(Global Constraints).
    await db.close();
  });
}
