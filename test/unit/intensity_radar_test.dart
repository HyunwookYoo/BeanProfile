import 'package:beanprofile/features/profile/widgets/intensity_radar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const center = Offset(90, 80);
  const radius = 58.0;

  test('축 0(산미)은 위쪽 — y가 작아진다', () {
    final p = radarPoint(0, 5, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(22, 1e-6));
  });

  test('축 1(단맛)은 오른쪽', () {
    final p = radarPoint(1, 5, center: center, radius: radius);
    expect(p.dx, closeTo(148, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('축 2(바디)는 아래쪽', () {
    final p = radarPoint(2, 5, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(138, 1e-6));
  });

  test('축 3(쓴맛)은 왼쪽', () {
    final p = radarPoint(3, 5, center: center, radius: radius);
    expect(p.dx, closeTo(32, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('값 0이면 중심', () {
    final p = radarPoint(1, 0, center: center, radius: radius);
    expect(p.dx, closeTo(90, 1e-6));
    expect(p.dy, closeTo(80, 1e-6));
  });

  test('값은 반지름에 선형 비례한다', () {
    final p = radarPoint(0, 2.5, center: center, radius: radius);
    expect(p.dy, closeTo(80 - 29, 1e-6)); // 절반
  });
}
