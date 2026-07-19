import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 사진 선택/보관 seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class PhotoService {
  /// 카메라(fromCamera=true) 또는 갤러리에서 이미지를 고른다.
  /// 반환: 임시 파일 경로, 취소 시 null.
  Future<String?> pick({required bool fromCamera});

  /// 임시 이미지를 앱 문서 디렉터리(photos/)로 복사하고 영구 경로를 반환한다.
  Future<String> persist(String tempPath);
}

class ImagePickerPhotoService implements PhotoService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    return x?.path;
  }

  @override
  Future<String> persist(String tempPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
    final dest = '${photos.path}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(tempPath).copy(dest);
    return dest;
  }
}
