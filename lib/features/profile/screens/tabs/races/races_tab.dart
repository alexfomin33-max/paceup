import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'tabs/my_races_content.dart';
import 'tabs/friend_races_content.dart';

class RacesTab extends StatefulWidget {
  const RacesTab({super.key});
  @override
  State<RacesTab> createState() => _RacesTabState();
}

class _RacesTabState extends State<RacesTab>
    with AutomaticKeepAliveClientMixin {
  int _segment = 0; // 0 — Мои, 1 — Друзей
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      primary: false, // Отключаем автоматическое использование PrimaryScrollController
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final w = MediaQuery.of(context).size.width;
              final pillWidth = (w - 32).clamp(
                200.0,
                260.0,
              ); // почти на всю ширину, но с красивым максимумом
              return Center(
                child: _SegmentedPill2(
                  items: const ['Мои', 'Друзей'],
                  value: _segment,
                  width: pillWidth,
                  onChanged: (v) => setState(() => _segment = v),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        if (_segment == 0)
          ...buildMyRacesSlivers()
        else
          ...buildFriendRacesSlivers(),
      ],
    );
  }
}

/// Пилюльный переключатель на 2 пункта — стиль как в awards_tab.dart
class _SegmentedPill2 extends StatelessWidget {
  final List<String> items;
  final int value;
  final double? width; // 👈 добавили ширину
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
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _seg(context, 0, items[0])),
          Expanded(child: _seg(context, 1, items[1])),
        ],
      ),
    );

    if (width == null) return content;
    return SizedBox(width: width, child: content); // 👈 равные и пошире
  }

  Widget _seg(BuildContext context, int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.getTextPrimaryColor(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? AppColors.getSurfaceColor(context)
                : AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}
