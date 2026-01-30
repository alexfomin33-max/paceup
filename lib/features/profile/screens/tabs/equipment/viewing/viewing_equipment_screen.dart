import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/segmented_pill.dart'; // ← глобальная пилюля
import '../../../../../../core/widgets/more_menu_hub.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import 'tabs/sneakers/viewing_sneakers_content.dart';
import 'tabs/bike/viewing_bike_content.dart';

/// Экран «Просмотр снаряжения»
class ViewingEquipmentScreen extends ConsumerStatefulWidget {
  /// 0 — Кроссовки (по умолчанию), 1 — Велосипеды
  final int initialSegment;
  /// ID пользователя, чье снаряжение нужно отобразить
  final int userId;
  const ViewingEquipmentScreen({
    super.key,
    this.initialSegment = 0,
    required this.userId,
  });

  @override
  ConsumerState<ViewingEquipmentScreen> createState() =>
      _ViewingEquipmentScreenState();
}

class _ViewingEquipmentScreenState
    extends ConsumerState<ViewingEquipmentScreen> {
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
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.getBackgroundColor(context),
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
            icon: Icon(
              CupertinoIcons.back,
              size: 22,
              color: AppColors.getIconPrimaryColor(context),
            ),
          ),
          // если нужен разделитель снизу, раскомментируй:
          // bottom: const PreferredSize(
          //   preferredSize: Size.fromHeight(1),
          //   child: Divider(height: 1, thickness: 1, color: AppColors.border),
          // ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: PageView(
            controller: _page,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: true,
            onPageChanged: (i) {
              if (_index != i) setState(() => _index = i);
            },
            children: [
              // Внутри каждого таба — свой вертикальный скролл и паддинги,
              // как устроены соответствующие *content.dart
              _TabScroller(
                segmentedPill: SegmentedPill(
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
                child: ViewingSneakersContent(
                  key: const PageStorageKey('view_sneakers'),
                  userId: widget.userId,
                ),
              ),
              _TabScroller(
                segmentedPill: SegmentedPill(
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
                child: ViewingBikeContent(
                  key: const PageStorageKey('view_bikes'),
                  userId: widget.userId,
                ),
              ),
            ],
          ),
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
  final SegmentedPill segmentedPill;
  const _TabScroller({
    required this.child,
    required this.segmentedPill,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // ────────── Скрываем меню при скролле ──────────
        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification ||
            notification is UserScrollNotification) {
          MoreMenuHub.hide();
        }
        return false;
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ── Пилюля скроллится вместе с контентом
              Center(child: segmentedPill),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
