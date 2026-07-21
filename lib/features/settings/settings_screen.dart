import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/backup_service.dart';
import '../../theme.dart';

const kAppVersion = 'v0.5.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('설정', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionLabel(context, '데이터'),
          _tile(
            context,
            icon: Icons.ios_share,
            title: '데이터 내보내기',
            subtitle: '사진 포함 JSON 백업 · 공유 시트',
            onTap: () => _export(context, ref),
          ),
          const SizedBox(height: 9),
          _tile(
            context,
            icon: Icons.download,
            title: '데이터 가져오기',
            subtitle: '백업에서 복원 · 현재 데이터를 대체',
            onTap: () => _import(context, ref),
          ),
          _sectionLabel(context, '정보'),
          _tile(
            context,
            icon: Icons.info_outline,
            title: '버전',
            trailing: Text(kAppVersion, style: monoStyle(size: 13, weight: FontWeight.w700, color: c.espresso)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('모든 데이터는 이 기기에만 저장됩니다 · 오프라인 전용',
                style: TextStyle(fontSize: 11, color: c.appMuted)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: monoStyle(size: 10.5, weight: FontWeight.w700, color: context.colors.appMuted)),
      );

  Widget _tile(BuildContext context,
      {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    final c = context.colors;
    return Material(
      color: c.cup,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.appLine),
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.cremaInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: TextStyle(fontSize: 11, color: c.appMuted)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
                Icon(Icons.chevron_right, color: c.appMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(beanRepositoryProvider);
    final service = ref.read(backupServiceProvider);
    try {
      final snap = await repo.getTasteSnapshot();
      await service.exportBackup(snap);
    } catch (e) {
      if (context.mounted) _snack(context, '내보내기에 실패했어요: $e');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    final repo = ref.read(beanRepositoryProvider);

    List<BackupFile> files;
    try {
      files = await service.listBackups();
    } catch (e) {
      if (context.mounted) _snack(context, '백업 폴더를 열 수 없어요: $e');
      return;
    }
    if (!context.mounted) return;
    if (files.isEmpty) {
      _snack(context, '가져올 백업 파일이 없어요 — Files 앱의 이 폴더에 .json을 넣어 주세요');
      return;
    }

    final picked = await showModalBottomSheet<BackupFile>(
      context: context,
      builder: (_) => _FileSheet(files: files),
    );
    if (picked == null || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ReplaceConfirmDialog(),
    );
    if (ok != true || !context.mounted) return;

    try {
      final snap = await service.readBackup(picked);
      await repo.replaceAll(snap);
      if (context.mounted) _snack(context, '복원했어요 · 원두 ${snap.beans.length}개');
    } catch (e) {
      if (context.mounted) _snack(context, '백업 파일을 읽을 수 없어요: $e');
    }
  }
}

class _FileSheet extends StatelessWidget {
  const _FileSheet({required this.files});
  final List<BackupFile> files;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: c.appLine, borderRadius: BorderRadius.circular(3)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('백업 파일 선택', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            for (final f in files)
              ListTile(
                leading: Icon(Icons.description_outlined, color: c.cremaInk),
                title: Text(f.name, style: monoStyle(size: 12, weight: FontWeight.w700, color: c.espresso)),
                subtitle: Text(_fmt(f.modified), style: TextStyle(fontSize: 11, color: c.appMuted)),
                onTap: () => Navigator.of(context).pop(f),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }
}

class _ReplaceConfirmDialog extends StatelessWidget {
  const _ReplaceConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: Text('현재 데이터가 모두 대체됩니다', style: TextStyle(color: c.cherry, fontWeight: FontWeight.w800, fontSize: 17)),
      content: const Text('가져오기는 지금 기록을 백업 내용으로 완전히 교체합니다. 되돌릴 수 없으니, 먼저 내보내기로 현재 상태를 백업해 두는 것을 권장합니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.cherry),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('복원'),
        ),
      ],
    );
  }
}
