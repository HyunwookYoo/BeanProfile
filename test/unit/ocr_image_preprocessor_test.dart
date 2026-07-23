import 'dart:io';
import 'package:beanprofile/services/ocr_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'enhance writes one grayscale PNG, preserves source, and deletes twice',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'beanprofile-enhance-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/source.jpg');
      final input = img.Image(width: 64, height: 32);
      img.fill(input, color: img.ColorRgb8(80, 100, 120));
      final sourceBytes = img.encodeJpg(input);
      await source.writeAsBytes(sourceBytes);
      final service = DartOcrImagePreprocessor(
        temporaryDirectory: () async => root,
      );

      final enhancedPath = await service.enhance(source.path);
      final enhanced = await img.decodeImageFile(enhancedPath);
      final enhancedOutputs = await root
          .list()
          .where(
            (entity) =>
                entity is File && entity.path.toLowerCase().endsWith('.png'),
          )
          .toList();

      expect(enhancedPath, endsWith('.png'));
      expect(enhancedOutputs, hasLength(1));
      expect(
        await File(enhancedOutputs.single.path).resolveSymbolicLinks(),
        await File(enhancedPath).resolveSymbolicLinks(),
      );
      expect(enhanced, isNotNull);
      final pixel = enhanced!.getPixel(0, 0);
      expect(pixel.r, pixel.g);
      expect(pixel.g, pixel.b);
      expect(await source.exists(), isTrue);
      expect(await source.readAsBytes(), orderedEquals(sourceBytes));

      await service.delete(enhancedPath);
      await service.delete(enhancedPath);
      expect(await File(enhancedPath).exists(), isFalse);
    },
  );

  test(
    'enhance bakes orientation and materially expands grayscale range',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'beanprofile-enhance-oriented-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/oriented.jpg');
      final input = img.Image(width: 32, height: 16);
      for (var y = 0; y < input.height; y++) {
        for (var x = 0; x < input.width; x++) {
          final value = x < input.width ~/ 2 ? 90 : 120;
          input.setPixelRgb(x, y, value, value, value);
        }
      }
      input.exif.imageIfd.orientation = 6;
      await source.writeAsBytes(img.encodeJpg(input, quality: 100));
      final service = DartOcrImagePreprocessor(
        temporaryDirectory: () async => root,
      );

      final enhancedPath = await service.enhance(source.path);
      final enhanced = await img.decodeImageFile(enhancedPath);

      expect(enhanced, isNotNull);
      expect(enhanced!.width, 16);
      expect(enhanced.height, 32);
      var minimum = 255;
      var maximum = 0;
      for (final pixel in enhanced) {
        expect(pixel.r, pixel.g);
        expect(pixel.g, pixel.b);
        final luminance = pixel.r.toInt();
        if (luminance < minimum) minimum = luminance;
        if (luminance > maximum) maximum = luminance;
      }
      expect(maximum - minimum, greaterThan(200));
    },
  );

  test('enhance uses the calibrated stretch and contrast pipeline', () async {
    final root = await Directory.systemTemp.createTemp(
      'beanprofile-enhance-calibrated-',
    );
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/multi-level-color.png');
    final input = img.Image(width: 100, height: 100);
    var index = 0;
    for (final (red, green, blue, count) in [
      (10, 20, 30, 100),
      (50, 60, 70, 75),
      (90, 100, 110, 3000),
      (120, 130, 140, 3650),
      (150, 160, 170, 3000),
      (190, 200, 210, 75),
      (230, 240, 250, 100),
    ]) {
      for (var i = 0; i < count; i++) {
        input.setPixelRgb(index % 100, index ~/ 100, red, green, blue);
        index++;
      }
    }
    expect(index, input.width * input.height);
    await source.writeAsBytes(img.encodePng(input));
    final service = DartOcrImagePreprocessor(
      temporaryDirectory: () async => root,
    );

    final enhancedPath = await service.enhance(source.path);
    final enhanced = await img.decodeImageFile(enhancedPath);

    expect(enhanced, isNotNull);
    expect(
      [
        enhanced!.getPixel(75, 1).r.toInt(),
        enhanced.getPixel(75, 31).r.toInt(),
        enhanced.getPixel(25, 68).r.toInt(),
      ],
      [62, 128, 192],
    );
  });
}
