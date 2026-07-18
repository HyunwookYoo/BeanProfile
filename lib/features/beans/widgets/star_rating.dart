import 'package:flutter/material.dart';
import '../../../theme.dart';

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 15});
  final double? value; // null = 평가 없음
  final double size;

  @override
  Widget build(BuildContext context) {
    final crema = context.colors.crema;
    if (value == null) {
      return Text('평가 없음',
          style: TextStyle(fontSize: size * 0.8, color: context.colors.appMuted));
    }
    final v = value!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          v >= i ? Icons.star : (v >= i - 0.5 ? Icons.star_half : Icons.star_border),
          size: size, color: crema,
        ),
      const SizedBox(width: 4),
      Text(v.toStringAsFixed(1), style: monoStyle(size: size * 0.8, color: context.colors.espresso)),
    ]);
  }
}
