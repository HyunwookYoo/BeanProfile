import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'bean_detail_screen.dart';
import 'bean_form_screen.dart';
import 'widgets/bean_card.dart';
import 'widgets/delete_ux.dart';

class BeanListScreen extends ConsumerWidget {
  const BeanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beans = ref.watch(beanListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BeanFormScreen())),
        backgroundColor: context.colors.crema,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: beans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('아직 기록한 원두가 없어요\n＋ 로 첫 원두를 추가해 보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.appMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = list[i];
              return Dismissible(
                key: ValueKey('bean-${s.bean.id}'),
                direction: DismissDirection.endToStart,
                background: const SwipeDeleteBackground(),
                confirmDismiss: (_) async {
                  final ok = await confirmDeleteBeanDialog(context);
                  if (ok) await ref.read(beanRepositoryProvider).deleteBean(s.bean.id);
                  return false; // 반응형 리빌드가 삭제된 카드 제거(assert 회피)
                },
                child: BeanCard(
                  summary: s,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BeanDetailScreen(beanId: s.bean.id))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
