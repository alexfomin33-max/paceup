import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import 'tabs/my_events_content.dart';
import 'tabs/bookmarks_content.dart';
import 'tabs/routes_content.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
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
          // ── Вкладки: иконка + текст (наш дефолтный паттерн TabBar + TabBarView)
          Container(
            // ── Цвет контейнера вкладок из темы
            color: AppColors.getSurfaceColor(context),
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              // ── Активная вкладка: всегда brandPrimary (одинаковый в светлой/темной)
              labelColor: AppColors.brandPrimary,
              // ── Неактивные вкладки: вторичный текст из темы
              unselectedLabelColor: AppColors.getTextSecondaryColor(context),
              indicatorColor: AppColors.brandPrimary,
              indicatorWeight: 1,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(
                  child: _TabLabel(
                    icon: CupertinoIcons.calendar,
                    text: 'События',
                  ),
                ),
                Tab(
                  child: _TabLabel(
                    icon: CupertinoIcons.bookmark,
                    text: 'Закладки',
                  ),
                ),
                Tab(
                  child: _TabLabel(icon: CupertinoIcons.map, text: 'Маршруты'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              // Добавляем padding снизу, чтобы контент не перекрывал нижнее меню
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    60, // высота нижнего меню + системный отступ
              ),
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: const [
                  MyEventsContent(),
                  BookmarksContent(),
                  RoutesContent(),
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
  const _TabLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    // ── TabBar автоматически применяет labelColor/unselectedLabelColor
    // ── через DefaultTextStyle, получаем цвет для иконки и текста
    final textStyle = DefaultTextStyle.of(context).style;
    final iconColor = textStyle.color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Иконка использует тот же цвет, что и текст (из DefaultTextStyle TabBar)
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        // ── Текст наследует цвет из DefaultTextStyle
        Text(text, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
