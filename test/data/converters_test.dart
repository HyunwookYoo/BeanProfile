import 'package:beanprofile/data/converters.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conv = StringListConverter();

  test('round-trips a list of strings', () {
    const notes = ['블루베리', '자스민', '홍차'];
    final sql = conv.toSql(notes);
    expect(conv.fromSql(sql), notes);
  });

  test('empty list round-trips', () {
    expect(conv.fromSql(conv.toSql(const [])), isEmpty);
  });

  test('enum labels are Korean', () {
    expect(BeanType.blend.label, '블렌드');
    expect(Process.natural.label, '내추럴');
    expect(RoastLevel.mediumDark.label, '미디엄다크');
  });
}
