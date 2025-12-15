import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart'; // ← наш глобальный AppBar
import '../../../core/widgets/transparent_route.dart';
import '../providers/profile_header_provider.dart';
import '../providers/profile_header_state.dart';
import '../../../providers/services/auth_provider.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats_tab.dart';
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
  final GlobalKey<MainTabState> _mainTabKey = GlobalKey<MainTabState>();

  int _tab = 0;
  bool _wasRouteActive =
      false; // Отслеживание предыдущего состояния видимости маршрута

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Обновление данных профиля при открытии экрана
  // Вызывается при инициализации виджета для получения свежих данных
  // Использует refresh() вместо reload() чтобы не очищать кэш аватарки
  // и избежать визуального "мигания" изображения
  // ────────────────────────────────────────────────────────────────────────
  void _updateProfileHeader(int userId) {
    // Используем refresh() для обновления данных без очистки кэша аватарки
    // Это обновит количество подписок и подписчиков без визуального эффекта
    ref.read(profileHeaderProvider(userId).notifier).refresh();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Проверка видимости экрана и обновление данных при отображении
  // Вызывается при каждом build для отслеживания видимости маршрута
  // ────────────────────────────────────────────────────────────────────────
  void _checkRouteVisibility() {
    final route = ModalRoute.of(context);
    final isRouteActive = route?.isCurrent ?? false;

    // Если маршрут стал активным (видимым), обновляем данные
    if (isRouteActive && !_wasRouteActive) {
      _wasRouteActive = true;

      // Обновляем данные профиля при отображении экрана
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final userId = widget.userId;
        if (userId != null) {
          _updateProfileHeader(userId);
        } else {
          final currentUserIdAsync = ref.read(currentUserIdProvider);
          currentUserIdAsync.whenData((currentUserId) {
            if (currentUserId != null && mounted) {
              _updateProfileHeader(currentUserId);
            }
          });
        }
      });
    } else if (!isRouteActive) {
      // Если маршрут стал неактивным, сбрасываем флаг для следующего отображения
      _wasRouteActive = false;
    }
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

  void _onPageChanged(int i) {
    setState(() => _tab = i);
    // При переключении на вкладку "Основное" (индекс 0) проверяем кэш
    if (i == 0) {
      MainTab.checkCache(_mainTabKey);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Обновление данных профиля при переключении вкладок
    // Обновляем количество подписок и подписчиков при каждом переключении
    // ────────────────────────────────────────────────────────────────────────
    final userId = widget.userId;
    if (userId != null) {
      _updateProfileHeader(userId);
    } else {
      // Если userId не передан, получаем текущего пользователя
      final currentUserIdAsync = ref.read(currentUserIdProvider);
      currentUserIdAsync.whenData((currentUserId) {
        if (currentUserId != null) {
          _updateProfileHeader(currentUserId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────────────
    // Проверка видимости экрана и обновление данных при отображении
    // Вызывается при каждом build для отслеживания, когда экран становится видимым
    // Это гарантирует обновление данных при возврате из других экранов (например, настроек)
    // ────────────────────────────────────────────────────────────────────────
    _checkRouteVisibility();

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
            backgroundColor: AppColors.getBackgroundColor(context),
            appBar: PaceAppBar(
              titleWidget: Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 20,
                    color: AppColors.getIconPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI тренер',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              showBack: false,
              showBottomDivider: true,
            ),
            body: Center(
              child: Text(
                'Необходима авторизация',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextSecondaryColor(context),
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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          titleWidget: Row(
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
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          titleWidget: Row(
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: AppColors.error,
              ),
              SizedBox(height: 16),
              Text(
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
      backgroundColor: AppColors.getBackgroundColor(context),

      // ─────────── Верхняя шапка: обычный, плоский PaceAppBar ───────────
      appBar: PaceAppBar(
        // Тот же заголовок с иконкой «AI тренер», но без стекла/прозрачности
        titleWidget: Row(
          children: [
            Icon(
              CupertinoIcons.sparkles,
              size: 20,
              color: AppColors.getIconPrimaryColor(context),
            ),
            const SizedBox(width: 8),
            Text(
              'AI тренер',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 6),
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
                ref.read(profileHeaderProvider(userId).notifier).reload();
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
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),

          // Контент вкладок — скроллится внутри, шапка/табы остаются на месте
          Expanded(
            child: GearPrefsScope(
              notifier: _gearPrefs,
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  MainTab(key: _mainTabKey, userId: userId),
                  PhotosTab(userId: userId),
                  const StatsTab(),
                  const TrainingTab(),
                  const RacesTab(),
                  const GearTab(),
                  ClubsTab(userId: userId),
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
    return SizedBox(
      width: 44.0, // kAppBarTapTarget
      height: 44.0, // kAppBarTapTarget
      child: IconButton(
        onPressed: onPressed ?? () {},
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
        icon: Icon(
          icon,
          color: AppColors.getIconPrimaryColor(context),
          size: 20.0,
        ),
        splashRadius: 22,
      ),
    );
  }
}
