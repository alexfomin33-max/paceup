import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_bar.dart'; // ← наш глобальный AppBar
import '../../../widgets/transparent_route.dart';
import '../../providers/profile/profile_header_provider.dart';
import '../../providers/profile/profile_header_state.dart';
import '../../providers/services/auth_provider.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats/stats_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/races/races_tab.dart';
import 'tabs/equipment/equipment_tab.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/awards/awards_tab.dart';
import 'tabs/skills/skills_tab.dart';

// общий стейт видимости снаряжения
import 'tabs/main/widgets/gear_screen.dart';
import 'state/search/search_screen.dart';

// экран настроек
import 'state/settings/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  /// Опциональный userId. Если не передан, используется текущий пользователь из AuthService
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    // Если userId передан явно, используем его, иначе получаем текущего пользователя из AuthService
    if (widget.userId != null) {
      // Используем переданный userId (например, при открытии профиля другого пользователя из ленты)
      final profileState = ref.watch(profileHeaderProvider(widget.userId!));
      return _buildProfileContent(widget.userId!, profileState);
    }

    // Получаем текущего пользователя из AuthService
    final currentUserIdAsync = ref.watch(currentUserIdProvider);

    // Обрабатываем состояние загрузки userId
    return currentUserIdAsync.when(
      data: (userId) {
        if (userId == null) {
          // Пользователь не авторизован
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: PaceAppBar(
              titleWidget: const Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 20,
                    color: AppColors.iconPrimary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI тренер',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16),
                  ),
                  SizedBox(width: 6),
                ],
              ),
              showBack: false,
              showBottomDivider: true,
            ),
            body: const Center(
              child: Text(
                'Необходима авторизация',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        // Читаем состояние профиля из Riverpod provider для текущего пользователя
        final profileState = ref.watch(profileHeaderProvider(userId));

        return _buildProfileContent(userId, profileState);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(
          titleWidget: const Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'AI тренер',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16),
              ),
              SizedBox(width: 6),
            ],
          ),
          showBack: false,
          showBottomDivider: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(
          titleWidget: const Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'AI тренер',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16),
              ),
              SizedBox(width: 6),
            ],
          ),
          showBack: false,
          showBottomDivider: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ошибка загрузки данных пользователя',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит контент профиля для указанного userId
  Widget _buildProfileContent(int userId, ProfileHeaderState profileState) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ─────────── Верхняя шапка: обычный, плоский PaceAppBar ───────────
      appBar: PaceAppBar(
        // Тот же заголовок с иконкой «AI тренер», но без стекла/прозрачности
        titleWidget: const Row(
          children: [
            Icon(
              CupertinoIcons.sparkles,
              size: 20,
              color: AppColors.iconPrimary,
            ),
            SizedBox(width: 8),
            Text(
              'AI тренер',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16),
            ),
            SizedBox(width: 6),
          ],
        ),
        showBack: false, // это корневой экран профиля — кнопка назад не нужна
        actions: [
          const _AppIcon(CupertinoIcons.square_arrow_up),
          _AppIcon(
            CupertinoIcons.person_badge_plus,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const SearchPrefsPage(startIndex: 0),
                ),
              );
            },
          ),
          _AppIcon(
            CupertinoIcons.gear,
            onPressed: () {
              Navigator.of(context).push(
                TransparentPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        showBottomDivider: true,
      ),

      // ─────────── Статика сверху (HeaderCard + TabsBar) + вкладки ниже ───────────
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Хедер профиля — статичный
          RepaintBoundary(
            child: HeaderCard(
              profile: profileState.profile,
              userId: userId,
              onReload: () {
                ref
                    .read(profileHeaderProvider(userId).notifier)
                    .reload();
              },
            ),
          ),

          // TabsBar — тоже статичный
          RepaintBoundary(
            child: SizedBox(
              height: 40.5,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, _) {
                  final page = _pageController.hasClients
                      ? (_pageController.page ?? _tab.toDouble())
                      : _tab.toDouble();
                  return TabsBar(
                    value: _tab,
                    page: page,
                    items: _tabTitles,
                    onChanged: _onTabTap,
                  );
                },
              ),
            ),
          ),

          // Разделитель под табами
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),

          // Контент вкладок — скроллится внутри, шапка/табы остаются на месте
          Expanded(
            child: GearPrefsScope(
              notifier: _gearPrefs,
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  MainTab(userId: userId),
                  const PhotosTab(),
                  const StatsTab(),
                  const TrainingTab(),
                  const RacesTab(),
                  const GearTab(),
                  const ClubsTab(),
                  const AwardsTab(),
                  const SkillsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _AppIcon(this.icon, {this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.iconPrimary, size: 20),
      onPressed: onPressed ?? () {},
      splashRadius: 22,
    );
  }
}
