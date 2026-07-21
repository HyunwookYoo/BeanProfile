import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/bean_repository.dart';
import 'data/database.dart';
import 'features/profile/taste_profile.dart';
import 'services/ocr_service.dart';
import 'services/photo_service.dart';

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

final beanDetailProvider =
    StreamProvider.autoDispose.family<BeanDetail?, int>(
  (ref, beanId) => ref.watch(beanRepositoryProvider).watchBeanDetail(beanId),
);

final ocrServiceProvider = Provider<OcrService>((ref) => MlkitOcrService());
final photoServiceProvider = Provider<PhotoService>((ref) => ImagePickerPhotoService());

final tasteProfileProvider = StreamProvider<TasteProfile>(
  (ref) => ref
      .watch(beanRepositoryProvider)
      .watchTasteSnapshot()
      .map(computeTasteProfile),
);
