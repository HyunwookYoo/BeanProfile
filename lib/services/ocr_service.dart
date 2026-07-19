import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 온디바이스 OCR seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class OcrService {
  /// [imagePath] 이미지의 전체 인식 텍스트를 반환한다. 실패/빈 이미지면 ''.
  Future<String> recognize(String imagePath);
}

class MlkitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  @override
  Future<String> recognize(String imagePath) async {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    final result = await _recognizer!.processImage(InputImage.fromFilePath(imagePath));
    return result.text;
  }
}
