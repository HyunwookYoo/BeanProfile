import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'widgets/intensity_selector.dart';
import 'widgets/star_input.dart';

class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen({super.key, required this.beanId});
  final int beanId;
  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormScreenState();
}

class _TastingFormScreenState extends ConsumerState<TastingFormScreen> {
  DateTime _date = DateTime.now();
  int _acidity = 3, _sweetness = 3, _body = 3, _bitterness = 3, _overall = 3;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final input = TastingInput(
      date: _date,
      acidity: _acidity, sweetness: _sweetness, body: _body,
      bitterness: _bitterness, overall: _overall,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );
    try {
      await ref.read(beanRepositoryProvider).createTasting(widget.beanId, input);
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
      appBar: AppBar(title: const Text('시음 기록')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
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
        const SizedBox(height: 8),
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
          controller: _comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '코멘트'),
        ),
      ]),
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
