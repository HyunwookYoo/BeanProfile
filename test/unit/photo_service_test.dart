import 'dart:io';

import 'package:beanprofile/services/photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory root;
  late ImagePickerPhotoService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('beanprofile-photo-');
    service = ImagePickerPhotoService(documentsDirectory: () async => root);
  });
  tearDown(() => root.delete(recursive: true));

  test('decodable image is persisted as quality-85 jpg', () async {
    final source = File('${root.path}/source.png');
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(40, 80, 120));
    await source.writeAsBytes(img.encodePng(image));

    final result = await service.persist(source.path);

    expect(result, endsWith('.jpg'));
    expect(await img.decodeImageFile(result), isNotNull);
    expect(await File(result).length(), greaterThan(0));
  });

  test('unsupported bytes are copied without failing save', () async {
    final source = File('${root.path}/source.heic');
    const bytes = [0, 1, 2, 3, 4, 5];
    await source.writeAsBytes(bytes);

    final result = await service.persist(source.path);

    expect(result, endsWith('.heic'));
    expect(await File(result).readAsBytes(), bytes);
  });

  test('unsupported extensionless bytes use img fallback from dotted parent',
      () async {
    final dottedParent = Directory('${root.path}/cache.v1');
    await dottedParent.create();
    final source = File('${dottedParent.path}/capture');
    const bytes = [0, 1, 2, 3, 4, 5];
    await source.writeAsBytes(bytes);

    final result = await service.persist(source.path);

    expect(result, endsWith('.img'));
    expect(await File(result).readAsBytes(), bytes);
  });
}
