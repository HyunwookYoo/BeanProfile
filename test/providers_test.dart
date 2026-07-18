import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/data/models.dart';
import 'package:beanprofile/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beanListProvider emits inserted beans', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(beanRepositoryProvider).createBean(const BeanInput(
          name: '케냐 니에리 AA', roaster: '리브레', type: BeanType.singleOrigin,
          roastLevel: null, roastDate: null, cupNotes: [], memo: null,
          components: [ComponentInput(country: 'Kenya', process: Process.washed)],
        ));

    // Riverpod 3.3.2: `container.read(x)` internally listens then immediately
    // closes that subscription (see ProviderContainer.read), so a bare
    // `container.read(beanListProvider.future)` races the provider's
    // listener-count-based pause and never resolves. A persistent listener
    // keeps the stream subscription active while we await the future.
    container.listen(beanListProvider, (_, _) {});
    final list = await container.read(beanListProvider.future);
    expect(list, hasLength(1));
    expect(list.first.bean.name, '케냐 니에리 AA');
  });
}
