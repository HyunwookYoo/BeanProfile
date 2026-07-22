import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'add_bean_sheet.dart';
import 'bean_detail_screen.dart';
import 'bean_sort.dart';
import 'widgets/bean_card.dart';
import 'widgets/delete_ux.dart';

class BeanListScreen extends ConsumerStatefulWidget {
  const BeanListScreen({super.key});

  @override
  ConsumerState<BeanListScreen> createState() => _BeanListScreenState();
}

class _BeanListScreenState extends ConsumerState<BeanListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beans = ref.watch(beanListProvider);
    final sort = ref.watch(beanSortProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 원두', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<BeanSort>(
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (s) => ref.read(beanSortProvider.notifier).set(s),
            itemBuilder: (_) => [
              for (final s in BeanSort.values) PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddBeanSheet(context, ref),
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
                  textAlign: TextAlign.center, style: TextStyle(color: context.colors.appMuted)),
            );
          }
          final shown = sortFilterBeans(list, _query, sort);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _SearchField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text("'$_query'에 맞는 원두가 없어요",
                              style: TextStyle(color: context.colors.appMuted)),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = shown[i];
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
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: '이름 · 로스터리 검색',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: c.cup,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.appLine)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.appLine)),
      ),
    );
  }
}
