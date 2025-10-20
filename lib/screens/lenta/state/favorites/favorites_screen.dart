import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import 'tabs/my_events_content.dart';
import 'tabs/bookmarks_content.dart';
import 'tabs/routes_content.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
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
      backgroundColor: AppColors.background,

      // ── Глобальная шапка без нижнего бордера
      appBar: const PaceAppBar(title: 'Избранное', showBottomDivider: false),

      body: Column(
        children: [
          // ── Вкладки: иконка + текст (наш дефолтный паттерн TabBar + TabBarView)
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textPrimary,
              indicatorColor: AppColors.brandPrimary,
              indicatorWeight: 1,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(
                  child: _TabLabel(
                    icon: CupertinoIcons.calendar,
                    text: 'Мои события',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
