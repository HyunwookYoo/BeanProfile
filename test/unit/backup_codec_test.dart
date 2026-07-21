import 'dart:typed_data';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/settings/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

TasteSnapshot _sample() => TasteSnapshot(
      beans: [
        beanRow(id: 1, name: '예가체프', roaster: '프릳츠',
            cupNotes: const ['블루베리', '자스민'], photoPath: '/p/a.jpg'),
        beanRow(id: 2, name: '수프리모', roaster: '테라로사', cupNotes: const []),
      ],
      components: [
        compRow(id: 1, beanId: 1, country: 'Ethiopia', process: Process.washed),
        compRow(id: 2, beanId: 2, country: 'Colombia', process: Process.natural, ratioPercent: 100),
      ],
      tastings: [tastingRow(id: 1, beanId: 1, overall: 5)],
    );

void main() {
  final when = DateTime.utc(2026, 7, 22, 9, 41);

  test('encode→decode→encode 라운드트립 JSON이 동일하다', () {
    final photos = {'/p/a.jpg': Uint8List.fromList([10, 20, 30])};
    final json1 = encodeBackup(_sample(), photos, exportedAt: when);
    final decoded = decodeBackup(json1);
    final json2 = encodeBackup(decoded.snapshot, decoded.photoBytesByPath, exportedAt: when);
    expect(json2, json1);
  });

  test('컵노트·enum·사진 바이트가 보존된다', () {
    final photos = {'/p/a.jpg': Uint8List.fromList([10, 20, 30])};
    final decoded = decodeBackup(encodeBackup(_sample(), photos, exportedAt: when));
    final bean = decoded.snapshot.beans.firstWhere((b) => b.id == 1);
    expect(bean.cupNotes, ['블루베리', '자스민']);
    expect(bean.roaster, '프릳츠');
    expect(decoded.photoBytesByPath['/p/a.jpg'], [10, 20, 30]);
    expect(decoded.snapshot.components.first.process, Process.washed);
    expect(decoded.snapshot.tastings.single.overall, 5);
  });

  test('사진 없는 원두는 photoBase64 없이 왕복된다', () {
    final decoded = decodeBackup(encodeBackup(_sample(), const {}, exportedAt: when));
    expect(decoded.photoBytesByPath, isEmpty);
    expect(decoded.snapshot.beans, hasLength(2));
  });

  test('빈 스냅샷도 왕복된다', () {
    const empty = TasteSnapshot(beans: [], components: [], tastings: []);
    final decoded = decodeBackup(encodeBackup(empty, const {}, exportedAt: when));
    expect(decoded.snapshot.beans, isEmpty);
    expect(decoded.photoBytesByPath, isEmpty);
  });

  test('미지 schemaVersion은 FormatException', () {
    expect(
      () => decodeBackup('{"schemaVersion":999,"beans":[],"components":[],"tastings":[]}'),
      throwsFormatException,
    );
  });

  test('깨진 JSON은 FormatException', () {
    expect(() => decodeBackup('not json at all'), throwsFormatException);
  });
}
