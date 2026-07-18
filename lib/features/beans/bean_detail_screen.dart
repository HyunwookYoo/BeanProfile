import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';
import '../tasting/tasting_form_screen.dart';
import 'bean_form_screen.dart';

class BeanDetailScreen extends ConsumerWidget {
  const BeanDetailScreen({super.key, required this.beanId});
  final int beanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beanDetailProvider(beanId));
    final detail = async.value;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('원두 상세'),
        actions: [
          if (detail != null) ...[
            IconButton(
              key: const Key('edit-bean'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BeanFormScreen(existing: detail))),
            ),
            IconButton(
              key: const Key('delete-bean'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDeleteBean(context, ref, detail.bean.id),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (d) => d == null
            ? const Center(child: Text('삭제된 원두예요'))
            : _DetailBody(detail: d),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('add-tasting'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TastingFormScreen(beanId: beanId))),
            icon: const Icon(Icons.add),
            label: const Text('시음 추가'),
            style: FilledButton.styleFrom(
                backgroundColor: c.crema,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBean(
      BuildContext context, WidgetRef ref, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('원두 삭제'),
        content: const Text('이 원두와 모든 시음 기록이 삭제됩니다. 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(beanRepositoryProvider).deleteBean(id);
    if (context.mounted) Navigator.of(context).pop(); // 리스트로 복귀
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});
  final BeanDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bean = detail.bean;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(bean.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text([bean.roaster, bean.type.label].where((e) => e.isNotEmpty).join(' · '),
          style: TextStyle(color: c.appMuted)),
      const SizedBox(height: 14),
      for (final comp in detail.components) _componentBlock(context, comp),
      if (bean.roastLevel != null || bean.roastDate != null)
        _specRow(context, '로스팅',
            [bean.roastDate?.toIso8601String().substring(0, 10), bean.roastLevel?.label]
                .where((e) => e != null).join(' · ')),
      if (bean.cupNotes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final n in bean.cupNotes)
            Chip(label: Text(n), backgroundColor: c.oat, side: BorderSide(color: c.appLine)),
        ]),
      ],
      if (bean.memo != null && bean.memo!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(bean.memo!, style: TextStyle(color: c.espresso)),
      ],
      const Divider(height: 32),
      Text('시음 기록 ${detail.tastings.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (detail.tastings.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cup, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.appLine),
          ),
          child: Text('아직 시음 기록이 없어요\n＋ 시음 추가로 첫 기록을 남겨보세요',
              textAlign: TextAlign.center, style: TextStyle(color: c.appMuted)),
        )
      else
        for (final t in detail.tastings) _tastingRow(context, t),
    ]);
  }

  Widget _componentBlock(BuildContext context, OriginComponent comp) {
    final parts = <String>[
      comp.country,
      if (comp.region != null) comp.region!,
      if (comp.variety != null) comp.variety!,
      comp.process.label,
      if (comp.altitude != null) comp.altitude!,
      if (comp.ratioPercent != null) '${comp.ratioPercent}%',
    ];
    return _specRow(context, '원산지', parts.join(' · '));
  }

  Widget _specRow(BuildContext context, String k, String v) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.appLine)),
      child: Row(children: [
        SizedBox(width: 64, child: Text(k, style: TextStyle(color: c.appMuted, fontSize: 12))),
        Expanded(child: Text(v, style: monoStyle(size: 12, color: c.espresso))),
      ]),
    );
  }

  Widget _tastingRow(BuildContext context, Tasting t) {
    final c = context.colors;
    return InkWell(
      key: Key('tasting-row-${t.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TastingFormScreen(beanId: t.beanId, existing: t))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.cup, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.appLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.date.toIso8601String().substring(0, 10), style: monoStyle(size: 11, color: c.appMuted)),
          const SizedBox(height: 4),
          Text('산미 ${t.acidity} · 단맛 ${t.sweetness} · 바디 ${t.body} · 쓴맛 ${t.bitterness} · 종합 ${t.overall}',
              style: monoStyle(size: 11, color: c.espresso)),
          if (t.comment != null && t.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(t.comment!, style: TextStyle(fontSize: 12, color: c.espresso)),
          ],
        ]),
      ),
    );
  }
}
