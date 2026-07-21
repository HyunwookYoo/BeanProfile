import 'dart:convert';
import 'dart:typed_data';

import '../../data/database.dart';
import '../../data/models.dart';

const _schemaVersion = 1;

/// 사진 base64를 포함한 단일 JSON 문자열. 순수 함수 — DB·파일·플러그인 무관.
/// [photoBytes]는 bean.photoPath → 파일 bytes 맵(서비스가 채워 넘긴다).
String encodeBackup(
  TasteSnapshot snap,
  Map<String, Uint8List> photoBytes, {
  required DateTime exportedAt,
}) {
  final beans = [
    for (final b in snap.beans)
      {
        ...b.toJson(),
        'photoBase64':
            (b.photoPath != null && photoBytes.containsKey(b.photoPath))
                ? base64Encode(photoBytes[b.photoPath]!)
                : null,
      },
  ];
  return jsonEncode({
    'schemaVersion': _schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'beans': beans,
    'components': [for (final c in snap.components) c.toJson()],
    'tastings': [for (final t in snap.tastings) t.toJson()],
  });
}

class DecodedBackup {
  final TasteSnapshot snapshot;
  final Map<String, Uint8List> photoBytesByPath;
  const DecodedBackup(this.snapshot, this.photoBytesByPath);
}

/// 잘못된 JSON·미지 버전·해석 실패는 모두 [FormatException].
DecodedBackup decodeBackup(String jsonStr) {
  final dynamic root = jsonDecode(jsonStr); // 깨진 JSON → FormatException 전파
  if (root is! Map || root['schemaVersion'] != _schemaVersion) {
    throw const FormatException('지원하지 않는 백업 형식 또는 버전입니다');
  }
  try {
    final photoBytes = <String, Uint8List>{};
    final beans = <Bean>[];
    for (final raw in (root['beans'] as List)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final b64 = m.remove('photoBase64') as String?;
      // drift의 기본 ValueSerializer는 DateTime/double/Uint8List만 특별 취급하므로
      // jsonDecode가 만든 List<dynamic>을 List<String>으로 그대로 캐스팅하지 못한다.
      // cupNotes(유일한 List<String> 컬럼)만 왕복 전 타입을 보정한다.
      final rawCupNotes = m['cupNotes'];
      if (rawCupNotes is List) {
        m['cupNotes'] = List<String>.from(rawCupNotes);
      }
      final bean = Bean.fromJson(m);
      beans.add(bean);
      if (b64 != null && bean.photoPath != null) {
        photoBytes[bean.photoPath!] = base64Decode(b64);
      }
    }
    final components = [
      for (final raw in (root['components'] as List))
        OriginComponent.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    final tastings = [
      for (final raw in (root['tastings'] as List))
        Tasting.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    return DecodedBackup(
      TasteSnapshot(beans: beans, components: components, tastings: tastings),
      photoBytes,
    );
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('백업 파일을 해석할 수 없습니다: $e');
  }
}
