import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'degassing.dart';
import 'widgets/intensity_selector.dart';
import 'widgets/star_input.dart';

class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen({
    super.key,
    required this.beanId,
    required this.roastDate,
    this.existing,
  });
  final int beanId;
  /// 원두의 로스팅 날짜. 있으면 디개싱 일수를 계산해 읽기 전용으로 보여주고,
  /// 없으면 사용자가 직접 적는다.
  final DateTime? roastDate;
  final Tasting? existing;
  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormScreenState();
}

class _TastingFormScreenState extends ConsumerState<TastingFormScreen> {
  DateTime _date = DateTime.now();
  int _acidity = 3, _sweetness = 3, _body = 3, _bitterness = 3, _overall = 3;
  final _comment = TextEditingController();
  final _degassing = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = e.date;
      _acidity = e.acidity;
      _sweetness = e.sweetness;
      _body = e.body;
      _bitterness = e.bitterness;
      _overall = e.overall;
      _comment.text = e.comment ?? '';
      _degassing.text = e.degassingDays?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _degassing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final input = TastingInput(
      date: _date,
      acidity: _acidity, sweetness: _sweetness, body: _body,
      bitterness: _bitterness, overall: _overall,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      degassingDays: int.tryParse(_degassing.text),
    );
    try {
      final repo = ref.read(beanRepositoryProvider);
      if (widget.existing == null) {
        await repo.createTasting(widget.beanId, input);
      } else {
        await repo.updateTasting(widget.existing!.id, input);
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('시음 기록 삭제'),
        content: const Text('이 시음 기록을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(beanRepositoryProvider).deleteTasting(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제에 실패했어요')));
      }
    }
  }

  Widget _degassingRow(BuildContext context) {
    final c = context.colors;
    const label = SizedBox(
        width: 52, child: Text('디개싱', style: TextStyle(fontSize: 13.5)));

    if (widget.roastDate == null) {
      return Row(children: [
        label,
        SizedBox(
          width: 82,
          child: TextField(
            key: const Key('degassing-input'),
            controller: _degassing,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(counterText: '', suffixText: '일'),
          ),
        ),
        const SizedBox(width: 10),
        Text('로스팅 날짜 없음', style: TextStyle(fontSize: 11.5, color: c.appMuted)),
      ]);
    }

    final deg = degassingLabel(roastDate: widget.roastDate, tastingDate: _date);
    if (deg == null) return const SizedBox.shrink(); // roastDate가 있으면 도달하지 않는다
    return Row(children: [
      Text(deg.text,
          style: monoStyle(
              size: 13, weight: FontWeight.w600,
              color: deg.warn ? c.cherry : c.espresso)),
      const SizedBox(width: 10),
      Text('로스팅 ${widget.roastDate!.toIso8601String().substring(0, 10)}',
          style: TextStyle(fontSize: 11.5, color: c.appMuted)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '시음 기록' : '시음 편집'),
        actions: [
          if (widget.existing != null)
            IconButton(
              key: const Key('delete-tasting'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
        Row(children: [
          Expanded(
            child: Text('시음일 ${_date.toIso8601String().substring(0, 10)}',
                style: TextStyle(color: c.espresso)),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2100),
                  initialDate: _date);
              if (picked != null) setState(() => _date = picked);
            },
            child: const Text('날짜 선택'),
          ),
        ]),
        _degassingRow(context),
        const Divider(height: 20),
        Text('강도', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        IntensitySelector(label: '산미', value: _acidity, onChanged: (v) => setState(() => _acidity = v)),
        IntensitySelector(label: '단맛', value: _sweetness, onChanged: (v) => setState(() => _sweetness = v)),
        IntensitySelector(label: '바디', value: _body, onChanged: (v) => setState(() => _body = v)),
        IntensitySelector(label: '쓴맛', value: _bitterness, onChanged: (v) => setState(() => _bitterness = v)),
        const SizedBox(height: 14),
        Text('종합 만족도', style: TextStyle(fontWeight: FontWeight.w700, color: c.espresso)),
        const SizedBox(height: 6),
        StarInput(value: _overall, onChanged: (v) => setState(() => _overall = v)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('tasting-comment'),
          controller: _comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '코멘트'),
        ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('save-tasting'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: c.espresso,
                foregroundColor: c.oat,
                minimumSize: const Size.fromHeight(48)),
            child: Text(_saving ? '저장 중…' : '저장'),
          ),
        ),
      ),
    );
  }
}
