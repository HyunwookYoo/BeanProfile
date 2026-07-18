import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';

class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({super.key, this.existing});
  final BeanDetail? existing;
  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _ComponentDraft {
  final country = TextEditingController();
  final region = TextEditingController();
  Process process = Process.washed;
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _components.first.country.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제품명과 첫 원산지 국가는 필수예요')));
      return;
    }
    setState(() => _saving = true);
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
    );
    try {
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '원두 추가' : '원두 편집')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        TextField(key: const Key('field-name'), controller: _name,
            decoration: const InputDecoration(labelText: '제품명 *')),
        const SizedBox(height: 10),
        TextField(controller: _roaster, decoration: const InputDecoration(labelText: '로스터리')),
        const SizedBox(height: 14),
        SegmentedButton<BeanType>(
          segments: const [
            ButtonSegment(value: BeanType.singleOrigin, label: Text('싱글')),
            ButtonSegment(value: BeanType.blend, label: Text('블렌드')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 14),
        Text('원산지 구성', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        for (var i = 0; i < _components.length; i++) _componentEditor(i),
        if (_type == BeanType.blend)
          TextButton.icon(
            onPressed: () => setState(() => _components.add(_ComponentDraft())),
            icon: const Icon(Icons.add), label: const Text('구성 원두 추가'),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RoastLevel>(
          initialValue: _roast,
          decoration: const InputDecoration(labelText: '로스팅 단계'),
          items: [for (final r in RoastLevel.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (v) => setState(() => _roast = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(_roastDate == null ? '로스팅 날짜 없음'
              : '로스팅 ${_roastDate!.toIso8601String().substring(0, 10)}')),
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
            decoration: const InputDecoration(labelText: '컵노트 (쉼표로 구분)', hintText: '블루베리, 자스민, 홍차')),
        const SizedBox(height: 10),
        TextField(controller: _memo, maxLines: 3, decoration: const InputDecoration(labelText: '메모')),
      ]),
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
              decoration: InputDecoration(labelText: i == 0 ? '원산지 국가 *' : '국가'),
            ),
          ),
          if (_type == BeanType.blend && _components.length > 1)
            IconButton(
              onPressed: () => setState(() { _components.removeAt(i).dispose(); }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: comp.region,
              decoration: const InputDecoration(labelText: '지역'))),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<Process>(
              initialValue: comp.process,
              decoration: const InputDecoration(labelText: '가공'),
              items: [for (final p in Process.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (v) => setState(() => comp.process = v ?? Process.washed),
            ),
          ),
          if (_type == BeanType.blend) ...[
            const SizedBox(width: 10),
            SizedBox(width: 64, child: TextField(controller: comp.ratio,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '%'))),
          ],
        ]),
      ]),
    );
  }
}
