import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../../providers/services/auth_provider.dart';
import 'tabs/my_events_content.dart';
import 'tabs/bookmarks_content.dart';
import 'tabs/routes_content.dart';
import 'tabs/segments_content.dart';

/// Высота нижней панели навигации (совпадает с app_bottom_nav_shell).
const double _kBottomNavHeight = 60;
/// Небольшой запас, чтобы контент не обрезался под плашкой.
const double _kBottomNavExtra = 12;
/// При ширине экрана меньше этой величины иконки во вкладках скрываются,
/// чтобы влезли подписи (узкие устройства, например iPhone 15).
const double _kTabBarMinWidthForIcons = 400;

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
  }

  /// При переключении на вкладку «Маршруты» или «Участки» — обновляем список.
  void _onTabChanged() {
    final uid = ref.read(currentUserIdProvider).valueOrNull ?? 0;
    if (uid <= 0) return;
    if (_tab.index == 2) ref.invalidate(myRoutesProvider(uid));
    if (_tab.index == 3) ref.invalidate(segmentsWithMyResultsProvider(uid));
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Фон из темы: в светлой теме — surface, в темной — из темы
      backgroundColor: AppColors.twinBg,

      // ── Глобальная шапка без нижнего бордера
      appBar: const PaceAppBar(title: 'Избранное', showBottomDivider: false, elevation: 0, scrolledUnderElevation: 0,),

      body: Column(
        children: [
          // ── Вкладки: иконка + текст; на узком экране — только текст
          Container(
            color: AppColors.getSurfaceColor(context),
            child: Builder(
              builder: (context) {
                final width = MediaQuery.sizeOf(context).width;
                final showIcons = width >= _kTabBarMinWidthForIcons;
                return TabBar(
                  controller: _tab,
                  isScrollable: false,
                  labelColor: AppColors.brandPrimary,
                  unselectedLabelColor:
                      AppColors.getTextSecondaryColor(context),
                  indicatorColor: AppColors.brandPrimary,
                  indicatorWeight: 1,
                  dividerColor: AppColors.twinchip,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [
                    Tab(
                      child: _TabLabel(
                        icon: CupertinoIcons.calendar,
                        text: 'События',
                        showIcon: showIcons,
                      ),
                    ),
                    Tab(
                      child: _TabLabel(
                        icon: CupertinoIcons.bookmark,
                        text: 'Закладки',
                        showIcon: showIcons,
                      ),
                    ),
                    Tab(
                      child: _TabLabel(
                        icon: CupertinoIcons.map,
                        text: 'Маршруты',
                        showIcon: showIcons,
                      ),
                    ),
                    Tab(
                      child: _TabLabel(
                        icon: CupertinoIcons.flag,
                        text: 'Участки',
                        showIcon: showIcons,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              // Контент до плашки меню: навбар + safe area + запас (viewPadding не обнуляется в SafeArea)
              padding: EdgeInsets.only(
                bottom: _kBottomNavHeight +
                    _kBottomNavExtra +
                    MediaQuery.of(context).viewPadding.bottom,
              ),
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: const [
                  MyEventsContent(),
                  BookmarksContent(),
                  RoutesContent(),
                  SegmentsContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool showIcon;

  const _TabLabel({
    required this.icon,
    required this.text,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style;
    final iconColor = textStyle.color;

    if (!showIcon) {
      return Text(text, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(text, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
