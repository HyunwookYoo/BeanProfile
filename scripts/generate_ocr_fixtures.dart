import 'dart:io';

import 'package:image/image.dart' as img;

img.Image _card({required img.Color background, required img.Color ink}) {
  final image = img.Image(width: 1080, height: 1440);
  img.fill(image, color: background);
  const lines = [
    'HOUSE BLEND',
    'ORIGIN 1  BRAZIL 60%',
    'REGION  CERRADO',
    'PROCESS  NATURAL',
    'ORIGIN 2  ETHIOPIA 40%',
    'REGION  GUJI',
    'PROCESS  WASHED',
    'ROAST  MEDIUM',
    'NOTES  COCOA, BERRY',
  ];
  for (var i = 0; i < lines.length; i++) {
    img.drawString(
      image,
      lines[i],
      font: i == 0 ? img.arial48 : img.arial24,
      x: 80,
      y: 90 + i * 130,
      color: ink,
    );
  }
  return image;
}

void main() {
  final dir = Directory('assets/test')..createSync(recursive: true);
  final bright = _card(
    background: img.ColorRgb8(245, 242, 232),
    ink: img.ColorRgb8(25, 20, 15),
  );
  final dark = _card(
    background: img.ColorRgb8(38, 38, 42),
    ink: img.ColorRgb8(58, 58, 62),
  );
  final bad = img.gaussianBlur(dark.clone(), radius: 8);
  img.fillRect(
    bad,
    x1: 540,
    y1: 180,
    x2: 1000,
    y2: 900,
    color: img.ColorRgb8(255, 255, 255),
  );

  File('${dir.path}/ocr_blend_en.png').writeAsBytesSync(img.encodePng(bright));
  File(
    '${dir.path}/ocr_dark_blend_en.png',
  ).writeAsBytesSync(img.encodePng(dark));
  File(
    '${dir.path}/ocr_bad_quality_en.png',
  ).writeAsBytesSync(img.encodePng(bad));
}
