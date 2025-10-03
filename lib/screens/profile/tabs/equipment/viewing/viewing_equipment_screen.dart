import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import 'viewing_sneakers_content.dart';
import 'viewing_bike_content.dart';

/// Экран «Просмотр снаряжения»
class ViewingEquipmentScreen extends StatefulWidget {
  final int initialSegment; // 0 — Кроссовки, 1 — Велосипед
  const ViewingEquipmentScreen({super.key, this.initialSegment = 0});

  @override
  State<ViewingEquipmentScreen> createState() => _ViewingEquipmentScreenState();
}

class _ViewingEquipmentScreenState extends State<ViewingEquipmentScreen> {
  late int _segment = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Просмотр снаряжения',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: _SegmentedPill2(
                items: const ['Кроссовки', 'Велосипеды'],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
                width: 280,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _segment == 0
                  ? const ViewingSneakersContent(key: ValueKey('s'))
                  : const ViewingBikeContent(key: ValueKey('b')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тот же «пилюльный» переключатель, что и в stats_tab.dart
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _seg(0, items[0])),
          Expanded(child: _seg(1, items[1])),
        ],
      ),
    );
    return width == null ? content : SizedBox(width: width, child: content);
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
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
