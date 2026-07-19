import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 한 줄: 텍스트 + 이미지 픽셀 좌표(boundingBox). 순수 Dart라 호스트 테스트에서 직접 생성 가능.
class OcrLine {
  final String text;
  final double left, top, right, bottom;
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
  double get width => right - left;
}

/// 온디바이스 OCR seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class OcrService {
  /// 이미지의 인식 라인들. 실패/빈 이미지면 빈 리스트.
  Future<List<OcrLine>> recognize(String imagePath);
}

class MlkitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
      final result = await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text,
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                right: line.boundingBox.right,
                bottom: line.boundingBox.bottom),
      ];
    } catch (_) {
      return const []; // 인식 실패/모델 미다운로드 → 빈 리스트(폼의 '자동 인식 실패' 배너로 이어짐)
    }
  }
}
