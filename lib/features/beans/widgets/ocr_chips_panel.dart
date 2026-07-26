import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../ocr/ocr_chip.dart';

/// 인식된 텍스트 칩. 탭하면 '어디에 넣을지' 배정 시트가 열리고,
/// 길게 눌러 다른 칩 위로 끌면 두 칩이 합쳐진다. 쓴 칩은 흐려짐.
class OcrChipsPanel extends StatelessWidget {
  const OcrChipsPanel({
    super.key,
    required this.chips,
    required this.onTap,
    required this.onMerge,
  });
  final List<OcrChip> chips;
  final void Function(int index) onTap;

  /// 떨군 칩(`target`) 뒤에 끌어온 칩(`source`)을 붙인다.
  final void Function(int target, int source) onMerge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.cup, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.crema, style: BorderStyle.solid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('인식된 텍스트 — 탭하면 어디에 넣을지 물어봐요 · 길게 눌러 다른 칩에 끌면 합쳐져요',
            style: TextStyle(fontSize: 11, color: c.cremaInk, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < chips.length; i++) _slot(context, i),
        ]),
      ]),
    );
  }

  /// 칩 하나 = 끌 수 있으면서 동시에 받을 수 있는 자리.
  Widget _slot(BuildContext context, int index) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMerge(index, d.data),
      builder: (context, candidate, _) => LongPressDraggable<int>(
        data: index,
        // feedback은 오버레이에 뜨므로 Key를 주지 않는다 — 드래그 중 같은 Key가
        // 둘이 되면 find.byKey가 흔들린다.
        feedback: Material(
          color: Colors.transparent,
          child: _chip(context, index, highlighted: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _chip(context, index, key: _keyOf(index)),
        ),
        child: _chip(context, index,
            key: _keyOf(index), highlighted: candidate.isNotEmpty),
      ),
    );
  }

  Key _keyOf(int index) => Key('chip-${chips[index].label}');

  Widget _chip(BuildContext context, int index, {Key? key, bool highlighted = false}) {
    final c = context.colors;
    final chip = chips[index];
    return ActionChip(
      key: key,
      label: Text(chip.label),
      onPressed: chip.used ? null : () => onTap(index),
      backgroundColor: chip.used ? c.oat : c.crema,
      side: highlighted ? BorderSide(color: c.cremaInk, width: 2) : null,
    );
  }
}
