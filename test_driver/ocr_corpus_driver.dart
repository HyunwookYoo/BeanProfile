// OCR 코퍼스 덤프용 호스트 드라이버.
// sources.json의 사진을 루프백 HTTP로 서빙하고, 기기가 reportData로 돌려준
// ML Kit 출력을 build/ocr_corpus/<id>.ocr.json에 쓴다.
// 커밋된 픽스처(test/fixtures/ocr_corpus/)는 건드리지 않는다 — 재덤프 결과는
// 사람이 diff를 보고 옮긴다(설계 §4.6).
//
// 실행:
//   flutter drive --driver=test_driver/ocr_corpus_driver.dart \
//     --target=integration_test/ocr_corpus_dump_test.dart -d emulator-5554
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

const _sources = 'test/fixtures/ocr_corpus/sources.json';
const _output = 'build/ocr_corpus';
// integration_test/ocr_corpus_dump_test.dart의 OCR_CORPUS_HOST 기본값과 짝이다.
const _port = 8765;

Future<void> main() async {
  final sources =
      (jsonDecode(File(_sources).readAsStringSync()) as Map).cast<String, String>();
  final missing = [
    for (final MapEntry(:key, :value) in sources.entries)
      if (!File(value).existsSync()) '$key → $value',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('원본 사진이 없다(samples/README.md 참고):\n${missing.join('\n')}');
    exit(2);
  }

  final HttpServer server;
  try {
    // 루프백에만 연다 — 사진을 LAN에 내놓지 않고, Windows 방화벽도 묻지 않는다.
    // 에뮬레이터는 호스트 루프백을 10.0.2.2로 본다.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  } on SocketException catch (error) {
    stderr.writeln('포트 $_port를 열 수 없다 — 다른 프로세스가 쓰는지 확인 ($error)');
    exit(2);
  }
  server.listen((request) async {
    final path = request.uri.pathSegments;
    final response = request.response;
    if (path.length == 1 && path.single == 'index.json') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(sources));
    } else if (path.length == 2 &&
        path.first == 'card' &&
        sources.containsKey(path.last)) {
      response.add(await File(sources[path.last]!).readAsBytes());
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });

  await integrationDriver(
    responseDataCallback: (data) async {
      final dir = await Directory(_output).create(recursive: true);
      for (final card in (data!['cards'] as List).cast<Map<String, dynamic>>()) {
        final file = File('${dir.path}/${card['id']}.ocr.json');
        await file.writeAsString(_format(card));
        stdout.writeln('saved ${file.path}');
      }
    },
  );
}

/// OCR 줄 하나를 한 줄에 쓴다 — 재덤프 diff에서 바뀐 줄만 보이게.
String _format(Map<String, dynamic> card) {
  final out = StringBuffer('{\n');
  for (final key in ['id', 'source', 'quality']) {
    out.writeln('  "$key": ${jsonEncode(card[key])},');
  }
  for (final key in ['original', 'enhanced']) {
    final lines = card[key] as List?;
    final comma = key == 'original' ? ',' : '';
    if (lines == null) {
      out.writeln('  "$key": null$comma');
      continue;
    }
    out.writeln('  "$key": [');
    for (var i = 0; i < lines.length; i++) {
      out.writeln('    ${jsonEncode(lines[i])}${i < lines.length - 1 ? ',' : ''}');
    }
    out.writeln('  ]$comma');
  }
  out.write('}\n');
  return out.toString();
}
