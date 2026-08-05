import 'package:beanprofile/app.dart';
import 'package:beanprofile/data/bean_repository.dart';
import 'package:beanprofile/data/database.dart';
import 'package:beanprofile/data/enums.dart';
import 'package:beanprofile/features/beans/ocr/ocr_diagnostics.dart';
import 'package:beanprofile/features/beans/ocr/ocr_pipeline.dart';
import 'package:beanprofile/providers.dart';
import 'package:beanprofile/services/backup_service.dart';
import 'package:beanprofile/services/ocr_service.dart';
import 'package:beanprofile/services/photo_service.dart';
import 'package:beanprofile/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 인메모리 테스트 DB (FK on). 반드시 addTearDown(db.close).
AppDatabase testDatabase() => AppDatabase.forTesting(NativeDatabase.memory());

/// DB를 주입한 저장소.
BeanRepository testRepository(AppDatabase db) => BeanRepository(db);

/// DB를 override한 ProviderContainer. addTearDown(container.dispose).
ProviderContainer testContainer(AppDatabase db) =>
    ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

/// 위젯 테스트용: 테마 + (선택) DB/OCR/Photo/Backup override로 화면을 감싼다.
Widget wrapApp(Widget child,
        {AppDatabase? db,
        OcrService? ocr,
        OcrPipeline? pipeline,
        OcrDiagnosticsService? diagnostics,
        bool? diagnosticsEnabled,
        PhotoService? photo,
        BackupService? backup}) =>
    ProviderScope(
      overrides: [
        if (diagnosticsEnabled != null)
          ocrDiagnosticsEnabledProvider.overrideWithValue(diagnosticsEnabled),
        if (diagnostics != null)
          ocrDiagnosticsServiceProvider.overrideWithValue(diagnostics),
        if (db != null) databaseProvider.overrideWithValue(db),
        if (ocr != null) ocrServiceProvider.overrideWithValue(ocr),
        if (pipeline != null) ocrPipelineProvider.overrideWithValue(pipeline),
        if (photo != null) photoServiceProvider.overrideWithValue(photo),
        if (backup != null) backupServiceProvider.overrideWithValue(backup),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        // 실제 앱과 같은 언어로 렌더해야 시스템 위젯(날짜 선택기 등)을 찾는
        // 단언이 화면과 어긋나지 않는다. lib/app.dart의 주석 참고.
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: child,
      ),
    );

/// 샘플 싱글 오리진.
BeanInput sampleSingle({String name = '예가체프 코체레', String country = 'Ethiopia'}) =>
    BeanInput(
      name: name, roaster: '프릳츠', type: BeanType.singleOrigin,
      roastLevel: RoastLevel.lightMedium, roastDate: null,
      cupNotes: const ['블루베리', '자스민'], memo: null,
      components: [ComponentInput(country: country, process: Process.washed)],
    );

/// 샘플 블렌드 (구성 2개 + 비율).
BeanInput sampleBlend({String name = '하우스 블렌드'}) => BeanInput(
      name: name, roaster: '테라로사', type: BeanType.blend,
      roastLevel: RoastLevel.medium, roastDate: null,
      cupNotes: const ['다크초콜릿'], memo: null,
      components: const [
        ComponentInput(country: 'Brazil', process: Process.natural, ratioPercent: 60),
        ComponentInput(country: 'Ethiopia', process: Process.washed, ratioPercent: 40),
      ],
    );

/// 샘플 시음 (강도 4축 + 종합 + 코멘트).
TastingInput sampleTasting({
  int acidity = 4,
  int sweetness = 3,
  int body = 3,
  int bitterness = 2,
  int overall = 4,
  String? comment = '균형이 좋다',
  DateTime? date,
  int? degassingDays,
}) =>
    TastingInput(
      date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall, comment: comment,
      degassingDays: degassingDays,
    );

extension BeanInputPhoto on BeanInput {
  BeanInput copyWithPhoto(String path) => BeanInput(
        name: name, roaster: roaster, type: type, roastLevel: roastLevel,
        roastDate: roastDate, cupNotes: cupNotes, memo: memo, components: components,
        photoPath: path,
      );
}

class FakeOcrService implements OcrService {
  FakeOcrService.lines(this._lines);
  factory FakeOcrService.text(String text) => FakeOcrService.lines([
        for (final (i, t) in _splitText(text).indexed)
          OcrLine(t, left: 0, top: i * 10.0, right: 100, bottom: i * 10.0 + 10),
      ]);
  final List<OcrLine> _lines;
  @override
  Future<List<OcrLine>> recognize(String imagePath) async => _lines;
  static List<String> _splitText(String s) =>
      s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}

class FakeOcrPipeline implements OcrPipeline {
  FakeOcrPipeline(this.results);
  final List<OcrPipelineResult> results;
  final paths = <String>[];
  var _index = 0;

  @override
  Future<OcrPipelineResult> analyze(String imagePath) async {
    paths.add(imagePath);
    return results[_index++];
  }
}

