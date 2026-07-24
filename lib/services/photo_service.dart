import 'dart:io';

import 'package:image/image.dart' as img;
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

typedef DocumentsDirectory = Future<Directory> Function();
typedef EncodedImageWriter = Future<void> Function(String path, List<int> bytes);

class ImagePickerPhotoService implements PhotoService {
  ImagePickerPhotoService({
    DocumentsDirectory? documentsDirectory,
    EncodedImageWriter? writeEncodedImage,
  })
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory,
      _writeEncodedImage = writeEncodedImage ?? _writeEncodedImageToFile;

  final ImagePicker _picker = ImagePicker();
  final DocumentsDirectory _documentsDirectory;
  final EncodedImageWriter _writeEncodedImage;

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    return x?.path;
  }

  @override
  Future<String> persist(String tempPath) async {
    final dir = await _documentsDirectory();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final jpegDest = '${photos.path}/$stamp.jpg';
    try {
      final decoded = await img.decodeImageFile(tempPath);
      if (decoded == null) return _copyOriginal(tempPath, photos, stamp);
      final oriented = img.bakeOrientation(decoded);
      await _writeEncodedImage(
          jpegDest, img.encodeJpg(oriented, quality: 85));
      return jpegDest;
    } catch (_) {
      final partial = File(jpegDest);
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {
        // The original-copy fallback below remains the recovery path.
      }
      return _copyOriginal(tempPath, photos, stamp);
    }
  }

  Future<String> _copyOriginal(
      String tempPath, Directory photos, int stamp) async {
    final basename = tempPath.split(RegExp(r'[/\\]')).last;
    final dot = basename.lastIndexOf('.');
    final ext = dot > 0 && dot < basename.length - 1
        ? basename.substring(dot + 1)
        : 'img';
    var dest = '${photos.path}/$stamp.$ext';
    if (await File(dest).exists()) {
      dest = '${photos.path}/${stamp}_original.$ext';
    }
    await File(tempPath).copy(dest);
    return dest;
  }

  static Future<void> _writeEncodedImageToFile(
          String path, List<int> bytes) =>
      File(path).writeAsBytes(bytes);
}
