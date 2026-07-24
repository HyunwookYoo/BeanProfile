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
    final source = File('${root.path}/source.jpg');
    final image = img.Image(width: 32, height: 16);
    img.fill(image, color: img.ColorRgb8(40, 80, 120));
    image.exif.imageIfd.orientation = 6;
    await source.writeAsBytes(img.encodeJpg(image, quality: 100));

    final result = await service.persist(source.path);
    final bytes = await File(result).readAsBytes();
    final persisted = img.decodeJpg(bytes);

    expect(result, endsWith('.jpg'));
    expect(persisted, isNotNull);
    expect(persisted!.width, 16);
    expect(persisted.height, 32);
    final pixel = persisted.getPixel(0, 0);
    expect(pixel.r.toInt(), closeTo(40, 8));
    expect(pixel.g.toInt(), closeTo(80, 8));
    expect(pixel.b.toInt(), closeTo(120, 8));
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

  test('partial JPEG write failure removes it and copies the original', () async {
    final source = File('${root.path}/source.png');
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    final sourceBytes = img.encodePng(image);
    await source.writeAsBytes(sourceBytes);
    service = ImagePickerPhotoService(
      documentsDirectory: () async => root,
      writeEncodedImage: (path, bytes) async {
        await File(path).writeAsBytes(bytes.take(4).toList());
        throw const FileSystemException('disk full');
      },
    );

    final result = await service.persist(source.path);

    expect(result, endsWith('.png'));
    expect(await File(result).readAsBytes(), sourceBytes);
    final partialJpegs = await Directory('${root.path}/photos')
        .list()
        .where((entry) => entry.path.endsWith('.jpg'))
        .toList();
    expect(partialJpegs, isEmpty);
  });
}
