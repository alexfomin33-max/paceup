// lib/screens/lenta/activity/together/together_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'member_content.dart';
import 'adding_content.dart';

class TogetherScreen extends StatefulWidget {
  const TogetherScreen({super.key});

  @override
  State<TogetherScreen> createState() => _TogetherScreenState();
}

class _TogetherScreenState extends State<TogetherScreen> {
  int _segment = 0; // 0 — Участники, 1 — Добавить
  late final PageController _page = PageController(initialPage: _segment);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Совместная тренировка',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          splashRadius: 22,
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.iconPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // bottom: const PreferredSize(
        //   preferredSize: Size.fromHeight(1),
        //   child: Divider(height: 1, thickness: 1, color: AppColors.border),
        // ),
      ),

      // ——— верх: сегменты; низ: PageView с горизонтальными свайпами
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: _SegmentedPill2(
                items: const ['Участники', 'Добавить'],
                value: _segment,
                onChanged: (v) {
                  _page.animateToPage(
                    v,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                width: 280,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ——— свайпы влево/вправо между вкладками
          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _segment = i),
              children: const [
                _PageWrapper(
                  key: PageStorageKey('together_members'),
                  child: MemberContent(),
                ),
                _PageWrapper(
                  key: PageStorageKey('together_adding'),
                  child: AddingContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Обёртка, чтобы каждая вкладка имела собственный вертикальный скролл и нижний отступ
class _PageWrapper extends StatelessWidget {
  final Widget child;
  const _PageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: child),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Более дёшевый вариант: один «ползунок» + статичные тексты.
/// Просто замени твой _SegmentedPill2 этим классом.
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
    final pill = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: SizedBox(
        height: 36,
        child: Stack(
          children: [
            // Скользящий фон — двигаем только его
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: value == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: RepaintBoundary(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF379AE6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),

            // Статичные кликабельные области + текст (не перерисовываются при движении фона)
            Row(
              children: [
                _seg(0, items[0], selected: value == 0),
                _seg(1, items[1], selected: value == 1),
              ],
            ),
          ],
        ),
      ),
    );

    if (width == null) return pill;
    return SizedBox(width: width, child: pill);
  }

  Widget _seg(int idx, String text, {required bool selected}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(idx),
        child: Center(
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
      ),
    );
  }
}
