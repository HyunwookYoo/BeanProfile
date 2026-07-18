import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/bean_repository.dart';
import 'data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final beanRepositoryProvider = Provider<BeanRepository>(
  (ref) => BeanRepository(ref.watch(databaseProvider)),
);

final beanListProvider = StreamProvider<List<BeanSummary>>(
  (ref) => ref.watch(beanRepositoryProvider).watchBeanSummaries(),
);

final beanDetailProvider = StreamProvider.family<BeanDetail?, int>(
  (ref, beanId) => ref.watch(beanRepositoryProvider).watchBeanDetail(beanId),
);
