import 'dart:io';
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// 원두 사진 썸네일. photoPath 없으면 문서 아이콘 플레이스홀더.
class BeanThumbnail extends StatelessWidget {
  const BeanThumbnail({super.key, required this.photoPath, this.width = 48, this.height = 60});
  final String? photoPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(10);
    Widget placeholder(IconData icon) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.oat, borderRadius: radius, border: Border.all(color: c.appLine)),
          child: Icon(icon, color: c.appMuted, size: width * 0.42),
        );
    if (photoPath == null) return placeholder(Icons.description_outlined);
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(photoPath!),
        width: width, height: height, fit: BoxFit.cover,
        cacheWidth: (width * 3).round(), // 썸네일 크기로 디코드(전체 해상도 디코드 방지)
        errorBuilder: (_, __, ___) => placeholder(Icons.broken_image_outlined),
      ),
    );
  }
}
