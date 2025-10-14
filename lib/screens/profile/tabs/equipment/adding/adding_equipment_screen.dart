import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import 'adding_bike_content.dart';
import 'adding_sneakers_content.dart';

/// Экран «Добавить снаряжение»
class AddingEquipmentScreen extends StatefulWidget {
  const AddingEquipmentScreen({super.key});

  @override
  State<AddingEquipmentScreen> createState() => _AddingEquipmentScreenState();
}

class _AddingEquipmentScreenState extends State<AddingEquipmentScreen> {
  int _segment = 0; // 0 = Кроссовки, 1 = Велосипед

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        centerTitle: true,
        title: const Text(
          'Добавить снаряжение',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.iconPrimary,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── Переключатель как в stats_tab.dart
            Center(
              child: _SegmentedPill2(
                items: const ['Кроссовки', 'Велосипед'],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
                width: 280,
              ),
            ),
            const SizedBox(height: 16),

            // ── Контент
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _segment == 0
                  ? const AddingSneakersContent(key: ValueKey('sneakers'))
                  : const AddingBikeContent(key: ValueKey('bike')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пилюльный переключатель на 2 пункта — копия из stats_tab.dart
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
        borderRadius: BorderRadius.circular(24),
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
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.surface : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
