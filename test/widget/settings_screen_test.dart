import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/features/settings/settings_screen.dart';
import 'package:beanprofile/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  testWidgets('내보내기 탭 → 서비스가 호출된다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeBackupService();
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 내보내기'));
    await t.pumpAndSettle();

    expect(fake.exportCalls, 1);
  });

  testWidgets('가져오기 → 파일 선택 → 확인 → replaceAll로 교체', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '기존'));

    final restore = TasteSnapshot(
      beans: [beanRow(id: 99, name: '복원됨')],
      components: [compRow(id: 5, beanId: 99, country: 'Kenya')],
      tastings: const [],
    );
    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      readResult: restore,
    );
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();
    await t.tap(find.text('x.json')); // 파일 시트 항목
    await t.pumpAndSettle();
    await t.tap(find.text('복원')); // 확인 다이얼로그
    await t.pumpAndSettle();

    final after = await repo.getTasteSnapshot();
    expect(after.beans.map((b) => b.name), ['복원됨']);
  });

  testWidgets('백업 파일이 없으면 안내한다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeBackupService(backups: const []);
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();

    expect(find.textContaining('가져올 백업 파일이 없어요'), findsOneWidget);
  });

  testWidgets('가져오기 → 파일 선택 → 취소하면 기존 데이터가 보존된다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '기존'));

    final other = TasteSnapshot(
      beans: [beanRow(id: 99, name: '다른것')],
      components: [compRow(id: 5, beanId: 99, country: 'Kenya')],
      tastings: const [],
    );
    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      readResult: other,
    );
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();
    await t.tap(find.text('x.json')); // 파일 시트 항목
    await t.pumpAndSettle();
    await t.tap(find.text('취소')); // 확인 다이얼로그
    await t.pumpAndSettle();

    expect((await repo.getTasteSnapshot()).beans.map((b) => b.name), ['기존']);
  });

  testWidgets('가져오기 → 파일 읽기 실패하면 에러를 안내하고 기존 데이터가 보존된다', (t) async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = testRepository(db);
    await repo.createBean(sampleSingle(name: '기존'));

    final fake = FakeBackupService(
      backups: [BackupFile(path: '/b/x.json', name: 'x.json', modified: DateTime(2026, 7, 22))],
      throwOnRead: true,
    );
    await t.pumpWidget(wrapApp(const SettingsScreen(), db: db, backup: fake));

    await t.tap(find.text('데이터 가져오기'));
    await t.pumpAndSettle();
    await t.tap(find.text('x.json')); // 파일 시트 항목
    await t.pumpAndSettle();
    await t.tap(find.text('복원')); // 확인 다이얼로그
    await t.pumpAndSettle();

    expect(find.textContaining('백업 파일을 읽을 수 없어요'), findsOneWidget);
    expect((await repo.getTasteSnapshot()).beans.map((b) => b.name), ['기존']);
  });
}
