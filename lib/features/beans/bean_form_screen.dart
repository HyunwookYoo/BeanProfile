import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'ocr/ocr_chip.dart';
import 'ocr/ocr_draft.dart';
import 'widgets/ocr_chips_panel.dart';

class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({
    super.key,
    this.existing,
    this.draft,
    this.initialType,
    this.photoTempPath,
  });
  final BeanDetail? existing;
  final OcrDraft? draft;
  final BeanType? initialType;
  final String? photoTempPath;
  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _ComponentDraft {
  _ComponentDraft({
    this.process = Process.washed,
    this.processProvidedOrEdited = false,
    this.processFromOcr = false,
    this.ratioFromOcr = false,
  });

  final country = TextEditingController();
  final region = TextEditingController();
  Process process;
  bool processProvidedOrEdited;
  bool processFromOcr;
  bool ratioFromOcr;
  final ratio = TextEditingController();
  void dispose() { country.dispose(); region.dispose(); ratio.dispose(); }
}

class _BeanFormScreenState extends ConsumerState<BeanFormScreen> {
  final _name = TextEditingController();
  final _roaster = TextEditingController();
  final _cupNotes = TextEditingController();
  final _memo = TextEditingController();
  BeanType _type = BeanType.singleOrigin;
  RoastLevel? _roast;
  DateTime? _roastDate;
  final _components = [_ComponentDraft()];
  bool _saving = false;
  bool _copyingDiagnostics = false;
  bool _typeFromOcr = false;
  final _chips = <OcrChip>[];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.bean.name;
      _roaster.text = e.bean.roaster;
      _cupNotes.text = e.bean.cupNotes.join(', ');
      _memo.text = e.bean.memo ?? '';
      _type = e.bean.type;
      _roast = e.bean.roastLevel;
      _roastDate = e.bean.roastDate;
      for (final c in _components) {
        c.dispose();
      }
      _components
        ..clear()
        ..addAll(e.components.map((comp) {
          final d = _ComponentDraft();
          d.country.text = comp.country;
          d.region.text = comp.region ?? '';
          d.process = comp.process;
          d.ratio.text = comp.ratioPercent?.toString() ?? '';
          return d;
        }));
      if (_components.isEmpty) _components.add(_ComponentDraft());
    }
    final d = widget.draft;
    if (d != null) _chips.addAll(d.chips.map((text) => OcrChip([text])));
    if (e == null) {
      _type = widget.initialType ?? d?.inferredType ?? BeanType.singleOrigin;
      _typeFromOcr = d?.inferredType != null && _type == d!.inferredType;
    }
    if (e == null && d != null) {
      if (d.name != null) _name.text = d.name!;
      if (d.roaster != null) _roaster.text = d.roaster!;
      for (final component in _components) {
        component.dispose();
      }
      _components.clear();
      for (final component in d.components) {
        final row = _ComponentDraft(
          process: component.process ?? Process.other,
          processProvidedOrEdited: component.process != null,
          processFromOcr: component.process != null,
          ratioFromOcr: component.ratioPercent != null,
        );
        row.country.text = component.country ?? '';
        row.region.text = component.region ?? '';
        row.ratio.text = component.ratioPercent?.toString() ?? '';
        _components.add(row);
      }
      if (_components.isEmpty) {
        _components.add(_ComponentDraft(process: Process.other));
      }
      _roast = d.roastLevel;
      _roastDate = d.roastDate;
      if (d.cupNotes.isNotEmpty) _cupNotes.text = d.cupNotes.join(', ');
    }
    if (_type == BeanType.singleOrigin && _components.length > 1) {
      for (final row in _components.skip(1)) {
        row.dispose();
      }
      _components.removeRange(1, _components.length);
    } else if (_type == BeanType.blend) {
      while (_components.length < 2) {
        _components.add(_ComponentDraft(
          process: e == null && d != null ? Process.other : Process.washed,
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _roaster.dispose(); _cupNotes.dispose(); _memo.dispose();
    for (final c in _components) { c.dispose(); }
    super.dispose();
  }

  List<String> _parseNotes() => _cupNotes.text
      .split(RegExp(r'[,\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _openAssignSheet(int index) async {
    final chip = _chips[index];
    // (라벨, 대상 컨트롤러, append 여부) — append는 곧 '쉼표로 이어붙임'이다.
    final targets = <(String, TextEditingController, bool)>[
      ('제품명', _name, false),
      ('로스터리', _roaster, false),
      ('원산지 국가', _components.first.country, false),
      ('지역', _components.first.region, false),
      ('컵노트에 추가', _cupNotes, true),
      ('메모', _memo, false),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              // 칩의 ' · '가 아니라 실제로 들어갈 값을 보여준다.
              child: Text('‘${chip.text(comma: false)}’ 어디에 넣을까요?',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          for (var i = 0; i < targets.length; i++)
            ListTile(
              key: Key('assign-${targets[i].$1}'),
              title: Text(targets[i].$1),
              subtitle: Text(targets[i].$2.text.trim().isEmpty ? '비어있음' : targets[i].$2.text),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    final (_, ctrl, append) = targets[picked];
    final value = chip.text(comma: append);
    setState(() {
      if (append) {
        final cur = ctrl.text.trim();
        ctrl.text = cur.isEmpty ? value : '$cur, $value';
      } else {
        ctrl.text = value;
      }
      _chips[index] = OcrChip(chip.parts, used: true);
    });
  }

  void _mergeChips(int target, int source) {
    // 두 손가락으로 동시에 끌면 드롭 시점의 인덱스가 이미 낡았을 수 있다.
    if (target == source || target >= _chips.length || source >= _chips.length) return;
    setState(() {
      final next = mergeChips(_chips, target: target, source: source);
      _chips
        ..clear()
        ..addAll(next);
    });
  }

  void _splitChips(int index) => setState(() {
        final next = splitChip(_chips, index);
        _chips
          ..clear()
          ..addAll(next);
      });

  bool get _auto => widget.existing == null && widget.draft != null;

  Future<void> _copyOcrDiagnostics() async {
    final path = widget.photoTempPath;
    if (path == null || _copyingDiagnostics) return;
    setState(() => _copyingDiagnostics = true);
    try {
      final text = await ref.read(ocrDiagnosticsServiceProvider).collect(path);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR 진단 정보가 복사됐어요')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR 진단 정보를 만들지 못했어요')),
      );
    } finally {
      if (mounted) setState(() => _copyingDiagnostics = false);
    }
  }

  Future<void> _changeType(BeanType next) async {
    if (next == _type) return;
    if (next == BeanType.blend) {
      setState(() {
        _type = next;
        _typeFromOcr = false;
        while (_components.length < 2) {
          _components.add(_ComponentDraft());
        }
      });
      return;
    }

    final removesMeaningfulRows = _components.skip(1).any((component) =>
        component.country.text.trim().isNotEmpty ||
        component.region.text.trim().isNotEmpty ||
        component.ratio.text.trim().isNotEmpty ||
        component.processProvidedOrEdited);
    if (removesMeaningfulRows) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('싱글 오리진으로 변경할까요?'),
          content: const Text('첫 번째 구성만 남아요.'),
          actions: [
            TextButton(
              key: const Key('keep-blend'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const Key('confirm-single'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('변경'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _type = BeanType.singleOrigin;
      _typeFromOcr = false;
      for (final row in _components.skip(1)) {
        row.dispose();
      }
      _components.removeRange(1, _components.length);
    });
  }

  Future<void> _save() async {
    final missingName = _name.text.trim().isEmpty;
    final missingSingleCountry = _type == BeanType.singleOrigin &&
        _components.first.country.text.trim().isEmpty;
    if (missingName || missingSingleCountry) {
      final message = _type == BeanType.singleOrigin
          ? '제품명과 첫 원산지 국가는 필수예요'
          : '제품명은 필수예요';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)));
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoPath = widget.existing?.bean.photoPath; // 편집 시 기존 사진 유지
      if (widget.photoTempPath != null) {
        photoPath = await ref.read(photoServiceProvider).persist(widget.photoTempPath!);
      }
      final input = BeanInput(
        name: _name.text.trim(),
        roaster: _roaster.text.trim(),
        type: _type,
        roastLevel: _roast,
        roastDate: _roastDate,
        cupNotes: _parseNotes(),
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        components: [
          for (final c in _components)
            if (c.country.text.trim().isNotEmpty)
              ComponentInput(
                country: c.country.text.trim(),
                region: c.region.text.trim().isEmpty ? null : c.region.text.trim(),
                process: c.process,
                ratioPercent: int.tryParse(c.ratio.text.trim()),
              ),
        ],
        photoPath: photoPath,
      );
      final repo = ref.read(beanRepositoryProvider);
      if (widget.existing == null) {
        await repo.createBean(input);
      } else {
        await repo.updateBean(widget.existing!.bean.id, input);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diagnosticsEnabled = ref.watch(ocrDiagnosticsEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '원두 추가' : '원두 편집')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
        TextField(key: const Key('field-name'), controller: _name,
            decoration: InputDecoration(labelText: '제품명 *',
                helperText: _auto && widget.draft!.name != null ? 'OCR 자동' : null)),
        const SizedBox(height: 10),
        TextField(key: const Key('field-roaster'), controller: _roaster,
            decoration: InputDecoration(labelText: '로스터리',
                helperText: _auto && widget.draft!.roaster != null ? 'OCR 자동' : null)),
        const SizedBox(height: 14),
        SegmentedButton<BeanType>(
          segments: const [
            ButtonSegment(value: BeanType.singleOrigin, label: Text('싱글')),
            ButtonSegment(value: BeanType.blend, label: Text('블렌드')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => _changeType(s.first),
        ),
        if (_typeFromOcr)
          const Text('OCR 자동', key: Key('ocr-auto-type')),
        const SizedBox(height: 14),
        Text('원산지 구성', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        if (_type == BeanType.blend &&
            _components.where((component) =>
                    component.country.text.trim().isNotEmpty).length < 2)
          const Text(
            '블렌드 구성 정보를 충분히 읽지 못했어요. '
            '아는 내용만 입력해도 저장할 수 있어요.',
            key: Key('incomplete-blend-warning'),
          ),
        for (var i = 0; i < _components.length; i++) _componentEditor(i),
        if (_type == BeanType.blend)
          TextButton.icon(
            onPressed: () => setState(() => _components.add(_ComponentDraft())),
            icon: const Icon(Icons.add), label: const Text('구성 원두 추가'),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RoastLevel>(
          initialValue: _roast,
          decoration: InputDecoration(
              labelText: '로스팅 단계',
              helperText: _auto && widget.draft!.roastLevel != null ? 'OCR 자동' : null),
          items: [for (final r in RoastLevel.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (v) => setState(() => _roast = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(_roastDate == null ? '로스팅 날짜 없음'
              : '로스팅 ${_roastDate!.toIso8601String().substring(0, 10)}'
                  '${_auto && widget.draft!.roastDate != null ? '  · OCR 자동' : ''}')),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context,
                  firstDate: DateTime(2015), lastDate: DateTime(2100),
                  initialDate: DateTime.now());
              if (picked != null) setState(() => _roastDate = picked);
            },
            child: const Text('날짜 선택'),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _cupNotes,
            decoration: InputDecoration(
                labelText: '컵노트 (쉼표로 구분)', hintText: '블루베리, 자스민, 홍차',
                helperText: _auto && widget.draft!.cupNotes.isNotEmpty ? 'OCR 자동' : null)),
        const SizedBox(height: 10),
        TextField(controller: _memo, maxLines: 3,
            decoration: const InputDecoration(labelText: '메모')),
        if (widget.draft != null) ...[
          const SizedBox(height: 14),
          if (widget.draft!.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.cup, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.appLine)),
              child: Text('글자를 자동 인식하지 못했어요. 아래 항목을 직접 입력하거나 다시 촬영해 주세요.',
                  style: TextStyle(fontSize: 12, color: c.espresso)),
            )
          else if (_chips.isNotEmpty)
            OcrChipsPanel(
              chips: _chips,
              onTap: _openAssignSheet,
              onMerge: _mergeChips,
              onSplit: _splitChips,
            ),
          if (diagnosticsEnabled &&
              _auto &&
              widget.photoTempPath != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('copy-ocr-diagnostics'),
              onPressed: _copyingDiagnostics ? null : _copyOcrDiagnostics,
              icon: _copyingDiagnostics
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy_outlined),
              label: Text(
                _copyingDiagnostics ? '진단 정보 생성 중…' : 'OCR 진단 복사',
              ),
            ),
          ],
        ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('save-bean'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: c.espresso, foregroundColor: c.oat,
                minimumSize: const Size.fromHeight(48)),
            child: Text(_saving ? '저장 중…' : '저장'),
          ),
        ),
      ),
    );
  }

  Widget _componentEditor(int i) {
    final comp = _components[i];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              key: Key('field-country-$i'),
              controller: comp.country,
              onChanged: (_) {
                if (_type == BeanType.blend) setState(() {});
              },
              decoration: InputDecoration(
                  labelText: i == 0 ? '원산지 국가 *' : '국가',
                  helperText: _auto && i < widget.draft!.components.length &&
                          widget.draft!.components[i].country != null
                      ? 'OCR 자동'
                      : null),
            ),
          ),
          if (_type == BeanType.blend && _components.length > 2)
            IconButton(
              onPressed: () => setState(() { _components.removeAt(i).dispose(); }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ]),
        // 지역에 'OCR 자동' helper가 붙으면 그만큼 키가 커진다. Row 기본 정렬(center)이면
        // helper가 없는 가공·% 필드가 아래로 밀려 밑줄이 어긋나므로 위를 맞춘다.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextField(
              key: Key('field-region-$i'),
              controller: comp.region,
              decoration: InputDecoration(
                  labelText: '지역',
                  helperText: _auto && i < widget.draft!.components.length &&
                          widget.draft!.components[i].region != null
                      ? 'OCR 자동'
                      : null))),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<Process>(
              key: Key('field-process-$i'),
              initialValue: comp.process,
              decoration: InputDecoration(
                labelText: '가공',
                helper: comp.processFromOcr
                    ? Text('OCR 자동', key: Key('ocr-auto-process-$i'))
                    : null,
              ),
              items: [for (final p in Process.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (v) => setState(() {
                comp.process = v ?? Process.washed;
                comp.processProvidedOrEdited = true;
                comp.processFromOcr = false;
              }),
            ),
          ),
          if (_type == BeanType.blend) ...[
            const SizedBox(width: 10),
            SizedBox(width: 64, child: TextField(
                key: Key('field-ratio-$i'),
                controller: comp.ratio,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => comp.ratioFromOcr = false),
                decoration: InputDecoration(
                  labelText: '%',
                  helper: comp.ratioFromOcr
                      ? Text(
                          'OCR 자동',
                          key: Key('ocr-auto-ratio-$i'),
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                ))),
          ],
        ]),
      ]),
    );
  }
}
