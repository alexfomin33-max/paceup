import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

import 'general_stats_content.dart';
import 'bytype_stats_content.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
    with AutomaticKeepAliveClientMixin {
  int _segment = 0; // 0 — Общая, 1 — По видам

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(
          child: Center(
            child: _SegmentedPill2(
              items: const ['Общая', 'По видам'],
              value: _segment,
              onChanged: (v) => setState(() => _segment = v),
              width: 280,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        if (_segment == 0)
          ...buildGeneralStatsSlivers()
        else
          ...buildByTypeStatsSlivers(),

        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }
}

/// Пилюльный переключатель на 2 пункта (как в других вкладках)
class _SegmentedPill2 extends StatelessWidget {
  final List<String> items;
  final int value;
  final double? width;
  final ValueChanged<int> onChanged;
  const _SegmentedPill2({
    required this.items,
    required this.value,
    required this.onChanged,
    this.width,
  }) : assert(items.length == 2);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _seg(0, items[0])),
          Expanded(child: _seg(1, items[1])),
        ],
      ),
    );

    if (width == null) return content;
    return SizedBox(width: width, child: content);
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? AppColors.surface : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
