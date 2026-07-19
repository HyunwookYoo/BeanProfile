import 'package:beanprofile/providers.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:beanprofile/services/photo_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('providers가 실제 서비스 구현으로 해석되고 생성이 네이티브를 안 건드린다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(ocrServiceProvider), isA<MlkitOcrService>());
    expect(c.read(photoServiceProvider), isA<ImagePickerPhotoService>());
  });
}
