import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'achievements_content.dart';
import 'collections_content.dart';
import 'medals_content.dart';

class AwardsTab extends StatefulWidget {
  const AwardsTab({super.key});
  @override
  State<AwardsTab> createState() => _AwardsTabState();
}

class _AwardsTabState extends State<AwardsTab>
    with AutomaticKeepAliveClientMixin {
  int _segment = 0; // 0 — достижения, 1 — коллекции, 2 — медали
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Center(
            child: _SegmentedPill3(
              items: const ['Достижения', 'Коллекции', 'Медали'],
              value: _segment,
              onChanged: (v) => setState(() => _segment = v),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        if (_segment == 0)
          ...buildAchievementsSlivers()
        else if (_segment == 1)
          ...buildCollectionsSlivers()
        else
          ...buildMedalsSlivers(),
      ],
    );
  }
}

/// Пилюльный переключатель на 3 пункта
class _SegmentedPill3 extends StatelessWidget {
  final List<String> items;
  final int value;
  final ValueChanged<int> onChanged;
  const _SegmentedPill3({
    required this.items,
    required this.value,
    required this.onChanged,
  }) : assert(items.length == 3);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => _seg(i, items[i])),
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.surface : AppColors.text,
          ),
        ),
      ),
    );
  }
}
