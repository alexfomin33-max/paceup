import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/workouts_tab.dart';
import 'tabs/races_tab.dart';
import 'tabs/gear_tab.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/awards/awards_tab.dart';
import 'tabs/skills_tab.dart';

// общий стейт видимости снаряжения
import 'state/gear_prefs.dart';

// 👉 экран настроек
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _tabTitles = [
    'Основное',
    'Фото',
    'Статистика',
    'Тренировки',
    'Соревнования',
    'Снаряжение',
    'Клубы',
    'Награды',
    'Навыки',
  ];

  final PageController _pageController = PageController();
  final GearPrefs _gearPrefs = GearPrefs();

  int _tab = 0;

  void _onTabTap(int i) {
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) => setState(() => _tab = i);

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Вариант без «прилипания» TabsBar: он скроллится вместе со страницей
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Закреплённый AppBar
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 8,
            title: const Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 18, color: AppColors.text),
                SizedBox(width: 8),
                Text(
                  'AI тренер',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(width: 6),
              ],
            ),
            // actions теперь НЕ const, чтобы передать колбэк
            actions: [
              const _AppIcon(CupertinoIcons.square_arrow_up),
              const _AppIcon(CupertinoIcons.person_badge_plus),
              _AppIcon(
                CupertinoIcons.gear,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(0.5),
              child: SizedBox(
                height: 0.5,
                child: ColoredBox(color: Color(0xFFEAEAEA)),
              ),
            ),
          ),

          // Хедер профиля
          const SliverToBoxAdapter(child: RepaintBoundary(child: HeaderCard())),

          // TabsBar — обычным сливером (не pinned)
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (_, __) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? _tab.toDouble())
                    : _tab.toDouble();
                return SizedBox(
                  height: 40.5,
                  child: TabsBar(
                    value: _tab,
                    page: page,
                    items: _tabTitles,
                    onChanged: _onTabTap,
                  ),
                );
              },
            ),
          ),
        ],
        // Тело — свайповый PageView, обёрнут в GearPrefsScope
        body: GearPrefsScope(
          notifier: _gearPrefs,
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onPageChanged,
            children: const [
              MainTab(),
              PhotosTab(),
              StatsTab(),
              WorkoutsTab(),
              RacesTab(),
              GearTab(),
              ClubsTab(),
              AwardsTab(),
              SkillsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed; // 👈 добавили колбэк
  const _AppIcon(this.icon, {this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.text, size: 20),
      onPressed: onPressed ?? () {},
      splashRadius: 18,
    );
  }
}