class FakePhotoService implements PhotoService {
  FakePhotoService({
    this.pickResult,
    this.pickResults,
    this.persistResult = '/app/photos/persisted.jpg',
    this.throwOnPersist = false,
  });
  final String? pickResult;
  final List<String?>? pickResults;
  final String persistResult;
  final bool throwOnPersist;
  int pickCalls = 0;

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final index = pickCalls++;
    return pickResults == null ? pickResult : pickResults![index];
  }

  @override
  Future<String> persist(String tempPath) async {
    if (throwOnPersist) throw Exception('persist failed');
    return persistResult;
  }
}

class FakeBackupService implements BackupService {
  FakeBackupService({this.backups = const [], TasteSnapshot? readResult, this.throwOnRead = false})
      : _readResult = readResult;
  final List<BackupFile> backups;
  final TasteSnapshot? _readResult;
  final bool throwOnRead;

  int exportCalls = 0;
  int readCalls = 0;
  TasteSnapshot? lastExported;

  @override
  Future<void> exportBackup(TasteSnapshot snap) async {
    exportCalls++;
    lastExported = snap;
  }

  @override
  Future<List<BackupFile>> listBackups() async => backups;

  @override
  Future<TasteSnapshot> readBackup(BackupFile file) async {
    readCalls++;
    if (throwOnRead) throw const FormatException('bad backup');
    return _readResult ?? const TasteSnapshot(beans: [], components: [], tastings: []);
  }
}

// ── 순수 함수(computeTasteProfile) 테스트용 drift 행 팩토리 ──
// BeanInput이 아니라 DB에서 읽힌 '행' 그대로가 필요해서 직접 만든다(DB 불필요).

Bean beanRow({
  int id = 1,
  String name = '원두',
  String roaster = '',
  List<String> cupNotes = const [],
  String? photoPath,
  DateTime? createdAt,
  DateTime? roastDate,
}) =>
    Bean(
      id: id, name: name, roaster: roaster, type: BeanType.singleOrigin,
      cupNotes: cupNotes, photoPath: photoPath, roastDate: roastDate,
      createdAt: createdAt ?? DateTime(2026, 7, 1),
    );

OriginComponent compRow({
  int id = 1,
  int beanId = 1,
  String country = 'Ethiopia',
  Process process = Process.washed,
  int? ratioPercent,
}) =>
    OriginComponent(
      id: id, beanId: beanId, country: country,
      process: process, ratioPercent: ratioPercent,
    );

Tasting tastingRow({
  int id = 1,
  int beanId = 1,
  int overall = 4,
  int acidity = 3,
  int sweetness = 3,
  int body = 3,
  int bitterness = 3,
  int? degassingDays,
  DateTime? date,
}) =>
    Tasting(
      id: id, beanId: beanId, date: date ?? DateTime(2026, 7, 1),
      acidity: acidity, sweetness: sweetness, body: body,
      bitterness: bitterness, overall: overall,
      degassingDays: degassingDays,
      createdAt: DateTime(2026, 7, 1),
    );

// ── 실기기 OCR 좌표 픽스처 ──
// 2026-08-04 Android 에뮬레이터 ML Kit(korean) ORIGINAL 패스 출력.
// 원본 4032x3024 / EXIF orientation 6 → ML Kit이 3024x4032 좌표계로 돌려준 값.
// 줄 순서가 파서 결과에 영향을 준다(순서 의존 경로 있음) — 재정렬 금지.
const redCascaraLines = <OcrLine>[
  OcrLine('블렌딩:', left: 876, top: 2453, right: 1095, bottom: 2520),
  OcrLine('노트:', left: 839, top: 3349, right: 1046, bottom: 3413),
  OcrLine('Blending Info', left: 876, top: 2559, right: 1218, bottom: 2617),
  OcrLine('Notes', left: 875, top: 3451, right: 1034, bottom: 3501),
  OcrLine('UNSPECIALTY BLEND', left: 1191, top: 191, right: 2160, bottom: 260),
  OcrLine('RED CASCARA', left: 1137, top: 511, right: 2303, bottom: 610),
  OcrLine('로스터기:', left: 873, top: 3708, right: 1159, bottom: 3781),
  OcrLine('Roaster', left: 864, top: 3820, right: 1073, bottom: 3874),
  OcrLine('레드 카스카라', left: 1312, top: 773, right: 2127, bottom: 895),
  OcrLine('Thailand Phupanna coffee',
      left: 1329, top: 2465, right: 2096, bottom: 2536),
  OcrLine('bio control Natural 70940%',
      left: 1352, top: 2563, right: 2236, bottom: 2622),
  OcrLine('Ethiopia Sidama Bensa Keramo Ako',
      left: 1327, top: 2745, right: 2394, bottom: 2807),
  OcrLine('GI Natural- 40%', left: 1366, top: 2836, right: 1846, bottom: 2901),
  OcrLine('Colombia Inmaculada Fellow Farnms',
      left: 1327, top: 3017, right: 2393, bottom: 3078),
  OcrLine('Papayo Natural 20%',
      left: 1345, top: 3102, right: 1973, bottom: 3176),
  OcrLine('Raspberrie, Sapphire Grape,',
      left: 1328, top: 3351, right: 2318, bottom: 3443),
  OcrLine('Complexity, Citrus fnish',
      left: 1328, top: 3450, right: 2197, bottom: 3527),
  OcrLine('Stronghold S7X Ver.2',
      left: 1326, top: 3704, right: 2065, bottom: 3780),
];
