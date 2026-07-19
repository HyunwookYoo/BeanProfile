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
