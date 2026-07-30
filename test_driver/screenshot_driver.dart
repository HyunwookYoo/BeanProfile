// App Store 스크린샷 수집용 드라이버.
// takeScreenshot이 기기에서 보낸 PNG를 호스트의 screenshots/에 그대로 기록한다.
// 가공(리사이즈·크롭)은 하지 않는다 — 규격 검증은 CI가 별도 스텝에서 하고,
// 여기서 조용히 손대면 "왜 해상도가 틀렸는지"를 진단할 수 없게 된다.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('saved ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
