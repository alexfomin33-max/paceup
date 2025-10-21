import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/segmented_pill.dart'; // ← глобальная пилюля
import 'tabs/sneakers/viewing_sneakers_content.dart';
import 'tabs/bike/viewing_bike_content.dart';

/// Экран «Просмотр снаряжения»
class ViewingEquipmentScreen extends StatefulWidget {
  /// 0 — Кроссовки (по умолчанию), 1 — Велосипеды
  final int initialSegment;
  const ViewingEquipmentScreen({super.key, this.initialSegment = 0});

  @override
  State<ViewingEquipmentScreen> createState() => _ViewingEquipmentScreenState();
}

class _ViewingEquipmentScreenState extends State<ViewingEquipmentScreen> {
  // motion-токены для табов (локально, чтобы не ловить undefined)
  static const Duration _kTabAnim = Duration(milliseconds: 300);
  static const Curve _kTabCurve = Curves.easeOutCubic;

  int _index = 0;
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    // страхуемся от некорректных значений
    _index = (widget.initialSegment == 1) ? 1 : 0;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        centerTitle: true,
        title: const Text(
          'Просмотр снаряжения',
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
        // если нужен разделитель снизу, раскомментируй:
        // bottom: const PreferredSize(
        //   preferredSize: Size.fromHeight(1),
        //   child: Divider(height: 1, thickness: 1, color: AppColors.border),
        // ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ── Пилюля как segmented_pill.dart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SegmentedPill(
                  left: 'Кроссовки',
                  right: 'Велосипеды',
                  value: _index,
                  width: 280,
                  height: 40,
                  duration: _kTabAnim,
                  curve: _kTabCurve,
                  haptics: true,
                  onChanged: (v) {
                    if (_index == v) return;
                    setState(() => _index = v);
                    _page.animateToPage(
                      v,
                      duration: _kTabAnim,
                      curve: _kTabCurve,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Горизонтальный свайп между вкладками (как в остальных экранах)
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                allowImplicitScrolling: true,
                onPageChanged: (i) {
                  if (_index != i) setState(() => _index = i);
                },
                children: const [
                  // Внутри каждого таба — свой вертикальный скролл и паддинги,
                  // как устроены соответствующие *content.dart
                  _TabScroller(
                    child: ViewingSneakersContent(
                      key: PageStorageKey('view_sneakers'),
                    ),
                  ),
                  _TabScroller(
                    child: ViewingBikeContent(
                      key: PageStorageKey('view_bikes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Обёртка таба: даёт вертикальный скролл + единые внутренние поля.
/// Если твои *_content уже сами скроллятся (ListView/CustomScrollView),
/// замени внутри PageView на них напрямую без _TabScroller.
class _TabScroller extends StatelessWidget {
  final Widget child;
  const _TabScroller({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: child,
      ),
    );
  }
}
