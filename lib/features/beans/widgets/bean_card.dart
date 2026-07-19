import 'package:flutter/material.dart';
import '../../../data/enums.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import 'bean_thumbnail.dart';
import 'star_rating.dart';

class BeanCard extends StatelessWidget {
  const BeanCard({super.key, required this.summary, this.onTap});
  final BeanSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bean = summary.bean;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.cup,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.appLine),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BeanThumbnail(photoPath: bean.photoPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bean.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text([bean.roaster, summary.originLabel].where((e) => e != null && e.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: c.appMuted)),
              const SizedBox(height: 8),
              Row(children: [
                if (bean.type == BeanType.blend) ...[
                  _Badge(text: 'BLEND', color: c.cremaInk),
                  const SizedBox(width: 8),
                ],
                StarRating(value: summary.avgRating),
                const Spacer(),
                Text('시음 ${summary.tastingCount}', style: monoStyle(size: 11, color: c.appMuted)),
              ]),
              if (bean.cupNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 5, runSpacing: 5, children: [
                  for (final n in bean.cupNotes.take(4)) _Note(text: n, color: c),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text; final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: monoStyle(size: 10, color: color)),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});
  final String text; final AppColors color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.oat,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.appLine),
        ),
        child: Text(text, style: TextStyle(fontSize: 10.5, color: color.espresso)),
      );
}
