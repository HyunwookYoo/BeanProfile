import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

enum ImageQualityIssue { lowContrast, blurry, strongHighlights }

class ImageQualityReport {
  final Set<ImageQualityIssue> issues;
  const ImageQualityReport([this.issues = const {}]);

  bool get lowContrast => issues.contains(ImageQualityIssue.lowContrast);
  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class ImageQualityAnalyzer {
  Future<ImageQualityReport> analyze(String imagePath);
}

class DartImageQualityAnalyzer implements ImageQualityAnalyzer {
  @override
  Future<ImageQualityReport> analyze(String imagePath) {
    return Isolate.run(() async {
      try {
        final image = await img.decodeImageFile(imagePath);
        if (image == null) return const ImageQualityReport();
        return analyzeDecodedImage(image);
      } catch (_) {
        return const ImageQualityReport();
      }
    });
  }
}

ImageQualityReport analyzeDecodedImage(img.Image source) {
  var image = img.bakeOrientation(source);
  image = img.grayscale(image);
  image = _resizeLongEdge(image, 1024);

  final histogram = List<int>.filled(256, 0);
  var sum = 0.0;
  var sumSquares = 0.0;
  var highlightCount = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final luminance = image.getPixel(x, y).r.toInt().clamp(0, 255);
      histogram[luminance]++;
      sum += luminance;
      sumSquares += luminance * luminance;
      if (luminance >= 250) highlightCount++;
    }
  }

  final pixelCount = image.width * image.height;
  final mean = sum / pixelCount;
  final luminanceVariance = math.max(
    0.0,
    sumSquares / pixelCount - mean * mean,
  );
  final standardDeviation = math.sqrt(luminanceVariance);
  final p05 = _percentile(histogram, pixelCount, 0.05);
  final p95 = _percentile(histogram, pixelCount, 0.95);
  final laplacianVariance = _laplacianVariance(image);

  final issues = <ImageQualityIssue>{};
  if (p95 - p05 < 64 && standardDeviation < 30) {
    issues.add(ImageQualityIssue.lowContrast);
  }
  if (laplacianVariance < 100) {
    issues.add(ImageQualityIssue.blurry);
  }
  if (highlightCount / pixelCount >= 0.06 && _hasHighlightCluster(image)) {
    issues.add(ImageQualityIssue.strongHighlights);
  }
  return ImageQualityReport(issues);
}

img.Image _resizeLongEdge(img.Image image, int target) {
  final longEdge = math.max(image.width, image.height);
  if (longEdge == target) return image;

  if (image.width >= image.height) {
    return img.copyResize(
      image,
      width: target,
      height: math.max(1, (image.height * target / image.width).round()),
    );
  }
  return img.copyResize(
    image,
    width: math.max(1, (image.width * target / image.height).round()),
    height: target,
  );
}

int _percentile(List<int> histogram, int pixelCount, double percentile) {
  final targetCount = (pixelCount * percentile).ceil();
  var cumulative = 0;
  for (var luminance = 0; luminance < histogram.length; luminance++) {
    cumulative += histogram[luminance];
    if (cumulative >= targetCount) return luminance;
  }
  return histogram.length - 1;
}

double _laplacianVariance(img.Image image) {
  if (image.width < 3 || image.height < 3) return 0;

  var count = 0;
  var sum = 0.0;
  var sumSquares = 0.0;
  for (var y = 1; y < image.height - 1; y++) {
    for (var x = 1; x < image.width - 1; x++) {
      final center = image.getPixel(x, y).r.toDouble();
      final response =
          image.getPixel(x - 1, y).r +
          image.getPixel(x + 1, y).r +
          image.getPixel(x, y - 1).r +
          image.getPixel(x, y + 1).r -
          4 * center;
      count++;
      sum += response;
      sumSquares += response * response;
    }
  }

  final mean = sum / count;
  return math.max(0.0, sumSquares / count - mean * mean);
}

bool _hasHighlightCluster(img.Image image) {
  const tileSize = 64;
  for (var tileY = 0; tileY < image.height; tileY += tileSize) {
    for (var tileX = 0; tileX < image.width; tileX += tileSize) {
      final maxY = math.min(tileY + tileSize, image.height);
      final maxX = math.min(tileX + tileSize, image.width);
      var highlights = 0;
      for (var y = tileY; y < maxY; y++) {
        for (var x = tileX; x < maxX; x++) {
          if (image.getPixel(x, y).r >= 250) highlights++;
        }
      }
      final tilePixelCount = (maxX - tileX) * (maxY - tileY);
      if (highlights / tilePixelCount >= 0.30) return true;
    }
  }
  return false;
}
