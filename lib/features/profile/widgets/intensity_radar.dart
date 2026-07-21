import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../taste_profile.dart';

const _axisLabels = ['산미', '단맛', '바디', '쓴맛'];
const _maxValue = 5.0;

/// 레이더 축 위의 점. 축 0=산미(위) 1=단맛(오른쪽) 2=바디(아래) 3=쓴맛(왼쪽).
/// 화면 좌표계(y가 아래로 증가)라 위쪽이 `-pi/2`다.
Offset radarPoint(int axis, double value,
        {required Offset center, required double radius}) =>
    center +
    Offset.fromDirection(
        -math.pi / 2 + axis * math.pi / 2, radius * value / _maxValue);

/// 강도 4축 레이더. 크기는 목업과 동일하게 180×164 고정.
class IntensityRadar extends StatelessWidget {
  const IntensityRadar({super.key, required this.intensity});

  final Intensity intensity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SizedBox(
        width: 180,
        height: 164,
        child: CustomPaint(
          painter: _RadarPainter(
            values: [
              intensity.acidity,
              intensity.sweetness,
              intensity.body,
              intensity.bitterness,
            ],
            grid: c.appLine,
            accent: c.crema,
            labelColor: c.appMuted,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.grid,
    required this.accent,
    required this.labelColor,
  });

  final List<double> values;
  final Color grid, accent, labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 축 라벨이 들어갈 여백을 위·아래로 남긴다(목업의 164 높이 기준).
    const center = Offset(90, 80);
    const radius = 58.0;

    Path ring(double value) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final p = radarPoint(i, value, center: center, radius: radius);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (var step = 1; step <= 5; step++) {
      canvas.drawPath(ring(step.toDouble()), gridPaint);
    }
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
          center, radarPoint(i, _maxValue, center: center, radius: radius),
          gridPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < 4; i++) {
      final p = radarPoint(i, values[i], center: center, radius: radius);
      i == 0 ? valuePath.moveTo(p.dx, p.dy) : valuePath.lineTo(p.dx, p.dy);
    }
    valuePath.close();
    canvas.drawPath(valuePath, Paint()..color = accent.withValues(alpha: 0.28));
    canvas.drawPath(
        valuePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent);

    final dot = Paint()..color = accent;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
          radarPoint(i, values[i], center: center, radius: radius), 3.2, dot);
    }

    // 축 라벨 — 위/아래는 가운데 정렬, 좌/우는 바깥쪽 정렬.
    const labelAnchors = [
      Offset(90, 4), // 산미 (위)
      Offset(153, 74), // 단맛 (오른쪽)
      Offset(90, 146), // 바디 (아래)
      Offset(27, 74), // 쓴맛 (왼쪽)
    ];
    for (var i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: _axisLabels[i],
            style: monoStyle(
                size: 10.5, weight: FontWeight.w700, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = labelAnchors[i];
      final dx = switch (i) {
        1 => anchor.dx, // 오른쪽: 왼쪽 정렬
        3 => anchor.dx - tp.width, // 왼쪽: 오른쪽 정렬
        _ => anchor.dx - tp.width / 2, // 위·아래: 가운데
      };
      tp.paint(canvas, Offset(dx, anchor.dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      !listEquals(old.values, values) || old.accent != accent;
}
