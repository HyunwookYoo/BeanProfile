import 'dart:io';

import 'package:beanprofile/services/image_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  img.Image checker(int a, int b) {
    final image = img.Image(width: 128, height: 128);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = ((x ~/ 8 + y ~/ 8).isEven) ? a : b;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    return image;
  }

  img.Image luminanceDistribution(List<(int, int)> buckets) {
    final image = img.Image(width: 1024, height: 1);
    var x = 0;
    for (final (luminance, count) in buckets) {
      for (var i = 0; i < count; i++) {
        image.setPixelRgb(x++, 0, luminance, luminance, luminance);
      }
    }
    expect(x, image.width);
    return image;
  }

  img.Image verticalStripes(int difference) {
    final image = img.Image(width: 1024, height: 64);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final luminance = x.isEven ? 100 : 100 + difference;
        image.setPixelRgb(x, y, luminance, luminance, luminance);
      }
    }
    return image;
  }

  img.Image tiledHighlights(List<int> counts) {
    final image = img.Image(width: 1024, height: 25);
    img.fill(image, color: img.ColorRgb8(30, 30, 30));
    expect(counts.length, 16);
    for (var tile = 0; tile < counts.length; tile++) {
      for (var i = 0; i < counts[tile]; i++) {
        final x = tile * 64 + i % 64;
        final y = i ~/ 64;
        image.setPixelRgb(x, y, 250, 250, 250);
      }
    }
    return image;
  }

  img.Image partialEdgeHighlightImage() {
    final image = img.Image(width: 1024, height: 65);
    img.fill(image, color: img.ColorRgb8(30, 30, 30));

    var remaining = 3974;
    for (var y = 1; y < 64 && remaining > 0; y++) {
      for (var tile = 0; tile < 16 && remaining > 0; tile++) {
        for (var offset = 0; offset < 4 && remaining > 0; offset++) {
          image.setPixelRgb(tile * 64 + offset, y, 250, 250, 250);
          remaining--;
        }
      }
    }
    expect(remaining, 0);
    for (var x = 0; x < 20; x++) {
      image.setPixelRgb(x, 64, 250, 250, 250);
    }
    return image;
  }

  test('narrow luminance range is low contrast', () {
    final report = analyzeDecodedImage(checker(100, 130));
    expect(report.issues, contains(ImageQualityIssue.lowContrast));
  });

  test('narrow percentile range with high deviation is not low contrast', () {
    final report = analyzeDecodedImage(
      luminanceDistribution([(100, 973), (255, 51)]),
    );

    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
  });

  test('standard deviation equal to 30 is not low contrast', () {
    final report = analyzeDecodedImage(
      luminanceDistribution([(8, 32), (128, 960), (248, 32)]),
    );

    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
  });

  test('percentile range equal to 64 is not low contrast', () {
    final report = analyzeDecodedImage(
      luminanceDistribution([(100, 52), (132, 920), (164, 52)]),
    );

    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
  });

  test('51 of 1024 low outliers remain below the p05 rank', () {
    final report = analyzeDecodedImage(
      luminanceDistribution([(0, 51), (100, 973)]),
    );

    expect(report.issues, contains(ImageQualityIssue.lowContrast));
  });

  test('52 of 1024 low outliers reach the p05 rank', () {
    final report = analyzeDecodedImage(
      luminanceDistribution([(0, 52), (100, 972)]),
    );

    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
  });

  test('sharp black-white edges are not blurry or low contrast', () {
    final report = analyzeDecodedImage(checker(0, 255));
    expect(report.issues, isNot(contains(ImageQualityIssue.lowContrast)));
    expect(report.issues, isNot(contains(ImageQualityIssue.blurry)));
  });

  test('Laplacian variance below 100 is blurry', () {
    final report = analyzeDecodedImage(verticalStripes(4));

    expect(report.issues, contains(ImageQualityIssue.blurry));
  });

  test('Laplacian variance equal to 100 is not blurry', () {
    final report = analyzeDecodedImage(verticalStripes(5));

    expect(report.issues, isNot(contains(ImageQualityIssue.blurry)));
  });

  test('large clipped highlight cluster is reported', () {
    final image = img.Image(width: 128, height: 128);
    img.fill(image, color: img.ColorRgb8(30, 30, 30));
    img.fillRect(
      image,
      x1: 16,
      y1: 16,
      x2: 95,
      y2: 95,
      color: img.ColorRgb8(255, 255, 255),
    );
    final report = analyzeDecodedImage(image);
    expect(report.issues, contains(ImageQualityIssue.strongHighlights));
  });

  test('global highlight coverage equal to 6 percent is reported', () {
    final report = analyzeDecodedImage(
      tiledHighlights([1536, ...List.filled(15, 0)]),
    );

    expect(report.issues, contains(ImageQualityIssue.strongHighlights));
  });

  test(
    'global highlight coverage one pixel below 6 percent is not reported',
    () {
      final report = analyzeDecodedImage(
        tiledHighlights([1535, ...List.filled(15, 0)]),
      );

      expect(
        report.issues,
        isNot(contains(ImageQualityIssue.strongHighlights)),
      );
    },
  );

  test('tile highlight coverage equal to 30 percent is reported', () {
    final report = analyzeDecodedImage(
      tiledHighlights([480, ...List.filled(15, 100)]),
    );

    expect(report.issues, contains(ImageQualityIssue.strongHighlights));
  });

  test(
    'tile highlight coverage one pixel below 30 percent is not reported',
    () {
      final report = analyzeDecodedImage(
        tiledHighlights([479, ...List.filled(15, 100)]),
      );

      expect(
        report.issues,
        isNot(contains(ImageQualityIssue.strongHighlights)),
      );
    },
  );

  test('partial edge tile uses its actual pixel area', () {
    final report = analyzeDecodedImage(partialEdgeHighlightImage());

    expect(report.issues, contains(ImageQualityIssue.strongHighlights));
  });

  test('EXIF orientation is baked before highlight tiles are analyzed', () {
    final image = partialEdgeHighlightImage();
    final unrotated = analyzeDecodedImage(image);
    image.exif.imageIfd.orientation = 6;

    final oriented = analyzeDecodedImage(image);

    expect(unrotated.issues, contains(ImageQualityIssue.strongHighlights));
    expect(
      oriented.issues,
      isNot(contains(ImageQualityIssue.strongHighlights)),
    );
  });

  test(
    'resolution normalization keeps equivalent stripe blur classification',
    () {
      img.Image stripes(int width, int height, int blockWidth) {
        final image = img.Image(width: width, height: height);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final luminance = (x ~/ blockWidth).isEven ? 100 : 125;
            image.setPixelRgb(x, y, luminance, luminance, luminance);
          }
        }
        return image;
      }

      final normalized = analyzeDecodedImage(stripes(1024, 64, 16));
      final halfResolution = analyzeDecodedImage(stripes(512, 32, 8));

      expect(normalized.issues, contains(ImageQualityIssue.blurry));
      expect(halfResolution.issues, normalized.issues);
    },
  );

  test('file analyzer returns empty report for a missing image', () async {
    final root = await Directory.systemTemp.createTemp(
      'beanprofile-quality-missing-',
    );
    addTearDown(() => root.delete(recursive: true));

    final report = await DartImageQualityAnalyzer().analyze(
      '${root.path}/missing.jpg',
    );

    expect(report.issues, isEmpty);
  });

  test('file analyzer returns empty report for an invalid image', () async {
    final root = await Directory.systemTemp.createTemp(
      'beanprofile-quality-invalid-',
    );
    addTearDown(() => root.delete(recursive: true));
    final invalid = File('${root.path}/invalid.jpg');
    await invalid.writeAsBytes([0, 1, 2, 3]);

    final report = await DartImageQualityAnalyzer().analyze(invalid.path);

    expect(report.issues, isEmpty);
  });
}
