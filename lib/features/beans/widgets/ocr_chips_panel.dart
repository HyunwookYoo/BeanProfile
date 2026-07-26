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
    required this.onSplit,
  });
  final List<OcrChip> chips;
  final void Function(int index) onTap;

  /// 떨군 칩(`target`) 뒤에 끌어온 칩(`source`)을 붙인다.
  final void Function(int target, int source) onMerge;

  /// 병합 칩을 조각들로 되돌린다.
  final void Function(int index) onSplit;

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
    // 배정된 칩은 조작 대상이 아니다 — 끌 수도, 받을 수도 없다.
    if (chips[index].used) return _chip(context, index, key: _keyOf(index));
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
    final border = highlighted ? BorderSide(color: c.cremaInk, width: 2) : null;
    // 배정된 칩은 병합 칩이어도 ✕ 없이 흐린 ActionChip이다(조작 대상 아님).
    if (chip.isMerged && !chip.used) {
      return InputChip(
        key: key,
        label: Text(chip.label),
        onPressed: () => onTap(index),
        backgroundColor: c.crema,
        side: border,
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => onSplit(index),
        // 기본 삭제 툴팁은 MaterialLocalizations의 영어 'Delete'로 떨어진다(로컬라이제이션
        // 미등록) — 문구도 틀리고(✕는 분해지 삭제가 아님), Tooltip이 LongPressDraggable과
        // 같은 kLongPressTimeout에 경쟁하는 제스처 인식기까지 깐다. 빈 문자열은
        // Tooltip.build가 그대로 반환해 둘 다 없앤다.
        deleteButtonTooltipMessage: '',
      );
    }
    return ActionChip(
      key: key,
      label: Text(chip.label),
      onPressed: chip.used ? null : () => onTap(index),
      backgroundColor: chip.used ? c.oat : c.crema,
      side: border,
    );
  }
}
