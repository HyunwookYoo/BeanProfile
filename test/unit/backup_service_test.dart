import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  test('FakeBackupService가 export 호출을 기록한다', () async {
    final fake = FakeBackupService();
    await fake.exportBackup(const TasteSnapshot(beans: [], components: [], tastings: []));
    expect(fake.exportCalls, 1);
  });

  test('FakeBackupService.readBackup이 주입한 스냅샷을 돌려준다', () async {
    final snap = TasteSnapshot(beans: [beanRow(id: 9, name: '복원됨')], components: const [], tastings: const []);
    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      readResult: snap,
    );
    final files = await fake.listBackups();
    expect(files.single.name, 'x.json');
    final got = await fake.readBackup(files.single);
    expect(got.beans.single.name, '복원됨');
  });
}
