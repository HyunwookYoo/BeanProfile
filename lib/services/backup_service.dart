import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../features/settings/backup_codec.dart';

/// 노출 폴더에서 발견된 백업 파일 한 건.
class BackupFile {
  final String path;
  final String name;
  final DateTime modified;
  const BackupFile({required this.path, required this.name, required this.modified});
}

/// 백업 I/O seam. 실검증은 기기 전용(호스트 테스트에선 가짜 주입).
abstract class BackupService {
  /// 스냅샷을 사진 포함 JSON으로 문서 폴더에 쓰고 공유 시트를 띄운다.
  Future<void> exportBackup(TasteSnapshot snap);

  /// 노출(문서) 폴더의 백업 `.json` 목록(최신 먼저).
  Future<List<BackupFile>> listBackups();

  /// 파일을 읽어 디코드하고, 사진을 새 기기에 기록한 뒤
  /// photoPath를 재작성한 스냅샷을 돌려준다(DB 교체는 호출부가 수행).
  Future<TasteSnapshot> readBackup(BackupFile file);
}

class SharePlusBackupService implements BackupService {
  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  String _stamp(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  @override
  Future<void> exportBackup(TasteSnapshot snap) async {
    final photoBytes = <String, Uint8List>{};
    for (final b in snap.beans) {
      final p = b.photoPath;
      if (p != null && await File(p).exists()) {
        photoBytes[p] = await File(p).readAsBytes();
      }
    }
    final json = encodeBackup(snap, photoBytes, exportedAt: DateTime.now());
    final dir = await _docs();
    final name = 'beanprofile-backup-${_stamp(DateTime.now())}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json);
    // share_plus 13.2.1: Share.shareXFiles는 deprecated → SharePlus.instance.share 사용.
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: name));
  }

  @override
  Future<List<BackupFile>> listBackups() async {
    final dir = await _docs();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    final result = [
      for (final f in files)
        BackupFile(
          path: f.path,
          name: f.uri.pathSegments.last,
          modified: f.statSync().modified,
        ),
    ];
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  @override
  Future<TasteSnapshot> readBackup(BackupFile file) async {
    final decoded = decodeBackup(await File(file.path).readAsString());
    final dir = await _docs();
    final photos = Directory('${dir.path}/photos');
    if (!await photos.exists()) await photos.create(recursive: true);

    final rewritten = <Bean>[];
    var i = 0;
    for (final b in decoded.snapshot.beans) {
      final bytes = b.photoPath != null ? decoded.photoBytesByPath[b.photoPath] : null;
      if (bytes != null) {
        final dest =
            '${photos.path}/${DateTime.now().microsecondsSinceEpoch}_${i++}.jpg';
        await File(dest).writeAsBytes(bytes);
        rewritten.add(b.copyWith(photoPath: Value(dest)));
      } else {
        // 사진 없음/소실 → 깨진 옛 경로를 남기지 않고 null로.
        rewritten.add(b.copyWith(photoPath: const Value(null)));
      }
    }
    return TasteSnapshot(
      beans: rewritten,
      components: decoded.snapshot.components,
      tastings: decoded.snapshot.tastings,
    );
  }
}
